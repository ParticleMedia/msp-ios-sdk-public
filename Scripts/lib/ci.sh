#!/bin/bash

# CI/CD specific functions for MSP iOS SDK build system
# This module provides CI environment detection, optimization, and integration features

# Source dependencies
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# CI Environment detection
detect_ci_provider() {
    if [[ -n "${GITHUB_ACTIONS}" ]]; then
        echo "github-actions"
    elif [[ -n "${GITLAB_CI}" ]]; then
        echo "gitlab-ci"
    elif [[ -n "${CIRCLECI}" ]]; then
        echo "circleci"
    elif [[ -n "${TRAVIS}" ]]; then
        echo "travis-ci"
    elif [[ -n "${JENKINS_URL}" ]]; then
        echo "jenkins"
    elif [[ -n "${BITBUCKET_BUILD_NUMBER}" ]]; then
        echo "bitbucket"
    elif [[ -n "${AZURE_PIPELINES}" ]]; then
        echo "azure-pipelines"
    elif [[ -n "${CI}" ]]; then
        echo "generic-ci"
    else
        echo "none"
    fi
}

is_ci_environment() {
    [[ "$(detect_ci_provider)" != "none" ]]
}

is_pull_request() {
    case "$(detect_ci_provider)" in
        "github-actions")
            [[ "${GITHUB_EVENT_NAME}" == "pull_request" ]]
            ;;
        "gitlab-ci")
            [[ -n "${CI_MERGE_REQUEST_ID}" ]]
            ;;
        "circleci")
            [[ -n "${CIRCLE_PULL_REQUEST}" ]]
            ;;
        "travis-ci")
            [[ "${TRAVIS_PULL_REQUEST}" != "false" ]]
            ;;
        *)
            false
            ;;
    esac
}

get_branch_name() {
    case "$(detect_ci_provider)" in
        "github-actions")
            if [[ "${GITHUB_EVENT_NAME}" == "pull_request" ]]; then
                echo "${GITHUB_HEAD_REF}"
            else
                echo "${GITHUB_REF_NAME}"
            fi
            ;;
        "gitlab-ci")
            echo "${CI_COMMIT_REF_NAME}"
            ;;
        "circleci")
            echo "${CIRCLE_BRANCH}"
            ;;
        "travis-ci")
            echo "${TRAVIS_BRANCH}"
            ;;
        *)
            git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"
            ;;
    esac
}

get_commit_sha() {
    case "$(detect_ci_provider)" in
        "github-actions")
            echo "${GITHUB_SHA}"
            ;;
        "gitlab-ci")
            echo "${CI_COMMIT_SHA}"
            ;;
        "circleci")
            echo "${CIRCLE_SHA1}"
            ;;
        "travis-ci")
            echo "${TRAVIS_COMMIT}"
            ;;
        *)
            git rev-parse HEAD 2>/dev/null || echo "unknown"
            ;;
    esac
}

get_build_number() {
    case "$(detect_ci_provider)" in
        "github-actions")
            echo "${GITHUB_RUN_NUMBER}"
            ;;
        "gitlab-ci")
            echo "${CI_PIPELINE_ID}"
            ;;
        "circleci")
            echo "${CIRCLE_BUILD_NUM}"
            ;;
        "travis-ci")
            echo "${TRAVIS_BUILD_NUMBER}"
            ;;
        "jenkins")
            echo "${BUILD_NUMBER}"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# CI-specific optimizations
configure_ci_environment() {
    local ci_provider
    ci_provider=$(detect_ci_provider)
    
    if [[ "$ci_provider" == "none" ]]; then
        log_debug "Not in CI environment, skipping CI configuration"
        return $EXIT_SUCCESS
    fi
    
    log_step "Configuring environment for $ci_provider..."
    
    # Common CI optimizations
    export CI_MODE=true
    export FASTLANE_DISABLE_COLORS=true
    export FASTLANE_SKIP_UPDATE_CHECK=true
    export COCOAPODS_DISABLE_STATS=true
    export HOMEBREW_NO_AUTO_UPDATE=1
    
    # Provider-specific optimizations
    case "$ci_provider" in
        "github-actions")
            configure_github_actions
            ;;
        "gitlab-ci")
            configure_gitlab_ci
            ;;
        "circleci")
            configure_circleci
            ;;
        *)
            configure_generic_ci
            ;;
    esac
    
    log_success "CI environment configured for $ci_provider"
}

