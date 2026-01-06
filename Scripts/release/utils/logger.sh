#!/bin/bash
# MSP iOS SDK - Unified Logging System
# Provides structured logging with timestamps, modules, and metrics

# Source guard: prevent multiple sourcing
if [[ -n "${MSP_LOGGER_LOADED:-}" ]]; then
    return 0  # Already loaded, skip
fi
export MSP_LOGGER_LOADED=1

# ============================================================================
# Initialize Metrics Temporary File (Early)
# ============================================================================
# Initialize _METRICS_TMP_FILE early to avoid "unbound variable" errors
# This must be initialized before any script tries to use it
_METRICS_TMP_FILE="${MSP_METRICS_TMP_FILE:-/tmp/msp-metrics-$$.tmp}"
export _METRICS_TMP_FILE

# ============================================================================
# Configuration
# ============================================================================

# Log levels (numeric priority)
export LOG_LEVEL_DEBUG=0
export LOG_LEVEL_INFO=1
export LOG_LEVEL_WARN=2
export LOG_LEVEL_ERROR=3
export LOG_LEVEL_FATAL=4
declare -r LOG_LEVEL_DEBUG LOG_LEVEL_INFO LOG_LEVEL_WARN LOG_LEVEL_ERROR LOG_LEVEL_FATAL

# Current log level (can be overridden by MSP_LOG_LEVEL)
MSP_LOG_LEVEL="${MSP_LOG_LEVEL:-$LOG_LEVEL_INFO}"
export MSP_LOG_LEVEL

# Log output destinations
# Initialize all log-related variables early to avoid "unbound variable" errors
MSP_LOG_FILE="${MSP_LOG_FILE:-/tmp/msp-release-$(date +%Y%m%d-%H%M%S).log}"
export MSP_LOG_FILE="${MSP_LOG_FILE}"
MSP_LOG_JSON="${MSP_LOG_JSON:-false}"  # Enable JSON structured logging
export MSP_LOG_JSON="${MSP_LOG_JSON}"
MSP_LOG_CONSOLE="${MSP_LOG_CONSOLE:-true}"  # Console output
export MSP_LOG_CONSOLE="${MSP_LOG_CONSOLE}"
MSP_LOG_FILE_ENABLED="${MSP_LOG_FILE_ENABLED:-true}"  # File output
export MSP_LOG_FILE_ENABLED="${MSP_LOG_FILE_ENABLED}"

# Performance metrics file
MSP_METRICS_FILE="${MSP_METRICS_FILE:-/tmp/msp-release-metrics-$(date +%Y%m%d-%H%M%S).json}"
export MSP_METRICS_FILE

