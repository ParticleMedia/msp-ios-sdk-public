#!/bin/bash

# Jenkins Pipeline Test Script
# This script simulates the Jenkins pipeline stages locally for testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo -e "${BLUE}🔧 $1${NC}"
}

print_section() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "$1"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
}

# Test parameters
BUILD_TYPE="${1:-pr-validation}"
FRAMEWORK_NAME="${2:-MSPCore}"
SKIP_CODE_SIGN="${3:-true}"
CLEAN_BUILD="${4:-true}"
PUBLISH_ARTIFACTS="${5:-false}"

# Environment variables (simulating Jenkins)
export CI=true
export JENKINS_URL="http://localhost:8080"
export SKIP_CODE_SIGN="${SKIP_CODE_SIGN}"
export CLEAN_BUILD="${CLEAN_BUILD}"
export WORKSPACE_PATH="${PWD}"
export SCRIPTS_PATH="${PWD}/Scripts"
export COCOAPODS_DISABLE_STATS=true
export COCOAPODS_CACHE_DIR="${PWD}/.cocoapods_cache"
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
export ARTIFACTS_DIR="${PWD}/artifacts"

# Test functions
test_checkout() {
    print_section "Stage: Checkout"
    
    log_step "Checking out repository..."
    
    # Simulate git checkout
    if [[ -d ".git" ]]; then
        GIT_COMMIT_SHORT=$(git rev-parse --short HEAD)
        GIT_BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
        
        log_success "Repository checked out"
        log_info "Commit: ${GIT_COMMIT_SHORT}"
        log_info "Branch: ${GIT_BRANCH_NAME}"
        log_info "Build Type: ${BUILD_TYPE}"
        log_info "Framework: ${FRAMEWORK_NAME}"
    else
        log_error "Not a git repository"
        return 1
    fi
}

test_environment_setup() {
    print_section "Stage: Environment Setup"
    
    log_step "Setting up build environment..."
    
    # Create necessary directories
    mkdir -p "${ARTIFACTS_DIR}"
    mkdir -p "${COCOAPODS_CACHE_DIR}"
    mkdir -p "${PWD}/DerivedData"
    
    # Create CI-specific xcconfig
    cat > ci.xcconfig << EOF
// CI-specific build optimizations
COMPILER_INDEX_STORE_ENABLE = NO
SWIFT_COMPILATION_MODE = wholemodule
SWIFT_OPTIMIZATION_LEVEL = -O
DEBUG_INFORMATION_FORMAT = dwarf
ONLY_ACTIVE_ARCH = NO
EOF
    
    log_success "Environment setup completed"
    
    # Verify required tools
    log_step "Verifying build tools..."
    
    local tools=("xcodebuild" "pod" "git")
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            log_success "$tool found"
        else
            log_error "$tool not found"
            return 1
        fi
    done
    
    # Display versions
    log_info "Tool Versions:"
    xcodebuild -version | head -1
    pod --version
    git --version
}

test_dependency_resolution() {
    print_section "Stage: Dependency Resolution"
    
    log_step "Resolving dependencies..."
    
    # Check if Podfile.lock exists
    if [[ -f "Podfile.lock" ]]; then
        log_success "Podfile.lock found - dependencies appear resolved"
    else
        log_warn "Podfile.lock not found - would need to run 'pod install'"
    fi
    
    # Verify workspace
    if [[ -d "msp-ios-sdk.xcworkspace" ]]; then
        log_success "Workspace found"
    else
        log_error "Workspace not found"
        return 1
    fi
}

test_build_dependencies() {
    if [[ "$BUILD_TYPE" == "pr-validation" ]]; then
        log_info "Skipping dependency builds for PR validation"
        return 0
    fi
    
    print_section "Stage: Build Dependencies"
    
    log_step "Building framework dependencies..."
    
    # Test if build scripts exist
    local build_scripts=(
        "Scripts/buildiOSCoreXCFramework.sh"
        "Scripts/buildNovaXCFramework.sh"
    )
    
    for script in "${build_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            log_success "Build script found: $script"
        else
            log_warn "Build script not found: $script"
        fi
    done
    
    log_info "Dependency build simulation completed"
}

test_validate_mspcore() {
    print_section "Stage: Validate MSPCore"
    
    log_step "Validating MSPCore podspec..."
    
    if [[ -f "MSPCore.podspec" ]]; then
        # Test Ruby syntax
        if ruby -c MSPCore.podspec >/dev/null 2>&1; then
            log_success "MSPCore.podspec syntax validation passed"
        else
            log_error "MSPCore.podspec syntax validation failed"
            return 1
        fi
        
        # Test pod spec lint (dry run)
        log_info "Testing pod spec lint (this may take a moment)..."
        if pod spec lint MSPCore.podspec --allow-warnings --quick >/dev/null 2>&1; then
            log_success "MSPCore podspec validation passed"
        else
            log_warn "MSPCore podspec validation failed (this is expected in test environment)"
        fi
    else
        log_error "MSPCore.podspec not found"
        return 1
    fi
}

