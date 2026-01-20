#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

# Git Utilities for Release Scripts
# Provides git operations for release workflows

# ============================================================================
# ROOT_DIR and UI System Loading
# ============================================================================
# ============================================
# Unified ROOT_DIR resolution (final version)
# ============================================
if [[ -z "${ROOT_DIR:-}" ]]; then
    # First try Git repo root (most reliable)
    if command -v git >/dev/null 2>&1; then
        git_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
        if [[ -n "$git_root" ]]; then
            ROOT_DIR="$git_root"
        fi
    fi

    # Fallback to walking up from SCRIPT_DIR
    if [[ -z "${ROOT_DIR:-}" ]]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        ROOT_DIR="$SCRIPT_DIR"
        while [[ "$ROOT_DIR" != "/" ]] && [[ "${ROOT_DIR##*/}" != "Scripts" ]]; do
            ROOT_DIR="$(dirname "$ROOT_DIR")"
        done
        if [[ "${ROOT_DIR##*/}" == "Scripts" ]]; then
            ROOT_DIR="$(dirname "$ROOT_DIR")"
        fi
    fi
fi

export ROOT_DIR

# Source UI system in order: colors.sh → ui.sh → logging.sh
# Handle NO_ANSI flag by setting NO_COLOR (logging.sh respects NO_COLOR)
if [[ "${NO_ANSI:-false}" == "true" ]]; then
    export NO_COLOR=1
fi

# Source colors.sh
if [[ -f "$ROOT_DIR/Scripts/lib/colors.sh" ]]; then
    # shellcheck source=Scripts/lib/colors.sh
    source "$ROOT_DIR/Scripts/lib/colors.sh" 2>/dev/null || true
fi

# Source ui.sh (depends on colors.sh)
if [[ -f "$ROOT_DIR/Scripts/lib/ui.sh" ]]; then
    # shellcheck source=Scripts/lib/ui.sh
    source "$ROOT_DIR/Scripts/lib/ui.sh" 2>/dev/null || true
fi

# Source logging.sh (depends on colors.sh and ui.sh)
if [[ -f "$ROOT_DIR/Scripts/lib/logging.sh" ]]; then
    # shellcheck source=Scripts/lib/logging.sh
    source "$ROOT_DIR/Scripts/lib/logging.sh" 2>/dev/null || true
fi

# Load release state utilities
if [[ -f "$SCRIPT_DIR/state.sh" ]]; then
    # shellcheck source=Scripts/release/utils/state.sh
    source "$SCRIPT_DIR/state.sh" 2>/dev/null || true
fi

# Fallback logging functions if UI system not available
if ! command -v log_info &>/dev/null; then
    : "${RED:=\033[0;31m}"
    : "${GREEN:=\033[0;32m}"
    : "${YELLOW:=\033[1;33m}"
    : "${BLUE:=\033[0;34m}"
    : "${NC:=\033[0m}"
    
    log_info() {
        if [[ "${NO_ANSI:-false}" == "true" ]]; then
            echo "[INFO] $1"
        else
            echo -e "${BLUE}ℹ️  $1${NC}"
        fi
    }
    
    log_success() {
        if [[ "${NO_ANSI:-false}" == "true" ]]; then
            echo "[SUCCESS] $1"
        else
            echo -e "${GREEN}✅ $1${NC}"
        fi
    }
    
    log_warning() {
        if [[ "${NO_ANSI:-false}" == "true" ]]; then
            echo "[WARN] $1"
        else
            echo -e "${YELLOW}⚠️  $1${NC}"
        fi
    }
    
    log_error() {
        if [[ "${NO_ANSI:-false}" == "true" ]]; then
            echo "[ERROR] $1" >&2
        else
            echo -e "${RED}❌ $1${NC}" >&2
        fi
    }
    
    log_step() {
        if [[ "${NO_ANSI:-false}" == "true" ]]; then
            echo "[STEP] $1"
        else
            echo -e "${BLUE}🔧 $1${NC}"
        fi
    }
    
    log_debug() {
        if [[ "${VERBOSE:-false}" == "true" ]]; then
            if [[ "${NO_ANSI:-false}" == "true" ]]; then
                echo "[DEBUG] $1"
            else
                echo -e "${BLUE}🔍 $1${NC}"
            fi
        fi
    }
    
    log_warn() {
        log_warning "$@"
    }
