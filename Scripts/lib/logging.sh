#!/bin/bash

# Logging and output functions for MSP iOS SDK build system
# This module provides comprehensive logging with environment-aware formatting

# Source common utilities
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Color definitions (conditional to avoid readonly conflicts)
[[ -z "${COLOR_RED:-}" ]] && readonly COLOR_RED='\033[0;31m'
[[ -z "${COLOR_GREEN:-}" ]] && readonly COLOR_GREEN='\033[0;32m'
[[ -z "${COLOR_YELLOW:-}" ]] && readonly COLOR_YELLOW='\033[1;33m'
[[ -z "${COLOR_BLUE:-}" ]] && readonly COLOR_BLUE='\033[0;34m'
[[ -z "${COLOR_PURPLE:-}" ]] && readonly COLOR_PURPLE='\033[0;35m'
[[ -z "${COLOR_CYAN:-}" ]] && readonly COLOR_CYAN='\033[0;36m'
[[ -z "${COLOR_WHITE:-}" ]] && readonly COLOR_WHITE='\033[1;37m'
[[ -z "${COLOR_GRAY:-}" ]] && readonly COLOR_GRAY='\033[0;37m'
[[ -z "${COLOR_NC:-}" ]] && readonly COLOR_NC='\033[0m' # No Color

# Log levels (conditional to avoid readonly conflicts)
[[ -z "${LOG_LEVEL_TRACE:-}" ]] && readonly LOG_LEVEL_TRACE=0
[[ -z "${LOG_LEVEL_DEBUG:-}" ]] && readonly LOG_LEVEL_DEBUG=1
[[ -z "${LOG_LEVEL_INFO:-}" ]] && readonly LOG_LEVEL_INFO=2
[[ -z "${LOG_LEVEL_WARN:-}" ]] && readonly LOG_LEVEL_WARN=3
[[ -z "${LOG_LEVEL_ERROR:-}" ]] && readonly LOG_LEVEL_ERROR=4
[[ -z "${LOG_LEVEL_FATAL:-}" ]] && readonly LOG_LEVEL_FATAL=5

# Current log level (can be overridden by environment variable)
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# Output format detection
should_use_colors() {
    case "$BUILD_ENVIRONMENT" in
        "local")
            [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]] && [[ "${NO_COLOR:-}" != "1" ]]
            ;;
        "github-actions")
            # GitHub Actions supports colors
            [[ "${FORCE_COLOR:-}" == "1" ]] || [[ "${NO_COLOR:-}" != "1" ]]
            ;;
        *)
            [[ "${FORCE_COLOR:-}" == "1" ]] && [[ "${NO_COLOR:-}" != "1" ]]
            ;;
    esac
}

should_use_structured_output() {
    case "$BUILD_ENVIRONMENT" in
        "github-actions"|"ci"|"fastlane")
            [[ "${STRUCTURED_OUTPUT:-}" == "1" ]]
            ;;
        *)
            false
            ;;
    esac
}

# Color utility functions
colorize() {
    local color="$1"
    local text="$2"
    
    if should_use_colors; then
        echo -e "${color}${text}${COLOR_NC}"
    else
        echo "$text"
    fi
}

# Emoji support
get_emoji() {
    local type="$1"
    
    # Disable emojis in CI environments that don't support them well
    if [[ "$BUILD_ENVIRONMENT" == "github-actions" ]] && [[ "${DISABLE_EMOJI:-}" == "1" ]]; then
        return
    fi
    
    case "$type" in
        "success") echo "✅" ;;
        "error") echo "❌" ;;
        "warning") echo "⚠️" ;;
        "info") echo "ℹ️" ;;
        "debug") echo "🔍" ;;
        "build") echo "🔧" ;;
        "deploy") echo "🚀" ;;
        "test") echo "🧪" ;;
        "clock") echo "⏱️" ;;
        "package") echo "📦" ;;
        "folder") echo "📁" ;;
        "file") echo "📄" ;;
        "check") echo "🔍" ;;
        "rocket") echo "🚀" ;;
        "party") echo "🎉" ;;
        "lock") echo "🔒" ;;
        "unlock") echo "🔓" ;;
        "phone") echo "📱" ;;
        "gear") echo "⚙️" ;;
        *) echo "" ;;
    esac
}

