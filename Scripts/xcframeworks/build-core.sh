#!/bin/bash
# ============================================================================
# XCFramework Builder for Core Modules
# ============================================================================
# Purpose: Build core modules in correct dependency order
# Usage:   ./Scripts/xcframeworks/build-core.sh
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

log_title "Building Core Modules"

# -----------------------------------------------------------
# Step 0 — Pre-build all CocoaPods dependencies
# This prevents SwiftVerifyEmittedModuleInterface from failing
# during MSP module archives.
# -----------------------------------------------------------
WORKSPACE_FILE="$ROOT_DIR/msp-ios-sdk.xcworkspace"

if [[ -d "$WORKSPACE_FILE" ]]; then
    log_title "Building CocoaPods dependencies first..."
    
    # Build key Pods dependencies using regular build (not archive)
    # This ensures module interfaces are verified during regular build,
    # preventing verification failures during MSP module archives
    # Key dependencies: SnapKit, Kingfisher, lottie-ios, Shimmer
    PODS_DEPENDENCIES=("SnapKit" "Kingfisher" "lottie-ios" "Shimmer")
    
    # Use a shared DerivedData path so pre-built Pods are available to archive builds
    SHARED_DERIVED_DATA="$ROOT_DIR/DerivedData/build-shared"
    mkdir -p "$SHARED_DERIVED_DATA"
    
    for pod in "${PODS_DEPENDENCIES[@]}"; do
        log_step "Building $pod..."
        # Build with shared DerivedData so modules are available for archive
        if xcodebuild \
            -workspace "$WORKSPACE_FILE" \
            -scheme "$pod" \
            -configuration Release \
            -destination "generic/platform=iOS" \
            -derivedDataPath "$SHARED_DERIVED_DATA" \
            build 2>&1 | tee "/tmp/build_pods_${pod}.log" | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error)" | tail -3; then
            log_success "$pod built successfully"
        else
            log_warn "$pod build had issues (checking if it actually succeeded)..."
            # Check if build actually succeeded despite exit code
            if grep -q "BUILD SUCCEEDED" "/tmp/build_pods_${pod}.log"; then
                log_success "$pod built successfully (despite warnings)"
            else
                log_warn "$pod build failed (continuing anyway - may cause issues)"
            fi
        fi
    done
    
    log_success "Pods dependencies pre-build complete"
else
    log_warn "Workspace not found: $WORKSPACE_FILE"
    log_warn "Skipping Pods dependency pre-build (may cause verification issues)"
fi

# -----------------------------------------------------------
# Continue with MSP core modules archive (NovaCore → MSPCore → MSPOMSDK → MSPSharedLibraries)
# -----------------------------------------------------------

# Core modules in dependency order
CORE_MODULES=(
    "NovaCore"
    "MSPCore"
    "MSPOMSDK"
    "MSPSharedLibraries"
)

SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_MODULES=()

for module in "${CORE_MODULES[@]}"; do
    log_section "Building $module"
    
    if "$BUILD_MODULE_SCRIPT" "$module"; then
        ((SUCCESS_COUNT++))
        log_success "$module: BUILD SUCCEEDED"
    else
        ((FAIL_COUNT++))
        FAILED_MODULES+=("$module")
        log_error "$module: BUILD FAILED"
        log_error "Aborting core module build pipeline"
        exit 1
    fi
done

log_title "Core Modules Build Complete"
log_success "Successfully built $SUCCESS_COUNT core module(s)"
if [[ $FAIL_COUNT -gt 0 ]]; then
    log_error "Failed to build $FAIL_COUNT core module(s): ${FAILED_MODULES[*]}"
    exit 1
fi

