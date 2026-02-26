#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

# MSPCore Build Script
# Dedicated script for building MSPCore framework and validating its podspec
# 
# This script is optimized for CI/CD environments and integrates with the
# existing modular script system.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [[ -f "$ROOT_DIR/Scripts/lib/colors.sh" ]]; then
    source "$ROOT_DIR/Scripts/lib/colors.sh"
fi
if [[ -f "$ROOT_DIR/Scripts/lib/ui.sh" ]]; then
    source "$ROOT_DIR/Scripts/lib/ui.sh"
fi

# R012e: Source time_utils.sh for unified duration formatting
if [[ -f "$ROOT_DIR/Scripts/lib/shared/time_utils.sh" ]]; then
    # shellcheck source=Scripts/lib/shared/time_utils.sh
    source "$ROOT_DIR/Scripts/lib/shared/time_utils.sh" 2>/dev/null || true
fi

readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="MSPCore Build Script"

readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_VALIDATION_ERROR=3
readonly EXIT_BUILD_ERROR=4

if command -v log_info &>/dev/null; then
    :
else
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
fi

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

get_project_root() {
    cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

ensure_project_root() {
    local project_root=$(get_project_root)
    if [[ "$(pwd)" != "$project_root" ]]; then
        cd "$project_root"
    fi
}

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

# R012e: Use time_utils.sh format_duration if available, fallback to inline
if ! command -v time_format_duration &>/dev/null; then
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
fi

print_build_summary() {
    local status="$1"
    local duration="$2"
    local details="$3"
    
    print_section "Build Summary"
    
    case "$status" in
        "success")
            log::success "XCFW" "Build completed successfully!"
            ;;
        "failed")
            log::error "XCFW" "Build failed!"
            ;;
        *)
            log::info "XCFW" "Build status: $status"
            ;;
    esac
    
    if [[ -n "$duration" ]]; then
        log::info "XCFW" "⏱️ Build duration: $(format_duration "$duration")"
    fi
    
    if [[ -n "$details" ]]; then
        echo "$details"
    fi
}

MSPCORE_NAME="MSPCore"
MSPCORE_PODSPEC="MSPCore.podspec"
MSPCORE_SCHEME="MSPCore"
MSPCORE_SOURCE_DIR="MSPCore/MSPCore"
MSPCORE_DEPENDENCIES=("MSPSharedLibraries" "PrebidAdapter" "SwiftProtobuf" "MSPSnapKit")

validate_environment() {
    log::step "XCFW" "Validating build environment..."
    
    if [[ ! -f "$MSPCORE_PODSPEC" ]]; then
        log::error "XCFW" "MSPCore.podspec not found. Please run from project root."
        return $EXIT_VALIDATION_ERROR
    fi
    
    if [[ ! -d "msp-ios-sdk.xcworkspace" ]]; then
        log::error "XCFW" "iOS workspace not found. Please run from project root."
        return $EXIT_VALIDATION_ERROR
    fi
    
    if [[ ! -d "$MSPCORE_SOURCE_DIR" ]]; then
        log::error "XCFW" "MSPCore source directory not found: $MSPCORE_SOURCE_DIR"
        return $EXIT_VALIDATION_ERROR
    fi
    
    if ! command -v xcodebuild >/dev/null 2>&1; then
        log::error "XCFW" "Xcode command line tools not found"
        return $EXIT_VALIDATION_ERROR
    fi
    
    if ! command -v pod >/dev/null 2>&1; then
        log::error "XCFW" "CocoaPods not found"
        return $EXIT_VALIDATION_ERROR
    fi
    
    log::success "XCFW" "Environment validation passed"
    return $EXIT_SUCCESS
}

validate_dependencies() {
    log::step "XCFW" "Validating MSPCore dependencies..."
    
    local missing_deps=()
    
    for dep in "${MSPCORE_DEPENDENCIES[@]}"; do
        if [[ ! -d "$dep" ]] && [[ ! -f "${dep}.podspec" ]]; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log::error "XCFW" "Missing dependencies: ${missing_deps[*]}"
        log::info "XCFW" "Please ensure all dependencies are available before building MSPCore"
        return $EXIT_VALIDATION_ERROR
    fi
    
    log::success "XCFW" "All dependencies validated"
    return $EXIT_SUCCESS
}

build_dependencies() {
    log::step "XCFW" "Building MSPCore dependencies..."
    
    if [[ ! -d "MSPSharedLibraries/MSPiOSCore.xcframework" ]]; then
        log::info "XCFW" "Building MSPiOSCore dependency..."
        if [[ -f "Scripts/buildiOSCoreXCFramework.sh" ]]; then
            if ! SKIP_CODE_SIGN="${SKIP_CODE_SIGN:-1}" ./Scripts/buildiOSCoreXCFramework.sh; then
                log::error "XCFW" "Failed to build MSPiOSCore"
                return $EXIT_BUILD_ERROR
            fi
        else
            log::warn "XCFW" "MSPiOSCore build script not found, using unified build script"
            if ! SKIP_CODE_SIGN="${SKIP_CODE_SIGN:-1}" ./Scripts/build.sh --framework MSPiOSCore; then
                log::error "XCFW" "Failed to build MSPiOSCore"
                return $EXIT_BUILD_ERROR
            fi
        fi
    else
        log::info "XCFW" "MSPiOSCore already built"
    fi
    
    if [[ ! -d "NovaAdapter/NovaCore.xcframework" ]]; then
        log::info "XCFW" "Building NovaCore dependency..."
        if [[ -f "Scripts/buildNovaXCFramework.sh" ]]; then
            if ! SKIP_CODE_SIGN="${SKIP_CODE_SIGN:-1}" ./Scripts/buildNovaXCFramework.sh; then
                log::error "XCFW" "Failed to build NovaCore"
                return $EXIT_BUILD_ERROR
            fi
        else
            log::warn "XCFW" "NovaCore build script not found, using unified build script"
            if ! SKIP_CODE_SIGN="${SKIP_CODE_SIGN:-1}" ./Scripts/build.sh --framework NovaCore; then
                log::error "XCFW" "Failed to build NovaCore"
                return $EXIT_BUILD_ERROR
            fi
        fi
    else
        log::info "XCFW" "NovaCore already built"
    fi
    
    log::success "XCFW" "Dependencies built successfully"
    return $EXIT_SUCCESS
}

