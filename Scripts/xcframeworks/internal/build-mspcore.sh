#!/bin/bash

# MSPCore Build Script
# Dedicated script for building MSPCore framework and validating its podspec
# 
# This script is optimized for CI/CD environments and integrates with the
# existing modular script system.

# Source library modules (with error handling)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source only essential library functions to avoid conflicts
if [[ -f "$ROOT_DIR/Scripts/lib/colors.sh" ]]; then
    source "$ROOT_DIR/Scripts/lib/colors.sh"
fi

# Script metadata
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="MSPCore Build Script"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_VALIDATION_ERROR=3
readonly EXIT_BUILD_ERROR=4

# Enhanced logging functions using library colors
log_info() {
    if [[ -n "${BLUE:-}" ]]; then
        echo -e "${BLUE}ℹ️  $1${NC}"
    else
        echo "INFO: $1"
    fi
}

log_success() {
    if [[ -n "${GREEN:-}" ]]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo "SUCCESS: $1"
    fi
}

log_warn() {
    if [[ -n "${YELLOW:-}" ]]; then
        echo -e "${YELLOW}⚠️  $1${NC}"
    else
        echo "WARNING: $1"
    fi
}

log_error() {
    if [[ -n "${RED:-}" ]]; then
        echo -e "${RED}❌ $1${NC}" >&2
    else
        echo "ERROR: $1" >&2
    fi
}

log_step() {
    if [[ -n "${BLUE:-}" ]]; then
        echo -e "${BLUE}🔧 $1${NC}"
    else
        echo "STEP: $1"
    fi
}

print_section() {
    echo ""
    if [[ -n "${PURPLE:-}" ]]; then
        echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════${NC}"
        echo -e "${PURPLE}$1${NC}"
        echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════${NC}"
    else
        echo "═══════════════════════════════════════════════════════════════════"
        echo "$1"
        echo "═══════════════════════════════════════════════════════════════════"
    fi
    echo ""
}

