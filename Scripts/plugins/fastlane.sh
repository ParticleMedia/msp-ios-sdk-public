#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch M, shared) ---
# shellcheck source=/dev/null
_msp_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$_msp_root" ] && [ -f "$_msp_root/Scripts/lib/worktree_guard.sh" ]; then
  . "$_msp_root/Scripts/lib/worktree_guard.sh"
  msp_enforce_main_repo_or_exit
fi
unset _msp_root
# --- End MSP Worktree Safety Guard (Patch M, shared) ---

# Fastlane Integration Plugin for MSP iOS SDK build system
# This plugin provides seamless integration with Fastlane automation

# Plugin metadata
readonly PLUGIN_NAME="fastlane"
readonly PLUGIN_VERSION="1.0.0"
readonly PLUGIN_DESCRIPTION="Fastlane Integration Plugin"

# Source dependencies (common.sh provides unified logging)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# Plugin activation check
is_plugin_active() {
    [[ -n "${FL_BUILDLOG_PATH}" ]] || [[ -n "${FASTLANE_LANE_NAME}" ]] || [[ "$BUILD_ENVIRONMENT" == "fastlane" ]]
}

# Plugin initialization
plugin_init() {
    if ! is_plugin_active; then
        return $EXIT_SUCCESS
    fi
    
    log::debug "PLUGIN" "Initializing Fastlane integration plugin..."
    
    # Configure Fastlane environment
    configure_fastlane_environment
    
    # Setup Fastlane optimizations
    setup_fastlane_optimizations
    
    # Setup lane integration
    setup_lane_integration
    
    # Configure reporting
    configure_fastlane_reporting
    
    log::success "PLUGIN" "Fastlane integration plugin initialized"
}

# Environment configuration
configure_fastlane_environment() {
    log::step "PLUGIN" "Configuring Fastlane environment..."
    
    # Fastlane-specific settings
    export FASTLANE_INTEGRATION_MODE=true
    export SKIP_CODE_SIGN=0  # Fastlane may handle code signing
    export BUILD_VERBOSE=YES
    export AUTO_CLEANUP_BUILD_ARTIFACTS=YES
    export ENABLE_BUILD_TIMING=YES
    export STRUCTURED_OUTPUT=NO  # Fastlane prefers regular output
    export FORCE_COLOR=1
    export DISABLE_EMOJI=0
    
    # Set appropriate log level for Fastlane
    export LOG_LEVEL=$LOG_LEVEL_INFO
    
    # Fastlane environment variables
    export FASTLANE_MODE=true
    export FASTLANE_DISABLE_ANIMATION=true
    export FASTLANE_SKIP_UPDATE_CHECK=true
    export FASTLANE_HIDE_GITHUB_ISSUES=true
    export FASTLANE_DISABLE_COLORS=false  # Keep colors for better UX
    
    # Integration settings
    export COCOAPODS_DISABLE_STATS=true
    export HOMEBREW_NO_AUTO_UPDATE=1
    
    log::debug "PLUGIN" "Fastlane environment configured"
}

# Fastlane optimizations
setup_fastlane_optimizations() {
    log::step "PLUGIN" "Setting up Fastlane optimizations..."
    
    # Configure paths for Fastlane integration
    setup_fastlane_paths
    
    # Setup caching for Fastlane
    setup_fastlane_caching
    
    # Configure build optimizations
    setup_fastlane_build_optimizations
    
    log::success "PLUGIN" "Fastlane optimizations configured"
}

setup_fastlane_paths() {
    log::debug "PLUGIN" "Configuring Fastlane paths..."
    
    # Use Fastlane's build log path if available
    if [[ -n "${FL_BUILDLOG_PATH}" ]]; then
        local fastlane_logs_dir
        fastlane_logs_dir=$(dirname "${FL_BUILDLOG_PATH}")
        export BUILD_LOGS_DIR="$fastlane_logs_dir"
        ensure_directory "$BUILD_LOGS_DIR"
    fi
    
    # Configure derived data path
    export DERIVED_DATA_PATH="${HOME}/Library/Developer/Xcode/DerivedData/MSP-iOS-SDK-Fastlane"
    ensure_directory "$DERIVED_DATA_PATH"
    
    # Setup Fastlane-specific cache directories
    export FASTLANE_CACHE_DIR="${HOME}/.fastlane_cache"
    export COCOAPODS_CACHE_DIR="${HOME}/.fastlane_cocoapods_cache"
    export BUNDLE_CACHE_DIR="${HOME}/.fastlane_bundle_cache"
    
    ensure_directory "$FASTLANE_CACHE_DIR"
    ensure_directory "$COCOAPODS_CACHE_DIR"
    ensure_directory "$BUNDLE_CACHE_DIR"
    
    log::debug "PLUGIN" "Fastlane paths configured"
}

