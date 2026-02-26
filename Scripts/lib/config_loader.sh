#!/usr/bin/env bash
# ============================================================================
# Config Loader - YAML Configuration Loading with Profile Support
# ============================================================================
#
# Loads configuration from Scripts/config/release.yaml with profile support.
# Supports consolidated schema v2 with profiles, modules, and verification.
#
# Usage:
#   source Scripts/lib/config_loader.sh
#   load_config "production"
#   echo "$DRY_RUN"  # Prints: false
#
# Profile precedence:
#   1. Environment variables (highest priority)
#   2. Selected profile
#   3. Default profile
#   4. Hardcoded defaults (lowest priority)
#
# Schema Version: 2 (consolidated)
# ============================================================================

set -euo pipefail

# ============================================================================
# Configuration (using path-helpers.sh and common.sh for logging)
# ============================================================================

# shellcheck source=Scripts/lib/path-helpers.sh
source "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/path-helpers.sh"

# shellcheck source=Scripts/lib/common.sh
source "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/common.sh"

# Config file path (use ROOT_DIR if available, otherwise relative)
if [[ -n "${ROOT_DIR:-}" ]]; then
    CONFIG_FILE="${MSP_CONFIG_FILE:-$ROOT_DIR/Scripts/config/release.yaml}"
else
    CONFIG_FILE="${MSP_CONFIG_FILE:-Scripts/config/release.yaml}"
fi

# Schema version
REQUIRED_SCHEMA_VERSION=2

# Default values (fallback if config file not found)
DEFAULT_PROFILE="local-dev"
DEFAULT_DRY_RUN="true"
DEFAULT_LOG_LEVEL="info"
DEFAULT_LOG_FORMAT="pretty"

# ============================================================================
# YAML Parser (Simple)
# ============================================================================
#
# Simple YAML parser for our specific config structure.
# Supports:
# - Nested keys (profiles.production.dry_run)
# - Boolean values (true, false)
# - String values
# - Integer values
# - Array items (prefixed with _item_N)
#
# Does NOT support:
# - Multi-line strings
# - Anchors/aliases
# ============================================================================

# @description Parse a YAML file into shell variable assignments.
#              Handles nested keys and array items.
# @param $1 yaml_file - Path to the YAML file
# @param $2 prefix - Optional prefix for generated variable names (default: "")
# @return Variable assignments via stdout, suitable for eval
parse_yaml() {
    local yaml_file="$1"
    local prefix="${2:-}"

    if [[ ! -f "$yaml_file" ]]; then
        return 1
    fi

    local s='[[:space:]]*'
    local w='[a-zA-Z0-9_-]*'
    local fs=$(echo @|tr @ '\034')

    # Remove comments and process YAML
    sed -e 's/#.*$//' -e '/^[[:space:]]*$/d' "$yaml_file" | \
    sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)-$s[\"']\(.*\)[\"']$s\$|\1${fs}_item${fs}\2|p" \
        -e "s|^\($s\)-$s\(.*\)$s\$|\1${fs}_item${fs}\2|p" |
    awk -F"$fs" '
    BEGIN { item_count = 0 }
    {
        indent = length($1)/2;
        # Replace hyphens with underscores in keys
        key = $2;
        gsub(/-/, "_", key);

        # Handle array items
        if (key == "_item") {
            vname[indent] = "_item_" item_count;
            item_count++;
        } else {
            vname[indent] = key;
            item_count = 0;  # Reset for new key
        }

        for (i in vname) {if (i > indent) {delete vname[i]}}
        value = $3;
        # Trim leading/trailing whitespace from value
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value);
        if (length(value) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            # Use current key (may include _item_N)
            printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, vname[indent], value);
        }
    }'
}

# ============================================================================
# Config Loading
# ============================================================================

