#!/bin/bash

# MSP iOS SDK Sequential Release System v4.0.0
# Sequential release script for MSP iOS SDK with dependency management and CocoaPods sync verification.

# Script metadata
SCRIPT_VERSION="4.0.0"
SCRIPT_NAME="MSP iOS SDK Sequential Release System"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

# Pod configurations
ALWAYS_PUBLISH_PODS=("FacebookAdapter" "GoogleAdapter" "NovaAdapter")
CONDITIONAL_PUBLISH_PODS=("MSPSharedLibraries" "PrebidAdapter")
MAIN_POD="MSPCore"
ALL_PODS=("${ALWAYS_PUBLISH_PODS[@]}" "${CONDITIONAL_PUBLISH_PODS[@]}" "$MAIN_POD")

# Source-only pods (don't require building)
SOURCE_ONLY_PODS=("FacebookAdapter" "GoogleAdapter" "NovaAdapter" "MSPCore")

# Default values
VERSION=""
PUBLISH_SHARED_LIBRARIES="false"
SKIP_VALIDATION="false"
SKIP_COCOAPODS="false"
SKIP_GITHUB="false"
DRY_RUN="false"
FORCE="false"
VERBOSE="false"
REPOSITORY_URL="https://github.com/ParticleMedia/msp-ios-sdk.git"
USE_GITHUB_RELEASE="false"

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                echo "$SCRIPT_NAME v$SCRIPT_VERSION"
                exit 0
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --force)
                FORCE="true"
                shift
                ;;
            --skip-validation)
                SKIP_VALIDATION="true"
                shift
                ;;
            --skip-cocoapods)
                SKIP_COCOAPODS="true"
                shift
                ;;
            --skip-github)
                SKIP_GITHUB="true"
                shift
                ;;
            --publish-shared-libraries)
                PUBLISH_SHARED_LIBRARIES="true"
                shift
                ;;
            --repository)
                REPOSITORY_URL="$2"
                shift 2
                ;;
            --github-release)
                USE_GITHUB_RELEASE="true"
                shift
                ;;
            --verbose)
                VERBOSE="true"
                shift
                ;;
            --version=*)
                VERSION="${1#*=}"
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                if [[ -z "$VERSION" ]]; then
                    VERSION="$1"
                else
                    log_error "Multiple versions specified: $VERSION and $1"
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

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
    --skip-validation             Skip podspec validation
    --skip-cocoapods              Skip CocoaPods publishing
    --skip-github                 Skip GitHub release creation
    --publish-shared-libraries    Publish MSPSharedLibraries and PrebidAdapter
    --repository URL              Set repository URL for podspec source
    --github-release              Use GitHub releases with zip files (like 0.0.1-migration)
    --verbose                     Enable verbose output

ENVIRONMENT VARIABLES:
    COCOAPODS_TRUNK_TOKEN         CocoaPods trunk token for publishing
    GITHUB_TOKEN                  GitHub token for releases

RELEASE PROCESS:
    1. Always publish: FacebookAdapter, GoogleAdapter, NovaAdapter (same version)
    2. Conditionally publish: MSPSharedLibraries, PrebidAdapter (if --publish-shared-libraries)
    3. Update MSPCore dependencies (if MSPSharedLibraries/PrebidAdapter published)
    4. Publish MSPCore
    5. Create release branch: release/(version_number)

EXAMPLES:
    # Release all adapters + MSPCore (no shared libraries)
    $0 1.2.3

    # Release with shared libraries (full release)
    $0 --publish-shared-libraries 1.2.3

    # Dry run to see what would be released
    $0 --dry-run 1.2.3
EOF
}

