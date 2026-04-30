#!/usr/bin/env bash
# ============================================================================
# MSP iOS SDK — Code Freeze Script
# ============================================================================
# Usage: ./Scripts/freeze.sh NB_VERSION=26.18.0
#    or: make freeze NB_VERSION=26.18.0
#
# Creates freeze/nb-{NB_VERSION} from develop and pushes to remote.
# Writes .msp-freeze-state.json for unfreeze to consume.
# ============================================================================
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
STATE_FILE="$ROOT_DIR/.msp-freeze-state.json"

# ---------------------------------------------------------------------------
# Parse NB_VERSION from args (supports both NB_VERSION=x.y.z and positional)
# ---------------------------------------------------------------------------
NB_VERSION=""
for arg in "$@"; do
    case "$arg" in
        NB_VERSION=*) NB_VERSION="${arg#NB_VERSION=}" ;;
        *)            [[ -z "$NB_VERSION" ]] && NB_VERSION="$arg" ;;
    esac
done

# ---------------------------------------------------------------------------
# Colors
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
[[ -z "$NB_VERSION" ]] && die "NB_VERSION is required. Usage: make freeze NB_VERSION=26.18.0"

FREEZE_BRANCH="freeze/nb-${NB_VERSION}"

info "Starting code freeze for NB ${NB_VERSION}"
info "Freeze branch: ${FREEZE_BRANCH}"

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
# Working tree must be clean
if ! git diff --quiet || ! git diff --cached --quiet; then
    die "Working tree is not clean. Commit or stash your changes first."
fi

# Must be on develop
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$CURRENT_BRANCH" != "develop" ]]; then
    die "Must be on 'develop' branch (currently on '$CURRENT_BRANCH')."
fi

# Freeze branch must not already exist
if git show-ref --verify --quiet "refs/heads/$FREEZE_BRANCH" || \
   git ls-remote --exit-code origin "$FREEZE_BRANCH" >/dev/null 2>&1; then
    die "Branch '$FREEZE_BRANCH' already exists. If this is a leftover from a previous freeze, run:\n  git branch -d $FREEZE_BRANCH\n  git push origin --delete $FREEZE_BRANCH\nThen re-run make freeze."
fi

# No active freeze state
if [[ -f "$STATE_FILE" ]]; then
    existing_nb="$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('nb_version',''))" 2>/dev/null || true)"
    existing_branch="$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('freeze_branch',''))" 2>/dev/null || true)"
    [[ -n "$existing_nb" ]] && die "An active freeze state exists for NB ${existing_nb} (branch: ${existing_branch}).\nRun 'make unfreeze NB_VERSION=${existing_nb}' to clean up first."
fi

# ---------------------------------------------------------------------------
# Pull latest develop
# ---------------------------------------------------------------------------
info "Pulling latest develop..."
git pull origin develop

# ---------------------------------------------------------------------------
# Create and push freeze branch
# ---------------------------------------------------------------------------
info "Creating ${FREEZE_BRANCH}..."
git checkout -b "$FREEZE_BRANCH"
git push -u origin "$FREEZE_BRANCH"
info "Branch pushed to remote."

# Switch back to develop so developers aren't left on the freeze branch
git checkout develop

# ---------------------------------------------------------------------------
# Write state file
# ---------------------------------------------------------------------------
FREEZE_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
FROZEN_BY="$(git config user.name 2>/dev/null || echo "unknown")"

python3 - <<EOF
import json, os
state = {
    "schema_version": 1,
    "nb_version": "${NB_VERSION}",
    "freeze_branch": "${FREEZE_BRANCH}",
    "frozen_at": "${FREEZE_TIME}",
    "frozen_by": "${FROZEN_BY}"
}
with open("${STATE_FILE}", "w") as f:
    json.dump(state, f, indent=2)
    f.write("\n")
print("State written to ${STATE_FILE}")
EOF

# ---------------------------------------------------------------------------
# Print notification template
# ---------------------------------------------------------------------------
RELEASE_DATE="$(python3 -c "
from datetime import datetime, timedelta
today = datetime.utcnow()
days_until_tuesday = (1 - today.weekday()) % 7
if days_until_tuesday == 0:
    days_until_tuesday = 7
release_day = today + timedelta(days=days_until_tuesday)
print(release_day.strftime('%Y-%m-%d'))
" 2>/dev/null || echo "TBD")"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  SDK Code Freeze (NB ${NB_VERSION})"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Release branch: ${FREEZE_BRANCH}"
echo "  Freeze time:    ${FREEZE_TIME}"
echo "  Planned release: ${RELEASE_DATE} (Tuesday)"
echo ""
echo "  Bugfixes → PR to ${FREEZE_BRANCH}"
echo "  New features → continue merging to develop"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
success "Code freeze complete. You are back on 'develop'."
