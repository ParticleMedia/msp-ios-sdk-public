#!/usr/bin/env bash
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
