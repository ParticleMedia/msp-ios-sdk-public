#!/bin/bash

# Modular SPM Release Script
# Releases Swift Package Manager packages

set -e

# Source the common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/Scripts/lib/release-common.sh"

# Default values
VERSION=""
RELEASE_BRANCH=""
RELEASE_NOTES=""
DRY_RUN="false"
VERBOSE="false"

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                echo "Modular SPM Release Script v1.0.0"
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
            --verbose)
                VERBOSE="true"
                shift
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
    echo "  --release-branch BRANCH Release branch to work on (default: release/VERSION)"
    echo "  --release-notes NOTES   Release notes for this version"
    echo "  --dry-run               Show what would be done without executing"
    echo "  --verbose               Enable verbose output"
    echo "  --help, -h              Show this help message"
    echo "  --version, -v           Show version information"
    echo ""
    echo "SPM Release Workflow:"
    echo "  1. Update NovaCore Package.swift version"
    echo "  2. Update NovaAdapter Package.swift version and dependency"
    echo "  3. Create git tags for SPM packages"
    echo "  4. Push tags to remote"
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
    
    log_info "SPM release configuration:"
    log_info "  Version: $VERSION"
    log_info "  Release Branch: $RELEASE_BRANCH"
    log_info "  Dry Run: $DRY_RUN"
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

# Update Package.swift version
update_package_swift_version() {
    local package_file="$1"
    local version="$2"
    
    if [[ ! -f "$package_file" ]]; then
        log_warning "Package.swift not found: $package_file"
        return 0
    fi
    
    log_step "Updating version in $package_file to $version"
    
    # Create backup
    cp "$package_file" "${package_file}.backup"
    
    # Update version in Package.swift
    sed -i '' "s|let version = \".*\"|let version = \"${version}\"|g" "$package_file"
    
    log_success "Updated version in $package_file"
}

# Update Package.swift dependency
update_package_swift_dependency() {
    local package_file="$1"
    local dependency_name="$2"
    local version="$3"
    
    if [[ ! -f "$package_file" ]]; then
        log_warning "Package.swift not found: $package_file"
        return 0
    fi
    
    log_step "Updating $dependency_name dependency in $package_file to $version"
    
    # Update dependency version
    sed -i '' "s|\.package(url: \"https://github\.com/ParticleMedia/msp-ios-sdk-public\.git\", from: \".*\")|.package(url: \"https://github.com/ParticleMedia/msp-ios-sdk-public.git\", from: \"${version}\")|g" "$package_file"
    
    log_success "Updated $dependency_name dependency in $package_file"
}

# Create git tag for SPM package
create_spm_tag() {
    local package_name="$1"
    local version="$2"
    local tag_name="${package_name}-${version}"
    
    log_step "Creating git tag for SPM package: $tag_name"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would create tag $tag_name"
        return 0
    fi
    
    # Check if tag already exists
    if git tag -l | grep -q "^${tag_name}$"; then
        log_warning "Tag $tag_name already exists"
        return 0
    fi
    
    # Create tag
    git tag "$tag_name"
    
    log_success "Created tag: $tag_name"
}

# Push tags to remote
push_spm_tags() {
    log_step "Pushing SPM tags to remote"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would push tags to remote"
        return 0
    fi
    
    # Push all tags
    git push origin --tags
    
    log_success "Pushed SPM tags to remote"
}

# Release NovaCore SPM package
release_novacore_spm() {
    log_release "Releasing NovaCore SPM package"
    
    # Update NovaCore Package.swift version
    update_package_swift_version "NovaCore/Package.swift" "$VERSION"
    
    # Create tag for NovaCore
    create_spm_tag "NovaCore" "$VERSION"
    
    log_success "NovaCore SPM package released"
}

# Release NovaAdapter SPM package
release_novaadapter_spm() {
    log_release "Releasing NovaAdapter SPM package"
    
    # Update NovaAdapter Package.swift version
    update_package_swift_version "NovaAdapter/Package.swift" "$VERSION"
    
    # Update NovaAdapter dependency on NovaCore
    update_package_swift_dependency "NovaAdapter/Package.swift" "NovaCore" "$VERSION"
    
    # Create tag for NovaAdapter
    create_spm_tag "NovaAdapter" "$VERSION"
    
    log_success "NovaAdapter SPM package released"
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
    
    print_section "Starting SPM Release Process for Version: $VERSION"
    
    # Skip individual start notifications - only send final success/failure
    
    # Track release statistics
    local total_packages=2
    local successful_packages=0
    local failed_packages=0
    local failed_package_names=()
    
    # Release NovaCore SPM package
    if release_novacore_spm; then
        ((successful_packages++))
    else
        ((failed_packages++))
        failed_package_names+=("NovaCore")
        if [[ "$DRY_RUN" != "true" ]]; then
            notify_release_failure "SPM" "$VERSION" "NovaCore release failed" "Core Package Release"
        fi
        exit 1
    fi
    
    # Release NovaAdapter SPM package
    if release_novaadapter_spm; then
        ((successful_packages++))
    else
        ((failed_packages++))
        failed_package_names+=("NovaAdapter")
        if [[ "$DRY_RUN" != "true" ]]; then
            notify_release_failure "SPM" "$VERSION" "NovaAdapter release failed" "Adapter Package Release"
        fi
        exit 1
    fi
    
    
    # Push all tags
    if push_spm_tags; then
        log_success "All SPM tags pushed successfully"
    else
        if [[ "$DRY_RUN" != "true" ]]; then
            notify_release_failure "SPM" "$VERSION" "Failed to push SPM tags" "Tag Push"
        fi
        exit 1
    fi
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local duration_formatted=$(printf "%02d:%02d:%02d" $((duration/3600)) $((duration%3600/60)) $((duration%60)))
    
    print_section "SPM Release Process Completed Successfully"
    log_success "All SPM packages released successfully for version: $VERSION"
    log_info "SPM packages available at:"
    log_info "  NovaCore: https://github.com/ParticleMedia/msp-ios-sdk-public.git (tag: NovaCore-$VERSION)"
    log_info "  NovaAdapter: https://github.com/ParticleMedia/msp-ios-sdk-public.git (tag: NovaAdapter-$VERSION)"
    
    # Send single comprehensive success notification (skip in dry-run mode)
    if [[ "$DRY_RUN" != "true" ]]; then
        local spm_packages="NovaCore, NovaAdapter"
        notify_release_success_with_summary "SPM" "$VERSION" "$spm_packages" "$duration_formatted" "$RELEASE_NOTES" "$total_packages" "$successful_packages" "$failed_packages" "$RELEASE_BRANCH"
    fi
}

# Show usage if no arguments provided
if [[ $# -eq 0 ]]; then
    show_help
    exit 1
fi

# Run main function with all arguments
main "$@"
