#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Slack Notification Module
# ============================================================================
# Purpose: Centralized Slack notification functions for the MSP iOS SDK
#          release system. Extracted from lib/release-common.sh for better
#          modularity.
#
# Usage:   source Scripts/notify/slack.sh
#
# Required Environment Variables:
#   SLACK_WEBHOOK_URL - Slack incoming webhook URL (required for notifications)
#
# Optional Environment Variables:
#   SLACK_CHANNEL     - Target channel (default: #releases)
#   SLACK_USERNAME    - Bot username (default: MSP iOS SDK Bot)
#   SLACK_ICON_EMOJI  - Bot icon (default: :rocket:)
#
# Configuration:
#   Can also be configured via Scripts/config/slack.conf
#   Environment variables take precedence over config file values.
# ============================================================================

# Prevent multiple sourcing
[[ -n "${_NOTIFY_SLACK_SOURCED:-}" ]] && return 0
readonly _NOTIFY_SLACK_SOURCED=1

# ============================================================================
# Determine script directory and root
# ============================================================================
_NOTIFY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_NOTIFY_ROOT_DIR="$(cd "$_NOTIFY_SCRIPT_DIR/../.." && pwd)"

# ============================================================================
# Logging Stubs (can be overridden by sourcing lib/logging.sh first)
# ============================================================================
if ! command -v log_debug &>/dev/null; then
    log_debug() { :; }
fi
if ! command -v log_info &>/dev/null; then
    log_info() { echo "ℹ️  $1"; }
fi
if ! command -v log_success &>/dev/null; then
    log_success() { echo "✅ $1"; }
fi
if ! command -v log_warning &>/dev/null; then
    log_warning() { echo "⚠️  $1"; }
fi
if ! command -v log_error &>/dev/null; then
    log_error() { echo "❌ $1" >&2; }
fi
if ! command -v log_step &>/dev/null; then
    log_step() { echo "🔧 $1"; }
fi

# ============================================================================
# Load Slack Configuration
# ============================================================================
# Loads configuration from Scripts/config/slack.conf if it exists.
# Environment variables take precedence over config file values.
load_slack_config() {
    local config_dir="$_NOTIFY_ROOT_DIR/Scripts/config"
    local config_file="${config_dir}/slack.conf"
    
    if [[ -f "$config_file" ]]; then
        log_debug "Loading Slack configuration from: $config_file"
        
        # Read the config file line by line
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip comments and empty lines
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${line// }" ]] && continue
            
            # Parse key=value pairs
            if [[ "$line" =~ ^[[:space:]]*([^=]+)=(.*)$ ]]; then
                local key="${BASH_REMATCH[1]}"
                local value="${BASH_REMATCH[2]}"
                
                # Remove leading/trailing whitespace from key
                key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                
                # Remove leading/trailing whitespace and quotes from value
                value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
                
                # Only set if not already set in environment (environment takes precedence)
                if [[ -n "$key" ]] && [[ -n "$value" ]]; then
                    case "$key" in
                        SLACK_WEBHOOK_URL)
                            [[ -z "${SLACK_WEBHOOK_URL:-}" ]] && export SLACK_WEBHOOK_URL="$value"
                            ;;
                        SLACK_CHANNEL)
                            [[ -z "${SLACK_CHANNEL:-}" ]] && export SLACK_CHANNEL="$value"
                            ;;
                        SLACK_USERNAME)
                            [[ -z "${SLACK_USERNAME:-}" ]] && export SLACK_USERNAME="$value"
                            ;;
                        SLACK_ICON_EMOJI)
                            [[ -z "${SLACK_ICON_EMOJI:-}" ]] && export SLACK_ICON_EMOJI="$value"
                            ;;
                    esac
                fi
            fi
        done < "$config_file"
    else
        log_debug "Slack config file not found: $config_file (using environment variables or defaults)"
    fi
}

# Load configuration on source
load_slack_config

# Slack configuration with defaults
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
SLACK_CHANNEL="${SLACK_CHANNEL:-#releases}"
SLACK_USERNAME="${SLACK_USERNAME:-MSP iOS SDK Bot}"
SLACK_ICON_EMOJI="${SLACK_ICON_EMOJI:-:rocket:}"

