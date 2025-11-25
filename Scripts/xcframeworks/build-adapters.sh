#!/bin/bash
# ============================================================================
# XCFramework Builder for Adapter Modules
# ============================================================================
# Purpose: Build all adapter modules into XCFrameworks
# Usage:   ./Scripts/xcframeworks/build-adapters.sh
# ============================================================================

set -euo pipefail

# Source common functions
XCFRAMEWORKS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$XCFRAMEWORKS_SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/target-switching/common.sh
source "$XCFRAMEWORKS_SCRIPT_DIR/../target-switching/common.sh"

ensure_repo_root

BUILD_MODULE_SCRIPT="$XCFRAMEWORKS_SCRIPT_DIR/build_module.sh"
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

# Core XCFrameworks that adapters depend on
CORE_XCFRAMEWORKS=(
    "MSPiOSCore"
    "NovaCore"
    "MSPSharedLibraries"
)

# Third-party XCFrameworks
THIRDPARTY_XCFRAMEWORKS=(
    "Sources/Core/ThirdParty/Kingfisher/Kingfisher.xcframework"
    "Sources/Core/ThirdParty/SnapKit/SnapKit.xcframework"
    "Sources/Core/ThirdParty/Lottie/Lottie.xcframework"
    "Sources/Core/ThirdParty/Shimmer/Shimmer.xcframework"
    "Sources/Core/ThirdParty/SwiftProtobuf/SwiftProtobuf.xcframework"
    "Sources/Core/MSPOMSDK/OMSDK_Newsbreak1.xcframework"
    "Sources/Core/MSPSharedLibraries/PrebidMobile.xcframework"
)

# Check core XCFrameworks exist
log_section "Checking core XCFrameworks"
for framework in "${CORE_XCFRAMEWORKS[@]}"; do
    XCFRAMEWORK_PATH="$ROOT_DIR/Build/XCFrameworks/$framework.xcframework"
    if [[ ! -d "$XCFRAMEWORK_PATH" ]]; then
        log_error "Core XCFramework not found: $XCFRAMEWORK_PATH"
        log_info "Please run ./Scripts/xcframeworks/build-core.sh first"
        exit 1
    else
        log_success "Found: $framework.xcframework"
    fi
done

# Check third-party XCFrameworks exist
log_section "Checking third-party XCFrameworks"
for framework_path in "${THIRDPARTY_XCFRAMEWORKS[@]}"; do
    FULL_PATH="$ROOT_DIR/$framework_path"
    if [[ ! -d "$FULL_PATH" ]]; then
        log_error "Third-party XCFramework not found: $FULL_PATH"
        exit 1
    else
        FRAMEWORK_NAME=$(basename "$framework_path")
        log_success "Found: $FRAMEWORK_NAME"
    fi
done

SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_MODULES=()

for module in "${ADAPTER_MODULES[@]}"; do
    log_section "Building $module"
    
    # Determine PRODUCT_NAME
    PRODUCT_NAME="$module"
    if [[ "$module" == "PrebidAdapter" ]]; then
        PRODUCT_NAME="MSPPrebidAdapter"
    fi
    
    # For Round 3, force rebuild all adapters to use new build system
    # Remove existing XCFramework to ensure fresh build with new pipeline
    XCFRAMEWORK_OUTPUT="$ROOT_DIR/Build/XCFrameworks/$PRODUCT_NAME.xcframework"
    if [[ -d "$XCFRAMEWORK_OUTPUT" ]]; then
        log_info "Removing existing $PRODUCT_NAME.xcframework for fresh rebuild..."
        rm -rf "$XCFRAMEWORK_OUTPUT"
    fi
    
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