setup_fastlane_caching() {
    log::debug "PLUGIN" "Setting up Fastlane caching..."
    
    # Configure bundler for Fastlane
    if command -v bundle >/dev/null 2>&1; then
        export BUNDLE_PATH="$BUNDLE_CACHE_DIR"
        export BUNDLE_USER_CONFIG="$BUNDLE_CACHE_DIR/.bundle/config"
        export BUNDLE_USER_CACHE="$BUNDLE_CACHE_DIR/cache"
        export BUNDLE_USER_PLUGIN="$BUNDLE_CACHE_DIR/plugins"
        
        ensure_directory "$BUNDLE_USER_CACHE"
        ensure_directory "$BUNDLE_USER_PLUGIN"
    fi
    
    # Configure CocoaPods caching for Fastlane
    export CP_HOME_DIR="$COCOAPODS_CACHE_DIR"
    export CP_REPOS_DIR="$COCOAPODS_CACHE_DIR/repos"
    
    log::debug "PLUGIN" "Fastlane caching configured"
}

setup_fastlane_build_optimizations() {
    log::debug "PLUGIN" "Setting up Fastlane build optimizations..."
    
    # Create Fastlane-specific xcconfig
    local xcconfig_file="$FASTLANE_CACHE_DIR/fastlane.xcconfig"
    create_fastlane_xcconfig "$xcconfig_file"
    export XCODE_XCCONFIG_FILE="$xcconfig_file"
    
    # Configure parallelization for Fastlane
    local cores
    cores=$(sysctl -n hw.ncpu 2>/dev/null || echo "2")
    export MAX_PARALLEL_JOBS="$cores"
    export FASTLANE_PARALLEL_BUILDS=YES
    
    log::debug "PLUGIN" "Fastlane build optimizations configured"
}

create_fastlane_xcconfig() {
    local xcconfig_file="$1"
    
    cat > "$xcconfig_file" << 'EOF'
// Fastlane Build Configuration for MSP iOS SDK

// Build performance
COMPILER_INDEX_STORE_ENABLE = NO
SWIFT_COMPILATION_MODE = wholemodule
ONLY_ACTIVE_ARCH = NO

// Debug information (preserve for Fastlane analysis)
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
ENABLE_TESTABILITY = YES

// Build settings
SKIP_INSTALL = NO
BUILD_LIBRARY_FOR_DISTRIBUTION = YES
ENABLE_BITCODE = NO

// Code signing (let Fastlane handle it)
// CODE_SIGN_IDENTITY will be set by Fastlane if needed
// CODE_SIGNING_REQUIRED will be set by Fastlane if needed

// Optimization
SWIFT_OPTIMIZATION_LEVEL = -O
GCC_OPTIMIZATION_LEVEL = s

// Warnings and analysis
CLANG_ANALYZER_NONNULL = YES
CLANG_WARN_DOCUMENTATION_COMMENTS = NO
GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR
EOF
    
    log::debug "PLUGIN" "Created Fastlane Xcode configuration: $xcconfig_file"
}

# Lane integration
setup_lane_integration() {
    log::step "PLUGIN" "Setting up Fastlane lane integration..."
    
    # Detect current lane
    detect_current_lane
    
    # Setup lane-specific configurations
    configure_lane_specific_settings
    
    # Setup callbacks
    setup_fastlane_callbacks
    
    log::success "PLUGIN" "Lane integration configured"
}

detect_current_lane() {
    local current_lane="${FASTLANE_LANE_NAME:-unknown}"
    local current_platform="${FASTLANE_PLATFORM_NAME:-ios}"
    
    export CURRENT_FASTLANE_LANE="$current_lane"
    export CURRENT_FASTLANE_PLATFORM="$current_platform"
    
    log::debug "PLUGIN" "Detected Fastlane lane: $current_platform:$current_lane"
}

configure_lane_specific_settings() {
    local lane="$CURRENT_FASTLANE_LANE"
    
    case "$lane" in
        "test"|"tests")
            configure_test_lane_settings
            ;;
        "build"|"build_all"|"build_msp_ios_core"|"build_nova_core")
            configure_build_lane_settings
            ;;
        "release"|"deploy")
            configure_release_lane_settings
            ;;
        "validate"|"validate_podspecs")
            configure_validation_lane_settings
            ;;
        *)
            configure_default_lane_settings
            ;;
    esac
    
    log::debug "PLUGIN" "Lane-specific settings configured for: $lane"
}

