#!/usr/bin/env bash
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

XCFRAMEWORKS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$XCFRAMEWORKS_SCRIPT_DIR/../.." && pwd)"


# shellcheck source=Scripts/target-switching/common.sh
source "$XCFRAMEWORKS_SCRIPT_DIR/../target-switching/common.sh"

# Ensure logger functions are available in subprocess
# (Force reload by unsetting the guard variable, as parent may have already sourced)
if [[ -f "$ROOT_DIR/Scripts/release/utils/logger.sh" ]]; then
    unset MSP_LOGGER_LOADED
    # shellcheck source=Scripts/release/utils/logger.sh
    source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true
fi

if [[ -f "$ROOT_DIR/Scripts/lib/process_utils.sh" ]]; then
    # shellcheck source=Scripts/lib/process_utils.sh
    source "$ROOT_DIR/Scripts/lib/process_utils.sh"
fi

# R029f: Source xcodegen module for unified generation
if [[ -f "$ROOT_DIR/Scripts/lib/xcodegen.sh" ]]; then
    # shellcheck source=Scripts/lib/xcodegen.sh
    source "$ROOT_DIR/Scripts/lib/xcodegen.sh" 2>/dev/null || true
fi

ensure_repo_root

BUILD_MODULE_SCRIPT="$XCFRAMEWORKS_SCRIPT_DIR/build_module.sh"
if [[ ! -f "$BUILD_MODULE_SCRIPT" ]]; then
    log::error "XCFW" "build_module.sh not found: $BUILD_MODULE_SCRIPT"
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
        log::error "XCFW" "Failed to build third-party XCFrameworks"
        exit 1
    fi
    log::success "XCFW" "Third-party XCFrameworks built successfully"
else
    log::warn "XCFW" "build-thirdparty.sh not found or not executable, skipping third-party build"
    log::warn "XCFW" "Core modules may fail if required third-party XCFrameworks are missing"
fi

# -----------------------------------------------------------
# Step 1 — Generate project.yml from templates (Template Architecture)
# -----------------------------------------------------------
log_section "Generating project.yml from templates"

if [[ -x "$ROOT_DIR/Scripts/target-switching/generate_project_templates.sh" ]]; then
    "$ROOT_DIR/Scripts/target-switching/generate_project_templates.sh"
else
    log::warn "XCFW" "generate_project_templates.sh not found or not executable"
fi

# -----------------------------------------------------------
# Step 1 — Ensure workspace and Pods are available
# Core modules depend on Pod sources (MSPPrebidAdapter, MSPKingfisher, etc.)
# via workspace, not XCFrameworks
# -----------------------------------------------------------
WORKSPACE_FILE="$ROOT_DIR/msp-ios-sdk.xcworkspace"

if [[ ! -d "$WORKSPACE_FILE" ]]; then
    log::error "XCFW" "Workspace not found: $WORKSPACE_FILE"
    log::error "XCFW" "Core modules require workspace for Pod dependencies (MSPPrebidAdapter, MSPKingfisher, etc.)"
    exit 1
fi

if ! xcodebuild -workspace "$WORKSPACE_FILE" -list 2>/dev/null | grep -q "Schemes:"; then
    log::info "XCFW" "Workspace has no schemes, running pod install..."
    if ! pod install --project-directory="$ROOT_DIR" 2>&1; then
        log::error "XCFW" "pod install failed"
        exit 1
    fi
    log::success "XCFW" "pod install completed"
fi

log::info "XCFW" "Using workspace: $WORKSPACE_FILE"
log::info "XCFW" "Core modules will resolve Pod dependencies (MSPPrebidAdapter, MSPKingfisher, MSPSnapKit, etc.) via workspace"

# -----------------------------------------------------------
# Step 1 — Pre-build Pod dependencies that Core modules need
# Core modules (especially NovaCore) need Pod modules to be built first
# so their Swift modules are available in DerivedData
# -----------------------------------------------------------
SHARED_DERIVED_DATA="$ROOT_DIR/.generated/DerivedData/build-shared"
mkdir -p "$SHARED_DERIVED_DATA"

log::step "XCFW" "Pre-building Pod dependencies for Core modules"

