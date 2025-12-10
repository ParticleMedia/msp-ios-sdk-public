#!/bin/bash
# --- MSP Worktree Safety Guard (Patch K, shared) ---
# shellcheck source=/dev/null
if command -v git >/dev/null 2>&1; then
  MSP_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$MSP_REPO_ROOT" ] && [ -f "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh" ]; then
    # shellcheck source=/dev/null
    . "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh"
    msp_enforce_main_repo_or_exit
  fi
fi
# --- End MSP Worktree Safety Guard (Patch K, shared) ---
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
            # Use Block Kit sender (handles both DM and Channel)
            # This function sends DM via API and Channel via webhook/API
            notify::slack::send_blockkit "$block_json" 2>/dev/null || true
            # Note: No fallback to text when BlockKit mode is enabled
            # If BlockKit fails, we fail silently (soft-fail)
        else
            # Fallback to text templates only if Block Kit rendering fails
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
    
    # Email always uses text template (only if not disabled)
    if [[ "${MSP_EMAIL_DISABLED:-0}" != "1" ]]; then
        email_html="$(notify::render::render_email_html "$json" 2>/dev/null || echo "")"
        email_subject="$(notify::render::render_email_subject "$json" 2>/dev/null || echo "")"
        [[ -n "$email_html" ]] && [[ -n "$email_subject" ]] && notify::email::send "$email_subject" "$email_html" 2>/dev/null || true
    fi
    
    return 0
}

