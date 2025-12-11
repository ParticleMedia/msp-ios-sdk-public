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

# Xcode build functions for MSP iOS SDK build system
# This module provides comprehensive Xcode build operations with error handling and optimization

# Source dependencies
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# Xcode build constants
readonly XCODE_WORKSPACE="msp-ios-sdk.xcworkspace"
readonly DEFAULT_BUILD_SETTINGS=(
    "SKIP_INSTALL=NO"
    "BUILD_LIBRARY_FOR_DISTRIBUTION=YES"
    "ONLY_ACTIVE_ARCH=NO"
)

# SDK and destination mappings
declare -A SDK_DESTINATIONS
SDK_DESTINATIONS[iphoneos]="iOS"
SDK_DESTINATIONS[iphonesimulator]="iOS Simulator"

declare -A PLATFORM_SDKS
PLATFORM_SDKS[ios]="iphoneos"
PLATFORM_SDKS[ios-simulator]="iphonesimulator"

# Architecture configurations
declare -A ARCH_CONFIGS
ARCH_CONFIGS[iphoneos]="arm64"
ARCH_CONFIGS[iphonesimulator]="arm64 x86_64"

# Build configuration functions
get_build_settings() {
    local skip_code_sign=$(get_env_bool SKIP_CODE_SIGN false)
    local configuration="${CONFIGURATION:-Release}"
    local deployment_target="${IPHONEOS_DEPLOYMENT_TARGET:-15.0}"
    
    local settings=("${DEFAULT_BUILD_SETTINGS[@]}")
    settings+=("CONFIGURATION=$configuration")
    settings+=("IPHONEOS_DEPLOYMENT_TARGET=$deployment_target")
    
    # Add code signing settings
    if [[ "$skip_code_sign" == "true" ]]; then
        settings+=(
            "CODE_SIGN_IDENTITY="
            "CODE_SIGNING_REQUIRED=NO"
            "CODE_SIGNING_ALLOWED=NO"
        )
    fi
    
    # Add environment-specific settings
    case "$BUILD_ENVIRONMENT" in
        "github-actions"|"ci")
            settings+=(
                "COMPILER_INDEX_STORE_ENABLE=NO"
                "SWIFT_COMPILATION_MODE=wholemodule"
            )
            ;;
    esac
    
    printf "%s " "${settings[@]}"
}

get_simulator_arch_settings() {
    local force_universal="${1:-true}"
    
    if [[ "$force_universal" == "true" ]]; then
        echo 'VALID_ARCHS="arm64 x86_64" ARCHS="arm64 x86_64" EXCLUDED_ARCHS=""'
    else
        echo ""
    fi
}

# Xcode project and workspace functions
validate_workspace() {
    local workspace="${1:-$XCODE_WORKSPACE}"
    
    if ! check_path_exists "$workspace" "Xcode workspace" "file"; then
        log_error "Xcode workspace not found: $workspace"
        return $EXIT_VALIDATION_ERROR
    fi
    
    log_debug "Using Xcode workspace: $workspace"
    return $EXIT_SUCCESS
}

list_schemes() {
    local workspace="${1:-$XCODE_WORKSPACE}"
    
    if ! validate_workspace "$workspace"; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    log_debug "Listing schemes for workspace: $workspace"
    xcodebuild -workspace "$workspace" -list 2>/dev/null | \
        awk '/Schemes:/,/^$/' | \
        grep -v "Schemes:" | \
        grep -v "^$" | \
        sed 's/^[[:space:]]*//'
}

validate_scheme() {
    local scheme="$1"
    local workspace="${2:-$XCODE_WORKSPACE}"
    
    if [[ -z "$scheme" ]]; then
        log_error "Scheme name is required"
        return $EXIT_VALIDATION_ERROR
    fi
    
    local available_schemes
    available_schemes=$(list_schemes "$workspace")
    
    if echo "$available_schemes" | grep -q "^${scheme}$"; then
        log_debug "Scheme '$scheme' found in workspace"
        return $EXIT_SUCCESS
    else
        log_error "Scheme '$scheme' not found in workspace"
        log_debug "Available schemes:"
        echo "$available_schemes" | while read -r s; do
            log_debug "  - $s"
        done
        return $EXIT_VALIDATION_ERROR
    fi
}

