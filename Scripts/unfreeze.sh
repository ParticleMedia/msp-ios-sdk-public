#!/usr/bin/env bash
# ============================================================================
# MSP iOS SDK — Code Unfreeze Script
# ============================================================================
# Usage: ./Scripts/unfreeze.sh NB_VERSION=26.18.0 [DELETE_BRANCH=1]
#    or: make unfreeze NB_VERSION=26.18.0 [DELETE_BRANCH=1]
#
# Closes the freeze cycle for NB_VERSION.
#
# Behavior:
#   - Verifies all freeze-branch commits are cherry-picked to develop
#   - Updates .msp-freeze-state.json on the freeze branch (status -> "closed")
#   - By default RETAINS the freeze branch for future diff/audit
#   - Pass DELETE_BRANCH=1 to remove the freeze branch (remote + local)
#
# State JSON lives ON the freeze branch (schema v2, see Scripts/freeze.sh).
# ============================================================================
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Error: not inside a git repository. Run from the msp-ios-sdk checkout." >&2
    exit 1
}
# Anchor cwd to repo root so relative `git add`/`-f` paths resolve correctly
# regardless of where the user invokes the script from.
cd "$ROOT_DIR"

STATE_FILENAME=".msp-freeze-state.json"

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
NB_VERSION=""
DELETE_BRANCH=0
# Backwards-compat: KEEP_BRANCH=0 (legacy) implies DELETE_BRANCH=1.
for arg in "$@"; do
    case "$arg" in
        NB_VERSION=*)    NB_VERSION="${arg#NB_VERSION=}" ;;
        DELETE_BRANCH=1) DELETE_BRANCH=1 ;;
        KEEP_BRANCH=0)   DELETE_BRANCH=1 ;;
        KEEP_BRANCH=1)   DELETE_BRANCH=0 ;;
        *)               [[ -z "$NB_VERSION" ]] && NB_VERSION="$arg" ;;
    esac
done

# ---------------------------------------------------------------------------
# Colors and logging helpers
# ---------------------------------------------------------------------------
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[unfreeze]${NC} $*"; }
success() { echo -e "${GREEN}[unfreeze]${NC} $*"; }
warn()    { echo -e "${YELLOW}[unfreeze]${NC} $*"; }
die()     { echo -e "${RED}[unfreeze] ERROR:${NC} $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Validate inputs
# ---------------------------------------------------------------------------
[[ -z "$NB_VERSION" ]] && die "NB_VERSION is required. Usage: make unfreeze NB_VERSION=26.18.0 [DELETE_BRANCH=1]"

# Layer 1 — project conventions (slashes/spaces/leading dot or dash).
if [[ "$NB_VERSION" =~ [[:space:]/] ]] \
    || [[ "$NB_VERSION" == .* ]] \
    || [[ "$NB_VERSION" == -* ]]; then
    die "NB_VERSION contains invalid characters. Use semver-like format (e.g., 26.18.0). Got: $NB_VERSION"
fi

FREEZE_BRANCH="freeze/nb-${NB_VERSION}"

# Layer 2 — git's authoritative ref-name validator (catches `:`, `..`,
# trailing `.`, `@{...}`, etc.).
if ! git check-ref-format --branch "$FREEZE_BRANCH" >/dev/null 2>&1; then
    die "NB_VERSION '$NB_VERSION' would point at an invalid git branch name ('$FREEZE_BRANCH'). Use semver-like format (e.g., 26.18.0)."
fi

# If we abort while sitting on the freeze branch (e.g., a step inside the
# retain-path checkout block fails), restore develop so the user is not
# stranded with cryptic state.
restore_develop_on_abort() {
    local rc=$?
    local current
    current="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    if [[ $rc -ne 0 ]] && [[ "$current" == "$FREEZE_BRANCH" ]]; then
        warn "Aborted while on ${FREEZE_BRANCH}. Restoring develop..."
        git checkout develop --quiet 2>/dev/null || true
    fi
}
trap restore_develop_on_abort EXIT

info "Closing freeze cycle for NB ${NB_VERSION}"
info "Freeze branch: ${FREEZE_BRANCH}"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[[ "$CURRENT_BRANCH" == "develop" ]] || \
    die "Must be on 'develop' branch (currently on '$CURRENT_BRANCH'). Run: git checkout develop"

if ! git diff --quiet || ! git diff --cached --quiet; then
    die "Working tree is not clean. Commit or stash your changes first."
fi

if ! git ls-remote --exit-code origin "$FREEZE_BRANCH" >/dev/null 2>&1; then
    die "Remote branch '$FREEZE_BRANCH' does not exist. Nothing to unfreeze."
fi

info "Fetching from remote..."
git fetch origin --quiet --prune

# ---------------------------------------------------------------------------
# Cherry-pick check (un-cherry-picked commits on freeze branch)
# ---------------------------------------------------------------------------
# Freeze metadata commits (.msp-freeze-state.json, .msp-freeze-notice.md) live
# only on the freeze branch by design — they record freeze ceremony, never
# meant to land on develop. We exclude commits whose ONLY changed files are
# in that metadata set; everything else (real bugfixes) must be cherry-picked.
info "Checking for un-cherry-picked commits..."

UNPICKED="$(FREEZE_BRANCH="$FREEZE_BRANCH" python3 - <<'PY'
import os, subprocess, sys

freeze_branch = os.environ["FREEZE_BRANCH"]
metadata_files = {".msp-freeze-state.json", ".msp-freeze-notice.md"}

cherry = subprocess.run(
    ["git", "cherry", "origin/develop", f"origin/{freeze_branch}"],
    capture_output=True, text=True, check=True,
)

for line in cherry.stdout.splitlines():
    if not line.startswith("+"):
        continue
    parts = line.split()
    if len(parts) < 2:
        continue
    sha = parts[1]
    files_proc = subprocess.run(
        ["git", "show", "--name-only", "--format=", sha],
        capture_output=True, text=True, check=True,
    )
    files = {f.strip() for f in files_proc.stdout.splitlines() if f.strip()}
    # Skip metadata-only commits AND empty commits; neither needs cherry-pick.
    # `files - metadata_files` is empty iff every changed file (if any) is
    # metadata, which covers both cases.
    if not (files - metadata_files):
        continue
    sys.stdout.write(line + "\n")
PY
)"

