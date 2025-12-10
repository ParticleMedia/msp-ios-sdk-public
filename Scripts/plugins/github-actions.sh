#!/bin/bash
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

# GitHub Actions Plugin for MSP iOS SDK build system
# This plugin provides GitHub Actions specific optimizations and integrations

# Plugin metadata
readonly PLUGIN_NAME="github-actions"
readonly PLUGIN_VERSION="1.0.0"
readonly PLUGIN_DESCRIPTION="GitHub Actions CI/CD Integration Plugin"

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/logging.sh"

# Plugin activation check
is_plugin_active() {
    [[ "${GITHUB_ACTIONS}" == "true" ]]
}

# Plugin initialization
plugin_init() {
    if ! is_plugin_active; then
        return $EXIT_SUCCESS
    fi
    
    log_debug "Initializing GitHub Actions plugin..."
    
    # Configure GitHub Actions environment
    configure_github_actions_environment
    
    # Setup GitHub Actions optimizations
    setup_github_actions_optimizations
    
    # Setup workflow integration
    setup_workflow_integration
    
    # Configure artifact management
    configure_artifact_management
    
    log_success "GitHub Actions plugin initialized"
}

# Environment configuration
configure_github_actions_environment() {
    log_step "Configuring GitHub Actions environment..."
    
    # Override settings for GitHub Actions
    export SKIP_CODE_SIGN=1
    export BUILD_VERBOSE=YES
    export AUTO_CLEANUP_BUILD_ARTIFACTS=YES
    export CLEANUP_DERIVED_DATA=YES
    export ENABLE_BUILD_TIMING=YES
    export STRUCTURED_OUTPUT=YES
    export FORCE_COLOR=0  # Disable colors in CI logs
    export DISABLE_EMOJI=1  # Disable emojis in CI logs
    
    # Set CI-appropriate log level
    export LOG_LEVEL=$LOG_LEVEL_INFO
    
    # GitHub Actions specific settings
    export CI=true
    export GITHUB_ACTIONS_MODE=true
    export RUNNER_TEMP="${RUNNER_TEMP:-/tmp}"
    export RUNNER_WORKSPACE="${RUNNER_WORKSPACE:-$(pwd)}"
    
    # Disable interactive features
    export FASTLANE_DISABLE_COLORS=true
    export FASTLANE_SKIP_UPDATE_CHECK=true
    export COCOAPODS_DISABLE_STATS=true
    export HOMEBREW_NO_AUTO_UPDATE=1
    export HOMEBREW_NO_INSTALL_CLEANUP=1
    
    log_debug "GitHub Actions environment configured"
}

# GitHub Actions optimizations
setup_github_actions_optimizations() {
    log_step "Setting up GitHub Actions optimizations..."
    
    # Configure paths for GitHub Actions runners
    setup_github_actions_paths
    
    # Setup caching strategy
    setup_github_actions_caching
    
    # Configure parallelization
    setup_github_actions_parallelization
    
    # Setup problem matchers
    setup_problem_matchers
    
    log_success "GitHub Actions optimizations configured"
}

setup_github_actions_paths() {
    log_debug "Configuring GitHub Actions paths..."
    
    # Use runner temporary directory for derived data
    export DERIVED_DATA_PATH="$RUNNER_TEMP/DerivedData"
    ensure_directory "$DERIVED_DATA_PATH"
    
    # Configure cache directories
    export COCOAPODS_CACHE_DIR="$HOME/.cocoapods_cache"
    export BUNDLE_CACHE_DIR="$HOME/.bundle_cache"
    export HOMEBREW_CACHE_DIR="$HOME/.homebrew_cache"
    
    # Ensure cache directories exist
    ensure_directory "$COCOAPODS_CACHE_DIR"
    ensure_directory "$BUNDLE_CACHE_DIR"
    ensure_directory "$HOMEBREW_CACHE_DIR"
    
    # Configure artifacts directory
    export GITHUB_ARTIFACTS_DIR="$RUNNER_TEMP/artifacts"
    ensure_directory "$GITHUB_ARTIFACTS_DIR"
    
    log_debug "GitHub Actions paths configured"
}