# @description Load configuration from release.yaml with profile support.
#              Applies: defaults → profile values → env overrides.
# @param $1 profile - Profile name (optional, uses default_profile if not set)
# @return 0 on success, 1 on parse error
load_config() {
    local profile="${1:-}"

    # Save original DRY_RUN value only if it was explicitly set before first load_config call
    # This ensures environment variable overrides work correctly while not persisting
    # values from previous load_config calls
    # Guard variables - do NOT export (each process should have its own config state)
    if [[ -z "${_CONFIG_FIRST_LOAD_DONE:-}" ]]; then
        # First time load_config is called - save original DRY_RUN if set
        if [[ -n "${DRY_RUN:-}" ]]; then
            _SAVED_DRY_RUN="${DRY_RUN}"
            _DRY_RUN_WAS_SET=1
        else
            _DRY_RUN_WAS_SET=0
        fi
        _CONFIG_FIRST_LOAD_DONE=1
    fi

    # Check if config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log::warn "CONFIG" "Config file not found: $CONFIG_FILE"
        log::warn "CONFIG" "Using default values and environment variables only"
        _load_defaults
        _load_env_overrides
        return 0
    fi

    # Parse YAML and extract config
    local config_vars
    config_vars=$(parse_yaml "$CONFIG_FILE" "CONFIG_")

    if [[ -z "$config_vars" ]]; then
        log::error "CONFIG" "Failed to parse config file: $CONFIG_FILE"
        return 1
    fi

    # Load config into environment
    eval "$config_vars"

    # Validate schema version
    if [[ "${CONFIG_schema_version:-1}" != "$REQUIRED_SCHEMA_VERSION" ]]; then
        log::warn "CONFIG" "Config schema version mismatch: expected $REQUIRED_SCHEMA_VERSION, got ${CONFIG_schema_version:-1}"
        log::warn "CONFIG" "Some features may not work correctly"
    fi

    # Determine profile to use
    if [[ -z "$profile" ]]; then
        profile="${CONFIG_default_profile:-$DEFAULT_PROFILE}"
    fi

    log::debug "CONFIG" "Loading config for profile: $profile"

    # Extract profile-specific values
    _extract_profile_config "$profile"

    # Extract metadata (version, branch config)
    _extract_metadata

    # Extract module configuration
    _extract_module_config

    # Extract verification configuration
    _extract_verify_config

    # Apply environment variable overrides (highest priority)
    _load_env_overrides

    # Validate configuration
    _validate_config

    log::success "CONFIG" "Configuration loaded successfully (profile: $profile)"
}

# @description Load hardcoded default values for all config variables.
#              Used as fallback when config file is not found.
_load_defaults() {
    DRY_RUN="${DRY_RUN:-$DEFAULT_DRY_RUN}"
    MSP_LOG_LEVEL="${MSP_LOG_LEVEL:-$DEFAULT_LOG_LEVEL}"
    MSP_LOG_FORMAT="${MSP_LOG_FORMAT:-$DEFAULT_LOG_FORMAT}"

    MSP_VALIDATION_PREFLIGHT="${MSP_VALIDATION_PREFLIGHT:-basic}"

    MSP_SLACK_ENABLED="${MSP_SLACK_ENABLED:-true}"
    MSP_SLACK_ENV="${MSP_SLACK_ENV:-prod}"
    MSP_EMAIL_ENABLED="${MSP_EMAIL_ENABLED:-false}"

    MSP_ALLOW_EXISTING_TAG="${MSP_ALLOW_EXISTING_TAG:-true}"
    MSP_ALLOW_EXISTING_RELEASE="${MSP_ALLOW_EXISTING_RELEASE:-true}"
    MSP_KEEP_SANDBOX="${MSP_KEEP_SANDBOX:-true}"

    MSP_PARALLEL_BUILDS="${MSP_PARALLEL_BUILDS:-true}"
    MSP_MAX_WORKERS="${MSP_MAX_WORKERS:-4}"
    MSP_CDN_WAIT_TIME="${MSP_CDN_WAIT_TIME:-60}"

    # Module config defaults
    MSP_PODS_ENABLED="${MSP_PODS_ENABLED:-true}"
    MSP_SPM_ENABLED="${MSP_SPM_ENABLED:-true}"

    # Verify config defaults
    MSP_SANDBOX_DIR="${MSP_SANDBOX_DIR:-/tmp/msp-verify-sandbox}"
    MSP_VERIFY_LOCAL="${MSP_VERIFY_LOCAL:-true}"
    MSP_VERIFY_REMOTE_PODS="${MSP_VERIFY_REMOTE_PODS:-true}"
    MSP_VERIFY_REMOTE_SPM="${MSP_VERIFY_REMOTE_SPM:-true}"
    MSP_VERIFY_SAMPLE_APP="${MSP_VERIFY_SAMPLE_APP:-true}"
    MSP_VERIFY_DEVICE="${MSP_VERIFY_DEVICE:-false}"
    MSP_SPM_STRICT="${MSP_SPM_STRICT:-true}"

    _export_all_vars
}

