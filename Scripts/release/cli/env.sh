#!/usr/bin/env bash
# ============================================================================
# MSP Release CLI - Environment Module
# ============================================================================
# Purpose: Provides environment display and export functionality
# Usage:   source Scripts/release/cli/env.sh
#          msp_env_display "$profile" "$release_mode"
#          msp_env_export "$profile"
#
# Dependencies:
#   - Scripts/lib/common.sh (log::* functions)
#   - Scripts/lib/config_loader.sh (load_config, config_env)
# ============================================================================

# Prevent multiple sourcing
[[ -n "${_MSP_CLI_ENV_SOURCED:-}" ]] && return 0
readonly _MSP_CLI_ENV_SOURCED=1

# Get script directory and ROOT_DIR
_ENV_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ENV_ROOT_DIR="$(cd "$_ENV_SCRIPT_DIR/../../.." && pwd)"

# Source dependencies if not already loaded
if ! command -v log::info &>/dev/null; then
    if [[ -f "$_ENV_ROOT_DIR/Scripts/lib/common.sh" ]]; then
        # shellcheck source=Scripts/lib/common.sh
        source "$_ENV_ROOT_DIR/Scripts/lib/common.sh" 2>/dev/null || true
    fi
fi

# ============================================================================
# Environment Display (Human-Readable)
# ============================================================================
# @description Displays environment configuration in human-readable format
# @param $1 profile - The configuration profile (local-dev, production, etc.)
# @param $2 release_mode - The release mode (simple, full)
# @return Echoes formatted environment info to stdout
msp_env_display() {
    local profile="${1:-local-dev}"
    local release_mode="${2:-simple}"

    # Load config silently if config_loader is available
    if command -v load_config &>/dev/null; then
        load_config "$profile" 2>/dev/null || true
    fi

    # Header
    echo ""
    echo "MSP Release Environment"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Profile: $profile"
    echo "Mode: $release_mode (use --full for verification)"
    echo ""

    # Essential Variables
    echo "Essential Variables:"
    printf "  %-26s = %s\n" "DRY_RUN" "${DRY_RUN:-false}"
    printf "  %-26s = %s\n" "MSP_RELEASE_MODE" "$release_mode"
    printf "  %-26s = %s\n" "MSP_SESSION_ID" "${MSP_SESSION_ID:-<not set>}"
    printf "  %-26s = %s\n" "MSP_LOG_LEVEL" "${MSP_LOG_LEVEL:-info}"
    printf "  %-26s = %s\n" "MSP_ALLOW_EXISTING_TAG" "${MSP_ALLOW_EXISTING_TAG:-false}"
    printf "  %-26s = %s\n" "MSP_ALLOW_EXISTING_RELEASE" "${MSP_ALLOW_EXISTING_RELEASE:-false}"
    printf "  %-26s = %s\n" "MSP_SLACK_ENV" "${MSP_SLACK_ENV:-prod}"
    echo ""

    # Config-Driven Variables
    echo "Config-Driven (from release.yaml):"
    printf "  %-26s = %s\n" "validation.pods" "${MSP_PODS_ENABLED:-true}"
    printf "  %-26s = %s\n" "validation.spm" "${MSP_SPM_ENABLED:-true}"
    printf "  %-26s = %s\n" "validation.local" "${MSP_VERIFY_LOCAL:-true}"
    printf "  %-26s = %s\n" "performance.parallel_builds" "${MSP_PARALLEL_BUILDS:-true}"
    printf "  %-26s = %s\n" "performance.max_workers" "${MSP_MAX_WORKERS:-6}"
    echo ""

    # Check for removed legacy variables
    local legacy_found=false
    echo "Legacy Variables (no longer supported):"
    if [[ -n "${MSP_RELEASE_TIER:-}" ]]; then
        printf "  %-26s = %s → Use DRY_RUN=true/false\n" "MSP_RELEASE_TIER" "$MSP_RELEASE_TIER"
        legacy_found=true
    fi
    if [[ -n "${MSP_ALLOW_LOCAL_RELEASE:-}" ]]; then
        printf "  %-26s = %s → Use --profile=local-dev\n" "MSP_ALLOW_LOCAL_RELEASE" "$MSP_ALLOW_LOCAL_RELEASE"
        legacy_found=true
    fi
    if [[ -n "${MSP_ALLOW_TRUNK_PUSH:-}" ]]; then
        printf "  %-26s = %s → Use DRY_RUN=false\n" "MSP_ALLOW_TRUNK_PUSH" "$MSP_ALLOW_TRUNK_PUSH"
        legacy_found=true
    fi
    if [[ "$legacy_found" == "false" ]]; then
        echo "  (none detected)"
    else
        echo ""
        echo "  ⚠️  These variables are no longer supported and will cause errors."
    fi
    echo ""
}

# ============================================================================
# Environment Export (Shell Format)
# ============================================================================
# @description Exports environment configuration in shell-eval format
# @param $1 profile - The configuration profile
# @return Echoes shell export statements to stdout
msp_env_export() {
    local profile="${1:-local-dev}"

    echo "# MSP Release Environment Configuration"
    echo "# Profile: $profile"
    echo "# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "#"
    echo "# Usage: eval \"\$(msp-release.sh env)\""
    echo "# Usage: eval \"\$(msp-release.sh --profile=production env)\""
    echo ""

    # Call config_env from config_loader.sh if available
    if command -v config_env &>/dev/null; then
        config_env "$profile"
    else
        # Fallback: output basic environment variables
        _msp_env_export_fallback "$profile"
    fi
}

# ============================================================================
# Fallback Export (when config_env not available)
# ============================================================================
# @description Fallback export when config_env function is not available
# @param $1 profile - The configuration profile
# @return Echoes basic shell export statements
_msp_env_export_fallback() {
    local profile="$1"
    cat <<EOF
export DRY_RUN="${DRY_RUN:-false}"
export MSP_LOG_LEVEL="${MSP_LOG_LEVEL:-info}"
export MSP_RELEASE_MODE="${MSP_RELEASE_MODE:-simple}"
export MSP_CURRENT_PROFILE="$profile"
export MSP_ALLOW_EXISTING_TAG="${MSP_ALLOW_EXISTING_TAG:-false}"
export MSP_ALLOW_EXISTING_RELEASE="${MSP_ALLOW_EXISTING_RELEASE:-false}"
export MSP_SLACK_ENV="${MSP_SLACK_ENV:-prod}"
export MSP_PODS_ENABLED="${MSP_PODS_ENABLED:-true}"
export MSP_SPM_ENABLED="${MSP_SPM_ENABLED:-true}"
export MSP_PARALLEL_BUILDS="${MSP_PARALLEL_BUILDS:-true}"
export MSP_MAX_WORKERS="${MSP_MAX_WORKERS:-6}"
EOF
}

# ============================================================================
# Main env command handler
# ============================================================================
# @description Handles the env subcommand (called from msp-release.sh)
# @param $@ - Command arguments (--show for display mode)
# @return Echoes environment info in appropriate format
msp_cmd_env() {
    local show_mode=false
    if [[ "${1:-}" == "--show" ]]; then
        show_mode=true
    fi

    local profile="${PROFILE:-local-dev}"
    local release_mode="${MSP_RELEASE_MODE:-simple}"

    if [[ "$show_mode" == "true" ]]; then
        msp_env_display "$profile" "$release_mode"
    else
        msp_env_export "$profile"
    fi
}

# Export functions
export -f msp_env_display 2>/dev/null || true
export -f msp_env_export 2>/dev/null || true
export -f _msp_env_export_fallback 2>/dev/null || true
export -f msp_cmd_env 2>/dev/null || true
