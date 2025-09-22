#!/bin/bash

# Modular CocoaPods Release Script
# Follows the exact release workflow: MSPSharedLibraries → Adapters → MSPCore

set -e

# Source the common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/release-common.sh"
source "$SCRIPT_DIR/lib/cocoapods.sh"

# Default values
VERSION=""
RELEASE_BRANCH=""
DRY_RUN="false"
SKIP_VALIDATION="false"
VERBOSE="false"
RELEASE_NOTES_SOURCE="auto"  # auto, git, template, prompt
RELEASE_NOTES_TEMPLATE=""
RELEASE_NOTES=""

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                echo "Modular CocoaPods Release Script v1.0.0"
                exit 0
                ;;
            --release-branch)
                RELEASE_BRANCH="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --skip-validation)
                SKIP_VALIDATION="true"
                shift
                ;;
            --verbose)
                VERBOSE="true"
                shift
                ;;
            --release-notes-source)
                RELEASE_NOTES_SOURCE="$2"
                shift 2
                ;;
            --release-notes-template)
                RELEASE_NOTES_TEMPLATE="$2"
                shift 2
                ;;
            --release-notes)
                RELEASE_NOTES="$2"
                shift 2
                ;;
            *)
                if [[ -z "$VERSION" ]]; then
                    VERSION="$1"
                else
                    log_error "Unknown argument: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS] <VERSION>"
    echo ""
    echo "Arguments:"
    echo "  VERSION                 Version to release (e.g., 0.0.2-migration-spm)"
    echo ""
    echo "Options:"
    echo "  --release-branch BRANCH       Release branch to work on (default: release/VERSION)"
    echo "  --dry-run                     Show what would be done without executing"
    echo "  --skip-validation             Skip podspec validation"
    echo "  --verbose                     Enable verbose output"
    echo "  --release-notes-source SOURCE Release notes source (auto, git, template, prompt)"
    echo "  --release-notes-template FILE Custom release notes template file"
    echo "  --release-notes NOTES        Custom release notes text"
    echo "  --help, -h                    Show this help message"
    echo "  --version, -v                 Show version information"
    echo ""
    echo "Release Workflow:"
    echo "  1. Publish MSPSharedLibraries (foundation dependency)"
    echo "  2. Wait for MSPSharedLibraries to be released"
    echo "  3. Publish Adapters (FacebookAdapter, GoogleAdapter, NovaAdapter, AmazonAdapter, PrebidAdapter)"
    echo "  4. Wait for Adapters to be released"
    echo "  5. Publish MSPCore (main framework)"
    echo "  6. Commit all changes to release branch"
}

# Validate inputs
validate_inputs() {
    if [[ -z "$VERSION" ]]; then
        log_error "Version is required"
        show_help
        exit 1
    fi
    
    # Set release branch if not provided
    if [[ -z "$RELEASE_BRANCH" ]]; then
        RELEASE_BRANCH="release/$VERSION"
    fi
    
    log_info "CocoaPods release configuration:"
    log_info "  Version: $VERSION"
    log_info "  Release Branch: $RELEASE_BRANCH"
    log_info "  Dry Run: $DRY_RUN"
    log_info "  Skip Validation: $SKIP_VALIDATION"
}

# Check if we're on the correct release branch
check_release_branch() {
    log_step "Checking release branch"
    
    # Skip branch check in dry-run mode
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Skipping release branch check"
        return 0
    fi
    
    local current_branch=$(git branch --show-current)
    if [[ "$current_branch" != "$RELEASE_BRANCH" ]]; then
        log_error "Not on release branch '$RELEASE_BRANCH'. Current branch: '$current_branch'"
        log_info "Please checkout the release branch first:"
        log_info "  git checkout $RELEASE_BRANCH"
        exit 1
    fi
    
    log_success "On correct release branch: $RELEASE_BRANCH"
}

