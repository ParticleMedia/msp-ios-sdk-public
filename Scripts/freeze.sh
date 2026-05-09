#!/usr/bin/env bash
# ============================================================================
# MSP iOS SDK — Code Freeze Script
# ============================================================================
# Usage: ./Scripts/freeze.sh NB_VERSION=26.18.0 [RELEASE_DATE=YYYY-MM-DD]
#    or: make freeze NB_VERSION=26.18.0 [RELEASE_DATE=YYYY-MM-DD]
#
# Creates freeze/nb-{NB_VERSION} from develop and commits .msp-freeze-state.json
# ON the freeze branch (single source of truth, schema v2). Posts a Slack
# announcement when MSP_FREEZE_SLACK_WEBHOOK_URL is configured (typically via
# Scripts/config/slack.conf, gitignored).
#
# Pre-flight requirements (no auto-fix; abort with explicit guidance):
#   - Currently on develop
#   - Working tree clean (no staged or unstaged changes)
#   - Local develop exactly matches origin/develop
#
# RELEASE_DATE defaults to next Tuesday when not supplied. The skill that
# wraps this script (freeze-cycle.skill.md) MUST confirm both NB_VERSION and
# RELEASE_DATE with the user before invoking.
# ============================================================================
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Error: not inside a git repository. Run from the msp-ios-sdk checkout." >&2
    exit 1
}
# All file ops that follow assume cwd == repo root (for `git add` of relative
# paths, etc.). Anchor here so the script behaves identically whether invoked
# from repo root, Scripts/, or any other subdirectory.
cd "$ROOT_DIR"

STATE_FILENAME=".msp-freeze-state.json"
NOTICE_FILENAME=".msp-freeze-notice.md"
SLACK_CONF="$ROOT_DIR/Scripts/config/slack.conf"

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
NB_VERSION=""
RELEASE_DATE=""
for arg in "$@"; do
    case "$arg" in
        NB_VERSION=*)   NB_VERSION="${arg#NB_VERSION=}" ;;
        RELEASE_DATE=*) RELEASE_DATE="${arg#RELEASE_DATE=}" ;;
        *)              [[ -z "$NB_VERSION" ]] && NB_VERSION="$arg" ;;
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

