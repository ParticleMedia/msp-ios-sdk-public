#!/usr/bin/env bash
# ============================================================================
# Shared XCFramework Build Module (R024)
# ============================================================================
# Module: lib/shared/xcframework_build.sh
# Purpose: Unified XCFramework build operations
#
# Functions:
#   - xcf_get_build_settings: Get unified build settings for xcodebuild
#   - xcf_archive_for_platform: Archive framework for a specific platform
#   - xcf_create_from_archives: Create XCFramework from device/simulator archives
#   - xcf_build_with_retry: Execute build command with retry logic
#   - xcf_find_framework_in_archive: Locate framework within archive
#   - xcf_clean_build_artifacts: Clean up build artifacts
#
# Environment Variables:
#   - BUILD_XCFRAMEWORK_BUILD_TIMEOUT: Build timeout in seconds (default: 900)
#   - BUILD_DEVICE_ARCHITECTURES: Device architectures (default: arm64)
#   - BUILD_SIMULATOR_ARCHITECTURES: Simulator architectures (default: arm64,x86_64)
#   - MSP_XCFRAMEWORK_MAX_RETRIES: Max build retry attempts (default: 3)
#   - MSP_XCFRAMEWORK_RETRY_DELAY: Delay between retries (default: 5)
#   - CI: Set to "true" in CI environment (enables optimizations)
#
# Dependencies:
#   - xcodebuild CLI
#   - Logging functions (log::info, log::error, log::success) - optional
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_SHARED_XCFRAMEWORK_BUILD_SOURCED:-}" ]] && return 0
readonly _SHARED_XCFRAMEWORK_BUILD_SOURCED=1

# ============================================================================
# Configuration Defaults
# ============================================================================

XCFRAMEWORK_BUILD_DEFAULT_TIMEOUT=900
XCFRAMEWORK_BUILD_DEFAULT_DEVICE_ARCHS="arm64"
XCFRAMEWORK_BUILD_DEFAULT_SIMULATOR_ARCHS="arm64,x86_64"
XCFRAMEWORK_BUILD_DEFAULT_MAX_RETRIES=3
XCFRAMEWORK_BUILD_DEFAULT_RETRY_DELAY=5
XCFRAMEWORK_BUILD_DEFAULT_DEPLOYMENT_TARGET="15.0"

# ============================================================================
# Internal Helpers
# ============================================================================

_xcf_log() {
    local level="$1"
    local tag="${2:-XCF}"
    local msg="$3"

    if command -v "log::${level}" &>/dev/null; then
        "log::${level}" "$tag" "$msg"
    else
        echo "[$level][$tag] $msg" >&2
    fi
}

# ============================================================================
# Get Build Settings
# ============================================================================
# Returns common xcodebuild settings as an array
#
# Args:
#   $1: platform - "iphoneos" or "iphonesimulator"
#   $2: deployment_target - iOS deployment target (optional, default: 15.0)
#
# Output:
#   Prints build settings as space-separated key=value pairs
# ============================================================================
xcf_get_build_settings() {
    local platform="$1"
    local deployment_target="${2:-${BUILD_XCFRAMEWORK_DEPLOYMENT_TARGET:-$XCFRAMEWORK_BUILD_DEFAULT_DEPLOYMENT_TARGET}}"

    local settings=(
        "SKIP_INSTALL=NO"
        "BUILD_LIBRARY_FOR_DISTRIBUTION=YES"
        "IPHONEOS_DEPLOYMENT_TARGET=$deployment_target"
        "CODE_SIGNING_ALLOWED=NO"
        "CODE_SIGN_IDENTITY=-"
    )

    # CI-specific optimizations
    if [[ "${CI:-false}" == "true" ]]; then
        settings+=(
            "DEBUG_INFORMATION_FORMAT=dwarf"
            "GCC_OPTIMIZATION_LEVEL=s"
            "SWIFT_OPTIMIZATION_LEVEL=-O"
        )
    fi

    # Platform-specific settings
    if [[ "$platform" == "iphoneos" ]]; then
        local archs="${BUILD_DEVICE_ARCHITECTURES:-$XCFRAMEWORK_BUILD_DEFAULT_DEVICE_ARCHS}"
        settings+=("ARCHS=$archs")
    elif [[ "$platform" == "iphonesimulator" ]]; then
        local archs="${BUILD_SIMULATOR_ARCHITECTURES:-$XCFRAMEWORK_BUILD_DEFAULT_SIMULATOR_ARCHS}"
        settings+=("ARCHS=$archs")
    fi

    # Output as string
    echo "${settings[*]}"
}

