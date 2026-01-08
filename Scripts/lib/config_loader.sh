#!/bin/bash
# ============================================================================
# Config Loader - YAML Configuration Loading with Profile Support
# ============================================================================
#
# Loads configuration from Scripts/config/release.yaml with profile support.
# Environment variables override config file settings.
#
# Usage:
#   source Scripts/lib/config_loader.sh
#   load_config "production"
#   echo "$MSP_DRY_RUN"  # Prints: false
#
# Profile precedence:
#   1. Environment variables (highest priority)
#   2. Selected profile
#   3. Default profile
#   4. Hardcoded defaults (lowest priority)
# ============================================================================

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Determine ROOT_DIR if not set
if [[ -z "${ROOT_DIR:-}" ]]; then
    # Try Git repo root (most reliable)
    if command -v git >/dev/null 2>&1; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        git_root="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null || echo "")"
        if [[ -n "$git_root" ]]; then
            ROOT_DIR="$git_root"
        fi
    fi

    # Fallback to walking up from script directory
    if [[ -z "${ROOT_DIR:-}" ]]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        ROOT_DIR="$SCRIPT_DIR"
        while [[ "$ROOT_DIR" != "/" ]] && [[ "${ROOT_DIR##*/}" != "Scripts" ]]; do
            ROOT_DIR="$(dirname "$ROOT_DIR")"
        done
        if [[ "${ROOT_DIR##*/}" == "Scripts" ]]; then
            ROOT_DIR="$(dirname "$ROOT_DIR")"
        fi
    fi
fi

# Config file path (use ROOT_DIR if available, otherwise relative)
if [[ -n "${ROOT_DIR:-}" ]]; then
    CONFIG_FILE="${MSP_CONFIG_FILE:-$ROOT_DIR/Scripts/config/release.yaml}"
else
    CONFIG_FILE="${MSP_CONFIG_FILE:-Scripts/config/release.yaml}"
fi

# Default values (fallback if config file not found)
DEFAULT_PROFILE="local-dev"
DEFAULT_DRY_RUN="true"
DEFAULT_MODE="cli"
DEFAULT_LOG_LEVEL="info"

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
#
# Does NOT support:
# - Lists/arrays
# - Multi-line strings
# - Anchors/aliases
# ============================================================================

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
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" |
    awk -F"$fs" '{
        indent = length($1)/2;
        # Replace hyphens with underscores in keys
        key = $2;
        gsub(/-/, "_", key);
        vname[indent] = key;
        for (i in vname) {if (i > indent) {delete vname[i]}}
        value = $3;
        # Trim leading/trailing whitespace from value
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value);
        if (length(value) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, key, value);
        }
    }'
}

# ============================================================================
# Config Loading
# ============================================================================

load_config() {
    local profile="${1:-$DEFAULT_PROFILE}"

    log_debug "Loading config for profile: $profile"

    # Check if config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warning "Config file not found: $CONFIG_FILE"
        log_warning "Using default values and environment variables only"
        _load_defaults
        _load_env_overrides
        return 0
    fi

    # Parse YAML and extract profile
    local config_vars
    config_vars=$(parse_yaml "$CONFIG_FILE" "CONFIG_")

    if [[ -z "$config_vars" ]]; then
        log_error "Failed to parse config file: $CONFIG_FILE"
        return 1
    fi

    # Load config into environment
    eval "$config_vars"

    # Extract profile-specific values
    _extract_profile_config "$profile"

    # Apply environment variable overrides
    _load_env_overrides

    # Validate configuration
    _validate_config

    log_success "Configuration loaded successfully (profile: $profile)"
}

