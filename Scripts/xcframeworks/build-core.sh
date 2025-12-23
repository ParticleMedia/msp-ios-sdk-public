#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
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
# Step 0 — Build third-party XCFrameworks first (required by core modules)
# -----------------------------------------------------------
log_section "Building third-party XCFrameworks"

THIRDPARTY_BUILD_SCRIPT="$XCFRAMEWORKS_SCRIPT_DIR/build-thirdparty.sh"
if [[ -f "$THIRDPARTY_BUILD_SCRIPT" ]] && [[ -x "$THIRDPARTY_BUILD_SCRIPT" ]]; then
    if ! bash "$THIRDPARTY_BUILD_SCRIPT"; then
        log_error "Failed to build third-party XCFrameworks"
        exit 1
    fi
    log_success "Third-party XCFrameworks built successfully"
else
    log_warn "build-thirdparty.sh not found or not executable, skipping third-party build"
    log_warn "Core modules may fail if required third-party XCFrameworks are missing"
fi

# -----------------------------------------------------------
# Step 1 — Generate project.yml from templates (Template Architecture)
# -----------------------------------------------------------
log_section "Generating project.yml from templates"

if [[ -x "$ROOT_DIR/Scripts/target-switching/generate_project_templates.sh" ]]; then
    "$ROOT_DIR/Scripts/target-switching/generate_project_templates.sh"
else
    log_warn "generate_project_templates.sh not found or not executable"
fi

# -----------------------------------------------------------
# Step 1 — Ensure workspace and Pods are available
# Core modules depend on Pod sources (MSPPrebidAdapter, MSPKingfisher, etc.)
# via workspace, not XCFrameworks
# -----------------------------------------------------------
WORKSPACE_FILE="$ROOT_DIR/msp-ios-sdk.xcworkspace"

if [[ ! -d "$WORKSPACE_FILE" ]]; then
    log_error "Workspace not found: $WORKSPACE_FILE"
    log_error "Core modules require workspace for Pod dependencies (MSPPrebidAdapter, MSPKingfisher, etc.)"
    exit 1
fi

log_info "Using workspace: $WORKSPACE_FILE"
log_info "Core modules will resolve Pod dependencies (MSPPrebidAdapter, MSPKingfisher, SnapKit, etc.) via workspace"

# -----------------------------------------------------------
# Step 1 — Pre-build Pod dependencies that Core modules need
# Core modules (especially NovaCore) need Pod modules to be built first
# so their Swift modules are available in DerivedData
# -----------------------------------------------------------
SHARED_DERIVED_DATA="$ROOT_DIR/.generated/DerivedData/build-shared"
mkdir -p "$SHARED_DERIVED_DATA"

log_step "Pre-building Pod dependencies for Core modules"

# List of Pod schemes to pre-build for Core module compilation
# These Pods provide Swift modules needed by Core modules:
# - MSPKingfisher: provides Kingfisher module (used by NovaCore)
# - SnapKit: used by NovaCore
# - lottie-ios: used by NovaCore  
# - MSPPrebidAdapter: used by MSPCore
POD_SCHEMES_TO_PREBUILD=("MSPKingfisher" "SnapKit" "lottie-ios" "MSPPrebidAdapter" "SwiftProtobuf")

