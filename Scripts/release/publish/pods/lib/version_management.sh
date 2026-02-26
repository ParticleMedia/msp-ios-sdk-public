#!/usr/bin/env bash
# ============================================================================
# Version Management Module
# ============================================================================
# Module: version_management.sh
# Purpose: Pod version updating, adapter SDK version management, podspec generation
# Extracted from: publish.sh
#
# Functions:
#   - get_module_dir: Map pod name to directory name
#   - load_adapter_sdk_version_config: Load adapter SDK version config
#   - adapter_sdk_version_should_skip: Check if adapter should skip version update
#   - resolve_adapter_sdk_version_tool: Get path to version update tool
#   - check_adapter_sdk_version: Verify adapter SDK version matches target
#   - update_adapter_sdk_version: Update adapter SDK version in source
#   - update_mspcore_version: Update MSPCore version
#   - update_podspec_for_release: Generate release podspec
#   - update_adapter_podspec_dependencies: Update podspec dependencies
#
# Dependencies:
#   - Logging functions (log::info, log::error, log::success, log::step, log::warn, log::debug)
#   - ROOT_DIR environment variable
#
# Environment Variables:
#   - ROOT_DIR: Project root directory
#   - ADAPTER_SDK_VERSION_CONFIG_FILE: Custom config file path (optional)
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_VERSION_MANAGEMENT_SOURCED:-}" ]] && return 0
readonly _VERSION_MANAGEMENT_SOURCED=1

# ============================================================================
# Module State
# ============================================================================

# Adapter SDK version configuration (config-driven)
ADAPTER_SDK_VERSION_CONFIG_LOADED="${ADAPTER_SDK_VERSION_CONFIG_LOADED:-false}"

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
# Adapter SDK Version Configuration
# ============================================================================

load_adapter_sdk_version_config() {
    if [[ "${ADAPTER_SDK_VERSION_CONFIG_LOADED:-false}" == "true" ]]; then
        return 0
    fi

    local config_file="${ADAPTER_SDK_VERSION_CONFIG_FILE:-$ROOT_DIR/Scripts/config/adapter_sdk_version.conf}"
    if [[ ! -f "$config_file" ]]; then
        log::error "PODS" "Adapter SDK version config not found: $config_file"
        return 1
    fi

    # shellcheck source=/dev/null
    source "$config_file"

    if [[ -z "${ADAPTER_SDK_VERSION_TOOL:-}" ]]; then
        log::error "PODS" "Adapter SDK version config missing ADAPTER_SDK_VERSION_TOOL"
        return 1
    fi
    if [[ -z "${ADAPTER_SDK_VERSION_FUNCTION:-}" ]]; then
        log::error "PODS" "Adapter SDK version config missing ADAPTER_SDK_VERSION_FUNCTION"
        return 1
    fi
    if [[ -z "${ADAPTER_SDK_VERSION_STRICT:-}" ]]; then
        log::error "PODS" "Adapter SDK version config missing ADAPTER_SDK_VERSION_STRICT"
        return 1
    fi
    ADAPTER_SDK_VERSION_CONFIG_LOADED="true"
    return 0
}

adapter_sdk_version_should_skip() {
    local adapter="$1"

    if ! load_adapter_sdk_version_config; then
        return 1
    fi

    if [[ -z "${ADAPTER_SDK_VERSION_SKIP_ADAPTERS:-}" ]]; then
        return 1
    fi

    if [[ " ${ADAPTER_SDK_VERSION_SKIP_ADAPTERS} " == *" ${adapter} "* ]]; then
        return 0
    fi

    return 1
}

