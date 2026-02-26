#!/usr/bin/env bash
# ============================================================================
# MSP Release CLI - Dispatch Module
# ============================================================================
# Purpose: Contains all subcommand handlers (do_*) and dispatch logic
# Usage:   source Scripts/release/cli/dispatch.sh
#          msp_dispatch_subcommand
#
# Dependencies:
#   - Scripts/lib/common.sh (log::* functions)
#   - Scripts/release/cli/commands.sh (msp_cmd_* functions)
#   - Scripts/release/cli/run_helpers.sh (run/resume helpers)
#   - Scripts/release/cli/resume.sh (resume helpers)
#   - Scripts/release/cli/help.sh (help/version display)
#   - Scripts/release/cli/env.sh (env command)
#   - Scripts/release/cli/config_helper.sh (config loading)
#
# Globals Required:
#   - SUBCOMMAND, REMAINING_ARGS
#   - VERBOSE, DRY_RUN, SKIP_PREFLIGHT, NO_ANSI, FORCE
#   - MODULAR_SCRIPT, COCOAPODS_SCRIPT, SPM_SCRIPT
#   - CONFIG_MODULE_LOADED
# ============================================================================

# Prevent multiple sourcing
[[ -n "${_MSP_CLI_DISPATCH_SOURCED:-}" ]] && return 0
readonly _MSP_CLI_DISPATCH_SOURCED=1

# Get script directory and ROOT_DIR
_DISPATCH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_DISPATCH_ROOT_DIR="$(cd "$_DISPATCH_SCRIPT_DIR/../../.." && pwd)"

# Source dependencies if not already loaded
if ! command -v log::info &>/dev/null; then
    if [[ -f "$_DISPATCH_ROOT_DIR/Scripts/lib/common.sh" ]]; then
        # shellcheck source=Scripts/lib/common.sh
        source "$_DISPATCH_ROOT_DIR/Scripts/lib/common.sh" 2>/dev/null || true
    fi
fi

# ============================================================================
# do_help - Display help message
# ============================================================================
msp_do_help() {
    if command -v msp_show_help &>/dev/null; then
        msp_show_help
    else
        echo "Error: help.sh module not loaded" >&2
        return 1
    fi
}

# ============================================================================
# do_version - Display version
# ============================================================================
msp_do_version() {
    if command -v msp_show_version &>/dev/null; then
        msp_show_version
    else
        echo "msp-release.sh version ${MSP_RELEASE_VERSION:-unknown}"
    fi
}

# ============================================================================
# do_config - Display configuration
# ============================================================================
msp_do_config() {
    if [[ "${CONFIG_MODULE_LOADED:-false}" != "true" ]]; then
        log::error "RELEASE" "Config module not available"
        return 1
    fi

    # Load config (applies CLI overrides)
    if command -v msp_load_release_config &>/dev/null; then
        msp_load_release_config
    fi

    # Print config summary
    if command -v print_config_summary &>/dev/null; then
        print_config_summary
    fi

    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo ""
        if command -v print_config_debug &>/dev/null; then
            print_config_debug
        fi
    fi
}

# ============================================================================
# do_env - Display environment (delegates to env.sh)
# ============================================================================
# shellcheck disable=SC2120
msp_do_env() {
    if command -v msp_cmd_env &>/dev/null; then
        msp_cmd_env "$@"
    else
        log::error "RELEASE" "env.sh module not loaded"
        return 1
    fi
}

# ============================================================================
# do_preflight - Run preflight checks only
# ============================================================================
msp_do_preflight() {
    if command -v log_section &>/dev/null; then
        log_section "MSP Release - Preflight"
    fi

    if command -v msp_load_release_config &>/dev/null; then
        msp_load_release_config
    fi

    if command -v msp_extract_version_from_args &>/dev/null; then
        msp_extract_version_from_args
    fi

    if command -v msp_run_preflight_checks &>/dev/null; then
        msp_run_preflight_checks "${RELEASE_VERSION:-unknown}" "preflight"
    else
        log::error "RELEASE" "run_helpers.sh module not loaded"
        return 1
    fi
}

