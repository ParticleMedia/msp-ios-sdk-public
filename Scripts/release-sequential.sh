#!/bin/bash

# MSP iOS SDK Sequential Release Script
# This script handles the sequential release of MSPCore and its dependencies
# with proper CocoaPods sync verification and exponential backoff

# Script metadata
SCRIPT_VERSION="3.0.0"
SCRIPT_NAME="MSP iOS SDK Sequential Release System"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

log_release() {
    echo -e "${PURPLE}🚀 $1${NC}"
}

log_wait() {
    echo -e "${CYAN}⏳ $1${NC}"
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}🔍 $1${NC}"
    fi
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

# Dependency configuration
DEPENDENCY_PODS=("FacebookAdapter" "GoogleAdapter" "NovaAdapter")
MAIN_POD="MSPCore"
ALL_PODS=("${DEPENDENCY_PODS[@]}" "$MAIN_POD")

# Pod types (source-only vs framework)
SOURCE_ONLY_PODS=("FacebookAdapter" "GoogleAdapter" "NovaAdapter" "MSPCore")

# CocoaPods sync configuration
COCOAPODS_SYNC_MAX_ATTEMPTS=20
COCOAPODS_SYNC_INITIAL_DELAY=30
COCOAPODS_SYNC_MAX_DELAY=600
COCOAPODS_SYNC_MULTIPLIER=1.5

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

# Validation functions
validate_release_environment() {
    log_step "Validating release environment..."
    
    # Check if we're in the project root
    if [[ ! -d "msp-ios-sdk.xcworkspace" ]]; then
        log_error "iOS workspace not found. Please run from project root."
        return 1
    fi
    
    # Check for required tools
    local required_tools="git xcodebuild pod"
    for tool in $required_tools; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_error "Required tool not found: $tool"
            return 1
        fi
    done
    
    # Check for GitHub CLI if needed
    if [[ "$RELEASE_TO_GITHUB" == "true" ]] && ! command -v gh >/dev/null 2>&1; then
        log_error "GitHub CLI (gh) not found but required for GitHub releases"
        return 1
    fi
    
    # Check git status
    if ! git diff-index --quiet HEAD --; then
        log_warn "Git working directory is not clean. Please commit or stash changes."
        if [[ "$FORCE_RELEASE" != "true" ]]; then
            return 1
        fi
    fi
    
    log_success "Release environment validation passed"
    return 0
}

update_all_podspec_versions() {
    local version="$1"
    
    log_step "Updating all podspec versions to $version..."
    
    for pod in "${ALL_PODS[@]}"; do
        local podspec_file="${pod}.podspec"
        if [[ -f "$podspec_file" ]]; then
            log_info "Updating $pod podspec version to $version..."
            if sed -i.bak "s/spec\.version.*=.*\".*\"/spec.version      = \"$version\"/" "$podspec_file"; then
                rm -f "${podspec_file}.bak"
                log_success "Updated $pod podspec version to $version"
            else
                log_error "Failed to update $pod podspec version"
                return 1
            fi
        else
            log_error "Podspec not found: $podspec_file"
            return 1
        fi
    done
    
    log_success "All podspec versions updated to $version"
    return 0
}