if [[ -n "$UNPICKED" ]]; then
    echo ""
    warn "The following commits on ${FREEZE_BRANCH} have NOT been cherry-picked to develop:"
    echo ""
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        hash="$(echo "$line" | awk '{print $2}')"
        subject="$(git log --format="%s" -1 "$hash" 2>/dev/null || echo "(unknown)")"
        echo -e "  ${YELLOW}+${NC} $hash  $subject"
    done <<< "$UNPICKED"
    echo ""
    die "Cherry-pick these commits to develop via PR before re-running unfreeze:\n\n  git checkout develop && git pull origin develop\n  git checkout -b chore/cherry-pick-<short-hash>\n  git cherry-pick <commit-hash>\n  git push -u origin chore/cherry-pick-<short-hash>\n  gh pr create --base develop --fill\n  # After PR merges to develop:\n  make unfreeze NB_VERSION=${NB_VERSION}\n\n(develop is branch-protected; do NOT push directly.)"
fi

success "All commits are already in develop (metadata-only freeze commits ignored). Cherry-pick check passed."

# ---------------------------------------------------------------------------
# Update state JSON on freeze branch (status -> closed) — only if retaining
# ---------------------------------------------------------------------------
if [[ "$DELETE_BRANCH" -eq 0 ]]; then
    info "Marking state on ${FREEZE_BRANCH} as closed..."

    # Ensure local branch exists and is in sync with remote.
    # The local-ahead path handles recovery from a previous failed push of a
    # close-state metadata commit. CRITICAL: we must NOT silently push
    # arbitrary local-ahead commits — if the local freeze branch has un-pushed
    # bugfix commits, those would land on remote without going through the
    # cherry-pick check (which runs against origin). Gate the recovery push
    # on "all local-ahead commits are metadata-only".
    if git show-ref --verify --quiet "refs/heads/$FREEZE_BRANCH"; then
        git checkout "$FREEZE_BRANCH" --quiet
        local_sha="$(git rev-parse "$FREEZE_BRANCH")"
        remote_sha="$(git rev-parse "origin/$FREEZE_BRANCH")"
        if [[ "$local_sha" != "$remote_sha" ]]; then
            base_sha="$(git merge-base "$FREEZE_BRANCH" "origin/$FREEZE_BRANCH")"
            if [[ "$remote_sha" == "$base_sha" ]]; then
                # Local ahead — verify ahead commits are all freeze-metadata
                NON_META_AHEAD="$(FREEZE_BRANCH="$FREEZE_BRANCH" python3 - <<'PY'
import os, subprocess
freeze_branch = os.environ["FREEZE_BRANCH"]
metadata_files = {".msp-freeze-state.json", ".msp-freeze-notice.md"}
proc = subprocess.run(
    ["git", "log", f"origin/{freeze_branch}..{freeze_branch}", "--format=%H"],
    capture_output=True, text=True, check=True,
)
for sha in proc.stdout.split():
    if not sha:
        continue
    files_proc = subprocess.run(
        ["git", "show", "--name-only", "--format=", sha],
        capture_output=True, text=True, check=True,
    )
    files = {f.strip() for f in files_proc.stdout.splitlines() if f.strip()}
    if files - metadata_files:
        print(sha)