_load_defaults() {
    MSP_DRY_RUN="${MSP_DRY_RUN:-$DEFAULT_DRY_RUN}"
    MSP_MODE="${MSP_MODE:-$DEFAULT_MODE}"
    MSP_LOG_LEVEL="${MSP_LOG_LEVEL:-$DEFAULT_LOG_LEVEL}"

    MSP_VALIDATION_PODS="${MSP_VALIDATION_PODS:-true}"
    MSP_VALIDATION_SPM="${MSP_VALIDATION_SPM:-false}"
    MSP_VALIDATION_XCFRAMEWORK="${MSP_VALIDATION_XCFRAMEWORK:-false}"
    MSP_VALIDATION_LOCAL="${MSP_VALIDATION_LOCAL:-true}"
    MSP_VALIDATION_REMOTE="${MSP_VALIDATION_REMOTE:-false}"
    MSP_VALIDATION_DEVICE="${MSP_VALIDATION_DEVICE:-false}"

    MSP_SLACK_ENABLED="${MSP_SLACK_ENABLED:-true}"
    MSP_SLACK_ENV="${MSP_SLACK_ENV:-test}"
    MSP_EMAIL_ENABLED="${MSP_EMAIL_ENABLED:-false}"

    MSP_ALLOW_EXISTING_TAG="${MSP_ALLOW_EXISTING_TAG:-true}"
    MSP_ALLOW_EXISTING_RELEASE="${MSP_ALLOW_EXISTING_RELEASE:-true}"
    MSP_KEEP_SANDBOX="${MSP_KEEP_SANDBOX:-true}"

    MSP_PARALLEL_BUILDS="${MSP_PARALLEL_BUILDS:-true}"
    MSP_MAX_WORKERS="${MSP_MAX_WORKERS:-4}"
    MSP_CDN_WAIT_TIME="${MSP_CDN_WAIT_TIME:-60}"

    export MSP_DRY_RUN MSP_MODE MSP_LOG_LEVEL
    export MSP_VALIDATION_PODS MSP_VALIDATION_SPM MSP_VALIDATION_XCFRAMEWORK
    export MSP_VALIDATION_LOCAL MSP_VALIDATION_REMOTE MSP_VALIDATION_DEVICE
    export MSP_SLACK_ENABLED MSP_SLACK_ENV MSP_EMAIL_ENABLED
    export MSP_ALLOW_EXISTING_TAG MSP_ALLOW_EXISTING_RELEASE MSP_KEEP_SANDBOX
    export MSP_PARALLEL_BUILDS MSP_MAX_WORKERS MSP_CDN_WAIT_TIME
}

_extract_profile_config() {
    local profile="$1"

    # Replace hyphens with underscores for variable names
    local profile_var="${profile//-/_}"

    # Build variable name prefix for this profile
    local prefix="CONFIG_profiles_${profile_var}_"

    # Core Release Control
    local var_dry_run="${prefix}dry_run"
    local var_mode="${prefix}mode"
    MSP_DRY_RUN="${!var_dry_run:-$DEFAULT_DRY_RUN}"
    MSP_MODE="${!var_mode:-$DEFAULT_MODE}"

    # Validation Control
    local var_validation_pods="${prefix}validation_pods"
    local var_validation_spm="${prefix}validation_spm"
    local var_validation_xcframework="${prefix}validation_xcframework"
    local var_validation_local="${prefix}validation_local"
    local var_validation_remote="${prefix}validation_remote"
    local var_validation_device="${prefix}validation_device"
    MSP_VALIDATION_PODS="${!var_validation_pods:-true}"
    MSP_VALIDATION_SPM="${!var_validation_spm:-false}"
    MSP_VALIDATION_XCFRAMEWORK="${!var_validation_xcframework:-false}"
    MSP_VALIDATION_LOCAL="${!var_validation_local:-true}"
    MSP_VALIDATION_REMOTE="${!var_validation_remote:-false}"
    MSP_VALIDATION_DEVICE="${!var_validation_device:-false}"

    # Notification Control
    local var_slack_enabled="${prefix}notifications_slack_enabled"
    local var_slack_env="${prefix}notifications_slack_env"
    local var_email_enabled="${prefix}notifications_email_enabled"
    MSP_SLACK_ENABLED="${!var_slack_enabled:-true}"
    MSP_SLACK_ENV="${!var_slack_env:-test}"
    MSP_EMAIL_ENABLED="${!var_email_enabled:-false}"

    # DEBUG: Uncomment to troubleshoot slack_env
    # log_debug "[CONFIG] var_slack_env=$var_slack_env, resolved=${!var_slack_env:-empty}, final=$MSP_SLACK_ENV"

    # Logging
    local var_log_level="${prefix}logging_level"
    local var_log_format="${prefix}logging_format"
    MSP_LOG_LEVEL="${!var_log_level:-info}"
    MSP_LOG_FORMAT="${!var_log_format:-pretty}"

    # Safety Controls
    local var_allow_tag="${prefix}safety_allow_existing_tag"
    local var_allow_release="${prefix}safety_allow_existing_release"
    local var_keep_sandbox="${prefix}safety_keep_sandbox"
    local var_require_confirm="${prefix}safety_require_confirmation"
    MSP_ALLOW_EXISTING_TAG="${!var_allow_tag:-true}"
    MSP_ALLOW_EXISTING_RELEASE="${!var_allow_release:-true}"
    MSP_KEEP_SANDBOX="${!var_keep_sandbox:-true}"
    MSP_REQUIRE_CONFIRMATION="${!var_require_confirm:-false}"

    # Performance
    local var_parallel="${prefix}performance_parallel_builds"
    local var_workers="${prefix}performance_max_workers"
    local var_cdn_wait="${prefix}performance_cdn_wait_time"
    MSP_PARALLEL_BUILDS="${!var_parallel:-true}"
    MSP_MAX_WORKERS="${!var_workers:-4}"
    MSP_CDN_WAIT_TIME="${!var_cdn_wait:-60}"

    export MSP_DRY_RUN MSP_MODE MSP_LOG_LEVEL MSP_LOG_FORMAT
    export MSP_VALIDATION_PODS MSP_VALIDATION_SPM MSP_VALIDATION_XCFRAMEWORK
    export MSP_VALIDATION_LOCAL MSP_VALIDATION_REMOTE MSP_VALIDATION_DEVICE
    export MSP_SLACK_ENABLED MSP_SLACK_ENV MSP_EMAIL_ENABLED
    export MSP_ALLOW_EXISTING_TAG MSP_ALLOW_EXISTING_RELEASE MSP_KEEP_SANDBOX
    export MSP_PARALLEL_BUILDS MSP_MAX_WORKERS MSP_CDN_WAIT_TIME
}