configure_test_lane_settings() {
    log::debug "PLUGIN" "Configuring test lane settings..."
    
    export FASTLANE_TEST_MODE=true
    export COLLECT_TEST_RESULTS=true
    export TEST_RESULTS_DIR="${BUILD_LOGS_DIR:-$PWD}/test-results"
    export CODE_COVERAGE_ENABLED=true
    
    ensure_directory "$TEST_RESULTS_DIR"
}

configure_build_lane_settings() {
    log::debug "PLUGIN" "Configuring build lane settings..."
    
    export FASTLANE_BUILD_MODE=true
    export ENABLE_BUILD_ANALYSIS=true
    export COLLECT_BUILD_ARTIFACTS=true
    export BUILD_ARTIFACTS_DIR="${BUILD_LOGS_DIR:-$PWD}/build-artifacts"
    
    ensure_directory "$BUILD_ARTIFACTS_DIR"
}

configure_release_lane_settings() {
    log::debug "PLUGIN" "Configuring release lane settings..."
    
    export FASTLANE_RELEASE_MODE=true
    export SKIP_CODE_SIGN=0  # Enable code signing for releases
    export ENABLE_BUILD_VALIDATION=true
    export STRICT_VALIDATION=true
    export PRODUCTION_BUILD=true
}

configure_validation_lane_settings() {
    log::debug "PLUGIN" "Configuring validation lane settings..."
    
    export FASTLANE_VALIDATION_MODE=true
    export STRICT_VALIDATION=true
    export ENABLE_PODSPEC_VALIDATION=true
    export VALIDATION_REPORTS_DIR="${BUILD_LOGS_DIR:-$PWD}/validation-reports"
    
    ensure_directory "$VALIDATION_REPORTS_DIR"
}

configure_default_lane_settings() {
    log::debug "PLUGIN" "Configuring default lane settings..."
    
    export FASTLANE_DEFAULT_MODE=true
}

setup_fastlane_callbacks() {
    log::debug "PLUGIN" "Setting up Fastlane callbacks..."
    
    # Export callback functions
    export -f fastlane_build_started fastlane_build_completed
    export -f fastlane_test_started fastlane_test_completed
    export -f fastlane_validation_started fastlane_validation_completed
    export -f fastlane_lane_started fastlane_lane_completed
    
    # Setup callback triggers
    setup_callback_triggers
}

setup_callback_triggers() {
    # These functions will be called by the build system at appropriate times
    export FASTLANE_CALLBACKS_ENABLED=true
}

# Reporting configuration
configure_fastlane_reporting() {
    log::step "PLUGIN" "Configuring Fastlane reporting..."
    
    # Setup build reporting
    setup_fastlane_build_reporting
    
    # Setup test reporting
    setup_fastlane_test_reporting
    
    # Setup validation reporting
    setup_fastlane_validation_reporting
    
    log::success "PLUGIN" "Fastlane reporting configured"
}

setup_fastlane_build_reporting() {
    log::debug "PLUGIN" "Setting up Fastlane build reporting..."
    
    export FASTLANE_BUILD_REPORTING=true
    export BUILD_REPORT_FILE="${BUILD_LOGS_DIR:-$PWD}/build-report.json"
    export BUILD_SUMMARY_FILE="${BUILD_LOGS_DIR:-$PWD}/build-summary.txt"
}

setup_fastlane_test_reporting() {
    log::debug "PLUGIN" "Setting up Fastlane test reporting..."
    
    export FASTLANE_TEST_REPORTING=true
    export TEST_REPORT_FILE="${BUILD_LOGS_DIR:-$PWD}/test-report.json"
    export TEST_SUMMARY_FILE="${BUILD_LOGS_DIR:-$PWD}/test-summary.txt"
}

setup_fastlane_validation_reporting() {
    log::debug "PLUGIN" "Setting up Fastlane validation reporting..."
    
    export FASTLANE_VALIDATION_REPORTING=true
    export VALIDATION_REPORT_FILE="${BUILD_LOGS_DIR:-$PWD}/validation-report.json"
    export VALIDATION_SUMMARY_FILE="${BUILD_LOGS_DIR:-$PWD}/validation-summary.txt"
}