info()    { echo -e "${CYAN}[freeze]${NC} $*"; }
success() { echo -e "${GREEN}[freeze]${NC} $*"; }
warn()    { echo -e "${YELLOW}[freeze]${NC} $*"; }
die()     { echo -e "${RED}[freeze] ERROR:${NC} $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Validate inputs
# ---------------------------------------------------------------------------
[[ -z "$NB_VERSION" ]] && die "NB_VERSION is required. Usage: make freeze NB_VERSION=26.18.0 [RELEASE_DATE=YYYY-MM-DD]"

# Layer 1 — project conventions. git would accept these as valid refs but we
# don't want them (nested freeze paths, flag-like inputs, dotfile-style).
if [[ "$NB_VERSION" =~ [[:space:]/] ]] \
    || [[ "$NB_VERSION" == .* ]] \
    || [[ "$NB_VERSION" == -* ]]; then
    die "NB_VERSION contains invalid characters. Use semver-like format (e.g., 26.18.0). Got: $NB_VERSION"
fi

FREEZE_BRANCH="freeze/nb-${NB_VERSION}"

# Layer 2 — authoritative git ref-name check. Catches `:`, `..`, trailing `.`,
# `@{...}`, control chars, etc. before any git command produces a raw
# "fatal: ..." message the user has to decode.
if ! git check-ref-format --branch "$FREEZE_BRANCH" >/dev/null 2>&1; then
    die "NB_VERSION '$NB_VERSION' would produce an invalid git branch name ('$FREEZE_BRANCH'). Use semver-like format (e.g., 26.18.0)."
fi

info "Starting code freeze for NB ${NB_VERSION}"
info "Freeze branch: ${FREEZE_BRANCH}"

# ---------------------------------------------------------------------------
# Pre-flight checks (no auto-fix; explicit fix instructions on failure)
# ---------------------------------------------------------------------------
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[[ "$CURRENT_BRANCH" == "develop" ]] || \
    die "Must be on 'develop' branch (currently on '$CURRENT_BRANCH')."

if ! git diff --quiet || ! git diff --cached --quiet; then
    die "Working tree is not clean. Commit or stash your changes first."
fi

info "Fetching origin/develop to verify sync state..."
git fetch origin develop --quiet

LOCAL_SHA="$(git rev-parse develop)"
REMOTE_SHA="$(git rev-parse origin/develop)"

if [[ "$LOCAL_SHA" != "$REMOTE_SHA" ]]; then
    BASE_SHA="$(git merge-base develop origin/develop)"
    if [[ "$LOCAL_SHA" == "$BASE_SHA" ]]; then
        die "Local develop is BEHIND origin/develop. Run: git pull origin develop"
    elif [[ "$REMOTE_SHA" == "$BASE_SHA" ]]; then
        die "Local develop is AHEAD of origin/develop. Push your commits via PR before freezing."
    else
        die "Local develop has DIVERGED from origin/develop. Resolve manually before freezing."
    fi
fi

if git show-ref --verify --quiet "refs/heads/$FREEZE_BRANCH" || \
   git ls-remote --exit-code origin "$FREEZE_BRANCH" >/dev/null 2>&1; then
    die "Branch '$FREEZE_BRANCH' already exists. If stale, delete first:\n  git branch -D $FREEZE_BRANCH 2>/dev/null || true\n  git push origin --delete $FREEZE_BRANCH"
fi

success "Pre-flight checks passed (develop in sync with origin)."

# ---------------------------------------------------------------------------
# Load Slack config (optional)
# ---------------------------------------------------------------------------
MSP_FREEZE_SLACK_WEBHOOK_URL="${MSP_FREEZE_SLACK_WEBHOOK_URL:-}"
MSP_SLACK_HANDLE="${MSP_SLACK_HANDLE:-}"
MSP_SLACK_USER_ID="${MSP_SLACK_USER_ID:-}"
if [[ -f "$SLACK_CONF" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$SLACK_CONF"
    set +a
fi

# ---------------------------------------------------------------------------
# Resolve and validate RELEASE_DATE
# ---------------------------------------------------------------------------
if [[ -z "$RELEASE_DATE" ]]; then
    # Use local time; calendar concept of "next Tuesday" is not UTC.
    # Python weekday(): Mon=0, Tue=1, ..., Sun=6
    RELEASE_DATE="$(python3 - <<'PY'
from datetime import datetime, timedelta
today = datetime.now()
days = (1 - today.weekday()) % 7
if days == 0:
    days = 7
print((today + timedelta(days=days)).strftime("%Y-%m-%d"))
PY
)"
    warn "RELEASE_DATE not provided -- defaulted to next Tuesday: ${RELEASE_DATE}"
    warn "Confirm this is correct. Pass RELEASE_DATE=YYYY-MM-DD explicitly to override."
fi

set +e
# We only need the exit code as a signal; redirect stderr so the internal
# diagnostic markers (invalid_format / past_date) do not leak to the user.
RELEASE_WEEKDAY="$(RELEASE_DATE="$RELEASE_DATE" python3 - 2>/dev/null <<'PY'
import os, sys
from datetime import datetime
rd = os.environ.get("RELEASE_DATE", "")
try:
    d = datetime.strptime(rd, "%Y-%m-%d").date()
except ValueError:
    sys.stderr.write("invalid_format\n")
    sys.exit(2)
# Compare against local "today" -- RELEASE_DATE is a calendar-local date.
today = datetime.now().date()
if d < today:
    sys.stderr.write("past_date\n")
    sys.exit(3)
print(d.strftime("%A"))
PY
)"
RELEASE_RC=$?
set -e

case "$RELEASE_RC" in
    0) ;;
    2) die "RELEASE_DATE must be in YYYY-MM-DD format. Got: ${RELEASE_DATE}" ;;
    3) die "RELEASE_DATE (${RELEASE_DATE}) is in the past. Pick today or a future date." ;;
    *) die "RELEASE_DATE validation failed (rc=${RELEASE_RC})." ;;
esac

# ---------------------------------------------------------------------------
# Create freeze branch and commit state file ON IT
# ---------------------------------------------------------------------------
DEVELOP_SHA="$LOCAL_SHA"
FREEZE_TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
FREEZE_DATE="${FREEZE_TIMESTAMP%%T*}"
FROZEN_BY="$(git config user.name 2>/dev/null || echo "unknown")"

# If we abort after creating/checking-out the freeze branch but before getting
# back to develop, restore develop so the user isn't stranded on the freeze
# branch with cryptic state.
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

info "Creating ${FREEZE_BRANCH} from develop @ ${DEVELOP_SHA:0:8}..."
git checkout -b "$FREEZE_BRANCH"

STATE_PATH="$ROOT_DIR/$STATE_FILENAME"
NB_VERSION="$NB_VERSION" \
FREEZE_BRANCH="$FREEZE_BRANCH" \
FREEZE_TIMESTAMP="$FREEZE_TIMESTAMP" \
FROZEN_BY="$FROZEN_BY" \
DEVELOP_SHA="$DEVELOP_SHA" \
RELEASE_DATE="$RELEASE_DATE" \
STATE_PATH="$STATE_PATH" \
python3 - <<'PY'
import json, os
state = {
    "schema_version": 2,
    "nb_version": os.environ["NB_VERSION"],
    "freeze_branch": os.environ["FREEZE_BRANCH"],
    "frozen_at": os.environ["FREEZE_TIMESTAMP"],
    "frozen_by": os.environ["FROZEN_BY"],
    "develop_sha_at_freeze": os.environ["DEVELOP_SHA"],
    "planned_release_date": os.environ["RELEASE_DATE"],
    "status": "active",
}
with open(os.environ["STATE_PATH"], "w") as f:
    json.dump(state, f, indent=2)
    f.write("\n")