_load_env_overrides() {
    # Allow direct environment variable overrides (highest priority)
    # These override profile settings

    # Core Release Control
    if [[ -n "${DRY_RUN:-}" ]]; then
        MSP_DRY_RUN="$DRY_RUN"
    fi
    if [[ -n "${MSP_DRY_RUN:-}" && "${DRY_RUN:-}" != "${MSP_DRY_RUN}" ]]; then
        # MSP_DRY_RUN was set directly (not from DRY_RUN above)
        : # Keep MSP_DRY_RUN as is
    fi

    # Backward compatibility: map old env vars to new config

    # Old: MSP_RELEASE_TIER (preflight|release)
    if [[ -n "${MSP_RELEASE_TIER:-}" ]]; then
        log_warning "MSP_RELEASE_TIER is deprecated, use DRY_RUN instead"
        case "$MSP_RELEASE_TIER" in
            preflight)
                MSP_DRY_RUN="true"
                ;;
            release)
                MSP_DRY_RUN="false"
                ;;
        esac
    fi

    # Old: MSP_ALLOW_LOCAL_RELEASE
    if [[ -n "${MSP_ALLOW_LOCAL_RELEASE:-}" ]]; then
        log_warning "MSP_ALLOW_LOCAL_RELEASE is deprecated, use --profile=local-dev instead"
    fi

    # Old: MSP_ALLOW_TRUNK_PUSH
    if [[ -n "${MSP_ALLOW_TRUNK_PUSH:-}" ]]; then
        log_warning "MSP_ALLOW_TRUNK_PUSH is deprecated, control via DRY_RUN instead"
    fi

    # Old: MSP_PODS_ENABLED
    if [[ -n "${MSP_PODS_ENABLED:-}" ]]; then
        MSP_VALIDATION_PODS="$MSP_PODS_ENABLED"
    fi

    # Old: MSP_SPM_ENABLED
    if [[ -n "${MSP_SPM_ENABLED:-}" ]]; then
        MSP_VALIDATION_SPM="$MSP_SPM_ENABLED"
    fi

    # Old: MSP_SKIP_* variables (inverted logic)
    if [[ -n "${MSP_SKIP_LOCAL_VALIDATION:-}" ]]; then
        [[ "$MSP_SKIP_LOCAL_VALIDATION" == "true" ]] && MSP_VALIDATION_LOCAL="false" || MSP_VALIDATION_LOCAL="true"
    fi

    if [[ -n "${MSP_SKIP_REMOTE_VALIDATION:-}" ]]; then
        [[ "$MSP_SKIP_REMOTE_VALIDATION" == "true" ]] && MSP_VALIDATION_REMOTE="false" || MSP_VALIDATION_REMOTE="true"
    fi

    if [[ -n "${MSP_SKIP_DEVICE_VALIDATION:-}" ]]; then
        [[ "$MSP_SKIP_DEVICE_VALIDATION" == "true" ]] && MSP_VALIDATION_DEVICE="false" || MSP_VALIDATION_DEVICE="true"
    fi

    # Old: MSP_SLACK_ALERT_ENV
    if [[ -n "${MSP_SLACK_ALERT_ENV:-}" ]]; then
        MSP_SLACK_ENV="$MSP_SLACK_ALERT_ENV"
    fi

    # Re-export all variables to ensure overrides take effect
    export MSP_DRY_RUN MSP_MODE MSP_LOG_LEVEL MSP_LOG_FORMAT
    export MSP_VALIDATION_PODS MSP_VALIDATION_SPM MSP_VALIDATION_XCFRAMEWORK
    export MSP_VALIDATION_LOCAL MSP_VALIDATION_REMOTE MSP_VALIDATION_DEVICE
    export MSP_SLACK_ENABLED MSP_SLACK_ENV MSP_EMAIL_ENABLED
    export MSP_ALLOW_EXISTING_TAG MSP_ALLOW_EXISTING_RELEASE MSP_KEEP_SANDBOX
    export MSP_PARALLEL_BUILDS MSP_MAX_WORKERS MSP_CDN_WAIT_TIME
}