setup_github_actions_caching() {
    log_debug "Setting up GitHub Actions caching strategy..."
    
    # Generate cache keys for different components
    local cocoapods_cache_key
    local bundle_cache_key
    local derived_data_cache_key
    
    if [[ -f "Podfile.lock" ]]; then
        cocoapods_cache_key="cocoapods-$(shasum -a 256 Podfile.lock | cut -d' ' -f1)"
    else
        cocoapods_cache_key="cocoapods-no-lock"
    fi
    
    if [[ -f "Gemfile.lock" ]]; then
        bundle_cache_key="bundle-$(shasum -a 256 Gemfile.lock | cut -d' ' -f1)"
    else
        bundle_cache_key="bundle-no-lock"
    fi
    
    derived_data_cache_key="derived-data-${GITHUB_SHA:0:8}"
    
    # Output cache keys for GitHub Actions
    echo "::set-output name=cocoapods-cache-key::$cocoapods_cache_key"
    echo "::set-output name=bundle-cache-key::$bundle_cache_key"
    echo "::set-output name=derived-data-cache-key::$derived_data_cache_key"
    
    log_debug "Cache keys generated"
}

setup_github_actions_parallelization() {
    log_debug "Setting up parallelization for GitHub Actions..."
    
    # Configure build parallelization based on runner specs
    local runner_cores
    runner_cores=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "2")
    
    # Use all available cores but cap at 8 for stability
    local max_jobs
    max_jobs=$((runner_cores > 8 ? 8 : runner_cores))
    
    export MAX_PARALLEL_JOBS="$max_jobs"
    export CI_PARALLEL_BUILDS=YES
    
    log_debug "Parallelization configured: $max_jobs parallel jobs"
}

setup_problem_matchers() {
    log_debug "Setting up GitHub Actions problem matchers..."
    
    # Create Xcode problem matcher
    local xcode_matcher_file="$RUNNER_TEMP/xcode-problem-matcher.json"
    
    cat > "$xcode_matcher_file" << 'EOF'
{
    "problemMatcher": [
        {
            "owner": "xcodebuild-error",
            "pattern": [
                {
                    "regexp": "^(.+?):(\\d+):(\\d+):\\s+(error):\\s+(.+)$",
                    "file": 1,
                    "line": 2,
                    "column": 3,
                    "severity": 4,
                    "message": 5
                }
            ]
        },
        {
            "owner": "xcodebuild-warning",
            "pattern": [
                {
                    "regexp": "^(.+?):(\\d+):(\\d+):\\s+(warning):\\s+(.+)$",
                    "file": 1,
                    "line": 2,
                    "column": 3,
                    "severity": 4,
                    "message": 5
                }
            ]
        }
    ]
}
EOF
    
    # Add the problem matcher
    echo "::add-matcher::$xcode_matcher_file"
    
    log_debug "Problem matchers configured"
}

# Workflow integration
setup_workflow_integration() {
    log_step "Setting up GitHub Actions workflow integration..."
    
    # Configure git for GitHub Actions
    configure_git_for_github_actions
    
    # Setup step annotations
    setup_step_annotations
    
    # Configure job outputs
    configure_job_outputs
    
    log_success "Workflow integration configured"
}

configure_git_for_github_actions() {
    log_debug "Configuring git for GitHub Actions..."
    
    # Set git user for any commits that might be needed
    if [[ -n "${GITHUB_ACTOR}" ]]; then
        git config --global user.name "${GITHUB_ACTOR}"
        git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"
        log_debug "Git user configured: ${GITHUB_ACTOR}"
    fi
    
    # Configure git settings for CI
    git config --global core.autocrlf false
    git config --global core.fileMode false
    
    log_debug "Git configuration completed"
}

setup_step_annotations() {
    log_debug "Setting up step annotations..."
    
    # Create step grouping functions
    export -f github_actions_group github_actions_endgroup
    export -f github_actions_notice github_actions_warning github_actions_error
    export -f github_actions_set_output github_actions_add_mask
    
    log_debug "Step annotation functions exported"
}

configure_job_outputs() {
    log_debug "Configuring job outputs..."
    
    # Set standard job outputs
    local build_number="${GITHUB_RUN_NUMBER:-unknown}"
    local commit_sha="${GITHUB_SHA:-unknown}"
    local branch_name="${GITHUB_REF_NAME:-unknown}"
    
    github_actions_set_output "build-number" "$build_number"
    github_actions_set_output "commit-sha" "$commit_sha"
    github_actions_set_output "branch-name" "$branch_name"
    
    log_debug "Job outputs configured"
}

# Artifact management
configure_artifact_management() {
    log_step "Configuring artifact management..."
    
    # Setup artifact collection
    setup_artifact_collection
    
    # Configure artifact retention
    configure_artifact_retention
    
    log_success "Artifact management configured"
}

