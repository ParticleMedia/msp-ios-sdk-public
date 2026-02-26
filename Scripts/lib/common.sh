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

# Common utility functions and variables for MSP iOS SDK build system
# This module provides shared functionality used across all build scripts

# Source unified logging (with guard against multiple sourcing)
# shellcheck source=Scripts/release/utils/logger.sh
if [[ -f "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/release/utils/logger.sh" ]]; then
    source "$(git rev-parse --show-toplevel)/Scripts/release/utils/logger.sh" 2>/dev/null || true
fi

# R041f: Source config loader extension for build settings
# shellcheck source=Scripts/lib/config_loader_ext.sh
if [[ -f "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/config_loader_ext.sh" ]]; then
    source "$(git rev-parse --show-toplevel)/Scripts/lib/config_loader_ext.sh" 2>/dev/null || true
    load_build_config 2>/dev/null || true
fi

# R012c: Source time_utils.sh for unified time functions
# shellcheck source=Scripts/lib/shared/time_utils.sh
if [[ -f "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/shared/time_utils.sh" ]]; then
    source "$(git rev-parse --show-toplevel)/Scripts/lib/shared/time_utils.sh" 2>/dev/null || true
fi

# Script metadata
[[ -z "${SCRIPT_VERSION:-}" ]] && readonly SCRIPT_VERSION="2.0.0"
[[ -z "${SCRIPT_NAME:-}" ]] && readonly SCRIPT_NAME="MSP iOS SDK Build System"

# Exit codes
[[ -z "${EXIT_SUCCESS:-}" ]] && readonly EXIT_SUCCESS=0
[[ -z "${EXIT_GENERAL_ERROR:-}" ]] && readonly EXIT_GENERAL_ERROR=1
[[ -z "${EXIT_COMMAND_NOT_FOUND:-}" ]] && readonly EXIT_COMMAND_NOT_FOUND=2
[[ -z "${EXIT_NOT_FOUND_YET:-}" ]] && readonly EXIT_NOT_FOUND_YET=7
[[ -z "${EXIT_VALIDATION_ERROR:-}" ]] && readonly EXIT_VALIDATION_ERROR=3
[[ -z "${EXIT_BUILD_ERROR:-}" ]] && readonly EXIT_BUILD_ERROR=4
[[ -z "${EXIT_DEPLOY_ERROR:-}" ]] && readonly EXIT_DEPLOY_ERROR=5
[[ -z "${EXIT_CONFIG_ERROR:-}" ]] && readonly EXIT_CONFIG_ERROR=6

# Default configuration
[[ -z "${DEFAULT_SKIP_CODE_SIGN:-}" ]] && readonly DEFAULT_SKIP_CODE_SIGN=0
[[ -z "${DEFAULT_CONFIGURATION:-}" ]] && readonly DEFAULT_CONFIGURATION="Release"
# R041f: Use configurable deployment target from build-config.yaml
[[ -z "${DEFAULT_IOS_DEPLOYMENT_TARGET:-}" ]] && readonly DEFAULT_IOS_DEPLOYMENT_TARGET="${BUILD_IOS_DEPLOYMENT_TARGET:-15.0}"

# Environment detection
detect_environment() {
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        echo "github-actions"
    elif [[ -n "${CI:-}" ]]; then
        echo "ci"
    elif [[ -n "${FL_BUILDLOG_PATH:-}" ]]; then
        echo "fastlane"
    else
        echo "local"
    fi
}

[[ -z "${BUILD_ENVIRONMENT:-}" ]] && readonly BUILD_ENVIRONMENT=$(detect_environment)

# Timing functions
start_timer() {
    TIMER_START=$(date +%s)
}

end_timer() {
    if [[ -n "${TIMER_START}" ]]; then
        local end_time=$(date +%s)
        local duration=$((end_time - TIMER_START))
        echo "$duration"
    else
        echo 0
    fi
}

format_duration() {
    local duration=$1
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    if [[ $minutes -gt 0 ]]; then
        echo "${minutes}m ${seconds}s"
    else
        echo "${seconds}s"
    fi
}

# Path utilities
get_script_dir() {
    echo "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
}

get_project_root() {
    local script_dir=$(get_script_dir)
    echo "$(dirname "$(dirname "$script_dir")")"
}

# Ensure we're in the project root
ensure_project_root() {
    local project_root=$(get_project_root)
    if [[ "$(pwd)" != "$project_root" ]]; then
        cd "$project_root" || {
            log::error "COMMON" "Failed to change to project root: $project_root"
            exit $EXIT_GENERAL_ERROR
        }
    fi
}

# Configuration loading
load_config() {
    local config_file="$1"
    local config_path="$(get_script_dir)/../config/$config_file"
    
    if [[ -f "$config_path" ]]; then
        source "$config_path"
        return $EXIT_SUCCESS
    else
        return $EXIT_CONFIG_ERROR
    fi
}