# Utility functions
get_project_root() {
    cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

ensure_project_root() {
    local project_root=$(get_project_root)
    if [[ "$(pwd)" != "$project_root" ]]; then
        cd "$project_root"
    fi
}

# Timing functions
start_timer() {
    TIMER_START=$(date +%s)
}

end_timer() {
    if [[ -n "${TIMER_START}" ]]; then
        local end_time=$(date +%s)
        local duration=$((end_time - TIMER_START))
        echo $duration
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
        log_info "⏱️ Build duration: $(format_duration "$duration")"
    fi
    
    if [[ -n "$details" ]]; then
        echo "$details"
    fi
}

# MSPCore specific configuration
MSPCORE_NAME="MSPCore"
MSPCORE_PODSPEC="MSPCore.podspec"
MSPCORE_SCHEME="MSPCore"
MSPCORE_SOURCE_DIR="MSPCore/MSPCore"
MSPCORE_DEPENDENCIES=("MSPSharedLibraries" "PrebidAdapter" "SwiftProtobuf" "SnapKit")

# Validation functions
validate_environment() {
    log_step "Validating build environment..."
    
    # Check if we're in the project root
    if [[ ! -f "$MSPCORE_PODSPEC" ]]; then
        log_error "MSPCore.podspec not found. Please run from project root."
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Check if workspace exists
    if [[ ! -d "msp-ios-sdk.xcworkspace" ]]; then
        log_error "iOS workspace not found. Please run from project root."
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Check MSPCore source directory
    if [[ ! -d "$MSPCORE_SOURCE_DIR" ]]; then
        log_error "MSPCore source directory not found: $MSPCORE_SOURCE_DIR"
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Check required tools
    if ! command -v xcodebuild >/dev/null 2>&1; then
        log_error "Xcode command line tools not found"
        return $EXIT_VALIDATION_ERROR
    fi
    
    if ! command -v pod >/dev/null 2>&1; then
        log_error "CocoaPods not found"
        return $EXIT_VALIDATION_ERROR
    fi
    
    log_success "Environment validation passed"
    return $EXIT_SUCCESS
}

validate_dependencies() {
    log_step "Validating MSPCore dependencies..."
    
    local missing_deps=()
    
    for dep in "${MSPCORE_DEPENDENCIES[@]}"; do
        if [[ ! -d "$dep" ]] && [[ ! -f "${dep}.podspec" ]]; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Please ensure all dependencies are available before building MSPCore"
        return $EXIT_VALIDATION_ERROR
    fi
    
    log_success "All dependencies validated"
    return $EXIT_SUCCESS
}

# Build functions
build_dependencies() {
    log_step "Building MSPCore dependencies..."
    
    # Build MSPiOSCore if needed
    if [[ ! -d "MSPSharedLibraries/MSPiOSCore.xcframework" ]]; then
        log_info "Building MSPiOSCore dependency..."
        if [[ -f "Scripts/buildiOSCoreXCFramework.sh" ]]; then
            if ! SKIP_CODE_SIGN="${SKIP_CODE_SIGN:-1}" ./Scripts/buildiOSCoreXCFramework.sh; then
                log_error "Failed to build MSPiOSCore"
                return $EXIT_BUILD_ERROR
            fi
        else
            log_warn "MSPiOSCore build script not found, using unified build script"
            if ! SKIP_CODE_SIGN="${SKIP_CODE_SIGN:-1}" ./Scripts/build.sh --framework MSPiOSCore; then
                log_error "Failed to build MSPiOSCore"
                return $EXIT_BUILD_ERROR
            fi
        fi
    else
        log_info "MSPiOSCore already built"
    fi
    
    # Build NovaCore if needed
    if [[ ! -d "NovaAdapter/NovaCore.xcframework" ]]; then
        log_info "Building NovaCore dependency..."
        if [[ -f "Scripts/buildNovaXCFramework.sh" ]]; then
            if ! SKIP_CODE_SIGN="${SKIP_CODE_SIGN:-1}" ./Scripts/buildNovaXCFramework.sh; then
                log_error "Failed to build NovaCore"
                return $EXIT_BUILD_ERROR
            fi
        else
            log_warn "NovaCore build script not found, using unified build script"
            if ! SKIP_CODE_SIGN="${SKIP_CODE_SIGN:-1}" ./Scripts/build.sh --framework NovaCore; then
                log_error "Failed to build NovaCore"
                return $EXIT_BUILD_ERROR
            fi
        fi
    else
        log_info "NovaCore already built"
    fi
    
    log_success "Dependencies built successfully"
    return $EXIT_SUCCESS
}

validate_podspec() {
    log_step "Validating MSPCore podspec..."
    
    if [[ ! -f "$MSPCORE_PODSPEC" ]]; then
        log_error "MSPCore.podspec not found"
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Validate podspec
    if bundle exec pod spec lint "$MSPCORE_PODSPEC" --allow-warnings; then
        log_success "MSPCore podspec validation passed"
        return $EXIT_SUCCESS
    else
        log_error "MSPCore podspec validation failed"
        return $EXIT_VALIDATION_ERROR
    fi
}

build_mspcore() {
    log_step "Building MSPCore framework..."
    
    # MSPCore is a source-only framework, so we mainly validate the build
    # by ensuring the project compiles correctly
    
    # Clean build if requested
    if [[ "${CLEAN_BUILD:-false}" == "true" ]]; then
        log_info "Cleaning build artifacts..."
        if ! xcodebuild clean -workspace msp-ios-sdk.xcworkspace -scheme "$MSPCORE_SCHEME" -quiet; then
            log_error "Failed to clean MSPCore"
            return $EXIT_BUILD_ERROR
        fi
    fi
    
    # Build the framework
    log_info "Building MSPCore scheme..."
    if ! xcodebuild build -workspace msp-ios-sdk.xcworkspace -scheme "$MSPCORE_SCHEME" -configuration Release -derivedDataPath DerivedData -quiet; then
        log_error "Failed to build MSPCore"
        return $EXIT_BUILD_ERROR
    fi
    
    log_success "MSPCore build completed"
    return $EXIT_SUCCESS
}

test_mspcore() {
    log_step "Testing MSPCore..."
    
    # Run tests if test scheme exists
    if xcodebuild -list -workspace msp-ios-sdk.xcworkspace | grep -q "MSPCoreTests"; then
        log_info "Running MSPCore tests..."
        if ! xcodebuild test -workspace msp-ios-sdk.xcworkspace -scheme "$MSPCORE_SCHEME" -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -derivedDataPath DerivedData -quiet; then
            log_error "MSPCore tests failed"
            return $EXIT_BUILD_ERROR
        fi
        log_success "MSPCore tests passed"
    else
        log_info "No test scheme found for MSPCore, skipping tests"
    fi
    
    return $EXIT_SUCCESS
}

# Cleanup functions
clean_build_artifacts() {
    log_step "Cleaning build artifacts..."
    
    local artifacts=(
        "DerivedData"
        "build"
        "*.log"
    )
    
    for artifact in "${artifacts[@]}"; do
        if [[ -e "$artifact" ]]; then
            rm -rf "$artifact"
            log_info "Removed: $artifact"
        fi
    done
    
    log_success "Build artifacts cleaned"
    return $EXIT_SUCCESS
}

# Show help
show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

Dedicated build script for MSPCore framework.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --help, -h              Show this help message
    --version, -v           Show version information
    --clean                 Clean build artifacts before building
    --skip-deps             Skip building dependencies
    --skip-validation       Skip podspec validation
    --skip-tests            Skip running tests
    --verbose               Enable verbose output
    --skip-code-sign        Skip code signing (development mode)

EXAMPLES:
    $0                      # Build MSPCore with all validations
    $0 --clean              # Clean and build MSPCore
    $0 --skip-deps          # Build MSPCore without building dependencies
    $0 --skip-validation    # Build without podspec validation

NOTES:
    MSPCore is a source-only framework that depends on:
    - MSPSharedLibraries (MSPiOSCore.xcframework)
    - PrebidAdapter
    - SwiftProtobuf
    - SnapKit

EOF
}

