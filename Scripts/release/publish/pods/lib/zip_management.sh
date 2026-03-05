#!/usr/bin/env bash
# ============================================================================
# ZIP Management Module
# ============================================================================
# Module: zip_management.sh
# Purpose: XCFramework ZIP creation, staleness detection, and verification
# Extracted from: publish.sh
#
# Functions:
#   - create_zip_from_xcframework: Create ZIP from XCFramework(s)
#   - get_zip_inputs_for_pod: Get input paths for ZIP creation
#   - latest_mtime: Get latest modification time for file/directory
#   - zip_needs_refresh: Check if ZIP needs to be recreated
#   - ensure_zip_file_exists_for_pod: Ensure ZIP exists with checksum verification
#
# Dependencies:
#   - zip CLI
#   - ditto (macOS)
#   - curl (for checksum verification)
#   - Logging functions (log::info, log::error, log::success, log::warn, log::debug)
#   - create_or_verify_github_release (from github_release.sh)
#   - upload_zip_to_github (from github_release.sh)
#   - wait_for_cdn_propagation, verify_cdn_availability (from cdn_verify.sh)
#   - unified_github_cli_auth_check (from publish.sh)
#   - is_binary_distribution (from publish.sh)
#
# Environment Variables:
#   - ROOT_DIR: Project root directory
#   - DRY_RUN: Skip actual operations (default: false)
#   - MSP_FORCE_REUPLOAD: Force re-upload even if ZIP exists (default: false)
#   - MSP_SKIP_ZIP_STALE_CHECK: Skip staleness check (default: false)
#   - MSP_CDN_WAIT_TIME: CDN propagation wait time in seconds
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_ZIP_MANAGEMENT_SOURCED:-}" ]] && return 0
readonly _ZIP_MANAGEMENT_SOURCED=1

# R031c: Source checksum module for unified SHA256 computation
_ZIP_MGMT_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
if [[ -f "$_ZIP_MGMT_ROOT_DIR/Scripts/lib/checksum.sh" ]]; then
    # shellcheck source=Scripts/lib/checksum.sh
    source "$_ZIP_MGMT_ROOT_DIR/Scripts/lib/checksum.sh" 2>/dev/null || true
fi

# ============================================================================
# Module Initialization
# ============================================================================

_zip_management_init() {
    # Verify required commands
    if ! command -v zip &>/dev/null; then
        echo "[ERROR] zip command not found" >&2
        return 1
    fi

    if ! command -v ditto &>/dev/null; then
        echo "[ERROR] ditto command not found (required on macOS)" >&2
        return 1
    fi

    # Verify logging functions
    if ! command -v log::info &>/dev/null; then
        echo "[ERROR] Logging functions not available. Source logger.sh first." >&2
        return 1
    fi

    return 0
}

# ============================================================================
# Internal Helper Functions
# ============================================================================

# Ensure each framework slice has a modulemap (ObjC @import support)
_ensure_modulemaps_in_xcframework() {
    local xcframework_path="$1"
    [[ -d "$xcframework_path" ]] || return

    find "$xcframework_path" -type d -name "*.framework" | while read -r framework_dir; do
        local module_name
        module_name="$(basename "$framework_dir" .framework)"
        local modulemap="$framework_dir/Modules/module.modulemap"

        if [[ ! -f "$modulemap" ]]; then
            mkdir -p "$(dirname "$modulemap")"
            cat > "$modulemap" <<EOF
framework module $module_name {
  export *
  module * { export * }
}
EOF
            log::warn "PODS" "Added missing module.modulemap for $module_name (pure Swift module)"
        fi
    done
}