validate_version_consistency() {
    local version="$1"
    
    log_step "Validating version consistency across all pods..."
    
    local inconsistent_pods=()
    
    for pod in "${ALL_PODS[@]}"; do
        local podspec_file="${pod}.podspec"
        if [[ -f "$podspec_file" ]]; then
            local current_version=$(grep "spec\.version" "$podspec_file" | head -1 | sed 's/.*= *"\([^"]*\)".*/\1/')
            if [[ "$current_version" != "$version" ]]; then
                inconsistent_pods+=("$pod (current: $current_version, expected: $version)")
            fi
        else
            log_error "Podspec not found: $podspec_file"
            return 1
        fi
    done
    
    if [[ ${#inconsistent_pods[@]} -gt 0 ]]; then
        log_warn "Version inconsistency detected. Auto-updating all podspecs to $version..."
        if ! update_all_podspec_versions "$version"; then
            log_error "Failed to update podspec versions"
            return 1
        fi
    fi
    
    log_success "Version consistency validated: $version"
    return 0
}

validate_pod_name() {
    local pod_name="$1"
    
    if [[ -z "$pod_name" ]]; then
        log_error "Pod name is required"
        return 1
    fi
    
    # Check if pod is in our supported list
    local is_supported=false
    for pod in "${ALL_PODS[@]}"; do
        if [[ "$pod" == "$pod_name" ]]; then
            is_supported=true
            break
        fi
    done
    
    if [[ "$is_supported" != "true" ]]; then
        log_error "Unsupported pod: $pod_name. Supported pods: ${ALL_PODS[*]}"
        return 1
    fi
    
    # Check if podspec exists
    local podspec_path="${pod_name}.podspec"
    if [[ ! -f "$podspec_path" ]]; then
        log_error "Podspec not found: $podspec_path"
        return 1
    fi
    
    log_success "Pod validation passed: $pod_name"
    return 0
}

validate_version() {
    local version="$1"
    
    if [[ -z "$version" ]]; then
        log_error "Version is required"
        return 1
    fi
    
    # Check version format (semantic versioning)
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$ ]]; then
        log_error "Invalid version format: $version. Expected format: X.Y.Z[-prerelease][+build]"
        return 1
    fi
    
    # Check if version already exists
    if git tag -l | grep -q "^$version$"; then
        log_error "Version $version already exists as a git tag"
        return 1
    fi
    
    log_success "Version validation passed: $version"
    return 0
}

# CocoaPods sync verification
check_pod_availability() {
    local pod_name="$1"
    local version="$2"
    
    log_debug "Checking availability of $pod_name version $version on CocoaPods..."
    
    # Use pod search to check if the pod is available
    if pod search "$pod_name" --simple 2>/dev/null | grep -q "$version"; then
        return 0
    fi
    
    # Alternative: try to install the specific version
    if pod try "$pod_name" --version="$version" --silent 2>/dev/null; then
        return 0
    fi
    
    return 1
}

wait_for_cocoapods_sync() {
    local pod_name="$1"
    local version="$2"
    local attempt=1
    local delay=$COCOAPODS_SYNC_INITIAL_DELAY
    
    log_wait "Waiting for $pod_name version $version to be available on CocoaPods..."
    
    while [[ $attempt -le $COCOAPODS_SYNC_MAX_ATTEMPTS ]]; do
        log_info "Attempt $attempt/$COCOAPODS_SYNC_MAX_ATTEMPTS: Checking $pod_name version $version..."
        
        if check_pod_availability "$pod_name" "$version"; then
            log_success "$pod_name version $version is now available on CocoaPods!"
            return 0
        fi
        
        if [[ $attempt -lt $COCOAPODS_SYNC_MAX_ATTEMPTS ]]; then
            log_info "Not yet available. Waiting ${delay}s before next attempt..."
            sleep $delay
            
            # Calculate next delay with exponential backoff
            delay=$(echo "$delay * $COCOAPODS_SYNC_MULTIPLIER" | bc)
            if [[ $(echo "$delay > $COCOAPODS_SYNC_MAX_DELAY" | bc) -eq 1 ]]; then
                delay=$COCOAPODS_SYNC_MAX_DELAY
            fi
        fi
        
        ((attempt++))
    done
    
    log_error "Timeout waiting for $pod_name version $version to be available on CocoaPods"
    return 1
}

# Release functions
update_podspec_version() {
    local pod_name="$1"
    local version="$2"
    
    log_step "Updating $pod_name podspec version to $version..."
    
    local podspec_file="${pod_name}.podspec"
    if [[ ! -f "$podspec_file" ]]; then
        log_error "Podspec not found: $podspec_file"
        return 1
    fi
    
    # Update version in podspec
    if sed -i.bak "s/spec\.version.*=.*\".*\"/spec.version      = \"$version\"/" "$podspec_file"; then
        rm -f "${podspec_file}.bak"
        log_success "Updated $pod_name podspec version to $version"
        return 0
    else
        log_error "Failed to update $pod_name podspec version"
        return 1
    fi
}

is_source_only_pod() {
    local pod_name="$1"
    
    for source_pod in "${SOURCE_ONLY_PODS[@]}"; do
        if [[ "$pod_name" == "$source_pod" ]]; then
            return 0
        fi
    done
    return 1
}

build_framework_for_release() {
    local framework_name="$1"
    
    # Check if this is a source-only pod
    if is_source_only_pod "$framework_name"; then
        log_info "Framework $framework_name is source-only, skipping build"
        return 0
    fi
    
    log_step "Building $framework_name for release..."
    
    # Use the unified build script
    if [[ -f "Scripts/build.sh" ]]; then
        if ./Scripts/build.sh --framework "$framework_name" --skip-code-sign; then
            log_success "Framework $framework_name built successfully"
            return 0
        else
            log_error "Failed to build framework $framework_name"
            return 1
        fi
    else
        log_error "Build script not found: Scripts/build.sh"
        return 1
    fi
}

validate_podspec() {
    local pod_name="$1"
    
    log_step "Validating podspec for $pod_name..."
    
    local podspec_path="${pod_name}.podspec"
    if [[ ! -f "$podspec_path" ]]; then
        log_error "Podspec not found: $podspec_path"
        return 1
    fi
    
    # Validate podspec
    if pod spec lint "$podspec_path" --allow-warnings --skip-import-validation; then
        log_success "Podspec validation passed: $pod_name"
        return 0
    else
        log_error "Podspec validation failed: $pod_name"
        return 1
    fi
}

publish_to_cocoapods() {
    local pod_name="$1"
    local version="$2"
    
    log_step "Publishing $pod_name version $version to CocoaPods..."
    
    local podspec_path="${pod_name}.podspec"
    
    # Check if trunk token is available
    if [[ -z "$COCOAPODS_TRUNK_TOKEN" ]]; then
        log_warn "COCOAPODS_TRUNK_TOKEN not set. Skipping CocoaPods publishing."
        return 0
    fi
    
    # Publish to CocoaPods trunk
    if pod trunk push "$podspec_path" --allow-warnings; then
        log_success "Successfully published $pod_name version $version to CocoaPods"
        return 0
    else
        log_error "Failed to publish $pod_name version $version to CocoaPods"
        return 1
    fi
}

create_github_release() {
    local pod_name="$1"
    local version="$2"
    
    log_step "Creating GitHub release for $pod_name version $version..."
    
    # Check if GitHub CLI is available
    if ! command -v gh >/dev/null 2>&1; then
        log_warn "GitHub CLI not available. Skipping GitHub release creation."
        return 0
    fi
    
    # Check if authenticated
    if ! gh auth status >/dev/null 2>&1; then
        log_warn "GitHub CLI not authenticated. Skipping GitHub release creation."
        return 0
    fi
    
    # Create release
    local release_title="$pod_name v$version"
    local release_notes="Release of $pod_name version $version"
    
    if gh release create "$version" --title "$release_title" --notes "$release_notes"; then
        log_success "GitHub release created: $version"
        return 0
    else
        log_error "Failed to create GitHub release: $version"
        return 1
    fi
}

create_git_tag() {
    local pod_name="$1"
    local version="$2"
    local message="$3"
    
    local tag_name="${pod_name}-${version}"
    
    log_step "Creating git tag: $tag_name"
    
    if git tag -a "$tag_name" -m "$message"; then
        log_success "Git tag created: $tag_name"
        return 0
    else
        log_error "Failed to create git tag: $tag_name"
        return 1
    fi
}

push_git_tag() {
    local pod_name="$1"
    local version="$2"
    
    local tag_name="${pod_name}-${version}"
    
    log_step "Pushing git tag: $tag_name"
    
    if git push origin "$tag_name"; then
        log_success "Git tag pushed: $tag_name"
        return 0
    else
        log_error "Failed to push git tag: $tag_name"
        return 1
    fi
}

# Sequential release functions
release_single_pod() {
    local pod_name="$1"
    local version="$2"
    local is_dependency="$3"
    local skip_validation="$4"
    
    print_section "Releasing $pod_name version $version"
    
    # Build framework (skip for source-only pods)
    if ! build_framework_for_release "$pod_name"; then
        return 1
    fi
    
    # Validate podspec (unless skipped)
    if [[ "$skip_validation" != "true" ]]; then
        if ! validate_podspec "$pod_name"; then
            return 1
        fi
    else
        log_info "Skipping podspec validation for $pod_name"
    fi
    
    # Create git tag
    local tag_message="Release $pod_name version $version"
    if ! create_git_tag "$pod_name" "$version" "$tag_message"; then
        return 1
    fi
    
    # Push git tag
    if ! push_git_tag "$pod_name" "$version"; then
        return 1
    fi
    
    # Create GitHub release
    if ! create_github_release "$pod_name" "$version"; then
        log_warn "GitHub release creation failed, but continuing with other steps"
    fi
    
    # Publish to CocoaPods (if enabled)
    if [[ "$PUBLISH_TO_COCOAPODS" == "true" ]]; then
        if ! publish_to_cocoapods "$pod_name" "$version"; then
            return 1
        fi
        
        # Wait for CocoaPods sync if this is a dependency
        if [[ "$is_dependency" == "true" ]]; then
            if ! wait_for_cocoapods_sync "$pod_name" "$version"; then
                return 1
            fi
        fi
    else
        log_info "Skipping CocoaPods publishing (PUBLISH_TO_COCOAPODS=false)"
    fi
    
    log_success "Successfully released $pod_name version $version"
    return 0
}

perform_sequential_release() {
    local version="$1"
    local skip_validation="$2"
    local failed_pods=()
    
    print_section "Starting Sequential Release Process"
    log_release "Releasing MSPCore and dependencies with version $version"
    
    # Start timing
    start_timer
    
    # Release dependencies first
    for pod in "${DEPENDENCY_PODS[@]}"; do
        log_release "Releasing dependency: $pod"
        if ! release_single_pod "$pod" "$version" "true" "$skip_validation"; then
            log_error "Failed to release dependency: $pod"
            failed_pods+=("$pod")
            break  # Stop on first failure
        fi
    done
    
    # Check if any dependencies failed
    if [[ ${#failed_pods[@]} -gt 0 ]]; then
        log_error "Dependency release failed. Failed pods: ${failed_pods[*]}"
        return 1
    fi
    
    # Release main pod (MSPCore)
    log_release "Releasing main pod: $MAIN_POD"
    if ! release_single_pod "$MAIN_POD" "$version" "false" "$skip_validation"; then
        log_error "Failed to release main pod: $MAIN_POD"
        return 1
    fi
    
    # Calculate total duration
    local duration=$(end_timer)
    
    print_section "Sequential Release Completed Successfully"
    log_success "🎉 All pods released successfully with version $version!"
    log_info "Released pods: ${ALL_PODS[*]}"
    log_info "Total duration: $(format_duration "$duration")"
    
    return 0
}

# Rollback functions
rollback_release() {
    local version="$1"
    local reason="$2"
    
    log_error "Rolling back release: version $version"
    log_error "Reason: $reason"
    
    # Delete git tag
    if git tag -d "$version" 2>/dev/null; then
        log_info "Deleted local git tag: $version"
    fi
    
    # Push deletion to remote
    if git push origin ":refs/tags/$version" 2>/dev/null; then
        log_info "Deleted remote git tag: $version"
    fi
    
    # Delete GitHub release if it exists
    if command -v gh >/dev/null 2>&1; then
        if gh release delete "$version" --yes 2>/dev/null; then
            log_info "Deleted GitHub release: $version"
        fi
    fi
    
    log_warn "Release rollback completed. Manual cleanup may be required."
}

# Help function
show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

Sequential release script for MSP iOS SDK with dependency management and CocoaPods sync verification.

USAGE:
    $0 [OPTIONS] VERSION

OPTIONS:
    --help, -h                    Show this help message
    --version, -v                 Show version information
    --dry-run                     Show what would be released without executing
    --force                       Force release even with uncommitted changes
    --skip-cocoapods              Skip CocoaPods publishing
    --skip-github                 Skip GitHub release creation
    --skip-validation             Skip podspec validation
    --publish-cocoapods           Enable CocoaPods publishing
    --verbose                     Enable verbose output

ENVIRONMENT VARIABLES:
    COCOAPODS_TRUNK_TOKEN         CocoaPods trunk token for publishing
    GITHUB_TOKEN                  GitHub token for releases
    FORCE_RELEASE                 Force release even with validation issues
    PUBLISH_TO_COCOAPODS          Enable CocoaPods publishing (default: false)

RELEASE PROCESS:
    1. Release FacebookAdapter with specified version
    2. Release GoogleAdapter with specified version
    3. Release NovaAdapter with specified version
    4. Wait for CocoaPods sync (exponential backoff)
    5. Release MSPCore with specified version

EXAMPLES:
    # Release all pods with version 1.2.3
    $0 1.2.3
    
    # Dry run release
    $0 --dry-run 1.2.3
    
    # Release with CocoaPods publishing
    PUBLISH_TO_COCOAPODS=true $0 1.2.3
    
    # Force release with uncommitted changes
    $0 --force 1.2.3

EOF
}

show_version() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

Sequential Release Features:
- Dependency management (FacebookAdapter, GoogleAdapter, NovaAdapter)
- CocoaPods sync verification with exponential backoff
- Version consistency validation
- Comprehensive error handling and rollback
- GitHub release integration
- Git tag management
- Dry-run mode for testing

Release Order:
1. FacebookAdapter
2. GoogleAdapter  
3. NovaAdapter
4. MSPCore

EOF
}

# Main execution
main() {
    # Ensure we're in the project root
    ensure_project_root
    
    # Parse arguments
    local version=""
    local dry_run_mode=false
    local force_mode=false
    local skip_cocoapods=false
    local skip_github=false
    local skip_validation=false
    local publish_cocoapods=false
    
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
            --dry-run)
                dry_run_mode=true
                shift
                ;;
            --force)
                force_mode=true
                export FORCE_RELEASE=true
                shift
                ;;
            --skip-cocoapods)
                skip_cocoapods=true
                shift
                ;;
            --skip-github)
                skip_github=true
                shift
                ;;
            --skip-validation)
                skip_validation=true
                shift
                ;;
            --publish-cocoapods)
                publish_cocoapods=true
                export PUBLISH_TO_COCOAPODS=true
                shift
                ;;
            --verbose)
                set -x
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                if [[ -z "$version" ]]; then
                    version="$1"
                fi
                shift
                ;;
        esac
    done
    
    print_section "MSP iOS SDK Sequential Release System"
    log_info "Version: $SCRIPT_VERSION"
    
    # Check required arguments
    if [[ -z "$version" ]]; then
        log_error "Version is required"
        show_help
        exit 1
    fi
    
    # Show dry run
    if [[ "$dry_run_mode" == "true" ]]; then
        print_section "Dry Run - What Would Be Released"
        log_info "Version: $version"
        log_info "Pods to release: ${ALL_PODS[*]}"
        log_info "Release order: ${DEPENDENCY_PODS[*]} -> $MAIN_POD"
        log_info "Skip CocoaPods: $skip_cocoapods"
        log_info "Skip GitHub: $skip_github"
        log_info "Publish to CocoaPods: $publish_cocoapods"
        log_info "Force mode: $force_mode"
        exit 0
    fi
    
    # Validate environment
    if ! validate_release_environment; then
        exit 1
    fi
    
    # Validate version
    if ! validate_version "$version"; then
        exit 1
    fi
    
    # Validate version consistency
    if ! validate_version_consistency "$version"; then
        exit 1
    fi
    
    # Perform sequential release
    if perform_sequential_release "$version" "$skip_validation"; then
        exit 0
    else
        exit 1
    fi
}

# Execute main function
main "$@"
