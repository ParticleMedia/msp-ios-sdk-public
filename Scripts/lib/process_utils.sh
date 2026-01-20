#!/usr/bin/env bash
# ============================================================================
# MSP Release System - Process Utilities
# ============================================================================
# Purpose: Provide timeout and process management utilities
# ============================================================================

# Prevent multiple sourcing
[[ -n "${_MSP_PROCESS_UTILS_SOURCED:-}" ]] && return 0
readonly _MSP_PROCESS_UTILS_SOURCED=1

# ============================================================================
# Detect timeout command (cross-platform)
# ============================================================================

detect_timeout_command() {
    if command -v gtimeout >/dev/null 2>&1; then
        echo "gtimeout"  # GNU coreutils on macOS
    elif command -v timeout >/dev/null 2>&1; then
        echo "timeout"   # Linux
    else
        return 1
    fi
}

# Global timeout command
TIMEOUT_CMD=$(detect_timeout_command)

# ============================================================================
# Function: wait_with_timeout
# ============================================================================
# Wait for a process with timeout
#
# Usage: wait_with_timeout <pid> <timeout_seconds> [description]
#
# Args:
#   pid: Process ID to wait for
#   timeout_seconds: Maximum wait time in seconds
#   description: Optional description for logging
#
# Returns:
#   0: Process completed successfully
#   124: Timeout
#   Other: Process exit code
#
# Example:
#   wait_with_timeout $PID 3600 "MSPCore release" || handle_error
# ============================================================================

wait_with_timeout() {
    local pid=$1
    local timeout=$2
    local description=${3:-"process $pid"}
    local elapsed=0
    local check_interval=5

    # Validate inputs
    if [[ -z "$pid" ]] || [[ -z "$timeout" ]]; then
        log_error "wait_with_timeout: Missing required arguments"
        log_error "Usage: wait_with_timeout <pid> <timeout> [description]"
        return 1
    fi

    # Check if process exists
    if ! kill -0 "$pid" 2>/dev/null; then
        log_warn "wait_with_timeout: Process $pid not found"
        return 1
    fi

    log_info "Waiting for $description (timeout: ${timeout}s, check interval: ${check_interval}s)"

    # Wait loop with timeout
    while kill -0 "$pid" 2>/dev/null; do
        sleep $check_interval
        elapsed=$((elapsed + check_interval))

        # Progress reporting every minute
        if [[ $((elapsed % 60)) -eq 0 ]]; then
            local remaining=$((timeout - elapsed))
            local percent=$((elapsed * 100 / timeout))
            log_debug "⏱️  $description: ${elapsed}s elapsed (${percent}%), ${remaining}s remaining"
        fi

        # Timeout check
        if [[ $elapsed -ge $timeout ]]; then
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log_error "⏱️  TIMEOUT: $description exceeded ${timeout}s limit"
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

            # Try graceful termination first
            log_warn "Sending SIGTERM to process $pid..."
            kill -TERM "$pid" 2>/dev/null || true
            sleep 2

            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                log_warn "Sending SIGKILL to process $pid..."
                kill -KILL "$pid" 2>/dev/null || true
            fi

            return 124  # Timeout exit code (same as GNU timeout)
        fi
    done

    # Process completed, get exit code
    wait "$pid" 2>/dev/null
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_success "✅ $description completed successfully in ${elapsed}s"
    else
        log_error "❌ $description failed with exit code $exit_code after ${elapsed}s"
    fi

    return $exit_code
}

# ============================================================================
# Function: run_with_timeout
# ============================================================================
# Run a command with timeout
#
# Usage: run_with_timeout <timeout_seconds> <command> [args...]
#
# Args:
#   timeout_seconds: Maximum execution time in seconds
#   command: Command to execute
#   args: Command arguments
#
# Returns:
#   0: Command completed successfully
#   124: Timeout
#   Other: Command exit code
#
# Example:
#   run_with_timeout 600 bundle exec pod repo update || handle_timeout
# ============================================================================

run_with_timeout() {
    local timeout=$1
    shift  # Remove timeout from args

    # Validate timeout command
    if [[ -z "$TIMEOUT_CMD" ]]; then
        log_error "timeout command not found"
        log_error "Install GNU coreutils: brew install coreutils (macOS) or apt-get install coreutils (Linux)"
        log_error "Falling back to running without timeout (DANGEROUS!)"
        "$@"
        return $?
    fi

    # Run with timeout
    if $TIMEOUT_CMD $timeout "$@"; then
        return 0
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log_error "⏱️  TIMEOUT: Command exceeded ${timeout}s limit"
            log_error "Command: $*"
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        fi
        return $exit_code
    fi
}

# ============================================================================
# Global Cleanup Mechanism
# ============================================================================

# Global arrays for tracking resources
declare -a GLOBAL_CHILD_PIDS=()
declare -a GLOBAL_TEMP_FILES=()
declare -a GLOBAL_TEMP_DIRS=()

# ============================================================================
# Function: register_child_pid
# ============================================================================
# Register a child process for cleanup
#
# Usage: register_child_pid <pid> [description]
#
# Example:
#   ( do_work ) &
#   register_child_pid $! "background worker"
# ============================================================================