# @description Extract release metadata (version, branch config) from parsed config.
_extract_metadata() {
    # Extract release metadata
    MSP_VERSION="${CONFIG_version:-}"
    MSP_RELEASE_BRANCH="${CONFIG_release_branch:-}"
    MSP_BASE_BRANCH="${CONFIG_base_branch:-main}"

    export MSP_VERSION MSP_RELEASE_BRANCH MSP_BASE_BRANCH
}

# @description Extract profile-specific configuration values.
# @param $1 profile - Profile name (e.g., "production", "local-dev")
_extract_profile_config() {
    local profile="$1"

    # Replace hyphens with underscores for variable names
    local profile_var="${profile//-/_}"

    # Build variable name prefix for this profile
    local prefix="CONFIG_profiles_${profile_var}_"

    # Core Release Control
    local var_dry_run="${prefix}dry_run"
    DRY_RUN="${!var_dry_run:-$DEFAULT_DRY_RUN}"

    # Validation Control (simplified to preflight level)
    local var_validation_preflight="${prefix}validation_preflight"
    MSP_VALIDATION_PREFLIGHT="${!var_validation_preflight:-basic}"

    # Notification Control
    local var_slack_enabled="${prefix}notifications_slack_enabled"
    local var_slack_env="${prefix}notifications_slack_env"
    local var_email_enabled="${prefix}notifications_email_enabled"
    MSP_SLACK_ENABLED="${!var_slack_enabled:-true}"
    MSP_SLACK_ENV="${!var_slack_env:-prod}"
    MSP_EMAIL_ENABLED="${!var_email_enabled:-false}"

    # Logging
    local var_log_level="${prefix}logging_level"
    local var_log_format="${prefix}logging_format"
    MSP_LOG_LEVEL="${!var_log_level:-$DEFAULT_LOG_LEVEL}"
    MSP_LOG_FORMAT="${!var_log_format:-$DEFAULT_LOG_FORMAT}"

    # Safety Controls
    local var_allow_tag="${prefix}safety_allow_existing_tag"
    local var_allow_release="${prefix}safety_allow_existing_release"
    local var_keep_sandbox="${prefix}safety_keep_sandbox"
    local var_require_ci="${prefix}safety_require_ci"
    MSP_ALLOW_EXISTING_TAG="${!var_allow_tag:-true}"
    MSP_ALLOW_EXISTING_RELEASE="${!var_allow_release:-true}"
    MSP_KEEP_SANDBOX="${!var_keep_sandbox:-true}"
    MSP_REQUIRE_CI="${!var_require_ci:-false}"

    # Performance
    local var_parallel="${prefix}performance_parallel_builds"
    local var_workers="${prefix}performance_max_workers"
    local var_cdn_wait="${prefix}performance_cdn_wait_time"
    MSP_PARALLEL_BUILDS="${!var_parallel:-true}"
    MSP_MAX_WORKERS="${!var_workers:-4}"
    MSP_CDN_WAIT_TIME="${!var_cdn_wait:-60}"

    # Store current profile
    MSP_CURRENT_PROFILE="$profile"

    _export_all_vars
}