# List of Pod schemes to pre-build for Core module compilation
# These Pods provide Swift modules needed by Core modules:
# - MSPKingfisher: provides Kingfisher module (used by NovaCore)
# - MSPSnapKit: used by NovaCore
# - SwiftProtobuf: used by MSPCore
# NOTE: MSPPrebidAdapter is NOT pre-built here because it depends on MSPiOSCore.
#       It will be rebuilt AFTER MSPiOSCore.xcframework is created to ensure ABI compatibility.
POD_SCHEMES_TO_PREBUILD=("MSPKingfisher" "MSPSnapKit" "SwiftProtobuf")

for pod_scheme in "${POD_SCHEMES_TO_PREBUILD[@]}"; do
    log::info "XCFW" "Pre-building $pod_scheme for iOS..."
    if xcodebuild -workspace "$WORKSPACE_FILE" \
        -scheme "$pod_scheme" \
        -configuration Release \
        -destination "generic/platform=iOS" \
        -derivedDataPath "$SHARED_DERIVED_DATA" \
        build 2>&1 | tee "/tmp/build_${pod_scheme}.log"; then
        if grep -q "BUILD SUCCEEDED" "/tmp/build_${pod_scheme}.log"; then
            log::success "XCFW" "$pod_scheme (iOS) built successfully"
        else
            log::error "XCFW" "$pod_scheme (iOS) build failed"
            exit 1
        fi
    else
        log::warn "XCFW" "$pod_scheme (iOS) build had issues, checking log..."
        if grep -q "BUILD SUCCEEDED" "/tmp/build_${pod_scheme}.log"; then
            log::success "XCFW" "$pod_scheme (iOS) built successfully (despite warnings)"
        else
            log::error "XCFW" "$pod_scheme (iOS) build failed - Core modules cannot resolve module"
            exit 1
        fi
    fi
    
    log::info "XCFW" "Pre-building $pod_scheme for Simulator..."
    if xcodebuild -workspace "$WORKSPACE_FILE" \
        -scheme "$pod_scheme" \
        -configuration Release \
        -destination "generic/platform=iOS Simulator" \
        -derivedDataPath "$SHARED_DERIVED_DATA" \
        build 2>&1 | tee "/tmp/build_${pod_scheme}_sim.log"; then
        if grep -q "BUILD SUCCEEDED" "/tmp/build_${pod_scheme}_sim.log"; then
            log::success "XCFW" "$pod_scheme (Simulator) built successfully"
        else
            log::warn "XCFW" "$pod_scheme (Simulator) build had issues, continuing..."
        fi
    fi
done

log::success "XCFW" "All Pod dependencies pre-built successfully"
log::info "XCFW" "Pod modules available at: $SHARED_DERIVED_DATA/Build/Products/Release-iphoneos/"

# -----------------------------------------------------------
# Build core modules in dependency order
# Note: MSPPrebidAdapter is a source pod, NOT an XCFramework
# Note: MSPKingfisher is pre-built above, so Kingfisher module is available
# -----------------------------------------------------------

ARCHIVES_DIR="$ROOT_DIR/Build/ReleaseArtifacts/Archives"
XCFRAMEWORKS_DIR="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks"
LOGS_DIR="$ROOT_DIR/Build/Logs"
mkdir -p "$ARCHIVES_DIR" "$XCFRAMEWORKS_DIR" "$LOGS_DIR"

# -----------------------------------------------------------
# Function: build_msp_prebid_adapter_xcframework
# Purpose: Build MSPPrebidAdapter.xcframework AFTER MSPiOSCore.xcframework
# Uses XcodeGen standalone project (not workspace) to ensure it links against
# MSPiOSCore.xcframework (binary) instead of Pod source version.
# -----------------------------------------------------------
build_msp_prebid_adapter_xcframework() {
    log::step "XCFW" "Building MSPPrebidAdapter.xcframework (post-MSPiOSCore)"
    log::info "XCFW" "Using XcodeGen standalone project to link against MSPiOSCore.xcframework"

    rm -rf "$XCFRAMEWORKS_DIR/MSPPrebidAdapter.xcframework"

    # Use build_module.sh which uses XcodeGen project (links XCFrameworks, not Pod sources)
    if "$BUILD_MODULE_SCRIPT" "MSPPrebidAdapter"; then
        log::success "XCFW" "MSPPrebidAdapter.xcframework built successfully"
        return 0
    else
        log::error "XCFW" "MSPPrebidAdapter.xcframework build failed"
        return 1
    fi
}