register_child_pid() {
    local pid=$1
    local description=${2:-"process $pid"}
    GLOBAL_CHILD_PIDS+=("$pid:$description")
    log_debug "[CLEANUP] Registered child PID: $pid ($description)" 2>/dev/null || true
}

# ============================================================================
# Function: register_temp_resource
# ============================================================================
# Register a temporary file or directory for cleanup
#
# Usage: register_temp_resource <path>
#
# Example:
#   temp_file=$(mktemp)
#   register_temp_resource "$temp_file"
# ============================================================================

register_temp_resource() {
    local path=$1
    if [[ -d "$path" ]]; then
        GLOBAL_TEMP_DIRS+=("$path")
        log_debug "[CLEANUP] Registered temp directory: $path" 2>/dev/null || true
    elif [[ -f "$path" ]] || [[ ! -e "$path" ]]; then
        # File exists or will be created
        GLOBAL_TEMP_FILES+=("$path")
        log_debug "[CLEANUP] Registered temp file: $path" 2>/dev/null || true
    fi
}

# ============================================================================
# Function: global_cleanup
# ============================================================================
# Global cleanup function (called by trap)
#
# Usage: Automatically called by trap, or manually: global_cleanup
# ============================================================================

global_cleanup() {
    local signal=${1:-EXIT}

    # Only run once
    if [[ "${_CLEANUP_DONE:-}" == "1" ]]; then
        return
    fi
    export _CLEANUP_DONE=1

    log_warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" 2>/dev/null || echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_warn "🧹 Global cleanup triggered by signal: $signal" 2>/dev/null || echo "🧹 Global cleanup triggered by signal: $signal"
    log_warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" 2>/dev/null || echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Step 1: Kill all child processes
    if [[ ${#GLOBAL_CHILD_PIDS[@]} -gt 0 ]]; then
        log_info "Terminating ${#GLOBAL_CHILD_PIDS[@]} child process(es)..." 2>/dev/null || echo "Terminating ${#GLOBAL_CHILD_PIDS[@]} child process(es)..."
        for entry in "${GLOBAL_CHILD_PIDS[@]}"; do
            local pid="${entry%%:*}"
            local description="${entry#*:}"

            if kill -0 "$pid" 2>/dev/null; then
                log_debug "Killing $description (PID: $pid) with SIGTERM..." 2>/dev/null || true
                kill -TERM "$pid" 2>/dev/null || true
            fi
        done

        # Wait for graceful shutdown
        sleep 2

        # Force kill if still running
        for entry in "${GLOBAL_CHILD_PIDS[@]}"; do
            local pid="${entry%%:*}"
            local description="${entry#*:}"

            if kill -0 "$pid" 2>/dev/null; then
                log_debug "Force killing $description (PID: $pid) with SIGKILL..." 2>/dev/null || true
                kill -KILL "$pid" 2>/dev/null || true
            fi
        done

        log_success "All child processes terminated" 2>/dev/null || echo "All child processes terminated"
    fi

    # Step 2: Clean up temporary files
    if [[ ${#GLOBAL_TEMP_FILES[@]} -gt 0 ]]; then
        log_info "Cleaning up ${#GLOBAL_TEMP_FILES[@]} temporary file(s)..." 2>/dev/null || echo "Cleaning up ${#GLOBAL_TEMP_FILES[@]} temporary file(s)..."
        for file in "${GLOBAL_TEMP_FILES[@]}"; do
            rm -f "$file" 2>/dev/null || true
        done
        log_success "Temporary files cleaned" 2>/dev/null || echo "Temporary files cleaned"
    fi

    # Step 3: Clean up temporary directories
    if [[ ${#GLOBAL_TEMP_DIRS[@]} -gt 0 ]]; then
        log_info "Cleaning up ${#GLOBAL_TEMP_DIRS[@]} temporary directory(ies)..." 2>/dev/null || echo "Cleaning up ${#GLOBAL_TEMP_DIRS[@]} temporary directory(ies)..."
        for dir in "${GLOBAL_TEMP_DIRS[@]}"; do
            rm -rf "$dir" 2>/dev/null || true
        done
        log_success "Temporary directories cleaned" 2>/dev/null || echo "Temporary directories cleaned"
    fi

    log_success "✅ Global cleanup completed" 2>/dev/null || echo "✅ Global cleanup completed"
}

# ============================================================================
# Set up global traps
# ============================================================================

# Only set traps if not already set
if [[ -z "${_GLOBAL_TRAPS_SET:-}" ]]; then
    trap 'global_cleanup EXIT' EXIT
    trap 'global_cleanup INT' INT
    trap 'global_cleanup TERM' TERM
    export _GLOBAL_TRAPS_SET=1
    log_debug "[CLEANUP] Global traps installed" 2>/dev/null || true
fi

# ============================================================================
# Export functions
# ============================================================================

export -f wait_with_timeout \
         run_with_timeout \
         detect_timeout_command \
         register_child_pid \
         register_temp_resource \
         global_cleanup 2>/dev/null || true

log_debug "[PROCESS_UTILS] Process utilities loaded" 2>/dev/null || true