# Ensure ObjC import works: add umbrella modulemap + Swift-generated header if missing
_ensure_objc_modulemap_and_header() {
    local xcframework_path="$1"
    local module_name="$2"
    [[ -d "$xcframework_path" ]] || return

    find "$xcframework_path" -type d -name "${module_name}.framework" | while read -r framework_dir; do
        # Skip embedded Frameworks/ to avoid touching dependencies
        if echo "$framework_dir" | grep -q "/Frameworks/"; then
            continue
        fi
        local modules_dir="$framework_dir/Modules"
        local headers_dir="$framework_dir/Headers"
        local modulemap="$modules_dir/module.modulemap"
        local umbrella="${module_name}-Swift.h"

        mkdir -p "$modules_dir" "$headers_dir"

        if [[ ! -f "$headers_dir/$umbrella" ]]; then
            cat > "$headers_dir/$umbrella" <<EOF
#pragma once
#import <Foundation/Foundation.h>
EOF
            log::warn "PODS" "Added stub umbrella header for $module_name: $headers_dir/$umbrella"
        fi

        cat > "$modulemap" <<EOF
framework module $module_name {
  umbrella header "$umbrella"
  export *
  module * { export * }
}
EOF
        log::warn "PODS" "Ensured umbrella modulemap for $module_name at $modulemap"
    done
}

# ============================================================================
# Public API
# ============================================================================

# Get input paths that are packaged into the zip for a given pod.
# Output: one path per line.
# @param $1 pod - Pod name
get_zip_inputs_for_pod() {
    local pod="$1"
    local root_dir="${ROOT_DIR:?ROOT_DIR not set}"

    case "$pod" in
        MSPSharedLibraries)
            echo "$root_dir/Build/ReleaseArtifacts/XCFrameworks/MSPSharedLibraries.xcframework"
            echo "$root_dir/Build/ReleaseArtifacts/XCFrameworks/MSPiOSCore.xcframework"
            echo "$root_dir/Build/ReleaseArtifacts/XCFrameworks/PrebidMobile.xcframework"
            echo "$root_dir/Build/ReleaseArtifacts/XCFrameworks/MSPSnapKit.xcframework"
            # Sources are included (optional) for dev mode; include them if present.
            if [[ -d "$root_dir/Sources" ]]; then
                echo "$root_dir/Sources"
            fi
            ;;
        MSPNovaAdapter)
            echo "$root_dir/Build/ReleaseArtifacts/XCFrameworks/MSPNovaAdapter.xcframework"
            echo "$root_dir/Build/ReleaseArtifacts/Binary/NovaCore.xcframework"
            ;;
        MSPCore)
            echo "$root_dir/Build/ReleaseArtifacts/XCFrameworks/MSPCore.xcframework"
            echo "$root_dir/Sources/Core/MSPCore/MSPCore/Resources/Config.plist"
            ;;
        MSPMolocoAdapter)
            echo "$root_dir/Build/ReleaseArtifacts/XCFrameworks/MSPMolocoAdapter.xcframework"
            ;;
        *)
            echo "$root_dir/Build/ReleaseArtifacts/XCFrameworks/${pod}.xcframework"
            ;;
    esac
}

# Get latest mtime (epoch seconds) for a file or directory (recursive for dirs).
# @param $1 path - File or directory path
# @return Latest modification time in epoch seconds
latest_mtime() {
    local path="$1"

    if [[ -f "$path" ]]; then
        stat -f %m "$path" 2>/dev/null || stat -c %Y "$path" 2>/dev/null || return 1
        return 0
    fi

    if [[ -d "$path" ]]; then
        local latest
        latest=$(find "$path" -type f -print0 2>/dev/null | xargs -0 stat -f %m 2>/dev/null | sort -n | tail -1)
        if [[ -z "$latest" ]]; then
            latest=$(stat -f %m "$path" 2>/dev/null || stat -c %Y "$path" 2>/dev/null || echo "")
        fi
        [[ -n "$latest" ]] && echo "$latest"
        return 0
    fi

    return 1
}