# -----------------------------------------------------------
# Function: fix_pod_modulemaps
# Purpose: Fix absolute paths in Pod modulemaps to use relative paths
# -----------------------------------------------------------
fix_pod_modulemaps() {
    log::info "XCFW" "Fixing Pod modulemaps (converting absolute paths to relative)"
    for plat in iphoneos iphonesimulator; do
        # Note: MSPPrebidAdapter is now an XCFramework, only SwiftProtobuf needs modulemap fix
        for pod in SwiftProtobuf; do
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
                log::info "XCFW" "Fixed modulemap: $plat/$pod"
            fi
        done
    done
}

# -----------------------------------------------------------
# Function: build_mspcore_with_modulemaps
# Purpose: Build MSPCore using XcodeGen project with explicit modulemap injection
# MSPCore needs SwiftProtobuf which requires Clang modulemap injection
# MSPPrebidAdapter is linked as XCFramework (built earlier in pipeline)
# -----------------------------------------------------------
build_mspcore_with_modulemaps() {
    local MODULE_NAME="MSPCore"
    
    log::info "XCFW" "Building $MODULE_NAME via XcodeGen project with modulemap injection"
    
    fix_pod_modulemaps

    rm -rf "$XCFRAMEWORKS_DIR/$MODULE_NAME.xcframework"

    local IOS_ARCHIVE="$ARCHIVES_DIR/$MODULE_NAME-iOS.xcarchive"
    local SIM_ARCHIVE="$ARCHIVES_DIR/$MODULE_NAME-Simulator.xcarchive"
    local PROJECT_FILE="$ROOT_DIR/Sources/Core/$MODULE_NAME/$MODULE_NAME.xcodeproj"
    local SCHEME_NAME="$MODULE_NAME-XCFramework"
    
    log::step "XCFW" "Regenerating $MODULE_NAME project"
    # R029f: Use xcodegen.sh module if available, fallback to direct call
    local module_dir="$ROOT_DIR/Sources/Core/$MODULE_NAME"
    if command -v xcodegen_generate &>/dev/null; then
        xcodegen_generate "$module_dir/project.yml" "$module_dir" 2>&1
    else
        (cd "$module_dir" && xcodegen generate 2>&1)
    fi
    
    rm -rf "$IOS_ARCHIVE" "$SIM_ARCHIVE"
    
    # Build iOS archive with explicit modulemap paths
    # Use standalone project to link against XCFramework versions of dependencies.
    # MSPPrebidAdapter.xcframework is built earlier in the pipeline.
    log::step "XCFW" "Building $MODULE_NAME iOS archive"
    local POD_BASE_IOS="$SHARED_DERIVED_DATA/Build/Products/Release-iphoneos"
    local SWIFT_FLAGS_IOS="-no-verify-emitted-module-interface -Xcc -fmodule-map-file=$POD_BASE_IOS/SwiftProtobuf/SwiftProtobuf.modulemap"

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
        2>&1 | tee "$LOGS_DIR/$MODULE_NAME-iOS.log"; then
        if ! grep -q "ARCHIVE SUCCEEDED" "$LOGS_DIR/$MODULE_NAME-iOS.log"; then
            log::error "XCFW" "$MODULE_NAME iOS archive failed"
            return 1
        fi
    fi
    
    if ! grep -q "ARCHIVE SUCCEEDED" "$LOGS_DIR/$MODULE_NAME-iOS.log"; then
        log::error "XCFW" "$MODULE_NAME iOS archive failed"
        return 1
    fi
    
    if [[ ! -d "$IOS_ARCHIVE" ]]; then
        log::error "XCFW" "$MODULE_NAME iOS archive not created"
        return 1
    fi
    log::success "XCFW" "$MODULE_NAME iOS archive succeeded"
    
    log::step "XCFW" "Building $MODULE_NAME Simulator archive"
    local POD_BASE_SIM="$SHARED_DERIVED_DATA/Build/Products/Release-iphonesimulator"
    local SWIFT_FLAGS_SIM="-no-verify-emitted-module-interface -Xcc -fmodule-map-file=$POD_BASE_SIM/SwiftProtobuf/SwiftProtobuf.modulemap"

    # Use timeout wrapper if available (from process_utils.sh)
    local build_cmd="xcodebuild archive \
        -project \"$PROJECT_FILE\" \
        -scheme \"$SCHEME_NAME\" \
        -configuration Release \
        -destination \"generic/platform=iOS Simulator\" \
        -archivePath \"$SIM_ARCHIVE\" \
        -derivedDataPath \"$ROOT_DIR/.generated/DerivedData/build-$MODULE_NAME\" \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        SKIP_INSTALL=NO \
        SWIFT_VERIFY_EMITTED_MODULE_INTERFACE=NO \
        \"OTHER_SWIFT_FLAGS=$SWIFT_FLAGS_SIM\""

    # Build with timeout protection (3600 seconds = 1 hour)
    local build_timeout=3600
    if command -v run_with_timeout >/dev/null 2>&1 && [[ -n "${TIMEOUT_CMD:-}" ]]; then
        log::info "XCFW" "Using timeout protection (${build_timeout}s) for Simulator archive build"
        if ! run_with_timeout $build_timeout bash -c "$build_cmd" 2>&1 | tee "$LOGS_DIR/$MODULE_NAME-Simulator.log"; then
            if ! grep -q "ARCHIVE SUCCEEDED" "$LOGS_DIR/$MODULE_NAME-Simulator.log"; then
                log::error "XCFW" "$MODULE_NAME Simulator archive failed or timed out"
                return 1
            fi
        fi
    else
        # Fallback: build without timeout (original behavior)
        log::warn "XCFW" "timeout wrapper not available, building without timeout protection"
        if ! bash -c "$build_cmd" 2>&1 | tee "$LOGS_DIR/$MODULE_NAME-Simulator.log"; then
            if ! grep -q "ARCHIVE SUCCEEDED" "$LOGS_DIR/$MODULE_NAME-Simulator.log"; then
                log::error "XCFW" "$MODULE_NAME Simulator archive failed"
                return 1
            fi
        fi
    fi
    
    if ! grep -q "ARCHIVE SUCCEEDED" "$LOGS_DIR/$MODULE_NAME-Simulator.log"; then
        log::error "XCFW" "$MODULE_NAME Simulator archive failed"
        return 1
    fi
    
    if [[ ! -d "$SIM_ARCHIVE" ]]; then
        log::error "XCFW" "$MODULE_NAME Simulator archive not created"
        return 1
    fi
    log::success "XCFW" "$MODULE_NAME Simulator archive succeeded"
    
    log::step "XCFW" "Creating $MODULE_NAME.xcframework"
    local XCFRAMEWORK_OUTPUT="$XCFRAMEWORKS_DIR/$MODULE_NAME.xcframework"
    
    if ! xcodebuild -create-xcframework \
        -framework "$IOS_ARCHIVE/Products/Library/Frameworks/$MODULE_NAME.framework" \
        -framework "$SIM_ARCHIVE/Products/Library/Frameworks/$MODULE_NAME.framework" \
        -output "$XCFRAMEWORK_OUTPUT"; then
        log::error "XCFW" "Failed to create $MODULE_NAME.xcframework"
        return 1
    fi
    
    if [[ ! -d "$XCFRAMEWORK_OUTPUT" ]]; then
        log::error "XCFW" "XCFramework not created: $XCFRAMEWORK_OUTPUT"
        return 1
    fi
    
    log::success "XCFW" "$MODULE_NAME.xcframework created successfully"
    return 0
}