# Update podspec version and source
update_podspec_for_release() {
    local pod="$1"
    local version="$2"
    local podspec="${pod}.podspec"
    
    if [[ ! -f "$podspec" ]]; then
        log_error "Podspec not found: $podspec"
        return 1
    fi
    
    log_step "Updating $podspec for release version $version"
    
    # Create backup
    cp "$podspec" "${podspec}.backup"
    
    # Update version
    sed -i '' "s|spec\.version.*=.*\".*\"|spec.version = \"${version}\"|g" "$podspec"
    
    # Update source to HTTP zip format
    local pod_name=$(basename "$podspec" .podspec)
    local http_url="https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/${pod_name}-${version}.zip"
    
    # Handle both git source and existing HTTP source
    sed -i '' "s|spec\.source.*=.*{.*:git.*=>.*\"https://github\.com/.*\.git\".*:tag.*=>.*\"#{spec\.version}\".*}|spec.source = {\n    http: \"${http_url}\",\n    type: \"zip\"\n  }|g" "$podspec"
    sed -i '' "s|http: \"https://github\.com/ParticleMedia/msp-ios-sdk-public/releases/download/[^\"]*\"|http: \"${http_url}\"|g" "$podspec"
    
    log_success "Updated $podspec for release"
}

# Update adapter SDK version
update_adapter_sdk_version() {
    local adapter="$1"
    local version="$2"
    
    log_step "Updating getSDKVersion() in $adapter"
    
    # Find Swift files in the adapter directory
    local adapter_dir="${adapter}/${adapter}"
    if [[ -d "$adapter_dir" ]]; then
        find "$adapter_dir" -name "*.swift" -exec grep -l "getSDKVersion" {} \; | while read -r file; do
            # Update getSDKVersion function to return the new version
            sed -i '' "s|return \".*\"|return \"${version}\"|g" "$file"
            log_info "Updated getSDKVersion in $file"
        done
    else
        log_warning "Adapter directory not found: $adapter_dir"
    fi
}

# Update MSPCore version
update_mspcore_version() {
    local version="$1"
    
    log_step "Updating MSPCore version property"
    
    # Only update MSPHelper.swift specifically
    local msphelper_file="MSPCore/MSPCore/MSPHelper.swift"
    if [[ -f "$msphelper_file" ]]; then
        # Update version property in MSPHelper.swift only
        sed -i '' "s|version.*=.*\".*\"|version = \"${version}\"|g" "$msphelper_file"
        log_info "Updated version in $msphelper_file"
    else
        log_warning "MSPHelper.swift not found at $msphelper_file"
    fi
}

# Update podspec dependencies
update_podspec_dependencies() {
    local pod="$1"
    local version="$2"
    local podspec="${pod}.podspec"
    
    if [[ ! -f "$podspec" ]]; then
        return 0
    fi
    
    log_step "Updating dependencies in $podspec"
    
    # Update MSPSharedLibraries dependency - handle both with and without version
    if grep -q "spec\.dependency.*MSPSharedLibraries" "$podspec"; then
        # Remove any existing version(s) and comments, then add the new one
        sed -i '' "s|spec\.dependency 'MSPSharedLibraries'[^#]*|spec.dependency 'MSPSharedLibraries'|g" "$podspec"
        sed -i '' "s|spec\.dependency 'MSPSharedLibraries'|spec.dependency 'MSPSharedLibraries', '${version}'|g" "$podspec"
        log_info "Updated MSPSharedLibraries dependency to $version"
    fi
    
    # Update PrebidAdapter dependency - handle both with and without version
    if grep -q "spec\.dependency.*PrebidAdapter" "$podspec"; then
        # Remove any existing version(s) and comments, then add the new one
        sed -i '' "s|spec\.dependency 'PrebidAdapter'[^#]*|spec.dependency 'PrebidAdapter'|g" "$podspec"
        sed -i '' "s|spec\.dependency 'PrebidAdapter'|spec.dependency 'PrebidAdapter', '${version}'|g" "$podspec"
        log_info "Updated PrebidAdapter dependency to $version"
    fi
    
    # Update MSPOMSDK dependency (keep without version constraint) - handle both with and without version
    if grep -q "spec\.dependency.*MSPOMSDK" "$podspec"; then
        # Remove any existing version(s) and comments, keep it without version constraint
        sed -i '' "s|spec\.dependency 'MSPOMSDK'[^#]*|spec.dependency 'MSPOMSDK'|g" "$podspec"
        log_info "Updated MSPOMSDK dependency to remove version constraint"
    fi
}