# Return 0 if zip needs refresh (missing or older than any input), else 1.
# @param $1 pod - Pod name
# @param $2 version - Version string
# @return 0 if refresh needed, 1 otherwise
zip_needs_refresh() {
    local pod="$1"
    local version="$2"
    local root_dir="${ROOT_DIR:?ROOT_DIR not set}"
    local zip_path="$root_dir/Build/Zips/${pod}-${version}.zip"

    if [[ ! -f "$zip_path" ]]; then
        log::info "PODS" "Local zip missing: $zip_path"
        return 0
    fi

    local zip_mtime
    zip_mtime=$(stat -f %m "$zip_path" 2>/dev/null || stat -c %Y "$zip_path" 2>/dev/null || echo "")
    if [[ -z "$zip_mtime" ]]; then
        log::warn "PODS" "Could not read zip mtime: $zip_path (treating as stale)"
        return 0
    fi

    local input_path
    while IFS= read -r input_path; do
        [[ -z "$input_path" ]] && continue
        if [[ ! -e "$input_path" ]]; then
            log::warn "PODS" "Zip input missing: $input_path (treating as stale)"
            return 0
        fi

        local input_mtime
        input_mtime=$(latest_mtime "$input_path" || echo "")
        if [[ -z "$input_mtime" ]]; then
            log::warn "PODS" "Could not read mtime for: $input_path (treating as stale)"
            return 0
        fi

        if (( input_mtime > zip_mtime )); then
            log::info "PODS" "Local zip stale: $input_path newer than $zip_path"
            return 0
        fi
    done < <(get_zip_inputs_for_pod "$pod")

    return 1
}