# Validation functions
validate_environment() {
    log_step "Validating release environment..."
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not in a git repository"
        return 1
    fi
    
    # Check if working directory is clean (unless force mode)
    if [[ "$FORCE" != "true" ]] && ! git diff-index --quiet HEAD --; then
        log_warn "Git working directory is not clean. Please commit or stash changes."
        log_info "Use --force to override this check"
        return 1
    fi
    
    # Check required tools
    local required_tools=("git" "xcodebuild")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_error "Required tool not found: $tool"
            return 1
        fi
    done
    
    # Check CocoaPods if not skipping
    if [[ "$SKIP_COCOAPODS" != "true" ]] && ! command -v pod >/dev/null 2>&1; then
        log_error "CocoaPods not found. Install with: gem install cocoapods"
        return 1
    fi
    
    log_success "Release environment validation passed"
    return 0
}

validate_version() {
    local version="$1"
    
    if [[ -z "$version" ]]; then
        log_error "Version is required"
        return 1
    fi
    
    # Basic semantic version validation (allow more flexible formats)
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9-]+)?(\+[a-zA-Z0-9-]+)?$ ]]; then
        log_error "Invalid version format: $version. Expected: X.Y.Z[-prerelease][+build]"
        return 1
    fi
    
    log_success "Version validation passed: $version"
    return 0
}

