#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch K, shared) ---
# shellcheck source=/dev/null
if command -v git >/dev/null 2>&1; then
  MSP_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$MSP_REPO_ROOT" ] && [ -f "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh" ]; then
    # shellcheck source=/dev/null
    . "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh"
    msp_enforce_main_repo_or_exit
  fi
fi
# --- End MSP Worktree Safety Guard (Patch K, shared) ---

# ============================================================================
# MSP iOS SDK - Unified UI System (FlagMaster Light Theme)
# ============================================================================
# Provides:
#   - ui_hr
#   - ui_block
#   - log_title
#   - log_section
#   - ui_kv (aligned key-value)
#   - ui_hint
#   - ui_divider
#
# Does NOT define log_info/log_error—those come from logging.sh
# ============================================================================

UI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ============================================
# Unified ROOT_DIR resolution (final version)
# ============================================
if [[ -z "${ROOT_DIR:-}" ]]; then
    # First try Git repo root (most reliable)
    if command -v git >/dev/null 2>&1; then
        git_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
        if [[ -n "$git_root" ]]; then
            ROOT_DIR="$git_root"
        fi
    fi

    # Fallback to walking up from UI_SCRIPT_DIR
    if [[ -z "${ROOT_DIR:-}" ]]; then
        ROOT_DIR="$UI_SCRIPT_DIR"
        while [[ "$ROOT_DIR" != "/" ]] && [[ "${ROOT_DIR##*/}" != "Scripts" ]]; do
            ROOT_DIR="$(dirname "$ROOT_DIR")"
        done
        if [[ "${ROOT_DIR##*/}" == "Scripts" ]]; then
            ROOT_DIR="$(dirname "$ROOT_DIR")"
        fi
    fi
fi

export ROOT_DIR

# Load colors first, then logging (colors may load logging, but that's safe)
source "$ROOT_DIR/Scripts/lib/colors.sh" 2>/dev/null || true
source "$ROOT_DIR/Scripts/lib/logging.sh" 2>/dev/null || true

# Terminal width fallback
TERMINAL_WIDTH="${COLUMNS:-80}"
if [[ "$TERMINAL_WIDTH" -lt 60 ]]; then
    TERMINAL_WIDTH=80
fi

# ---------------------------------------------------------------------------
# Horizontal rule
# ---------------------------------------------------------------------------
ui_hr() {
    printf "%*s\n" "$TERMINAL_WIDTH" "" | tr " " "─"
}

# ---------------------------------------------------------------------------
# Box content block
# ---------------------------------------------------------------------------
ui_block() {
    local title="$1"
    local content="$2"
    local width=$((TERMINAL_WIDTH - 4))

    colorize "$COLOR_PURPLE_LIGHT" "$(printf "┌%*s┐" "$width" "" | tr " " "─")"
    colorize "$COLOR_PURPLE_LIGHT" "│ $(printf "%-${width}s" "$title") │"
    colorize "$COLOR_PURPLE_LIGHT" "$(printf "├%*s┤" "$width" "" | tr " " "─")"

    while IFS= read -r line; do
        colorize "$COLOR_PURPLE_LIGHT" "│ $(printf "%-${width}s" "$line") │"
    done <<< "$content"

    colorize "$COLOR_PURPLE_LIGHT" "$(printf "└%*s┘" "$width" "" | tr " " "─")"
}

# ---------------------------------------------------------------------------
# Section title
# ---------------------------------------------------------------------------
log_section() {
    local title="$1"
    echo ""
    ui_hr
    colorize "$COLOR_CYAN_BRIGHT" "━━━ $title"
    ui_hr
    echo ""
}

# ---------------------------------------------------------------------------
# Page-level title
# ---------------------------------------------------------------------------
log_title() {
    local title="$1"
    echo ""
    ui_hr
    colorize "$COLOR_CYAN_BRIGHT" "$title"
    ui_hr
    echo ""
}

# ---------------------------------------------------------------------------
# Aligned key-value
# ---------------------------------------------------------------------------
ui_kv() {
    local key="$1"
    local value="$2"
    printf "%-25s %s\n" "$(colorize "$COLOR_PURPLE_LIGHT" "$key")" "$value"
}

# Hint / light note
ui_hint() {
    colorize "$COLOR_GRAY" "$1"
}

# Divider
ui_divider() {
    colorize "$COLOR_GRAY" "$(printf "%*s\n" "$TERMINAL_WIDTH" "" | tr " " "·")"
}

export -f ui_hr ui_block log_section log_title ui_kv ui_hint ui_divider
