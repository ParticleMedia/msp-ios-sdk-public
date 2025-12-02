#!/bin/bash
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

