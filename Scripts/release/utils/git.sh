#!/bin/bash

# Git Utilities for Release Scripts
# Provides git operations for release workflows

# ============================================================================
# ROOT_DIR and UI System Loading
# ============================================================================
# Calculate ROOT_DIR if not already set (may be set by parent script)
if [[ -z "${ROOT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

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
    
    if [[ -z "$tag_name" ]]; then
        log_error "Tag name is required"
        return 1
    fi
    
    # Check if tag already exists
    if tag_exists "$tag_name"; then
        if [[ "$force" == "true" ]]; then
            log_warning "Tag $tag_name already exists, deleting..."
            git tag -d "$tag_name" 2>/dev/null || true
        else
            log_warning "Tag $tag_name already exists"
            return 0
        fi
    fi
    
    log_step "Creating tag $tag_name"
    
    if git tag -a "$tag_name" -m "$message" 2>/dev/null; then
        log_success "Created tag $tag_name"
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

# Export functions
export -f ensure_git_clean create_branch delete_branch tag_exists create_tag push_branch push_tag fetch_remote 2>/dev/null || true


