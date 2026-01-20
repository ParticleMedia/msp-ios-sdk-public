#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

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

    # Fallback to walking up from SCRIPT_DIR
    if [[ -z "${ROOT_DIR:-}" ]]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        ROOT_DIR="$SCRIPT_DIR"
        while [[ "$ROOT_DIR" != "/" ]] && [[ "${ROOT_DIR##*/}" != "Scripts" ]]; do
            ROOT_DIR="$(dirname "$ROOT_DIR")"
        done
        if [[ "${ROOT_DIR##*/}" == "Scripts" ]]; then
            ROOT_DIR="$(dirname "$ROOT_DIR")"
        fi
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

# Load unified logger system (provides log::warn, log::debug, etc.)
if [[ -f "$ROOT_DIR/Scripts/release/utils/logger.sh" ]]; then
    # shellcheck source=Scripts/release/utils/logger.sh
    source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true
fi

# Fallback: if log:: namespace functions are not available, define them
# This prevents "command not found" errors in subshells or when logger.sh source fails
if ! command -v log::warn &>/dev/null; then
    log::warn() {
        local module="${1:-GENERAL}"
        local message="$2"
        echo "[WARN] [$module] $message" >&2
    }
    log::debug() {
        local module="${1:-GENERAL}"
        local message="$2"
        [[ "${MSP_LOG_LEVEL:-1}" -le 0 ]] && echo "[DEBUG] [$module] $message" >&2
    }
    log::info() {
        local module="${1:-GENERAL}"
        local message="$2"
        echo "[INFO] [$module] $message" >&2
    }
    log::error() {
        local module="${1:-GENERAL}"
        local message="$2"
        echo "[ERROR] [$module] $message" >&2
    }
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