setup_artifact_collection() {
    log_debug "Setting up artifact collection..."
    
    # Create artifact collection functions
    export GITHUB_COLLECT_ARTIFACTS=true
    export GITHUB_ARTIFACTS_BASE_DIR="$GITHUB_ARTIFACTS_DIR"
    
    # Define artifact categories
    local artifact_categories=(
        "frameworks"
        "logs"
        "reports"
        "metadata"
    )
    
    for category in "${artifact_categories[@]}"; do
        ensure_directory "$GITHUB_ARTIFACTS_DIR/$category"
    done
    
    log_debug "Artifact collection configured"
}

configure_artifact_retention() {
    log_debug "Configuring artifact retention..."
    
    # Set retention based on event type
    local retention_days=7
    
    case "${GITHUB_EVENT_NAME}" in
        "release")
            retention_days=90
            ;;
        "push")
            if [[ "${GITHUB_REF_NAME}" == "main" ]] || [[ "${GITHUB_REF_NAME}" == "master" ]]; then
                retention_days=30
            else
                retention_days=7
            fi
            ;;
        "pull_request")
            retention_days=7
            ;;
        *)
            retention_days=7
            ;;
    esac
    
    export GITHUB_ARTIFACT_RETENTION_DAYS="$retention_days"
    github_actions_set_output "artifact-retention-days" "$retention_days"
    
    log_debug "Artifact retention configured: $retention_days days"
}

# GitHub Actions specific functions
github_actions_group() {
    local group_name="$1"
    echo "::group::$group_name"
}

github_actions_endgroup() {
    echo "::endgroup::"
}

github_actions_notice() {
    local message="$1"
    local file="${2:-}"
    local line="${3:-}"
    
    local annotation="::notice"
    if [[ -n "$file" ]]; then
        annotation="$annotation file=$file"
    fi
    if [[ -n "$line" ]]; then
        annotation="$annotation,line=$line"
    fi
    
    echo "$annotation::$message"
}

github_actions_warning() {
    local message="$1"
    local file="${2:-}"
    local line="${3:-}"
    
    local annotation="::warning"
    if [[ -n "$file" ]]; then
        annotation="$annotation file=$file"
    fi
    if [[ -n "$line" ]]; then
        annotation="$annotation,line=$line"
    fi
    
    echo "$annotation::$message"
}

github_actions_error() {
    local message="$1"
    local file="${2:-}"
    local line="${3:-}"
    
    local annotation="::error"
    if [[ -n "$file" ]]; then
        annotation="$annotation file=$file"
    fi
    if [[ -n "$line" ]]; then
        annotation="$annotation,line=$line"
    fi
    
    echo "$annotation::$message"
}

github_actions_set_output() {
    local name="$1"
    local value="$2"
    
    echo "::set-output name=$name::$value"
}

github_actions_add_mask() {
    local value="$1"
    echo "::add-mask::$value"
}

# Build customizations for GitHub Actions
customize_build_for_github_actions() {
    log_debug "Customizing build process for GitHub Actions..."
    
    # Create GitHub Actions specific xcconfig
    local xcconfig_file="$RUNNER_TEMP/github-actions.xcconfig"
    create_github_actions_xcconfig "$xcconfig_file"
    export XCODE_XCCONFIG_FILE="$xcconfig_file"
    
    # Setup build progress reporting
    setup_build_progress_reporting
    
    # Configure test reporting
    setup_test_reporting
}

create_github_actions_xcconfig() {
    local xcconfig_file="$1"
    
    cat > "$xcconfig_file" << 'EOF'
// GitHub Actions Build Configuration for MSP iOS SDK

// Performance optimizations for CI
COMPILER_INDEX_STORE_ENABLE = NO
SWIFT_COMPILATION_MODE = wholemodule
SWIFT_OPTIMIZATION_LEVEL = -O
DEBUG_INFORMATION_FORMAT = dwarf
ONLY_ACTIVE_ARCH = NO

// Code signing (disabled for CI)
CODE_SIGN_IDENTITY = 
CODE_SIGNING_REQUIRED = NO
CODE_SIGNING_ALLOWED = NO

// Build settings
SKIP_INSTALL = NO
BUILD_LIBRARY_FOR_DISTRIBUTION = YES
ENABLE_BITCODE = NO

// Suppress warnings that are problematic in CI
GCC_WARN_INHIBIT_ALL_WARNINGS = NO
CLANG_WARN_DOCUMENTATION_COMMENTS = NO
EOF
    
    log_debug "Created GitHub Actions Xcode configuration: $xcconfig_file"
}