fi

# Ensure git working directory is clean
ensure_git_clean() {
    local allow_untracked="${1:-false}"
    
    if [[ "$allow_untracked" == "true" ]]; then
        # Only check for modified and staged files
        if ! git diff --quiet || ! git diff --cached --quiet; then
            log_error "Git working directory has uncommitted changes"
            return 1
        fi
    else
        # Check for any changes including untracked files
        if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
            log_error "Git working directory is not clean"
            return 1
        fi
    fi
    
    return 0
}

# Create a new git branch
create_branch() {
    local branch_name="$1"
    local from_branch="${2:-HEAD}"
    
    if [[ -z "$branch_name" ]]; then
        log_error "Branch name is required"
        return 1
    fi
    
    # Check if branch already exists
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        log_warning "Branch $branch_name already exists"
        return 0
    fi
    
    log_step "Creating branch $branch_name from $from_branch"
    
    if git checkout -b "$branch_name" "$from_branch" 2>/dev/null; then
        log_success "Created branch $branch_name"
        return 0
    else
        log_error "Failed to create branch $branch_name"
        return 1
    fi
}

# Delete a git branch
delete_branch() {
    local branch_name="$1"
    local force="${2:-false}"
    
    if [[ -z "$branch_name" ]]; then
        log_error "Branch name is required"
        return 1
    fi
    
    # Check if branch exists
    if ! git show-ref --verify --quiet "refs/heads/$branch_name"; then
        log_warning "Branch $branch_name does not exist"
        return 0
    fi
    
    log_step "Deleting branch $branch_name"
    
    if [[ "$force" == "true" ]]; then
        git branch -D "$branch_name" 2>/dev/null
    else
        git branch -d "$branch_name" 2>/dev/null
    fi
    
    if [[ $? -eq 0 ]]; then
        log_success "Deleted branch $branch_name"
        return 0
    else
        log_error "Failed to delete branch $branch_name"
        return 1
    fi
}

# Check if a git tag exists
tag_exists() {
    local tag_name="$1"
    
    if [[ -z "$tag_name" ]]; then
        return 1
    fi
    
    git rev-parse --verify --quiet "refs/tags/$tag_name" >/dev/null 2>&1
}

# Create a git tag
create_tag() {
    local tag_name="$1"
    local message="${2:-Release $tag_name}"
    local force="${3:-false}"
    local target_commit="${4:-HEAD}"
    
    if [[ -z "$tag_name" ]]; then
        log_error "Tag name is required"
        return 1
    fi
    
    # Resolve target commit to full SHA
    local target_commit_sha
    if ! target_commit_sha=$(git rev-parse "$target_commit" 2>/dev/null); then
        log_error "Failed to resolve target commit: $target_commit"
        return 1
    fi

    log_step "Creating tag $tag_name at commit $target_commit_sha"

    # Check if tag already exists and verify commit
    if tag_exists "$tag_name"; then
        local existing_commit_sha
        existing_commit_sha=$(git rev-parse "$tag_name" 2>/dev/null || echo "")

        if [[ -n "$existing_commit_sha" ]]; then
            if [[ "$existing_commit_sha" == "$target_commit_sha" ]]; then
                log_info "Tag $tag_name already exists and points to correct commit: $target_commit_sha"
                return 0
            else
                log_warning "Tag $tag_name exists but points to wrong commit: $existing_commit_sha (expected: $target_commit_sha)"

        if [[ "$force" == "true" ]]; then
                    log_info "Force mode: deleting incorrect tag..."
            git tag -d "$tag_name" 2>/dev/null || true
        else
                    log_error "Tag points to wrong commit. Use force=true to recreate"
                    return 1
        fi
    fi
        fi
    fi

    # Create tag at specified commit
    if git tag -a "$tag_name" -m "$message" "$target_commit_sha" 2>/dev/null; then
        log_success "Created tag $tag_name at commit $target_commit_sha"

        # Final verification
        local final_commit_sha
        final_commit_sha=$(git rev-parse "$tag_name" 2>/dev/null || echo "")
        if [[ "$final_commit_sha" != "$target_commit_sha" ]]; then
            log_error "Tag verification failed: tag points to $final_commit_sha instead of $target_commit_sha"
            return 1
        fi
        
        # Track tag creation in state
        if command -v msp_state_mark_git_flag &>/dev/null; then
            msp_state_mark_git_flag "tag_created" true
            if command -v msp_state_set_tag_name &>/dev/null; then
                msp_state_set_tag_name "$tag_name"
            fi
        fi
        
        return 0
    else
        log_error "Failed to create tag $tag_name"
        return 1
    fi
}

