#!/usr/bin/env bash
# MSP iOS SDK - Unified Logging System
# Provides structured logging with timestamps, modules, and metrics

# Source guard: prevent multiple sourcing
if [[ -n "${MSP_LOGGER_LOADED:-}" ]]; then
    return 0  # Already loaded, skip
fi
# Note: Do NOT export this variable. Each subprocess should initialize its own logger.
# Exported env vars are inherited but bash functions are not, causing "command not found" errors.
MSP_LOGGER_LOADED=1

# ============================================================================
# Initialize Metrics Temporary File (Early)
# ============================================================================
# Initialize _METRICS_TMP_FILE early to avoid "unbound variable" errors
# This must be initialized before any script tries to use it
_METRICS_TMP_FILE="${MSP_METRICS_TMP_FILE:-/tmp/msp-metrics-$$.tmp}"
export _METRICS_TMP_FILE

# ============================================================================
# Phase/Step Constants (FR-062)
# ============================================================================

# 4-Phase Release Flow
export PHASE_PREFLIGHT=1
export PHASE_BUILD=2
export PHASE_PUBLISH=3
export PHASE_VERIFY=4
export PHASE_TOTAL=4

# @description Get human-readable phase name by number.
# @param $1 phase - Phase number (1-4)
# @return Phase name string via stdout ("Preflight", "Build", "Publish", "Verify")
_get_phase_name() {
    local phase="$1"
    case "$phase" in
        1) echo "Preflight" ;;
        2) echo "Build" ;;
        3) echo "Publish" ;;
        4) echo "Verify" ;;
        *) echo "Unknown" ;;
    esac
}

# @description Get Chinese phase name by number.
# @param $1 phase - Phase number (1-4)
# @return Chinese phase name string via stdout
_get_phase_name_cn() {
    local phase="$1"
    case "$phase" in
        1) echo "预检" ;;
        2) echo "构建" ;;
        3) echo "发布" ;;
        4) echo "验证" ;;
        *) echo "未知" ;;
    esac
}

# @description Get total step count for a phase (per FR-062 spec).
# @param $1 phase - Phase number (1-4)
# @return Step count as integer via stdout
_get_phase_step_count() {
    local phase="$1"
    case "$phase" in
        1) echo "5" ;;   # Preflight: 5 steps
        2) echo "5" ;;   # Build: 5 steps
        3) echo "14" ;;  # Publish: 14 steps
        4) echo "6" ;;   # Verify: 6 steps
        *) echo "0" ;;
    esac
}

# Current phase/step tracking
_CURRENT_PHASE=0
_CURRENT_STEP=0
_PHASE_START_TIME=0

# Phase status tracking (using simple variables instead of associative array)
_PHASE_1_STATUS="not_run"
_PHASE_2_STATUS="not_run"
_PHASE_3_STATUS="not_run"
_PHASE_4_STATUS="not_run"
_PHASE_1_DURATION=0
_PHASE_2_DURATION=0
_PHASE_3_DURATION=0
_PHASE_4_DURATION=0

# @description Get the current status of a phase.
# @param $1 phase - Phase number (1-4)
# @return Status string via stdout ("not_run", "success", "failed", "skipped")
_get_phase_status() {
    local phase="$1"
    case "$phase" in
        1) echo "$_PHASE_1_STATUS" ;;
        2) echo "$_PHASE_2_STATUS" ;;
        3) echo "$_PHASE_3_STATUS" ;;
        4) echo "$_PHASE_4_STATUS" ;;
        *) echo "not_run" ;;
    esac
}

# @description Set the status of a phase.
# @param $1 phase - Phase number (1-4)
# @param $2 status - Status string ("not_run", "success", "failed", "skipped")
_set_phase_status() {
    local phase="$1"
    local status="$2"
    case "$phase" in
        1) _PHASE_1_STATUS="$status" ;;
        2) _PHASE_2_STATUS="$status" ;;
        3) _PHASE_3_STATUS="$status" ;;
        4) _PHASE_4_STATUS="$status" ;;
    esac
}

# @description Get the duration of a phase in milliseconds.
# @param $1 phase - Phase number (1-4)
# @return Duration in milliseconds via stdout
_get_phase_duration() {
    local phase="$1"
    case "$phase" in
        1) echo "$_PHASE_1_DURATION" ;;
        2) echo "$_PHASE_2_DURATION" ;;
        3) echo "$_PHASE_3_DURATION" ;;
        4) echo "$_PHASE_4_DURATION" ;;
        *) echo "0" ;;
    esac
}

