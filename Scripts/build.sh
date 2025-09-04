#!/bin/bash

# MSP iOS SDK Unified Build Script v2.0.0
# Simplified version compatible with Bash 3.2

set -e

# Script metadata
SCRIPT_VERSION="2.0.0"
SCRIPT_NAME="MSP iOS SDK Build System"

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

# Framework configurations (simplified)
MSPIOSSCORE_CONFIG="name=MSPiOSCore;scheme=MSPiOSCore;output_dir=outputMSPiOSCore;deploy_dir=MSPSharedLibraries;xcframework_name=MSPiOSCore.xcframework;source_only=false"
NOVACORE_CONFIG="name=NovaCore;scheme=NovaCore;output_dir=outputNova;deploy_dir=NovaAdapter;xcframework_name=NovaCore.xcframework;source_only=false"

# Parse config value
parse_config_value() {
    local config_string="$1"
    local key="$2"
    echo "$config_string" | grep -o "$key=[^;]*" | cut -d'=' -f2
}

# Load framework config
load_framework_config() {
    local framework_name="$1"
    local config_var=""
    
    # Convert to uppercase for config variable name (Bash 3.2 compatible)
    case "$framework_name" in
        "MSPiOSCore")
            config_var="MSPIOSSCORE_CONFIG"
            ;;
        "NovaCore")
            config_var="NOVACORE_CONFIG"
            ;;
        "MSPCore")
            config_var="MSPCORE_CONFIG"
            ;;
        *)
            log_error "Unknown framework: $framework_name"
            return 1
            ;;
    esac
    
    local config_value="${!config_var}"
    
    if [[ -z "$config_value" ]]; then
        log_error "Configuration not found for framework: $framework_name"
        return 1
    fi
    
    FRAMEWORK_NAME=$(parse_config_value "$config_value" "name")
    FRAMEWORK_SCHEME=$(parse_config_value "$config_value" "scheme")
    FRAMEWORK_OUTPUT_DIR=$(parse_config_value "$config_value" "output_dir")
    FRAMEWORK_DEPLOY_DIR=$(parse_config_value "$config_value" "deploy_dir")
    FRAMEWORK_XCFRAMEWORK_NAME=$(parse_config_value "$config_value" "xcframework_name")
    FRAMEWORK_SOURCE_ONLY=$(parse_config_value "$config_value" "source_only")
    
    return 0
}

# Build framework
build_framework() {
    local framework_name="$1"
    
    log_step "Building framework: $framework_name"
    
    if ! load_framework_config "$framework_name"; then
        return 1
    fi
    
    if [[ "$FRAMEWORK_SOURCE_ONLY" == "true" ]]; then
        log_info "Framework $framework_name is source-only, skipping build"
        return 0
    fi
    
    case "$framework_name" in
        "MSPiOSCore")
            # Use shared library directly
            if [[ -f "Scripts/lib/xcframework_builder.sh" ]]; then
                source "Scripts/lib/xcframework_builder.sh"
                SKIP_CODE_SIGN="${SKIP_CODE_SIGN:-1}" build_xcframework \
                    "MSPiOSCore" \
                    "MSPiOSCore" \
                    "MSPiOSCore/MSPiOSCore" \
                    "outputMSPiOSCore/xcframework" \
                    "MSPSharedLibraries" \
                    "MSPiOSCore.xcframework"
                return $?
            else
                log_error "XCFramework builder library not found: Scripts/lib/xcframework_builder.sh"
                return 1
            fi
            ;;
        "NovaCore")
            # NovaCore has CocoaPods dependencies, use individual build script
            if [[ -f "Scripts/buildNovaXCFramework.sh" ]]; then
                log_info "Building NovaCore using individual build script (CocoaPods dependencies)"
                SKIP_CODE_SIGN="${SKIP_CODE_SIGN:-1}" ./Scripts/buildNovaXCFramework.sh
                return $?
            else
                log_error "NovaCore build script not found: Scripts/buildNovaXCFramework.sh"
                return 1
            fi
            ;;
        *)
            log_info "Framework $framework_name build not implemented yet"
            return 0
            ;;
    esac
}

