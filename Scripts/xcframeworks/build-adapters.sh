#!/bin/bash
# ============================================================================
# XCFramework Builder for Adapter Modules (OPTIONAL)
# ============================================================================
# Purpose: Build adapter modules into XCFrameworks (for testing only)
#
# IMPORTANT: Adapters are SOURCE-ONLY in all modes (pods-dev, pods-release, spm-release)
#            This script is optional and MUST NOT block any pipeline.
#            All failures are warnings, not errors.
#
# Usage:   ./Scripts/xcframeworks/build-adapters.sh
# ============================================================================

# Note: We use `set -o pipefail` but NOT `set -e` to ensure failures don't exit
set -o pipefail

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

# ============================================================================
# Generate project.yml from templates (Template Architecture)
# ============================================================================
log_section "Generating project.yml from templates"

if [[ -x "$ROOT_DIR/Scripts/target-switching/generate_project_templates.sh" ]]; then
    "$ROOT_DIR/Scripts/target-switching/generate_project_templates.sh"
else
    log_warn "generate_project_templates.sh not found or not executable"
fi

# All adapter modules (including MSPGoogleAdsTypes which is a Common module)
ADAPTER_MODULES=(
    "MSPGoogleAdsTypes"
    "NovaAdapter"
    "MSPPrebidAdapter"
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

# Check core XCFrameworks exist (optional - adapters may work without them in source mode)
log_section "Checking core XCFrameworks (optional for adapter builds)"
CORE_MISSING=0
for framework in "${CORE_XCFRAMEWORKS[@]}"; do
    XCFRAMEWORK_PATH="$ROOT_DIR/Build/XCFrameworks/$framework.xcframework"
    if [[ ! -d "$XCFRAMEWORK_PATH" ]]; then
        log_warn "Core XCFramework not found: $XCFRAMEWORK_PATH (adapter builds may fail)"
        ((CORE_MISSING++)) || true
    else
        log_success "Found: $framework.xcframework"
    fi
done

if [[ $CORE_MISSING -gt 0 ]]; then
    log_warn "$CORE_MISSING core XCFramework(s) missing - adapter builds may fail"
    log_info "To build core modules: ./Scripts/xcframeworks/build-core.sh"
fi

# Third-party dependencies (Kingfisher, SnapKit, etc.) are resolved via CocoaPods
# No need to check for XCFrameworks - the workspace build will find them in Pods/
log_info "Third-party dependencies will be resolved via CocoaPods workspace"

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

# NOTE: Adapters are SOURCE-ONLY in the final architecture.
# This script is for optional testing/validation only.
# Failures are warnings, not errors.

if [[ $SUCCESS_COUNT -gt 0 ]]; then
    log_success "Successfully built $SUCCESS_COUNT adapter(s)"
fi

if [[ $FAIL_COUNT -gt 0 ]]; then
    log_warn "WARNING: $FAIL_COUNT adapter(s) failed to build: ${FAILED_MODULES[*]}"
    log_warn "This is expected - adapters are source-only and don't require XCFrameworks."
    log_warn "Continuing without blocking the pipeline."
fi

# Copy all adapter XCFrameworks to Binary/ directory
log_section "Copying Adapter XCFrameworks to Binary/"
BINARY_DIR="$ROOT_DIR/Binary"
mkdir -p "$BINARY_DIR"

for module in "${ADAPTER_MODULES[@]}"; do
    PRODUCT_NAME="$module"
    XCFRAMEWORK_SRC="$ROOT_DIR/Build/XCFrameworks/$PRODUCT_NAME.xcframework"
    XCFRAMEWORK_DST="$BINARY_DIR/$PRODUCT_NAME.xcframework"
    
    if [[ -d "$XCFRAMEWORK_SRC" ]]; then
        rm -rf "$XCFRAMEWORK_DST"
        cp -R "$XCFRAMEWORK_SRC" "$XCFRAMEWORK_DST"
        log_success "Copied $PRODUCT_NAME.xcframework to Binary/"
    else
        log_warn "Not found: $XCFRAMEWORK_SRC"
    fi
done

log_section "Final Summary"
log_info "Binary/ directory contents:"
ls -1 "$BINARY_DIR" 2>/dev/null | while read -r xcf; do
    log_success "  ✓ $xcf"
done || true

log_info ""
log_info "NOTE: Adapter XCFrameworks are OPTIONAL."
log_info "The pods-dev, pods-release, and spm-release modes all use adapters as SOURCE code."
log_info ""

# Always exit 0 - adapter builds are optional
exit 0
