#!/bin/bash

# Create Release Branch Script
# Creates a release branch from the base branch for version releases

set -e

# Source the common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Use ROOT_DIR from environment if set, otherwise calculate from script location
if [[ -z "${ROOT_DIR:-}" ]]; then
    ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
source "$ROOT_DIR/Scripts/lib/release-common.sh"

# Default values
VERSION=""
BASE_BRANCH="newsbreak_msp_migration_spm_dist"
RELEASE_BRANCH=""
DRY_RUN="false"

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                echo "Create Release Branch Script v1.0.0"
                exit 0
                ;;
            --base-branch)
                BASE_BRANCH="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
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
    echo "  --base-branch BRANCH    Base branch to create release from (default: newsbreak_msp_migration_spm_dist)"
    echo "  --dry-run               Show what would be done without executing"
    echo "  --help, -h              Show this help message"
    echo "  --version, -v           Show version information"
    echo ""
    echo "Examples:"
    echo "  $0 0.0.2-migration-spm"
    echo "  $0 --base-branch main 0.0.2-migration-spm"
    echo "  $0 --dry-run 0.0.2-migration-spm"
}

# Validate inputs
validate_inputs() {
    if [[ -z "$VERSION" ]]; then
        log_error "Version is required"
        show_help
        exit 1
    fi
    
    # Set release branch name
    RELEASE_BRANCH="release/$VERSION"
    
    log_info "Release configuration:"
    log_info "  Version: $VERSION"
    log_info "  Base Branch: $BASE_BRANCH"
    log_info "  Release Branch: $RELEASE_BRANCH"
}

# Check if base branch exists
check_base_branch() {
    log_step "Checking base branch: $BASE_BRANCH"
    
    if ! git show-ref --verify --quiet "refs/heads/$BASE_BRANCH"; then
        log_error "Base branch '$BASE_BRANCH' does not exist locally"
        exit 1
    fi
    
    if ! git show-ref --verify --quiet "refs/remotes/origin/$BASE_BRANCH"; then
        log_error "Base branch '$BASE_BRANCH' does not exist on remote"
        exit 1
    fi
    
    log_success "Base branch '$BASE_BRANCH' exists"
}

# Check if release branch already exists
check_release_branch() {
    log_step "Checking if release branch already exists: $RELEASE_BRANCH"
    
    if git show-ref --verify --quiet "refs/heads/$RELEASE_BRANCH"; then
        log_warning "Release branch '$RELEASE_BRANCH' already exists locally"
        if [[ "$DRY_RUN" != "true" ]]; then
            log_info "Automatically deleting existing local release branch"
            git branch -D "$RELEASE_BRANCH"
            log_success "Deleted existing local release branch"
        fi
    fi
    
    if git show-ref --verify --quiet "refs/remotes/origin/$RELEASE_BRANCH"; then
        log_warning "Release branch '$RELEASE_BRANCH' already exists on remote"
        if [[ "$DRY_RUN" != "true" ]]; then
            log_info "Automatically deleting existing remote release branch"
            git push origin --delete "$RELEASE_BRANCH"
            log_success "Deleted existing remote release branch"
        fi
    fi
}

# Create release branch
create_release_branch() {
    log_step "Creating release branch: $RELEASE_BRANCH"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would create branch '$RELEASE_BRANCH' from '$BASE_BRANCH'"
        return 0
    fi
    
    # Ensure we're on the base branch
    git checkout "$BASE_BRANCH"
    
    # Pull latest changes
    git pull origin "$BASE_BRANCH"
    
    # Create and checkout release branch
    git checkout -b "$RELEASE_BRANCH"
    
    log_success "Created release branch: $RELEASE_BRANCH"
}

# Push release branch
push_release_branch() {
    log_step "Pushing release branch to remote"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would push branch '$RELEASE_BRANCH' to origin"
        return 0
    fi
    
    git push origin "$RELEASE_BRANCH"
    
    log_success "Pushed release branch to remote"
}

# Main function
main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Validate inputs
    validate_inputs
    
    # Ensure we're in the project root
    ensure_project_root
    
    # Check prerequisites
    check_base_branch
    check_release_branch
    
    # Create release branch
    create_release_branch
    
    # Push release branch
    push_release_branch
    
    print_section "Release Branch Created Successfully"
    log_success "Release branch '$RELEASE_BRANCH' is ready for version '$VERSION'"
    log_info "Next steps:"
    log_info "  1. Run CocoaPods release: ./Scripts/release-cocoapods-modular.sh $VERSION"
    log_info "  2. Run SPM release: ./Scripts/release-spm-modular.sh $VERSION"
    log_info "  3. Push final release: git push origin $RELEASE_BRANCH"
}

# Show usage if no arguments provided
if [[ $# -eq 0 ]]; then
    show_help
    exit 1
fi

# Run main function with all arguments
main "$@"