# Core logging functions
log_with_level() {
    local level="$1"
    local level_name="$2"
    local color="$3"
    local emoji="$4"
    local message="$5"
    
    # Check if we should log this level
    if [[ $level -lt $LOG_LEVEL ]]; then
        return
    fi
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local emoji_str=$(get_emoji "$emoji")
    
    if should_use_structured_output; then
        # JSON structured output for CI systems
        cat <<EOF
{
  "timestamp": "$timestamp",
  "level": "$level_name",
  "message": "$message",
  "environment": "$BUILD_ENVIRONMENT"
}
EOF
    else
        # Human-readable output
        local prefix=""
        if [[ -n "$emoji_str" ]]; then
            prefix="$emoji_str "
        fi
        
        if [[ "$BUILD_ENVIRONMENT" == "local" ]]; then
            # Full format for local development
            colorize "$color" "[$timestamp] $level_name: $prefix$message"
        else
            # Simplified format for CI
            colorize "$color" "$prefix$message"
        fi
    fi
}

# Specific log level functions
log_trace() {
    log_with_level $LOG_LEVEL_TRACE "TRACE" "$COLOR_GRAY" "debug" "$1"
}

log_debug() {
    log_with_level $LOG_LEVEL_DEBUG "DEBUG" "$COLOR_BLUE" "debug" "$1"
}

log_info() {
    log_with_level $LOG_LEVEL_INFO "INFO" "$COLOR_WHITE" "info" "$1"
}

log_warn() {
    log_with_level $LOG_LEVEL_WARN "WARN" "$COLOR_YELLOW" "warning" "$1"
}

log_error() {
    log_with_level $LOG_LEVEL_ERROR "ERROR" "$COLOR_RED" "error" "$1" >&2
}

log_fatal() {
    log_with_level $LOG_LEVEL_FATAL "FATAL" "$COLOR_RED" "error" "$1" >&2
}

# Success and status functions
log_success() {
    log_with_level $LOG_LEVEL_INFO "SUCCESS" "$COLOR_GREEN" "success" "$1"
}

log_step() {
    log_with_level $LOG_LEVEL_INFO "STEP" "$COLOR_CYAN" "build" "$1"
}

# Section and formatting functions
print_section() {
    local title="$1"
    local width=67
    
    if should_use_structured_output; then
        log_info "=== $title ==="
    else
        local separator=""
        for ((i=0; i<width; i++)); do
            separator+="═"
        done
        
        echo ""
        colorize "$COLOR_PURPLE" "$separator"
        colorize "$COLOR_PURPLE" "$title"
        colorize "$COLOR_PURPLE" "$separator"
        echo ""
    fi
}

print_subsection() {
    local title="$1"
    
    if should_use_structured_output; then
        log_info "--- $title ---"
    else
        colorize "$COLOR_CYAN" "--- $title ---"
    fi
}

# Progress and status functions
print_progress() {
    local current="$1"
    local total="$2"
    local message="$3"
    
    local percentage=$((current * 100 / total))
    
    if should_use_structured_output; then
        cat <<EOF
{
  "type": "progress",
  "current": $current,
  "total": $total,
  "percentage": $percentage,
  "message": "$message"
}
EOF
    else
        local emoji_str=$(get_emoji "gear")
        log_info "$emoji_str [$current/$total] ($percentage%) $message"
    fi
}

print_build_summary() {
    local status="$1"
    local duration="$2"
    local details="$3"
    
    print_section "Build Summary"
    
    case "$status" in
        "success")
            log_success "Build completed successfully!"
            ;;
        "failed")
            log_error "Build failed!"
            ;;
        *)
            log_info "Build status: $status"
            ;;
    esac
    
    if [[ -n "$duration" ]]; then
        local clock_emoji=$(get_emoji "clock")
        log_info "$clock_emoji Build duration: $(format_duration "$duration")"
    fi
    
    if [[ -n "$details" ]]; then
        echo "$details"
    fi
}

# Framework and artifact logging
log_framework_info() {
    local name="$1"
    local path="$2"
    local size="$3"
    
    local package_emoji=$(get_emoji "package")
    local folder_emoji=$(get_emoji "folder")
    
    if [[ -n "$size" ]]; then
        log_info "$package_emoji $name: $path ($size)"
    else
        log_info "$folder_emoji $name: $path"
    fi
}

log_artifact() {
    local type="$1"
    local name="$2"
    local path="$3"
    local metadata="$4"
    
    if should_use_structured_output; then
        cat <<EOF
{
  "type": "artifact",
  "artifact_type": "$type",
  "name": "$name",
  "path": "$path",
  "metadata": "$metadata",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    else
        local emoji=""
        case "$type" in
            "framework") emoji=$(get_emoji "package") ;;
            "archive") emoji=$(get_emoji "file") ;;
            "log") emoji=$(get_emoji "file") ;;
            *) emoji=$(get_emoji "file") ;;
        esac
        
        if [[ -n "$metadata" ]]; then
            log_info "$emoji $name: $path ($metadata)"
        else
            log_info "$emoji $name: $path"
        fi
    fi
}