PY

# State file is gitignored on develop as a safety net; force-add for first commit.
git add -f "$STATE_FILENAME"
git commit -m "chore(freeze): record freeze state for NB ${NB_VERSION}"
git push -u origin "$FREEZE_BRANCH"

git checkout develop --quiet
success "Branch ${FREEZE_BRANCH} created and pushed; back on develop."

# ---------------------------------------------------------------------------
# Compose Slack notice (mrkdwn) and write a local archive copy
# ---------------------------------------------------------------------------
DISPLAY_HANDLE="${MSP_SLACK_HANDLE:-$FROZEN_BY}"
if [[ -n "$MSP_SLACK_USER_ID" ]]; then
    REACH_OUT_TARGET="<@${MSP_SLACK_USER_ID}>"
else
    REACH_OUT_TARGET="${DISPLAY_HANDLE}"
fi

NOTICE_PATH="$ROOT_DIR/$NOTICE_FILENAME"
cat > "$NOTICE_PATH" <<EOF
:snowflake: *MSP iOS SDK — Code Freeze for NB ${NB_VERSION}*

The SDK has been frozen for the *NB ${NB_VERSION}* release.

*Freeze branch:* \`${FREEZE_BRANCH}\`
*Frozen at:* ${FREEZE_DATE}
*Planned release:* ${RELEASE_DATE} (${RELEASE_WEEKDAY})

*What this means*
• *Bugfixes for this release* → open PR targeting \`${FREEZE_BRANCH}\`, then cherry-pick to \`develop\`
• *New features / unrelated work* → continue merging to \`develop\` as usual
• *Jenkins release build* → select \`${FREEZE_BRANCH}\` branch

Please do *not* merge feature work into \`${FREEZE_BRANCH}\`.
Reach out to ${REACH_OUT_TARGET} if you have a fix that needs to land in this release.
EOF

info "Notice written to ${NOTICE_PATH}"

# ---------------------------------------------------------------------------
# Send to Slack if a webhook is configured
# ---------------------------------------------------------------------------
if [[ -n "$MSP_FREEZE_SLACK_WEBHOOK_URL" ]]; then
    info "Posting freeze announcement to Slack..."
    PAYLOAD="$(NOTICE_PATH="$NOTICE_PATH" python3 - <<'PY'
import json, os
with open(os.environ["NOTICE_PATH"], "r") as f:
    text = f.read()
print(json.dumps({"text": text, "mrkdwn": True}))
PY
)"
    # Capture body and HTTP status separately so success detection is robust
    # to verbose stderr from curl (DNS errors, redirects, etc.). Stderr is
    # discarded to avoid leaking the webhook URL into terminal logs.
    SLACK_RESP="$(curl -s -o /dev/stdout -w $'\n%{http_code}' \
        -X POST -H 'Content-type: application/json' \
        --data "$PAYLOAD" "$MSP_FREEZE_SLACK_WEBHOOK_URL" 2>/dev/null || true)"
    SLACK_STATUS="${SLACK_RESP##*$'\n'}"
    SLACK_BODY="${SLACK_RESP%$'\n'*}"
    # Trim any trailing whitespace/newline from the body — Slack currently
    # returns plain "ok" but be defensive against future format changes.
    SLACK_BODY="${SLACK_BODY%"${SLACK_BODY##*[![:space:]]}"}"
    if [[ "$SLACK_STATUS" == "200" ]] && [[ "$SLACK_BODY" == "ok" ]]; then
        success "Slack announcement posted."
    else
        warn "Slack post failed (HTTP ${SLACK_STATUS:-?}, body: ${SLACK_BODY:-empty})."
        warn "Notice file ready at: ${NOTICE_PATH} (copy/paste manually)."
    fi
else
    warn "MSP_FREEZE_SLACK_WEBHOOK_URL not set — skipped Slack post."
    warn "Copy the notice from: ${NOTICE_PATH}"
fi

# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  SDK Code Freeze (NB ${NB_VERSION})"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Release branch:  ${FREEZE_BRANCH}"
echo "  Develop SHA:     ${DEVELOP_SHA:0:12}"
echo "  Frozen at:       ${FREEZE_DATE}"
echo "  Planned release: ${RELEASE_DATE} (${RELEASE_WEEKDAY})"
echo "  Notice file:     ${NOTICE_FILENAME}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
success "Code freeze complete."
