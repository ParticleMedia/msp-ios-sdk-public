#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

# Create Release Branch Script
# Creates a release branch from the base branch for version releases

set +e  # Disabled to allow graceful error handling

# shellcheck source=Scripts/lib/path-helpers.sh
source "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/path-helpers.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/Scripts/lib/release-common.sh"

VERSION=""
BASE_BRANCH="${BASE_BRANCH:-}"
RELEASE_BRANCH=""
DRY_RUN="false"

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
                    log::error "BRANCH" "Unknown argument: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

show_help() {
    echo "Usage: $0 [OPTIONS] <VERSION>"
    echo ""
    echo "Arguments:"
    echo "  VERSION                 Version to release (e.g., 0.0.2-migration-spm)"
    echo ""
    echo "Options:"
    echo "  --base-branch BRANCH    Base branch to create release from (default: current branch)"
    echo "  --dry-run               Show what would be done without executing"
    echo "  --help, -h              Show this help message"
    echo "  --version, -v           Show version information"
    echo ""
    echo "Examples:"
    echo "  $0 0.0.2-migration-spm"
    echo "  $0 --base-branch develop 0.0.2-migration-spm"
    echo "  $0 --dry-run 0.0.2-migration-spm"
}

validate_inputs() {
    if [[ -z "$VERSION" ]]; then
        log::error "BRANCH" "Version is required"
        show_help
        exit 1
    fi
    
    if [[ -z "$BASE_BRANCH" ]]; then
        BASE_BRANCH="$(git branch --show-current)"
        if [[ -z "$BASE_BRANCH" ]]; then
            log::error "BRANCH" "Could not determine current branch. Please specify --base-branch"
            exit 1
        fi
    fi

    RELEASE_BRANCH="release/$VERSION"
    
    log::info "BRANCH" "Release configuration:"
    log::info "BRANCH" "  Version: $VERSION"
    log::info "BRANCH" "  Base Branch: $BASE_BRANCH"
    log::info "BRANCH" "  Release Branch: $RELEASE_BRANCH"
}

check_base_branch() {
    log::step "BRANCH" "Checking base branch: $BASE_BRANCH"
    
    if ! git show-ref --verify --quiet "refs/heads/$BASE_BRANCH"; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log::warn "BRANCH" "DRY RUN: Base branch '$BASE_BRANCH' does not exist locally (continuing)"
        else
            log::error "BRANCH" "Base branch '$BASE_BRANCH' does not exist locally"
            exit 1
        fi
    fi
    
    if ! git show-ref --verify --quiet "refs/remotes/origin/$BASE_BRANCH"; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log::warn "BRANCH" "DRY RUN: Base branch '$BASE_BRANCH' does not exist on remote (continuing)"
        else
            log::error "BRANCH" "Base branch '$BASE_BRANCH' does not exist on remote"
            exit 1
        fi
    fi
    
    if [[ "$DRY_RUN" != "true" ]]; then
        log::success "BRANCH" "Base branch '$BASE_BRANCH' exists"
    else
        log::info "BRANCH" "DRY RUN: Skipping base branch validation"
    fi
}