# Fastlane integration functions
run_fastlane_lane() {
    local lane="$1"
    local platform="${2:-ios}"
    shift 2
    local args=("$@")
    
    log::step "PLUGIN" "Running Fastlane lane: $platform:$lane"
    
    # Check if bundle exec should be used
    local fastlane_cmd="fastlane"
    if command -v bundle >/dev/null 2>&1 && [[ -f "Gemfile" ]]; then
        fastlane_cmd="bundle exec fastlane"
    fi
    
    # Run the lane
    if $fastlane_cmd "$platform" "$lane" "${args[@]}"; then
        log::success "PLUGIN" "Fastlane lane completed: $platform:$lane"
        return $EXIT_SUCCESS
    else
        log::error "PLUGIN" "Fastlane lane failed: $platform:$lane"
        return $EXIT_BUILD_ERROR
    fi
}

get_fastlane_lane_list() {
    local platform="${1:-ios}"
    
    local fastlane_cmd="fastlane"
    if command -v bundle >/dev/null 2>&1 && [[ -f "Gemfile" ]]; then
        fastlane_cmd="bundle exec fastlane"
    fi
    
    $fastlane_cmd lanes | grep "^$platform" | awk '{print $2}' | sort
}

validate_fastlane_setup() {
    log::step "PLUGIN" "Validating Fastlane setup..."
    
    # Check if Fastlane is installed
    if ! command -v fastlane >/dev/null 2>&1; then
        if command -v bundle >/dev/null 2>&1 && bundle exec fastlane version >/dev/null 2>&1; then
            log::success "PLUGIN" "Fastlane available via bundle exec"
        else
            log::error "PLUGIN" "Fastlane not available"
            return $EXIT_COMMAND_NOT_FOUND
        fi
    else
        log::success "PLUGIN" "Fastlane command available"
    fi
    
    # Check if Fastfile exists
    if [[ ! -f "fastlane/Fastfile" ]]; then
        log::error "PLUGIN" "Fastfile not found"
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Check if Appfile exists
    if [[ ! -f "fastlane/Appfile" ]]; then
        log::warn "PLUGIN" "Appfile not found (optional)"
    fi
    
    log::success "PLUGIN" "Fastlane setup validated"
}

# Callback functions
fastlane_lane_started() {
    local lane="$1"
    local platform="$2"
    
    if [[ "$FASTLANE_CALLBACKS_ENABLED" == "true" ]]; then
        log::info "PLUGIN" "🚀 Fastlane lane started: $platform:$lane"
        
        # Record start time
        export FASTLANE_LANE_START_TIME=$(date +%s)
    fi
}

fastlane_lane_completed() {
    local lane="$1"
    local platform="$2"
    local status="$3"
    
    if [[ "$FASTLANE_CALLBACKS_ENABLED" == "true" ]]; then
        local duration=""
        if [[ -n "$FASTLANE_LANE_START_TIME" ]]; then
            local end_time
            end_time=$(date +%s)
            duration=$(format_duration $((end_time - FASTLANE_LANE_START_TIME)))
        fi
        
        if [[ "$status" == "success" ]]; then
            log::success "PLUGIN" "✅ Fastlane lane completed: $platform:$lane ($duration)"
        else
            log::error "PLUGIN" "❌ Fastlane lane failed: $platform:$lane ($duration)"
        fi
    fi
}

fastlane_build_started() {
    local framework="$1"
    
    if [[ "$FASTLANE_BUILD_REPORTING" == "true" ]]; then
        log::info "PLUGIN" "🔨 Build started: $framework"
        
        # Record in build report
        if [[ -n "$BUILD_REPORT_FILE" ]]; then
            echo "Build started for $framework at $(date)" >> "$BUILD_SUMMARY_FILE"
        fi
    fi
}

fastlane_build_completed() {
    local framework="$1"
    local status="$2"
    local duration="$3"
    
    if [[ "$FASTLANE_BUILD_REPORTING" == "true" ]]; then
        if [[ "$status" == "success" ]]; then
            log::success "PLUGIN" "✅ Build completed: $framework ($duration)"
        else
            log::error "PLUGIN" "❌ Build failed: $framework ($duration)"
        fi
        
        # Record in build report
        if [[ -n "$BUILD_REPORT_FILE" ]]; then
            echo "Build $status for $framework at $(date) (Duration: $duration)" >> "$BUILD_SUMMARY_FILE"
        fi
    fi
}

fastlane_test_started() {
    local scheme="$1"
    
    if [[ "$FASTLANE_TEST_REPORTING" == "true" ]]; then
        log::info "PLUGIN" "🧪 Tests started: $scheme"
        
        # Record in test report
        if [[ -n "$TEST_REPORT_FILE" ]]; then
            echo "Tests started for $scheme at $(date)" >> "$TEST_SUMMARY_FILE"
        fi
    fi
}

