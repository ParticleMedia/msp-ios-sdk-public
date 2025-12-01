#!/bin/bash

# ============================================================================
# Notification Utilities for Release Scripts
# ============================================================================
# Provides wrapper functions for Slack notifications with TEST/PROD mode support
#
# Environment Variables:
#   MSP_SLACK_ALERT_ENV
#     - Determines Slack notification mode: "test" or "prod" (default)
#     - TEST mode: Uses test webhook, requires MSP_SLACK_DM_OVERRIDE for DMs
#     - PROD mode: Uses YAML config webhooks and user mappings
#
#   MSP_SLACK_DM_OVERRIDE
#     - If set, ALL direct messages are sent to this Slack user_id
#     - Applies in BOTH test and prod modes
#     - Fully bypasses resolve_user() and module_owner mapping
#     - In TEST mode, if not set, DMs are skipped with a warning
#
#   MSP_SLACK_TEST_WEBHOOK
#     - In TEST mode, ALL channel notifications use this webhook URL
#     - YAML alerts.webhook is ignored in TEST mode for safety
#     - If missing in TEST mode, channel messages are skipped with a warning
#
# TEST MODE Safety:
#   - TEST mode ignores YAML webhooks to prevent accidental production notifications
#   - TEST mode requires explicit DM override to prevent hardcoded user IDs
#   - All failures are soft-fail (logged but non-blocking)
# ============================================================================

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

# ============================================================================
# Slack Notification Functions (TEST MODE Safe)
# ============================================================================

# Check if TEST MODE is enabled
notify::is_test_mode() {
    [[ "${MSP_SLACK_ALERT_ENV:-}" == "test" ]]
}

# Internal helper: Send DM to Slack user (soft-fail)
notify::_send_dm() {
    local user_id="$1"
    local message="$2"
    
    # Silent skip if no bot token
    [[ -z "${SLACK_BOT_TOKEN:-}" ]] && return 0

    # Open DM channel (silent on failure)
    local channel
    channel=$(curl -s -X POST \
      -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
      -H "Content-type: application/json; charset=utf-8" \
      --data "{\"users\": \"$user_id\"}" \
      https://slack.com/api/conversations.open 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin).get('channel',{}).get('id',''))" 2>/dev/null) || true

    [[ -z "$channel" ]] && return 0

    # Send message (silent on failure)
    curl -s -X POST \
      -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
      -H "Content-type: application/json" \
      --data "{\"channel\":\"$channel\",\"text\":\"$message\"}" \
      https://slack.com/api/chat.postMessage >/dev/null 2>&1 || true
    
    return 0
}

# Internal helper: Send message to webhook (soft-fail)
notify::_send_webhook() {
    local webhook_url="$1"
    local message="$2"
    
    [[ -z "$webhook_url" ]] && return 0
    
    # Send to webhook (silent on failure)
    curl -s -X POST \
      -H "Content-type: application/json" \
      --data "{\"text\":\"$message\"}" \
      "$webhook_url" >/dev/null 2>&1 || true
    
    return 0
}

# Load Slack mapping configuration
notify::load_mapping() {
    local mapping_file="$ROOT_DIR/Scripts/config/slack_mapping.yaml"
    [[ ! -f "$mapping_file" ]] && return 1

    eval "$(python3 - <<EOF
import yaml, json, sys
d=yaml.safe_load(open("$mapping_file"))
print("SLACK_EMAIL_MAP='"+json.dumps(d.get("email_map",{})).replace("'","'\"'\"'")+"'")
print("SLACK_MODULE_OWNER='"+json.dumps(d.get("module_owner",{})).replace("'","'\"'\"'")+"'")
print("SLACK_ALERTS='"+json.dumps(d.get("alerts",{})).replace("'","'\"'\"'")+"'")
EOF
)"
}