# ============================================================================
# Build with Retry
# ============================================================================
# Executes a build command with configurable retry logic
#
# Args:
#   $1: description - Human-readable description for logging
#   $@: command - Command and arguments to execute
#
# Returns:
#   0 on success, 1 on failure after all retries
# ============================================================================
xcf_build_with_retry() {
    local description="$1"
    shift
    local cmd=("$@")

    local max_retries="${MSP_XCFRAMEWORK_MAX_RETRIES:-$XCFRAMEWORK_BUILD_DEFAULT_MAX_RETRIES}"
    local retry_delay="${MSP_XCFRAMEWORK_RETRY_DELAY:-$XCFRAMEWORK_BUILD_DEFAULT_RETRY_DELAY}"

    local attempt=1
    while [[ $attempt -le $max_retries ]]; do
        _xcf_log "info" "XCF" "[$attempt/$max_retries] $description"

        if "${cmd[@]}"; then
            _xcf_log "success" "XCF" "✓ $description completed"
            return 0
        else
            if [[ $attempt -lt $max_retries ]]; then
                _xcf_log "warn" "XCF" "Build failed, retrying in ${retry_delay}s..."
                sleep "$retry_delay"
            fi
        fi
        ((attempt++)) || true
    done

    _xcf_log "error" "XCF" "✗ $description failed after $max_retries attempts"
    return 1
}

# ============================================================================
# Archive for Platform
# ============================================================================
# Creates an archive for a specific platform using xcodebuild
#
# Args:
#   $1: project - Path to .xcodeproj or .xcworkspace
#   $2: scheme - Build scheme name
#   $3: platform - "iphoneos" or "iphonesimulator"
#   $4: archive_path - Output archive path (.xcarchive)
#   $5: extra_settings - Additional build settings (optional, space-separated)
#
# Returns:
#   0 on success, 1 on failure
# ============================================================================
xcf_archive_for_platform() {
    local project="$1"
    local scheme="$2"
    local platform="$3"
    local archive_path="$4"
    local extra_settings="${5:-}"

    _xcf_log "info" "XCF" "Archiving for $platform..."
    _xcf_log "info" "XCF" "  Project: $project"
    _xcf_log "info" "XCF" "  Scheme: $scheme"
    _xcf_log "info" "XCF" "  Output: $archive_path"

    # Verify project exists
    if [[ ! -e "$project" ]]; then
        _xcf_log "error" "XCF" "Project not found: $project"
        return 1
    fi

    # Determine project type
    local project_flag
    if [[ "$project" == *.xcworkspace ]]; then
        project_flag="-workspace"
    else
        project_flag="-project"
    fi

    # Get build settings
    local build_settings
    build_settings=$(xcf_get_build_settings "$platform")

    rm -rf "$archive_path"

    local cmd=(
        xcodebuild
        "$project_flag" "$project"
        -scheme "$scheme"
        -destination "generic/platform=${platform}"
        -archivePath "$archive_path"
        archive
    )

    # shellcheck disable=SC2086 -- intentional word-splitting: build_settings is a space-delimited flag list
    for setting in $build_settings; do
        cmd+=("$setting")
    done

    if [[ -n "$extra_settings" ]]; then
        # shellcheck disable=SC2086 -- intentional word-splitting: extra_settings is a space-delimited flag list
        for setting in $extra_settings; do
            cmd+=("$setting")
        done
    fi

    if xcf_build_with_retry "Archive for $platform" "${cmd[@]}"; then
        if [[ -d "$archive_path" ]]; then
            _xcf_log "success" "XCF" "✓ Archive created: $archive_path"
            return 0
        else
            _xcf_log "error" "XCF" "Archive not found after build: $archive_path"
            return 1
        fi
    else
        return 1
    fi
}

# ============================================================================
# Find Framework in Archive
# ============================================================================
# Locates the .framework directory within an archive
#
# Args:
#   $1: archive_path - Path to .xcarchive
#   $2: framework_name - Name of framework (without .framework extension)
#
# Output:
#   Prints path to .framework directory
#
# Returns:
#   0 if found, 1 if not found
# ============================================================================
xcf_find_framework_in_archive() {
    local archive_path="$1"
    local framework_name="$2"

    if [[ ! -d "$archive_path" ]]; then
        _xcf_log "error" "XCF" "Archive not found: $archive_path"
        return 1
    fi

    # Standard paths to search
    local search_paths=(
        "$archive_path/Products/Library/Frameworks/${framework_name}.framework"
        "$archive_path/Products/Library/Frameworks/${framework_name}.xcframework"
        "$archive_path/Products/usr/local/lib/${framework_name}.framework"
    )

    # Check standard paths first
    for path in "${search_paths[@]}"; do
        if [[ -d "$path" ]]; then
            echo "$path"
            return 0
        fi
    done

    # Fallback: Search with find
    local found_path
    found_path=$(find "$archive_path" -name "${framework_name}.framework" -type d 2>/dev/null | head -1)

    if [[ -n "$found_path" ]] && [[ -d "$found_path" ]]; then
        echo "$found_path"
        return 0
    fi

    _xcf_log "error" "XCF" "Framework not found in archive: ${framework_name}.framework"
    _xcf_log "info" "XCF" "Searched in: $archive_path"
    return 1
}