# Show help
show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

Unified build script for MSP iOS SDK frameworks.

USAGE:
    $0 [OPTIONS] [FRAMEWORK_NAME]

OPTIONS:
    --help, -h              Show this help message
    --version, -v           Show version information
    --framework, -f NAME    Build specific framework
    --frameworks LIST       Build multiple frameworks (comma-separated)
    --clean                 Clean build artifacts before building (default: enabled)
    --clean-all             Clean all build artifacts
    --status                Show build status
    --info                  Show project information
    --verbose               Enable verbose output
    --skip-code-sign        Skip code signing (development mode)
    --dry-run               Show what would be built without executing

FRAMEWORK NAMES:
    MSPiOSCore              MSP iOS Core framework
    NovaCore                Nova Core framework
    all                     Build all frameworks

EXAMPLES:
    $0 MSPiOSCore
    $0 --frameworks MSPiOSCore,NovaCore
    $0 --clean MSPiOSCore
    $0 --status
    $0 --dry-run all

NOTES:
    Clean mode is enabled by default to ensure fresh builds.
    Use --clean explicitly if you want to ensure cleaning.

EOF
}

show_version() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

Build System Architecture:
- Simplified modular system compatible with Bash 3.2
- Environment-aware configuration
- Integration with existing build scripts

Framework Support:
- MSPiOSCore (XCFramework)
- NovaCore (XCFramework)

EOF
}

# Show build status
show_build_status() {
    print_section "Build Status"
    
    local frameworks="MSPiOSCore NovaCore"
    local built_count=0
    local total_count=0
    
    for framework in $frameworks; do
        total_count=$((total_count + 1))
        
        if load_framework_config "$framework" 2>/dev/null; then
            local xcframework_name="$FRAMEWORK_XCFRAMEWORK_NAME"
            local deploy_dir="$FRAMEWORK_DEPLOY_DIR"
            
            if [[ -n "$xcframework_name" ]] && [[ -n "$deploy_dir" ]]; then
                local framework_path="$deploy_dir/$xcframework_name"
                if [[ -d "$framework_path" ]]; then
                    built_count=$((built_count + 1))
                    log_success "$framework: Built ($framework_path)"
                else
                    log_error "$framework: Not built"
                fi
            fi
        fi
    done
    
    echo ""
    log_info "Summary: $built_count/$total_count frameworks built"
}

# Show project info
show_project_info() {
    print_section "Project Information"
    
    log_info "Project: MSP iOS SDK"
    log_info "Version: $SCRIPT_VERSION"
    log_info "Build System: Simplified Modular Architecture v2.0"
    
    echo ""
    log_info "Available Frameworks:"
    log_info "  📦 MSPiOSCore (XCFramework)"
    log_info "  📦 NovaCore (XCFramework)"
    
    echo ""
    log_info "Build Scripts:"
    if [[ -f "Scripts/buildiOSCoreXCFramework.sh" ]]; then
        log_success "  ✅ MSPiOSCore build script"
    else
        log_error "  ❌ MSPiOSCore build script missing"
    fi
    
    if [[ -f "Scripts/buildNovaXCFramework.sh" ]]; then
        log_success "  ✅ NovaCore build script"
    else
        log_error "  ❌ NovaCore build script missing"
    fi
}

# Clean functions
clean_build_artifacts() {
    log_step "Cleaning build artifacts..."
    
    local output_dirs="outputMSPiOSCore outputNova DerivedData"
    
    for dir in $output_dirs; do
        if [[ -d "$dir" ]]; then
            rm -rf "$dir"
            log_info "Removed: $dir"
        fi
    done
    
    log_success "Build artifacts cleaned"
}

clean_all_artifacts() {
    log_step "Cleaning all artifacts..."
    
    clean_build_artifacts
    
    if [[ -d "Pods" ]]; then
        rm -rf "Pods"
        log_info "Removed: Pods"
    fi
    
    if [[ -f "Podfile.lock" ]]; then
        rm -f "Podfile.lock"
        log_info "Removed: Podfile.lock"
    fi
    
    log_success "All artifacts cleaned"
}

