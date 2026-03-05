#!/usr/bin/env bash
# ============================================================================
# NovaCore Build Module
# ============================================================================
# Module: novacore_build.sh
# Purpose: NovaCore XCFramework build and deployment functions
# Extracted from: publish.sh
#
# Functions:
#   - ensure_novacore_xcframework: Ensure NovaCore.xcframework is available
#   - prebuild_novacore_dependencies: Pre-build Pod dependencies for NovaCore
#
# Dependencies:
#   - Logging functions (log::info, log::error, log::success, log::step, log_section)
#   - ROOT_DIR environment variable
#   - Xcode build tools (xcodebuild)
#
# Environment Variables:
#   - ROOT_DIR: Project root directory
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_NOVACORE_BUILD_SOURCED:-}" ]] && return 0
readonly _NOVACORE_BUILD_SOURCED=1

# ============================================================================
# Pre-build NovaCore Dependencies
# ============================================================================
# Pre-builds Pod dependencies that NovaCore needs:
# NovaCore imports: Kingfisher (via MSPKingfisher), MSPSnapKit, Lottie
# These must be built to shared DerivedData before NovaCore can compile
#
# Args:
#   $1: workspace_file - Path to .xcworkspace
#   $2: shared_derived_data - Path to shared DerivedData directory
#
# Returns:
#   0 if all dependencies built, 1 if any failed
# ============================================================================
prebuild_novacore_dependencies() {
    local workspace_file="$1"
    local shared_derived_data="$2"

    log::info "PODS" "Pre-building Pod dependencies for NovaCore..."

    # Check if workspace exists
    if [[ ! -d "$workspace_file" ]]; then
        log::error "PODS" "Workspace not found: $workspace_file"
        log::error "PODS" "NovaCore requires workspace for Pod dependencies"
        return 1
    fi

    # Create shared DerivedData directory
    mkdir -p "$shared_derived_data"

    # Pod schemes that NovaCore depends on
    local pod_schemes=("MSPKingfisher" "MSPSnapKit")

    for pod_scheme in "${pod_schemes[@]}"; do
        log::info "PODS" "Pre-building $pod_scheme for iOS..."
        if xcodebuild -workspace "$workspace_file" \
            -scheme "$pod_scheme" \
            -configuration Release \
            -destination "generic/platform=iOS" \
            -derivedDataPath "$shared_derived_data" \
            build 2>&1 | tee "/tmp/build_${pod_scheme}.log" | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)" | tail -3; then
            if grep -q "BUILD SUCCEEDED" "/tmp/build_${pod_scheme}.log"; then
                log::success "PODS" "  $pod_scheme (iOS) built successfully"
            else
                log::error "PODS" "  $pod_scheme (iOS) build failed"
                log::error "PODS" "  Check log: /tmp/build_${pod_scheme}.log"
                return 1
            fi
        else
            if grep -q "BUILD SUCCEEDED" "/tmp/build_${pod_scheme}.log"; then
                log::success "PODS" "  $pod_scheme (iOS) built successfully (despite warnings)"
            else
                log::error "PODS" "  $pod_scheme (iOS) build failed"
                return 1
            fi
        fi

        log::info "PODS" "Pre-building $pod_scheme for Simulator..."
        if xcodebuild -workspace "$workspace_file" \
            -scheme "$pod_scheme" \
            -configuration Release \
            -destination "generic/platform=iOS Simulator" \
            -derivedDataPath "$shared_derived_data" \
            build 2>&1 | tee "/tmp/build_${pod_scheme}_sim.log" | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)" | tail -3; then
            if grep -q "BUILD SUCCEEDED" "/tmp/build_${pod_scheme}_sim.log"; then
                log::success "PODS" "  $pod_scheme (Simulator) built successfully"
            fi
        fi
    done

    log::success "PODS" "All Pod dependencies pre-built for NovaCore"
    log::info "PODS" "Pod modules available at: $shared_derived_data/Build/Products/"
    return 0
}