# Create GitHub release and upload zip
create_github_release_for_pod() {
    local pod="$1"
    local version="$2"
    
    log_step "Creating GitHub release for $pod"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would create GitHub release for $pod version $version"
        return 0
    fi
    
    # Create zip file
    local zip_name="${pod}-${version}.zip"
    if [[ -d "$pod" ]]; then
        zip -r "$zip_name" "$pod" >/dev/null 2>&1
        log_info "Created zip file: $zip_name"
    else
        log_error "Pod directory not found: $pod"
        return 1
    fi
    
    # Create or update GitHub release
    if gh release view "$version" --repo "ParticleMedia/msp-ios-sdk-public" &>/dev/null; then
        log_info "Release $version already exists, uploading assets"
        gh release upload "$version" "$zip_name" --repo "ParticleMedia/msp-ios-sdk-public" --clobber
    else
        log_info "Creating new release $version"
        gh release create "$version" "$zip_name" --repo "ParticleMedia/msp-ios-sdk-public" --title "Release $version" --notes "Release $version"
    fi
    
    # Clean up zip file
    rm -f "$zip_name"
    
    log_success "GitHub release created for $pod"
}

# Publish pod to CocoaPods
publish_pod_to_cocoapods() {
    local pod="$1"
    local version="$2"
    local podspec="${pod}.podspec"
    
    log_step "Publishing $pod to CocoaPods"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would publish $pod version $version to CocoaPods"
        return 0
    fi
    
    # Validate podspec if not skipped
    if [[ "$SKIP_VALIDATION" != "true" ]]; then
        if ! validate_podspec_with_retry "$podspec"; then
            log_error "Podspec validation failed for $pod"
            return 1
        fi
    fi
    
    # Publish to CocoaPods
    if ! publish_podspec_with_retry "$podspec"; then
        log_error "Failed to publish $pod to CocoaPods"
        return 1
    fi
    
    log_success "Published $pod to CocoaPods"
}

# Wait for pod to be available
wait_for_pod_availability() {
    local pod="$1"
    local version="$2"
    local max_attempts=8
    local base_delay=15  # Start with 15 seconds for better balance
    
    log_step "Waiting for $pod version $version to be available"
    
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if check_pod_availability "$pod" "$version"; then
            log_success "$pod version $version is now available"
            return 0
        else
            if [[ $attempt -lt $max_attempts ]]; then
                local delay=$((base_delay * (1 << (attempt - 1))))
                log_info "Waiting ${delay}s for $pod to be published (attempt $attempt/$max_attempts)..."
                sleep $delay
            else
                log_error "Timeout waiting for $pod version $version to be published"
                return 1
            fi
        fi
        ((attempt++))
    done
    
    return 1
}

# Release MSPSharedLibraries (Step 1)
release_msp_shared_libraries() {
    log_release "Step 1: Releasing MSPSharedLibraries (foundation dependency)"
    
    # Update podspec
    update_podspec_for_release "MSPSharedLibraries" "$VERSION"
    
    # Create GitHub release
    create_github_release_for_pod "MSPSharedLibraries" "$VERSION"
    
    # Publish to CocoaPods
    publish_pod_to_cocoapods "MSPSharedLibraries" "$VERSION"
    
    # Wait for availability (skip in dry-run mode)
    if [[ "$DRY_RUN" != "true" ]]; then
        wait_for_pod_availability "MSPSharedLibraries" "$VERSION"
    fi
    
    log_success "MSPSharedLibraries released successfully"
}

# Release single adapter (helper function for parallel processing)
release_single_adapter() {
    local adapter="$1"
    local version="$2"
    local result_file="$3"
    
    log_release "Releasing $adapter"
    
    # Update podspec
    if ! update_podspec_for_release "$adapter" "$version"; then
        echo "ERROR: Failed to update podspec for $adapter" > "$result_file"
        return 1
    fi
    
    # Update dependencies
    if ! update_podspec_dependencies "$adapter" "$version"; then
        echo "ERROR: Failed to update dependencies for $adapter" > "$result_file"
        return 1
    fi
    
    # Update SDK version in adapter code
    if ! update_adapter_sdk_version "$adapter" "$version"; then
        echo "ERROR: Failed to update SDK version for $adapter" > "$result_file"
        return 1
    fi
    
    # Create GitHub release
    if ! create_github_release_for_pod "$adapter" "$version"; then
        echo "ERROR: Failed to create GitHub release for $adapter" > "$result_file"
        return 1
    fi
    
    # Publish to CocoaPods
    if ! publish_pod_to_cocoapods "$adapter" "$version"; then
        echo "ERROR: Failed to publish $adapter to CocoaPods" > "$result_file"
        return 1
    fi
    
    # Note: Availability checking is done after ALL adapters are released
    echo "SUCCESS: $adapter released successfully" > "$result_file"
    return 0
}