# Create zip file from XCFramework(s)
# @param $1 pod - Pod name
# @param $2 version - Version string
# @return 0 on success, 1 on failure
create_zip_from_xcframework() {
    local pod="$1"
    local version="$2"
    local zip_name="${pod}-${version}.zip"
    local root_dir="${ROOT_DIR:?ROOT_DIR not set}"

    log::info "PODS" "Creating zip file from XCFramework..."

    # Prepare temp directory with unique name
    local temp_zip_dir
    temp_zip_dir=$(mktemp -d "/tmp/msp_zip_${pod}_${version}_XXXXXX")

    if [[ -z "$temp_zip_dir" || ! -d "$temp_zip_dir" ]]; then
        log::error "PODS" "Failed to create temporary directory"
        return 1
    fi

    log::debug "PODS" "Created temporary directory: $temp_zip_dir (PID: $$, BASHPID: ${BASHPID:-N/A})"

    # Ensure cleanup on exit
    # shellcheck disable=SC2064  # We want $temp_zip_dir expanded now
    trap "rm -rf '$temp_zip_dir' 2>/dev/null || true" EXIT INT TERM

    # Check if zip command is available
    if ! command -v zip &>/dev/null; then
        log::error "PODS" "zip command not found"
        rm -rf "$temp_zip_dir"
        return 1
    fi

    # ========================================================================
    # Special handling for different pod types
    # ========================================================================
    case "$pod" in
        MSPSharedLibraries)
            log::info "PODS" "Special handling for MSPSharedLibraries (embeds MSPiOSCore)"
            mkdir -p "$temp_zip_dir/Binary"
            mkdir -p "$temp_zip_dir/ThirdParty/PrebidMobile"

            # Copy MSPSharedLibraries.xcframework
            local shared_lib_path="$root_dir/Build/ReleaseArtifacts/XCFrameworks/MSPSharedLibraries.xcframework"
            if [[ ! -d "$shared_lib_path" ]]; then
                log::error "PODS" "MSPSharedLibraries.xcframework not found: $shared_lib_path"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            if ! ditto "$shared_lib_path" "$temp_zip_dir/Binary/$(basename "$shared_lib_path")"; then
                log::error "PODS" "Failed to copy MSPSharedLibraries.xcframework"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            _ensure_modulemaps_in_xcframework "$temp_zip_dir/Binary/$(basename "$shared_lib_path")"

            # Copy embedded MSPiOSCore.xcframework
            local ios_core_path="$root_dir/Build/ReleaseArtifacts/XCFrameworks/MSPiOSCore.xcframework"
            if [[ ! -d "$ios_core_path" ]]; then
                log::error "PODS" "MSPiOSCore.xcframework not found: $ios_core_path"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            if ! ditto "$ios_core_path" "$temp_zip_dir/Binary/$(basename "$ios_core_path")"; then
                log::error "PODS" "Failed to copy MSPiOSCore.xcframework"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            _ensure_modulemaps_in_xcframework "$temp_zip_dir/Binary/$(basename "$ios_core_path")"
            _ensure_objc_modulemap_and_header "$temp_zip_dir/Binary/$(basename "$ios_core_path")" "MSPiOSCore"

            # Copy ThirdParty PrebidMobile
            local prebid_path="$root_dir/Build/ReleaseArtifacts/XCFrameworks/PrebidMobile.xcframework"
            if [[ ! -d "$prebid_path" ]]; then
                log::error "PODS" "PrebidMobile.xcframework not found: $prebid_path"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            if ! ditto "$prebid_path" "$temp_zip_dir/ThirdParty/PrebidMobile/$(basename "$prebid_path")"; then
                log::error "PODS" "Failed to copy PrebidMobile.xcframework"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            _ensure_modulemaps_in_xcframework "$temp_zip_dir/ThirdParty/PrebidMobile/$(basename "$prebid_path")"

            # Copy MSPSnapKit
            local snapkit_path="$root_dir/Build/ReleaseArtifacts/XCFrameworks/MSPSnapKit.xcframework"
            if [[ ! -d "$snapkit_path" ]]; then
                log::error "PODS" "MSPSnapKit.xcframework not found: $snapkit_path"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            mkdir -p "$temp_zip_dir/ThirdParty/MSPSnapKit"
            if ! ditto "$snapkit_path" "$temp_zip_dir/ThirdParty/MSPSnapKit/$(basename "$snapkit_path")"; then
                log::error "PODS" "Failed to copy MSPSnapKit.xcframework"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            _ensure_modulemaps_in_xcframework "$temp_zip_dir/ThirdParty/MSPSnapKit/$(basename "$snapkit_path")"

            # Copy OMSDK_Newsbreak1
            local omsdk_path="$root_dir/Sources/Core/MSPOMSDK/OMSDK_Newsbreak1.xcframework"
            if [[ ! -d "$omsdk_path" ]]; then
                log::error "PODS" "OMSDK_Newsbreak1.xcframework not found: $omsdk_path"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            mkdir -p "$temp_zip_dir/ThirdParty/OMSDK"
            if ! ditto "$omsdk_path" "$temp_zip_dir/ThirdParty/OMSDK/OMSDK_Newsbreak1.xcframework"; then
                log::error "PODS" "Failed to copy OMSDK_Newsbreak1.xcframework"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            _ensure_modulemaps_in_xcframework "$temp_zip_dir/ThirdParty/OMSDK/OMSDK_Newsbreak1.xcframework"
            log::success "PODS" "Copied OMSDK_Newsbreak1.xcframework"

            # Copy Sources (optional)
            if [[ -d "$root_dir/Sources" ]]; then
                ditto "$root_dir/Sources" "$temp_zip_dir/Sources" || log::warn "PODS" "Failed to copy Sources directory (non-critical)"
            fi

            log::success "PODS" "Prepared MSPSharedLibraries structure (with OMSDK)"
            ;;

        MSPiOSCore)
            mkdir -p "$temp_zip_dir/Binary"
            local xcframework_path="$root_dir/Build/ReleaseArtifacts/XCFrameworks/${pod}.xcframework"
            if [[ ! -d "$xcframework_path" ]]; then
                log::error "PODS" "XCFramework not found: $xcframework_path"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            if ! ditto "$xcframework_path" "$temp_zip_dir/Binary/$(basename "$xcframework_path")"; then
                log::error "PODS" "Failed to copy MSPiOSCore.xcframework"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            log::success "PODS" "Prepared MSPiOSCore structure"
            ;;

        MSPNovaAdapter)
            log::info "PODS" "MSPNovaAdapter: Binary adapter with embedded NovaCore dependency"
            mkdir -p "$temp_zip_dir/Binary"

            # Copy MSPNovaAdapter.xcframework
            local novaadapter_path="$root_dir/Build/ReleaseArtifacts/XCFrameworks/MSPNovaAdapter.xcframework"
            if [[ ! -d "$novaadapter_path" ]]; then
                log::error "PODS" "MSPNovaAdapter.xcframework not found: $novaadapter_path"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            if ! ditto "$novaadapter_path" "$temp_zip_dir/Binary/MSPNovaAdapter.xcframework"; then
                log::error "PODS" "Failed to copy MSPNovaAdapter.xcframework"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            log::success "PODS" "Copied MSPNovaAdapter.xcframework"

            # Copy NovaCore.xcframework
            local novacore_path="$root_dir/Build/ReleaseArtifacts/Binary/NovaCore.xcframework"
            if [[ ! -d "$novacore_path" ]]; then
                log::error "PODS" "NovaCore.xcframework not found: $novacore_path"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            if ! ditto "$novacore_path" "$temp_zip_dir/Binary/NovaCore.xcframework"; then
                log::error "PODS" "Failed to copy NovaCore.xcframework"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            log::success "PODS" "Copied NovaCore.xcframework"
            log::success "PODS" "Prepared MSPNovaAdapter structure (MSPNovaAdapter + NovaCore)"
            ;;

        MSPMolocoAdapter)
            log::info "PODS" "MSPMolocoAdapter: Binary adapter"
            mkdir -p "$temp_zip_dir/Binary"
            local xcframework_path="$root_dir/Build/ReleaseArtifacts/XCFrameworks/${pod}.xcframework"
            if [[ ! -d "$xcframework_path" ]]; then
                log::error "PODS" "XCFramework not found: $xcframework_path"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            if ! ditto "$xcframework_path" "$temp_zip_dir/Binary/$(basename "$xcframework_path")"; then
                log::error "PODS" "Failed to copy ${pod}.xcframework"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            _ensure_modulemaps_in_xcframework "$temp_zip_dir/Binary/$(basename "$xcframework_path")"
            log::success "PODS" "Prepared MSPMolocoAdapter structure"
            ;;

        MSPCore)
            # MSPCore: Binary XCFramework + Resources/Config.plist for getMSPVersion()
            # Config.plist must be outside the xcframework so CocoaPods resource_bundles
            # can package it into MSPCoreResources.bundle for the consumer app.
            mkdir -p "$temp_zip_dir/Binary" "$temp_zip_dir/Resources"
            local xcframework_path="$root_dir/Build/ReleaseArtifacts/XCFrameworks/MSPCore.xcframework"
            if [[ ! -d "$xcframework_path" ]]; then
                log::error "PODS" "XCFramework not found: $xcframework_path"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            if ! ditto "$xcframework_path" "$temp_zip_dir/Binary/$(basename "$xcframework_path")"; then
                log::error "PODS" "Failed to copy MSPCore.xcframework"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            _ensure_modulemaps_in_xcframework "$temp_zip_dir/Binary/$(basename "$xcframework_path")"
            _ensure_objc_modulemap_and_header "$temp_zip_dir/Binary/$(basename "$xcframework_path")" "MSPCore"

            local config_plist="$root_dir/Sources/Core/MSPCore/MSPCore/Resources/Config.plist"
            if [[ -f "$config_plist" ]]; then
                cp "$config_plist" "$temp_zip_dir/Resources/Config.plist"
                log::success "PODS" "Included Resources/Config.plist for MSPCoreResources bundle"
            else
                log::warn "PODS" "Config.plist not found: $config_plist (getMSPVersion will return empty)"
            fi
            log::success "PODS" "Prepared MSPCore structure"
            ;;

        *)
            # Default: Binary/<Pod>.xcframework
            mkdir -p "$temp_zip_dir/Binary"
            local xcframework_path="$root_dir/Build/ReleaseArtifacts/XCFrameworks/${pod}.xcframework"
            if [[ ! -d "$xcframework_path" ]]; then
                log::error "PODS" "XCFramework not found: $xcframework_path"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            if ! ditto "$xcframework_path" "$temp_zip_dir/Binary/$(basename "$xcframework_path")"; then
                log::error "PODS" "Failed to copy ${pod}.xcframework"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            _ensure_modulemaps_in_xcframework "$temp_zip_dir/Binary/$(basename "$xcframework_path")"
            if [[ "$pod" == "MSPiOSCore" ]]; then
                _ensure_objc_modulemap_and_header "$temp_zip_dir/Binary/$(basename "$xcframework_path")" "$pod"
            fi
            log::success "PODS" "Prepared $pod structure"
            ;;
    esac

    # ========================================================================
    # Create zip file
    # ========================================================================
    log::info "PODS" "Creating zip: $zip_name"

    # Pre-flight check: detect broken symbolic links
    local broken_links
    broken_links=$(find "$temp_zip_dir" -type l ! -exec test -e {} \; -print 2>/dev/null || true)
    if [[ -n "$broken_links" ]]; then
        log::warn "PODS" "Found broken symbolic links (will attempt to zip anyway):"
        echo "$broken_links" | while read -r link; do
            log::warn "PODS" "  - $link -> $(readlink "$link" 2>/dev/null || echo 'broken')"
        done
    fi

    local zip_error_output
    zip_error_output=$(mktemp)

    (
        cd "$temp_zip_dir" || exit 1

        # DETERMINISTIC ZIP: Normalize timestamps for reproducible checksums
        find . -exec touch -t 202001010000.00 {} \; 2>/dev/null

        # Exclude common problematic files
        if zip -X -r "$zip_name" . \
            -x '*.DS_Store' \
            -x '__MACOSX/*' \
            >/dev/null 2>"$zip_error_output"; then
            log::success "PODS" "Zip file created"
        else
            log::error "PODS" "Failed to create zip file"
            cat "$zip_error_output" >&2
            rm -f "$zip_error_output"
            exit 1
        fi
    )

    local zip_exit_code=$?
    rm -f "$zip_error_output"

    if [[ $zip_exit_code -ne 0 ]]; then
        rm -rf "$temp_zip_dir"
        return 1
    fi

    # Verify zip file was created and is not empty
    if [[ ! -f "$temp_zip_dir/$zip_name" ]]; then
        log::error "PODS" "Zip file was not created: $temp_zip_dir/$zip_name"
        rm -rf "$temp_zip_dir"
        return 1
    fi

    local zip_size
    zip_size=$(stat -f%z "$temp_zip_dir/$zip_name" 2>/dev/null || stat -c%s "$temp_zip_dir/$zip_name" 2>/dev/null || echo "0")

    if [[ $zip_size -eq 0 ]]; then
        log::error "PODS" "Zip file is empty: $temp_zip_dir/$zip_name"
        rm -rf "$temp_zip_dir"
        return 1
    fi

    log::info "PODS" "Zip file created successfully (size: $zip_size bytes)"

    # Move zip to Build/Zips
    mkdir -p "$root_dir/Build/Zips"
    mv "$temp_zip_dir/$zip_name" "$root_dir/Build/Zips/"

    # Cleanup
    rm -rf "$temp_zip_dir"

    log::success "PODS" "Zip created: Build/Zips/$zip_name"
    return 0
}

