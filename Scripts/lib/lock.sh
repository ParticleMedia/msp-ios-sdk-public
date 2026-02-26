#!/usr/bin/env bash
# ============================================================================
# MSP iOS SDK - Cross-Platform Lock Mechanism
# ============================================================================
# Module: lock.sh
# Purpose: Provide cross-platform file locking for concurrent operations
# Created for: T069
#
# Description:
#   Provides a unified locking API that works on both macOS and Linux.
#   Uses flock when available (Linux), falls back to mkdir-based locking
#   for macOS compatibility.
#
# Usage:
#   source Scripts/lib/lock.sh
#   lock_acquire "my-operation"
#   # ... do work ...
#   lock_release "my-operation"
#
#   # Or with auto-release:
#   lock_with "my-operation" "command to run"
#
# Environment Variables:
#   MSP_LOCK_DIR: Base directory for lock files (default: /tmp/msp-locks)
#   MSP_LOCK_TIMEOUT: Maximum wait time in seconds (default: 300)
#   MSP_LOCK_DEBUG: Enable debug output if "true"
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_MSP_LOCK_SOURCED:-}" ]] && return 0
readonly _MSP_LOCK_SOURCED=1

# ============================================================================
# Configuration
# ============================================================================

# Base directory for lock files
readonly MSP_LOCK_BASE_DIR="${MSP_LOCK_DIR:-/tmp/msp-locks}"

# Maximum wait time for lock acquisition (seconds)
readonly MSP_LOCK_DEFAULT_TIMEOUT="${MSP_LOCK_TIMEOUT:-300}"

# Debug mode
readonly MSP_LOCK_DEBUG_MODE="${MSP_LOCK_DEBUG:-false}"

# ============================================================================
# Internal State
# ============================================================================

# Track acquired locks for cleanup
declare -a _MSP_ACQUIRED_LOCKS=()

# ============================================================================
# Internal Helpers
# ============================================================================

_lock_log() {
    if [[ "$MSP_LOCK_DEBUG_MODE" == "true" ]]; then
        echo "[LOCK] $*" >&2
    fi
}

_lock_error() {
    echo "[LOCK ERROR] $*" >&2
}

# Get lock file path for a given name
# @param $1 name - Lock name
# @return Lock file path via stdout
_lock_get_path() {
    local name="$1"
    # Sanitize name (replace non-alphanumeric with -)
    local safe_name
    safe_name=$(echo "$name" | tr -c '[:alnum:]-_' '-')
    echo "$MSP_LOCK_BASE_DIR/$safe_name.lock"
}

# Get lock directory path (for mkdir-based locking)
# @param $1 name - Lock name
# @return Lock directory path via stdout
_lock_get_dir() {
    local name="$1"
    local safe_name
    safe_name=$(echo "$name" | tr -c '[:alnum:]-_' '-')
    echo "$MSP_LOCK_BASE_DIR/$safe_name.lockdir"
}

# Check if flock is available
# @return 0 if available, 1 otherwise
_lock_has_flock() {
    command -v flock >/dev/null 2>&1
}

# Write lock metadata
_lock_write_metadata() {
    local lock_file="$1"
    local lock_dir
    lock_dir=$(dirname "$lock_file")
    mkdir -p "$lock_dir"

    {
        echo "PID=$$"
        echo "TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "HOSTNAME=$(hostname)"
        echo "USER=${USER:-unknown}"
    } > "$lock_file.meta"
}

# ============================================================================
# Public API
# ============================================================================

# Initialize lock system
# @description Creates lock directory if needed
lock_init() {
    mkdir -p "$MSP_LOCK_BASE_DIR"
    _lock_log "Lock system initialized: $MSP_LOCK_BASE_DIR"
}