# ============================================================================
# Create XCFramework from Archives
# ============================================================================
# Creates an XCFramework from device and simulator archives
#
# Args:
#   $1: framework_name - Name of the framework
#   $2: device_archive - Path to device .xcarchive
#   $3: simulator_archive - Path to simulator .xcarchive
#   $4: output_path - Output XCFramework path
#
# Returns:
#   0 on success, 1 on failure
# ============================================================================
xcf_create_from_archives() {
    local framework_name="$1"
    local device_archive="$2"
    local simulator_archive="$3"
    local output_path="$4"

    _xcf_log "info" "XCF" "Creating XCFramework: $framework_name"
    _xcf_log "info" "XCF" "  Device archive: $device_archive"
    _xcf_log "info" "XCF" "  Simulator archive: $simulator_archive"
    _xcf_log "info" "XCF" "  Output: $output_path"

    # Find frameworks in archives
    local device_framework
    local simulator_framework

    device_framework=$(xcf_find_framework_in_archive "$device_archive" "$framework_name") || return 1
    simulator_framework=$(xcf_find_framework_in_archive "$simulator_archive" "$framework_name") || return 1

    rm -rf "$output_path"

    mkdir -p "$(dirname "$output_path")"

    local cmd=(
        xcodebuild
        -create-xcframework
        -framework "$device_framework"
        -framework "$simulator_framework"
        -output "$output_path"
    )

    _xcf_log "info" "XCF" "Running: xcodebuild -create-xcframework..."

    if "${cmd[@]}" 2>&1; then
        if [[ -d "$output_path" ]]; then
            _xcf_log "success" "XCF" "✓ XCFramework created: $output_path"
            return 0
        else
            _xcf_log "error" "XCF" "XCFramework not found after creation: $output_path"
            return 1
        fi
    else
        _xcf_log "error" "XCF" "✗ Failed to create XCFramework"
        return 1
    fi
}

# ============================================================================
# Clean Build Artifacts
# ============================================================================
# Cleans up temporary build artifacts
#
# Args:
#   $@: paths - Paths to clean
# ============================================================================
xcf_clean_build_artifacts() {
    local paths=("$@")

    for path in "${paths[@]}"; do
        if [[ -e "$path" ]]; then
            _xcf_log "info" "XCF" "Cleaning: $path"
            rm -rf "$path"
        fi
    done
}

# ============================================================================
# Build Complete XCFramework (Convenience Function)
# ============================================================================
# Full workflow: archive for both platforms, create xcframework
#
# Args:
#   $1: project - Path to .xcodeproj or .xcworkspace
#   $2: scheme - Build scheme name
#   $3: framework_name - Name of the framework
#   $4: output_path - Output XCFramework path
#   $5: archive_base_path - Base path for temporary archives (optional)
#
# Returns:
#   0 on success, 1 on failure
# ============================================================================
xcf_build_complete() {
    local project="$1"
    local scheme="$2"
    local framework_name="$3"
    local output_path="$4"
    local archive_base="${5:-/tmp/xcf-build-$$}"

    local device_archive="$archive_base/${framework_name}-device.xcarchive"
    local simulator_archive="$archive_base/${framework_name}-simulator.xcarchive"

    _xcf_log "info" "XCF" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    _xcf_log "info" "XCF" "Building XCFramework: $framework_name"
    _xcf_log "info" "XCF" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Step 1: Archive for device
    _xcf_log "info" "XCF" ""
    _xcf_log "info" "XCF" "Step 1/3: Archive for iOS device"
    if ! xcf_archive_for_platform "$project" "$scheme" "iphoneos" "$device_archive"; then
        xcf_clean_build_artifacts "$device_archive" "$simulator_archive"
        return 1
    fi

    # Step 2: Archive for simulator
    _xcf_log "info" "XCF" ""
    _xcf_log "info" "XCF" "Step 2/3: Archive for iOS simulator"
    if ! xcf_archive_for_platform "$project" "$scheme" "iphonesimulator" "$simulator_archive"; then
        xcf_clean_build_artifacts "$device_archive" "$simulator_archive"
        return 1
    fi

    # Step 3: Create XCFramework
    _xcf_log "info" "XCF" ""
    _xcf_log "info" "XCF" "Step 3/3: Create XCFramework"
    if ! xcf_create_from_archives "$framework_name" "$device_archive" "$simulator_archive" "$output_path"; then
        xcf_clean_build_artifacts "$device_archive" "$simulator_archive"
        return 1
    fi

    # Cleanup
    xcf_clean_build_artifacts "$device_archive" "$simulator_archive"

    _xcf_log "success" "XCF" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    _xcf_log "success" "XCF" "XCFramework Build Complete ✓"
    _xcf_log "success" "XCF" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    return 0
}

# ============================================================================
# Export Functions
# ============================================================================

export -f xcf_get_build_settings 2>/dev/null || true
export -f xcf_build_with_retry 2>/dev/null || true
export -f xcf_archive_for_platform 2>/dev/null || true
export -f xcf_find_framework_in_archive 2>/dev/null || true
export -f xcf_create_from_archives 2>/dev/null || true
export -f xcf_clean_build_artifacts 2>/dev/null || true
export -f xcf_build_complete 2>/dev/null || true