# ============================================================================
# Environment Detection
# ============================================================================
get_slack_environment() {
    if [[ -n "${JENKINS_URL:-}" ]]; then
        echo "jenkins"
    elif [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        echo "github-actions"
    elif [[ -n "${CI:-}" ]]; then
        echo "ci"
    else
        echo "local"
    fi
}

get_slack_environment_info() {
    local env
    env=$(get_slack_environment)
    case "$env" in
        "jenkins")
            echo "Jenkins Build #${BUILD_NUMBER:-unknown}"
            ;;
        "github-actions")
            echo "GitHub Actions - ${GITHUB_WORKFLOW:-unknown workflow}"
            ;;
        "ci")
            echo "CI Environment"
            ;;
        "local")
            local hostname
            hostname=$(hostname)
            echo "Local Development - $(whoami)@${hostname}"
            ;;
        *)
            echo "Unknown Environment"
            ;;
    esac
}

# ============================================================================
# Formatting Helpers
# ============================================================================

# Convert markdown to Slack formatting
format_release_notes_for_slack() {
    local release_notes="$1"
    
    if [[ -z "$release_notes" ]]; then
        echo ""
        return
    fi
    
    # Convert markdown headers to Slack bold
    local formatted_notes
    formatted_notes=$(echo "$release_notes" | sed 's/^## \(.*\)$/*\1*/g')
    formatted_notes=$(echo "$formatted_notes" | sed 's/^### \(.*\)$/*\1*/g')
    
    # Convert markdown lists to Slack formatting
    formatted_notes=$(echo "$formatted_notes" | sed 's/^- /• /g')
    
    # Clean up extra whitespace but preserve line breaks
    formatted_notes=$(echo "$formatted_notes" | sed 's/^[[:space:]]*//g' | sed 's/[[:space:]]*$//g')
    
    # Replace multiple newlines with single newline
    formatted_notes=$(echo "$formatted_notes" | tr -s '\n')
    
    # Truncate if too long for Slack (count characters including newlines)
    local char_count
    char_count=$(echo "$formatted_notes" | wc -c)
    if [[ $char_count -gt 200 ]]; then
        # Truncate to 197 characters and add ellipsis
        formatted_notes=$(echo "$formatted_notes" | head -c 197)
        formatted_notes="${formatted_notes}..."
    fi
    
    echo "$formatted_notes"
}

# ============================================================================
# Core Notification Function
# ============================================================================

# Send Slack notification
# Args: message, color, title, fields (JSON array items)
send_slack_notification() {
    local message="$1"
    local color="${2:-good}"
    local title="${3:-}"
    local fields="${4:-}"
    
    if [[ -z "$SLACK_WEBHOOK_URL" ]]; then
        log_warning "SLACK_WEBHOOK_URL not set, skipping Slack notification"
        return 0
    fi
    
    # Escape special characters for JSON
    local escaped_message
    local escaped_title
    local escaped_footer
    escaped_message=$(echo "$message" | sed 's/"/\\"/g' | sed 's/\\/\\\\/g')
    escaped_title=$(echo "$title" | sed 's/"/\\"/g' | sed 's/\\/\\\\/g')
    escaped_footer=$(get_slack_environment_info | sed 's/"/\\"/g' | sed 's/\\/\\\\/g')
    
    # Build the JSON payload
    local json_payload
    json_payload=$(cat <<EOF
{
    "channel": "$SLACK_CHANNEL",
    "username": "$SLACK_USERNAME",
    "icon_emoji": "$SLACK_ICON_EMOJI",
    "text": "$escaped_message",
    "attachments": [
        {
            "color": "$color",
            "title": "$escaped_title",
            "fields": [$fields],
            "footer": "$escaped_footer",
            "ts": $(date +%s)
        }
    ]
}
EOF
)
    
    # Send the notification
    local response
    response=$(curl -s -X POST -H 'Content-type: application/json' \
        --data "$json_payload" \
        "$SLACK_WEBHOOK_URL" 2>/dev/null)
    
    if [[ "$response" == "ok" ]]; then
        log_success "Slack notification sent successfully"
    else
        log_warning "Failed to send Slack notification: $response"
    fi
}

# ============================================================================
# High-Level Notification Functions
# ============================================================================

# Send release success notification
notify_release_success() {
    local release_type="$1"
    local version="$2"
    local pods="$3"
    local duration="${4:-unknown}"
    local release_notes="${5:-}"
    
    local message="🚀 *${release_type} Release Successful!*"
    local title="Release Details"
    local fields=""
    
    # Add version field
    fields+="{\"title\": \"Version\", \"value\": \"$version\", \"short\": true},"
    
    # Add pods field
    if [[ -n "$pods" ]]; then
        fields+="{\"title\": \"Released Pods\", \"value\": \"$pods\", \"short\": true},"
    fi
    
    # Add duration field
    fields+="{\"title\": \"Duration\", \"value\": \"$duration\", \"short\": true},"
    
    # Add environment field
    fields+="{\"title\": \"Environment\", \"value\": \"$(get_slack_environment_info)\", \"short\": true}"
    
    # Add release notes if provided
    if [[ -n "$release_notes" ]]; then
        local formatted_notes
        formatted_notes=$(format_release_notes_for_slack "$release_notes")
        fields+=",{\"title\": \"Release Notes\", \"value\": \"$formatted_notes\", \"short\": false}"
    fi
    
    send_slack_notification "$message" "good" "$title" "$fields"
}