# @description Set the duration of a phase in milliseconds.
# @param $1 phase - Phase number (1-4)
# @param $2 duration - Duration in milliseconds
_set_phase_duration() {
    local phase="$1"
    local duration="$2"
    case "$phase" in
        1) _PHASE_1_DURATION="$duration" ;;
        2) _PHASE_2_DURATION="$duration" ;;
        3) _PHASE_3_DURATION="$duration" ;;
        4) _PHASE_4_DURATION="$duration" ;;
    esac
}

# ============================================================================
# Configuration
# ============================================================================

# Log levels (numeric priority)
# Only define if not already set (avoid readonly variable conflict)
if [[ -z "${LOG_LEVEL_DEBUG:-}" ]]; then
    export LOG_LEVEL_DEBUG=0
    export LOG_LEVEL_INFO=1
    export LOG_LEVEL_WARN=2
    export LOG_LEVEL_ERROR=3
    export LOG_LEVEL_FATAL=4
    declare -r LOG_LEVEL_DEBUG LOG_LEVEL_INFO LOG_LEVEL_WARN LOG_LEVEL_ERROR LOG_LEVEL_FATAL
fi

# Current log level (can be overridden by MSP_LOG_LEVEL)
MSP_LOG_LEVEL="${MSP_LOG_LEVEL:-$LOG_LEVEL_INFO}"

# Normalize string log levels to numeric (config_loader uses strings like "info")
case "$MSP_LOG_LEVEL" in
    debug)  MSP_LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
    info)   MSP_LOG_LEVEL=$LOG_LEVEL_INFO ;;
    warn)   MSP_LOG_LEVEL=$LOG_LEVEL_WARN ;;
    error)  MSP_LOG_LEVEL=$LOG_LEVEL_ERROR ;;
    fatal)  MSP_LOG_LEVEL=$LOG_LEVEL_FATAL ;;
esac

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

# ANSI colors - use safe default pattern to avoid readonly conflict
# (colors.sh may have already defined these as readonly)
# NOTE: Use $'...' (ANSI-C quoting) so escape sequences become actual
# ESC characters.  The old '\033[…]' form embedded literal single-quotes
# that leaked into output.
COLOR_RESET=${COLOR_RESET:-$'\033[0m'}
COLOR_RED=${COLOR_RED:-$'\033[0;31m'}
COLOR_GREEN=${COLOR_GREEN:-$'\033[0;32m'}
COLOR_YELLOW=${COLOR_YELLOW:-$'\033[1;33m'}
COLOR_BLUE=${COLOR_BLUE:-$'\033[0;34m'}
COLOR_PURPLE=${COLOR_PURPLE:-$'\033[0;35m'}
COLOR_CYAN=${COLOR_CYAN:-$'\033[0;36m'}
COLOR_GRAY=${COLOR_GRAY:-$'\033[0;90m'}

# ============================================================================
# Core Logging Functions
# ============================================================================

# @description Get current timestamp in local time (human-readable).
# @return Timestamp string via stdout (YYYY-MM-DD HH:MM:SS)
_log_timestamp() {
    date +"%Y-%m-%d %H:%M:%S" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S"
}

# @description Get calling function/script info for log context.
# @param $1 frame - Stack frame to inspect (default: 2)
# @return Caller info string "file:line:function" via stdout
_log_caller() {
    local frame="${1:-2}"  # Default to 2 levels up
    local caller_info=""

    # Try the requested frame first.  In subshells the call stack may be
    # shallower, so fall back to lower frames, skipping internal logger
    # functions so the reported location is meaningful.
    local f
    for ((f=frame; f>=0; f--)); do
        if caller_info=$(caller "$f" 2>/dev/null) && [[ -n "$caller_info" ]]; then
            # Extract function name and skip logger internals
            local _fn="${caller_info#* }"
            _fn="${_fn%% *}"
            case "$_fn" in
                _log|_log_caller|_log_timestamp|log::*) continue ;;
                *) break ;;
            esac
        fi
        caller_info=""
    done

    if [[ -z "$caller_info" ]]; then
        echo "unknown:0:unknown"
        return
    fi

    # Parse caller output: line_number function_name file_path
    local line="${caller_info%% *}"
    local rest="${caller_info#* }"
    local func="${rest%% *}"
    local file="${rest#* }"

    # Extract just the filename
    file="${file##*/}"

    echo "${file}:${line}:${func}"
}

