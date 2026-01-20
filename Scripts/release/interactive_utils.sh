#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# MSP Release System - Interactive Utilities
# ============================================================================
# Purpose: Interactive prompt functions for CLI release workflow
#          Compatible with macOS and Linux, supports color output
# ============================================================================

# ============================================================================
# Color Support Detection
# ============================================================================
# Check if colors are supported (respect NO_COLOR environment variable)
_msp_color_supported() {
    if [[ "${NO_COLOR:-0}" == "1" ]] || [[ "${NO_ANSI:-false}" == "true" ]]; then
        return 1
    fi
    # Check if stdout is a terminal
    [[ -t 1 ]]
}

# Color codes (only if supported)
if _msp_color_supported; then
    if command -v tput >/dev/null 2>&1; then
        MSP_COLOR_RESET="$(tput sgr0)"
        MSP_COLOR_BOLD="$(tput bold)"
        MSP_COLOR_CYAN="$(tput setaf 6)"
        MSP_COLOR_GREEN="$(tput setaf 2)"
        MSP_COLOR_YELLOW="$(tput setaf 3)"
        MSP_COLOR_RED="$(tput setaf 1)"
    else
        # Fallback ANSI codes
        MSP_COLOR_RESET="\033[0m"
        MSP_COLOR_BOLD="\033[1m"
        MSP_COLOR_CYAN="\033[36m"
        MSP_COLOR_GREEN="\033[32m"
        MSP_COLOR_YELLOW="\033[33m"
        MSP_COLOR_RED="\033[31m"
    fi
else
    MSP_COLOR_RESET=""
    MSP_COLOR_BOLD=""
    MSP_COLOR_CYAN=""
    MSP_COLOR_GREEN=""
    MSP_COLOR_YELLOW=""
    MSP_COLOR_RED=""
fi

# ============================================================================
# Prompt Menu (Number Selection)
# ============================================================================
# Display a numbered menu and return the selected option index (0-based)
# Usage: msp_prompt_menu "Select option:" "Option 1" "Option 2" "Option 3"
# Returns: selected index (0, 1, 2, ...)
msp_prompt_menu() {
    local prompt="$1"
    shift
    local options=("$@")
    local num_options=${#options[@]}
    local choice
    
    # Display prompt
    echo "${MSP_COLOR_BOLD}${MSP_COLOR_CYAN}${prompt}${MSP_COLOR_RESET}"
    
    # Display options
    for i in $(seq 0 $((num_options - 1))); do
        echo "  $((i + 1))) ${options[$i]}"
    done
    
    # Read user input
    while true; do
        echo -n "${MSP_COLOR_BOLD}Your choice:${MSP_COLOR_RESET} "
        read -r choice
        
        # Validate input
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$num_options" ]]; then
            echo "$((choice - 1))"
            return 0
        else
            echo "${MSP_COLOR_RED}Invalid choice. Please enter a number between 1 and $num_options.${MSP_COLOR_RESET}"
        fi
    done
}

# ============================================================================
# Yes/No Prompt
# ============================================================================
# Prompt for yes/no confirmation
# Usage: msp_prompt_yes_no "Continue?" "N"
# Returns: 0 for yes, 1 for no
msp_prompt_yes_no() {
    local prompt="$1"
    local default="${2:-N}"
    local default_upper=$(echo "$default" | tr '[:lower:]' '[:upper:]' 2>/dev/null || echo "$default" | awk '{print toupper($0)}')
    local response
    
    # Build prompt with default
    if [[ "$default_upper" == "Y" ]]; then
        local prompt_text="${prompt} (Y/n)"
    else
        local prompt_text="${prompt} (y/N)"
    fi
    
    while true; do
        echo -n "${MSP_COLOR_BOLD}${prompt_text}${MSP_COLOR_RESET} "
        read -r response
        
        # Handle empty input (use default)
        if [[ -z "$response" ]]; then
            response="$default_upper"
        else
            response=$(echo "$response" | tr '[:lower:]' '[:upper:]' 2>/dev/null || echo "$response" | awk '{print toupper($0)}')
        fi
        
        case "$response" in
            Y|YES)
                return 0
                ;;
            N|NO)
                return 1
                ;;
            *)
                echo "${MSP_COLOR_RED}Please enter 'y' or 'n'.${MSP_COLOR_RESET}"
                ;;
        esac
    done
}

# ============================================================================
# Text Input Prompt
# ============================================================================
# Prompt for text input with optional default value
# Usage: msp_prompt_text "Enter version:" "1.0.0"
# Returns: user input or default if empty
msp_prompt_text() {
    local prompt="$1"
    local default="${2:-}"
    local response
    
    if [[ -n "$default" ]]; then
        local prompt_text="${prompt} [${MSP_COLOR_CYAN}${default}${MSP_COLOR_RESET}]"
    else
        local prompt_text="${prompt}"
    fi
    
    echo -n "${MSP_COLOR_BOLD}${prompt_text}${MSP_COLOR_RESET} "
    read -r response
    
    # Return default if empty, otherwise return user input
    if [[ -z "$response" ]]; then
        echo "$default"
    else
        echo "$response"
    fi
}

# ============================================================================
# Multi-Select Checkbox Menu
# ============================================================================
# Display a multi-select checkbox menu
# Usage: msp_prompt_checkboxes "Select components:" "CocoaPods" "SPM" "XCF verify"
# Returns: space-separated list of selected indices (0-based)
msp_prompt_checkboxes() {
    local prompt="$1"
    shift
    local options=("$@")
    local num_options=${#options[@]}
    local selected=()
    local choice
    local i
    
    # Display prompt
    echo "${MSP_COLOR_BOLD}${MSP_COLOR_CYAN}${prompt}${MSP_COLOR_RESET}"
    
    # Display options with checkboxes
    for i in $(seq 0 $((num_options - 1))); do
        echo "  [ ] ${options[$i]}"
    done
    
    echo ""
    echo "${MSP_COLOR_YELLOW}Enter numbers to toggle (e.g., '1 3' to toggle options 1 and 3), or 'done' to finish:${MSP_COLOR_RESET}"
    
    # Track selected state
    local selected_state=()
    for i in $(seq 0 $((num_options - 1))); do
        selected_state[$i]=0
    done
    
    while true; do
        echo -n "${MSP_COLOR_BOLD}Your choice:${MSP_COLOR_RESET} "
        read -r choice
        
        if [[ "$choice" == "done" ]] || [[ "$choice" == "d" ]]; then
            break
        fi
        
        # Parse space-separated numbers
        for num in $choice; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le "$num_options" ]]; then
                local idx=$((num - 1))
                # Toggle state
                if [[ "${selected_state[$idx]}" -eq 0 ]]; then
                    selected_state[$idx]=1
                else
                    selected_state[$idx]=0
                fi
            fi
        done
        
        # Redraw menu with current selections
        echo ""
        echo "${MSP_COLOR_BOLD}${MSP_COLOR_CYAN}${prompt}${MSP_COLOR_RESET}"
        for i in $(seq 0 $((num_options - 1))); do
            if [[ "${selected_state[$i]}" -eq 1 ]]; then
                echo "  ${MSP_COLOR_GREEN}[✓]${MSP_COLOR_RESET} ${options[$i]}"
            else
                echo "  [ ] ${options[$i]}"
            fi
        done
        echo ""
    done
    
    # Build result list
    local result=""
    for i in $(seq 0 $((num_options - 1))); do
        if [[ "${selected_state[$i]}" -eq 1 ]]; then
            if [[ -z "$result" ]]; then
                result="$i"
            else
                result="$result $i"
            fi
        fi
    done
    
    echo "$result"
}