# @description Extract module configuration (pods, spm) from parsed config.
_extract_module_config() {
    # Extract pods configuration
    MSP_PODS_ENABLED="${CONFIG_pods_enabled:-true}"
    MSP_PODS_REMOTE_URL="${CONFIG_pods_remote_url:-}"
    MSP_PODS_REMOTE_PRIMARY_PRODUCT="${CONFIG_pods_remote_primary_product:-MSPCore}"

    # Build pods modules array from config
    MSP_PODS_MODULES=()
    local i=0
    while true; do
        local var_name="CONFIG_pods_modules__item_${i}"
        if [[ -n "${!var_name:-}" ]]; then
            MSP_PODS_MODULES+=("${!var_name}")
            ((i++)) || true
        else
            break
        fi
    done

    # Extract SPM configuration
    MSP_SPM_ENABLED="${CONFIG_spm_enabled:-true}"
    MSP_SPM_REMOTE_URL="${CONFIG_spm_remote_url:-}"
    MSP_SPM_REMOTE_PRODUCT_NAME="${CONFIG_spm_remote_product_name:-MSPAds}"

    # Build SPM packages array from config
    MSP_SPM_PACKAGES=()
    i=0
    while true; do
        local var_name="CONFIG_spm_packages__item_${i}"
        if [[ -n "${!var_name:-}" ]]; then
            MSP_SPM_PACKAGES+=("${!var_name}")
            ((i++)) || true
        else
            break
        fi
    done

    export MSP_PODS_ENABLED MSP_PODS_REMOTE_URL MSP_PODS_REMOTE_PRIMARY_PRODUCT
    export MSP_SPM_ENABLED MSP_SPM_REMOTE_URL MSP_SPM_REMOTE_PRODUCT_NAME
}

# @description Extract verification configuration from parsed config.
_extract_verify_config() {
    # Extract verification configuration
    MSP_SANDBOX_DIR="${CONFIG_verify_sandbox_dir:-/tmp/msp-verify-sandbox}"
    MSP_VERIFY_CLEANUP_ON_SUCCESS="${CONFIG_verify_cleanup_on_success:-true}"

    MSP_VERIFY_LOCAL="${CONFIG_verify_types_local:-true}"
    MSP_VERIFY_REMOTE_PODS="${CONFIG_verify_types_remote_pods:-true}"
    MSP_VERIFY_REMOTE_SPM="${CONFIG_verify_types_remote_spm:-true}"
    MSP_VERIFY_SAMPLE_APP="${CONFIG_verify_types_sample_app:-true}"
    MSP_VERIFY_DEVICE="${CONFIG_verify_types_device:-false}"

    MSP_SPM_STRICT="${CONFIG_verify_spm_strict:-true}"

    # Timeouts
    MSP_VERIFY_TIMEOUT_LOCAL="${CONFIG_verify_timeouts_local:-300}"
    MSP_VERIFY_TIMEOUT_REMOTE_PODS="${CONFIG_verify_timeouts_remote_pods:-600}"
    MSP_VERIFY_TIMEOUT_REMOTE_SPM="${CONFIG_verify_timeouts_remote_spm:-300}"
    MSP_VERIFY_TIMEOUT_SAMPLE_APP="${CONFIG_verify_timeouts_sample_app:-600}"
    MSP_VERIFY_TIMEOUT_DEVICE="${CONFIG_verify_timeouts_device:-900}"

    export MSP_SANDBOX_DIR MSP_VERIFY_CLEANUP_ON_SUCCESS
    export MSP_VERIFY_LOCAL MSP_VERIFY_REMOTE_PODS MSP_VERIFY_REMOTE_SPM
    export MSP_VERIFY_SAMPLE_APP MSP_VERIFY_DEVICE MSP_SPM_STRICT
    export MSP_VERIFY_TIMEOUT_LOCAL MSP_VERIFY_TIMEOUT_REMOTE_PODS
    export MSP_VERIFY_TIMEOUT_REMOTE_SPM MSP_VERIFY_TIMEOUT_SAMPLE_APP
    export MSP_VERIFY_TIMEOUT_DEVICE
}