# Validation
validate_environment() {
    log_step "Validating environment..."
    
    if [[ ! -d "msp-ios-sdk.xcworkspace" ]]; then
        log_error "iOS workspace not found. Please run from project root."
        return 1
    fi
    
    if ! command -v xcodebuild >/dev/null 2>&1; then
        log_error "Xcode command line tools not found"
        return 1
    fi
    
    log_success "Environment validation passed"
    return 0
}

# Main execution
main() {
    # Ensure we're in the project root
    ensure_project_root
    
    # Parse arguments
    local framework_name=""
    local frameworks_list=""
    local clean_mode=true
    local clean_all_mode=false
    local status_mode=false
    local info_mode=false
    local dry_run_mode=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                show_version
                exit 0
                ;;
            --framework|-f)
                framework_name="$2"
                shift 2
                ;;
            --frameworks)
                frameworks_list="$2"
                shift 2
                ;;
            --clean)
                clean_mode=true
                shift
                ;;
            --clean-all)
                clean_all_mode=true
                shift
                ;;
            --status)
                status_mode=true
                shift
                ;;
            --info)
                info_mode=true
                shift
                ;;
            --verbose)
                set -x
                shift
                ;;
            --skip-code-sign)
                export SKIP_CODE_SIGN=1
                shift
                ;;
            --dry-run)
                dry_run_mode=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                if [[ -z "$framework_name" ]] && [[ -z "$frameworks_list" ]]; then
                    framework_name="$1"
                fi
                shift
                ;;
        esac
    done
    
    print_section "MSP iOS SDK Build System"
    log_info "Version: $SCRIPT_VERSION"
    
    # Handle special modes (these exit immediately)
    if [[ "$status_mode" == "true" ]]; then
        show_build_status
        exit 0
    fi
    
    if [[ "$info_mode" == "true" ]]; then
        show_project_info
        exit 0
    fi
    
    if [[ "$clean_all_mode" == "true" ]]; then
        clean_all_artifacts
        exit 0
    fi
    
    # Clean build artifacts if requested (default behavior)
    # Note: clean_mode=true means clean BEFORE building, not clean INSTEAD OF building
    if [[ "$clean_mode" == "true" ]]; then
        clean_build_artifacts
        # Don't exit - continue to build after cleaning
    fi
    
    # Validate environment
    if ! validate_environment; then
        exit 1
    fi
    
    # Determine frameworks to build
    local frameworks_to_build=""
    
    if [[ -n "$framework_name" ]]; then
        frameworks_to_build="$framework_name"
    elif [[ -n "$frameworks_list" ]]; then
        frameworks_to_build="$frameworks_list"
    else
        frameworks_to_build="all"
    fi
    
    # Convert to list
    if [[ "$frameworks_to_build" == "all" ]]; then
        frameworks_to_build="MSPiOSCore NovaCore"
    else
        # Convert comma-separated frameworks to space-separated
        frameworks_to_build=$(echo "$frameworks_to_build" | tr ',' ' ')
    fi
    
    # Show dry run
    if [[ "$dry_run_mode" == "true" ]]; then
        print_section "Dry Run - What Would Be Built"
        log_info "Frameworks to build: $frameworks_to_build"
        log_info "Skip code sign: ${SKIP_CODE_SIGN:-0}"
        exit 0
    fi
    
    # Build frameworks
    local failed_frameworks=""
    local successful_frameworks=""
    
    for framework in $frameworks_to_build; do
        if build_framework "$framework"; then
            successful_frameworks="$successful_frameworks $framework"
        else
            failed_frameworks="$failed_frameworks $framework"
        fi
    done
    
    # Report results
    print_section "Build Results"
    
    if [[ -n "$successful_frameworks" ]]; then
        log_success "Successfully built:$successful_frameworks"
    fi
    
    if [[ -n "$failed_frameworks" ]]; then
        log_error "Failed to build:$failed_frameworks"
        exit 1
    fi
    
    log_success "All frameworks built successfully!"
}

# Execute main function
main "$@"