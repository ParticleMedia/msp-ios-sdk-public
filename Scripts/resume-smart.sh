#!/usr/bin/env bash
# ============================================================================
# MSP Smart Resume - Auto-switch branch and resume release
# ============================================================================
# Purpose: Automatically detect version, switch to release branch, set
#          environment variables, and resume release
#
# Usage:
#   ./Scripts/resume-smart.sh
#
# Features:
#   - Auto-detect version from state file
#   - Auto-switch to release branch (even if not currently on it)
#   - Auto-set environment variables (using setup-release-env.sh)
#   - Resume release with all fixes in place
# ============================================================================

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

log_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# ============================================================================
# Step 1: Detect version from state file
# ============================================================================
log_section "🔍 Detecting Resume Information"

STATE_FILE=$(ls -t ~/.msp-state/release-*.json 2>/dev/null | head -1)

if [[ ! -f "$STATE_FILE" ]]; then
    log_error "No resume state file found"
    log_info "Expected location: ~/.msp-state/release-*.json"
    log_info ""
    log_info "This script is used to resume a failed release."
    log_info "If you want to start a new release, use:"
    log_info "  ./Scripts/msp-release.sh --version X.Y.Z"
    exit 1
fi

VERSION=$(basename "$STATE_FILE" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9.]+)?')

if [[ -z "$VERSION" ]]; then
    log_error "Failed to parse version from state file: $STATE_FILE"
    exit 1
fi

log_info "Resume Information:"
echo "   Version:     $VERSION"
echo "   State File:  $STATE_FILE"
echo ""

# ============================================================================
# Step 2: Check and switch to release branch
# ============================================================================
log_section "🔀 Ensuring Correct Branch"

RELEASE_BRANCH="release/$VERSION"
CURRENT_BRANCH=$(git branch --show-current)

log_info "Current Branch:  $CURRENT_BRANCH"
log_info "Target Branch:   $RELEASE_BRANCH"
echo ""

if [[ "$CURRENT_BRANCH" != "$RELEASE_BRANCH" ]]; then
    log_warning "Not on release branch, switching..."

    # Check if release branch exists
    if git show-ref --verify --quiet "refs/heads/$RELEASE_BRANCH"; then
        git checkout "$RELEASE_BRANCH"
        log_success "Switched to $RELEASE_BRANCH"
    else
        log_error "Release branch does not exist: $RELEASE_BRANCH"
        log_info ""
        log_info "Available branches:"
        git branch -a | grep -E "release/|feature/"
        exit 1
    fi
else
    log_success "Already on correct branch: $RELEASE_BRANCH"
fi

echo ""

# ============================================================================
# Step 3: Set environment variables
# ============================================================================
log_section "⚙️  Setting Environment Variables"

if [[ -z "${MSP_RELEASE_TIER:-}" ]]; then
    log_info "Environment not configured, setting up..."

    if [[ -f "$SCRIPT_DIR/utils/setup-release-env.sh" ]]; then
        # Use resume profile if available, otherwise use local
        if grep -q "setup_resume_profile" "$SCRIPT_DIR/utils/setup-release-env.sh" 2>/dev/null; then
            log_info "Using 'resume' profile"
            source "$SCRIPT_DIR/utils/setup-release-env.sh" resume
        else
            log_info "Using 'local' profile (resume profile not available)"
            source "$SCRIPT_DIR/utils/setup-release-env.sh" local

            # Manually add resume-specific settings
            export MSP_ALLOW_EXISTING_TAG=1
            log_info "Added: MSP_ALLOW_EXISTING_TAG=1 (for resume)"
        fi
    else
        log_error "setup-release-env.sh not found"
        exit 1
    fi
else
    log_success "Environment already configured"
    log_info "MSP_RELEASE_TIER: ${MSP_RELEASE_TIER}"
fi

echo ""

# ============================================================================
# Step 4: Show configuration summary
# ============================================================================
log_section "📋 Configuration Summary"

echo "Branch:      $RELEASE_BRANCH"
echo "Version:     $VERSION"
echo "State File:  $STATE_FILE"
echo ""
echo "Environment Variables:"
echo "  MSP_RELEASE_TIER:          ${MSP_RELEASE_TIER:-<not set>}"
echo "  MSP_ALLOW_LOCAL_RELEASE:   ${MSP_ALLOW_LOCAL_RELEASE:-<not set>}"
echo "  MSP_ALLOW_EXISTING_TAG:    ${MSP_ALLOW_EXISTING_TAG:-<not set>}"
echo "  MSP_ALLOW_TRUNK_PUSH:      ${MSP_ALLOW_TRUNK_PUSH:-<not set>}"
echo "  MSP_SLACK_ALERT_ENV:       ${MSP_SLACK_ALERT_ENV:-<not set>}"
echo "  MSP_SPM_ENABLED:           ${MSP_SPM_ENABLED:-<not set>}"
echo ""

# ============================================================================
# Step 5: Confirm and resume
# ============================================================================
log_section "🚀 Ready to Resume"

echo "This will resume the release from where it failed."
echo ""
echo "Press Enter to continue, or Ctrl+C to cancel..."
read -r

log_info "Starting resume..."
echo ""

# Execute resume
exec "$SCRIPT_DIR/msp-release.sh" resume