configure_github_actions() {
    log_debug "Configuring GitHub Actions specific settings..."
    
    # Enable problem matchers
    echo "::add-matcher::.github/problem-matchers/xcodebuild.json" 2>/dev/null || true
    
    # Configure git for GitHub Actions
    if [[ -n "${GITHUB_ACTOR}" ]]; then
        git config --global user.name "${GITHUB_ACTOR}"
        git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"
    fi
    
    # Set environment variables for better caching
    export COCOAPODS_CACHE_DIR="${HOME}/.cocoapods_cache"
    export BUNDLE_CACHE_DIR="${HOME}/.bundle_cache"
    
    # Optimize for GitHub Actions runners
    export XCODE_XCCONFIG_FILE="${RUNNER_TEMP}/ci.xcconfig"
    
    # Create temporary xcconfig for CI optimizations
    cat > "${XCODE_XCCONFIG_FILE}" << EOF
// CI-specific build optimizations
COMPILER_INDEX_STORE_ENABLE = NO
SWIFT_COMPILATION_MODE = wholemodule
SWIFT_OPTIMIZATION_LEVEL = -O
DEBUG_INFORMATION_FORMAT = dwarf
ONLY_ACTIVE_ARCH = NO
EOF
}

configure_gitlab_ci() {
    log_debug "Configuring GitLab CI specific settings..."
    
    # GitLab CI optimizations
    export GITLAB_CI_MODE=true
    
    # Configure caching paths
    export COCOAPODS_CACHE_DIR="${CI_PROJECT_DIR}/.cocoapods_cache"
    export BUNDLE_CACHE_DIR="${CI_PROJECT_DIR}/.bundle_cache"
}

configure_circleci() {
    log_debug "Configuring CircleCI specific settings..."
    
    # CircleCI optimizations
    export CIRCLE_CI_MODE=true
    
    # Configure caching paths
    export COCOAPODS_CACHE_DIR="/tmp/cocoapods_cache"
    export BUNDLE_CACHE_DIR="/tmp/bundle_cache"
}

configure_generic_ci() {
    log_debug "Configuring generic CI settings..."
    
    # Generic CI optimizations
    export GENERIC_CI_MODE=true
    
    # Use temporary directories for caching
    export COCOAPODS_CACHE_DIR="/tmp/cocoapods_cache"
    export BUNDLE_CACHE_DIR="/tmp/bundle_cache"
}

# Artifact management
create_ci_artifacts_dir() {
    local artifacts_dir="${CI_ARTIFACTS_DIR:-artifacts}"
    
    ensure_directory "$artifacts_dir"
    export CI_ARTIFACTS_DIR="$artifacts_dir"
    
    log_debug "CI artifacts directory: $artifacts_dir"
    echo "$artifacts_dir"
}

save_build_artifact() {
    local source_path="$1"
    local artifact_name="$2"
    local artifact_type="${3:-file}"
    
    local artifacts_dir
    artifacts_dir=$(create_ci_artifacts_dir)
    
    if [[ ! -e "$source_path" ]]; then
        log_warn "Artifact source not found: $source_path"
        return $EXIT_VALIDATION_ERROR
    fi
    
    local destination="$artifacts_dir/$artifact_name"
    
    log_step "Saving $artifact_type artifact: $artifact_name..."
    
    if [[ -d "$source_path" ]]; then
        # Directory artifact - create archive
        local archive_path="$destination.tar.gz"
        if tar -czf "$archive_path" -C "$(dirname "$source_path")" "$(basename "$source_path")"; then
            log_artifact "$artifact_type" "$artifact_name" "$archive_path" "$(get_file_size "$archive_path")"
            log_success "Directory artifact saved: $archive_path"
        else
            log_error "Failed to create directory artifact: $archive_path"
            return $EXIT_GENERAL_ERROR
        fi
    else
        # File artifact - copy directly
        if cp "$source_path" "$destination"; then
            log_artifact "$artifact_type" "$artifact_name" "$destination" "$(get_file_size "$destination")"
            log_success "File artifact saved: $destination"
        else
            log_error "Failed to copy file artifact: $destination"
            return $EXIT_GENERAL_ERROR
        fi
    fi
    
    return $EXIT_SUCCESS
}