# @description Apply environment variable overrides (highest priority).
#              Also handles backward compatibility for deprecated env vars.
_load_env_overrides() {
    # Allow direct environment variable overrides (highest priority)
    # These override profile settings

    # Core Release Control - use saved value from before profile extraction
    # Only override if DRY_RUN was explicitly set before first load_config call
    if [[ "${_DRY_RUN_WAS_SET:-0}" == "1" ]] && [[ -n "${_SAVED_DRY_RUN:-}" ]]; then
        DRY_RUN="$_SAVED_DRY_RUN"
    fi

    # Logging - MSP_LOG_LEVEL can override profile
    # (Already set via profile, env var wins if set externally)
    if [[ -n "${MSP_LOG_LEVEL_OVERRIDE:-}" ]]; then
        MSP_LOG_LEVEL="$MSP_LOG_LEVEL_OVERRIDE"
    fi

    # Safety Controls
    if [[ -n "${MSP_ALLOW_EXISTING_TAG_OVERRIDE:-}" ]]; then
        MSP_ALLOW_EXISTING_TAG="$MSP_ALLOW_EXISTING_TAG_OVERRIDE"
    fi

    # Performance
    if [[ -n "${MSP_PARALLEL_BUILDS_OVERRIDE:-}" ]]; then
        MSP_PARALLEL_BUILDS="$MSP_PARALLEL_BUILDS_OVERRIDE"
    fi

    if [[ -n "${MSP_CDN_WAIT_TIME_OVERRIDE:-}" ]]; then
        MSP_CDN_WAIT_TIME="$MSP_CDN_WAIT_TIME_OVERRIDE"
    fi

    # Verification
    if [[ -n "${MSP_SANDBOX_DIR_OVERRIDE:-}" ]]; then
        MSP_SANDBOX_DIR="$MSP_SANDBOX_DIR_OVERRIDE"
    fi

    # Removed legacy variables - show error if used
    if [[ -n "${MSP_RELEASE_TIER:-}" ]]; then
        log::error "CONFIG" "MSP_RELEASE_TIER is no longer supported. Use DRY_RUN=true/false instead"
        return 1
    fi
    if [[ -n "${MSP_ALLOW_LOCAL_RELEASE:-}" ]]; then
        log::error "CONFIG" "MSP_ALLOW_LOCAL_RELEASE is no longer supported. Use --profile=local-dev instead"
        return 1
    fi
    if [[ -n "${MSP_ALLOW_TRUNK_PUSH:-}" ]]; then
        log::error "CONFIG" "MSP_ALLOW_TRUNK_PUSH is no longer supported. Use DRY_RUN=false instead"
        return 1
    fi

    # Old: MSP_SLACK_ALERT_ENV
    if [[ -n "${MSP_SLACK_ALERT_ENV:-}" ]]; then
        MSP_SLACK_ENV="$MSP_SLACK_ALERT_ENV"
    fi

    # Re-export all variables to ensure overrides take effect
    _export_all_vars
}

# @description Export all MSP_* configuration variables to the environment.
_export_all_vars() {
    export DRY_RUN MSP_LOG_LEVEL MSP_LOG_FORMAT
    export MSP_VALIDATION_PREFLIGHT
    export MSP_SLACK_ENABLED MSP_SLACK_ENV MSP_EMAIL_ENABLED
    export MSP_ALLOW_EXISTING_TAG MSP_ALLOW_EXISTING_RELEASE MSP_KEEP_SANDBOX MSP_REQUIRE_CI
    export MSP_PARALLEL_BUILDS MSP_MAX_WORKERS MSP_CDN_WAIT_TIME
    export MSP_CURRENT_PROFILE
}