# Release Adapters (Step 2) - Parallel Processing
release_adapters() {
    log_release "Step 2: Releasing Adapters that depend on MSPSharedLibraries (in parallel)"
    
    local adapters=("FacebookAdapter" "GoogleAdapter" "NovaAdapter" "AmazonAdapter" "PrebidAdapter")
    local pids=()
    local result_files=()
    local temp_dir="/tmp/msp_parallel_release_$$"
    
    # Create temporary directory for result files
    mkdir -p "$temp_dir"
    
    # Start all adapter releases in parallel
    for adapter in "${adapters[@]}"; do
        local result_file="$temp_dir/${adapter}_result.txt"
        result_files+=("$result_file")
        
        # Start adapter release in background
        release_single_adapter "$adapter" "$VERSION" "$result_file" &
        local pid=$!
        pids+=("$pid")
        
        log_info "Started parallel release of $adapter (PID: $pid)"
    done
    
    # Wait for all parallel processes to complete
    log_info "Waiting for all adapters to complete..."
    local success_count=0
    local failure_count=0
    local failed_adapters=()
    
    for i in "${!pids[@]}"; do
        local pid="${pids[$i]}"
        local adapter="${adapters[$i]}"
        local result_file="${result_files[$i]}"
        
        # Wait for this specific process
        if wait "$pid"; then
            # Process completed successfully
            if [[ -f "$result_file" ]] && grep -q "SUCCESS" "$result_file"; then
                log_success "$adapter released successfully"
                ((success_count++))
            else
                log_error "$adapter release failed"
                ((failure_count++))
                failed_adapters+=("$adapter")
            fi
        else
            # Process failed
            log_error "$adapter release failed (exit code: $?)"
            ((failure_count++))
            failed_adapters+=("$adapter")
        fi
        
        # Show result details
        if [[ -f "$result_file" ]]; then
            local result_content
            result_content=$(cat "$result_file")
            if [[ "$result_content" == *"ERROR"* ]]; then
                log_error "$adapter: $result_content"
            else
                log_info "$adapter: $result_content"
            fi
        fi
    done
    
    # Clean up temporary files
    rm -rf "$temp_dir"
    
    # Report final results
    log_release "Parallel adapter release completed:"
    log_info "  ✅ Successful: $success_count"
    log_info "  ❌ Failed: $failure_count"
    
    if [[ $failure_count -gt 0 ]]; then
        log_error "Failed adapters: ${failed_adapters[*]}"
        return 1
    fi
    
    log_success "All adapters released successfully in parallel"
    
    # Step 2.5: Check availability of MSPSharedLibraries and PrebidAdapter before MSPCore release
    if [[ "$DRY_RUN" != "true" ]]; then
        log_release "Step 2.5: Checking availability of dependencies for MSPCore"
        
        # Update specs repository once
        log_info "Updating CocoaPods specs repository..."
        if ! update_specs_repo; then
            log_error "Failed to update specs repository"
            return 1
        fi
        
        # Check MSPSharedLibraries availability
        log_info "Checking MSPSharedLibraries availability..."
        if ! wait_for_pod_availability "MSPSharedLibraries" "$VERSION"; then
            log_error "MSPSharedLibraries not available, cannot proceed with MSPCore release"
            return 1
        fi
        
        # Check PrebidAdapter availability (MSPCore depends on it)
        log_info "Checking PrebidAdapter availability..."
        if ! wait_for_pod_availability "PrebidAdapter" "$VERSION"; then
            log_error "PrebidAdapter not available, cannot proceed with MSPCore release"
            return 1
        fi
        
        log_success "All dependencies available for MSPCore release"
    fi
    
    return 0
}

# Release MSPCore (Step 3)
release_msp_core() {
    log_release "Step 3: Releasing MSPCore (main framework)"
    
    # Update podspec
    update_podspec_for_release "MSPCore" "$VERSION"
    
    # Update dependencies
    update_podspec_dependencies "MSPCore" "$VERSION"
    
    # Update MSPCore version property
    update_mspcore_version "$VERSION"
    
    # Create GitHub release
    create_github_release_for_pod "MSPCore" "$VERSION"
    
    # Publish to CocoaPods
    publish_pod_to_cocoapods "MSPCore" "$VERSION"
    
    # Wait for availability (skip in dry-run mode)
    if [[ "$DRY_RUN" != "true" ]]; then
        wait_for_pod_availability "MSPCore" "$VERSION"
    fi
    
    log_success "MSPCore released successfully"
}

