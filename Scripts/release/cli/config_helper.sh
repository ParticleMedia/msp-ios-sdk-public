#!/usr/bin/env bash
# ============================================================================
# MSP Release CLI - Config Helper Module
# ============================================================================
# Purpose: Provides configuration loading and CLI override helpers
# Usage:   source Scripts/release/cli/config_helper.sh
#          msp_load_release_config
#          msp_apply_cli_overrides
#
# Dependencies:
#   - Scripts/release/utils/config.sh (config module)
#   - Scripts/lib/config_loader.sh (config loader)
#   - log::* functions (from common.sh)
#
# Globals Required (set by msp-release.sh before calling):
#   - CONFIG_FILE, CLI_VERSION, CLI_RELEASE_NOTES, CLI_BASE_BRANCH
#   - VERBOSE, DRY_RUN, SKIP_PREFLIGHT, NO_ANSI
#   - SKIP_PODS, SKIP_SPM, ONLY_PODS, ONLY_SPM, FORCE
#   - CONFIG_MODULE_LOADED
# ============================================================================

# Prevent multiple sourcing
[[ -n "${_MSP_CLI_CONFIG_HELPER_SOURCED:-}" ]] && return 0
readonly _MSP_CLI_CONFIG_HELPER_SOURCED=1

# Get script directory and ROOT_DIR
_CONFIG_HELPER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CONFIG_HELPER_ROOT_DIR="$(cd "$_CONFIG_HELPER_SCRIPT_DIR/../../.." && pwd)"

# Source dependencies if not already loaded
if ! command -v log::info &>/dev/null; then
    if [[ -f "$_CONFIG_HELPER_ROOT_DIR/Scripts/lib/common.sh" ]]; then
        # shellcheck source=Scripts/lib/common.sh
        source "$_CONFIG_HELPER_ROOT_DIR/Scripts/lib/common.sh" 2>/dev/null || true
    fi
fi

# ============================================================================
# Apply CLI Overrides
# ============================================================================
# @description Applies CLI flag values into exported config values
#              Implements priority: CLI flags > config file > built-in defaults
# @globals Uses CLI_VERSION, SKIP_PODS, ONLY_PODS, SKIP_SPM, ONLY_SPM,
#          DRY_RUN, VERBOSE, SKIP_PREFLIGHT, NO_ANSI, FORCE, CLI_RELEASE_NOTES
# @return Exports RELEASE_VERSION, PODS_ENABLED, SPM_ENABLED, etc.
msp_apply_cli_overrides() {
    local config_module_loaded="${CONFIG_MODULE_LOADED:-false}"

    # Version override
    if [[ -n "${CLI_VERSION:-}" ]]; then
        export RELEASE_VERSION="$CLI_VERSION"
        if [[ "$config_module_loaded" == "true" ]] && command -v set_config_version &>/dev/null; then
            set_config_version "$CLI_VERSION"
        fi
        log::debug "RELEASE" "[CLI] Override: RELEASE_VERSION=$CLI_VERSION"
    fi

    # Pods enabled override
    if [[ "${SKIP_PODS:-false}" == "true" ]]; then
        export PODS_ENABLED="false"
        if [[ "$config_module_loaded" == "true" ]] && command -v set_config_pods_enabled &>/dev/null; then
            set_config_pods_enabled "false"
        fi
        log::debug "RELEASE" "[CLI] Override: PODS_ENABLED=false"
    elif [[ "${ONLY_PODS:-false}" == "true" ]]; then
        export PODS_ENABLED="true"
        if [[ "$config_module_loaded" == "true" ]] && command -v set_config_pods_enabled &>/dev/null; then
            set_config_pods_enabled "true"
        fi
        log::debug "RELEASE" "[CLI] Override: PODS_ENABLED=true (only-pods)"
    fi

    # SPM enabled override
    if [[ "${SKIP_SPM:-false}" == "true" ]]; then
        export SPM_ENABLED="false"
        if [[ "$config_module_loaded" == "true" ]] && command -v set_config_spm_enabled &>/dev/null; then
            set_config_spm_enabled "false"
        fi
        log::debug "RELEASE" "[CLI] Override: SPM_ENABLED=false"
    elif [[ "${ONLY_SPM:-false}" == "true" ]]; then
        export SPM_ENABLED="true"
        if [[ "$config_module_loaded" == "true" ]] && command -v set_config_spm_enabled &>/dev/null; then
            set_config_spm_enabled "true"
        fi
        log::debug "RELEASE" "[CLI] Override: SPM_ENABLED=true (only-spm)"
    fi

    # Export other CLI flags
    export DRY_RUN="${DRY_RUN:-false}"
    export VERBOSE="${VERBOSE:-false}"
    export SKIP_PREFLIGHT="${SKIP_PREFLIGHT:-false}"
    export NO_ANSI="${NO_ANSI:-false}"
    export MSP_RELEASE_FORCE="${FORCE:-false}"

    # Base branch override (CLI flag has highest priority)
    if [[ -n "${CLI_BASE_BRANCH:-}" ]]; then
        export BASE_BRANCH="$CLI_BASE_BRANCH"
        if [[ "$config_module_loaded" == "true" ]] && command -v set_config_base_branch &>/dev/null; then
            set_config_base_branch "$CLI_BASE_BRANCH"
        fi
        log::debug "RELEASE" "[CLI] Override: BASE_BRANCH=$CLI_BASE_BRANCH"
    fi

    # T054: Export release notes from CLI (FR-016)
    if [[ -n "${CLI_RELEASE_NOTES:-}" ]]; then
        export RELEASE_NOTES="$CLI_RELEASE_NOTES"
        log::debug "RELEASE" "[CLI] Override: RELEASE_NOTES set via --release-notes"
    fi

    # T059: Verbose mode enables DEBUG level logging (FR-020)
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        export MSP_LOG_LEVEL=0  # DEBUG level
        log::debug "RELEASE" "[CLI] Override: MSP_LOG_LEVEL=0 (DEBUG) due to --verbose"
    fi

    log::debug "RELEASE" "[CLI] Applied all CLI overrides"
}

