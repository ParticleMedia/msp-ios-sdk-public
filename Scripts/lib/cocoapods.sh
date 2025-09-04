#!/bin/bash

# CocoaPods operations for MSP iOS SDK build system
# This module provides comprehensive CocoaPods management with dependency handling and validation

# Source dependencies
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# CocoaPods constants
readonly PODFILE="Podfile"
readonly PODFILE_LOCK="Podfile.lock"
readonly PODS_DIR="Pods"
readonly PODSPEC_EXTENSION=".podspec"

# CocoaPods validation functions
validate_cocoapods_environment() {
    log_step "Validating CocoaPods environment..."
    
    # Check if CocoaPods is installed
    if ! check_command_exists "pod" "CocoaPods"; then
        log_error "CocoaPods not installed. Run: sudo gem install cocoapods"
        return $EXIT_COMMAND_NOT_FOUND
    fi
    
    # Check CocoaPods version
    local pod_version
    pod_version=$(get_command_version "pod")
    if [[ "$pod_version" == "unknown" ]]; then
        log_warn "Could not determine CocoaPods version"
    else
        log_debug "CocoaPods version: $pod_version"
    fi
    
    # Check if Podfile exists
    if ! check_path_exists "$PODFILE" "Podfile" "file"; then
        log_error "Podfile not found. This doesn't appear to be a CocoaPods project."
        return $EXIT_VALIDATION_ERROR
    fi
    
    log_success "CocoaPods environment validated"
    return $EXIT_SUCCESS
}

# Podfile operations
validate_podfile() {
    local podfile="${1:-$PODFILE}"
    
    if ! check_path_exists "$podfile" "Podfile" "file"; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    log_step "Validating Podfile syntax..."
    
    # Basic syntax check
    if pod spec lint --quick --allow-warnings "$podfile" >/dev/null 2>&1; then
        log_success "Podfile syntax is valid"
        return $EXIT_SUCCESS
    else
        # Pod spec lint might not work on Podfile, so try a different approach
        if ruby -c "$podfile" >/dev/null 2>&1; then
            log_success "Podfile syntax is valid"
            return $EXIT_SUCCESS
        else
            log_error "Podfile has syntax errors"
            return $EXIT_VALIDATION_ERROR
        fi
    fi
}

get_podfile_platforms() {
    local podfile="${1:-$PODFILE}"
    
    if [[ ! -f "$podfile" ]]; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    grep -o "platform :ios, '[0-9.]*'" "$podfile" | head -n1 | grep -o "[0-9.]*"
}

# Installation and update operations
install_pods() {
    local options=("$@")
    local repo_update=false
    local clean_install=false
    
    # Parse options
    for option in "${options[@]}"; do
        case "$option" in
            "--repo-update") repo_update=true ;;
            "--clean") clean_install=true ;;
        esac
    done
    
    if ! validate_cocoapods_environment; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Clean install if requested
    if [[ "$clean_install" == "true" ]]; then
        clean_pods
    fi
    
    log_step "Installing CocoaPods dependencies..."
    
    local install_cmd="pod install"
    
    # Add repo update if requested or if this is CI
    if [[ "$repo_update" == "true" ]] || [[ "$BUILD_ENVIRONMENT" == "github-actions" ]]; then
        install_cmd="$install_cmd --repo-update"
        log_debug "Including repository update"
    fi
    
    # Add CI-specific flags
    case "$BUILD_ENVIRONMENT" in
        "github-actions"|"ci")
            install_cmd="$install_cmd --verbose"
            ;;
    esac
    
    local start_time
    start_time=$(date +%s)
    
    if eval "$install_cmd"; then
        local duration
        duration=$(($(date +%s) - start_time))
        log_success "CocoaPods installation completed in $(format_duration $duration)"
        
        # Verify installation
        verify_pods_installation
        return $EXIT_SUCCESS
    else
        log_error "CocoaPods installation failed"
        return $EXIT_BUILD_ERROR
    fi
}

update_pods() {
    local options=("$@")
    
    if ! validate_cocoapods_environment; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    log_step "Updating CocoaPods dependencies..."
    
    local update_cmd="pod update"
    
    # Add options
    for option in "${options[@]}"; do
        case "$option" in
            "--verbose") update_cmd="$update_cmd --verbose" ;;
            "--no-repo-update") update_cmd="$update_cmd --no-repo-update" ;;
        esac
    done
    
    if eval "$update_cmd"; then
        log_success "CocoaPods update completed"
        verify_pods_installation
        return $EXIT_SUCCESS
    else
        log_error "CocoaPods update failed"
        return $EXIT_BUILD_ERROR
    fi
}

