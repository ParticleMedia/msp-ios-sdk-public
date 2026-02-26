#!/usr/bin/env bash
# ============================================================================
# MSP Release CLI - Run Helpers Module
# ============================================================================
# Purpose: Shared helper functions for run/resume commands
# Usage:   source Scripts/release/cli/run_helpers.sh
#          msp_init_release_session "$version" "$dry_run"
#          msp_run_preflight_checks "$version" "$context"
#          msp_finalize_release
#          msp_delegate_to_script "$script" "$version" "${args[@]}"
#
# Dependencies:
#   - Scripts/lib/common.sh (log::* functions)
#   - Scripts/release/utils/logger.sh (phase logging)
#   - Scripts/release/preflight/preflight.sh (preflight checks)
# ============================================================================

# Prevent multiple sourcing
[[ -n "${_MSP_CLI_RUN_HELPERS_SOURCED:-}" ]] && return 0
readonly _MSP_CLI_RUN_HELPERS_SOURCED=1

# Get script directory and ROOT_DIR
_RUN_HELPERS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_RUN_HELPERS_ROOT_DIR="$(cd "$_RUN_HELPERS_SCRIPT_DIR/../../.." && pwd)"

# Source dependencies if not already loaded
if ! command -v log::info &>/dev/null; then
    if [[ -f "$_RUN_HELPERS_ROOT_DIR/Scripts/lib/common.sh" ]]; then
        # shellcheck source=Scripts/lib/common.sh
        source "$_RUN_HELPERS_ROOT_DIR/Scripts/lib/common.sh" 2>/dev/null || true
    fi
fi

# ============================================================================
# Initialize Release Session
# ============================================================================
# @description Sets up logging, session ID, and metrics for a release run
# @param $1 version - The release version
# @param $2 dry_run - Whether this is a dry run (true/false)
# @return Exports MSP_SESSION_ID, MSP_LOG_FILE, MSP_METRICS_FILE
msp_init_release_session() {
    local version="${1:-unknown}"
    local dry_run="${2:-true}"
    local mode_label="dryrun"

    if [[ "$dry_run" == "false" ]]; then
        mode_label="production"
    fi

    # Generate unique session ID for this release
    export MSP_SESSION_ID="${MSP_SESSION_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
    export MSP_LOG_FILE="/tmp/msp-release-${version}-${mode_label}-${MSP_SESSION_ID}.log"
    export MSP_METRICS_FILE="/tmp/msp-release-${version}-${mode_label}-${MSP_SESSION_ID}-metrics.json"

    log::info "MSP" "Starting MSP iOS SDK Release"
    log::info "MSP" "Version: $version"
    log::info "MSP" "Mode: $mode_label (DRY_RUN=$dry_run)"
    log::info "MSP" "Session ID: $MSP_SESSION_ID"
    log::info "MSP" "Log file: $MSP_LOG_FILE"
    log::info "MSP" "Metrics file: $MSP_METRICS_FILE"

    # Start metrics timing
    if command -v metrics::start &>/dev/null; then
        metrics::start "msp_release_total"
    fi
}

# ============================================================================
# Determine Release Mode
# ============================================================================
# @description Sets MSP_RELEASE_MODE based on flags and profile
# @globals Uses FULL_MODE, PROFILE
# @return Exports MSP_RELEASE_MODE
msp_determine_release_mode() {
    if [[ "${FULL_MODE:-false}" == "true" ]]; then
        export MSP_RELEASE_MODE="full"
        log::info "RELEASE" "[MODE] Full release mode (--full flag): includes verification phase"
    elif [[ "${PROFILE:-}" == "production" ]]; then
        export MSP_RELEASE_MODE="full"
        log::info "RELEASE" "[MODE] Full release mode (--profile=production): includes verification phase"
    else
        export MSP_RELEASE_MODE="simple"
        log::info "RELEASE" "[MODE] Simple release mode (default): skips verification phase"
    fi
}

# ============================================================================
# Run Preflight Checks
# ============================================================================
# @description Runs preflight checks with proper phase logging and error handling
# @param $1 version - The release version (for notifications)
# @param $2 context - The context (run/resume) for error messages
# @return 0 on success, 1 on failure
msp_run_preflight_checks() {
    local version="${1:-unknown}"
    local context="${2:-run}"
    local root_dir="${ROOT_DIR:-$_RUN_HELPERS_ROOT_DIR}"

    log::info "RELEASE" "Running preflight checks (use --skip-preflight to disable)"

    # Start Phase 1: Preflight
    if command -v log_phase_start &>/dev/null; then
        # shellcheck disable=SC2154  # PHASE_PREFLIGHT defined in logger.sh
        log_phase_start "$PHASE_PREFLIGHT"
    fi

    local pre_script="$root_dir/Scripts/release/preflight/preflight.sh"
    if [[ ! -f "$pre_script" ]]; then
        log::error "RELEASE" "Preflight script not found at $pre_script"
        if command -v log_phase_end &>/dev/null; then
            log_phase_end "failed"
        fi
        return 1
    fi

    # shellcheck source=Scripts/release/preflight/preflight.sh
    source "$pre_script"

    if ! preflight_static; then
        log::error "RELEASE" "Static preflight failed. Aborting $context"
        if command -v notify_release_failure &>/dev/null; then
            notify_release_failure "MSP iOS SDK" "$version" \
                "Static preflight checks failed (git, branch, or version validation)" "Preflight Static"
        fi
        if command -v log_phase_end &>/dev/null; then
            log_phase_end "failed"
        fi
        return 1
    fi

    # Round-trip test only runs in full mode; simple mode skips for fast publish
    if [[ "${MSP_RELEASE_MODE:-simple}" == "full" ]]; then
        if ! preflight_build; then
            log::error "RELEASE" "Build preflight failed. Aborting $context"
            if command -v notify_release_failure &>/dev/null; then
                notify_release_failure "MSP iOS SDK" "$version" \
                    "Build preflight failed (XCFramework build or round-trip test)" "Preflight Build"
            fi
            if command -v log_phase_end &>/dev/null; then
                log_phase_end "failed"
            fi
            return 1
        fi
    else
        log::info "RELEASE" "Skipping build preflight / round-trip test (simple mode)"
    fi

    log::success "RELEASE" "Preflight checks passed"

    # End Phase 1: Preflight
    if command -v log_phase_end &>/dev/null; then
        log_phase_end "success"
    fi

    return 0
}