# @description Core logging function. Routes output to console and/or file.
#              Supports JSON structured logging when MSP_LOG_JSON=true.
# @param $1 level - Log level name (DEBUG, INFO, WARN, ERROR, FATAL)
# @param $2 level_num - Numeric log level for filtering
# @param $3 module - Module identifier for categorization
# @param $4 message - Log message content
# @param $5 color - ANSI color code (optional, default: reset)
_log() {
    local level="$1"
    local level_num="$2"
    local module="$3"
    local message="$4"
    local color="${5:-$COLOR_RESET}"

    # Filter by log level
    # Ensure all variables are numeric (defensive check for set -u environments)
    local log_level="${MSP_LOG_LEVEL:-${LOG_LEVEL_INFO:-1}}"
    local level_num_safe="${level_num:-1}"

    # Force numeric conversion - use pattern matching to check if numeric
    # This avoids unbound variable errors when non-numeric strings are passed
    if [[ "$log_level" =~ ^[0-9]+$ ]]; then
        log_level=$((log_level + 0))
    else
        log_level=1
    fi
    if [[ "$level_num_safe" =~ ^[0-9]+$ ]]; then
        level_num_safe=$((level_num_safe + 0))
    else
        level_num_safe=1
    fi

    # Use arithmetic comparison
    if (( level_num_safe < log_level )); then
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

# ---------------------------------------------------------------------------
# Helper: assemble message from 2-arg or 3-arg call forms.
#   2-arg: log::xxx MODULE MESSAGE
#   3-arg: log::xxx MODULE SUB_MODULE MESSAGE  →  "[SUB_MODULE] MESSAGE"
# ---------------------------------------------------------------------------
_log_msg() {
    if [[ $# -ge 3 ]]; then
        echo "[$2] $3"
    else
        echo "${2:-}"
    fi
}

# @description Log a debug message. Only shown when MSP_LOG_LEVEL=0.
# @param $1 module - Module identifier (default: GENERAL)
# @param $2 message | sub-module (when $3 is provided)
# @param $3 message (optional, when sub-module is given in $2)
log::debug() {
    local module="${1:-GENERAL}"
    local message
    message=$(_log_msg "$@")
    _log "DEBUG" "$LOG_LEVEL_DEBUG" "$module" "$message" "$COLOR_GRAY"
}

# @description Log an info message.
# @param $1 module - Module identifier (default: GENERAL)
# @param $2 message | sub-module (when $3 is provided)
# @param $3 message (optional)
log::info() {
    local module="${1:-GENERAL}"
    local message
    message=$(_log_msg "$@")
    _log "INFO" "$LOG_LEVEL_INFO" "$module" "$message" "$COLOR_BLUE"
}

# @description Log a warning message.
# @param $1 module - Module identifier (default: GENERAL)
# @param $2 message | sub-module (when $3 is provided)
# @param $3 message (optional)
log::warn() {
    local module="${1:-GENERAL}"
    local message
    message=$(_log_msg "$@")
    _log "WARN" "$LOG_LEVEL_WARN" "$module" "$message" "$COLOR_YELLOW"
}

# @description Log an error message.
# @param $1 module - Module identifier (default: GENERAL)
# @param $2 message | sub-module (when $3 is provided)
# @param $3 message (optional)
log::error() {
    local module="${1:-GENERAL}"
    local message
    message=$(_log_msg "$@")
    _log "ERROR" "$LOG_LEVEL_ERROR" "$module" "$message" "$COLOR_RED"
}

# @description Log a fatal error and exit the script.
# @param $1 module - Module identifier (default: GENERAL)
# @param $2 message | sub-module (when $3 is provided)
# @param $3 message (optional)
# @return Does not return (calls exit 1)
log::fatal() {
    local module="${1:-GENERAL}"
    local message
    message=$(_log_msg "$@")
    _log "FATAL" "$LOG_LEVEL_FATAL" "$module" "$message" "$COLOR_RED"
    exit 1
}

# @description Log a success message with checkmark icon.
# @param $1 module - Module identifier (default: GENERAL)
# @param $2 message | sub-module (when $3 is provided)
# @param $3 message (optional)
log::success() {
    local module="${1:-GENERAL}"
    local message
    message=$(_log_msg "$@")
    _log "SUCCESS" "$LOG_LEVEL_INFO" "$module" "✅ $message" "$COLOR_GREEN"
}

# @description Log a step (alias for log_step with namespace syntax).
#              Provides consistency with log::info, log::error, etc.
# @param $1 module - Module identifier
# @param $2 message - Step message content
log::step() {
    local module="${1:-GENERAL}"
    local message="$2"
    log::info "$module" "$message"
}

# @description Display a section header for visual separation.
#              Used for grouping related log entries.
# @param $1 title - Section title text
log_section() {
    local title="$1"
    local width="${TERMINAL_WIDTH:-80}"
    local separator
    separator=$(printf '%*s' "$width" '' | tr ' ' '─')

    echo ""
    echo "$separator"
    if [[ "${NO_ANSI:-false}" == "true" ]]; then
        echo "━━━ $title"
    else
        echo -e "${COLOR_CYAN:-}━━━ $title${COLOR_RESET:-}"
    fi
    echo "$separator"
    echo ""
}

# ============================================================================
# Phase/Step Logging API (FR-063~065)
# ============================================================================

# @description Start a new release phase with separator banner and timing.
#              Updates _CURRENT_PHASE and resets _CURRENT_STEP to 0.
#              Starts metrics tracking for the phase.
# @param $1 phase - Phase number (1-4: Preflight, Build, Publish, Verify)
log_phase_start() {
    local phase="$1"
    local phase_name
    phase_name=$(_get_phase_name "$phase")
    local phase_name_cn
    phase_name_cn=$(_get_phase_name_cn "$phase")
    local total_steps
    total_steps=$(_get_phase_step_count "$phase")

    # Update current phase tracking
    _CURRENT_PHASE="$phase"
    _CURRENT_STEP=0

    # Start timing
    if command -v gdate &>/dev/null; then
        _PHASE_START_TIME=$(gdate +%s%3N)
    elif [[ "$(uname)" == "Darwin" ]] && command -v python3 &>/dev/null; then
        _PHASE_START_TIME=$(python3 -c 'import time; print(int(time.time() * 1000))')
    else
        _PHASE_START_TIME=$(date +%s)
        _PHASE_START_TIME=$((_PHASE_START_TIME * 1000))
    fi

    # Also start metrics tracking (bash 3.x compatible lowercase)
    local phase_name_lower
    phase_name_lower=$(echo "$phase_name" | tr '[:upper:]' '[:lower:]')
    metrics::start "phase_${phase}_${phase_name_lower}"

    # Output separator and header (FR-064)
    local separator="═══════════════════════════════════════════════════════════════════════════════"
    local header="   Phase ${phase}/${PHASE_TOTAL}: ${phase_name}（${phase_name_cn}）   "

    if [[ "${MSP_LOG_CONSOLE:-true}" == "true" ]]; then
        echo ""
        if [[ "${NO_ANSI:-false}" != "true" ]]; then
            echo -e "${COLOR_CYAN}${separator}${COLOR_RESET}"
            echo -e "${COLOR_CYAN}${header}${COLOR_RESET}"
            echo -e "${COLOR_CYAN}${separator}${COLOR_RESET}"
        else
            echo "$separator"
            echo "$header"
            echo "$separator"
        fi
        echo ""
    fi

    # Log to file
    if [[ "${MSP_LOG_FILE_ENABLED:-true}" == "true" ]]; then
        echo "" >> "$MSP_LOG_FILE"
        echo "$separator" >> "$MSP_LOG_FILE"
        echo "$header" >> "$MSP_LOG_FILE"
        echo "$separator" >> "$MSP_LOG_FILE"
        echo "" >> "$MSP_LOG_FILE"
    fi

    # bash 3.x compatible uppercase
    local phase_name_upper
    phase_name_upper=$(echo "$phase_name" | tr '[:lower:]' '[:upper:]')
    log::info "$phase_name_upper" "Starting Phase ${phase}/${PHASE_TOTAL}: ${phase_name} (${total_steps} steps)"
}

# @description End the current phase with timing and status summary.
#              Records phase duration and ends metrics tracking.
# @param $1 status - Phase completion status (default: "success")
#                    Options: "success", "failed", "skipped"
log_phase_end() {
    local status="${1:-success}"
    local phase="$_CURRENT_PHASE"
    local phase_name
    phase_name=$(_get_phase_name "$phase")

    # Calculate duration
    local end_time
    if command -v gdate &>/dev/null; then
        end_time=$(gdate +%s%3N)
    elif [[ "$(uname)" == "Darwin" ]] && command -v python3 &>/dev/null; then
        end_time=$(python3 -c 'import time; print(int(time.time() * 1000))')
    else
        end_time=$(date +%s)
        end_time=$((end_time * 1000))
    fi

    local duration=$(( end_time - _PHASE_START_TIME ))
    local duration_sec=$((duration / 1000))
    local duration_ms=$((duration % 1000))

    # Store status and duration
    _set_phase_status "$phase" "$status"
    _set_phase_duration "$phase" "$duration"

    # End metrics tracking (bash 3.x compatible lowercase)
    local phase_name_lower
    phase_name_lower=$(echo "$phase_name" | tr '[:upper:]' '[:lower:]')
    metrics::end "phase_${phase}_${phase_name_lower}"

    # Determine status indicator and color
    local status_indicator
    local status_color
    case "$status" in
        success)
            status_indicator="✅ COMPLETED"
            status_color="${COLOR_GREEN}"
            ;;
        failed)
            status_indicator="❌ FAILED"
            status_color="${COLOR_RED}"
            ;;
        skipped)
            status_indicator="⏭️  SKIPPED"
            status_color="${COLOR_YELLOW}"
            ;;
        *)
            status_indicator="⚠️  UNKNOWN"
            status_color="${COLOR_YELLOW}"
            ;;
    esac

    # Output summary (bash 3.x compatible uppercase)
    local phase_name_upper
    phase_name_upper=$(echo "$phase_name" | tr '[:lower:]' '[:upper:]')
    local summary="Phase ${phase}/${PHASE_TOTAL}: ${phase_name} ${status_indicator} (${duration_sec}s ${duration_ms}ms)"

    if [[ "$status" == "success" ]]; then
        log::success "$phase_name_upper" "$summary"
    elif [[ "$status" == "failed" ]]; then
        log::error "$phase_name_upper" "$summary"
    else
        log::warn "$phase_name_upper" "$summary"
    fi

    # Output separator
    local separator="───────────────────────────────────────────────────────────────────────────────"
    if [[ "${MSP_LOG_CONSOLE:-true}" == "true" ]]; then
        if [[ "${NO_ANSI:-false}" != "true" ]]; then
            echo -e "${status_color}${separator}${COLOR_RESET}"
        else
            echo "$separator"
        fi
        echo ""
    fi

    if [[ "${MSP_LOG_FILE_ENABLED:-true}" == "true" ]]; then
        echo "$separator" >> "$MSP_LOG_FILE"
        echo "" >> "$MSP_LOG_FILE"
    fi
}

