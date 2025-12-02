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
        return 0  # Soft-fail on empty input
    fi
    
    # Initialize templates (soft-fail)
    notify::render::init_templates 2>/dev/null || true
    
    # Render messages (all soft-fail)
    local dm_msg channel_msg email_html email_subject block_json
    
    # Check if Block Kit mode is enabled
    if [[ "${MSP_SLACK_BLOCK_MODE:-0}" == "1" ]]; then
        # Try Block Kit (structured blocks)
        block_json="$(notify::render::render_slack_block "$json" 2>/dev/null || echo "")"
        
        if [[ -n "$block_json" ]]; then
            # Use Block Kit via webhook
            notify::slack::send_block "$block_json" 2>/dev/null || {
                # Fallback to text templates if Block Kit fails
                dm_msg="$(notify::render::render_dm "$json" 2>/dev/null || echo "")"
                channel_msg="$(notify::render::render_channel "$json" 2>/dev/null || echo "")"
                
                [[ -n "$dm_msg" ]] && notify::slack::send_dm "$dm_msg" 2>/dev/null || true
                [[ -n "$channel_msg" ]] && notify::slack::send_channel "$channel_msg" 2>/dev/null || true
            }
        else
            # Fallback to text templates if Block Kit rendering fails
            dm_msg="$(notify::render::render_dm "$json" 2>/dev/null || echo "")"
            channel_msg="$(notify::render::render_channel "$json" 2>/dev/null || echo "")"
            
            [[ -n "$dm_msg" ]] && notify::slack::send_dm "$dm_msg" 2>/dev/null || true
            [[ -n "$channel_msg" ]] && notify::slack::send_channel "$channel_msg" 2>/dev/null || true
        fi
    else
        # Use original text templates
        dm_msg="$(notify::render::render_dm "$json" 2>/dev/null || echo "")"
        channel_msg="$(notify::render::render_channel "$json" 2>/dev/null || echo "")"
        
        [[ -n "$dm_msg" ]] && notify::slack::send_dm "$dm_msg" 2>/dev/null || true
        [[ -n "$channel_msg" ]] && notify::slack::send_channel "$channel_msg" 2>/dev/null || true
    fi
    
    # Email always uses text template
    email_html="$(notify::render::render_email_html "$json" 2>/dev/null || echo "")"
    email_subject="$(notify::render::render_email_subject "$json" 2>/dev/null || echo "")"
    [[ -n "$email_html" ]] && [[ -n "$email_subject" ]] && notify::email::send "$email_subject" "$email_html" 2>/dev/null || true
    
    return 0
}