# ============================================================================
# Skip Preflight (log phase as skipped)
# ============================================================================
# @description Marks preflight phase as skipped
msp_skip_preflight() {
    log::warn "RELEASE" "Skipping preflight due to --skip-preflight flag"
    if command -v log_phase_start &>/dev/null; then
        # shellcheck disable=SC2154  # PHASE_PREFLIGHT defined in logger.sh
        log_phase_start "$PHASE_PREFLIGHT"
    fi
    if command -v log_phase_end &>/dev/null; then
        log_phase_end "skipped"
    fi
}

# ============================================================================
# Finalize Release
# ============================================================================
# @description Ends metrics timing, generates reports, logs completion
msp_finalize_release() {
    if command -v metrics::end &>/dev/null; then
        metrics::end "msp_release_total"
        metrics::report
        metrics::save

        # Generate analytics summary
        local root_dir="${ROOT_DIR:-$_RUN_HELPERS_ROOT_DIR}"
        if [[ -f "$root_dir/Scripts/release/utils/analytics.sh" ]]; then
            # shellcheck source=Scripts/release/utils/analytics.sh
            source "$root_dir/Scripts/release/utils/analytics.sh" 2>/dev/null || true
            if command -v analytics::summary &>/dev/null; then
                analytics::summary "$MSP_METRICS_FILE" "$MSP_LOG_FILE"
            fi
        fi

        log::success "MSP" "Release completed!"
        log::info "MSP" "Full logs: $MSP_LOG_FILE"
        log::info "MSP" "Metrics: $MSP_METRICS_FILE"
    fi
}

# ============================================================================
# Extract Version from Args
# ============================================================================
# @description Extracts version from REMAINING_ARGS array
# @globals Uses/modifies REMAINING_ARGS, CLI_VERSION, CONFIG_MODULE_LOADED
# @return Exports RELEASE_VERSION if found
msp_extract_version_from_args() {
    if [[ ${#REMAINING_ARGS[@]} -gt 0 && ! "${REMAINING_ARGS[0]}" =~ ^- ]]; then
        CLI_VERSION="${REMAINING_ARGS[0]}"
        REMAINING_ARGS=("${REMAINING_ARGS[@]:1}")
        if [[ "${CONFIG_MODULE_LOADED:-false}" == "true" ]] && command -v set_config_version &>/dev/null; then
            set_config_version "$CLI_VERSION"
        fi
    fi

    if [[ -n "${CLI_VERSION:-}" ]]; then
        export RELEASE_VERSION="$CLI_VERSION"
        if command -v apply_cli_overrides &>/dev/null; then
            apply_cli_overrides
        elif command -v msp_apply_cli_overrides &>/dev/null; then
            msp_apply_cli_overrides
        fi
    fi
}

# ============================================================================
# Package Release Handler (pods/spm)
# ============================================================================
# @description Handles pods or spm subcommand with shared logic
# @param $1 package_type - "pods" or "spm"
# @param $2 script_path - Path to the publish script
# @globals Uses REMAINING_ARGS, CLI_VERSION, CONFIG_MODULE_LOADED
msp_package_release() {
    local package_type="$1"
    local script_path="$2"

    log::info "RELEASE" "[CLI] $package_type subcommand invoked"

    # Export subcommand for state tracking
    export SUBCOMMAND="$package_type"

    # Load config (applies CLI overrides)
    if command -v load_release_config &>/dev/null; then
        load_release_config
    elif command -v msp_load_release_config &>/dev/null; then
        msp_load_release_config
    fi

    # Extract version from args
    msp_extract_version_from_args

    # Check if version is set
    if [[ -z "${RELEASE_VERSION:-}" ]]; then
        log::error "RELEASE" "VERSION is required for '$package_type' command"
        log::info "RELEASE" "Usage: msp-release.sh $package_type <VERSION> [OPTIONS]"
        log::info "RELEASE" "   or: msp-release.sh $package_type --config <file>  (with version in config)"
        exit 1
    fi

    # Delegate to the package script
    log::info "RELEASE" "Delegating to: $script_path"
    log::info "RELEASE" "Arguments: $RELEASE_VERSION ${REMAINING_ARGS[*]:-}"

    exec "$script_path" "$RELEASE_VERSION" ${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}
}

# Export functions
export -f msp_init_release_session 2>/dev/null || true
export -f msp_determine_release_mode 2>/dev/null || true
export -f msp_run_preflight_checks 2>/dev/null || true
export -f msp_skip_preflight 2>/dev/null || true
export -f msp_finalize_release 2>/dev/null || true
export -f msp_extract_version_from_args 2>/dev/null || true
export -f msp_package_release 2>/dev/null || true