# ============================================================================
# Apply Verification Based on Release Mode
# ============================================================================
# @description Disables all verification steps when not in full mode
# @globals Uses MSP_RELEASE_MODE
# @return Exports MSP_VERIFY_* variables set to false when not full mode
msp_apply_disable_verification() {
    if [[ "${MSP_RELEASE_MODE:-simple}" != "full" ]]; then
        # Use unified MSP_VERIFY_* pattern (all false = skip verification)
        export MSP_VERIFY_LOCAL="false"
        export MSP_VERIFY_REMOTE="false"
        export MSP_VERIFY_DEVICE="false"
        export MSP_VERIFY_PODS="false"
        export MSP_VERIFY_SPM="false"
        export MSP_VERIFY_XCF="false"
        log::info "RELEASE" "Verification skipped (simple mode — use --full for verification)"
    fi
}

# ============================================================================
# Load Release Configuration
# ============================================================================
# @description Loads YAML config file and exports environment variables for later phases
#              Implements override priority: CLI args > YAML config > built-in defaults
# @globals Uses CONFIG_FILE, CONFIG_MODULE_LOADED, VERBOSE
# @return Exports configuration variables
msp_load_release_config() {
    local config_module_loaded="${CONFIG_MODULE_LOADED:-false}"

    # If config module is not available, skip config loading (backward compatibility)
    if [[ "$config_module_loaded" != "true" ]]; then
        log::debug "RELEASE" "[CONFIG] Config module not available - using CLI arguments only"
        return 0
    fi

    # Initialize defaults from config.sh
    if command -v init_config_defaults &>/dev/null; then
        init_config_defaults
    fi

    # Load config file if --config was provided AND config not already loaded
    # by the profile system (config_loader.sh). Skip reload to prevent function
    # collision: release-common.sh re-sources common.sh which overwrites
    # config_loader.sh's load_config with an incompatible version.
    if [[ -n "${CONFIG_FILE:-}" ]] && [[ -z "${_CONFIG_FIRST_LOAD_DONE:-}" ]]; then
        # Validate config file exists
        if [[ ! -f "$CONFIG_FILE" ]]; then
            log::error "RELEASE" "Config file not found: $CONFIG_FILE"
            exit 1
        fi

        # Resolve absolute path for clarity
        local config_abs_path
        config_abs_path="$(cd "$(dirname "$CONFIG_FILE")" && pwd)/$(basename "$CONFIG_FILE")"

        log::debug "RELEASE" "[CONFIG] Loading config from: $config_abs_path"

        # Parse YAML config file
        if command -v load_config &>/dev/null && ! load_config "$CONFIG_FILE"; then
            log::error "RELEASE" "Failed to parse config file: $CONFIG_FILE"
            exit 1
        fi

        if [[ "${VERBOSE:-false}" == "true" ]]; then
            log::info "RELEASE" "[CONFIG] Loaded from: $config_abs_path"
        fi
    else
        if [[ "${VERBOSE:-false}" == "true" ]]; then
            if [[ -n "${_CONFIG_FIRST_LOAD_DONE:-}" ]]; then
                log::info "RELEASE" "[CONFIG] Config already loaded by profile system - skipping reload"
            else
                log::info "RELEASE" "[CONFIG] No config file specified - using defaults"
            fi
        fi
    fi

    # Validate config (warnings only, not fatal)
    if command -v validate_config &>/dev/null; then
        validate_config || true
    fi

    # Export environment variables from config (before CLI overrides)
    # Note: Declare and assign separately to avoid masking return values (SC2155)
    if command -v get_config_version &>/dev/null; then
        local _cfg_version _cfg_release_branch _cfg_base_branch
        local _cfg_pods_enabled _cfg_spm_enabled _cfg_pods_modules _cfg_spm_packages
        local _cfg_slack_channel _cfg_dm_on_failure
        local _cfg_pods_remote_url _cfg_pods_remote_primary_product
        local _cfg_spm_remote_url _cfg_spm_remote_product_name _cfg_verify_spm_strict

        _cfg_version="$(get_config_version)"
        _cfg_release_branch="$(get_config_release_branch)"
        _cfg_base_branch="$(get_config_base_branch)"
        _cfg_pods_enabled="$(get_config_pods_enabled)"
        _cfg_spm_enabled="$(get_config_spm_enabled)"
        _cfg_pods_modules="$(get_config_pods_modules)"
        _cfg_spm_packages="$(get_config_spm_packages)"
        _cfg_slack_channel="$(get_config_slack_channel)"
        _cfg_dm_on_failure="$(get_config_dm_on_failure)"
        _cfg_pods_remote_url="$(get_config_pods_remote_url)"
        _cfg_pods_remote_primary_product="$(get_config_pods_remote_primary_product)"
        _cfg_spm_remote_url="$(get_config_spm_remote_url)"
        _cfg_spm_remote_product_name="$(get_config_spm_remote_product_name)"
        _cfg_verify_spm_strict="$(get_config_verify_spm_strict)"

        export RELEASE_VERSION="$_cfg_version"
        export RELEASE_BRANCH="$_cfg_release_branch"
        export BASE_BRANCH="${BASE_BRANCH:-$_cfg_base_branch}"
        export PODS_ENABLED="$_cfg_pods_enabled"
        export SPM_ENABLED="$_cfg_spm_enabled"
        export PODS_MODULES="$_cfg_pods_modules"
        export SPM_PACKAGES="$_cfg_spm_packages"
        export SLACK_CHANNEL="$_cfg_slack_channel"
        export DM_ON_FAILURE="$_cfg_dm_on_failure"
        export PODS_REMOTE_URL="$_cfg_pods_remote_url"
        export PODS_REMOTE_PRIMARY_PRODUCT="$_cfg_pods_remote_primary_product"
        export SPM_REMOTE_URL="$_cfg_spm_remote_url"
        export SPM_REMOTE_PRODUCT_NAME="$_cfg_spm_remote_product_name"
        export VERIFY_SPM_STRICT="$_cfg_verify_spm_strict"
    fi

    # Apply CLI overrides (CLI takes precedence)
    msp_apply_cli_overrides
    msp_apply_disable_verification

    # Print verbose debug output in requested format
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo ""
        echo "[CONFIG] Configuration Summary:"
        echo "[CONFIG]   version = ${RELEASE_VERSION:-<not set>}"
        echo "[CONFIG]   release_branch = ${RELEASE_BRANCH:-<auto>}"
        echo "[CONFIG]   base_branch = ${BASE_BRANCH:-<auto-detect current branch>}"
        echo "[CONFIG]   pods.enabled = ${PODS_ENABLED:-true}"
        echo "[CONFIG]   pods.modules = ${PODS_MODULES:-<default>}"
        echo "[CONFIG]   spm.enabled = ${SPM_ENABLED:-true}"
        echo "[CONFIG]   spm.packages = ${SPM_PACKAGES:-<default>}"
        echo "[CONFIG]   notifications.slack_channel = ${SLACK_CHANNEL:-#msp-release}"
        echo "[CONFIG]   notifications.dm_on_failure = ${DM_ON_FAILURE:-true}"
        echo ""
    fi
}

# Export functions
export -f msp_apply_cli_overrides 2>/dev/null || true
export -f msp_apply_disable_verification 2>/dev/null || true
export -f msp_load_release_config 2>/dev/null || true
