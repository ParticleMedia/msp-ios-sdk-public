#!/bin/bash
# ============================================================================
# XCFramework Builder for Adapter Modules
# ============================================================================
# Purpose: Build all adapter modules
# Usage:   ./Scripts/xcframeworks/build-adapters.sh
# ============================================================================

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/target-switching/common.sh
source "$SCRIPT_DIR/../target-switching/common.sh"

ensure_repo_root

BUILD_MODULE_SCRIPT="$SCRIPT_DIR/build_module.sh"
if [[ ! -f "$BUILD_MODULE_SCRIPT" ]]; then
    log_error "build_module.sh not found: $BUILD_MODULE_SCRIPT"
    exit 1
fi

log_title "Building Adapter Modules"

# All adapter modules
ADAPTER_MODULES=(
    "NovaAdapter"
    "PrebidAdapter"
    "MSPGoogleAdapter"
    "MSPFacebookAdapter"
    "InmobiAdapter"
    "MintegralAdapter"
    "MobilefuseAdapter"
    "PubmaticAdapter"
    "UnityAdapter"
    "AmazonAdapter"
)

SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_MODULES=()

for module in "${ADAPTER_MODULES[@]}"; do
    log_section "Building $module"
    
    if "$BUILD_MODULE_SCRIPT" "$module"; then
        ((SUCCESS_COUNT++))
        log_success "$module: BUILD SUCCEEDED"
    else
        ((FAIL_COUNT++))
        FAILED_MODULES+=("$module")
        log_error "$module: BUILD FAILED"
    fi
done

log_title "Adapter Modules Build Complete"
log_success "Successfully built $SUCCESS_COUNT adapter(s)"
if [[ $FAIL_COUNT -gt 0 ]]; then
    log_error "Failed to build $FAIL_COUNT adapter(s): ${FAILED_MODULES[*]}"
    exit 1
fi