# @description Log a step within current phase (FR-063 format).
#              Auto-increments step counter unless step_override is provided.
#              Format: [Phase X/4] [Step YY/ZZ] [LEVEL] message
# @param $1 level - Log level (INFO, WARN, ERROR, SUCCESS, DEBUG)
#                   OR message string for legacy single-arg usage
# @param $2 message - Log message content (optional if $1 is message)
# @param $3 step_override - Override step number instead of auto-increment
log_step() {
    local level=""
    local message=""
    local step_override=""

    # Handle backward compatibility: single arg = INFO level with message
    if [[ $# -eq 1 ]]; then
        level="INFO"
        message="$1"
    elif [[ $# -eq 2 ]]; then
        level="$1"
        message="$2"
    else
        level="${1:-INFO}"
        message="${2:-}"
        step_override="${3:-}"
    fi

    # Auto-increment step if not overridden
    if [[ -z "$step_override" ]]; then
        _CURRENT_STEP=$((_CURRENT_STEP + 1))
    else
        _CURRENT_STEP="$step_override"
    fi

    local phase="$_CURRENT_PHASE"
    local total_steps
    total_steps=$(_get_phase_step_count "$phase")
    local phase_name
    phase_name=$(_get_phase_name "$phase")

    # Format step number with leading zero
    local step_str
    printf -v step_str "%02d" "$_CURRENT_STEP"
    local total_str
    printf -v total_str "%02d" "$total_steps"

    # Build prefix: [Phase X/4] [Step YY/ZZ]
    local prefix="[Phase ${phase}/${PHASE_TOTAL}] [Step ${step_str}/${total_str}]"

    # Determine color based on level (bash 3.x compatible uppercase)
    local color="$COLOR_RESET"
    local level_upper
    level_upper=$(echo "$level" | tr '[:lower:]' '[:upper:]')
    case "$level_upper" in
        DEBUG) color="$COLOR_GRAY" ;;
        INFO)  color="$COLOR_BLUE" ;;
        WARN)  color="$COLOR_YELLOW" ;;
        ERROR) color="$COLOR_RED" ;;
        SUCCESS) color="$COLOR_GREEN" ;;
    esac

    # Build full log line
    local timestamp
    timestamp=$(_log_timestamp)

    local log_line
    if [[ "${NO_ANSI:-false}" == "true" ]]; then
        log_line="[$timestamp] ${prefix} [$level_upper] $message"
    else
        log_line="${COLOR_GRAY}[$timestamp]${COLOR_RESET} ${COLOR_PURPLE}${prefix}${COLOR_RESET} ${color}[$level_upper]${COLOR_RESET} $message"
    fi

    # Output to console
    if [[ "${MSP_LOG_CONSOLE:-true}" == "true" ]]; then
        if [[ "$level_upper" == "ERROR" ]] || [[ "$level_upper" == "FATAL" ]]; then
            echo -e "$log_line" >&2
        else
            echo -e "$log_line"
        fi
    fi

    # Output to file (strip ANSI codes)
    if [[ "${MSP_LOG_FILE_ENABLED:-true}" == "true" ]]; then
        echo -e "$log_line" | sed 's/\x1b\[[0-9;]*m//g' >> "$MSP_LOG_FILE"
    fi
}