# Build functions
execute_xcodebuild() {
    local command_args=("$@")
    local log_file=""
    local command="xcodebuild ${command_args[*]}"
    
    # Create log file for CI environments
    if [[ "$BUILD_ENVIRONMENT" != "local" ]]; then
        log_file="$(pwd)/xcodebuild-$(date +%s).log"
        command="$command 2>&1 | tee '$log_file'"
    fi
    
    log_debug "Executing: $command"
    
    if [[ -n "$log_file" ]]; then
        if eval "$command"; then
            log_artifact "log" "xcodebuild.log" "$log_file" "Build log"
            return $EXIT_SUCCESS
        else
            local exit_code=$?
            log_artifact "log" "xcodebuild-error.log" "$log_file" "Build error log"
            return $exit_code
        fi
    else
        eval "$command"
    fi
}

build_archive() {
    local scheme="$1"
    local sdk="$2"
    local archive_path="$3"
    local additional_settings="${4:-}"
    local workspace="${5:-$XCODE_WORKSPACE}"
    
    # Validate inputs
    if ! validate_workspace "$workspace"; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    if ! validate_scheme "$scheme" "$workspace"; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Prepare build arguments
    local destination="${SDK_DESTINATIONS[$sdk]}"
    if [[ -z "$destination" ]]; then
        log_error "Unknown SDK: $sdk"
        return $EXIT_VALIDATION_ERROR
    fi
    
    local build_settings
    build_settings=$(get_build_settings)
    
    # Add additional settings
    if [[ -n "$additional_settings" ]]; then
        build_settings="$build_settings $additional_settings"
    fi
    
    # Ensure archive directory exists
    local archive_dir
    archive_dir=$(dirname "$archive_path")
    ensure_directory "$archive_dir"
    
    # Build the archive
    log_step "Building $scheme archive for $destination ($sdk)..."
    
    local build_args=(
        "archive"
        "-workspace" "$workspace"
        "-scheme" "$scheme"
        "-destination" "$destination"
        "-archivePath" "$archive_path"
        "-sdk" "$sdk"
        $build_settings
    )
    
    if execute_xcodebuild "${build_args[@]}"; then
        log_success "$scheme archive created successfully"
        
        # Verify archive
        local framework_path="$archive_path.xcarchive/Products/Library/Frameworks/$scheme.framework"
        if [[ -d "$framework_path" ]]; then
            log_debug "Framework found: $framework_path"
            
            # Log framework details
            local framework_size
            framework_size=$(get_file_size "$framework_path")
            log_framework_info "$scheme" "$framework_path" "$framework_size"
            
            # Verify architectures
            verify_framework_architectures "$framework_path/$scheme" "$sdk"
        else
            log_warn "Framework not found at expected location: $framework_path"
        fi
        
        return $EXIT_SUCCESS
    else
        log_error "$scheme archive build failed"
        return $EXIT_BUILD_ERROR
    fi
}

