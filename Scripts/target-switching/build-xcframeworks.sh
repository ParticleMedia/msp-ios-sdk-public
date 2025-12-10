#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch K, shared) ---
# shellcheck source=/dev/null
if command -v git >/dev/null 2>&1; then
  MSP_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$MSP_REPO_ROOT" ] && [ -f "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh" ]; then
    # shellcheck source=/dev/null
    . "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh"
    msp_enforce_main_repo_or_exit
  fi
fi
# --- End MSP Worktree Safety Guard (Patch K, shared) ---
# ============================================================================
# Build All XCFrameworks
# ============================================================================
# Purpose: Wrapper script to build all wrapper xcframeworks.
#
# Usage:   ./Scripts/target-switching/build-xcframeworks.sh
# ============================================================================

set -euo pipefail

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/target-switching/common.sh
source "$SCRIPT_DIR/common.sh"

log_title "Building All XCFrameworks"

# Call the main build-all script
BUILD_SCRIPT="$ROOT_DIR/Scripts/xcframeworks/build-all.sh"

if [[ ! -f "$BUILD_SCRIPT" ]]; then
    log_error "build-all.sh not found: $BUILD_SCRIPT"
    exit 1
fi

log_step "Running build-all.sh"
"$BUILD_SCRIPT"

log_title "Build Complete"
log_success "All xcframeworks built successfully"