PY
)"
                if [[ -n "$NON_META_AHEAD" ]]; then
                    echo ""
                    warn "Local ${FREEZE_BRANCH} has commits ahead of origin that touch non-metadata files:"
                    echo ""
                    while IFS= read -r sha; do
                        [[ -z "$sha" ]] && continue
                        subject="$(git log -1 --format=%s "$sha" 2>/dev/null || echo "(unknown)")"
                        echo -e "  ${YELLOW}+${NC} $sha  $subject"
                    done <<< "$NON_META_AHEAD"
                    echo ""
                    git checkout develop --quiet
                    die "These un-pushed commits would bypass the cherry-pick check.\nPush them to origin/${FREEZE_BRANCH} via PR (or revert locally) before re-running unfreeze."
                fi
                info "Local ${FREEZE_BRANCH} is ahead with metadata-only commits — recovering from previous failed push..."
                git push origin "$FREEZE_BRANCH"
            elif [[ "$local_sha" == "$base_sha" ]]; then
                git pull origin "$FREEZE_BRANCH" --ff-only --quiet
            else
                git checkout develop --quiet
                die "Local ${FREEZE_BRANCH} has diverged from origin. Resolve manually then re-run unfreeze."
            fi
        fi
    else
        git checkout -b "$FREEZE_BRANCH" "origin/$FREEZE_BRANCH" --quiet
    fi

    if [[ ! -f "$STATE_FILENAME" ]]; then
        warn "State file ${STATE_FILENAME} not found on ${FREEZE_BRANCH} — skipping status update (likely a legacy freeze)."
    else
        CLOSED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        set +e
        STATE_PATH="$ROOT_DIR/$STATE_FILENAME" \
        CLOSED_AT="$CLOSED_AT" \
        python3 - 2>/dev/null <<'PY'
import json, os, sys
path = os.environ["STATE_PATH"]
try:
    with open(path, "r") as f:
        state = json.load(f)
except json.JSONDecodeError:
    sys.exit(2)
except OSError:
    sys.exit(3)

# Idempotency: never re-stamp closed_at on an already-closed state.
# Re-running unfreeze should be a no-op once the cycle is closed.
# Only write the file when there is a real change to commit.
write_needed = False
if state.get("status") != "closed":
    state["status"] = "closed"
    state["closed_at"] = os.environ["CLOSED_AT"]
    write_needed = True
elif "closed_at" not in state:
    # Already closed but timestamp missing (legacy / partially written).
    # Backfill once and stop.
    state["closed_at"] = os.environ["CLOSED_AT"]
    write_needed = True

if write_needed:
    with open(path, "w") as f:
        json.dump(state, f, indent=2)
        f.write("\n")
PY
        STATE_RC=$?
        set -e
        case "$STATE_RC" in
            0) ;;
            2) git checkout develop --quiet
               die "State file on ${FREEZE_BRANCH} is not valid JSON. Edit it manually on that branch and push, then re-run unfreeze." ;;
            3) git checkout develop --quiet
               die "Could not read state file on ${FREEZE_BRANCH}. Permissions or filesystem issue?" ;;
            *) git checkout develop --quiet
               die "State file update failed (rc=${STATE_RC})." ;;
        esac

        if git diff --quiet "$STATE_FILENAME"; then
            info "State already marked closed. Nothing to commit."
        else
            git add "$STATE_FILENAME"
            git commit -m "chore(freeze): close NB ${NB_VERSION} freeze cycle"
            git push origin "$FREEZE_BRANCH"
            success "State on ${FREEZE_BRANCH} updated to status=closed."
        fi
    fi

    git checkout develop --quiet
fi

# ---------------------------------------------------------------------------
# Branch retention vs deletion
# ---------------------------------------------------------------------------
if [[ "$DELETE_BRANCH" -eq 1 ]]; then
    info "Deleting remote branch ${FREEZE_BRANCH}..."
    git push origin --delete "$FREEZE_BRANCH"

    if git show-ref --verify --quiet "refs/heads/$FREEZE_BRANCH"; then
        info "Deleting local branch ${FREEZE_BRANCH}..."
        git branch -D "$FREEZE_BRANCH"
    fi

    success "Branch ${FREEZE_BRANCH} deleted (remote + local)."
else
    info "Retaining ${FREEZE_BRANCH} for future diff/audit (default behavior)."
    info "Pass DELETE_BRANCH=1 to delete instead."
fi

# ---------------------------------------------------------------------------
# Cleanup any stale local state file (legacy from freeze.sh v1)
# ---------------------------------------------------------------------------
if [[ -f "$ROOT_DIR/$STATE_FILENAME" ]]; then
    rm "$ROOT_DIR/$STATE_FILENAME"
    info "Removed legacy local state file."
fi

echo ""
success "Unfreeze complete. develop is the active branch."
echo ""
echo "  Next freeze: make freeze NB_VERSION=<next-nb-version>"
echo ""
