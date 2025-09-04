#!/bin/bash

# Color definitions for MSP iOS SDK build system
# This module provides centralized color constants used across all build scripts

# Standard colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export GRAY='\033[0;37m'
export NC='\033[0m' # No Color

# Bright variants
export BRIGHT_RED='\033[1;31m'
export BRIGHT_GREEN='\033[1;32m'
export BRIGHT_YELLOW='\033[1;33m'
export BRIGHT_BLUE='\033[1;34m'
export BRIGHT_PURPLE='\033[1;35m'
export BRIGHT_CYAN='\033[1;36m'

# Background colors
export BG_RED='\033[41m'
export BG_GREEN='\033[42m'
export BG_YELLOW='\033[43m'
export BG_BLUE='\033[44m'
export BG_PURPLE='\033[45m'
export BG_CYAN='\033[46m'

# Utility function to check if colors should be used
should_use_colors() {
    # Check if we're in a terminal that supports colors
    [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]] && [[ "${NO_COLOR:-}" != "1" ]]
}

# Function to get color with fallback to plain text
get_color() {
    local color="$1"
    local text="$2"
    
    if should_use_colors; then
        echo -e "${color}${text}${NC}"
    else
        echo "$text"
    fi
}

# Predefined colored output functions
color_success() { get_color "$GREEN" "$1"; }
color_error() { get_color "$RED" "$1"; }
color_warning() { get_color "$YELLOW" "$1"; }
color_info() { get_color "$BLUE" "$1"; }
color_debug() { get_color "$CYAN" "$1"; }
color_highlight() { get_color "$PURPLE" "$1"; }
