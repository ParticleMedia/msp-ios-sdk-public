#!/usr/bin/env bash
# ============================================================================
# MSP iOS SDK — Code Unfreeze Script
# ============================================================================
# Usage: ./Scripts/unfreeze.sh NB_VERSION=26.18.0 [KEEP_BRANCH=1]
#    or: make unfreeze NB_VERSION=26.18.0 [KEEP_BRANCH=1]
#
# After release:
#   - Checks for un-cherry-picked commits on the freeze branch
#   - If all commits are already in develop: deletes freeze branch (no merge)
#   - If there are missing commits: warns and aborts (must cherry-pick first)
#   - Deletes remote and local freeze branch (unless KEEP_BRANCH=1)
#   - Removes .msp-freeze-state.json
# ============================================================================
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
STATE_FILE="$ROOT_DIR/.msp-freeze-state.json"

# ---------------------------------------------------------------------------
# Parse args (NB_VERSION=x.y.z and KEEP_BRANCH=1)
# ---------------------------------------------------------------------------
NB_VERSION=""
KEEP_BRANCH=0
for arg in "$@"; do
    case "$arg" in
        NB_VERSION=*)  NB_VERSION="${arg#NB_VERSION=}" ;;
        KEEP_BRANCH=1) KEEP_BRANCH=1 ;;
        *)             [[ -z "$NB_VERSION" ]] && NB_VERSION="$arg" ;;
    esac
done

# Fall back to state file if NB_VERSION not provided
if [[ -z "$NB_VERSION" ]] && [[ -f "$STATE_FILE" ]]; then
    NB_VERSION="$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('nb_version',''))" 2>/dev/null || true)"
fi

# ---------------------------------------------------------------------------
# Colors
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
[[ -z "$NB_VERSION" ]] && die "NB_VERSION is required. Usage: make unfreeze NB_VERSION=26.18.0"

FREEZE_BRANCH="freeze/nb-${NB_VERSION}"

info "Starting unfreeze for NB ${NB_VERSION}"
info "Freeze branch: ${FREEZE_BRANCH}"

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
if ! git diff --quiet || ! git diff --cached --quiet; then
    die "Working tree is not clean. Commit or stash your changes first."
fi

# Verify freeze branch exists on remote
if ! git ls-remote --exit-code origin "$FREEZE_BRANCH" >/dev/null 2>&1; then
    die "Remote branch '$FREEZE_BRANCH' does not exist. Nothing to unfreeze."
fi

# ---------------------------------------------------------------------------
# Fetch latest state from remote
# ---------------------------------------------------------------------------
info "Fetching from remote..."
git fetch origin

# ---------------------------------------------------------------------------
# Check for un-cherry-picked commits
# ---------------------------------------------------------------------------
# Find commits on freeze branch not reachable from develop (by patch content)
# git cherry compares patch IDs, so cherry-picks are correctly excluded
info "Checking for un-cherry-picked commits..."

UNPICKED="$(git cherry origin/develop "origin/${FREEZE_BRANCH}" | grep '^+' || true)"

if [[ -n "$UNPICKED" ]]; then
    echo ""
    warn "The following commits on ${FREEZE_BRANCH} have NOT been cherry-picked to develop:"
    echo ""
    git cherry origin/develop "origin/${FREEZE_BRANCH}" | grep '^+' | while read -r _ hash; do
        subject="$(git log --format="%s" -1 "$hash" 2>/dev/null || echo "(unknown)")"
        echo -e "  ${YELLOW}+${NC} $hash  $subject"
    done
    echo ""
    die "Cherry-pick these commits to develop before running unfreeze.\n\n  git checkout develop && git pull origin develop\n  git cherry-pick <commit-hash>\n  git push origin develop\n\nThen re-run: make unfreeze NB_VERSION=${NB_VERSION}"
fi

success "All commits are already in develop. No merge needed."

# ---------------------------------------------------------------------------
# Ensure we are on develop
# ---------------------------------------------------------------------------
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$CURRENT_BRANCH" != "develop" ]]; then
    info "Switching to develop..."
    git checkout develop
fi
git pull origin develop

# ---------------------------------------------------------------------------
# Delete freeze branch
# ---------------------------------------------------------------------------
if [[ "$KEEP_BRANCH" -eq 1 ]]; then
    warn "KEEP_BRANCH=1: skipping branch deletion (branch kept for reference)."
else
    info "Deleting remote branch ${FREEZE_BRANCH}..."
    git push origin --delete "$FREEZE_BRANCH"

    # Delete local branch if it exists
    if git show-ref --verify --quiet "refs/heads/$FREEZE_BRANCH"; then
        info "Deleting local branch ${FREEZE_BRANCH}..."
        git branch -d "$FREEZE_BRANCH"
    fi

    success "Branch ${FREEZE_BRANCH} deleted."
fi

# ---------------------------------------------------------------------------
# Remove state file
# ---------------------------------------------------------------------------
if [[ -f "$STATE_FILE" ]]; then
    rm "$STATE_FILE"
    info "State file removed."
fi

echo ""
success "Unfreeze complete. develop is the active branch."
echo ""
echo "  Next freeze: make freeze NB_VERSION=<next-nb-version>"
echo ""
