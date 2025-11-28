#!/bin/bash

# State Management Utilities for Release Scripts
# Provides functions to save, load, and manage release state

# ============================================================================
# ROOT_DIR and UI System Loading
# ============================================================================
# Calculate ROOT_DIR if not already set (may be set by parent script)
if [[ -z "${ROOT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

# Source UI system in order: colors.sh → ui.sh → logging.sh
# Handle NO_ANSI flag by setting NO_COLOR (logging.sh respects NO_COLOR)
if [[ "${NO_ANSI:-false}" == "true" ]]; then
    export NO_COLOR=1
fi

# Source colors.sh
if [[ -f "$ROOT_DIR/Scripts/lib/colors.sh" ]]; then
    # shellcheck source=Scripts/lib/colors.sh
    source "$ROOT_DIR/Scripts/lib/colors.sh" 2>/dev/null || true
fi

# Source ui.sh (depends on colors.sh)
if [[ -f "$ROOT_DIR/Scripts/lib/ui.sh" ]]; then
    # shellcheck source=Scripts/lib/ui.sh
    source "$ROOT_DIR/Scripts/lib/ui.sh" 2>/dev/null || true
fi

# Source logging.sh (depends on colors.sh and ui.sh)
if [[ -f "$ROOT_DIR/Scripts/lib/logging.sh" ]]; then
    # shellcheck source=Scripts/lib/logging.sh
    source "$ROOT_DIR/Scripts/lib/logging.sh" 2>/dev/null || true
fi

# Fallback logging functions if UI system not available
if ! command -v log_info &>/dev/null; then
    : "${RED:=[0;31m}"
    : "${GREEN:=[0;32m}"
    : "${YELLOW:=[1;33m}"
    : "${BLUE:=[0;34m}"
    : "${NC:=[0m}"
    
    log_info() {
        if [[ "${NO_ANSI:-false}" == "true" ]]; then
            echo "[INFO] $1"
        else
            echo -e "${BLUE}ℹ️  $1${NC}"
        fi
    }
    
    log_success() {
        if [[ "${NO_ANSI:-false}" == "true" ]]; then
            echo "[SUCCESS] $1"
        else
            echo -e "${GREEN}✅ $1${NC}"
        fi
    }
    
    log_warning() {
        if [[ "${NO_ANSI:-false}" == "true" ]]; then
            echo "[WARN] $1"
        else
            echo -e "${YELLOW}⚠️  $1${NC}"
        fi
    }
    
    log_error() {
        if [[ "${NO_ANSI:-false}" == "true" ]]; then
            echo "[ERROR] $1" >&2
        else
            echo -e "${RED}❌ $1${NC}" >&2
        fi
    }
    
    log_step() {
        if [[ "${NO_ANSI:-false}" == "true" ]]; then
            echo "[STEP] $1"
        else
            echo -e "${BLUE}🔧 $1${NC}"
        fi
    }
    
    log_debug() {
        if [[ "${VERBOSE:-false}" == "true" ]]; then
            if [[ "${NO_ANSI:-false}" == "true" ]]; then
                echo "[DEBUG] $1"
            else
                echo -e "${BLUE}🔍 $1${NC}"
            fi
        fi
    }
    
    log_warn() {
        log_warning "$@"
    }
fi


# Default state file location
STATE_FILE="${RELEASE_STATE_FILE:-$ROOT_DIR/.release-state.json}"

# Save release state to file
save_release_state() {
    local state_data="$1"
    local state_file="${2:-$STATE_FILE}"
    
    if [[ -z "$state_data" ]]; then
        log_error "State data is required"
        return 1
    fi
    
    log_debug "Saving release state to $state_file"
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$state_file")"
    
    # Write state to file
    echo "$state_data" > "$state_file"
    
    if [[ $? -eq 0 ]]; then
        log_success "Saved release state to $state_file"
        return 0
    else
        log_error "Failed to save release state to $state_file"
        return 1
    fi
}

# Load release state from file
load_release_state() {
    local state_file="${1:-$STATE_FILE}"
    
    if [[ ! -f "$state_file" ]]; then
        log_warning "State file not found: $state_file"
        return 1
    fi
    
    log_debug "Loading release state from $state_file"
    
    # Read state from file
    cat "$state_file"
    
    if [[ $? -eq 0 ]]; then
        log_success "Loaded release state from $state_file"
        return 0
    else
        log_error "Failed to load release state from $state_file"
        return 1
    fi
}

# Update release state (merge with existing state)
update_release_state() {
    local key="$1"
    local value="$2"
    local state_file="${3:-$STATE_FILE}"
    
    if [[ -z "$key" || -z "$value" ]]; then
        log_error "Key and value are required"
        return 1
    fi
    
    log_debug "Updating release state: $key = $value"
    
    # Load existing state or create new
    local existing_state="{}"
    if [[ -f "$state_file" ]]; then
        existing_state=$(cat "$state_file" 2>/dev/null || echo "{}")
    fi
    
    # Update state (simple JSON update - for complex cases, use jq if available)
    if command -v jq &>/dev/null; then
        # Use jq for proper JSON manipulation
        local updated_state
        updated_state=$(echo "$existing_state" | jq ". + {\"$key\": \"$value\"}" 2>/dev/null)
        if [[ $? -eq 0 ]]; then
            echo "$updated_state" > "$state_file"
            log_success "Updated release state: $key = $value"
            return 0
        fi
    fi
    
    # Fallback: simple string replacement (not perfect JSON, but works for simple cases)
    if [[ "$existing_state" == "{}" ]]; then
        echo "{\"$key\": \"$value\"}" > "$state_file"
    else
        # Remove existing key if present, then add new one
        local temp_state
        temp_state=$(echo "$existing_state" | sed "s/\"$key\":[^,}]*//" | sed 's/,,/,/g' | sed 's/,}/}/g' | sed 's/{,/{/g')
        # Add new key-value pair
        if [[ "$temp_state" == "{}" ]]; then
            echo "{\"$key\": \"$value\"}" > "$state_file"
        else
            echo "$temp_state" | sed "s/}/, \"$key\": \"$value\"}/" > "$state_file"
        fi
    fi
    
    log_success "Updated release state: $key = $value"
    return 0
}

# Reset release state (delete state file)
reset_release_state() {
    local state_file="${1:-$STATE_FILE}"
    
    log_debug "Resetting release state: $state_file"
    
    if [[ -f "$state_file" ]]; then
        rm -f "$state_file"
        if [[ $? -eq 0 ]]; then
            log_success "Reset release state"
            return 0
        else
            log_error "Failed to reset release state"
            return 1
        fi
    else
        log_info "State file does not exist, nothing to reset"
        return 0
    fi
}

# Export functions
export -f save_release_state load_release_state update_release_state reset_release_state 2>/dev/null || true