# Internal helper: Send DM to Slack user (with detailed logging)
notify::_send_dm() {
    local user_id="$1"
    local message="$2"

    # Define local logging functions for this function's scope
    # Use simple stderr output - reliable and doesn't depend on external loggers
    log_debug() { echo "[DEBUG] $*" >&2; }
    log_info() { echo "[INFO] $*" >&2; }
    log_warn() { echo "[WARN] $*" >&2; }
    log_error() { echo "[ERROR] $*" >&2; }

    log_debug "Attempting to send DM to user: $user_id"

    # Check for bot token
    if [[ -z "${SLACK_BOT_TOKEN:-}" ]]; then
        log_error "SLACK_BOT_TOKEN not set - DM will not be sent"
        log_warn "Please configure SLACK_BOT_TOKEN in Scripts/config/slack.conf"
        log_warn "DM message was: ${message:0:100}..."
        return 1  # Return failure status
    fi

    log_debug "SLACK_BOT_TOKEN is set: ${SLACK_BOT_TOKEN:0:20}..."

    # Validate token before attempting to use it
    log_debug "Validating Slack Bot Token..."
    local auth_response
    auth_response=$(curl -s -X POST \
      -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
      -H "Content-type: application/json" \
      https://slack.com/api/auth.test 2>&1)

    local auth_ok
    auth_ok=$(echo "$auth_response" | python3 -c "import sys, json; data=json.load(sys.stdin); print('True' if data.get('ok') else 'False')" 2>/dev/null || echo "false")

    if [[ "$auth_ok" != "True" ]]; then
        log_error "Slack Bot Token validation failed"
        local error_msg
        error_msg=$(echo "$auth_response" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('error', 'unknown error'))" 2>/dev/null || echo "unknown error")
        log_error "Slack API error: $error_msg"
        log_debug "Full API response: $auth_response"
        log_warn "Please check SLACK_BOT_TOKEN in Scripts/config/slack.conf"
        log_warn "Token may be expired or invalid. Regenerate token at: https://api.slack.com/apps"
        log_warn "Required scopes: chat:write, im:write, users:read"
        return 1
    fi

    log_debug "Slack Bot Token validated successfully"

    # Open DM channel with error handling
    log_debug "Opening DM channel with Slack user: $user_id"
    local api_response
    api_response=$(curl -s -X POST \
      -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
      -H "Content-type: application/json; charset=utf-8" \
      --data "{\"users\": \"$user_id\"}" \
      https://slack.com/api/conversations.open 2>&1)

    # Check API response for errors
    local ok_status
    ok_status=$(echo "$api_response" | python3 -c "import sys, json; data=json.load(sys.stdin); print('True' if data.get('ok') else 'False')" 2>/dev/null || echo "false")

    if [[ "$ok_status" != "True" ]]; then
        log_error "Failed to open DM channel with user: $user_id"
        # Extract error message from API response
        local error_msg
        error_msg=$(echo "$api_response" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('error', 'unknown error'))" 2>/dev/null || echo "unknown error")
        log_error "Slack API error: $error_msg"
        log_debug "Full API response: $api_response"
        return 1
    fi

    # Extract channel ID
    local channel
    channel=$(echo "$api_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('channel',{}).get('id',''))" 2>/dev/null || echo "")

    if [[ -z "$channel" ]]; then
        log_error "Failed to extract channel ID from Slack API response"
        log_debug "API response: $api_response"
        return 1
    fi

    log_debug "DM channel opened successfully: $channel"

    # Send message with error handling
    log_debug "Sending message to channel: $channel"
    local send_response
    send_response=$(curl -s -X POST \
      -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
      -H "Content-type: application/json" \
      --data "{\"channel\":\"$channel\",\"text\":\"$message\"}" \
      https://slack.com/api/chat.postMessage 2>&1)

    # Check send response
    local send_ok
    send_ok=$(echo "$send_response" | python3 -c "import sys, json; data=json.load(sys.stdin); print('True' if data.get('ok') else 'False')" 2>/dev/null || echo "false")

    if [[ "$send_ok" != "True" ]]; then
        log_error "Failed to send DM to user: $user_id"
        local error_msg
        error_msg=$(echo "$send_response" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('error', 'unknown error'))" 2>/dev/null || echo "unknown error")
        log_error "Slack API error: $error_msg"
        log_debug "Full API response: $send_response"
        return 1
    fi

    log_info "✓ DM sent successfully to user: $user_id"
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

    # Load existing mappings (email_map, module_owner, alerts)
    eval "$(python3 - <<EOF
import yaml, json, sys
d=yaml.safe_load(open("$mapping_file"))
print("SLACK_EMAIL_MAP='"+json.dumps(d.get("email_map",{})).replace("'","'\"'\"'")+"'")
print("SLACK_MODULE_OWNER='"+json.dumps(d.get("module_owner",{})).replace("'","'\"'\"'")+"'")
print("SLACK_ALERTS='"+json.dumps(d.get("alerts",{})).replace("'","'\"'\"'")+"'")
EOF
)" || return 1

    # Load templates section (optional, soft-fail if missing or malformed)
    local templates_json
    templates_json=$(python3 - <<EOF
import yaml, json, sys
try:
    d=yaml.safe_load(open("$mapping_file"))
    templates = d.get("templates", {})
    if templates:
        # Escape single quotes and newlines for shell
        success = templates.get("success", "").replace("'", "'\"'\"'").replace("\n", "\\n")
        error = templates.get("error", "").replace("'", "'\"'\"'").replace("\n", "\\n")
        print("NOTIFY_TEMPLATE_SUCCESS='"+success+"'")
        print("NOTIFY_TEMPLATE_ERROR='"+error+"'")
except Exception as e:
    # Silent failure - templates are optional
    pass
EOF
    ) 2>/dev/null || true

    # Only set template variables if parsing succeeded and templates exist
    if [[ -n "$templates_json" ]]; then
        eval "$templates_json" 2>/dev/null || {
            log_warning "Failed to load Slack message templates from YAML; using built-in defaults"
            unset NOTIFY_TEMPLATE_SUCCESS
            unset NOTIFY_TEMPLATE_ERROR
        }
    else
        # Templates section missing or empty - use defaults (variables remain unset)
        unset NOTIFY_TEMPLATE_SUCCESS
        unset NOTIFY_TEMPLATE_ERROR
    fi
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
    
    # Send DM using internal helper
    if ! notify::_send_dm "$target_user" "$message"; then
        # Log failure but don't block execution (non-critical)
        if command -v log_warning &>/dev/null; then
            log_warning "Failed to send DM notification to user: $target_user"
        fi
        return 1
    fi
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
    
    # PROD MODE: Use webhook with priority order
    # Priority:
    #   1. SLACK_WEBHOOK_URL (from slack.conf or environment variable)
    #   2. alerts.webhook from slack_mapping.yaml (fallback, deprecated)

    local webhook_url=""

    # Try environment variable first (highest priority)
    if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
        webhook_url="$SLACK_WEBHOOK_URL"
        log_debug "Using SLACK_WEBHOOK_URL from environment/slack.conf: ${webhook_url:0:40}..."
    else
        # Fallback to YAML webhook (deprecated)
        if [[ -z "${SLACK_ALERTS:-}" ]]; then
            notify::load_mapping || return 0
        fi

        webhook_url=$(python3 - <<EOF
import json;print(json.loads('$SLACK_ALERTS').get("webhook",""))
EOF
        ) 2>/dev/null || true

        if [[ -n "$webhook_url" ]]; then
            log_debug "Using webhook from slack_mapping.yaml (deprecated, please migrate to SLACK_WEBHOOK_URL in slack.conf)"
        fi
    fi

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
# Uses config-driven template if available, falls back to hard-coded default
notify::build_success_message() {
    local module="$1"
    local version="$2"
    local author="$3"
    local env="$4"
    
    # Use config template if available
    if [[ -n "${NOTIFY_TEMPLATE_SUCCESS:-}" ]]; then
        local template="${NOTIFY_TEMPLATE_SUCCESS}"
        # Replace placeholders using parameter expansion (safe for typical values)
        template="${template//\{\{MODULE\}\}/$module}"
        template="${template//\{\{VERSION\}\}/$version}"
        template="${template//\{\{AUTHOR\}\}/${author:-unknown}}"
        template="${template//\{\{ENV\}\}/$env}"
        # Convert \n to actual newlines
        echo -e "$template"
        return 0
    fi
    
    # Fallback to hard-coded default template
    printf "🎉 Module Released Successfully\nModule: %s\nVersion: %s\nReleased by: %s\nEnvironment: %s\n" \
        "$module" \
        "$version" \
        "${author:-unknown}" \
        "$env"
}

# Build error message template
# Returns formatted error message with exact structure
# Uses config-driven template if available, falls back to hard-coded default
notify::build_error_message() {
    local module="$1"
    local version="$2"
    local short_reason="$3"
    local author="$4"
    local env="$5"
    
    # Use config template if available
    if [[ -n "${NOTIFY_TEMPLATE_ERROR:-}" ]]; then
        local template="${NOTIFY_TEMPLATE_ERROR}"
        # Replace placeholders using parameter expansion (safe for typical values)
        template="${template//\{\{MODULE\}\}/$module}"
        template="${template//\{\{VERSION\}\}/$version}"
        template="${template//\{\{ERROR\}\}/$short_reason}"
        template="${template//\{\{AUTHOR\}\}/${author:-unknown}}"
        template="${template//\{\{ENV\}\}/$env}"
        # Convert \n to actual newlines
        echo -e "$template"
        return 0
    fi
    
    # Fallback to hard-coded default template
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
# DEPRECATED: Module-level success notifications are disabled
# This function is now a NO-OP to maintain backward compatibility
notify::module_success() {
    # Module-level success sends nothing (Slack OR Email)
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
    if ! notify::dm "$module" "$message"; then
        # Log failure for debugging
        if command -v log_warning &>/dev/null; then
            log_warning "Failed to send error notification for module: $module"
            log_warning "Error message was: ${short_reason:0:100}..."
        fi
    fi

    # Always return 0 (non-blocking)
    return 0
}

# Notify global release success (DM only)
# Sends DM to appropriate user based on TEST/PROD mode and routing rules
# Soft-fail always
# DEPRECATED: Use notify::send_release_summary() instead
# This function is kept for backward compatibility only
notify::release_success_dm() {
    local version="$1"
    
    # Build message with verification status if available
    local message="MSP Release Success — Version: $version"
    if [[ -n "${REMOTE_VERIFY_STATUS:-}" ]]; then
        message="$message"$'\n\n'"Verification:"$'\n'"${REMOTE_VERIFY_STATUS}"
    fi
    
    # Send DM using existing routing logic (respects MSP_SLACK_DM_OVERRIDE, TEST/PROD mode)
    notify::dm "" "$message" 2>/dev/null || true
    
    return 0
}

# Notify global release success (Channel broadcast only)
# Sends to channel using TEST/PROD webhook rules
# Soft-fail always
# DEPRECATED: Use notify::send_release_summary() instead
# This function is kept for backward compatibility only
notify::release_success_channel() {
    local version="$1"
    
    # Build message with verification status if available
    local message="MSP Release Success — Version: $version"
    if [[ -n "${REMOTE_VERIFY_STATUS:-}" ]]; then
        message="$message"$'\n\n'"Verification:"$'\n'"${REMOTE_VERIFY_STATUS}"
    fi
    
    # Send channel message using existing routing logic (TEST/PROD webhook rules)
    notify::channel "$message" 2>/dev/null || true
    
    return 0
}

# Export Slack notification functions
export -f notify::is_test_mode notify::load_mapping notify::resolve_user notify::dm notify::channel notify::module_success notify::module_error notify::build_success_message notify::build_error_message notify::render_message notify::_send_dm notify::_send_webhook notify::release_success_dm notify::release_success_channel 2>/dev/null || true