# Resolve Slack user ID from module or author email
# PROD MODE: Uses email_map/module_owner mapping
# TEST MODE: Returns empty (DM override required)
notify::resolve_user() {
    local module="$1"
    
    # TEST MODE: Return empty (DM override must be used)
    if notify::is_test_mode; then
        return 0
    fi
    
    # PROD MODE: Use actual mapping
    local author="${MSP_AUTHOR_EMAIL:-}"
    
    # Load mapping if not already loaded
    if [[ -z "${SLACK_EMAIL_MAP:-}" ]]; then
        notify::load_mapping || return 1
    fi
    
    local email_id
    email_id=$(python3 - <<EOF
import json
email_map=json.loads('$SLACK_EMAIL_MAP')
print(email_map.get("$author",""))
EOF
    ) 2>/dev/null || true

    [[ -n "$email_id" ]] && echo "$email_id" && return 0

    local module_owner
    module_owner=$(python3 - <<EOF
import json
m=json.loads('$SLACK_MODULE_OWNER')
print(m.get("$module", m.get("default","")))
EOF
    ) 2>/dev/null || true

    echo "$module_owner"
}

# Send direct message to Slack user
# Respects MSP_SLACK_DM_OVERRIDE if set (applies in both test and prod)
# TEST MODE: Requires MSP_SLACK_DM_OVERRIDE, otherwise logs warning and skips
# PROD MODE: Uses resolve_user() if override not set
notify::dm() {
    local user="$1"
    local message="$2"
    
    local target_user=""
    
    # Check for DM override (applies in both test and prod)
    if [[ -n "${MSP_SLACK_DM_OVERRIDE:-}" ]]; then
        target_user="$MSP_SLACK_DM_OVERRIDE"
    elif notify::is_test_mode; then
        # TEST MODE: Override required
        log_warning "TEST MODE active but MSP_SLACK_DM_OVERRIDE not set; skipping DM (soft-fail)"
        return 0
    else
        # PROD MODE: Use resolved user or provided user
        if [[ -z "$user" ]]; then
            # Try to resolve from module (if called from module_success)
            target_user="$(notify::resolve_user "" 2>/dev/null || echo "")"
        else
            target_user="$user"
        fi
    fi
    
    [[ -z "$target_user" ]] && return 0
    
    # Send DM using internal helper (soft-fail)
    notify::_send_dm "$target_user" "$message"
    return 0
}

# Send message to Slack channel
# TEST MODE: Uses MSP_SLACK_TEST_WEBHOOK (ignores YAML webhook for safety)
# PROD MODE: Uses alerts.webhook from slack_mapping.yaml
notify::channel() {
    local message="$1"

    # TEST MODE: Use test webhook only (ignore YAML webhook)
    if notify::is_test_mode; then
        local test_webhook="${MSP_SLACK_TEST_WEBHOOK:-}"
        if [[ -z "$test_webhook" ]]; then
            log_warning "TEST MODE active but MSP_SLACK_TEST_WEBHOOK not set; skipping channel message (soft-fail)"
            return 0
        fi
        
        # Send to test webhook using internal helper (soft-fail)
        notify::_send_webhook "$test_webhook" "$message"
        return 0
    fi
    
    # PROD MODE: Use YAML webhook from alerts.webhook
    if [[ -z "${SLACK_ALERTS:-}" ]]; then
        notify::load_mapping || return 0
    fi
    
    local webhook_url
    webhook_url=$(python3 - <<EOF
import json;print(json.loads('$SLACK_ALERTS').get("webhook",""))
EOF
    ) 2>/dev/null || true
    
    if [[ -n "$webhook_url" ]]; then
        # Use webhook if available (soft-fail)
        notify::_send_webhook "$webhook_url" "$message"
        return 0
    fi
    
    # Fallback: Use channel API if webhook not available
    local channel
    channel=$(python3 - <<EOF
import json;print(json.loads('$SLACK_ALERTS').get("channel",""))
EOF
    ) 2>/dev/null || true
    
    [[ -z "$channel" ]] && return 0
    [[ -z "${SLACK_BOT_TOKEN:-}" ]] && return 0

    # Send message via channel API (silent on failure)
    curl -s -X POST \
      -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
      -H "Content-type: application/json" \
      --data "{\"channel\":\"$channel\",\"text\":\"$message\"}" \
      https://slack.com/api/chat.postMessage >/dev/null 2>&1 || true
    
    return 0
}