validate_repository_url() {
    local repository_url="$1"
    
    if [[ -z "$repository_url" ]]; then
        log_error "Repository URL is required"
        return 1
    fi
    
    # Check if it's a valid GitHub URL
    if [[ ! "$repository_url" =~ ^https://github\.com/[^/]+/[^/]+\.git$ ]]; then
        log_error "Invalid repository URL format: $repository_url. Expected: https://github.com/owner/repo.git"
        return 1
    fi
    
    log_success "Repository URL validation passed: $repository_url"
    return 0
}

# Check if a pod version is already published to CocoaPods
check_pod_version_published() {
    local pod_name="$1"
    local version="$2"
    
    log_step "Checking if $pod_name version $version is already published to CocoaPods..."
    
    # Check if pod search command is available
    if ! command -v pod >/dev/null 2>&1; then
        log_warn "CocoaPods not available, cannot check if version is published"
        return 1
    fi
    
    # Update pod repo to get latest information
    if ! pod repo update >/dev/null 2>&1; then
        log_warn "Failed to update pod repo, using cached information"
    fi
    
    # Check if the specific version exists
    if pod search "$pod_name" --simple 2>/dev/null | grep -q "$version"; then
        log_warn "Version $version of $pod_name is already published to CocoaPods"
        return 0
    else
        log_info "Version $version of $pod_name is not published to CocoaPods"
        return 1
    fi
}

# Branch management
create_release_branch() {
    local version="$1"
    local branch_name="release/$version"
    
    log_step "Creating release branch: $branch_name"
    
    # Check if branch already exists
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        log_warn "Branch $branch_name already exists. Checking it out..."
        if ! git checkout "$branch_name"; then
            log_error "Failed to checkout existing branch: $branch_name"
            return 1
        fi
    else
        # Create new branch
        if ! git checkout -b "$branch_name"; then
            log_error "Failed to create branch: $branch_name"
            return 1
        fi
    fi
    
    log_success "Release branch ready: $branch_name"
    return 0
}

# Podspec management
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

update_podspec_repository_url() {
    local pod_name="$1"
    local repository_url="$2"
    
    log_step "Updating $pod_name podspec repository URL to $repository_url..."
    
    local podspec_file="${pod_name}.podspec"
    if [[ ! -f "$podspec_file" ]]; then
        log_error "Podspec not found: $podspec_file"
        return 1
    fi
    
    # Update repository URL in podspec
    if sed -i.bak "s|spec\.source.*=.*{ :git => \".*\", :tag => \"#{spec\.version}\" }|spec.source       = { :git => \"$repository_url\", :tag => \"#{spec.version}\" }|" "$podspec_file"; then
        rm -f "${podspec_file}.bak"
        log_success "Updated $pod_name podspec repository URL to $repository_url"
        return 0
    else
        log_error "Failed to update $pod_name podspec repository URL"
        return 1
    fi
}

update_mspcore_dependencies() {
    local msp_shared_version="$1"
    local prebid_version="$2"
    
    log_step "Updating MSPCore dependencies..."
    
    local podspec_file="MSPCore.podspec"
    if [[ ! -f "$podspec_file" ]]; then
        log_error "MSPCore podspec not found: $podspec_file"
        return 1
    fi
    
    # Update MSPSharedLibraries dependency
    if sed -i.bak "s/spec\.dependency 'MSPSharedLibraries'[^']*/spec.dependency 'MSPSharedLibraries', '$msp_shared_version'/" "$podspec_file"; then
        log_success "Updated MSPCore MSPSharedLibraries dependency to $msp_shared_version"
    else
        log_warn "Failed to update MSPSharedLibraries dependency"
    fi
    
    # Update PrebidAdapter dependency
    if sed -i.bak "s/spec\.dependency 'PrebidAdapter'[^']*/spec.dependency 'PrebidAdapter', '$prebid_version'/" "$podspec_file"; then
        log_success "Updated MSPCore PrebidAdapter dependency to $prebid_version"
    else
        log_warn "Failed to update PrebidAdapter dependency"
    fi
    
    # Clean up backup file
    rm -f "${podspec_file}.bak"
    
    return 0
}

# Release functions
release_single_pod() {
    local pod_name="$1"
    local version="$2"
    local skip_validation="$3"
    
    log_release "Releasing $pod_name version $version"
    
    # Check if version is already published to CocoaPods
    if check_pod_version_published "$pod_name" "$version"; then
        log_warn "Version $version of $pod_name is already published to CocoaPods, skipping release"
        return 0
    fi
    
    # Update podspec version
    if ! update_podspec_version "$pod_name" "$version"; then
        return 1
    fi
    
    # Update podspec repository URL if provided
    if [[ -n "$REPOSITORY_URL" ]] && ! update_podspec_repository_url "$pod_name" "$REPOSITORY_URL"; then
        return 1
    fi
    
    # Use release.sh for the actual release
    local release_cmd="./Scripts/release.sh --force"
    
    if [[ "$skip_validation" == "true" ]]; then
        release_cmd="$release_cmd --skip-validation"
    fi
    
    if [[ "$SKIP_COCOAPODS" == "true" ]]; then
        release_cmd="$release_cmd --skip-cocoapods"
    fi
    
    if [[ "$SKIP_GITHUB" == "true" ]]; then
        release_cmd="$release_cmd --skip-github"
    fi
    
    if [[ -n "$REPOSITORY_URL" ]]; then
        release_cmd="$release_cmd --repository $REPOSITORY_URL"
    fi
    
    if [[ "$USE_GITHUB_RELEASE" == "true" ]]; then
        release_cmd="$release_cmd --github-release"
    fi
    
    release_cmd="$release_cmd $pod_name $version"
    
    log_info "Executing: $release_cmd"
    
    if eval "$release_cmd"; then
        log_success "Successfully released $pod_name version $version"
        return 0
    else
        log_error "Failed to release $pod_name version $version"
        return 1
    fi
}

# CocoaPods sync verification
wait_for_cocoapods_sync() {
    local pod_name="$1"
    local version="$2"
    local max_attempts=10
    local base_delay=30
    local attempt=1
    
    log_step "Waiting for CocoaPods to sync $pod_name version $version..."
    
    while [[ $attempt -le $max_attempts ]]; do
        local delay=$((base_delay * (2 ** (attempt - 1))))
        
        log_info "Attempt $attempt/$max_attempts: Waiting ${delay}s before checking..."
        sleep "$delay"
        
        if pod search "$pod_name" --simple | grep -q "$version"; then
            log_success "CocoaPods sync confirmed: $pod_name version $version is available"
            return 0
        fi
        
        log_warn "CocoaPods sync not yet complete for $pod_name version $version"
        ((attempt++))
    done
    
    log_error "CocoaPods sync timeout: $pod_name version $version not found after $max_attempts attempts"
    return 1
}

# Concurrent publishing functions
publish_pod_concurrent() {
    local pod_name="$1"
    local version="$2"
    local skip_validation="$3"
    local log_file="/tmp/release_${pod_name}_${version}.log"
    
    log_info "Starting concurrent release of $pod_name version $version (log: $log_file)"
    
    # Run release in background and capture output
    {
        echo "=== Starting release of $pod_name version $version at $(date) ==="
        release_single_pod "$pod_name" "$version" "$skip_validation"
        local exit_code=$?
        echo "=== Release of $pod_name version $version completed with exit code $exit_code at $(date) ==="
        exit $exit_code
    } > "$log_file" 2>&1 &
    
    local pid=$!
    echo "$pid:$log_file:$pod_name:$version"
}

wait_for_concurrent_releases() {
    local release_info=("$@")
    local failed_pods=()
    local success_pods=()
    
    log_step "Waiting for all concurrent releases to complete..."
    
    # Wait for all background processes
    for info in "${release_info[@]}"; do
        IFS=':' read -r pid log_file pod_name version <<< "$info"
        
        log_info "Waiting for $pod_name (PID: $pid)..."
        if wait $pid; then
            log_success "✅ $pod_name version $version released successfully"
            success_pods+=("$pod_name")
        else
            log_error "❌ $pod_name version $version failed to release"
            failed_pods+=("$pod_name")
            log_error "Check log file for details: $log_file"
        fi
    done
    
    # Report results
    if [[ ${#failed_pods[@]} -eq 0 ]]; then
        log_success "All concurrent releases completed successfully: ${success_pods[*]}"
        return 0
    else
        log_error "Some releases failed: ${failed_pods[*]}"
        log_error "Successful releases: ${success_pods[*]}"
        return 1
    fi
}

check_all_pods_published() {
    local version="$1"
    shift
    local pods=("$@")
    
    log_step "Verifying all pods are published to CocoaPods..."
    
    local failed_checks=()
    for pod in "${pods[@]}"; do
        if ! check_pod_version_published "$pod" "$version"; then
            failed_checks+=("$pod")
        fi
    done
    
    if [[ ${#failed_checks[@]} -eq 0 ]]; then
        log_success "All pods verified as published: ${pods[*]}"
        return 0
    else
        log_error "Some pods not found in CocoaPods: ${failed_checks[*]}"
        return 1
    fi
}

# Main release process
perform_sequential_release() {
    local version="$1"
    
    print_section "Starting Sequential Release Process"
    log_release "Releasing version $version"
    
    # Create release branch
    if ! create_release_branch "$version"; then
        return 1
    fi
    
    # Step 1: Always publish adapters (FacebookAdapter, GoogleAdapter, NovaAdapter)
    print_section "Step 1: Publishing Adapter Pods"
    for pod in "${ALWAYS_PUBLISH_PODS[@]}"; do
        if ! release_single_pod "$pod" "$version" "$SKIP_VALIDATION"; then
            log_error "Failed to release $pod. Aborting sequential release."
            return 1
        fi
    done
    
    # Step 2: Conditionally publish shared libraries (concurrently)
    if [[ "$PUBLISH_SHARED_LIBRARIES" == "true" ]]; then
        print_section "Step 2: Publishing Shared Library Pods (Concurrently)"
        
        # Start all conditional pods concurrently
        local release_info=()
        for pod in "${CONDITIONAL_PUBLISH_PODS[@]}"; do
            local info=$(publish_pod_concurrent "$pod" "$version" "$SKIP_VALIDATION")
            release_info+=("$info")
        done
        
        # Wait for all concurrent releases to complete
        if ! wait_for_concurrent_releases "${release_info[@]}"; then
            log_error "Some concurrent releases failed. Aborting sequential release."
            return 1
        fi
        
        # Verify all pods are published to CocoaPods
        if [[ "$SKIP_COCOAPODS" != "true" ]]; then
            if ! check_all_pods_published "$version" "${CONDITIONAL_PUBLISH_PODS[@]}"; then
                log_error "Not all conditional pods are available in CocoaPods. Aborting sequential release."
                return 1
            fi
        fi
        
        # Update MSPCore dependencies
        if ! update_mspcore_dependencies "$version" "$version"; then
            log_error "Failed to update MSPCore dependencies. Aborting sequential release."
            return 1
        fi
    fi
    
    # Step 3: Publish MSPCore
    print_section "Step 3: Publishing MSPCore"
    if ! release_single_pod "$MAIN_POD" "$version" "$SKIP_VALIDATION"; then
        log_error "Failed to release $MAIN_POD. Aborting sequential release."
        return 1
    fi
    
    # Step 4: Commit all changes
    print_section "Step 4: Committing Changes"
    if ! git add -A && git commit -m "Release $version: Update all podspecs and dependencies"; then
        log_error "Failed to commit changes"
        return 1
    fi
    
    if ! git push origin "release/$version"; then
        log_error "Failed to push release branch"
        return 1
    fi
    
    log_success "Release branch pushed: release/$version"
    
    print_section "Sequential Release Completed Successfully"
    log_success "🎉 All pods released successfully with version $version!"
    
    if [[ "$PUBLISH_SHARED_LIBRARIES" == "true" ]]; then
        log_info "Published pods: ${ALWAYS_PUBLISH_PODS[*]}, ${CONDITIONAL_PUBLISH_PODS[*]}, $MAIN_POD"
    else
        log_info "Published pods: ${ALWAYS_PUBLISH_PODS[*]}, $MAIN_POD"
    fi
    
    log_info "Release branch: release/$version"
    log_info "All changes committed and pushed"
    
    return 0
}

# Dry run function
perform_dry_run() {
    local version="$1"
    
    print_section "Dry Run - What Would Be Released"
    log_info "Version: $version"
    log_info "Publish shared libraries: $PUBLISH_SHARED_LIBRARIES"
    log_info "Skip validation: $SKIP_VALIDATION"
    log_info "Skip CocoaPods: $SKIP_COCOAPODS"
    log_info "Skip GitHub: $SKIP_GITHUB"
    log_info "Force mode: $FORCE"
    
    echo ""
    log_info "Release plan:"
    echo "1. Create branch: release/$version"
    echo "2. Always publish: ${ALWAYS_PUBLISH_PODS[*]} (version $version)"
    
    if [[ "$PUBLISH_SHARED_LIBRARIES" == "true" ]]; then
        echo "3. Publish shared libraries concurrently: ${CONDITIONAL_PUBLISH_PODS[*]} (version $version)"
        echo "4. Wait for all concurrent releases to complete"
        echo "5. Verify all pods are published to CocoaPods"
        echo "6. Update MSPCore dependencies to version $version"
        echo "7. Publish: $MAIN_POD (version $version)"
        echo "8. Commit and push all changes"
    else
        echo "3. Skip shared libraries publishing"
        echo "4. Publish: $MAIN_POD (version $version)"
        echo "5. Commit and push all changes"
    fi
    
    return 0
}

# Main function
main() {
    ensure_project_root
    
    parse_arguments "$@"
    
    print_section "$SCRIPT_NAME"
    log_info "Version: $SCRIPT_VERSION"
    
    # Validate inputs
    if ! validate_environment; then
        exit 1
    fi
    
    if ! validate_version "$VERSION"; then
        exit 1
    fi
    
    # Perform release or dry run
    if [[ "$DRY_RUN" == "true" ]]; then
        perform_dry_run "$VERSION"
    else
        perform_sequential_release "$VERSION"
    fi
}

# Run main function with all arguments
main "$@"