fastlane_test_completed() {
    local scheme="$1"
    local status="$2"
    local duration="$3"
    
    if [[ "$FASTLANE_TEST_REPORTING" == "true" ]]; then
        if [[ "$status" == "success" ]]; then
            log::success "PLUGIN" "✅ Tests completed: $scheme ($duration)"
        else
            log::error "PLUGIN" "❌ Tests failed: $scheme ($duration)"
        fi
        
        # Record in test report
        if [[ -n "$TEST_REPORT_FILE" ]]; then
            echo "Tests $status for $scheme at $(date) (Duration: $duration)" >> "$TEST_SUMMARY_FILE"
        fi
    fi
}

fastlane_validation_started() {
    local component="$1"
    
    if [[ "$FASTLANE_VALIDATION_REPORTING" == "true" ]]; then
        log::info "PLUGIN" "🔍 Validation started: $component"
        
        # Record in validation report
        if [[ -n "$VALIDATION_REPORT_FILE" ]]; then
            echo "Validation started for $component at $(date)" >> "$VALIDATION_SUMMARY_FILE"
        fi
    fi
}

fastlane_validation_completed() {
    local component="$1"
    local status="$2"
    local duration="$3"
    
    if [[ "$FASTLANE_VALIDATION_REPORTING" == "true" ]]; then
        if [[ "$status" == "success" ]]; then
            log::success "PLUGIN" "✅ Validation completed: $component ($duration)"
        else
            log::error "PLUGIN" "❌ Validation failed: $component ($duration)"
        fi
        
        # Record in validation report
        if [[ -n "$VALIDATION_REPORT_FILE" ]]; then
            echo "Validation $status for $component at $(date) (Duration: $duration)" >> "$VALIDATION_SUMMARY_FILE"
        fi
    fi
}

# Plugin cleanup
plugin_cleanup() {
    if ! is_plugin_active; then
        return $EXIT_SUCCESS
    fi
    
    log::debug "PLUGIN" "Cleaning up Fastlane integration plugin..."
    
    # Generate final reports
    generate_fastlane_reports
    
    # Clean up temporary files
    local temp_files=(
        "$FASTLANE_CACHE_DIR/fastlane.xcconfig"
    )
    
    for temp_file in "${temp_files[@]}"; do
        if [[ -f "$temp_file" ]]; then
            rm -f "$temp_file"
        fi
    done
    
    log::debug "PLUGIN" "Fastlane integration plugin cleanup completed"
}

generate_fastlane_reports() {
    if [[ "$FASTLANE_BUILD_REPORTING" == "true" ]] && [[ -n "$BUILD_REPORT_FILE" ]]; then
        log::debug "PLUGIN" "Generating Fastlane build report..."
        
        # Create JSON build report
        cat > "$BUILD_REPORT_FILE" << EOF
{
    "build_system": "MSP iOS SDK Build System",
    "fastlane_integration": true,
    "lane": "$CURRENT_FASTLANE_LANE",
    "platform": "$CURRENT_FASTLANE_PLATFORM",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "reports_generated": {
        "build_summary": "$(basename "$BUILD_SUMMARY_FILE")",
        "test_summary": "$(basename "$TEST_SUMMARY_FILE")",
        "validation_summary": "$(basename "$VALIDATION_SUMMARY_FILE")"
    }
}
EOF
    fi
}

# Plugin command handlers
handle_plugin_command() {
    local command="$1"
    shift
    
    case "$command" in
        "run-lane")
            run_fastlane_lane "$@"
            ;;
        "list-lanes")
            get_fastlane_lane_list "$@"
            ;;
        "validate-setup")
            validate_fastlane_setup
            ;;
        "generate-reports")
            generate_fastlane_reports
            ;;
        *)
            log::warn "PLUGIN" "Unknown Fastlane plugin command: $command"
            return $EXIT_GENERAL_ERROR
            ;;
    esac
}

# Export plugin functions
export -f is_plugin_active plugin_init plugin_cleanup handle_plugin_command
export -f configure_fastlane_environment setup_fastlane_optimizations setup_lane_integration
export -f run_fastlane_lane get_fastlane_lane_list validate_fastlane_setup
export -f fastlane_lane_started fastlane_lane_completed
export -f fastlane_build_started fastlane_build_completed
export -f fastlane_test_started fastlane_test_completed
export -f fastlane_validation_started fastlane_validation_completed