# Acquire a named lock
# @param $1 name - Lock name (alphanumeric, dashes, underscores)
# @param $2 timeout - Optional timeout in seconds (default: MSP_LOCK_DEFAULT_TIMEOUT)
# @return 0 on success, 1 on timeout
lock_acquire() {
    local name="$1"
    local timeout="${2:-$MSP_LOCK_DEFAULT_TIMEOUT}"

    lock_init

    _lock_log "Acquiring lock: $name (timeout: ${timeout}s)"

    if _lock_has_flock; then
        _lock_acquire_flock "$name" "$timeout"
    else
        _lock_acquire_mkdir "$name" "$timeout"
    fi
}

# Acquire lock using flock (Linux)
_lock_acquire_flock() {
    local name="$1"
    local timeout="$2"

    local lock_file
    lock_file=$(_lock_get_path "$name")

    # Create lock file
    mkdir -p "$(dirname "$lock_file")"
    touch "$lock_file"

    # Open file descriptor 200 for the lock file
    exec 200>"$lock_file"

    # Try to acquire lock with timeout
    if flock -w "$timeout" 200; then
        _lock_write_metadata "$lock_file"
        _MSP_ACQUIRED_LOCKS+=("flock:$lock_file")
        _lock_log "Lock acquired (flock): $name"
        return 0
    else
        _lock_error "Failed to acquire lock within ${timeout}s: $name"
        return 1
    fi
}

# Acquire lock using mkdir (macOS fallback)
_lock_acquire_mkdir() {
    local name="$1"
    local timeout="$2"

    local lock_dir
    lock_dir=$(_lock_get_dir "$name")

    local elapsed=0
    local wait_interval=1

    while ! mkdir "$lock_dir" 2>/dev/null; do
        if [[ $elapsed -ge $timeout ]]; then
            _lock_error "Failed to acquire lock within ${timeout}s: $name"
            return 1
        fi

        if [[ $elapsed -eq 0 ]]; then
            _lock_log "Lock held by another process, waiting..."
        fi

        sleep $wait_interval
        elapsed=$((elapsed + wait_interval))
    done

    # Write metadata
    local meta_file="$lock_dir/meta"
    {
        echo "PID=$$"
        echo "TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "HOSTNAME=$(hostname)"
        echo "USER=${USER:-unknown}"
    } > "$meta_file"

    _MSP_ACQUIRED_LOCKS+=("mkdir:$lock_dir")
    _lock_log "Lock acquired (mkdir): $name"
    return 0
}

# Release a named lock
# @param $1 name - Lock name
# @return 0 on success, 1 if lock not held
lock_release() {
    local name="$1"

    _lock_log "Releasing lock: $name"

    if _lock_has_flock; then
        _lock_release_flock "$name"
    else
        _lock_release_mkdir "$name"
    fi
}

# Release flock-based lock
_lock_release_flock() {
    local name="$1"
    local lock_file
    lock_file=$(_lock_get_path "$name")

    # Close file descriptor to release lock
    exec 200>&-

    # Remove metadata
    rm -f "$lock_file.meta"

    # Remove from tracked locks
    local new_locks=()
    for lock in "${_MSP_ACQUIRED_LOCKS[@]:-}"; do
        if [[ "$lock" != "flock:$lock_file" ]]; then
            new_locks+=("$lock")
        fi
    done
    _MSP_ACQUIRED_LOCKS=("${new_locks[@]:-}")

    _lock_log "Lock released (flock): $name"
    return 0
}

# Release mkdir-based lock
_lock_release_mkdir() {
    local name="$1"
    local lock_dir
    lock_dir=$(_lock_get_dir "$name")

    if [[ -d "$lock_dir" ]]; then
        rm -rf "$lock_dir"

        # Remove from tracked locks
        local new_locks=()
        for lock in "${_MSP_ACQUIRED_LOCKS[@]:-}"; do
            if [[ "$lock" != "mkdir:$lock_dir" ]]; then
                new_locks+=("$lock")
            fi
        done
        _MSP_ACQUIRED_LOCKS=("${new_locks[@]:-}")

        _lock_log "Lock released (mkdir): $name"
        return 0
    else
        _lock_error "Lock not held: $name"
        return 1
    fi
}