show_version() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

MSPCore Build System:
- Source-only framework build
- Dependency management
- Podspec validation
- Test execution
- CI/CD integration

EOF
}

# Main execution
main() {
    # Parse arguments
    local clean_mode=false
    local skip_deps=false
    local skip_validation=false
    local skip_tests=false
    local verbose_mode=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit $EXIT_SUCCESS
                ;;
            --version|-v)
                show_version
                exit $EXIT_SUCCESS
                ;;
            --clean)
                clean_mode=true
                shift
                ;;
            --skip-deps)
                skip_deps=true
                shift
                ;;
            --skip-validation)
                skip_validation=true
                shift
                ;;
            --skip-tests)
                skip_tests=true
                shift
                ;;
            --verbose)
                verbose_mode=true
                set -x
                shift
                ;;
            --skip-code-sign)
                export SKIP_CODE_SIGN=1
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit $EXIT_GENERAL_ERROR
                ;;
            *)
                log_error "Unexpected argument: $1"
                show_help
                exit $EXIT_GENERAL_ERROR
                ;;
        esac
    done
    
    print_section "MSPCore Build System"
    log_info "Version: $SCRIPT_VERSION"
    log_info "Framework: $MSPCORE_NAME"
    log_info "Podspec: $MSPCORE_PODSPEC"
    
    # Start timing
    start_timer
    
    # Validate environment
    if ! validate_environment; then
        exit $EXIT_VALIDATION_ERROR
    fi
    
    # Clean if requested
    if [[ "$clean_mode" == "true" ]]; then
        clean_build_artifacts
    fi
    
    # Validate dependencies if not skipped
    if [[ "$skip_deps" != "true" ]]; then
        if ! validate_dependencies; then
            exit $EXIT_VALIDATION_ERROR
        fi
    fi
    
    # Build dependencies if not skipped
    if [[ "$skip_deps" != "true" ]]; then
        if ! build_dependencies; then
            log_error "Failed to build dependencies"
            exit $EXIT_BUILD_ERROR
        fi
    fi
    
    # Validate podspec if not skipped
    if [[ "$skip_validation" != "true" ]]; then
        if ! validate_podspec; then
            log_error "Podspec validation failed"
            exit $EXIT_VALIDATION_ERROR
        fi
    fi
    
    # Build MSPCore
    if ! build_mspcore; then
        log_error "Failed to build MSPCore"
        exit $EXIT_BUILD_ERROR
    fi
    
    # Run tests if not skipped
    if [[ "$skip_tests" != "true" ]]; then
        if ! test_mspcore; then
            log_error "Tests failed"
            exit $EXIT_BUILD_ERROR
        fi
    fi
    
    # Calculate build duration
    local duration=$(end_timer)
    
    # Report success
    print_build_summary "success" "$duration" "MSPCore build completed successfully!"
    log_info "Framework: $MSPCORE_NAME"
    log_info "Podspec: $MSPCORE_PODSPEC"
    log_info "Source Directory: $MSPCORE_SOURCE_DIR"
    
    exit $EXIT_SUCCESS
}

# Execute main function
main "$@"