create_xcframework() {
    local framework_name="$1"
    local output_path="$2"
    shift 2
    local framework_paths=("$@")
    
    if [[ ${#framework_paths[@]} -eq 0 ]]; then
        log_error "No framework paths provided for XCFramework creation"
        return $EXIT_VALIDATION_ERROR
    fi
    
    log_step "Creating $framework_name XCFramework..."
    
    # Verify all framework paths exist
    for framework_path in "${framework_paths[@]}"; do
        if ! check_path_exists "$framework_path" "Framework" "directory"; then
            return $EXIT_VALIDATION_ERROR
        fi
    done
    
    # Prepare xcodebuild arguments
    local xcframework_args=("-create-xcframework")
    for framework_path in "${framework_paths[@]}"; do
        xcframework_args+=("-framework" "$framework_path")
    done
    xcframework_args+=("-output" "$output_path")
    
    # Ensure output directory exists
    local output_dir
    output_dir=$(dirname "$output_path")
    ensure_directory "$output_dir"
    
    # Remove existing XCFramework if it exists
    safe_remove "$output_path"
    
    # Create XCFramework
    if execute_xcodebuild "${xcframework_args[@]}"; then
        log_success "$framework_name XCFramework created successfully"
        
        # Verify XCFramework
        if verify_xcframework "$output_path"; then
            local xcframework_size
            xcframework_size=$(get_file_size "$output_path")
            log_framework_info "$framework_name" "$output_path" "$xcframework_size"
            log_artifact "framework" "$framework_name" "$output_path" "$xcframework_size"
        fi
        
        return $EXIT_SUCCESS
    else
        log_error "$framework_name XCFramework creation failed"
        return $EXIT_BUILD_ERROR
    fi
}

# Architecture verification functions
verify_framework_architectures() {
    local binary_path="$1"
    local sdk="$2"
    
    if [[ ! -f "$binary_path" ]]; then
        log_warn "Binary not found for architecture verification: $binary_path"
        return $EXIT_SUCCESS
    fi
    
    local expected_archs="${ARCH_CONFIGS[$sdk]}"
    if [[ -z "$expected_archs" ]]; then
        log_debug "No expected architectures defined for SDK: $sdk"
        return $EXIT_SUCCESS
    fi
    
    local actual_archs
    actual_archs=$(lipo -info "$binary_path" 2>/dev/null | grep -o "arm64\|x86_64\|i386" | sort | uniq | tr '\n' ' ' | trim_whitespace)
    
    if [[ -z "$actual_archs" ]]; then
        log_warn "Could not determine architectures for: $binary_path"
        return $EXIT_SUCCESS
    fi
    
    log_debug "Framework architectures: $actual_archs (expected: $expected_archs)"
    
    # Check if all expected architectures are present
    for arch in $expected_archs; do
        if [[ "$actual_archs" != *"$arch"* ]]; then
            log_warn "Missing expected architecture '$arch' in framework"
            return $EXIT_VALIDATION_ERROR
        fi
    done
    
    log_success "Framework architectures verified: $actual_archs"
    return $EXIT_SUCCESS
}

verify_xcframework() {
    local xcframework_path="$1"
    
    if ! check_path_exists "$xcframework_path" "XCFramework" "directory"; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Check for Info.plist
    local info_plist="$xcframework_path/Info.plist"
    if ! check_path_exists "$info_plist" "XCFramework Info.plist" "file"; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Parse and validate Info.plist
    if command -v plutil >/dev/null 2>&1; then
        log_debug "XCFramework Info.plist contents:"
        local info_content
        info_content=$(plutil -p "$info_plist" 2>/dev/null | grep -E "(LibraryIdentifier|SupportedArchitectures|SupportedPlatform)" || true)
        
        if [[ -n "$info_content" ]]; then
            echo "$info_content" | while read -r line; do
                log_debug "  $line"
            done
        fi
    fi
    
    log_success "XCFramework structure verified"
    return $EXIT_SUCCESS
}

# Framework deployment functions
deploy_framework() {
    local source_path="$1"
    local destination_dir="$2"
    local framework_name="$3"
    
    if ! check_path_exists "$source_path" "Source framework" "directory"; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    ensure_directory "$destination_dir"
    
    local destination_path="$destination_dir/$(basename "$source_path")"
    
    log_step "Deploying $(basename "$source_path") to $destination_dir..."
    
    # Remove existing framework
    safe_remove "$destination_path"
    
    # Copy new framework
    if cp -R "$source_path" "$destination_dir/"; then
        log_success "Framework deployed successfully"
        
        # Verify deployment
        if check_path_exists "$destination_path" "Deployed framework" "directory"; then
            local framework_size
            framework_size=$(get_file_size "$destination_path")
            log_framework_info "$framework_name" "$destination_path" "$framework_size"
            return $EXIT_SUCCESS
        else
            log_error "Framework deployment verification failed"
            return $EXIT_DEPLOY_ERROR
        fi
    else
        log_error "Framework deployment failed"
        return $EXIT_DEPLOY_ERROR
    fi
}

# Clean functions
clean_build_products() {
    local schemes=("$@")
    
    if [[ ${#schemes[@]} -eq 0 ]]; then
        log_step "Cleaning all build products..."
        execute_xcodebuild "clean" "-workspace" "$XCODE_WORKSPACE" "-alltargets"
    else
        for scheme in "${schemes[@]}"; do
            log_step "Cleaning $scheme build products..."
            execute_xcodebuild "clean" "-workspace" "$XCODE_WORKSPACE" "-scheme" "$scheme"
        done
    fi
}

clean_derived_data() {
    local derived_data_path
    
    # Try to get DerivedData path from Xcode
    derived_data_path=$(xcodebuild -showBuildSettings -workspace "$XCODE_WORKSPACE" 2>/dev/null | \
        grep "BUILD_DIR" | head -n1 | awk '{print $3}' | sed 's|/Build/Products||')
    
    if [[ -z "$derived_data_path" ]]; then
        # Fallback to default location
        derived_data_path="$HOME/Library/Developer/Xcode/DerivedData"
    fi
    
    if [[ -d "$derived_data_path" ]]; then
        log_step "Cleaning DerivedData..."
        safe_remove "$derived_data_path"
        log_success "DerivedData cleaned"
    else
        log_debug "DerivedData not found or already clean"
    fi
}

# High-level build functions
build_framework_for_platforms() {
    local scheme="$1"
    local output_base_dir="$2"
    local platforms=("${@:3}")
    
    if [[ ${#platforms[@]} -eq 0 ]]; then
        platforms=("ios" "ios-simulator")
    fi
    
    local archive_paths=()
    local framework_paths=()
    
    # Build for each platform
    for platform in "${platforms[@]}"; do
        local sdk="${PLATFORM_SDKS[$platform]}"
        if [[ -z "$sdk" ]]; then
            log_error "Unknown platform: $platform"
            return $EXIT_VALIDATION_ERROR
        fi
        
        local archive_path="$output_base_dir/$scheme-${platform^}"
        local additional_settings=""
        
        # Add special settings for iOS Simulator
        if [[ "$platform" == "ios-simulator" ]]; then
            additional_settings=$(get_simulator_arch_settings true)
        fi
        
        if build_archive "$scheme" "$sdk" "$archive_path" "$additional_settings"; then
            archive_paths+=("$archive_path.xcarchive")
            framework_paths+=("$archive_path.xcarchive/Products/Library/Frameworks/$scheme.framework")
        else
            log_error "Failed to build $scheme for $platform"
            return $EXIT_BUILD_ERROR
        fi
    done
    
    # Create XCFramework
    local xcframework_path="$output_base_dir/$scheme.xcframework"
    if create_xcframework "$scheme" "$xcframework_path" "${framework_paths[@]}"; then
        echo "$xcframework_path"
        return $EXIT_SUCCESS
    else
        return $EXIT_BUILD_ERROR
    fi
}

# Testing functions
run_tests() {
    local scheme="$1"
    local device="${2:-iPhone 15}"
    local workspace="${3:-$XCODE_WORKSPACE}"
    
    if ! validate_scheme "$scheme" "$workspace"; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    log_step "Running tests for $scheme..."
    
    local test_args=(
        "test"
        "-workspace" "$workspace"
        "-scheme" "$scheme"
        "-destination" "platform=iOS Simulator,name=$device"
        "-enableCodeCoverage" "YES"
    )
    
    # Add test-specific settings
    local test_settings
    test_settings=$(get_build_settings)
    test_settings="$test_settings ENABLE_TESTING_SEARCH_PATHS=YES"
    
    if execute_xcodebuild "${test_args[@]}" $test_settings; then
        log_success "$scheme tests completed successfully"
        return $EXIT_SUCCESS
    else
        log_error "$scheme tests failed"
        return $EXIT_BUILD_ERROR
    fi
}

# Export Xcode functions
export -f get_build_settings get_simulator_arch_settings
export -f validate_workspace list_schemes validate_scheme
export -f execute_xcodebuild
export -f build_archive create_xcframework
export -f verify_framework_architectures verify_xcframework
export -f deploy_framework
export -f clean_build_products clean_derived_data
export -f build_framework_for_platforms
export -f run_tests