# Execute command with lock
# @param $1 name - Lock name
# @param $@ command - Command to execute
# @return Command's exit code
lock_with() {
    local name="$1"
    shift
    local command=("$@")

    if ! lock_acquire "$name"; then
        return 1
    fi

    local exit_code=0
    "${command[@]}" || exit_code=$?

    lock_release "$name"

    return $exit_code
}

# Check if lock is held
# @param $1 name - Lock name
# @return 0 if locked, 1 if unlocked
lock_is_held() {
    local name="$1"

    if _lock_has_flock; then
        local lock_file
        lock_file=$(_lock_get_path "$name")
        # Try non-blocking lock
        if flock -n "$lock_file" true 2>/dev/null; then
            return 1  # Not locked
        else
            return 0  # Locked
        fi
    else
        local lock_dir
        lock_dir=$(_lock_get_dir "$name")
        [[ -d "$lock_dir" ]]
    fi
}

# Get lock holder info
# @param $1 name - Lock name
# @return Lock metadata via stdout
lock_get_holder() {
    local name="$1"

    local meta_file=""
    if _lock_has_flock; then
        local lock_file
        lock_file=$(_lock_get_path "$name")
        meta_file="$lock_file.meta"
    else
        local lock_dir
        lock_dir=$(_lock_get_dir "$name")
        meta_file="$lock_dir/meta"
    fi

    if [[ -f "$meta_file" ]]; then
        cat "$meta_file"
    else
        echo "Lock holder information not available"
        return 1
    fi
}

# Clean up stale locks
# @description Removes locks older than specified age
# @param $1 max_age - Maximum age in seconds (default: 3600)
lock_cleanup_stale() {
    local max_age="${1:-3600}"

    _lock_log "Cleaning up stale locks older than ${max_age}s"

    local now
    now=$(date +%s)

    # Clean mkdir-based locks
    for dir in "$MSP_LOCK_BASE_DIR"/*.lockdir; do
        [[ -d "$dir" ]] || continue

        local meta_file="$dir/meta"
        if [[ -f "$meta_file" ]]; then
            local lock_time
            lock_time=$(stat -f %m "$meta_file" 2>/dev/null || stat -c %Y "$meta_file" 2>/dev/null || echo 0)
            local age=$((now - lock_time))

            if [[ $age -gt $max_age ]]; then
                _lock_log "Removing stale lock: $dir (age: ${age}s)"
                rm -rf "$dir"
            fi
        fi
    done

    # Clean flock metadata files
    for meta in "$MSP_LOCK_BASE_DIR"/*.lock.meta; do
        [[ -f "$meta" ]] || continue

        local lock_time
        lock_time=$(stat -f %m "$meta" 2>/dev/null || stat -c %Y "$meta" 2>/dev/null || echo 0)
        local age=$((now - lock_time))

        if [[ $age -gt $max_age ]]; then
            _lock_log "Removing stale lock metadata: $meta (age: ${age}s)"
            rm -f "$meta" "${meta%.meta}"
        fi
    done
}

# Release all locks held by this process
# @description Called automatically on exit
lock_release_all() {
    _lock_log "Releasing all held locks"

    for lock in "${_MSP_ACQUIRED_LOCKS[@]:-}"; do
        local type="${lock%%:*}"
        local path="${lock#*:}"

        case "$type" in
            flock)
                exec 200>&- 2>/dev/null || true
                rm -f "$path.meta"
                ;;
            mkdir)
                rm -rf "$path"
                ;;
        esac
    done

    _MSP_ACQUIRED_LOCKS=()
}

# ============================================================================
# Exit Trap
# ============================================================================

# Register cleanup trap
_lock_exit_trap() {
    lock_release_all
}

trap _lock_exit_trap EXIT

# ============================================================================
# Export Functions
# ============================================================================

export -f lock_init lock_acquire lock_release lock_with
export -f lock_is_held lock_get_holder lock_cleanup_stale lock_release_all
