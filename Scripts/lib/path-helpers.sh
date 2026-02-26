#!/usr/bin/env bash
# =============================================================================
# path-helpers.sh - Unified path resolution utilities
# =============================================================================
# Purpose: Eliminate duplicate ROOT_DIR/SCRIPT_DIR resolution code across 110+ scripts
#
# Usage:
#   source "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/path-helpers.sh"
#   # Or if already have ROOT_DIR:
#   source "$ROOT_DIR/Scripts/lib/path-helpers.sh"
#
# After sourcing:
#   - ROOT_DIR is set and exported (project root)
#   - SCRIPT_DIR is set (directory of the script that sourced this)
#   - msp_get_root() function available for dynamic resolution
# =============================================================================

# Prevent multiple sourcing
[[ -n "${_MSP_PATH_HELPERS_LOADED:-}" ]] && return 0
readonly _MSP_PATH_HELPERS_LOADED=1

# =============================================================================
# Core Resolution Functions
# =============================================================================

# @description Get the directory of the calling script
# @param $1 Optional: BASH_SOURCE array index (default: 1, the caller)
# @return Echoes absolute path to script directory
# @example
#   script_dir="$(msp_get_script_dir)"
msp_get_script_dir() {
    local source_index="${1:-1}"
    local source_file="${BASH_SOURCE[$source_index]:-${BASH_SOURCE[0]}}"
    cd "$(dirname "$source_file")" && pwd
}

# @description Get the project root directory (git-aware with fallback)
# @return Echoes absolute path to project root
# @example
#   root="$(msp_get_root)"
msp_get_root() {
    # If ROOT_DIR already set and valid, use it
    if [[ -n "${ROOT_DIR:-}" ]] && [[ -d "$ROOT_DIR/Scripts" ]]; then
        echo "$ROOT_DIR"
        return 0
    fi

    local root=""

    # Method 1: Git repository root (most reliable)
    if command -v git >/dev/null 2>&1; then
        root="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
        if [[ -n "$root" ]] && [[ -d "$root/Scripts" ]]; then
            echo "$root"
            return 0
        fi
    fi

    # Method 2: Walk up from current script location
    local dir
    dir="$(msp_get_script_dir 2)"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/Scripts" ]] && [[ -f "$dir/Scripts/lib/path-helpers.sh" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done

    # Method 3: Walk up looking for Scripts directory marker
    dir="$(msp_get_script_dir 2)"
    while [[ "$dir" != "/" ]]; do
        if [[ "${dir##*/}" == "Scripts" ]]; then
            dirname "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done

    # Fallback: Return empty and let caller handle
    echo ""
    return 1
}

# @description Resolve ROOT_DIR and export it (idempotent)
# @return Sets and exports ROOT_DIR global variable
# @example
#   msp_resolve_root
#   echo "$ROOT_DIR"
msp_resolve_root() {
    if [[ -z "${ROOT_DIR:-}" ]]; then
        ROOT_DIR="$(msp_get_root)"
    fi
    export ROOT_DIR
}

# @description Resolve SCRIPT_DIR for the calling script
# @return Sets SCRIPT_DIR variable (not exported, script-local)
# @example
#   msp_resolve_script_dir
#   echo "$SCRIPT_DIR"
msp_resolve_script_dir() {
    # Use index 2 to get the caller of this function (not this file)
    SCRIPT_DIR="$(msp_get_script_dir 2)"
}

# =============================================================================
# Convenience Functions
# =============================================================================

# @description Get path relative to ROOT_DIR
# @param $1 Relative path from project root
# @return Echoes absolute path
# @example
#   config_path="$(msp_path "Scripts/config/release.yaml")"
msp_path() {
    local relative_path="$1"
    msp_resolve_root
    echo "${ROOT_DIR}/${relative_path}"
}

# @description Check if we're in the project root
# @return 0 if in project root, 1 otherwise
msp_is_project_root() {
    [[ -d "./Scripts" ]] && [[ -f "./Scripts/lib/path-helpers.sh" ]]
}

# @description Validate ROOT_DIR is correctly set
# @return 0 if valid, 1 with error message if invalid
msp_validate_root() {
    msp_resolve_root

    if [[ -z "$ROOT_DIR" ]]; then
        echo "ERROR: Could not determine project root" >&2
        return 1
    fi

    if [[ ! -d "$ROOT_DIR/Scripts" ]]; then
        echo "ERROR: Invalid ROOT_DIR - Scripts directory not found: $ROOT_DIR" >&2
        return 1
    fi

    return 0
}

# =============================================================================
# Auto-initialization
# =============================================================================

# Automatically resolve ROOT_DIR when this file is sourced
# Note: ROOT_DIR is global and shared across all scripts
msp_resolve_root

# Note: SCRIPT_DIR is NOT set here - each script should set its own SCRIPT_DIR
# using: SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# This prevents overwriting when multiple scripts are sourced.

# Export functions for subshells
export -f msp_get_script_dir msp_get_root msp_resolve_root msp_path msp_is_project_root msp_validate_root
