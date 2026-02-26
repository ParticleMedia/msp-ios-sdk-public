#!/usr/bin/env bash
# ============================================================================
# Time Utilities Module
# ============================================================================
# Module: Scripts/lib/shared/time_utils.sh
# Purpose: Unified duration calculation and formatting functions
# Created: R011 DRY Refactoring
#
# Functions:
#   - time_calculate_duration(start, end) - Calculate duration in seconds
#   - time_format_duration(seconds) - Format duration as "Xm Ys"
#   - time_start_timer() - Start a named timer
#   - time_end_timer() - End timer and return duration
#   - time_parse_timestamp(timestamp) - Parse timestamp to epoch seconds
#
# Cross-Platform:
#   - Supports both macOS (date -j) and Linux (date -d) formats
#   - Handles epoch timestamps and formatted strings
#
# Dependencies:
#   - None (self-contained)
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_TIME_UTILS_SOURCED:-}" ]] && return 0
readonly _TIME_UTILS_SOURCED=1

# ============================================================================
# Timer Storage (Global State)
# ============================================================================
# Associative array to store named timers (bash 4+)
# Fallback to single TIMER_START variable for bash 3 compatibility
declare -A _TIME_UTILS_TIMERS 2>/dev/null || true
_TIME_UTILS_TIMER_START="${_TIME_UTILS_TIMER_START:-}"

# ============================================================================
# Parse Timestamp to Epoch Seconds
# ============================================================================
# Parses a timestamp string to Unix epoch seconds.
# Supports:
#   - Unix epoch (raw number)
#   - "YYYY-MM-DD HH:MM:SS" format
#   - ISO 8601 format
#
# Args:
#   $1: timestamp - Timestamp string or epoch seconds
#
# Returns:
#   Prints epoch seconds on success, empty string on failure
# ============================================================================
time_parse_timestamp() {
    local timestamp="$1"

    # If already epoch seconds (numeric), return as-is
    if [[ "$timestamp" =~ ^[0-9]+$ ]]; then
        echo "$timestamp"
        return 0
    fi

    # Try macOS date format first
    local epoch
    epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$timestamp" "+%s" 2>/dev/null || \
            date -d "$timestamp" "+%s" 2>/dev/null || echo "")

    if [[ -n "$epoch" ]]; then
        echo "$epoch"
        return 0
    fi

    # Return empty if parsing failed
    echo ""
    return 1
}

# ============================================================================
# Calculate Duration Between Timestamps
# ============================================================================
# Calculates duration in seconds between two timestamps.
#
# Args:
#   $1: start_time - Start timestamp (epoch or "YYYY-MM-DD HH:MM:SS")
#   $2: end_time - End timestamp (epoch or "YYYY-MM-DD HH:MM:SS")
#
# Returns:
#   Duration in seconds (integer)
#   Returns 0 if calculation fails
# ============================================================================
time_calculate_duration() {
    local start_time="$1"
    local end_time="$2"

    if [[ -z "$start_time" ]] || [[ -z "$end_time" ]]; then
        echo "0"
        return 0
    fi

    local start_epoch end_epoch
    start_epoch=$(time_parse_timestamp "$start_time")
    end_epoch=$(time_parse_timestamp "$end_time")

    if [[ -n "$start_epoch" ]] && [[ -n "$end_epoch" ]]; then
        local duration=$((end_epoch - start_epoch))
        # Ensure non-negative
        if [[ $duration -lt 0 ]]; then
            duration=0
        fi
        echo "$duration"
        return 0
    fi

    echo "0"
    return 0
}

# ============================================================================
# Format Duration (Human Readable)
# ============================================================================
# Formats a duration in seconds to human-readable format.
#
# Args:
#   $1: duration - Duration in seconds
#
# Returns:
#   Formatted string (e.g., "5m 30s", "30s", "1h 5m 30s")
# ============================================================================
time_format_duration() {
    local duration="${1:-0}"

    # Handle edge cases
    if [[ -z "$duration" ]] || [[ "$duration" == "0" ]]; then
        echo "0s"
        return 0
    fi

    # Calculate hours, minutes, seconds
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))

    if [[ $hours -gt 0 ]]; then
        echo "${hours}h ${minutes}m ${seconds}s"
    elif [[ $minutes -gt 0 ]]; then
        echo "${minutes}m ${seconds}s"
    else
        echo "${seconds}s"
    fi
}

# ============================================================================
# Start Timer
# ============================================================================
# Starts a named timer or the default timer.
#
# Args:
#   $1: timer_name (optional) - Name for the timer
#
# Returns:
#   0 on success
# ============================================================================
time_start_timer() {
    local timer_name="${1:-default}"
    local current_time
    current_time=$(date +%s)

    # Try associative array first (bash 4+)
    if declare -p _TIME_UTILS_TIMERS &>/dev/null 2>&1; then
        _TIME_UTILS_TIMERS["$timer_name"]="$current_time"
    else
        # Fallback for bash 3
        _TIME_UTILS_TIMER_START="$current_time"
    fi

    return 0
}

# ============================================================================
# End Timer
# ============================================================================
# Ends a named timer and returns the duration.
#
# Args:
#   $1: timer_name (optional) - Name of the timer
#
# Returns:
#   Prints duration in seconds
# ============================================================================
time_end_timer() {
    local timer_name="${1:-default}"
    local end_time
    end_time=$(date +%s)

    local start_time=""

    # Try associative array first (bash 4+)
    if declare -p _TIME_UTILS_TIMERS &>/dev/null 2>&1; then
        start_time="${_TIME_UTILS_TIMERS[$timer_name]:-}"
    else
        # Fallback for bash 3
        start_time="$_TIME_UTILS_TIMER_START"
    fi

    if [[ -n "$start_time" ]]; then
        local duration=$((end_time - start_time))
        echo "$duration"
    else
        echo "0"
    fi
}

# ============================================================================
# Get Current Timestamp
# ============================================================================
# Returns the current Unix timestamp.
#
# Returns:
#   Current epoch seconds
# ============================================================================
time_now() {
    date +%s
}

# ============================================================================
# Get Formatted Current Time
# ============================================================================
# Returns the current time in human-readable format.
#
# Args:
#   $1: format (optional) - strftime format string (default: "%Y-%m-%d %H:%M:%S")
#
# Returns:
#   Formatted timestamp string
# ============================================================================
time_now_formatted() {
    local format="${1:-%Y-%m-%d %H:%M:%S}"
    date +"$format"
}

# ============================================================================
# Backward Compatibility Aliases
# ============================================================================
# These provide compatibility with existing code that uses older function names.

# Alias for format_duration (used in common.sh, build scripts)
format_duration() {
    time_format_duration "$@"
}

# Alias for orch_calculate_duration (used in orchestrator/summary.sh)
orch_calculate_duration() {
    local start_time="$1"
    local end_time="$2"

    local duration_seconds
    duration_seconds=$(time_calculate_duration "$start_time" "$end_time")

    time_format_duration "$duration_seconds"
}

# ============================================================================
# Export Functions
# ============================================================================

export -f time_parse_timestamp 2>/dev/null || true
export -f time_calculate_duration 2>/dev/null || true
export -f time_format_duration 2>/dev/null || true
export -f time_start_timer 2>/dev/null || true
export -f time_end_timer 2>/dev/null || true
export -f time_now 2>/dev/null || true
export -f time_now_formatted 2>/dev/null || true

# Backward compatibility exports
export -f format_duration 2>/dev/null || true
export -f orch_calculate_duration 2>/dev/null || true