# ============================================================================
# Message Template Functions
# ============================================================================

# Build success message template
# Returns formatted success message with exact structure
notify::build_success_message() {
    local module="$1"
    local version="$2"
    local author="$3"
    local env="$4"
    
    # Exact format as specified:
    # 🎉 Module Released Successfully  
    # Module: <module>  
    # Version: <version>  
    # Released by: <author>  
    # Environment: <env>  
    printf "🎉 Module Released Successfully\nModule: %s\nVersion: %s\nReleased by: %s\nEnvironment: %s\n" \
        "$module" \
        "$version" \
        "${author:-unknown}" \
        "$env"
}

# Build error message template
# Returns formatted error message with exact structure
notify::build_error_message() {
    local module="$1"
    local version="$2"
    local short_reason="$3"
    local author="$4"
    local env="$5"
    
    # Exact format as specified:
    # ❌ Module Release Failed  
    # Module: <module>  
    # Version: <version>  
    # Error: <short_reason>  
    printf "❌ Module Release Failed\nModule: %s\nVersion: %s\nError: %s\n" \
        "$module" \
        "$version" \
        "$short_reason"
}

# Render message based on type
# Pure function: no side effects, no logging
notify::render_message() {
    local type="$1"
    local module="$2"
    local version="$3"
    local author="$4"
    local env="$5"
    local error_reason="${6:-}"
    
    if [[ "$type" == "success" ]]; then
        notify::build_success_message "$module" "$version" "$author" "$env"
    elif [[ "$type" == "error" ]]; then
        notify::build_error_message "$module" "$version" "$error_reason" "$author" "$env"
    else
        return 1
    fi
}

# Notify module release success
# TEST MODE: Requires MSP_SLACK_DM_OVERRIDE for DM, uses MSP_SLACK_TEST_WEBHOOK for channel
# PROD MODE: Uses resolve_user() for DM, uses YAML webhook for channel
notify::module_success() {
    local module="$1"
    local version="$2"

    # Load mapping (optional, may fail silently)
    notify::load_mapping 2>/dev/null || true

    # Compute author and environment
    local author="${MSP_AUTHOR_EMAIL:-unknown}"
    local env
    if notify::is_test_mode; then
        env="test"
    else
        env="prod"
    fi

    # Build message using template
    local message
    message="$(notify::build_success_message "$module" "$version" "$author" "$env")" || true

    # Send DM (respects MSP_SLACK_DM_OVERRIDE, handles TEST MODE requirements)
    # Note: notify::dm expects (user, message) but we pass module for user resolution
    # The actual user resolution happens inside notify::dm
    notify::dm "$module" "$message" 2>/dev/null || true

    # Send channel message (uses test webhook in TEST MODE, YAML webhook in PROD MODE)
    # DM and channel MUST use the exact same body string
    notify::channel "$message" 2>/dev/null || true
    
    return 0
}

# Notify module release error
# Sends DM ONLY (no channel notification in test or prod)
# TEST MODE: Requires MSP_SLACK_DM_OVERRIDE
# PROD MODE: Uses resolve_user() unless overridden
notify::module_error() {
    local module="$1"
    local version="$2"
    local short_reason="$3"

    # Load mapping (optional, may fail silently)
    notify::load_mapping 2>/dev/null || true

    # Compute author and environment
    local author="${MSP_AUTHOR_EMAIL:-unknown}"
    local env
    if notify::is_test_mode; then
        env="test"
    else
        env="prod"
    fi

    # Build message using template
    local message
    message="$(notify::build_error_message "$module" "$version" "$short_reason" "$author" "$env")" || true

    # Send DM ONLY (no channel notification)
    # Note: notify::dm expects (user, message) but we pass module for user resolution
    # The actual user resolution happens inside notify::dm
    notify::dm "$module" "$message" 2>/dev/null || true
    
    return 0
}

# Export Slack notification functions
export -f notify::is_test_mode notify::load_mapping notify::resolve_user notify::dm notify::channel notify::module_success notify::module_error notify::build_success_message notify::build_error_message notify::render_message notify::_send_dm notify::_send_webhook 2>/dev/null || true