save_framework_artifacts() {
    local frameworks=(
        "MSPSharedLibraries/MSPiOSCore.xcframework:MSPiOSCore.xcframework"
        "NovaAdapter/NovaCore.xcframework:NovaCore.xcframework"
    )
    
    log_step "Saving framework artifacts..."
    
    for framework_spec in "${frameworks[@]}"; do
        local source_path="${framework_spec%:*}"
        local artifact_name="${framework_spec#*:}"
        
        if [[ -d "$source_path" ]]; then
            save_build_artifact "$source_path" "$artifact_name" "framework"
        else
            log_debug "Framework not found, skipping: $source_path"
        fi
    done
}

save_log_artifacts() {
    local log_files=(
        "xcodebuild*.log"
        "fastlane*.log"
        "pod*.log"
    )
    
    log_step "Saving log artifacts..."
    
    for log_pattern in "${log_files[@]}"; do
        for log_file in $log_pattern; do
            if [[ -f "$log_file" ]]; then
                save_build_artifact "$log_file" "$(basename "$log_file")" "log"
            fi
        done
    done
}

# Build status reporting
report_build_status() {
    local status="$1"
    local message="${2:-}"
    local details="${3:-}"
    
    case "$(detect_ci_provider)" in
        "github-actions")
            report_github_actions_status "$status" "$message" "$details"
            ;;
        "gitlab-ci")
            report_gitlab_ci_status "$status" "$message" "$details"
            ;;
        *)
            log_info "Build status: $status"
            if [[ -n "$message" ]]; then
                log_info "Message: $message"
            fi
            ;;
    esac
}

report_github_actions_status() {
    local status="$1"
    local message="${2:-}"
    local details="${3:-}"
    
    case "$status" in
        "success")
            echo "::notice::$message"
            if [[ -n "$details" ]]; then
                echo "::notice::$details"
            fi
            ;;
        "failure")
            echo "::error::$message"
            if [[ -n "$details" ]]; then
                echo "::error::$details"
            fi
            ;;
        "warning")
            echo "::warning::$message"
            if [[ -n "$details" ]]; then
                echo "::warning::$details"
            fi
            ;;
    esac
}

report_gitlab_ci_status() {
    local status="$1"
    local message="${2:-}"
    
    # GitLab CI uses job status, so we just log appropriately
    case "$status" in
        "success")
            log_success "$message"
            ;;
        "failure")
            log_error "$message"
            ;;
        "warning")
            log_warn "$message"
            ;;
    esac
}

# Environment information
dump_ci_environment() {
    if [[ $LOG_LEVEL -le $LOG_LEVEL_DEBUG ]]; then
        print_subsection "CI Environment Information"
        
        local ci_provider
        ci_provider=$(detect_ci_provider)
        
        log_debug "CI Provider: $ci_provider"
        log_debug "Is CI: $(is_ci_environment && echo "true" || echo "false")"
        log_debug "Is PR: $(is_pull_request && echo "true" || echo "false")"
        log_debug "Branch: $(get_branch_name)"
        log_debug "Commit: $(get_commit_sha)"
        log_debug "Build Number: $(get_build_number)"
        
        # Provider-specific information
        case "$ci_provider" in
            "github-actions")
                log_debug "GitHub Repository: ${GITHUB_REPOSITORY:-unknown}"
                log_debug "GitHub Actor: ${GITHUB_ACTOR:-unknown}"
                log_debug "GitHub Event: ${GITHUB_EVENT_NAME:-unknown}"
                log_debug "GitHub Workflow: ${GITHUB_WORKFLOW:-unknown}"
                log_debug "GitHub Job: ${GITHUB_JOB:-unknown}"
                ;;
            "gitlab-ci")
                log_debug "GitLab Project: ${CI_PROJECT_PATH:-unknown}"
                log_debug "GitLab Pipeline: ${CI_PIPELINE_ID:-unknown}"
                log_debug "GitLab Job: ${CI_JOB_NAME:-unknown}"
                ;;
            "circleci")
                log_debug "Circle Project: ${CIRCLE_PROJECT_REPONAME:-unknown}"
                log_debug "Circle Build: ${CIRCLE_BUILD_NUM:-unknown}"
                log_debug "Circle Job: ${CIRCLE_JOB:-unknown}"
                ;;
        esac
    fi
}