# ANSI colors
# Export colors to avoid "unbound variable" errors when scripts use 'set -u'
export COLOR_RESET='\033[0m'
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[1;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_PURPLE='\033[0;35m'
export COLOR_CYAN='\033[0;36m'
export COLOR_GRAY='\033[0;90m'
declare -r COLOR_RESET COLOR_RED COLOR_GREEN COLOR_YELLOW COLOR_BLUE COLOR_PURPLE COLOR_CYAN COLOR_GRAY

# ============================================================================
# Core Logging Functions
# ============================================================================

# Get current timestamp in ISO 8601 format
_log_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%S.%3NZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Get calling function/script info
_log_caller() {
    local frame="${1:-2}"  # Default to 2 levels up
    local caller_info
    caller_info=$(caller "$frame" 2>/dev/null || echo "0 unknown unknown")

    # Parse caller output: line_number function_name file_path
    local line="${caller_info%% *}"
    local rest="${caller_info#* }"
    local func="${rest%% *}"
    local file="${rest#* }"

    # Extract just the filename
    file="${file##*/}"

    echo "${file}:${line}:${func}"
}

# Core log function
_log() {
    local level="$1"
    local level_num="$2"
    local module="$3"
    local message="$4"
    local color="${5:-$COLOR_RESET}"

    # Filter by log level
    # Ensure MSP_LOG_LEVEL is defined (defensive check for set -u environments)
    local log_level="${MSP_LOG_LEVEL:-${LOG_LEVEL_INFO:-1}}"
    # Use arithmetic comparison to avoid variable expansion issues
    if (( level_num < log_level )); then
        return 0
    fi

    local timestamp
    timestamp=$(_log_timestamp)

    local caller
    caller=$(_log_caller 3)

    # JSON structured logging
    if [[ "$MSP_LOG_JSON" == "true" ]]; then
        local json_log

        # Escape message for JSON (escape quotes and newlines)
        local message_escaped
        message_escaped=$(echo "$message" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ')

        json_log=$(cat <<EOF
{"timestamp":"$timestamp","level":"$level","module":"$module","caller":"$caller","message":"$message_escaped"}
EOF
)
        if [[ "$MSP_LOG_CONSOLE" == "true" ]]; then
            echo "$json_log"
        fi
        if [[ "$MSP_LOG_FILE_ENABLED" == "true" ]]; then
            echo "$json_log" >> "$MSP_LOG_FILE"
        fi
        return 0
    fi

    # Human-readable format
    local log_line
    if [[ "${NO_ANSI:-false}" == "true" ]]; then
        log_line="[$timestamp] [$level] [$module] $message ($caller)"
    else
        log_line="${COLOR_GRAY}[$timestamp]${COLOR_RESET} ${color}[$level]${COLOR_RESET} ${COLOR_CYAN}[$module]${COLOR_RESET} $message ${COLOR_GRAY}($caller)${COLOR_RESET}"
    fi

    # Output to console
    if [[ "$MSP_LOG_CONSOLE" == "true" ]]; then
        if [[ "$level" == "ERROR" ]] || [[ "$level" == "FATAL" ]]; then
            echo -e "$log_line" >&2
        else
            echo -e "$log_line"
        fi
    fi

    # Output to file (strip ANSI codes)
    if [[ "$MSP_LOG_FILE_ENABLED" == "true" ]]; then
        echo -e "$log_line" | sed 's/\x1b\[[0-9;]*m//g' >> "$MSP_LOG_FILE"
    fi
}

# ============================================================================
# Public Logging API
# ============================================================================

log::debug() {
    local module="${1:-GENERAL}"
    local message="$2"
    _log "DEBUG" "$LOG_LEVEL_DEBUG" "$module" "$message" "$COLOR_GRAY"
}

log::info() {
    local module="${1:-GENERAL}"
    local message="$2"
    _log "INFO" "$LOG_LEVEL_INFO" "$module" "$message" "$COLOR_BLUE"
}

log::warn() {
    local module="${1:-GENERAL}"
    local message="$2"
    _log "WARN" "$LOG_LEVEL_WARN" "$module" "$message" "$COLOR_YELLOW"
}

log::error() {
    local module="${1:-GENERAL}"
    local message="$2"
    _log "ERROR" "$LOG_LEVEL_ERROR" "$module" "$message" "$COLOR_RED"
}

log::fatal() {
    local module="${1:-GENERAL}"
    local message="$2"
    _log "FATAL" "$LOG_LEVEL_FATAL" "$module" "$message" "$COLOR_RED"
    exit 1
}

log::success() {
    local module="${1:-GENERAL}"
    local message="$2"
    _log "SUCCESS" "$LOG_LEVEL_INFO" "$module" "✅ $message" "$COLOR_GREEN"
}

# ============================================================================
# Performance Metrics API
# ============================================================================

# Metrics storage file (temporary) - use session ID + PID for uniqueness
_METRICS_TMP_FILE="${MSP_METRICS_FILE%.json}-$$.tmp"

# Start timing a named operation
metrics::start() {
    local operation="$1"
    local timestamp
    
    # Try to get milliseconds precision, fallback to seconds
    if command -v gdate &>/dev/null; then
        # GNU date with milliseconds support
        timestamp=$(gdate +%s%3N)
    elif [[ "$(uname)" == "Darwin" ]]; then
        # macOS: use Python for high-precision timestamp
        if command -v python3 &>/dev/null; then
            timestamp=$(python3 -c 'import time; print(int(time.time() * 1000))')
        else
            # Fallback to seconds
            timestamp=$(date +%s)
            timestamp=$((timestamp * 1000))
        fi
    else
        # Linux with milliseconds support
        timestamp=$(date +%s%3N 2>/dev/null || date +%s)
        # If date +%s%3N failed, multiply by 1000
        if [[ ${#timestamp} -lt 13 ]]; then
            timestamp=$((timestamp * 1000))
        fi
    fi
    
    # Store start time in temp file (operation:timestamp format)
    echo "$operation:$timestamp" >> "$_METRICS_TMP_FILE"
    log::debug "METRICS" "Started timing: $operation"
}

# End timing and record duration
metrics::end() {
    local operation="$1"
    local end_time
    
    # Try to get milliseconds precision, fallback to seconds
    if command -v gdate &>/dev/null; then
        # GNU date with milliseconds support
        end_time=$(gdate +%s%3N)
    elif [[ "$(uname)" == "Darwin" ]]; then
        # macOS: use Python for high-precision timestamp
        if command -v python3 &>/dev/null; then
            end_time=$(python3 -c 'import time; print(int(time.time() * 1000))')
        else
            # Fallback to seconds
            end_time=$(date +%s)
            end_time=$((end_time * 1000))
        fi
    else
        # Linux with milliseconds support
        end_time=$(date +%s%3N 2>/dev/null || date +%s)
        # If date +%s%3N failed, multiply by 1000
        if [[ ${#end_time} -lt 13 ]]; then
            end_time=$((end_time * 1000))
        fi
    fi

    # Find start time from temp file (get last occurrence)
    local start_time=0
    if [[ -f "$_METRICS_TMP_FILE" ]]; then
        start_time=$(grep "^${operation}:" "$_METRICS_TMP_FILE" | tail -1 | cut -d: -f2)
    fi
    
    if [[ -z "$start_time" ]] || [[ "$start_time" -eq 0 ]]; then
        log::warn "METRICS" "No start time found for operation: $operation"
        return 1
    fi

    local duration=$((end_time - start_time))
    
    # Store duration in temp file (operation:duration format)
    echo "${operation}_duration:$duration" >> "$_METRICS_TMP_FILE"

    # Convert to human-readable format
    local duration_sec=$((duration / 1000))
    local duration_ms=$((duration % 1000))

    log::info "METRICS" "Completed: $operation (${duration_sec}s ${duration_ms}ms)"
}

# Record a metric value
metrics::record() {
    local metric_name="$1"
    local metric_value="$2"
    local metric_unit="${3:-count}"

    log::debug "METRICS" "Recorded: $metric_name = $metric_value $metric_unit"

    # Append to metrics file (JSON Lines format)
    if [[ -n "$MSP_METRICS_FILE" ]]; then
        local timestamp
        timestamp=$(_log_timestamp)
        echo "{\"timestamp\":\"$timestamp\",\"metric\":\"$metric_name\",\"value\":$metric_value,\"unit\":\"$metric_unit\"}" >> "$MSP_METRICS_FILE"
    fi
}

# Save all collected metrics to file
metrics::save() {
    if [[ -z "$MSP_METRICS_FILE" ]]; then
        log::warn "METRICS" "No metrics file configured"
        return 1
    fi

    log::info "METRICS" "Saving metrics to: $MSP_METRICS_FILE"

    # Create JSON report from temp file
    local json_report="{"
    json_report+="\"timestamp\":\"$(_log_timestamp)\","
    json_report+="\"durations\":{"

    local first=true
    if [[ -f "$_METRICS_TMP_FILE" ]]; then
        while IFS=':' read -r key duration; do
            # Extract operation name by removing "_duration" suffix
            local operation="${key%_duration}"

            if [[ "$first" == "false" ]]; then
                json_report+=","
            fi
            json_report+="\"$operation\":$duration"
            first=false
        done < <(grep "_duration:" "$_METRICS_TMP_FILE")
    fi

    json_report+="}}"

    echo "$json_report" >> "$MSP_METRICS_FILE"
    log::success "METRICS" "Metrics saved successfully"
    
    # Clean up temp file
    rm -f "$_METRICS_TMP_FILE"
}

# Generate human-readable metrics report
metrics::report() {
    echo ""
    echo "==================================================================="
    echo "                    PERFORMANCE METRICS REPORT"
    echo "==================================================================="
    echo ""

    if [[ ! -f "$_METRICS_TMP_FILE" ]]; then
        echo "No metrics collected."
        return 0
    fi

    # Extract durations from temp file (consistent with metrics::save)
    local sorted_ops
    sorted_ops=$(
        while IFS=':' read -r key duration; do
            echo "${key%_duration} $duration"
        done < <(grep "_duration:" "$_METRICS_TMP_FILE") | sort -rn -k2
    )

    if [[ -z "$sorted_ops" ]]; then
        echo "No metrics collected."
        return 0
    fi

    echo "Operation                                         Duration"
    echo "-------------------------------------------------------------------"

    local total_duration=0
    while IFS=' ' read -r operation duration; do
        local duration_sec=$((duration / 1000))
        local duration_ms=$((duration % 1000))
        printf "%-50s %5ds %03dms\n" "$operation" "$duration_sec" "$duration_ms"
        total_duration=$((total_duration + duration))
    done <<< "$sorted_ops"

    echo "-------------------------------------------------------------------"
    local total_sec=$((total_duration / 1000))
    local total_ms=$((total_duration % 1000))
    printf "%-50s %5ds %03dms\n" "TOTAL" "$total_sec" "$total_ms"
    echo ""
    echo "Metrics saved to: $MSP_METRICS_FILE"
    echo "==================================================================="
    echo ""
}

# ============================================================================
# Backward Compatibility Layer
# ============================================================================

# Map old logging functions to new API
log_info() {
    log::info "LEGACY" "$1"
}

log_error() {
    log::error "LEGACY" "$1"
}

log_warning() {
    log::warn "LEGACY" "$1"
}

# Backward compatibility alias: log_warn -> log_warning
# Many scripts use log_warn() (without "ing"), so provide this alias
log_warn() {
    log_warning "$@"
}

log_success() {
    log::success "LEGACY" "$1"
}

log_step() {
    log::info "STEP" "$1"
}

# ============================================================================
# Initialization
# ============================================================================

_log_init() {
    # Create log directory if needed
    local log_dir
    log_dir=$(dirname "$MSP_LOG_FILE")
    mkdir -p "$log_dir" 2>/dev/null || true

    # Create metrics directory if needed
    local metrics_dir
    metrics_dir=$(dirname "$MSP_METRICS_FILE")
    mkdir -p "$metrics_dir" 2>/dev/null || true
    
    # Initialize metrics temp file with session ID + PID
    _METRICS_TMP_FILE="${MSP_METRICS_FILE%.json}-$$.tmp"
    rm -f "$_METRICS_TMP_FILE" 2>/dev/null || true
    touch "$_METRICS_TMP_FILE" 2>/dev/null || true

    log::info "LOGGER" "Logging initialized"
    log::debug "LOGGER" "Log file: $MSP_LOG_FILE"
    log::debug "LOGGER" "Metrics file: $MSP_METRICS_FILE"
    log::debug "LOGGER" "Log level: $MSP_LOG_LEVEL"
}

# Auto-initialize when sourced
_log_init