verify_pods_installation() {
    log_step "Verifying CocoaPods installation..."
    
    # Check if Podfile.lock exists
    if ! check_path_exists "$PODFILE_LOCK" "Podfile.lock" "file"; then
        log_warn "Podfile.lock not found"
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Check if Pods directory exists
    if ! check_path_exists "$PODS_DIR" "Pods directory" "directory"; then
        log_warn "Pods directory not found"
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Check if dependencies are up to date
    if command -v bundle >/dev/null 2>&1; then
        if bundle check >/dev/null 2>&1; then
            log_debug "Bundle dependencies are up to date"
        else
            log_warn "Bundle dependencies need updating"
        fi
    fi
    
    # Get installation statistics
    local pods_count=0
    if [[ -f "$PODFILE_LOCK" ]]; then
        pods_count=$(grep -c "^  - " "$PODFILE_LOCK" 2>/dev/null || echo "0")
    fi
    
    log_success "CocoaPods installation verified ($pods_count dependencies)"
    return $EXIT_SUCCESS
}

# Cleanup operations
clean_pods() {
    log_step "Cleaning CocoaPods installation..."
    
    # Remove Pods directory
    if [[ -d "$PODS_DIR" ]]; then
        safe_remove "$PODS_DIR"
        log_debug "Removed Pods directory"
    fi
    
    # Remove Podfile.lock
    if [[ -f "$PODFILE_LOCK" ]]; then
        safe_remove "$PODFILE_LOCK"
        log_debug "Removed Podfile.lock"
    fi
    
    # Remove workspace if it exists and seems to be generated by CocoaPods
    local workspace_files=(*.xcworkspace)
    for workspace in "${workspace_files[@]}"; do
        if [[ -f "$workspace" ]] && [[ "$workspace" != "*.xcworkspace" ]]; then
            # Check if workspace is likely generated by CocoaPods
            if grep -q "Pods/" "$workspace/contents.xcworkspacedata" 2>/dev/null; then
                log_debug "Workspace $workspace appears to be CocoaPods-managed, keeping it"
            fi
        fi
    done
    
    log_success "CocoaPods cleanup completed"
}

deintegrate_pods() {
    log_step "Deintegrating CocoaPods..."
    
    if command -v pod >/dev/null 2>&1; then
        if pod deintegrate; then
            log_success "CocoaPods deintegration completed"
        else
            log_warn "CocoaPods deintegration had issues, continuing with manual cleanup"
            clean_pods
        fi
    else
        log_warn "CocoaPods not available, performing manual cleanup"
        clean_pods
    fi
}

# Podspec operations
find_podspecs() {
    local directory="${1:-.}"
    find "$directory" -name "*$PODSPEC_EXTENSION" -type f
}

validate_podspec() {
    local podspec="$1"
    local options=("${@:2}")
    
    if ! check_path_exists "$podspec" "Podspec" "file"; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    log_step "Validating podspec: $(basename "$podspec")..."
    
    local lint_cmd="pod spec lint \"$podspec\""
    
    # Add common options
    lint_cmd="$lint_cmd --allow-warnings --skip-import-validation"
    
    # Add custom options
    for option in "${options[@]}"; do
        lint_cmd="$lint_cmd $option"
    done
    
    if eval "$lint_cmd"; then
        log_success "Podspec validation passed: $(basename "$podspec")"
        return $EXIT_SUCCESS
    else
        log_error "Podspec validation failed: $(basename "$podspec")"
        return $EXIT_VALIDATION_ERROR
    fi
}

