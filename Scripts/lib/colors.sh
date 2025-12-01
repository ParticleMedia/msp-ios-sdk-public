#!/bin/bash

# ============================================================================
# MSP iOS SDK - Color Compatibility Layer (FlagMaster Light Theme)
# ============================================================================
# Provides:
#   - ANSI theme colors
#   - Backward-compatible aliases (RED/GREEN/NC…)
#   - Fallback should_use_colors + colorize if logging.sh not loaded
#   - Zero dependency failures
# ============================================================================

COLOR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ========================================
# Unified ROOT_DIR resolution (final)
# ========================================
# The root dir is always the directory that contains
# the parent Scripts/ folder where msp-release.sh lives.
if [[ -z "${ROOT_DIR:-}" ]]; then
    # Find Scripts/ directory by going up until we find it, then go up one more level
    ROOT_DIR="$COLOR_SCRIPT_DIR"
    while [[ "$ROOT_DIR" != "/" ]] && [[ "${ROOT_DIR##*/}" != "Scripts" ]]; do
        ROOT_DIR="$(dirname "$ROOT_DIR")"
    done
    # If we found Scripts/, go up one more level to get repo root
    if [[ "${ROOT_DIR##*/}" == "Scripts" ]]; then
        ROOT_DIR="$(dirname "$ROOT_DIR")"
    fi
fi
export ROOT_DIR

# Try loading logging.sh first (preferred path for color logic)
if ! declare -f colorize >/dev/null 2>&1; then
    if [[ -f "$COLOR_SCRIPT_DIR/logging.sh" ]]; then
        # shellcheck source=Scripts/lib/logging.sh
        source "$COLOR_SCRIPT_DIR/logging.sh"
    fi
fi

# ---------------------------------------------------------------------------
# FlagMaster Light Theme Colors (fallback if logging did not define)
# ---------------------------------------------------------------------------
: "${COLOR_CYAN_BRIGHT:='\033[1;36m'}"
: "${COLOR_PURPLE_LIGHT:='\033[1;35m'}"
: "${COLOR_GREEN_BRIGHT:='\033[1;32m'}"
: "${COLOR_RED_BRIGHT:='\033[1;31m'}"
: "${COLOR_YELLOW:='\033[1;33m'}"
: "${COLOR_GRAY:='\033[0;37m'}"
: "${COLOR_NC:='\033[0m'}"

# Backward compatibility aliases
export CYAN="$COLOR_CYAN_BRIGHT"
export PURPLE="$COLOR_PURPLE_LIGHT"
export GREEN="$COLOR_GREEN_BRIGHT"
export RED="$COLOR_RED_BRIGHT"
export YELLOW="$COLOR_YELLOW"
export GRAY="$COLOR_GRAY"
export NC="$COLOR_NC"
export WHITE="\033[1;37m"

# ---------------------------------------------------------------------------
# should_use_colors fallback
# ---------------------------------------------------------------------------
if ! declare -f should_use_colors >/dev/null 2>&1; then
should_use_colors() {
    [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]] && [[ "${NO_COLOR:-}" != "1" ]]
}
fi

# ---------------------------------------------------------------------------
# colorize fallback
# ---------------------------------------------------------------------------
if ! declare -f colorize >/dev/null 2>&1; then
colorize() {
    local color="$1"; shift
    local text="$*"
    if should_use_colors; then
        echo -e "${color}${text}${COLOR_NC}"
    else
        echo "$text"
    fi
}
fi

# ---------------------------------------------------------------------------
# Convenience helpers (always safe)
# ---------------------------------------------------------------------------
color_success() { colorize "$COLOR_GREEN_BRIGHT" "$1"; }
color_error()   { colorize "$COLOR_RED_BRIGHT" "$1"; }
color_warning() { colorize "$COLOR_YELLOW" "$1"; }
color_info()    { colorize "$COLOR_CYAN_BRIGHT" "$1"; }
color_highlight(){ colorize "$COLOR_PURPLE_LIGHT" "$1"; }

export -f should_use_colors colorize
export -f color_success color_error color_warning color_info color_highlight