# Environment-specific logging
log_github_actions_command() {
    local command="$1"
    local value="$2"
    
    if [[ "$BUILD_ENVIRONMENT" == "github-actions" ]]; then
        echo "::$command::$value"
    fi
}

log_github_actions_error() {
    local message="$1"
    local file="${2:-}"
    local line="${3:-}"
    
    if [[ "$BUILD_ENVIRONMENT" == "github-actions" ]]; then
        local cmd="::error"
        if [[ -n "$file" ]]; then
            cmd="$cmd file=$file"
        fi
        if [[ -n "$line" ]]; then
            cmd="$cmd,line=$line"
        fi
        echo "$cmd::$message"
    fi
    
    log_error "$message"
}

log_github_actions_warning() {
    local message="$1"
    local file="${2:-}"
    local line="${3:-}"
    
    if [[ "$BUILD_ENVIRONMENT" == "github-actions" ]]; then
        local cmd="::warning"
        if [[ -n "$file" ]]; then
            cmd="$cmd file=$file"
        fi
        if [[ -n "$line" ]]; then
            cmd="$cmd,line=$line"
        fi
        echo "$cmd::$message"
    fi
    
    log_warn "$message"
}

# Command execution with logging
execute_with_logging() {
    local command="$1"
    local description="$2"
    local log_file="${3:-}"
    
    log_step "$description..."
    
    if [[ -n "$log_file" ]]; then
        if eval "$command" > "$log_file" 2>&1; then
            log_success "$description completed"
            return $EXIT_SUCCESS
        else
            local exit_code=$?
            log_error "$description failed (exit code: $exit_code)"
            if [[ -f "$log_file" ]]; then
                log_error "Check log file: $log_file"
            fi
            return $exit_code
        fi
    else
        if eval "$command"; then
            log_success "$description completed"
            return $EXIT_SUCCESS
        else
            local exit_code=$?
            log_error "$description failed (exit code: $exit_code)"
            return $exit_code
        fi
    fi
}

# Debug and diagnostic functions
dump_environment() {
    if [[ $LOG_LEVEL -le $LOG_LEVEL_DEBUG ]]; then
        print_subsection "Environment Information"
        log_debug "Build environment: $BUILD_ENVIRONMENT"
        log_debug "Working directory: $(pwd)"
        log_debug "Script directory: $(get_script_dir)"
        log_debug "Project root: $(get_project_root)"
        log_debug "Log level: $LOG_LEVEL"
        log_debug "Skip code sign: ${SKIP_CODE_SIGN:-unset}"
        log_debug "Configuration: ${CONFIGURATION:-unset}"
        
        if [[ "$BUILD_ENVIRONMENT" == "github-actions" ]]; then
            log_debug "GitHub Actions Runner: ${RUNNER_NAME:-unknown}"
            log_debug "GitHub Repository: ${GITHUB_REPOSITORY:-unknown}"
            log_debug "GitHub Ref: ${GITHUB_REF:-unknown}"
        fi
    fi
}

# Set log level from environment
set_log_level_from_env() {
    local level_str="${LOG_LEVEL_STR:-${DEBUG_LEVEL:-}}"
    
    case "$(to_lowercase "$level_str")" in
        "trace") LOG_LEVEL=$LOG_LEVEL_TRACE ;;
        "debug") LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        "info") LOG_LEVEL=$LOG_LEVEL_INFO ;;
        "warn"|"warning") LOG_LEVEL=$LOG_LEVEL_WARN ;;
        "error") LOG_LEVEL=$LOG_LEVEL_ERROR ;;
        "fatal") LOG_LEVEL=$LOG_LEVEL_FATAL ;;
    esac
    
    # Enable debug logging if DEBUG=1
    if [[ "$(get_env_bool DEBUG false)" == "true" ]]; then
        LOG_LEVEL=$LOG_LEVEL_DEBUG
    fi
}

# Initialize logging
init_logging() {
    set_log_level_from_env
    
    # Dump environment in debug mode
    dump_environment
}

# Export logging functions
export -f should_use_colors should_use_structured_output
export -f colorize get_emoji
export -f log_with_level log_trace log_debug log_info log_warn log_error log_fatal
export -f log_success log_step
export -f print_section print_subsection print_progress print_build_summary
export -f log_framework_info log_artifact
export -f log_github_actions_command log_github_actions_error log_github_actions_warning
export -f execute_with_logging
export -f dump_environment set_log_level_from_env init_logging