validate_podspec() {
    log::step "XCFW" "Validating MSPCore podspec..."
    
    if [[ ! -f "$MSPCORE_PODSPEC" ]]; then
        log::error "XCFW" "MSPCore.podspec not found"
        return $EXIT_VALIDATION_ERROR
    fi
    
    if bundle exec pod spec lint "$MSPCORE_PODSPEC" --allow-warnings; then
        log::success "XCFW" "MSPCore podspec validation passed"
        return $EXIT_SUCCESS
    else
        log::error "XCFW" "MSPCore podspec validation failed"
        return $EXIT_VALIDATION_ERROR
    fi
}

build_mspcore() {
    log::step "XCFW" "Building MSPCore framework..."
    
    # MSPCore is a source-only framework, so we mainly validate the build
    # by ensuring the project compiles correctly
    
    if [[ "${CLEAN_BUILD:-false}" == "true" ]]; then
        log::info "XCFW" "Cleaning build artifacts..."
        if ! xcodebuild clean -workspace msp-ios-sdk.xcworkspace -scheme "$MSPCORE_SCHEME" -quiet; then
            log::error "XCFW" "Failed to clean MSPCore"
            return $EXIT_BUILD_ERROR
        fi
    fi
    
    log::info "XCFW" "Building MSPCore scheme..."
    if ! xcodebuild build -workspace msp-ios-sdk.xcworkspace -scheme "$MSPCORE_SCHEME" -configuration Release -derivedDataPath DerivedData -quiet; then
        log::error "XCFW" "Failed to build MSPCore"
        return $EXIT_BUILD_ERROR
    fi
    
    log::success "XCFW" "MSPCore build completed"
    return $EXIT_SUCCESS
}

test_mspcore() {
    log::step "XCFW" "Testing MSPCore..."
    
    if xcodebuild -list -workspace msp-ios-sdk.xcworkspace | grep -q "MSPCoreTests"; then
        log::info "XCFW" "Running MSPCore tests..."
        if ! xcodebuild test -workspace msp-ios-sdk.xcworkspace -scheme "$MSPCORE_SCHEME" -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -derivedDataPath DerivedData -quiet; then
            log::error "XCFW" "MSPCore tests failed"
            return $EXIT_BUILD_ERROR
        fi
        log::success "XCFW" "MSPCore tests passed"
    else
        log::info "XCFW" "No test scheme found for MSPCore, skipping tests"
    fi
    
    return $EXIT_SUCCESS
}

clean_build_artifacts() {
    log::step "XCFW" "Cleaning build artifacts..."
    
    local artifacts=(
        "DerivedData"
        "build"
        "*.log"
    )
    
    for artifact in "${artifacts[@]}"; do
        if [[ -e "$artifact" ]]; then
            rm -rf "$artifact"
            log::info "XCFW" "Removed: $artifact"
        fi
    done
    
    log::success "XCFW" "Build artifacts cleaned"
    return $EXIT_SUCCESS
}

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
    - MSPSnapKit

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

main() {
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
                log::error "XCFW" "Unknown option: $1"
                show_help
                exit $EXIT_GENERAL_ERROR
                ;;
            *)
                log::error "XCFW" "Unexpected argument: $1"
                show_help
                exit $EXIT_GENERAL_ERROR
                ;;
        esac
    done
    
    print_section "MSPCore Build System"
    log::info "XCFW" "Version: $SCRIPT_VERSION"
    log::info "XCFW" "Framework: $MSPCORE_NAME"
    log::info "XCFW" "Podspec: $MSPCORE_PODSPEC"
    
    start_timer

    if ! validate_environment; then
        exit $EXIT_VALIDATION_ERROR
    fi
    
    if [[ "$clean_mode" == "true" ]]; then
        clean_build_artifacts
    fi
    
    if [[ "$skip_deps" != "true" ]]; then
        if ! validate_dependencies; then
            exit $EXIT_VALIDATION_ERROR
        fi
    fi
    
    if [[ "$skip_deps" != "true" ]]; then
        if ! build_dependencies; then
            log::error "XCFW" "Failed to build dependencies"
            exit $EXIT_BUILD_ERROR
        fi
    fi
    
    if [[ "$skip_validation" != "true" ]]; then
        if ! validate_podspec; then
            log::error "XCFW" "Podspec validation failed"
            exit $EXIT_VALIDATION_ERROR
        fi
    fi
    
    if ! build_mspcore; then
        log::error "XCFW" "Failed to build MSPCore"
        exit $EXIT_BUILD_ERROR
    fi
    
    if [[ "$skip_tests" != "true" ]]; then
        if ! test_mspcore; then
            log::error "XCFW" "Tests failed"
            exit $EXIT_BUILD_ERROR
        fi
    fi
    
    local duration=$(end_timer)

    print_build_summary "success" "$duration" "MSPCore build completed successfully!"
    log::info "XCFW" "Framework: $MSPCORE_NAME"
    log::info "XCFW" "Podspec: $MSPCORE_PODSPEC"
    log::info "XCFW" "Source Directory: $MSPCORE_SOURCE_DIR"
    
    exit $EXIT_SUCCESS
}

main "$@"