# @description Log an INFO level step.
# @param $1 message - Step message
# @param $2 step_override - Optional step number override
log_step_info() {
    log_step "INFO" "$1" "${2:-}"
}

# @description Log a WARN level step.
# @param $1 message - Step message
# @param $2 step_override - Optional step number override
log_step_warn() {
    log_step "WARN" "$1" "${2:-}"
}

# @description Log an ERROR level step.
# @param $1 message - Step message
# @param $2 step_override - Optional step number override
log_step_error() {
    log_step "ERROR" "$1" "${2:-}"
}

# @description Log a SUCCESS level step with checkmark icon.
# @param $1 message - Step message
# @param $2 step_override - Optional step number override
log_step_success() {
    log_step "SUCCESS" "✅ $1" "${2:-}"
}

# @description Log a DEBUG level step. Only shown when MSP_LOG_LEVEL=0.
# @param $1 message - Step message
# @param $2 step_override - Optional step number override
log_step_debug() {
    # Only output if log level allows DEBUG
    local log_level="${MSP_LOG_LEVEL:-$LOG_LEVEL_INFO}"
    if (( log_level <= LOG_LEVEL_DEBUG )); then
        log_step "DEBUG" "$1" "${2:-}"
    fi
}

# @description Generate and display release summary table (FR-065).
#              Shows status and duration for all 4 phases.
# @param $1 final_status - Overall release status (default: "success")
log_summary() {
    local final_status="${1:-success}"

    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                           RELEASE SUMMARY                                      ║"
    echo "╠═══════════════════════════════════════════════════════════════════════════════╣"

    local total_duration=0
    local all_success=true

    for phase in 1 2 3 4; do
        local phase_name
        phase_name=$(_get_phase_name "$phase")
        local status
        status=$(_get_phase_status "$phase")
        local duration
        duration=$(_get_phase_duration "$phase")

        # Calculate duration display
        local duration_sec=$((duration / 1000))
        local duration_ms=$((duration % 1000))
        local duration_display
        printf -v duration_display "%3ds %03dms" "$duration_sec" "$duration_ms"

        # Determine status indicator
        local status_indicator
        case "$status" in
            success)
                status_indicator="✅ PASS"
                ;;
            failed)
                status_indicator="❌ FAIL"
                all_success=false
                ;;
            skipped)
                status_indicator="⏭️  SKIP"
                ;;
            *)
                status_indicator="⚪ N/A "
                ;;
        esac

        printf "║  Phase %d/4: %-10s  │  %-10s  │  %s  ║\n" \
            "$phase" "$phase_name" "$status_indicator" "$duration_display"

        if [[ "$status" != "not_run" ]] && [[ "$status" != "skipped" ]]; then
            total_duration=$((total_duration + duration))
        fi
    done

    echo "╠═══════════════════════════════════════════════════════════════════════════════╣"

    # Total duration
    local total_sec=$((total_duration / 1000))
    local total_ms=$((total_duration % 1000))
    local total_display
    printf -v total_display "%3ds %03dms" "$total_sec" "$total_ms"

    # Final status
    local final_indicator
    if [[ "$all_success" == "true" ]] && [[ "$final_status" == "success" ]]; then
        final_indicator="✅ RELEASE SUCCESSFUL"
    else
        final_indicator="❌ RELEASE FAILED"
    fi

    printf "║  TOTAL TIME: %-12s │  %s              ║\n" "$total_display" "$final_indicator"
    echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
    echo ""

    # Log file location
    if [[ -n "${MSP_LOG_FILE:-}" ]]; then
        echo "📝 Full log: $MSP_LOG_FILE"
    fi
    if [[ -n "${MSP_METRICS_FILE:-}" ]]; then
        echo "📊 Metrics: $MSP_METRICS_FILE"
    fi
    echo ""
}