validate_all_podspecs() {
    local directory="${1:-.}"
    local failed_specs=()
    local total_specs=0
    
    log_step "Validating all podspecs in $directory..."
    
    # Find all podspecs
    local podspecs
    mapfile -t podspecs < <(find_podspecs "$directory")
    
    if [[ ${#podspecs[@]} -eq 0 ]]; then
        log_warn "No podspecs found in $directory"
        return $EXIT_SUCCESS
    fi
    
    # Validate each podspec
    for podspec in "${podspecs[@]}"; do
        ((total_specs++))
        
        if ! validate_podspec "$podspec" >/dev/null 2>&1; then
            failed_specs+=("$(basename "$podspec")")
        fi
    done
    
    # Report results
    if [[ ${#failed_specs[@]} -eq 0 ]]; then
        log_success "All $total_specs podspecs validated successfully"
        return $EXIT_SUCCESS
    else
        log_error "${#failed_specs[@]} of $total_specs podspecs failed validation:"
        for spec in "${failed_specs[@]}"; do
            log_error "  - $spec"
        done
        return $EXIT_VALIDATION_ERROR
    fi
}

# Publishing operations
publish_podspec() {
    local podspec="$1"
    local options=("${@:2}")
    
    if ! check_path_exists "$podspec" "Podspec" "file"; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Validate before publishing
    if ! validate_podspec "$podspec"; then
        log_error "Cannot publish invalid podspec"
        return $EXIT_VALIDATION_ERROR
    fi
    
    log_step "Publishing podspec: $(basename "$podspec")..."
    
    local push_cmd="pod trunk push \"$podspec\""
    
    # Add common options
    push_cmd="$push_cmd --allow-warnings"
    
    # Add custom options
    for option in "${options[@]}"; do
        push_cmd="$push_cmd $option"
    done
    
    if eval "$push_cmd"; then
        log_success "Podspec published successfully: $(basename "$podspec")"
        return $EXIT_SUCCESS
    else
        log_error "Podspec publishing failed: $(basename "$podspec")"
        return $EXIT_BUILD_ERROR
    fi
}

# Repository operations
update_specs_repo() {
    log_step "Updating CocoaPods specs repository..."
    
    if pod repo update; then
        log_success "Specs repository updated"
        return $EXIT_SUCCESS
    else
        log_error "Specs repository update failed"
        return $EXIT_BUILD_ERROR
    fi
}

check_pod_availability() {
    local pod_name="$1"
    local version="${2:-}"
    
    local search_cmd="pod search $pod_name"
    
    if [[ -n "$version" ]]; then
        log_step "Checking availability of $pod_name version $version..."
    else
        log_step "Checking availability of $pod_name..."
    fi
    
    if eval "$search_cmd" >/dev/null 2>&1; then
        if [[ -n "$version" ]]; then
            # Try to find specific version
            if pod spec cat "$pod_name" --version="$version" >/dev/null 2>&1; then
                log_success "$pod_name version $version is available"
                return $EXIT_SUCCESS
            else
                log_warn "$pod_name is available but version $version not found"
                return $EXIT_VALIDATION_ERROR
            fi
        else
            log_success "$pod_name is available"
            return $EXIT_SUCCESS
        fi
    else
        log_error "$pod_name not found in CocoaPods repository"
        return $EXIT_VALIDATION_ERROR
    fi
}

# Cache operations
clean_pod_cache() {
    log_step "Cleaning CocoaPods cache..."
    
    if pod cache clean --all; then
        log_success "CocoaPods cache cleaned"
        return $EXIT_SUCCESS
    else
        log_warn "CocoaPods cache cleaning had issues"
        return $EXIT_GENERAL_ERROR
    fi
}

# Information and diagnostics
show_pod_info() {
    if ! validate_cocoapods_environment; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    print_subsection "CocoaPods Information"
    
    # CocoaPods version
    local pod_version
    pod_version=$(get_command_version "pod")
    log_info "CocoaPods version: $pod_version"
    
    # Ruby version (CocoaPods is Ruby-based)
    local ruby_version
    ruby_version=$(get_command_version "ruby")
    log_info "Ruby version: $ruby_version"
    
    # Bundler version if available
    if command -v bundle >/dev/null 2>&1; then
        local bundle_version
        bundle_version=$(get_command_version "bundle")
        log_info "Bundler version: $bundle_version"
    fi
    
    # Platform info from Podfile
    if [[ -f "$PODFILE" ]]; then
        local ios_version
        ios_version=$(get_podfile_platforms)
        if [[ -n "$ios_version" ]]; then
            log_info "iOS deployment target: $ios_version"
        fi
    fi
    
    # Installation status
    if [[ -f "$PODFILE_LOCK" ]]; then
        local pods_count
        pods_count=$(grep -c "^  - " "$PODFILE_LOCK" 2>/dev/null || echo "0")
        log_info "Installed pods: $pods_count"
        
        local lockfile_date
        if command -v stat >/dev/null 2>&1; then
            lockfile_date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$PODFILE_LOCK" 2>/dev/null || echo "unknown")
            log_info "Podfile.lock date: $lockfile_date"
        fi
    else
        log_info "No pods installed"
    fi
}

# Bundle integration
setup_bundle_integration() {
    log_step "Setting up Bundle integration with CocoaPods..."
    
    # Check if Gemfile exists
    if [[ -f "Gemfile" ]]; then
        # Check if CocoaPods is in Gemfile
        if grep -q "gem ['\"]cocoapods['\"]" Gemfile; then
            log_debug "CocoaPods found in Gemfile"
            
            # Use bundle exec for pod commands if available
            if command -v bundle >/dev/null 2>&1; then
                # Create wrapper functions that use bundle exec
                alias pod='bundle exec pod'
                log_debug "Set up bundle exec wrapper for pod commands"
            fi
        else
            log_debug "CocoaPods not found in Gemfile"
        fi
    else
        log_debug "No Gemfile found"
    fi
    
    log_success "Bundle integration setup completed"
}

# High-level operations
full_pod_setup() {
    local clean="${1:-false}"
    
    print_section "CocoaPods Setup"
    
    if ! validate_cocoapods_environment; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Setup bundle integration if available
    if [[ -f "Gemfile" ]]; then
        setup_bundle_integration
    fi
    
    # Clean if requested
    if [[ "$clean" == "true" ]]; then
        clean_pods
    fi
    
    # Install pods
    local install_options=()
    
    # Add repo update for CI environments
    if [[ "$BUILD_ENVIRONMENT" == "github-actions" ]]; then
        install_options+=("--repo-update")
    fi
    
    if install_pods "${install_options[@]}"; then
        show_pod_info
        return $EXIT_SUCCESS
    else
        return $EXIT_BUILD_ERROR
    fi
}

# Export CocoaPods functions
export -f validate_cocoapods_environment
export -f validate_podfile get_podfile_platforms
export -f install_pods update_pods verify_pods_installation
export -f clean_pods deintegrate_pods
export -f find_podspecs validate_podspec validate_all_podspecs
export -f publish_podspec
export -f update_specs_repo check_pod_availability
export -f clean_pod_cache
export -f show_pod_info setup_bundle_integration
export -f full_pod_setup
