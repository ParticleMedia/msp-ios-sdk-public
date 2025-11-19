#!/usr/bin/env bash
# ============================================================================
# Unified UI System for All Scripts
# ============================================================================
# Purpose: Professional, consistent CLI UI layer for all scripts in Scripts/
#
# Usage:   source Scripts/lib/ui.sh
# ============================================================================

# Load color utilities
# Note: This script should be sourced after colors.sh
# But we ensure colors are available if sourced directly
if [[ -z "${RED:-}" ]]; then
    UI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT_DIR="$(cd "$UI_SCRIPT_DIR/../.." && pwd)"
    # shellcheck source=Scripts/lib/colors.sh
    source "$ROOT_DIR/Scripts/lib/colors.sh" 2>/dev/null || true
fi

# Terminal width (default to 80 if not detected)
TERMINAL_WIDTH="${COLUMNS:-80}"
if [[ "$TERMINAL_WIDTH" -lt 60 ]]; then
    TERMINAL_WIDTH=80
fi

# ============================================================================
# Helper Functions
# ============================================================================

# Print horizontal rule
ui_hr() {
    local char="${1:-=}"
    printf "%*s\n" "$TERMINAL_WIDTH" "" | tr " " "$char"
}

# Indent multiline messages
ui_indent() {
    local indent="${1:-2}"
    local spaces
    spaces=$(printf "%*s" "$indent" "")
    while IFS= read -r line; do
        printf "%s%s\n" "$spaces" "$line"
    done
}

# Format multi-line block with borders
ui_block() {
    local title="${1:-}"
    local content="${2:-}"
    local width=$((TERMINAL_WIDTH - 4))
    
    if [[ -n "$title" ]]; then
        printf "┌%*s┐\n" "$width" "" | tr " " "─"
        printf "│ %-*s │\n" "$((width - 2))" "$title"
        printf "├%*s┤\n" "$width" "" | tr " " "─"
    else
        printf "┌%*s┐\n" "$width" "" | tr " " "─"
    fi
    
    while IFS= read -r line; do
        printf "│ %-*s │\n" "$((width - 2))" "$line"
    done <<< "$content"
    
    printf "└%*s┘\n" "$width" "" | tr " " "─"
}

# ============================================================================
# Logging Functions
# ============================================================================

# Print title with full-width border
log_title() {
    local title="$1"
    printf "\n"
    ui_hr "="
    if should_use_colors; then
        printf "${BRIGHT_CYAN}%s${NC}\n" "$title"
    else
        printf "%s\n" "$title"
    fi
    ui_hr "="
    printf "\n"
}

# Print section header
log_section() {
    local section="$1"
    printf "\n"
    if should_use_colors; then
        printf "${CYAN}━━━ %s${NC}\n" "$section"
    else
        printf "━━━ %s\n" "$section"
    fi
    printf "\n"
}

# Print step with bullet
log_step() {
    local step="$1"
    if should_use_colors; then
        printf "${CYAN}•${NC} %s\n" "$step"
    else
        printf "• %s\n" "$step"
    fi
}

# Print info message (dim)
log_info() {
    local message="$1"
    if should_use_colors; then
        printf "${GRAY}%s${NC}\n" "$message"
    else
        printf "%s\n" "$message"
    fi
}

# Print success message
log_success() {
    local message="$1"
    if should_use_colors; then
        printf "${GREEN}✓${NC} %s\n" "$message"
    else
        printf "✓ %s\n" "$message"
    fi
}

# Print warning message
log_warn() {
    local message="$1"
    if should_use_colors; then
        printf "${YELLOW}⚠${NC} %s\n" "$message" >&2
    else
        printf "⚠ %s\n" "$message" >&2
    fi
}

# Print error message
log_error() {
    local message="$1"
    if should_use_colors; then
        printf "${RED}✗${NC} %s\n" "$message" >&2
    else
        printf "✗ %s\n" "$message" >&2
    fi
}

# Print fatal error and exit
log_fatal() {
    local message="$1"
    if should_use_colors; then
        printf "${BRIGHT_RED}✗ FATAL:${NC} %s\n" "$message" >&2
    else
        printf "✗ FATAL: %s\n" "$message" >&2
    fi
    exit 1
}

# ============================================================================
# Legacy Compatibility (for gradual migration)
# ============================================================================

# These functions maintain backward compatibility with existing code
# They will be removed once all scripts are migrated

# Legacy log_step with step number (deprecated, use log_step directly)
log_step_legacy() {
    local step_num="$1"
    local step_name="$2"
    log_step "Step $step_num: $step_name"
}