resolve_adapter_sdk_version_tool() {
    if ! load_adapter_sdk_version_config; then
        return 1
    fi

    local tool="${ADAPTER_SDK_VERSION_TOOL}"
    if [[ "$tool" != /* ]]; then
        tool="$ROOT_DIR/$tool"
    fi

    if [[ ! -x "$tool" ]]; then
        log::error "PODS" "Adapter SDK version tool not found or not executable: $tool"
        return 1
    fi

    echo "$tool"
    return 0
}

# ============================================================================
# Adapter SDK Version Check and Update
# ============================================================================

check_adapter_sdk_version() {
    local adapter="$1"
    local version="$2"

    if adapter_sdk_version_should_skip "$adapter"; then
        log::info "PODS" "PUBLISH" "Skipping ${ADAPTER_SDK_VERSION_FUNCTION}() check for $adapter (config skip list)"
        return 0
    fi

    local module_dir
    module_dir=$(get_module_dir "$adapter")
    local adapter_dir="${ROOT_DIR}/Sources/Adapters/${module_dir}/${module_dir}"

    if [[ ! -d "$adapter_dir" ]]; then
        log::error "PODS" "PUBLISH" "Adapter directory not found: $adapter_dir"
        return 1
    fi

    local tool
    if ! tool=$(resolve_adapter_sdk_version_tool); then
        return 1
    fi

    if "$tool" --path "$adapter_dir" --function "$ADAPTER_SDK_VERSION_FUNCTION" --version "$version" --check; then
        return 0
    fi
    return $?
}

# Update adapter SDK version
update_adapter_sdk_version() {
    local adapter="$1"
    local version="$2"

    if adapter_sdk_version_should_skip "$adapter"; then
        log::info "PODS" "PUBLISH" "Skipping ${ADAPTER_SDK_VERSION_FUNCTION}() update for $adapter (config skip list)"
        return 0
    fi

    log::info "PODS" "PUBLISH" "Updating ${ADAPTER_SDK_VERSION_FUNCTION}() in $adapter to version $version"

    # Map pod name to directory name (for adapters with renamed modules)
    # Example: MSPAmazonAdapter (pod) → AmazonAdapter (directory)
    local module_dir
    module_dir=$(get_module_dir "$adapter")
    local adapter_dir="${ROOT_DIR}/Sources/Adapters/${module_dir}/${module_dir}"

    # Validate directory exists
    if [[ ! -d "$adapter_dir" ]]; then
        log::error "PODS" "PUBLISH" "Adapter directory not found: $adapter_dir"
        log::error "PODS" "PUBLISH" "Expected structure: Sources/Adapters/$module_dir/$module_dir/*.swift"
        log::error "PODS" "PUBLISH" "Pod name: $adapter, Directory name: $module_dir"
        return 1
    fi

    local tool
    if ! tool=$(resolve_adapter_sdk_version_tool); then
        return 1
    fi

    if "$tool" --path "$adapter_dir" --function "$ADAPTER_SDK_VERSION_FUNCTION" --version "$version"; then
        log::info "PODS" "PUBLISH" "✓ Updated ${ADAPTER_SDK_VERSION_FUNCTION}() for $adapter"
        return 0
    fi

    local rc=$?
    case "$rc" in
        2)
            log::warn "PODS" "PUBLISH" "No ${ADAPTER_SDK_VERSION_FUNCTION}() found in $adapter"
            ;;
        3)
            log::warn "PODS" "PUBLISH" "No string literal found inside ${ADAPTER_SDK_VERSION_FUNCTION}() for $adapter"
            ;;
        *)
            log::error "PODS" "PUBLISH" "Failed to update ${ADAPTER_SDK_VERSION_FUNCTION}() for $adapter (exit $rc)"
            ;;
    esac

    if [[ "${ADAPTER_SDK_VERSION_STRICT}" == "true" ]]; then
        return 1
    fi

    return 0
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
export -f load_adapter_sdk_version_config 2>/dev/null || true
export -f adapter_sdk_version_should_skip 2>/dev/null || true
export -f resolve_adapter_sdk_version_tool 2>/dev/null || true
export -f check_adapter_sdk_version 2>/dev/null || true
export -f update_adapter_sdk_version 2>/dev/null || true
export -f update_mspcore_version 2>/dev/null || true
export -f update_podspec_for_release 2>/dev/null || true
export -f update_adapter_podspec_dependencies 2>/dev/null || true