# @description Reset all phase tracking state to initial values.
#              Useful for test setup and cleanup.
_reset_phase_tracking() {
    _CURRENT_PHASE=0
    _CURRENT_STEP=0
    _PHASE_START_TIME=0
    _PHASE_1_STATUS="not_run"
    _PHASE_2_STATUS="not_run"
    _PHASE_3_STATUS="not_run"
    _PHASE_4_STATUS="not_run"
    _PHASE_1_DURATION=0
    _PHASE_2_DURATION=0
    _PHASE_3_DURATION=0
    _PHASE_4_DURATION=0
}

# ============================================================================
# Performance Metrics API
# ============================================================================

# Metrics storage file (temporary) - use session ID + PID for uniqueness
_METRICS_TMP_FILE="${MSP_METRICS_FILE%.json}-$$.tmp"

# @description Start timing a named operation for performance metrics.
#              Stores start timestamp in temporary metrics file.
# @param $1 operation - Operation name identifier
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

# @description End timing for a named operation and record duration.
#              Must be called after metrics::start with the same operation name.
# @param $1 operation - Operation name identifier (must match metrics::start)
# @return 0 on success, 1 if no matching start time found
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

# @description Record a metric value to the metrics file.
# @param $1 metric_name - Name of the metric
# @param $2 metric_value - Numeric value
# @param $3 metric_unit - Unit of measurement (default: "count")
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