# ============================================================================
# Ensure NovaCore XCFramework
# ============================================================================
# Ensures NovaCore.xcframework is available in Binary/ directory for MSPNovaAdapter release
# ALWAYS rebuilds NovaCore to ensure source code changes are included
# Pre-builds Pod dependencies (Kingfisher, MSPSnapKit, Lottie) before building NovaCore
#
# Returns:
#   0 if NovaCore.xcframework is ready, 1 if failed
# ============================================================================
ensure_novacore_xcframework() {
    local novacore_binary_path="$ROOT_DIR/Build/ReleaseArtifacts/Binary/NovaCore.xcframework"
    local novacore_build_path="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks/NovaCore.xcframework"
    local workspace_file="$ROOT_DIR/msp-ios-sdk.xcworkspace"
    local shared_derived_data="$ROOT_DIR/.generated/DerivedData/build-shared"

    log_section "Ensuring NovaCore.xcframework is available for MSPNovaAdapter"

    # ALWAYS rebuild NovaCore to ensure source code changes are included
    # Previous logic only checked if Binary/ exists, which caused stale binary issues
    # when source code was updated but binary was not rebuilt
    log::info "PODS" "Rebuilding NovaCore.xcframework to include latest source code changes..."

    # Clean up old binaries to ensure fresh build
    if [[ -d "$novacore_binary_path" ]]; then
        log::info "PODS" "Removing old Binary/NovaCore.xcframework..."
        rm -rf "$novacore_binary_path"
    fi
    if [[ -d "$novacore_build_path" ]]; then
        log::info "PODS" "Removing old Build/ReleaseArtifacts/XCFrameworks/NovaCore.xcframework..."
        rm -rf "$novacore_build_path"
    fi

    # -----------------------------------------------------------
    # Step 1: Pre-build Pod dependencies that NovaCore needs
    # -----------------------------------------------------------
    if ! prebuild_novacore_dependencies "$workspace_file" "$shared_derived_data"; then
        log::error "PODS" "Failed to pre-build NovaCore dependencies"
        return 1
    fi

    # -----------------------------------------------------------
    # Step 2: Build NovaCore.xcframework from source
    # -----------------------------------------------------------
    log::info "PODS" "Building NovaCore.xcframework from source..."
    log::info "PODS" "This will take approximately 3-5 minutes..."

    # Check if build script exists
    local build_script="$ROOT_DIR/Scripts/xcframeworks/build_module.sh"
    if [[ ! -x "$build_script" ]]; then
        log::error "PODS" "Build script not found or not executable: $build_script"
        log::error "PODS" "Cannot build NovaCore.xcframework automatically"
        log::error "PODS" "Please build manually:"
        log::error "PODS" "  cd $ROOT_DIR"
        log::error "PODS" "  ./Scripts/xcframeworks/build_module.sh NovaCore"
        return 1
    fi

    # Build NovaCore.xcframework
    log::info "PODS" "Running: $build_script NovaCore"
    if "$build_script" NovaCore; then
        log::success "PODS" "NovaCore.xcframework built successfully"
    else
        log::error "PODS" "Failed to build NovaCore.xcframework"
        log::error "PODS" "Please check build logs and fix any build errors"
        log::error "PODS" "Common issues:"
        log::error "PODS" "  1. Missing dependencies (Kingfisher, MSPSnapKit, Lottie, etc.)"
        log::error "PODS" "  2. Code signing issues"
        log::error "PODS" "  3. Xcode version incompatibility"
        return 1
    fi

    # Verify build output
    if [[ ! -d "$novacore_build_path" ]]; then
        log::error "PODS" "NovaCore.xcframework was not created in expected location"
        log::error "PODS" "Expected: $novacore_build_path"
        return 1
    fi

    # Copy to Binary/ directory
    log::info "PODS" "Copying built XCFramework to Binary/ directory..."
    mkdir -p "$ROOT_DIR/Build/ReleaseArtifacts/Binary"

    if ditto "$novacore_build_path" "$novacore_binary_path"; then
        log::success "PODS" "NovaCore.xcframework deployed to Binary/"

        # Verify final deployment
        if [[ -f "$novacore_binary_path/Info.plist" ]]; then
            log::success "PODS" "NovaCore.xcframework is valid and ready for MSPNovaAdapter release"

            # Show framework size
            local framework_size
            framework_size=$(du -sh "$novacore_binary_path" 2>/dev/null | cut -f1)
            log::info "PODS" "Framework size: $framework_size"

            return 0
        else
            log::error "PODS" "Deployed NovaCore.xcframework is invalid (missing Info.plist)"
            return 1
        fi
    else
        log::error "PODS" "Failed to copy NovaCore.xcframework to Binary/"
        return 1
    fi
}

# ============================================================================
# Export Functions
# ============================================================================

export -f prebuild_novacore_dependencies 2>/dev/null || true
export -f ensure_novacore_xcframework 2>/dev/null || true