# Send release failure notification
notify_release_failure() {
    local release_type="$1"
    local version="$2"
    local error_message="$3"
    local failed_step="${4:-unknown}"
    
    local message="❌ *${release_type} Release Failed!*"
    local title="Release Error Details"
    local fields=""
    
    # Add version field
    fields+="{\"title\": \"Version\", \"value\": \"$version\", \"short\": true},"
    
    # Add failed step field
    fields+="{\"title\": \"Failed Step\", \"value\": \"$failed_step\", \"short\": true},"
    
    # Add error message field
    fields+="{\"title\": \"Error Message\", \"value\": \"$error_message\", \"short\": false},"
    
    # Add environment field
    fields+="{\"title\": \"Environment\", \"value\": \"$(get_slack_environment_info)\", \"short\": true}"
    
    send_slack_notification "$message" "danger" "$title" "$fields"
}

# Send release warning notification
notify_release_warning() {
    local release_type="$1"
    local version="$2"
    local warning_message="$3"
    local warning_step="${4:-unknown}"
    
    local message="⚠️ *${release_type} Release Completed with Warnings*"
    local title="Release Warning Details"
    local fields=""
    
    # Add version field
    fields+="{\"title\": \"Version\", \"value\": \"$version\", \"short\": true},"
    
    # Add warning step field
    fields+="{\"title\": \"Warning Step\", \"value\": \"$warning_step\", \"short\": true},"
    
    # Add warning message field
    fields+="{\"title\": \"Warning Message\", \"value\": \"$warning_message\", \"short\": false},"
    
    # Add environment field
    fields+="{\"title\": \"Environment\", \"value\": \"$(get_slack_environment_info)\", \"short\": true}"
    
    send_slack_notification "$message" "warning" "$title" "$fields"
}

# Send release start notification
notify_release_start() {
    local release_type="$1"
    local version="$2"
    local pods="$3"
    local release_notes="${4:-}"
    
    local message="🔄 *${release_type} Release Started*"
    local title="Release Information"
    local fields=""
    
    # Add version field
    fields+="{\"title\": \"Version\", \"value\": \"$version\", \"short\": true},"
    
    # Add pods field
    if [[ -n "$pods" ]]; then
        fields+="{\"title\": \"Pods to Release\", \"value\": \"$pods\", \"short\": true},"
    fi
    
    # Add environment field
    fields+="{\"title\": \"Environment\", \"value\": \"$(get_slack_environment_info)\", \"short\": true}"
    
    # Add release notes if provided
    if [[ -n "$release_notes" ]]; then
        local formatted_notes
        formatted_notes=$(format_release_notes_for_slack "$release_notes")
        fields+=",{\"title\": \"Release Notes\", \"value\": \"$formatted_notes\", \"short\": false}"
    fi
    
    send_slack_notification "$message" "#36a64f" "$title" "$fields"
}

# Send individual pod release notification
notify_pod_release() {
    local pod="$1"
    local version="$2"
    local pod_status="$3"  # success, failure, warning
    local message="$4"
    
    local emoji=""
    local color=""
    
    case "$pod_status" in
        "success")
            emoji="✅"
            color="good"
            ;;
        "failure")
            emoji="❌"
            color="danger"
            ;;
        "warning")
            emoji="⚠️"
            color="warning"
            ;;
        *)
            emoji="ℹ️"
            color="#36a64f"
            ;;
    esac
    
    local slack_message="${emoji} *${pod}* v${version}"
    if [[ -n "$message" ]]; then
        slack_message+="
$message"
    fi
    
    local fields="{\"title\": \"Pod\", \"value\": \"$pod\", \"short\": true},"
    fields+="{\"title\": \"Version\", \"value\": \"$version\", \"short\": true},"
    fields+="{\"title\": \"Status\", \"value\": \"$pod_status\", \"short\": true}"
    
    send_slack_notification "$slack_message" "$color" "Pod Release Update" "$fields"
}

