#!/usr/bin/env bash
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
# Time Utilities Library
# ============================================================================
# Purpose: Common timestamp formatting functions for all scripts
#
# Usage:
#   source Scripts/lib/time-utils.sh
#   human_time=$(format_timestamp_human "2025-12-01T11:37:06Z")
#   slack_time=$(format_timestamp_slack "2025-12-01T11:37:06Z")
# ============================================================================

# ============================================================================
# Format Timestamp to Human-Readable Format
# ============================================================================
# Converts ISO8601 timestamp to YYYY-MM-DD HH:MM:SS format
#
# Usage: format_timestamp_human "2025-12-01T11:37:06Z"
# Output: "2025-12-01 11:37:06"
#
# Supports:
#   - macOS date command (date -jf)
#   - GNU date command (date -d)
#   - Falls back to original string if parsing fails
# ============================================================================

format_timestamp_human() {
    local iso8601="$1"
    
    if [[ -z "$iso8601" ]] || [[ "$iso8601" == "null" ]] || [[ "$iso8601" == "unknown" ]]; then
        echo "unknown"
        return 0
    fi
    
    # Try to parse and format (support both macOS date and GNU date)
    # Format: YYYY-MM-DD HH:MM:SS (human-readable, no timezone suffix)
    local formatted
    formatted="$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$iso8601" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || \
                 date -jf "%Y-%m-%dT%H:%M:%S" "${iso8601%Z}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || \
                 date -d "$iso8601" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || \
                 echo "$iso8601")"
    echo "$formatted"
}

# ============================================================================
# Format Timestamp for Slack
# ============================================================================
# Converts ISO8601 timestamp to Slack's date formatting syntax
#
# Usage: format_timestamp_slack "2025-12-01T11:37:06Z"
# Output: "<!date^1764734580^{date_num} {time}|2025-12-01T11:37:06Z>"
#
# Supports:
#   - macOS date command (date -jf)
#   - GNU date command (date -d)
#   - Falls back to original ISO string if parsing fails
# ============================================================================

format_timestamp_slack() {
    local iso8601="$1"
    
    if [[ -z "$iso8601" ]]; then
        echo ""
        return 0
    fi
    
    # Try to convert ISO8601 to unix timestamp
    local unix_ts
    unix_ts="$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$iso8601" "+%s" 2>/dev/null || \
               date -jf "%Y-%m-%dT%H:%M:%S" "${iso8601%Z}" "+%s" 2>/dev/null || \
               date -d "$iso8601" "+%s" 2>/dev/null || \
               echo "")"
    
    if [[ -n "$unix_ts" ]] && [[ "$unix_ts" =~ ^[0-9]+$ ]]; then
        # Use Slack's date formatting: <!date^unix_ts^{format}|fallback>
        echo "<!date^${unix_ts}^{date_num} {time}|${iso8601}>"
    else
        # Fallback to original ISO string if parsing fails
        echo "$iso8601"
    fi
}

# Export functions for use in other scripts
export -f format_timestamp_human format_timestamp_slack 2>/dev/null || true