_validate_config() {
    # Validate boolean values
    for var in MSP_DRY_RUN MSP_VALIDATION_PODS MSP_VALIDATION_SPM MSP_VALIDATION_XCFRAMEWORK \
               MSP_VALIDATION_LOCAL MSP_VALIDATION_REMOTE MSP_VALIDATION_DEVICE \
               MSP_SLACK_ENABLED MSP_EMAIL_ENABLED \
               MSP_ALLOW_EXISTING_TAG MSP_ALLOW_EXISTING_RELEASE MSP_KEEP_SANDBOX \
               MSP_PARALLEL_BUILDS; do
        local value="${!var}"
        if [[ "$value" != "true" && "$value" != "false" ]]; then
            log_error "Invalid boolean value for $var: $value (must be true or false)"
            return 1
        fi
    done

    # Validate log level
    case "$MSP_LOG_LEVEL" in
        debug|info|warn|error)
            ;;
        *)
            log_error "Invalid log level: $MSP_LOG_LEVEL (must be debug, info, warn, or error)"
            return 1
            ;;
    esac

    # Validate mode
    case "$MSP_MODE" in
        cli|ci)
            ;;
        *)
            log_error "Invalid mode: $MSP_MODE (must be cli or ci)"
            return 1
            ;;
    esac

    return 0
}

# ============================================================================
# Config Display
# ============================================================================

display_config() {
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "📋 Release Configuration"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    log_info "Core:"
    log_info "  DRY_RUN: $MSP_DRY_RUN"
    log_info "  MODE: $MSP_MODE"
    log_info "  LOG_LEVEL: $MSP_LOG_LEVEL"

    log_info "Validation:"
    log_info "  Pods: $MSP_VALIDATION_PODS"
    log_info "  SPM: $MSP_VALIDATION_SPM"
    log_info "  XCFramework: $MSP_VALIDATION_XCFRAMEWORK"
    log_info "  Local: $MSP_VALIDATION_LOCAL"
    log_info "  Remote: $MSP_VALIDATION_REMOTE"
    log_info "  Device: $MSP_VALIDATION_DEVICE"

    log_info "Notifications:"
    log_info "  Slack: $MSP_SLACK_ENABLED ($MSP_SLACK_ENV)"
    log_info "  Email: $MSP_EMAIL_ENABLED"

    log_info "Safety:"
    log_info "  Allow Existing Tag: $MSP_ALLOW_EXISTING_TAG"
    log_info "  Allow Existing Release: $MSP_ALLOW_EXISTING_RELEASE"
    log_info "  Keep Sandbox: $MSP_KEEP_SANDBOX"
    log_info "  Interactive Mode: ${INTERACTIVE:-false} (controlled by --interactive flag)"

    log_info "Performance:"
    log_info "  Parallel Builds: $MSP_PARALLEL_BUILDS"
    log_info "  Max Workers: $MSP_MAX_WORKERS"
    log_info "  CDN Wait Time: ${MSP_CDN_WAIT_TIME}s"

    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============================================================================
# Logging Helpers (Simple fallback if not sourced from logger.sh)
# ============================================================================

if ! command -v log_info &>/dev/null; then
    log_info() { echo "[INFO] $*"; }
    log_error() { echo "[ERROR] $*" >&2; }
    log_warning() { echo "[WARN] $*"; }
    log_success() { echo "[SUCCESS] $*"; }
    log_debug() { [[ "${MSP_LOG_LEVEL:-info}" == "debug" ]] && echo "[DEBUG] $*" || true; }
fi