# Commit all changes to release branch
commit_release_changes() {
    log_step "Committing all release changes to release branch"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would commit all changes"
        return 0
    fi
    
    # Add all changes
    git add .
    
    # Check if there are changes to commit
    if git diff --cached --quiet; then
        log_info "No changes to commit"
        return 0
    fi
    
    # Commit changes
    git commit -m "Release version $VERSION - Update podspecs and version numbers"
    
    log_success "Committed all release changes"
}

# Main function
main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Validate inputs
    validate_inputs
    
    # Ensure we're in the project root
    ensure_project_root
    
    # Check release branch
    check_release_branch
    
    # Record start time for duration calculation
    local start_time=$(date +%s)
    
    print_section "Starting CocoaPods Release Process for Version: $VERSION"
    
    # Generate release notes
    local release_notes=""
    if [[ -n "$RELEASE_NOTES" ]]; then
        release_notes="$RELEASE_NOTES"
        log_info "Using provided release notes"
    else
        log_step "Generating release notes from source: $RELEASE_NOTES_SOURCE"
        release_notes=$(get_release_notes "$VERSION" "CocoaPods" "$RELEASE_NOTES_SOURCE" "$RELEASE_NOTES_TEMPLATE")
    fi
    
    # Create CocoaPods-specific pod list (exclude MSPOMSDK which is SPM-only)
    local cocoapods_pods=("MSPSharedLibraries" "FacebookAdapter" "GoogleAdapter" "NovaAdapter" "AmazonAdapter" "PrebidAdapter" "MSPCore")
    
    # Skip individual start notifications - only send final success/failure
    
    # Track release statistics
    local total_pods=${#cocoapods_pods[@]}
    local successful_pods=0
    local failed_pods=0
    local failed_pod_names=()
    
    # Step 1: Release MSPSharedLibraries
    if release_msp_shared_libraries; then
        ((successful_pods++))
    else
        ((failed_pods++))
        failed_pod_names+=("MSPSharedLibraries")
        if [[ "$DRY_RUN" != "true" ]]; then
            notify_release_failure "CocoaPods" "$VERSION" "MSPSharedLibraries release failed" "Foundation Release"
        fi
        exit 1
    fi
    
    # Step 2: Release Adapters
    if release_adapters; then
        # Count successful adapters (assuming all adapters in POD_RELEASE_ORDER except MSPSharedLibraries and MSPCore)
        local adapter_count=$((${#POD_RELEASE_ORDER[@]} - 2))  # Subtract MSPSharedLibraries and MSPCore
        successful_pods=$((successful_pods + adapter_count))
    else
        # Count failed adapters
        local adapter_count=$((${#POD_RELEASE_ORDER[@]} - 2))
        failed_pods=$((failed_pods + adapter_count))
        failed_pod_names+=("Adapters")
        if [[ "$DRY_RUN" != "true" ]]; then
            notify_release_failure "CocoaPods" "$VERSION" "Adapter release failed" "Adapter Release"
        fi
        exit 1
    fi
    
    # Step 3: Release MSPCore
    if release_msp_core; then
        ((successful_pods++))
    else
        ((failed_pods++))
        failed_pod_names+=("MSPCore")
        if [[ "$DRY_RUN" != "true" ]]; then
            notify_release_failure "CocoaPods" "$VERSION" "MSPCore release failed" "Main Framework Release"
        fi
        exit 1
    fi
    
    # Commit all changes
    commit_release_changes
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local duration_formatted=$(printf "%02d:%02d:%02d" $((duration/3600)) $((duration%3600/60)) $((duration%60)))
    
    print_section "CocoaPods Release Process Completed Successfully"
    log_success "All pods released successfully for version: $VERSION"
    log_info "Release branch '$RELEASE_BRANCH' is ready to be pushed"
    
    # Send single comprehensive success notification (skip in dry-run mode)
    if [[ "$DRY_RUN" != "true" ]]; then
        local pods_list=$(IFS=", "; echo "${cocoapods_pods[*]}")
        notify_release_success_with_summary "CocoaPods" "$VERSION" "$pods_list" "$duration_formatted" "$release_notes" "$total_pods" "$successful_pods" "$failed_pods" "$RELEASE_BRANCH"
    fi
}

# Show usage if no arguments provided
if [[ $# -eq 0 ]]; then
    show_help
    exit 1
fi

# Run main function with all arguments
main "$@"