# @description Save all collected metrics to JSON file.
#              Creates JSON report with all operation durations.
# @return 0 on success, 1 if no metrics file configured
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

# @description Generate and display human-readable metrics report.
#              Shows all operations sorted by duration.
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

# @description [LEGACY] Log an info message. Use log::info instead.
# @param $1 message - Log message content
log_info() {
    log::info "LEGACY" "$1"
}

# @description [LEGACY] Log an error message. Use log::error instead.
# @param $1 message - Log message content
log_error() {
    log::error "LEGACY" "$1"
}

# @description [LEGACY] Log a warning message. Use log::warn instead.
# @param $1 message - Log message content
log_warning() {
    log::warn "LEGACY" "$1"
}

# @description [LEGACY] Alias for log_warning. Use log::warn instead.
# @param $1 message - Log message content
log_warn() {
    log_warning "$@"
}

# @description [LEGACY] Log a success message. Use log::success instead.
# @param $1 message - Log message content
log_success() {
    log::success "LEGACY" "$1"
}

# @description [LEGACY] Internal legacy step logging. Use log_step instead.
# @param $1 message - Log message content
_legacy_log_step() {
    log::info "STEP" "$1"
}

# ============================================================================
# Initialization
# ============================================================================

# @description Initialize the logging system.
#              Creates log and metrics directories, initializes temp files.
#              Called automatically when this module is sourced.
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