# @description Validate loaded configuration values.
#              Checks boolean validity, log level, and validation preflight level.
# @return 0 on success, 1 on validation error
_validate_config() {
    # Validate boolean values
    for var in DRY_RUN MSP_SLACK_ENABLED MSP_EMAIL_ENABLED \
               MSP_ALLOW_EXISTING_TAG MSP_ALLOW_EXISTING_RELEASE MSP_KEEP_SANDBOX \
               MSP_PARALLEL_BUILDS MSP_PODS_ENABLED MSP_SPM_ENABLED \
               MSP_VERIFY_LOCAL MSP_VERIFY_REMOTE_PODS MSP_VERIFY_REMOTE_SPM \
               MSP_VERIFY_SAMPLE_APP MSP_VERIFY_DEVICE MSP_SPM_STRICT; do
        local value="${!var:-}"
        if [[ -n "$value" && "$value" != "true" && "$value" != "false" ]]; then
            log::error "CONFIG" "Invalid boolean value for $var: $value (must be true or false)"
            return 1
        fi
    done

    # Validate log level
    case "${MSP_LOG_LEVEL:-info}" in
        debug|info|warn|error)
            ;;
        *)
            log::error "CONFIG" "Invalid log level: $MSP_LOG_LEVEL (must be debug, info, warn, or error)"
            return 1
            ;;
    esac

    # Validate validation preflight level
    case "${MSP_VALIDATION_PREFLIGHT:-basic}" in
        none|basic|full)
            ;;
        *)
            log::error "CONFIG" "Invalid validation preflight: $MSP_VALIDATION_PREFLIGHT (must be none, basic, or full)"
            return 1
            ;;
    esac

    return 0
}

# ============================================================================
# Config Display
# ============================================================================

