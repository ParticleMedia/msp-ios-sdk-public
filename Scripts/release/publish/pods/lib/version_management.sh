#!/usr/bin/env bash
# ============================================================================
# Version Management Module
# ============================================================================
# Module: version_management.sh
# Purpose: Pod version updating, podspec generation
# Extracted from: publish.sh
#
# Functions:
#   - get_module_dir: Map pod name to directory name
#   - update_mspcore_version: Update MSPCore version
#   - update_podspec_for_release: Generate release podspec
#   - update_adapter_podspec_dependencies: Update podspec dependencies
#
# Note: Adapter SDK version functions (load_adapter_sdk_version_config,
# adapter_sdk_version_should_skip, resolve_adapter_sdk_version_tool,
# check_adapter_sdk_version, update_adapter_sdk_version) have been removed.
# Adapter SDK versions are now read at runtime from each third-party SDK.
#
# Dependencies:
#   - Logging functions (log::info, log::error, log::success, log::step, log::warn, log::debug)
#   - ROOT_DIR environment variable
#
# Environment Variables:
#   - ROOT_DIR: Project root directory
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_VERSION_MANAGEMENT_SOURCED:-}" ]] && return 0
readonly _VERSION_MANAGEMENT_SOURCED=1

# ============================================================================
# Pod Name → Directory Name Mapping
# ============================================================================
# Some adapters have different pod names vs directory names
# Example: MSPAmazonAdapter (pod) → AmazonAdapter (directory)
# Note: XCFramework name now matches pod name (MSPAmazonAdapter.xcframework)

get_module_dir() {
    local pod_name="$1"
    case "$pod_name" in
        "MSPAmazonAdapter") echo "AmazonAdapter" ;;
        "MSPMolocoAdapter") echo "MolocoAdapter" ;;
        "MSPLiftoffAdapter") echo "LiftoffAdapter" ;;
        "MSPNovaAdapter") echo "NovaAdapter" ;;
        *) echo "$pod_name" ;;
    esac
}

# ============================================================================
# MSPCore Version Update
# ============================================================================

update_mspcore_version() {
    local version="$1"

    log::info "PODS" "Skipping MSPCore version property update (reads from Config.plist)"
    # MSP class version is read from Config.plist, so we don't need to update the code
    # The version will be updated via update_config_plist_version function instead
}

# ============================================================================
# Podspec Functions
# ============================================================================

update_podspec_for_release() {
    local pod="$1"
    local version="$2"

    log::step "PODS" "Generating release podspec for $pod version $version"

    # Call the podspec generator script
    if [[ ! -x "$ROOT_DIR/Scripts/release/generate_podspec.sh" ]]; then
        log::error "PODS" "Podspec generator script not found or not executable"
        return 1
    fi

    # Generate the release podspec
    if ! "$ROOT_DIR/Scripts/release/generate_podspec.sh" "$pod" "$version"; then
        log::error "PODS" "Failed to generate release podspec for $pod"
        return 1
    fi

    log::success "PODS" "Generated release podspec for $pod at Build/ReleasePodspecs/${pod}.podspec"
}

# Local version for adapter release (2 params: pod, version)
# Renamed to avoid conflict with utils/podspec.sh version (3 params)
update_adapter_podspec_dependencies() {
    local pod="$1"
    local version="$2"

    # ========================================================================
    # DEBUG: Diagnose ROOT_DIR issue in subprocess
    # ========================================================================
    log::info "PODS" "[DEBUG] update_adapter_podspec_dependencies called for: $pod"
    log::info "PODS" "[DEBUG] ROOT_DIR value: '${ROOT_DIR:-<EMPTY>}'"
    log::info "PODS" "[DEBUG] PWD: $(pwd)"

    # CRITICAL FIX: Ensure ROOT_DIR is set (same logic as release_single_adapter)
    if [[ -z "${ROOT_DIR:-}" ]]; then
        log::warn "PODS" "[DEBUG] ROOT_DIR is empty, attempting to resolve..."

        # Try git method first
        if command -v git >/dev/null 2>&1; then
            ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
            if [[ -n "$ROOT_DIR" ]]; then
                log::info "PODS" "[DEBUG] ROOT_DIR resolved via git: $ROOT_DIR"
            fi
        fi

        # Fallback to relative path
        if [[ -z "${ROOT_DIR:-}" ]]; then
            # This function is called from release_single_adapter
            # which is in Scripts/release/publish/pods/publish.sh
            ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
            log::info "PODS" "[DEBUG] ROOT_DIR resolved via relative path: $ROOT_DIR"
        fi

        export ROOT_DIR
    else
        log::info "PODS" "[DEBUG] ROOT_DIR already set: $ROOT_DIR"
    fi

    # Use generated podspec from Build/ReleasePodspecs/ (not source podspec)
    local podspec="$ROOT_DIR/Build/ReleasePodspecs/${pod}.podspec"

    log::info "PODS" "[DEBUG] Constructed podspec path: $podspec"
    log::info "PODS" "[DEBUG] Checking if file exists..."

    if [[ ! -f "$podspec" ]]; then
        log::error "PODS" "Podspec file not found: $podspec"
        log::error "PODS" "[DEBUG] File does not exist at expected location"
        log::error "PODS" "[DEBUG] Listing Build/ReleasePodspecs/ contents:"
        if [[ -d "$ROOT_DIR/Build/ReleasePodspecs/" ]]; then
            ls -la "$ROOT_DIR/Build/ReleasePodspecs/" 2>/dev/null || echo "  Failed to list directory"
        else
            log::error "PODS" "[DEBUG] Directory does not exist: $ROOT_DIR/Build/ReleasePodspecs/"
        fi
        log::error "PODS" "Make sure update_podspec_for_release() was called first"
        return 1
    fi

    log::info "PODS" "[DEBUG] ✅ Podspec file found: $podspec"
    # ========================================================================
    # END DEBUG
    # ========================================================================

    log::step "PODS" "Updating dependencies in $podspec"

    # Update MSPSharedLibraries dependency - handle both with and without version
    if grep -q "spec\.dependency.*MSPSharedLibraries" "$podspec"; then
        # Remove any existing version(s) and comments, then add the new one
        sed -i '' "s|spec\.dependency 'MSPSharedLibraries'[^#]*|spec.dependency 'MSPSharedLibraries'|g" "$podspec"
        sed -i '' "s|spec\.dependency 'MSPSharedLibraries'|spec.dependency 'MSPSharedLibraries', '${version}'|g" "$podspec"
        log::info "PODS" "Updated MSPSharedLibraries dependency to $version"
    fi

    # Update PrebidAdapter dependency - handle both with and without version
    if grep -q "spec\.dependency.*PrebidAdapter" "$podspec"; then
        # Remove any existing version(s) and comments, then add the new one
        sed -i '' "s|spec\.dependency 'PrebidAdapter'[^#]*|spec.dependency 'PrebidAdapter'|g" "$podspec"
        sed -i '' "s|spec\.dependency 'PrebidAdapter'|spec.dependency 'PrebidAdapter', '${version}'|g" "$podspec"
        log::info "PODS" "Updated PrebidAdapter dependency to $version"
    fi

    # Stage B: MSPOMSDK removed - OMSDK now embedded in NovaCore
    # No longer need to handle MSPOMSDK dependency
}

# ============================================================================
# Export Functions
# ============================================================================

export -f get_module_dir 2>/dev/null || true
export -f update_mspcore_version 2>/dev/null || true
export -f update_podspec_for_release 2>/dev/null || true
export -f update_adapter_podspec_dependencies 2>/dev/null || true