setup_build_progress_reporting() {
    log_debug "Setting up build progress reporting..."
    
    # Override logging functions to include GitHub Actions annotations
    export BUILD_PROGRESS_REPORTING=true
    
    # Create progress reporting functions
    export -f report_build_start report_build_step report_build_completion
}

setup_test_reporting() {
    log_debug "Setting up test reporting..."
    
    # Configure test result collection
    export COLLECT_TEST_RESULTS=true
    export TEST_RESULTS_DIR="$GITHUB_ARTIFACTS_DIR/test-results"
    ensure_directory "$TEST_RESULTS_DIR"
    
    log_debug "Test reporting configured"
}

# Progress reporting functions
report_build_start() {
    local framework="$1"
    github_actions_group "Building $framework"
    github_actions_notice "Started building $framework"
}

report_build_step() {
    local step="$1"
    local framework="${2:-}"
    
    if [[ -n "$framework" ]]; then
        log_info "$step ($framework)"
    else
        log_info "$step"
    fi
}

report_build_completion() {
    local framework="$1"
    local status="$2"
    local duration="${3:-}"
    
    if [[ "$status" == "success" ]]; then
        local message="Successfully built $framework"
        if [[ -n "$duration" ]]; then
            message="$message in $(format_duration $duration)"
        fi
        github_actions_notice "$message"
    else
        github_actions_error "Failed to build $framework"
    fi
    
    github_actions_endgroup
}

# Artifact management functions
save_framework_artifact() {
    local framework_path="$1"
    local framework_name="$2"
    
    if [[ ! -d "$framework_path" ]]; then
        log_warn "Framework not found for artifact collection: $framework_path"
        return $EXIT_VALIDATION_ERROR
    fi
    
    local artifact_path="$GITHUB_ARTIFACTS_DIR/frameworks/$framework_name"
    
    log_step "Saving framework artifact: $framework_name"
    
    # Create compressed archive of the framework
    if tar -czf "$artifact_path.tar.gz" -C "$(dirname "$framework_path")" "$(basename "$framework_path")"; then
        local size
        size=$(get_file_size "$artifact_path.tar.gz")
        github_actions_notice "Framework artifact saved: $framework_name ($size)"
        
        # Set artifact output
        github_actions_set_output "framework-$framework_name-artifact" "$artifact_path.tar.gz"
        github_actions_set_output "framework-$framework_name-size" "$size"
        
        return $EXIT_SUCCESS
    else
        github_actions_error "Failed to save framework artifact: $framework_name"
        return $EXIT_GENERAL_ERROR
    fi
}

save_log_artifact() {
    local log_file="$1"
    local log_name="${2:-$(basename "$log_file")}"
    
    if [[ ! -f "$log_file" ]]; then
        return $EXIT_SUCCESS  # No error if log doesn't exist
    fi
    
    local artifact_path="$GITHUB_ARTIFACTS_DIR/logs/$log_name"
    
    if cp "$log_file" "$artifact_path"; then
        local size
        size=$(get_file_size "$artifact_path")
        log_debug "Log artifact saved: $log_name ($size)"
        return $EXIT_SUCCESS
    else
        log_warn "Failed to save log artifact: $log_name"
        return $EXIT_GENERAL_ERROR
    fi
}

# Performance monitoring
monitor_github_actions_performance() {
    log_debug "Starting GitHub Actions performance monitoring..."
    
    # Start resource monitoring
    start_resource_monitoring
    
    # Monitor build metrics
    export BUILD_METRICS_FILE="$GITHUB_ARTIFACTS_DIR/metadata/build-metrics.json"
    export BUILD_START_TIME=$(date +%s)
    
    # Setup completion callback
    trap 'report_github_actions_completion' EXIT
}

start_resource_monitoring() {
    local monitor_file="$GITHUB_ARTIFACTS_DIR/metadata/resource-usage.csv"
    
    # Start background resource monitoring
    {
        echo "timestamp,memory_mb,disk_usage_gb"
        while true; do
            local timestamp
            timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
            local memory_mb
            memory_mb=$(ps -eo rss= | awk '{sum+=$1} END {print int(sum/1024)}')
            local disk_usage_gb
            disk_usage_gb=$(df . | tail -1 | awk '{print int($3/1024/1024)}')
            
            echo "$timestamp,$memory_mb,$disk_usage_gb"
            sleep 60
        done
    } > "$monitor_file" &
    
    local monitor_pid=$!
    echo "$monitor_pid" > "$RUNNER_TEMP/resource_monitor.pid"
    log_debug "Started resource monitoring (PID: $monitor_pid)"
}