# Push a branch to remote
push_branch() {
    local branch_name="$1"
    local remote="${2:-origin}"
    local force="${3:-false}"
    
    if [[ -z "$branch_name" ]]; then
        log_error "Branch name is required"
        return 1
    fi
    
    log_step "Pushing branch $branch_name to $remote"
    
    if [[ "$force" == "true" ]]; then
        git push "$remote" "$branch_name" --force 2>/dev/null
    else
        git push "$remote" "$branch_name" 2>/dev/null
    fi
    
    if [[ $? -eq 0 ]]; then
        log_success "Pushed branch $branch_name to $remote"
        return 0
    else
        log_error "Failed to push branch $branch_name to $remote"
        return 1
    fi
}

# Push a tag to remote
push_tag() {
    local tag_name="$1"
    local remote="${2:-origin}"
    
    if [[ -z "$tag_name" ]]; then
        log_error "Tag name is required"
        return 1
    fi
    
    log_step "Pushing tag $tag_name to $remote"
    
    if git push "$remote" "$tag_name" 2>/dev/null; then
        log_success "Pushed tag $tag_name to $remote"
        return 0
    else
        log_error "Failed to push tag $tag_name to $remote"
        return 1
    fi
}

# Fetch from remote
fetch_remote() {
    local remote="${1:-origin}"
    
    log_step "Fetching from $remote"
    
    if git fetch "$remote" 2>/dev/null; then
        log_success "Fetched from $remote"
        return 0
    else
        log_error "Failed to fetch from $remote"
        return 1
    fi
}

# Delete a local and remote git tag
# Usage: msp_git_delete_tag <tag_name>
msp_git_delete_tag() {
    local tag_name="$1"
    
    if [[ -z "$tag_name" ]]; then
        log_warn "msp_git_delete_tag: empty tag name, nothing to delete"
        return 0
    fi
    
    # Delete local tag (ignore errors if it doesn't exist)
    if git tag -l "$tag_name" >/dev/null 2>&1; then
        if ! git tag -d "$tag_name" 2>/dev/null; then
            log_error "Failed to delete local git tag: ${tag_name}"
            return 1
        fi
        log_info "Deleted local git tag: ${tag_name}"
    else
        log_info "Local git tag ${tag_name} does not exist; skipping local delete"
    fi
    
    # Delete remote tag (assume 'origin'; ignore errors if it doesn't exist)
    if ! git push origin ":refs/tags/${tag_name}" 2>/dev/null; then
        log_error "Failed to delete remote git tag: ${tag_name}"
        return 1
    fi
    
    log_success "Deleted git tag (local and remote): ${tag_name}"
    return 0
}

# Delete a remote release branch
# Usage: msp_git_delete_remote_branch <branch_name>
msp_git_delete_remote_branch() {
    local branch_name="$1"
    
    if [[ -z "$branch_name" ]]; then
        log_warn "msp_git_delete_remote_branch: empty branch name, nothing to delete"
        return 0
    fi
    
    # We intentionally do NOT delete the local branch for safety
    if ! git push origin --delete "$branch_name" 2>/dev/null; then
        log_error "Failed to delete remote release branch: ${branch_name}"
        return 1
    fi
    
    log_success "Deleted remote release branch: ${branch_name}"
    return 0
}

# Export functions
export -f ensure_git_clean create_branch delete_branch tag_exists create_tag push_branch push_tag fetch_remote msp_git_delete_tag msp_git_delete_remote_branch 2>/dev/null || true