for pod_scheme in "${POD_SCHEMES_TO_PREBUILD[@]}"; do
    log_info "Pre-building $pod_scheme for iOS..."
    if xcodebuild -workspace "$WORKSPACE_FILE" \
        -scheme "$pod_scheme" \
        -configuration Release \
        -destination "generic/platform=iOS" \
        -derivedDataPath "$SHARED_DERIVED_DATA" \
        build 2>&1 | tee "/tmp/build_${pod_scheme}.log" | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error)" | tail -3; then
        if grep -q "BUILD SUCCEEDED" "/tmp/build_${pod_scheme}.log"; then
            log_success "$pod_scheme (iOS) built successfully"
        else
            log_error "$pod_scheme (iOS) build failed"
            exit 1
        fi
    else
        log_warn "$pod_scheme (iOS) build had issues, checking log..."
        if grep -q "BUILD SUCCEEDED" "/tmp/build_${pod_scheme}.log"; then
            log_success "$pod_scheme (iOS) built successfully (despite warnings)"
        else
            log_error "$pod_scheme (iOS) build failed - Core modules cannot resolve module"
            exit 1
        fi
    fi
    
    log_info "Pre-building $pod_scheme for Simulator..."
    if xcodebuild -workspace "$WORKSPACE_FILE" \
        -scheme "$pod_scheme" \
        -configuration Release \
        -destination "generic/platform=iOS Simulator" \
        -derivedDataPath "$SHARED_DERIVED_DATA" \
        build 2>&1 | tee "/tmp/build_${pod_scheme}_sim.log" | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error)" | tail -3; then
        if grep -q "BUILD SUCCEEDED" "/tmp/build_${pod_scheme}_sim.log"; then
            log_success "$pod_scheme (Simulator) built successfully"
        else
            log_warn "$pod_scheme (Simulator) build had issues, continuing..."
        fi
    fi
done

log_success "All Pod dependencies pre-built successfully"
log_info "Pod modules available at: $SHARED_DERIVED_DATA/Build/Products/Release-iphoneos/"

# -----------------------------------------------------------
# Build core modules in dependency order
# Note: MSPPrebidAdapter is a source pod, NOT an XCFramework
# Note: MSPKingfisher is pre-built above, so Kingfisher module is available
# -----------------------------------------------------------

# Output directories
ARCHIVES_DIR="$ROOT_DIR/Build/Archives"
XCFRAMEWORKS_DIR="$ROOT_DIR/Build/XCFrameworks"
LOGS_DIR="$ROOT_DIR/Build/Logs"
mkdir -p "$ARCHIVES_DIR" "$XCFRAMEWORKS_DIR" "$LOGS_DIR"

# -----------------------------------------------------------
# Function: fix_pod_modulemaps
# Purpose: Fix absolute paths in Pod modulemaps to use relative paths
# -----------------------------------------------------------
fix_pod_modulemaps() {
    log_info "Fixing Pod modulemaps (converting absolute paths to relative)"
    for plat in iphoneos iphonesimulator; do
        for pod in MSPPrebidAdapter SwiftProtobuf; do
            local MODULE_DIR="$SHARED_DERIVED_DATA/Build/Products/Release-$plat/$pod"
            local MODULEMAP="$MODULE_DIR/$pod.modulemap"
            if [[ -f "$MODULEMAP" ]]; then
                # Replace absolute path to Swift Compatibility Header with relative path
                cat > "$MODULEMAP" << EOF
module $pod {
  umbrella header "$pod-umbrella.h"
  export *
  module * { export * }
}

module $pod.Swift {
  header "Swift Compatibility Header/$pod-Swift.h"
  requires objc
}
EOF
                log_info "Fixed modulemap: $plat/$pod"
            fi
        done
    done
}