# Performance monitoring
start_performance_monitoring() {
    local monitor_file="/tmp/build_performance.log"
    
    if command -v top >/dev/null 2>&1; then
        # Start background monitoring
        {
            echo "timestamp,cpu_usage,memory_usage"
            while true; do
                local timestamp
                timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
                local cpu_usage
                cpu_usage=$(top -l 1 -n 0 | grep "CPU usage" | cut -d: -f2 | cut -d% -f1 | xargs)
                local memory_usage
                memory_usage=$(top -l 1 -n 0 | grep "PhysMem" | cut -d: -f2 | cut -d, -f1 | xargs)
                
                echo "$timestamp,$cpu_usage,$memory_usage"
                sleep 30
            done
        } > "$monitor_file" &
        
        echo $! > "/tmp/performance_monitor.pid"
        log_debug "Started performance monitoring (PID: $!)"
    fi
}

stop_performance_monitoring() {
    local pid_file="/tmp/performance_monitor.pid"
    local monitor_file="/tmp/build_performance.log"
    
    if [[ -f "$pid_file" ]]; then
        local pid
        pid=$(cat "$pid_file")
        if kill "$pid" 2>/dev/null; then
            log_debug "Stopped performance monitoring (PID: $pid)"
        fi
        rm -f "$pid_file"
        
        # Save performance log as artifact
        if [[ -f "$monitor_file" ]]; then
            save_build_artifact "$monitor_file" "performance.log" "log"
        fi
    fi
}

# Cache management
setup_ci_caching() {
    local cache_dirs=(
        "${COCOAPODS_CACHE_DIR:-$HOME/.cocoapods}"
        "${BUNDLE_CACHE_DIR:-$HOME/.bundle}"
        "DerivedData"
    )
    
    log_step "Setting up CI caching..."
    
    for cache_dir in "${cache_dirs[@]}"; do
        if [[ -n "$cache_dir" ]]; then
            ensure_directory "$cache_dir"
            log_debug "Cache directory prepared: $cache_dir"
        fi
    done
    
    # Provider-specific caching setup
    case "$(detect_ci_provider)" in
        "github-actions")
            setup_github_actions_caching
            ;;
        "gitlab-ci")
            setup_gitlab_ci_caching
            ;;
    esac
    
    log_success "CI caching setup completed"
}

setup_github_actions_caching() {
    # GitHub Actions caching is handled by the workflow,
    # but we can optimize the cache key generation
    local cache_key_base="ios-build"
    local cache_key_suffix
    
    # Create cache key based on dependencies
    if [[ -f "Podfile.lock" ]]; then
        cache_key_suffix=$(sha256sum "Podfile.lock" | cut -d' ' -f1)
    else
        cache_key_suffix="no-podfile"
    fi
    
    echo "::set-output name=cache-key::$cache_key_base-$cache_key_suffix"
}

setup_gitlab_ci_caching() {
    # GitLab CI caching is handled by .gitlab-ci.yml,
    # but we can prepare the cache directories
    log_debug "GitLab CI caching prepared"
}

# Cleanup for CI
cleanup_ci_environment() {
    log_step "Cleaning up CI environment..."
    
    # Stop performance monitoring
    stop_performance_monitoring
    
    # Save artifacts
    save_framework_artifacts
    save_log_artifacts
    
    # Clean up temporary files
    local temp_files=(
        "/tmp/xcodebuild*.log"
        "/tmp/build*.log"
        "${XCODE_XCCONFIG_FILE:-}"
    )
    
    for temp_file in "${temp_files[@]}"; do
        if [[ -n "$temp_file" ]] && [[ -f "$temp_file" ]]; then
            rm -f "$temp_file"
        fi
    done
    
    log_success "CI environment cleanup completed"
}

# Main CI initialization
init_ci() {
    if is_ci_environment; then
        log_info "Initializing CI environment..."
        
        # Configure CI environment
        configure_ci_environment
        
        # Dump environment information
        dump_ci_environment
        
        # Setup caching
        setup_ci_caching
        
        # Start performance monitoring
        start_performance_monitoring
        
        # Setup cleanup trap
        trap cleanup_ci_environment EXIT
        
        log_success "CI environment initialized"
    else
        log_debug "Not in CI environment, skipping CI initialization"
    fi
}

# Export CI functions
export -f detect_ci_provider is_ci_environment is_pull_request
export -f get_branch_name get_commit_sha get_build_number
export -f configure_ci_environment
export -f create_ci_artifacts_dir save_build_artifact save_framework_artifacts save_log_artifacts
export -f report_build_status
export -f dump_ci_environment
export -f start_performance_monitoring stop_performance_monitoring
export -f setup_ci_caching cleanup_ci_environment
export -f init_ci
