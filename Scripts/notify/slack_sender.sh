#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Slack Notification Sender (Internal)
# ============================================================================
# Purpose: Internal Slack DM and Channel message sending
#          DO NOT call directly from orchestrator
#
# Usage:   Source this file and call internal functions
# ============================================================================

set -euo pipefail

# Source existing Slack notification utilities
source "${ROOT_DIR:-.}/Scripts/release/utils/notify.sh" 2>/dev/null || {
    echo "Warning: Could not source notify.sh" >&2
    return 0
}

# ============================================================================
# Internal Slack DM Sender
# ============================================================================

notify::slack::send_dm() {
    local message="$1"
    
    if [[ -z "$message" ]]; then
        return 0
    fi
    
    # Use existing notify::dm function (respects TEST MODE / PROD MODE routing)
    notify::dm "" "$message" 2>/dev/null || true
    
    return 0
}

# ============================================================================
# Internal Slack Channel Sender
# ============================================================================

notify::slack::send_channel() {
    local message="$1"
    
    if [[ -z "$message" ]]; then
        return 0
    fi
    
    # Use existing notify::channel function (respects TEST MODE / PROD MODE routing)
    notify::channel "$message" 2>/dev/null || true
    
    return 0
}

# ============================================================================
# Internal Slack Block Kit Sender
# ============================================================================