# -----------------------------------------------------------
# Core modules in dependency order
# CORRECT Order: MSPiOSCore → MSPSharedLibraries → NovaCore → MSPCore
# Rationale:
# - MSPiOSCore: Base framework (no XCFramework dependencies)
# - MSPSharedLibraries: Depends on MSPiOSCore (@_exported import MSPiOSCore in Shim.swift)
# - NovaCore: May depend on MSPiOSCore/MSPSharedLibraries
# - MSPCore: Top-level module, depends on everything above
# Stage B: MSPOMSDK removed - OMSDK now embedded in NovaCore
# -----------------------------------------------------------
# MSPSharedLibraries, MSPiOSCore, NovaCore: Use XcodeGen project mode (existing)
# MSPCore: Use Workspace mode (new) - needs Pods for MSPPrebidAdapter
# -----------------------------------------------------------

CORE_MODULES=(
    "MSPiOSCore"
    "MSPSharedLibraries"
    "NovaCore"
    "MSPPrebidAdapter"  # Must be after MSPiOSCore, before MSPCore
    "MSPCore"
)

SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_MODULES=()

for module in "${CORE_MODULES[@]}"; do
    log_section "Building $module"

    case "$module" in
        MSPPrebidAdapter)
            # MSPPrebidAdapter: Build using XcodeGen standalone project
            # This links against MSPiOSCore.xcframework (built earlier), ensuring ABI compatibility
            if build_msp_prebid_adapter_xcframework; then
                ((++SUCCESS_COUNT))
                log::success "XCFW" "$module: BUILD SUCCEEDED (xcodegen mode)"
            else
                ((FAIL_COUNT++)) || true
                FAILED_MODULES+=("$module")
                log::error "XCFW" "$module: BUILD FAILED (xcodegen mode)"
                log::error "XCFW" "Aborting core module build pipeline"
                exit 1
            fi
            ;;
        MSPCore)
            # MSPCore needs explicit modulemap injection for MSPPrebidAdapter and SwiftProtobuf
            if build_mspcore_with_modulemaps; then
                ((++SUCCESS_COUNT))
                log::success "XCFW" "$module: BUILD SUCCEEDED (xcodegen + modulemap mode)"
            else
                ((FAIL_COUNT++)) || true
                FAILED_MODULES+=("$module")
                log::error "XCFW" "$module: BUILD FAILED (xcodegen + modulemap mode)"
                log::error "XCFW" "Aborting core module build pipeline"
                exit 1
            fi
            ;;
        *)
            # Other modules: Build via XcodeGen project + build_module.sh
            if "$BUILD_MODULE_SCRIPT" "$module"; then
                ((++SUCCESS_COUNT))
                log::success "XCFW" "$module: BUILD SUCCEEDED (xcodegen mode)"
            else
                ((FAIL_COUNT++)) || true
                FAILED_MODULES+=("$module")
                log::error "XCFW" "$module: BUILD FAILED (xcodegen mode)"
                log::error "XCFW" "Aborting core module build pipeline"
                exit 1
            fi
            ;;
    esac
done

log_title "Core Modules Build Complete"
log::success "XCFW" "Successfully built $SUCCESS_COUNT core module(s)"
if [[ $FAIL_COUNT -gt 0 ]]; then
    log::error "XCFW" "Failed to build $FAIL_COUNT core module(s): ${FAILED_MODULES[*]}"
    exit 1
fi

# Task 2: Cleanup generated project.yml files after build
# Ensure workspace remains clean - project.yml should only exist during build
log::step "XCFW" "Cleaning up generated project.yml files"
CLEANED_COUNT=0
while IFS= read -r project_yml; do
    [[ -z "$project_yml" ]] && continue
    if [[ -f "$project_yml" ]]; then
        rm -f "$project_yml"
        ((CLEANED_COUNT++)) || true
    fi
done < <(find "$ROOT_DIR/Sources" "$ROOT_DIR/Examples" -name "project.yml" -type f 2>/dev/null | grep -v ".generated" | grep -v "DerivedData" || true)

if [[ $CLEANED_COUNT -gt 0 ]]; then
    log::info "XCFW" "  Cleaned up $CLEANED_COUNT project.yml file(s)"
else
    log::info "XCFW" "  No project.yml files to clean up"
fi

# Explicit success exit to ensure correct exit code under set -e
exit 0
