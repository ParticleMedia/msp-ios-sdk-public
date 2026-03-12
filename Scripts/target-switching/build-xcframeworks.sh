#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch M, shared) ---
# shellcheck source=/dev/null
_msp_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$_msp_root" ] && [ -f "$_msp_root/Scripts/lib/worktree_guard.sh" ]; then
  . "$_msp_root/Scripts/lib/worktree_guard.sh"
  msp_enforce_main_repo_or_exit
fi
unset _msp_root
# --- End MSP Worktree Safety Guard (Patch M, shared) ---
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
    log::error "TARGET" "build-all.sh not found: $BUILD_SCRIPT"
    exit 1
fi

log::step "TARGET" "Running build-all.sh"
"$BUILD_SCRIPT"

log_title "Build Complete"
log::success "TARGET" "All xcframeworks built successfully"