# ============================================================================
# do_fix_public_tag - Fix public tag issues
# ============================================================================
msp_do_fix_public_tag() {
    if [[ ${#REMAINING_ARGS[@]} -eq 0 ]]; then
        log::error "RELEASE" "Usage: msp-release.sh fix-public-tag <version>"
        return 1
    fi
    local version="${REMAINING_ARGS[0]}"

    if command -v msp_cmd_fix_public_tag &>/dev/null; then
        msp_cmd_fix_public_tag "$version"
    else
        log::error "RELEASE" "commands.sh module not loaded"
        return 1
    fi
}

# ============================================================================
# do_run - Execute full release
# ============================================================================
msp_do_run() {
    local root_dir="${ROOT_DIR:-$_DISPATCH_ROOT_DIR}"

    # Record author email for Slack notifications
    export MSP_AUTHOR_EMAIL
    MSP_AUTHOR_EMAIL="$(git config user.email 2>/dev/null || echo "")"

    # Set release mode (simple vs full)
    if command -v msp_determine_release_mode &>/dev/null; then
        msp_determine_release_mode
    fi

    # Initialize session and logging
    local version="${REMAINING_ARGS[0]:-unknown}"
    if command -v msp_init_release_session &>/dev/null; then
        msp_init_release_session "$version" "${DRY_RUN:-true}"
    fi

    # Reset state for fresh run
    local state_file="${root_dir}/.msp-release-state.json"
    if [[ -f "$state_file" ]]; then
        log::info "MSP" "Resetting state file for fresh run"
        rm -f "$state_file"
    fi
    unset MSP_RESUME_MODE

    # Load config and extract version
    if command -v msp_load_release_config &>/dev/null; then
        msp_load_release_config
    fi
    if command -v msp_extract_version_from_args &>/dev/null; then
        msp_extract_version_from_args
    fi

    # Apply component selections
    [[ "${MSP_PODS_ENABLED:-}" == "true" ]] && export PODS_ENABLED="true"
    [[ "${MSP_PODS_ENABLED:-}" == "false" ]] && export PODS_ENABLED="false"
    [[ "${MSP_SPM_ENABLED:-}" == "true" ]] && export SPM_ENABLED="true"
    [[ "${MSP_SPM_ENABLED:-}" == "false" ]] && export SPM_ENABLED="false"

    # Require version
    if [[ -z "${RELEASE_VERSION:-}" ]]; then
        log::error "RELEASE" "VERSION is required for 'run' command"
        log::info "RELEASE" "Usage: msp-release.sh run <VERSION> [OPTIONS]"
        return 1
    fi

    # Run preflight checks
    if [[ "${SKIP_PREFLIGHT:-false}" != "true" ]]; then
        if command -v msp_run_preflight_checks &>/dev/null; then
            if ! msp_run_preflight_checks "$RELEASE_VERSION" "release"; then
                return 1
            fi
        fi
    else
        if command -v msp_skip_preflight &>/dev/null; then
            msp_skip_preflight
        fi
    fi

    # Set defaults and delegate
    [[ -z "${DRY_RUN:-}" ]] && DRY_RUN="true" && log::info "RELEASE" "[MODE] DRY_RUN not set; defaulting to dry-run mode"
    export DRY_RUN
    export MSP_RELEASE_MODE="${MSP_RELEASE_MODE:-cli}"

    log::info "MSP" "Delegating to: $MODULAR_SCRIPT"
    log::info "MSP" "Arguments: $RELEASE_VERSION ${REMAINING_ARGS[*]:-}"

    bash "$MODULAR_SCRIPT" "$RELEASE_VERSION" ${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}
    local result=$?

    # Finalize
    if command -v msp_finalize_release &>/dev/null; then
        msp_finalize_release
    fi
    return $result
}

# ============================================================================
# do_pods - Publish to CocoaPods only
# ============================================================================
msp_do_pods() {
    if command -v msp_package_release &>/dev/null; then
        msp_package_release "pods" "$COCOAPODS_SCRIPT"
    else
        log::error "RELEASE" "run_helpers.sh module not loaded"
        return 1
    fi
}

# ============================================================================
# do_spm - Publish to SPM only
# ============================================================================
msp_do_spm() {
    if command -v msp_package_release &>/dev/null; then
        msp_package_release "spm" "$SPM_SCRIPT"
    else
        log::error "RELEASE" "run_helpers.sh module not loaded"
        return 1
    fi
}

# ============================================================================
# do_verify - Run verification
# ============================================================================
msp_do_verify() {
    # Load config and get version
    if command -v msp_load_release_config &>/dev/null; then
        msp_load_release_config
    fi

    local version="${RELEASE_VERSION:-}"
    if [[ -n "${REMAINING_ARGS:-}" ]] && [[ ${#REMAINING_ARGS[@]} -gt 0 ]] && \
       [[ -n "${REMAINING_ARGS[0]:-}" ]] && [[ ! "${REMAINING_ARGS[0]}" =~ ^- ]]; then
        version="${REMAINING_ARGS[0]}"
        export RELEASE_VERSION="$version"
        if command -v msp_apply_cli_overrides &>/dev/null; then
            msp_apply_cli_overrides
        fi
    fi

    # Delegate to extracted module
    if command -v msp_cmd_verify &>/dev/null; then
        msp_cmd_verify "$version"
    else
        log::error "RELEASE" "commands.sh module not loaded"
        return 1
    fi
}

# ============================================================================
# do_verify_matrix - Run verification matrix
# ============================================================================
msp_do_verify_matrix() {
    # Load config
    if command -v msp_load_release_config &>/dev/null; then
        msp_load_release_config
    fi

    # Delegate to extracted module
    if command -v msp_cmd_verify_matrix &>/dev/null; then
        msp_cmd_verify_matrix
    else
        log::error "RELEASE" "commands.sh module not loaded"
        return 1
    fi
}

# ============================================================================
# do_rollback - Rollback a release
# ============================================================================
msp_do_rollback() {
    # Parse rollback-specific flags
    local force=0

    for arg in "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"; do
        case "$arg" in
            --force)
                force=1
                ;;
            --no-ansi)
                NO_ANSI=true
                export NO_ANSI
                ;;
        esac
    done

    # Delegate to extracted module
    if command -v msp_cmd_rollback &>/dev/null; then
        msp_cmd_rollback "$force"
    else
        log::error "RELEASE" "commands.sh module not loaded"
        return 1
    fi
}

# ============================================================================
# do_create_github_releases - Create GitHub releases for all binary pods
# ============================================================================
msp_do_create_github_releases() {
    if [[ ${#REMAINING_ARGS[@]} -eq 0 ]]; then
        log::error "RELEASE" "Usage: msp-release.sh create-github-releases <version>"
        return 1
    fi
    local version="${REMAINING_ARGS[0]}"

    # Source the create_github_releases module if not already loaded
    if ! command -v create_github_releases_command &>/dev/null; then
        local create_gh_module="$_DISPATCH_ROOT_DIR/Scripts/release/cli/create_github_releases.sh"
        if [[ -f "$create_gh_module" ]]; then
            # shellcheck source=Scripts/release/cli/create_github_releases.sh
            source "$create_gh_module"
        else
            log::error "RELEASE" "create_github_releases.sh module not found"
            return 1
        fi
    fi

    if command -v create_github_releases_command &>/dev/null; then
        create_github_releases_command "$version"
    else
        log::error "RELEASE" "create_github_releases.sh module not loaded"
        return 1
    fi
}

# ============================================================================
# do_resume - Resume an interrupted release
# ============================================================================
msp_do_resume() {
    echo ""
    log::info "RELEASE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "RELEASE" "🔄 MSP Release Resume"
    log::info "RELEASE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Check state file exists
    if command -v msp_resume_check_state_file &>/dev/null; then
        msp_resume_check_state_file || return 1
    else
        log::error "RELEASE" "resume.sh module not loaded"
        return 1
    fi

    # Get version from args or state file
    local version
    version=$(msp_resume_get_version "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}")
    [[ -z "$version" ]] && return 1

    # Load dependencies
    msp_resume_load_dependencies || return 1

    # Sync from GitHub and display summary
    if command -v msp_sync_from_github_release &>/dev/null; then
        msp_sync_from_github_release "$version"
    fi
    if command -v msp_display_resume_summary &>/dev/null; then
        msp_display_resume_summary "$version"
    fi

    # Check if already complete
    if command -v msp_resume_is_complete &>/dev/null && msp_resume_is_complete; then
        log::success "RELEASE" "All pods are already published!"
        log::info "RELEASE" "No action needed. Release $version is complete."
        return 0
    fi

    echo ""
    log::info "RELEASE" "🔄 Resuming release for $version..."
    echo ""

    # Increment resume count
    command -v msp_state_increment_resume_count &>/dev/null && msp_state_increment_resume_count

    # Setup environment
    if command -v msp_resume_setup_environment &>/dev/null; then
        msp_resume_setup_environment "$version"
    fi

    # Load config
    if command -v msp_load_release_config &>/dev/null; then
        msp_load_release_config
    fi

    # Run preflight checks
    if [[ "${SKIP_PREFLIGHT:-false}" != "true" ]]; then
        if command -v msp_run_preflight_checks &>/dev/null; then
            msp_run_preflight_checks "$RELEASE_VERSION" "resume" || return 1
        fi
    else
        if command -v msp_skip_preflight &>/dev/null; then
            msp_skip_preflight
        fi
    fi

    # Delegate to modular.sh
    log::info "RELEASE" "Delegating to: $MODULAR_SCRIPT"
    log::info "RELEASE" "Arguments: $RELEASE_VERSION ${REMAINING_ARGS[*]:-}"

    if ! bash "$MODULAR_SCRIPT" "$RELEASE_VERSION" ${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}; then
        local exit_code=$?
        log::error "RELEASE" "Resume failed with exit code: $exit_code"
        command -v notify_release_failure &>/dev/null && \
            notify_release_failure "MSP iOS SDK" "$RELEASE_VERSION" "Release execution failed" "Resume Execution"
        return $exit_code
    fi
}

# ============================================================================
# Subcommand Dispatch
# ============================================================================
msp_dispatch_subcommand() {
    local subcommand="${SUBCOMMAND:-help}"

    case "$subcommand" in
        help|"")
            msp_do_help
            ;;
        version)
            msp_do_version
            ;;
        config)
            msp_do_config
            ;;
        env)
            msp_do_env "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"
            ;;
        preflight)
            msp_do_preflight
            ;;
        run)
            msp_do_run
            ;;
        pods)
            msp_do_pods
            ;;
        spm)
            msp_do_spm
            ;;
        verify)
            msp_do_verify
            ;;
        verify-matrix)
            msp_do_verify_matrix
            ;;
        rollback)
            msp_do_rollback
            ;;
        resume)
            msp_do_resume
            ;;
        fix-public-tag)
            msp_do_fix_public_tag
            ;;
        create-github-releases)
            msp_do_create_github_releases
            ;;
        *)
            log::error "RELEASE" "Unknown command: $subcommand"
            echo ""
            msp_do_help
            return 1
            ;;
    esac
}

# Export functions
export -f msp_do_help 2>/dev/null || true
export -f msp_do_version 2>/dev/null || true
export -f msp_do_config 2>/dev/null || true
export -f msp_do_env 2>/dev/null || true
export -f msp_do_preflight 2>/dev/null || true
export -f msp_do_fix_public_tag 2>/dev/null || true
export -f msp_do_run 2>/dev/null || true
export -f msp_do_pods 2>/dev/null || true
export -f msp_do_spm 2>/dev/null || true
export -f msp_do_verify 2>/dev/null || true
export -f msp_do_verify_matrix 2>/dev/null || true
export -f msp_do_rollback 2>/dev/null || true
export -f msp_do_resume 2>/dev/null || true
export -f msp_do_create_github_releases 2>/dev/null || true
export -f msp_dispatch_subcommand 2>/dev/null || true
