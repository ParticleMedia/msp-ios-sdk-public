#!/bin/bash

# Notification Utilities for Release Scripts
# Provides wrapper functions for Slack notifications

# ============================================================================
# ROOT_DIR and UI System Loading
# ============================================================================
# ========================================
# Unified ROOT_DIR resolution (final)
# ========================================
# The root dir is always the directory that contains
# the parent Scripts/ folder where msp-release.sh lives.
if [[ -z "${ROOT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # Find Scripts/ directory by going up until we find it, then go up one more level
    ROOT_DIR="$SCRIPT_DIR"
    while [[ "$ROOT_DIR" != "/" ]] && [[ "${ROOT_DIR##*/}" != "Scripts" ]]; do
        ROOT_DIR="$(dirname "$ROOT_DIR")"
    done
    # If we found Scripts/, go up one more level to get repo root
    if [[ "${ROOT_DIR##*/}" == "Scripts" ]]; then
        ROOT_DIR="$(dirname "$ROOT_DIR")"
    fi
fi
export ROOT_DIR

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


# Source Slack notification module
if [[ -f "$ROOT_DIR/Scripts/notify/slack.sh" ]]; then
    # shellcheck source=Scripts/notify/slack.sh
    source "$ROOT_DIR/Scripts/notify/slack.sh" 2>/dev/null || true
else
    # Fallback: Define stub functions if module not found
    log_warning "notify/slack.sh not found - Slack notifications will be disabled"
    send_slack_notification() { log_warning "Slack notifications disabled (module not found)"; }
    notify_release_success() { :; }
    notify_release_failure() { :; }
    notify_release_warning() { :; }
    notify_release_start() { :; }
    notify_pod_release() { :; }
    notify_release_summary() { :; }
    notify_release_success_with_summary() { :; }
fi

# Notify release start
notify_start() {
    local release_type="${1:-Release}"
    local version="${2:-}"
    
    if [[ -n "$version" ]]; then
        notify_release_start "$release_type" "$version"
    else
        notify_release_start "$release_type"
    fi
}

# Notify release success
notify_success() {
    local release_type="${1:-Release}"
    local version="${2:-}"
    local message="${3:-}"
    
    if [[ -n "$message" ]]; then
        notify_release_success "$release_type" "$version" "$message"
    elif [[ -n "$version" ]]; then
        notify_release_success "$release_type" "$version"
    else
        notify_release_success "$release_type"
    fi
}

# Notify release failure
notify_failure() {
    local release_type="${1:-Release}"
    local version="${2:-}"
    local error_message="${3:-}"
    local stage="${4:-}"
    
    if [[ -n "$stage" ]]; then
        notify_release_failure "$release_type" "$version" "$error_message" "$stage"
    elif [[ -n "$error_message" ]]; then
        notify_release_failure "$release_type" "$version" "$error_message"
    elif [[ -n "$version" ]]; then
        notify_release_failure "$release_type" "$version"
    else
        notify_release_failure "$release_type"
    fi
}

# Notify release warning
notify_warning() {
    local release_type="${1:-Release}"
    local version="${2:-}"
    local warning_message="${3:-}"
    
    if [[ -n "$warning_message" ]]; then
        notify_release_warning "$release_type" "$version" "$warning_message"
    elif [[ -n "$version" ]]; then
        notify_release_warning "$release_type" "$version"
    else
        notify_release_warning "$release_type"
    fi
}

# Notify release summary
notify_summary() {
    local release_type="${1:-Release}"
    local version="${2:-}"
    local summary_data="${3:-}"
    
    if [[ -n "$summary_data" ]]; then
        notify_release_summary "$release_type" "$version" "$summary_data"
    elif [[ -n "$version" ]]; then
        notify_release_summary "$release_type" "$version"
    else
        notify_release_summary "$release_type"
    fi
}

# Export functions
export -f notify_start notify_success notify_failure notify_warning notify_summary 2>/dev/null || true