# -----------------------------------------------------------
# Function: build_mspcore_with_modulemaps
# Purpose: Build MSPCore using XcodeGen project with explicit modulemap injection
# MSPCore needs MSPPrebidAdapter and SwiftProtobuf which require Clang modulemaps
# -----------------------------------------------------------
build_mspcore_with_modulemaps() {
    local MODULE_NAME="MSPCore"
    
    log_info "Building $MODULE_NAME via XcodeGen project with modulemap injection"
    
    # Fix Pod modulemaps first
    fix_pod_modulemaps
    
    # Clean up any placeholder XCFramework
    rm -rf "$XCFRAMEWORKS_DIR/$MODULE_NAME.xcframework"
    
    # Archive paths
    local IOS_ARCHIVE="$ARCHIVES_DIR/$MODULE_NAME-iOS.xcarchive"
    local SIM_ARCHIVE="$ARCHIVES_DIR/$MODULE_NAME-Simulator.xcarchive"
    local PROJECT_FILE="$ROOT_DIR/Sources/Core/$MODULE_NAME/$MODULE_NAME.xcodeproj"
    local SCHEME_NAME="$MODULE_NAME-XCFramework"
    
    # Regenerate project
    log_step "Regenerating $MODULE_NAME project"
    cd "$ROOT_DIR/Sources/Core/$MODULE_NAME" && xcodegen generate 2>&1 && cd "$ROOT_DIR"
    
    # Clean previous archives
    rm -rf "$IOS_ARCHIVE" "$SIM_ARCHIVE"
    
    # Build iOS archive with explicit modulemap paths
    log_step "Building $MODULE_NAME iOS archive"
    local POD_BASE_IOS="$SHARED_DERIVED_DATA/Build/Products/Release-iphoneos"
    local SWIFT_FLAGS_IOS="-no-verify-emitted-module-interface -Xcc -fmodule-map-file=$POD_BASE_IOS/MSPPrebidAdapter/MSPPrebidAdapter.modulemap -Xcc -fmodule-map-file=$POD_BASE_IOS/SwiftProtobuf/SwiftProtobuf.modulemap"
    
    if ! xcodebuild archive \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME_NAME" \
        -configuration Release \
        -destination "generic/platform=iOS" \
        -archivePath "$IOS_ARCHIVE" \
        -derivedDataPath "$ROOT_DIR/.generated/DerivedData/build-$MODULE_NAME" \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        SKIP_INSTALL=NO \
        SWIFT_VERIFY_EMITTED_MODULE_INTERFACE=NO \
        "OTHER_SWIFT_FLAGS=$SWIFT_FLAGS_IOS" \
        2>&1 | tee "$LOGS_DIR/$MODULE_NAME-iOS.log" | grep -E "(ARCHIVE SUCCEEDED|ARCHIVE FAILED|error:)" | tail -5; then
        if ! grep -q "ARCHIVE SUCCEEDED" "$LOGS_DIR/$MODULE_NAME-iOS.log"; then
            log_error "$MODULE_NAME iOS archive failed"
            return 1
        fi
    fi
    
    if [[ ! -d "$IOS_ARCHIVE" ]]; then
        log_error "$MODULE_NAME iOS archive not created"
        return 1
    fi
    log_success "$MODULE_NAME iOS archive succeeded"
    
    # Build Simulator archive
    log_step "Building $MODULE_NAME Simulator archive"
    local POD_BASE_SIM="$SHARED_DERIVED_DATA/Build/Products/Release-iphonesimulator"
    local SWIFT_FLAGS_SIM="-no-verify-emitted-module-interface -Xcc -fmodule-map-file=$POD_BASE_SIM/MSPPrebidAdapter/MSPPrebidAdapter.modulemap -Xcc -fmodule-map-file=$POD_BASE_SIM/SwiftProtobuf/SwiftProtobuf.modulemap"
    
    if ! xcodebuild archive \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME_NAME" \
        -configuration Release \
        -destination "generic/platform=iOS Simulator" \
        -archivePath "$SIM_ARCHIVE" \
        -derivedDataPath "$ROOT_DIR/.generated/DerivedData/build-$MODULE_NAME" \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        SKIP_INSTALL=NO \
        SWIFT_VERIFY_EMITTED_MODULE_INTERFACE=NO \
        "OTHER_SWIFT_FLAGS=$SWIFT_FLAGS_SIM" \
        2>&1 | tee "$LOGS_DIR/$MODULE_NAME-Simulator.log" | grep -E "(ARCHIVE SUCCEEDED|ARCHIVE FAILED|error:)" | tail -5; then
        if ! grep -q "ARCHIVE SUCCEEDED" "$LOGS_DIR/$MODULE_NAME-Simulator.log"; then
            log_error "$MODULE_NAME Simulator archive failed"
            return 1
        fi
    fi
    
    if [[ ! -d "$SIM_ARCHIVE" ]]; then
        log_error "$MODULE_NAME Simulator archive not created"
        return 1
    fi
    log_success "$MODULE_NAME Simulator archive succeeded"
    
    # Create XCFramework
    log_step "Creating $MODULE_NAME.xcframework"
    local XCFRAMEWORK_OUTPUT="$XCFRAMEWORKS_DIR/$MODULE_NAME.xcframework"
    
    if ! xcodebuild -create-xcframework \
        -framework "$IOS_ARCHIVE/Products/Library/Frameworks/$MODULE_NAME.framework" \
        -framework "$SIM_ARCHIVE/Products/Library/Frameworks/$MODULE_NAME.framework" \
        -output "$XCFRAMEWORK_OUTPUT"; then
        log_error "Failed to create $MODULE_NAME.xcframework"
        return 1
    fi
    
    if [[ ! -d "$XCFRAMEWORK_OUTPUT" ]]; then
        log_error "XCFramework not created: $XCFRAMEWORK_OUTPUT"
        return 1
    fi
    
    log_success "$MODULE_NAME.xcframework created successfully"
    return 0
}