notify::slack::send_blockkit() {
    local json_payload="$1"
    
    if [[ -z "$json_payload" ]]; then
        return 0  # Soft-fail: empty payload
    fi
    
    # Validate JSON
    if ! echo "$json_payload" | python3 -c "import sys, json; json.load(sys.stdin)" 2>/dev/null; then
        return 0  # Soft-fail: invalid JSON
    fi
    
    # Extract blocks from payload
    local blocks_json
    blocks_json="$(echo "$json_payload" | python3 -c "import sys, json; print(json.dumps(json.load(sys.stdin).get('blocks', [])))" 2>/dev/null || echo "[]")"
    
    if [[ "$blocks_json" == "[]" ]] || [[ -z "$blocks_json" ]]; then
        return 0  # Soft-fail: no blocks
    fi
    
    # Determine if we're in TEST MODE
    local is_test_mode=false
    if [[ "${MSP_SLACK_ALERT_ENV:-}" == "test" ]]; then
        is_test_mode=true
    fi
    
    # For DM: Get user ID and open DM channel
    if [[ -n "${MSP_SLACK_DM_OVERRIDE:-}" ]]; then
        # TEMPORARY FIX: Disable DM notifications to unblock release
        # TODO: Update SLACK_BOT_TOKEN when new token is available
        echo "[SLACK][DM] DM notifications temporarily disabled" >&2
        # Fall through to webhook channel notification
        MSP_SLACK_DM_OVERRIDE=""
    fi

    # Original DM logic (now unreachable, kept for reference)
    if [[ -n "${MSP_SLACK_DM_OVERRIDE_DISABLED:-}" ]]; then
        local user_id="$MSP_SLACK_DM_OVERRIDE"
        
        # Skip if no bot token
        [[ -z "${SLACK_BOT_TOKEN:-}" ]] && return 0
        
        # Open DM channel
        local channel
        channel=$(curl -s -X POST \
          -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
          -H "Content-type: application/json; charset=utf-8" \
          --data "{\"users\": \"$user_id\"}" \
          https://slack.com/api/conversations.open 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin).get('channel',{}).get('id',''))" 2>/dev/null) || true
        
        if [[ -n "$channel" ]]; then
            # Send Block Kit message via chat.postMessage
            local dm_payload
            dm_payload="{\"channel\":\"$channel\",\"blocks\":$blocks_json}"
            echo "[SLACK][DM] Sending BlockKit to channel: $channel" >&2
            echo "[SLACK][DM] Payload: $dm_payload" >&2
            curl -s -w "\n[SLACK][DM] HTTP Status: %{http_code}\n" -X POST \
              -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
              -H "Content-type: application/json" \
              --data "$dm_payload" \
              https://slack.com/api/chat.postMessage >/dev/null 2>&1 || true
        fi
    fi
    
    # For Channel: Use webhook or channel API
    if [[ "$is_test_mode" == "true" ]]; then
        # TEST MODE: Use test webhook
        local test_webhook="${MSP_SLACK_TEST_WEBHOOK:-}"
        if [[ -n "$test_webhook" ]]; then
            # Webhooks DO support Block Kit blocks parameter
            # Send Block Kit JSON directly via webhook
            local channel_payload
            channel_payload="{\"blocks\":$blocks_json}"
            echo "[SLACK][CHANNEL] Sending BlockKit to webhook" >&2
            echo "[SLACK][CHANNEL] Payload: $channel_payload" >&2
            curl -s -w "\n[SLACK][CHANNEL] HTTP Status: %{http_code}\n" -X POST \
              -H "Content-type: application/json" \
              --data "$channel_payload" \
              "$test_webhook" >/dev/null 2>&1 || true
        fi
    else
        # PROD MODE: Prefer API if bot token available, otherwise use webhook
        if [[ -n "${SLACK_BOT_TOKEN:-}" ]]; then
            # Load channel from YAML config
            source "${ROOT_DIR:-.}/Scripts/release/utils/notify.sh" 2>/dev/null || true
            notify::load_mapping 2>/dev/null || true
            
            local channel_id
            channel_id=$(python3 - <<EOF
import json
alerts = json.loads('${SLACK_ALERTS:-{}}')
print(alerts.get('channel', ''))
EOF
2>/dev/null || echo "")
            
            if [[ -n "$channel_id" ]]; then
                # Send Block Kit message via chat.postMessage API
                curl -s -X POST \
                  -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
                  -H "Content-type: application/json" \
                  --data "{\"channel\":\"$channel_id\",\"blocks\":$blocks_json}" \
                  https://slack.com/api/chat.postMessage >/dev/null 2>&1 || true
            fi
        else
            # Fallback to webhook if no bot token
            source "${ROOT_DIR:-.}/Scripts/release/utils/notify.sh" 2>/dev/null || true
            notify::load_mapping 2>/dev/null || true
            
            local webhook_url
            webhook_url=$(python3 - <<EOF
import json
try:
    alerts = json.loads('${SLACK_ALERTS:-{}}')
    print(alerts.get('webhook', ''))
except Exception:
    print('')
EOF
2>/dev/null || echo "")
            
            if [[ -n "$webhook_url" ]]; then
                # Send Block Kit via webhook
                curl -s -X POST \
                  -H "Content-type: application/json" \
                  --data "{\"blocks\":$blocks_json}" \
                  "$webhook_url" >/dev/null 2>&1 || true
            fi
        fi
    fi
    
    return 0
}


# ============================================================================
# Internal Slack Block Sender (Webhook-based)
# ============================================================================

notify::slack::send_block() {
    local json_payload="$1"
    
    if [[ -z "$json_payload" ]]; then
        return 0  # Soft-fail: empty payload
    fi
    
    # Validate JSON
    if ! echo "$json_payload" | python3 -c "import sys, json; json.load(sys.stdin)" 2>/dev/null; then
        return 0  # Soft-fail: invalid JSON
    fi
    
    # Determine if we're in TEST MODE
    local is_test_mode=false
    if [[ "${MSP_SLACK_ALERT_ENV:-}" == "test" ]]; then
        is_test_mode=true
    fi
    
    # Extract blocks from payload
    local blocks_json
    blocks_json="$(echo "$json_payload" | python3 -c "import sys, json; print(json.dumps(json.load(sys.stdin).get('blocks', [])))" 2>/dev/null || echo "[]")"
    
    if [[ "$blocks_json" == "[]" ]] || [[ -z "$blocks_json" ]]; then
        return 0  # Soft-fail: no blocks
    fi
    
    # Use webhook to send Block Kit JSON
    if [[ "$is_test_mode" == "true" ]]; then
        # TEST MODE: Use test webhook
        local test_webhook="${MSP_SLACK_TEST_WEBHOOK:-}"
        if [[ -z "$test_webhook" ]]; then
            return 0  # Soft-fail: test webhook not set
        fi
        
        # Send Block Kit via webhook (webhooks support blocks parameter)
        curl -s -X POST \
          -H "Content-type: application/json" \
          --data "{\"blocks\":$blocks_json}" \
          "$test_webhook" >/dev/null 2>&1 || true
    else
        # PROD MODE: Use production webhook from YAML config
        source "${ROOT_DIR:-.}/Scripts/release/utils/notify.sh" 2>/dev/null || true
        notify::load_mapping 2>/dev/null || true
        
        local webhook_url
        webhook_url=$(python3 - <<EOF
import json
try:
    alerts = json.loads('${SLACK_ALERTS:-{}}')
    print(alerts.get('webhook', ''))
except Exception:
    print('')
EOF
2>/dev/null || echo "")
        
        if [[ -n "$webhook_url" ]]; then
            # Send Block Kit via webhook
            curl -s -X POST \
              -H "Content-type: application/json" \
              --data "{\"blocks\":$blocks_json}" \
              "$webhook_url" >/dev/null 2>&1 || true
        fi
    fi
    
    return 0
}