report_github_actions_completion() {
    if [[ -n "$BUILD_START_TIME" ]]; then
        local build_duration=$(($(date +%s) - BUILD_START_TIME))
        local formatted_duration
        formatted_duration=$(format_duration $build_duration)
        
        # Stop resource monitoring
        local monitor_pid_file="$RUNNER_TEMP/resource_monitor.pid"
        if [[ -f "$monitor_pid_file" ]]; then
            local monitor_pid
            monitor_pid=$(cat "$monitor_pid_file")
            kill "$monitor_pid" 2>/dev/null || true
            rm -f "$monitor_pid_file"
        fi
        
        # Create build metrics
        if [[ -n "$BUILD_METRICS_FILE" ]]; then
            cat > "$BUILD_METRICS_FILE" << EOF
{
    "build_duration_seconds": $build_duration,
    "build_duration_formatted": "$formatted_duration",
    "build_start_time": "$BUILD_START_TIME",
    "build_end_time": "$(date +%s)",
    "github_run_id": "${GITHUB_RUN_ID:-unknown}",
    "github_run_number": "${GITHUB_RUN_NUMBER:-unknown}",
    "github_sha": "${GITHUB_SHA:-unknown}",
    "github_ref": "${GITHUB_REF:-unknown}",
    "runner_os": "${RUNNER_OS:-unknown}",
    "runner_arch": "${RUNNER_ARCH:-unknown}"
}
EOF
        fi
        
        github_actions_notice "Build completed in $formatted_duration"
        github_actions_set_output "build-duration" "$formatted_duration"
        github_actions_set_output "build-duration-seconds" "$build_duration"
    fi
}

# Plugin cleanup
plugin_cleanup() {
    if ! is_plugin_active; then
        return $EXIT_SUCCESS
    fi
    
    log_debug "Cleaning up GitHub Actions plugin..."
    
    # Collect all artifacts
    collect_all_artifacts
    
    # Remove temporary files
    local temp_files=(
        "$RUNNER_TEMP/xcode-problem-matcher.json"
        "$RUNNER_TEMP/github-actions.xcconfig"
        "$RUNNER_TEMP/resource_monitor.pid"
    )
    
    for temp_file in "${temp_files[@]}"; do
        if [[ -f "$temp_file" ]]; then
            rm -f "$temp_file"
        fi
    done
    
    log_debug "GitHub Actions plugin cleanup completed"
}

collect_all_artifacts() {
    log_step "Collecting all artifacts..."
    
    # Collect framework artifacts
    local frameworks=(
        "MSPSharedLibraries/MSPiOSCore.xcframework:MSPiOSCore"
        "NovaAdapter/NovaCore.xcframework:NovaCore"
    )
    
    for framework_spec in "${frameworks[@]}"; do
        local framework_path="${framework_spec%:*}"
        local framework_name="${framework_spec#*:}"
        save_framework_artifact "$framework_path" "$framework_name"
    done
    
    # Collect log artifacts
    local log_files=(
        "xcodebuild*.log"
        "fastlane*.log"
        "pod*.log"
    )
    
    for log_pattern in "${log_files[@]}"; do
        for log_file in $log_pattern; do
            if [[ -f "$log_file" ]]; then
                save_log_artifact "$log_file"
            fi
        done
    done
    
    # Set final artifact directory output
    github_actions_set_output "artifacts-dir" "$GITHUB_ARTIFACTS_DIR"
    
    log_success "Artifact collection completed"
}

# Plugin command handlers
handle_plugin_command() {
    local command="$1"
    shift
    
    case "$command" in
        "monitor")
            monitor_github_actions_performance
            ;;
        "collect-artifacts")
            collect_all_artifacts
            ;;
        "group")
            github_actions_group "$1"
            ;;
        "endgroup")
            github_actions_endgroup
            ;;
        "notice")
            github_actions_notice "$@"
            ;;
        "warning")
            github_actions_warning "$@"
            ;;
        "error")
            github_actions_error "$@"
            ;;
        *)
            log_warn "Unknown GitHub Actions plugin command: $command"
            return $EXIT_GENERAL_ERROR
            ;;
    esac
}

# Export plugin functions
export -f is_plugin_active plugin_init plugin_cleanup handle_plugin_command
export -f configure_github_actions_environment setup_github_actions_optimizations
export -f setup_workflow_integration configure_artifact_management
export -f customize_build_for_github_actions monitor_github_actions_performance