check_release_branch() {
    log::step "BRANCH" "Checking if release branch already exists: $RELEASE_BRANCH"
    
    # In resume mode, don't delete existing branches - just use them
    if [[ "${MSP_RESUME_MODE:-0}" == "1" ]]; then
        if git show-ref --verify --quiet "refs/heads/$RELEASE_BRANCH"; then
            log::info "BRANCH" "Release branch '$RELEASE_BRANCH' already exists locally (resume mode: keeping it)"
            return 0
        fi
        if git show-ref --verify --quiet "refs/remotes/origin/$RELEASE_BRANCH"; then
            log::info "BRANCH" "Release branch '$RELEASE_BRANCH' already exists on remote (resume mode: keeping it)"
            return 0
        fi
    fi
    
    # Normal mode: delete existing branches to recreate fresh
    if git show-ref --verify --quiet "refs/heads/$RELEASE_BRANCH"; then
        log::warn "BRANCH" "Release branch '$RELEASE_BRANCH' already exists locally"
        if [[ "$DRY_RUN" != "true" ]]; then
            log::info "BRANCH" "Automatically deleting existing local release branch"
            git branch -D "$RELEASE_BRANCH"
            log::success "BRANCH" "Deleted existing local release branch"
        fi
    fi
    
    if git show-ref --verify --quiet "refs/remotes/origin/$RELEASE_BRANCH"; then
        log::warn "BRANCH" "Release branch '$RELEASE_BRANCH' already exists on remote"
        if [[ "$DRY_RUN" != "true" ]]; then
            log::info "BRANCH" "Automatically deleting existing remote release branch"
            git push origin --delete "$RELEASE_BRANCH"
            log::success "BRANCH" "Deleted existing remote release branch"
        fi
    fi
}

create_release_branch() {
    log::step "BRANCH" "Creating release branch: $RELEASE_BRANCH"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log::info "BRANCH" "DRY RUN: Would create branch '$RELEASE_BRANCH' from '$BASE_BRANCH'"
        return 0
    fi
    
    # In resume mode, if branch already exists, just checkout to it
    if [[ "${MSP_RESUME_MODE:-0}" == "1" ]]; then
        if git show-ref --verify --quiet "refs/heads/$RELEASE_BRANCH"; then
            log::info "BRANCH" "Release branch '$RELEASE_BRANCH' already exists (resume mode: checking out)"
            git checkout "$RELEASE_BRANCH"
            log::success "BRANCH" "Checked out existing release branch: $RELEASE_BRANCH"
            return 0
        fi
        # If branch exists on remote but not locally, fetch and checkout
        if git show-ref --verify --quiet "refs/remotes/origin/$RELEASE_BRANCH"; then
            log::info "BRANCH" "Release branch '$RELEASE_BRANCH' exists on remote (resume mode: fetching and checking out)"
            git fetch origin "$RELEASE_BRANCH"
            git checkout -b "$RELEASE_BRANCH" "origin/$RELEASE_BRANCH" || git checkout "$RELEASE_BRANCH"
            log::success "BRANCH" "Checked out existing release branch from remote: $RELEASE_BRANCH"
            return 0
        fi
    fi
    
    # Normal mode: create new branch
    # Ensure we're on the base branch
    # Clean untracked files that might conflict with checkout
    # This is safe in CI/sandbox environments where untracked files are from script copying
    git clean -fd || true
    git checkout "$BASE_BRANCH"
    
    # Pull latest changes
    git pull origin "$BASE_BRANCH"
    
    # Create and checkout release branch
    git checkout -b "$RELEASE_BRANCH"
    
    log::success "BRANCH" "Created release branch: $RELEASE_BRANCH"
}

push_release_branch() {
    log::step "BRANCH" "Pushing release branch to remote"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log::info "BRANCH" "DRY RUN: Would push branch '$RELEASE_BRANCH' to origin"
        return 0
    fi
    
    git push origin "$RELEASE_BRANCH"
    
    log::success "BRANCH" "Pushed release branch to remote"
}

main() {
    parse_arguments "$@"
    validate_inputs
    ensure_project_root
    check_base_branch
    check_release_branch
    
    create_release_branch
    push_release_branch
    
    print_section "Release Branch Created Successfully"
    log::success "BRANCH" "Release branch '$RELEASE_BRANCH' is ready for version '$VERSION'"
    log::info "BRANCH" "Next steps:"
    log::info "BRANCH" "  1. Run CocoaPods release: ./Scripts/release-cocoapods-modular.sh $VERSION"
    log::info "BRANCH" "  2. Run SPM release: ./Scripts/release-spm-modular.sh $VERSION"
    log::info "BRANCH" "  3. Push final release: git push origin $RELEASE_BRANCH"
}

if [[ $# -eq 0 ]]; then
    show_help
    exit 1
fi

main "$@"
