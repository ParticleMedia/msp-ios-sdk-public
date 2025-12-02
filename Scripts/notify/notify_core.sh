#!/bin/bash
# ============================================================================
# Notification Core - Unified Notification API
# ============================================================================
# Purpose: Single entry point for all release notifications
#
# Usage:   notify::send_release_summary "$NOTIFY_DATA_JSON"
# ============================================================================

set -euo pipefail

# Source rendering engine
source "${ROOT_DIR:-.}/Scripts/notify/render.sh" 2>/dev/null || {
    echo "Warning: Could not source render.sh" >&2
    return 0
}

# Source senders
source "${ROOT_DIR:-.}/Scripts/notify/slack_sender.sh" 2>/dev/null || {
    echo "Warning: Could not source slack_sender.sh" >&2
    return 0
}

source "${ROOT_DIR:-.}/Scripts/notify/email_sender.sh" 2>/dev/null || {
    echo "Warning: Could not source email_sender.sh" >&2
    return 0
}

# ============================================================================
# Unified Notification Entry Point
# ============================================================================

notify::send_release_summary() {
    local json="$1"
    
    if [[ -z "$json" ]]; then
        echo "Warning: Empty notification data" >&2
        return 0
    fi
    
    # Initialize templates (soft-fail)
    notify::render::init_templates 2>/dev/null || {
        echo "Warning: Failed to load templates, skipping notifications" >&2
        return 0
    }
    
    # Render messages
    local dm_msg channel_msg email_html email_subject
    
    dm_msg="$(notify::render::render_dm "$json" 2>/dev/null || echo "")"
    channel_msg="$(notify::render::render_channel "$json" 2>/dev/null || echo "")"
    email_html="$(notify::render::render_email_html "$json" 2>/dev/null || echo "")"
    email_subject="$(notify::render::render_email_subject "$json" 2>/dev/null || echo "")"
    
    # Send notifications (all soft-fail)
    [[ -n "$dm_msg" ]] && notify::slack::send_dm "$dm_msg" || true
    [[ -n "$channel_msg" ]] && notify::slack::send_channel "$channel_msg" || true
    [[ -n "$email_html" ]] && [[ -n "$email_subject" ]] && notify::email::send "$email_subject" "$email_html" || true
    
    return 0
}