# Array utilities
array_contains() {
    local element="$1"
    shift
    local array=("$@")
    
    for item in "${array[@]}"; do
        if [[ "$item" == "$element" ]]; then
            return $EXIT_SUCCESS
        fi
    done
    return $EXIT_GENERAL_ERROR
}

# String utilities
trim_whitespace() {
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"   # remove leading whitespace
    var="${var%"${var##*[![:space:]]}"}"   # remove trailing whitespace
    echo "$var"
}

to_lowercase() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

to_uppercase() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Version comparison
version_greater_equal() {
    local version1="$1"
    local version2="$2"
    
    if [[ "$(printf '%s\n' "$version1" "$version2" | sort -V | head -n1)" == "$version2" ]]; then
        return $EXIT_SUCCESS
    else
        return $EXIT_GENERAL_ERROR
    fi
}

# File and directory utilities
ensure_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || {
            log::error "COMMON" "Failed to create directory: $dir"
            return $EXIT_GENERAL_ERROR
        }
    fi
    return $EXIT_SUCCESS
}

safe_remove() {
    local path="$1"
    if [[ -e "$path" ]]; then
        rm -rf "$path" || {
            log::error "COMMON" "Failed to remove: $path"
            return $EXIT_GENERAL_ERROR
        }
    fi
    return $EXIT_SUCCESS
}

get_file_size() {
    local file="$1"
    if [[ -e "$file" ]] && command -v du >/dev/null 2>&1; then
        du -sh "$file" 2>/dev/null | cut -f1
    else
        echo "unknown"
    fi
}

# Process utilities
is_process_running() {
    local process_name="$1"
    pgrep -f "$process_name" >/dev/null 2>&1
}

wait_for_process() {
    local process_name="$1"
    local timeout="${2:-30}"
    local count=0
    
    while is_process_running "$process_name" && [[ $count -lt $timeout ]]; do
        sleep 1
        ((count++)) || true
    done
    
    if [[ $count -ge $timeout ]]; then
        return $EXIT_GENERAL_ERROR
    fi
    return $EXIT_SUCCESS
}

# Cleanup utilities
cleanup_build_artifacts() {
    local artifacts=(
        "Build/Temp/MSPiOSCore"
        "Build/Temp/NovaCore"
        "DerivedData"
        "*.xcarchive"
        "*.dSYM.zip"
    )
    
    for artifact in "${artifacts[@]}"; do
        safe_remove "$artifact"
    done
}

# Environment variable utilities
set_env_default() {
    local var_name="$1"
    local default_value="$2"
    
    if [[ -z "${!var_name}" ]]; then
        export "$var_name"="$default_value"
    fi
}

get_env_bool() {
    local var_name="$1"
    local default_value="${2:-false}"
    local value="${!var_name:-$default_value}"
    
    case "$(to_lowercase "$value")" in
        true|1|yes|on) echo "true" ;;
        *) echo "false" ;;
    esac
}

# Architecture utilities
get_supported_architectures() {
    local platform="$1"
    
    case "$platform" in
        "ios"|"iphoneos")
            echo "arm64"
            ;;
        "ios-simulator"|"iphonesimulator")
            echo "arm64 x86_64"
            ;;
        *)
            echo "arm64"
            ;;
    esac
}

# Error handling utilities
setup_error_handling() {
    set -e
    set -o pipefail
    set -u
}

handle_script_error() {
    local exit_code=$?
    local line_number=$1
    local command="$2"
    
    log::error "COMMON" "Script failed at line $line_number with exit code $exit_code"
    log::error "COMMON" "Failed command: $command"
    
    # Cleanup on error
    cleanup_on_error
    
    exit $exit_code
}

setup_error_trap() {
    trap 'handle_script_error $LINENO "$BASH_COMMAND"' ERR
}

cleanup_on_error() {
    # Override this function in scripts that need custom cleanup on error
    log::debug "COMMON" "Performing default error cleanup..."
}

# Initialization
init_common() {
    setup_error_handling
    setup_error_trap
    ensure_project_root
    set_env_default "SKIP_CODE_SIGN" "$DEFAULT_SKIP_CODE_SIGN"
    set_env_default "CONFIGURATION" "$DEFAULT_CONFIGURATION"
    set_env_default "IPHONEOS_DEPLOYMENT_TARGET" "$DEFAULT_IOS_DEPLOYMENT_TARGET"
    start_timer
}

export -f detect_environment
export -f start_timer end_timer format_duration
export -f get_script_dir get_project_root ensure_project_root
export -f load_config
export -f array_contains
export -f trim_whitespace to_lowercase to_uppercase
export -f version_greater_equal
export -f ensure_directory safe_remove get_file_size
export -f is_process_running wait_for_process
export -f cleanup_build_artifacts
export -f set_env_default get_env_bool
export -f get_supported_architectures
export -f setup_error_handling handle_script_error setup_error_trap cleanup_on_error
export -f init_common