# -----------------------------------------------------------
# Core modules in dependency order
# Order: MSPSharedLibraries → MSPiOSCore → NovaCore → MSPCore
# Stage B: MSPOMSDK removed - OMSDK now embedded in NovaCore
# -----------------------------------------------------------
# MSPSharedLibraries, MSPiOSCore, NovaCore: Use XcodeGen project mode (existing)
# MSPCore: Use Workspace mode (new) - needs Pods for MSPPrebidAdapter
# -----------------------------------------------------------

CORE_MODULES=(
    "MSPSharedLibraries"
    "MSPiOSCore"
    "NovaCore"
    "MSPCore"
)

SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_MODULES=()

for module in "${CORE_MODULES[@]}"; do
    log_section "Building $module"
    
    case "$module" in
        MSPCore)
            # MSPCore needs explicit modulemap injection for MSPPrebidAdapter and SwiftProtobuf
            if build_mspcore_with_modulemaps; then
                ((SUCCESS_COUNT++))
                log_success "$module: BUILD SUCCEEDED (xcodegen + modulemap mode)"
            else
                ((FAIL_COUNT++))
                FAILED_MODULES+=("$module")
                log_error "$module: BUILD FAILED (xcodegen + modulemap mode)"
                log_error "Aborting core module build pipeline"
                exit 1
            fi
            ;;
        *)
            # Other modules: Build via XcodeGen project + build_module.sh
            if "$BUILD_MODULE_SCRIPT" "$module"; then
                ((SUCCESS_COUNT++))
                log_success "$module: BUILD SUCCEEDED (xcodegen mode)"
            else
                ((FAIL_COUNT++))
                FAILED_MODULES+=("$module")
                log_error "$module: BUILD FAILED (xcodegen mode)"
                log_error "Aborting core module build pipeline"
                exit 1
            fi
            ;;
    esac
done

log_title "Core Modules Build Complete"
log_success "Successfully built $SUCCESS_COUNT core module(s)"
if [[ $FAIL_COUNT -gt 0 ]]; then
    log_error "Failed to build $FAIL_COUNT core module(s): ${FAILED_MODULES[*]}"
    exit 1
fi

# Task 2: Cleanup generated project.yml files after build
# Ensure workspace remains clean - project.yml should only exist during build
log_step "Cleaning up generated project.yml files"
CLEANED_COUNT=0
while IFS= read -r project_yml; do
    [[ -z "$project_yml" ]] && continue
    if [[ -f "$project_yml" ]]; then
        rm -f "$project_yml"
        ((CLEANED_COUNT++)) || true
    fi
done < <(find "$ROOT_DIR/Sources" "$ROOT_DIR/Examples" -name "project.yml" -type f 2>/dev/null | grep -v ".generated" | grep -v "DerivedData" || true)

if [[ $CLEANED_COUNT -gt 0 ]]; then
    log_info "  Cleaned up $CLEANED_COUNT project.yml file(s)"
else
    log_info "  No project.yml files to clean up"
fi