# @description Display all current configuration values in a formatted table.
display_config() {
    log::info "CONFIG" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "CONFIG" "Release Configuration"
    log::info "CONFIG" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    log::info "CONFIG" "Profile: ${MSP_CURRENT_PROFILE:-unknown}"
    log::info "CONFIG" ""

    log::info "CONFIG" "Core:"
    log::info "CONFIG" "  DRY_RUN: $DRY_RUN"
    log::info "CONFIG" "  LOG_LEVEL: $MSP_LOG_LEVEL"
    log::info "CONFIG" "  LOG_FORMAT: $MSP_LOG_FORMAT"
    log::info "CONFIG" ""

    log::info "CONFIG" "Release Metadata:"
    log::info "CONFIG" "  Version: ${MSP_VERSION:-<not set>}"
    log::info "CONFIG" "  Base Branch: ${MSP_BASE_BRANCH:-main}"
    log::info "CONFIG" "  Release Branch: ${MSP_RELEASE_BRANCH:-<auto>}"
    log::info "CONFIG" ""

    log::info "CONFIG" "Validation:"
    log::info "CONFIG" "  Preflight: $MSP_VALIDATION_PREFLIGHT"
    log::info "CONFIG" ""

    log::info "CONFIG" "Modules:"
    log::info "CONFIG" "  Pods Enabled: $MSP_PODS_ENABLED"
    log::info "CONFIG" "  SPM Enabled: $MSP_SPM_ENABLED"
    log::info "CONFIG" "  Pods Modules: ${#MSP_PODS_MODULES[@]} modules"
    log::info "CONFIG" "  SPM Packages: ${#MSP_SPM_PACKAGES[@]} packages"
    log::info "CONFIG" ""

    log::info "CONFIG" "Notifications:"
    log::info "CONFIG" "  Slack: $MSP_SLACK_ENABLED ($MSP_SLACK_ENV)"
    log::info "CONFIG" "  Email: $MSP_EMAIL_ENABLED"
    log::info "CONFIG" ""

    log::info "CONFIG" "Safety:"
    log::info "CONFIG" "  Allow Existing Tag: $MSP_ALLOW_EXISTING_TAG"
    log::info "CONFIG" "  Allow Existing Release: $MSP_ALLOW_EXISTING_RELEASE"
    log::info "CONFIG" "  Keep Sandbox: $MSP_KEEP_SANDBOX"
    log::info "CONFIG" "  Require CI: ${MSP_REQUIRE_CI:-false}"
    log::info "CONFIG" ""

    log::info "CONFIG" "Performance:"
    log::info "CONFIG" "  Parallel Builds: $MSP_PARALLEL_BUILDS"
    log::info "CONFIG" "  Max Workers: $MSP_MAX_WORKERS"
    log::info "CONFIG" "  CDN Wait Time: ${MSP_CDN_WAIT_TIME}s"
    log::info "CONFIG" ""

    log::info "CONFIG" "Verification:"
    log::info "CONFIG" "  Sandbox Dir: $MSP_SANDBOX_DIR"
    log::info "CONFIG" "  Local: $MSP_VERIFY_LOCAL"
    log::info "CONFIG" "  Remote Pods: $MSP_VERIFY_REMOTE_PODS"
    log::info "CONFIG" "  Remote SPM: $MSP_VERIFY_REMOTE_SPM"
    log::info "CONFIG" "  Sample App: $MSP_VERIFY_SAMPLE_APP"
    log::info "CONFIG" "  Device: $MSP_VERIFY_DEVICE"
    log::info "CONFIG" "  SPM Strict: $MSP_SPM_STRICT"

    log::info "CONFIG" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============================================================================
# Env Subcommand Support (FR-020)
# ============================================================================

# @description Print environment configuration for shell evaluation.
#              Usage: eval "$(config_env)"
# @param $1 profile - Profile name (optional)
# @return Shell export statements via stdout
config_env() {
    local profile="${1:-}"

    # Load config silently
    local original_log_level="${MSP_LOG_LEVEL:-info}"
    MSP_LOG_LEVEL="error"
    load_config "$profile" 2>/dev/null || true
    MSP_LOG_LEVEL="$original_log_level"

    # Output environment variables
    cat <<EOF
export DRY_RUN="$DRY_RUN"
export MSP_LOG_LEVEL="$MSP_LOG_LEVEL"
export MSP_LOG_FORMAT="$MSP_LOG_FORMAT"
export MSP_VALIDATION_PREFLIGHT="$MSP_VALIDATION_PREFLIGHT"
export MSP_SLACK_ENABLED="$MSP_SLACK_ENABLED"
export MSP_SLACK_ENV="$MSP_SLACK_ENV"
export MSP_EMAIL_ENABLED="$MSP_EMAIL_ENABLED"
export MSP_ALLOW_EXISTING_TAG="$MSP_ALLOW_EXISTING_TAG"
export MSP_ALLOW_EXISTING_RELEASE="$MSP_ALLOW_EXISTING_RELEASE"
export MSP_KEEP_SANDBOX="$MSP_KEEP_SANDBOX"
export MSP_REQUIRE_CI="${MSP_REQUIRE_CI:-false}"
export MSP_PARALLEL_BUILDS="$MSP_PARALLEL_BUILDS"
export MSP_MAX_WORKERS="$MSP_MAX_WORKERS"
export MSP_CDN_WAIT_TIME="$MSP_CDN_WAIT_TIME"
export MSP_PODS_ENABLED="$MSP_PODS_ENABLED"
export MSP_SPM_ENABLED="$MSP_SPM_ENABLED"
export MSP_SANDBOX_DIR="$MSP_SANDBOX_DIR"
export MSP_VERIFY_LOCAL="$MSP_VERIFY_LOCAL"
export MSP_VERIFY_REMOTE_PODS="$MSP_VERIFY_REMOTE_PODS"
export MSP_VERIFY_REMOTE_SPM="$MSP_VERIFY_REMOTE_SPM"
export MSP_SPM_STRICT="$MSP_SPM_STRICT"
export MSP_CURRENT_PROFILE="${MSP_CURRENT_PROFILE:-}"
export MSP_VERSION="${MSP_VERSION:-}"
export MSP_BASE_BRANCH="${MSP_BASE_BRANCH:-main}"
export MSP_RELEASE_BRANCH="${MSP_RELEASE_BRANCH:-}"
EOF
}

# @description List available profiles defined in the config file.
# @return Profile names via stdout, one per line
list_profiles() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "local-dev"
        echo "quick-test"
        echo "production"
        return 0
    fi

    # Extract profile names from config
    grep -E '^  [a-z]' "$CONFIG_FILE" | sed 's/://g' | sed 's/^  //' | grep -v '^#' || true
}