# Send release summary notification
notify_release_summary() {
    local release_type="$1"
    local version="$2"
    local total_pods="$3"
    local successful_pods="$4"
    local failed_pods="$5"
    local duration="$6"
    
    local message="📊 *${release_type} Release Summary*"
    local title="Release Statistics"
    local fields=""
    
    # Add version field
    fields+="{\"title\": \"Version\", \"value\": \"$version\", \"short\": true},"
    
    # Add total pods field
    fields+="{\"title\": \"Total Pods\", \"value\": \"$total_pods\", \"short\": true},"
    
    # Add successful pods field
    fields+="{\"title\": \"Successful\", \"value\": \"$successful_pods\", \"short\": true},"
    
    # Add failed pods field
    fields+="{\"title\": \"Failed\", \"value\": \"$failed_pods\", \"short\": true},"
    
    # Add duration field
    fields+="{\"title\": \"Duration\", \"value\": \"$duration\", \"short\": true},"
    
    # Add environment field
    fields+="{\"title\": \"Environment\", \"value\": \"$(get_slack_environment_info)\", \"short\": true}"
    
    local color="good"
    if [[ "$failed_pods" -gt 0 ]]; then
        color="danger"
    elif [[ "$successful_pods" -lt "$total_pods" ]]; then
        color="warning"
    fi
    
    send_slack_notification "$message" "$color" "$title" "$fields"
}

# Send combined release success notification with summary
notify_release_success_with_summary() {
    local release_type="$1"
    local version="$2"
    local pods="$3"
    local duration="${4:-unknown}"
    local release_notes="${5:-}"
    local total_pods="$6"
    local successful_pods="$7"
    local failed_pods="$8"
    local release_branch="${9:-}"
    
    local message="🚀 *${release_type} Release Successful!*"
    local title="Release Details & Summary"
    local fields=""
    
    # Add version field
    fields+="{\"title\": \"Version\", \"value\": \"$version\", \"short\": true}"
    
    # Add release branch field if provided
    if [[ -n "$release_branch" ]]; then
        fields+=",{\"title\": \"Release Branch\", \"value\": \"$release_branch\", \"short\": true}"
    fi
    
    # Add duration field
    fields+=",{\"title\": \"Duration\", \"value\": \"$duration\", \"short\": true}"
    
    # Add released pods field
    if [[ -n "$pods" ]]; then
        fields+=",{\"title\": \"Released Pods\", \"value\": \"$pods\", \"short\": true}"
    fi
    
    # Add environment field
    fields+=",{\"title\": \"Environment\", \"value\": \"$(get_slack_environment_info)\", \"short\": true}"
    
    # Add release notes if provided
    if [[ -n "$release_notes" ]]; then
        local formatted_notes
        formatted_notes=$(format_release_notes_for_slack "$release_notes")
        fields+=",{\"title\": \"Release Notes\", \"value\": \"$formatted_notes\", \"short\": false}"
    fi
    
    # Add summary statistics
    fields+=",{\"title\": \"Total Pods\", \"value\": \"$total_pods\", \"short\": true}"
    fields+=",{\"title\": \"Successful\", \"value\": \"$successful_pods\", \"short\": true}"
    fields+=",{\"title\": \"Failed\", \"value\": \"$failed_pods\", \"short\": true}"
    
    local color="good"
    if [[ "$failed_pods" -gt 0 ]]; then
        color="danger"
    elif [[ "$successful_pods" -lt "$total_pods" ]]; then
        color="warning"
    fi
    
    send_slack_notification "$message" "$color" "$title" "$fields"
}

# Test Slack notification
test_slack_notification() {
    log_step "Testing Slack notification..."
    
    if [[ -z "$SLACK_WEBHOOK_URL" ]]; then
        log_error "SLACK_WEBHOOK_URL not set. Please set it to test notifications."
        return 1
    fi
    
    local message="🧪 *Test Notification*"
    local title="Slack Integration Test"
    local fields="{\"title\": \"Test\", \"value\": \"This is a test notification from MSP iOS SDK Release Bot\", \"short\": false},"
    fields+="{\"title\": \"Environment\", \"value\": \"$(get_slack_environment_info)\", \"short\": true},"
    fields+="{\"title\": \"Timestamp\", \"value\": \"$(date)\", \"short\": true}"
    
    send_slack_notification "$message" "good" "$title" "$fields"
}

# ============================================================================
# Export Functions
# ============================================================================
export -f load_slack_config
export -f get_slack_environment get_slack_environment_info
export -f format_release_notes_for_slack
export -f send_slack_notification
export -f notify_release_success notify_release_failure notify_release_warning
export -f notify_release_start notify_pod_release notify_release_summary
export -f notify_release_success_with_summary test_slack_notification