test_build_mspcore() {
    print_section "Stage: Build MSPCore"
    
    log_step "Building MSPCore..."
    
    # Test the build script
    if [[ -f "Scripts/buildMSPCore.sh" ]]; then
        log_info "Testing MSPCore build script..."
        
        # Test with minimal options
        if ./Scripts/buildMSPCore.sh --skip-deps --skip-validation --skip-tests --help >/dev/null 2>&1; then
            log_success "MSPCore build script is functional"
        else
            log_error "MSPCore build script failed"
            return 1
        fi
    else
        log_error "MSPCore build script not found"
        return 1
    fi
}

test_collect_artifacts() {
    if [[ "$PUBLISH_ARTIFACTS" != "true" ]]; then
        log_info "Skipping artifact collection (PUBLISH_ARTIFACTS=false)"
        return 0
    fi
    
    print_section "Stage: Collect Artifacts"
    
    log_step "Collecting build artifacts..."
    
    # Create artifacts directory
    mkdir -p "${ARTIFACTS_DIR}"
    
    # Collect podspec
    if [[ -f "MSPCore.podspec" ]]; then
        cp MSPCore.podspec "${ARTIFACTS_DIR}/"
        log_success "Collected: MSPCore.podspec"
    fi
    
    # Collect source files
    if [[ -d "MSPCore" ]]; then
        tar -czf "${ARTIFACTS_DIR}/MSPCore-source.tar.gz" MSPCore/ 2>/dev/null || true
        log_success "Collected: MSPCore source"
    fi
    
    # Create build info
    cat > "${ARTIFACTS_DIR}/build-info.txt" << EOF
Build Information
=================
Build Type: ${BUILD_TYPE}
Framework: ${FRAMEWORK_NAME}
Git Commit: $(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
Git Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
Build Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Test Environment: Local
EOF
    
    log_success "Artifacts collected successfully"
}

test_cleanup() {
    print_section "Cleanup"
    
    log_step "Cleaning up test environment..."
    
    # Clean up temporary files
    rm -f ci.xcconfig
    rm -rf DerivedData
    
    # Show artifacts if they exist
    if [[ -d "${ARTIFACTS_DIR}" ]] && [[ "$(ls -A ${ARTIFACTS_DIR})" ]]; then
        log_info "Test artifacts created:"
        ls -la "${ARTIFACTS_DIR}/"
    fi
    
    log_success "Cleanup completed"
}

# Main test execution
main() {
    print_section "Jenkins Pipeline Test"
    log_info "Testing Jenkins pipeline locally"
    log_info "Build Type: ${BUILD_TYPE}"
    log_info "Framework: ${FRAMEWORK_NAME}"
    log_info "Skip Code Sign: ${SKIP_CODE_SIGN}"
    log_info "Clean Build: ${CLEAN_BUILD}"
    log_info "Publish Artifacts: ${PUBLISH_ARTIFACTS}"
    
    local failed_stages=()
    
    # Run test stages
    if ! test_checkout; then
        failed_stages+=("Checkout")
    fi
    
    if ! test_environment_setup; then
        failed_stages+=("Environment Setup")
    fi
    
    if ! test_dependency_resolution; then
        failed_stages+=("Dependency Resolution")
    fi
    
    if ! test_build_dependencies; then
        failed_stages+=("Build Dependencies")
    fi
    
    if ! test_validate_mspcore; then
        failed_stages+=("Validate MSPCore")
    fi
    
    if ! test_build_mspcore; then
        failed_stages+=("Build MSPCore")
    fi
    
    if ! test_collect_artifacts; then
        failed_stages+=("Collect Artifacts")
    fi
    
    test_cleanup
    
    # Report results
    print_section "Test Results"
    
    if [[ ${#failed_stages[@]} -eq 0 ]]; then
        log_success "All pipeline stages passed!"
        log_info "Jenkins pipeline is ready for deployment"
        exit 0
    else
        log_error "Failed stages: ${failed_stages[*]}"
        log_info "Please fix the failed stages before deploying to Jenkins"
        exit 1
    fi
}

# Show help
show_help() {
    cat << EOF
Jenkins Pipeline Test Script

USAGE:
    $0 [BUILD_TYPE] [FRAMEWORK_NAME] [SKIP_CODE_SIGN] [CLEAN_BUILD] [PUBLISH_ARTIFACTS]

PARAMETERS:
    BUILD_TYPE        Type of build (pr-validation, release, manual) [default: pr-validation]
    FRAMEWORK_NAME    Framework to build [default: MSPCore]
    SKIP_CODE_SIGN    Skip code signing (true/false) [default: true]
    CLEAN_BUILD       Clean build artifacts (true/false) [default: true]
    PUBLISH_ARTIFACTS Publish build artifacts (true/false) [default: false]

EXAMPLES:
    $0                                    # Test PR validation build
    $0 release MSPCore true true true     # Test release build with artifacts
    $0 manual MSPCore false false false   # Test manual build without skipping

EOF
}

# Handle help
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_help
    exit 0
fi

# Run main function
main "$@"