# Ensure ZIP file exists for a pod with full checksum verification
# @param $1 pod - Pod name
# @param $2 version - Version string
# @return 0 on success, 1 on failure
ensure_zip_file_exists_for_pod() {
    local pod="$1"
    local version="$2"
    local root_dir="${ROOT_DIR:?ROOT_DIR not set}"

    # Only check binary distribution pods
    if ! command -v is_binary_distribution &>/dev/null || ! is_binary_distribution "$pod"; then
        return 0
    fi

    log::step "PODS" "Ensuring zip file exists for $pod $version"

    local zip_url="https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/${pod}-${version}.zip"
    local zip_name="${pod}-${version}.zip"
    local local_zip_path="$root_dir/Build/Zips/$zip_name"

    # Step 0: Local zip staleness check
    local force_reupload="${MSP_FORCE_REUPLOAD:-false}"

    if [[ "${MSP_SKIP_ZIP_STALE_CHECK:-false}" != "true" ]]; then
        if zip_needs_refresh "$pod" "$version"; then
            if [[ "${DRY_RUN:-false}" == "true" ]]; then
                log::info "PODS" "DRY RUN: Would refresh local zip for $pod"
            else
                log::info "PODS" "Refreshing local zip for $pod (inputs updated)..."
                if ! create_zip_from_xcframework "$pod" "$version"; then
                    log::error "PODS" "Failed to refresh local zip for $pod"
                    return 1
                fi
            fi
            force_reupload=true
        fi
    fi

    # Step 1: Check if zip exists on GitHub
    log::info "PODS" "Checking zip file: $zip_url"

    local zip_exists=false
    if curl -L -f -I -s "$zip_url" >/dev/null 2>&1; then
        zip_exists=true
        log::info "PODS" "Zip file exists on GitHub Release"
    else
        log::warn "PODS" "Zip file not found on GitHub Release"
    fi

    # Step 2: Verify checksum if zip exists
    local need_reupload=false

    if [[ "$zip_exists" == "true" ]]; then
        if [[ "$force_reupload" == "true" ]]; then
            log::info "PODS" "Forcing reupload (MSP_FORCE_REUPLOAD=true or local zip refreshed)"
            need_reupload=true
        else
            log::info "PODS" "Verifying checksum (automatic CDN cache detection)..."

            local expected_checksum=""

            if [[ -f "$local_zip_path" ]]; then
                expected_checksum=$(if command -v checksum_compute_sha256 &>/dev/null; then checksum_compute_sha256 "$local_zip_path"; else shasum -a 256 "$local_zip_path" 2>/dev/null | awk '{print $1}'; fi)
                log::info "PODS" "Expected checksum (from local cache): $expected_checksum"
            else
                log::info "PODS" "Creating local zip to calculate expected checksum..."
                if ! create_zip_from_xcframework "$pod" "$version"; then
                    log::error "PODS" "Failed to create local zip for checksum calculation"
                    return 1
                fi
                expected_checksum=$(if command -v checksum_compute_sha256 &>/dev/null; then checksum_compute_sha256 "$local_zip_path"; else shasum -a 256 "$local_zip_path" 2>/dev/null | awk '{print $1}'; fi)
                log::info "PODS" "Expected checksum (newly calculated): $expected_checksum"
            fi

            # Download and verify
            log::info "PODS" "Downloading zip from GitHub to verify checksum..."
            local temp_verify="/tmp/msp-checksum-verify-$$"
            mkdir -p "$temp_verify"

            if curl -L -f -s -o "$temp_verify/verify.zip" "$zip_url" 2>/dev/null; then
                local actual_checksum
                actual_checksum=$(if command -v checksum_compute_sha256 &>/dev/null; then checksum_compute_sha256 "$temp_verify/verify.zip"; else shasum -a 256 "$temp_verify/verify.zip" 2>/dev/null | awk '{print $1}'; fi)
                rm -rf "$temp_verify"

                log::info "PODS" "Expected checksum: $expected_checksum"
                log::info "PODS" "GitHub checksum:   $actual_checksum"

                if [[ "$actual_checksum" == "$expected_checksum" ]]; then
                    log::success "PODS" "Checksum verified - zip is correct"
                    return 0
                else
                    log::warn "PODS" "CHECKSUM MISMATCH DETECTED (CDN cache issue)"
                    need_reupload=true
                fi
            else
                log::warn "PODS" "Failed to download zip for verification"
                rm -rf "$temp_verify"
                need_reupload=true
            fi
        fi
    else
        log::info "PODS" "Zip file not found, will create and upload"
        need_reupload=true
    fi

    # Step 3: Reupload if needed
    if [[ "$need_reupload" != "true" ]]; then
        return 0
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log::info "PODS" "DRY RUN: Would recreate and reupload zip file"
        return 0
    fi

    log::info "PODS" "Recreating and reuploading zip file..."

    # Delete existing zip from GitHub Release
    if [[ "$zip_exists" == "true" ]]; then
        log::info "PODS" "Deleting old zip from GitHub Release to clear CDN cache..."

        if command -v unified_github_cli_auth_check &>/dev/null && ! unified_github_cli_auth_check; then
            log::error "PODS" "GitHub CLI authentication failed"
            return 1
        fi

        gh release delete-asset "$version" "$zip_name" \
            --repo "ParticleMedia/msp-ios-sdk-public" \
            --yes 2>/dev/null || log::warn "PODS" "Failed to delete old zip (continuing anyway)"

        log::info "PODS" "Waiting 10 seconds for CDN to clear cache..."
        sleep 10
    fi

    # Create zip file
    if ! create_zip_from_xcframework "$pod" "$version"; then
        log::error "PODS" "Failed to create zip file from XCFramework"
        return 1
    fi

    local checksum
    checksum=$(if command -v checksum_compute_sha256 &>/dev/null; then checksum_compute_sha256 "$local_zip_path"; else shasum -a 256 "$local_zip_path" 2>/dev/null | awk '{print $1}'; fi)
    log::info "PODS" "SHA256: $checksum"

    # Upload to GitHub Release
    log::info "PODS" "Uploading zip file to GitHub Release..."

    if command -v create_or_verify_github_release &>/dev/null; then
        if ! create_or_verify_github_release "$version"; then
            log::error "PODS" "Failed to create/verify GitHub Release"
            return 1
        fi
    fi

    if command -v upload_zip_to_github &>/dev/null; then
        if ! upload_zip_to_github "$version" "$root_dir/Build/Zips/$zip_name"; then
            log::error "PODS" "Failed to upload zip file"
            return 0  # Return success to allow checksum calculation with local zip
        fi
    fi

    # Verify upload with CDN propagation
    log::info "PODS" "Verifying upload and waiting for CDN propagation..."

    local file_size_mb
    file_size_mb=$(du -m "$local_zip_path" 2>/dev/null | awk '{print $1}')

    local cdn_wait_time
    if [[ $file_size_mb -lt 5 ]]; then
        cdn_wait_time=60
    elif [[ $file_size_mb -lt 20 ]]; then
        cdn_wait_time=90
    else
        cdn_wait_time=120
    fi

    export MSP_CDN_WAIT_TIME=$cdn_wait_time
    log::info "PODS" "File size: ${file_size_mb}MB -> CDN wait time: ${cdn_wait_time}s"

    if command -v wait_for_cdn_propagation &>/dev/null; then
        wait_for_cdn_propagation "$version"
    fi

    if command -v verify_cdn_availability &>/dev/null; then
        if ! verify_cdn_availability "$version" "$zip_name"; then
            log::error "PODS" "Zip file not accessible on CDN"
            if [[ "${DRY_RUN:-false}" == "false" ]]; then
                return 1
            fi
        fi
    fi

    log::success "PODS" "Zip file upload verified"
    return 0
}

# Export functions
export -f get_zip_inputs_for_pod 2>/dev/null || true
export -f latest_mtime 2>/dev/null || true
export -f zip_needs_refresh 2>/dev/null || true
export -f create_zip_from_xcframework 2>/dev/null || true
export -f ensure_zip_file_exists_for_pod 2>/dev/null || true
