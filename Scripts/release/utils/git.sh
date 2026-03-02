#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

# Git Utilities for Release Scripts
# Provides git operations for release workflows

# ============================================================================
# ROOT_DIR and UI System Loading (using path-helpers.sh)
# ============================================================================
# shellcheck source=Scripts/lib/path-helpers.sh
source "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/path-helpers.sh"

# Handle NO_ANSI flag by setting NO_COLOR
if [[ "${NO_ANSI:-false}" == "true" ]]; then
    export NO_COLOR=1
fi

# Source common.sh which provides unified logging via logger.sh
if [[ -f "$ROOT_DIR/Scripts/lib/common.sh" ]]; then
    # shellcheck source=Scripts/lib/common.sh
    source "$ROOT_DIR/Scripts/lib/common.sh" 2>/dev/null || true
fi

# Load release state utilities
if [[ -f "$SCRIPT_DIR/state.sh" ]]; then
    # shellcheck source=Scripts/release/utils/state.sh
    source "$SCRIPT_DIR/state.sh" 2>/dev/null || true
fi

# Fallback logging functions if unified logging not available
if ! command -v log::info &>/dev/null; then
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
        log::warn "GIT" "$@"
    }
fi

ensure_git_clean() {
    local allow_untracked="${1:-false}"
    
    if [[ "$allow_untracked" == "true" ]]; then
        # Only check for modified and staged files
        if ! git diff --quiet || ! git diff --cached --quiet; then
            log::error "GIT" "Git working directory has uncommitted changes"
            return 1
        fi
    else
        # Check for any changes including untracked files
        if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
            log::error "GIT" "Git working directory is not clean"
            return 1
        fi
    fi
    
    return 0
}

create_branch() {
    local branch_name="$1"
    local from_branch="${2:-HEAD}"
    
    if [[ -z "$branch_name" ]]; then
        log::error "GIT" "Branch name is required"
        return 1
    fi
    
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        log::warn "GIT" "Branch $branch_name already exists"
        return 0
    fi
    
    log::step "GIT" "Creating branch $branch_name from $from_branch"
    
    if git checkout -b "$branch_name" "$from_branch" 2>/dev/null; then
        log::success "GIT" "Created branch $branch_name"
        return 0
    else
        log::error "GIT" "Failed to create branch $branch_name"
        return 1
    fi
}

delete_branch() {
    local branch_name="$1"
    local force="${2:-false}"
    
    if [[ -z "$branch_name" ]]; then
        log::error "GIT" "Branch name is required"
        return 1
    fi
    
    if ! git show-ref --verify --quiet "refs/heads/$branch_name"; then
        log::warn "GIT" "Branch $branch_name does not exist"
        return 0
    fi
    
    log::step "GIT" "Deleting branch $branch_name"
    
    if [[ "$force" == "true" ]]; then
        git branch -D "$branch_name" 2>/dev/null
    else
        git branch -d "$branch_name" 2>/dev/null
    fi
    
    if [[ $? -eq 0 ]]; then
        log::success "GIT" "Deleted branch $branch_name"
        return 0
    else
        log::error "GIT" "Failed to delete branch $branch_name"
        return 1
    fi
}

tag_exists() {
    local tag_name="$1"
    
    if [[ -z "$tag_name" ]]; then
        return 1
    fi
    
    git rev-parse --verify --quiet "refs/tags/$tag_name" >/dev/null 2>&1
}

create_tag() {
    local tag_name="$1"
    local message="${2:-Release $tag_name}"
    local force="${3:-false}"
    local target_commit="${4:-HEAD}"
    
    if [[ -z "$tag_name" ]]; then
        log::error "GIT" "Tag name is required"
        return 1
    fi
    
    local target_commit_sha
    if ! target_commit_sha=$(git rev-parse "$target_commit" 2>/dev/null); then
        log::error "GIT" "Failed to resolve target commit: $target_commit"
        return 1
    fi

    log::step "GIT" "Creating tag $tag_name at commit $target_commit_sha"

    if tag_exists "$tag_name"; then
        local existing_commit_sha
        existing_commit_sha=$(git rev-parse "$tag_name" 2>/dev/null || echo "")

        if [[ -n "$existing_commit_sha" ]]; then
            if [[ "$existing_commit_sha" == "$target_commit_sha" ]]; then
                log::info "GIT" "Tag $tag_name already exists and points to correct commit: $target_commit_sha"
                return 0
            else
                log::warn "GIT" "Tag $tag_name exists but points to wrong commit: $existing_commit_sha (expected: $target_commit_sha)"

        if [[ "$force" == "true" ]]; then
                    log::info "GIT" "Force mode: deleting incorrect tag..."
            git tag -d "$tag_name" 2>/dev/null || true
        else
                    log::error "GIT" "Tag points to wrong commit. Use force=true to recreate"
                    return 1
        fi
    fi
        fi
    fi

    if git tag -a "$tag_name" -m "$message" "$target_commit_sha" 2>/dev/null; then
        log::success "GIT" "Created tag $tag_name at commit $target_commit_sha"

        local final_commit_sha
        final_commit_sha=$(git rev-parse "$tag_name" 2>/dev/null || echo "")
        if [[ "$final_commit_sha" != "$target_commit_sha" ]]; then
            log::error "GIT" "Tag verification failed: tag points to $final_commit_sha instead of $target_commit_sha"
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
        log::error "GIT" "Failed to create tag $tag_name"
        return 1
    fi
}

push_branch() {
    local branch_name="$1"
    local remote="${2:-origin}"
    local force="${3:-false}"
    
    if [[ -z "$branch_name" ]]; then
        log::error "GIT" "Branch name is required"
        return 1
    fi
    
    log::step "GIT" "Pushing branch $branch_name to $remote"
    
    if [[ "$force" == "true" ]]; then
        git push "$remote" "$branch_name" --force 2>/dev/null
    else
        git push "$remote" "$branch_name" 2>/dev/null
    fi
    
    if [[ $? -eq 0 ]]; then
        log::success "GIT" "Pushed branch $branch_name to $remote"
        return 0
    else
        log::error "GIT" "Failed to push branch $branch_name to $remote"
        return 1
    fi
}

push_tag() {
    local tag_name="$1"
    local remote="${2:-origin}"
    
    if [[ -z "$tag_name" ]]; then
        log::error "GIT" "Tag name is required"
        return 1
    fi
    
    log::step "GIT" "Pushing tag $tag_name to $remote"
    
    if git push "$remote" "$tag_name" 2>/dev/null; then
        log::success "GIT" "Pushed tag $tag_name to $remote"
        return 0
    else
        log::error "GIT" "Failed to push tag $tag_name to $remote"
        return 1
    fi
}

fetch_remote() {
    local remote="${1:-origin}"
    
    log::step "GIT" "Fetching from $remote"
    
    if git fetch "$remote" 2>/dev/null; then
        log::success "GIT" "Fetched from $remote"
        return 0
    else
        log::error "GIT" "Failed to fetch from $remote"
        return 1
    fi
}

# Usage: msp_git_delete_tag <tag_name>
msp_git_delete_tag() {
    local tag_name="$1"
    
    if [[ -z "$tag_name" ]]; then
        log::warn "GIT" "msp_git_delete_tag: empty tag name, nothing to delete"
        return 0
    fi
    
    # Delete local tag (ignore errors if it doesn't exist)
    if git tag -l "$tag_name" >/dev/null 2>&1; then
        if ! git tag -d "$tag_name" 2>/dev/null; then
            log::error "GIT" "Failed to delete local git tag: ${tag_name}"
            return 1
        fi
        log::info "GIT" "Deleted local git tag: ${tag_name}"
    else
        log::info "GIT" "Local git tag ${tag_name} does not exist; skipping local delete"
    fi
    
    # Delete remote tag (assume 'origin'; ignore errors if it doesn't exist)
    if ! git push origin ":refs/tags/${tag_name}" 2>/dev/null; then
        log::error "GIT" "Failed to delete remote git tag: ${tag_name}"
        return 1
    fi
    
    log::success "GIT" "Deleted git tag (local and remote): ${tag_name}"
    return 0
}

# Delete a remote release branch
# Usage: msp_git_delete_remote_branch <branch_name>
msp_git_delete_remote_branch() {
    local branch_name="$1"
    
    if [[ -z "$branch_name" ]]; then
        log::warn "GIT" "msp_git_delete_remote_branch: empty branch name, nothing to delete"
        return 0
    fi
    
    # We intentionally do NOT delete the local branch for safety
    if ! git push origin --delete "$branch_name" 2>/dev/null; then
        log::error "GIT" "Failed to delete remote release branch: ${branch_name}"
        return 1
    fi
    
    log::success "GIT" "Deleted remote release branch: ${branch_name}"
    return 0
}

# @description Create a pull request from current branch to target branch using gh CLI
# @param $1 version - Release version (for PR title)
# @param $2 target_branch - Target branch (e.g., BASE_BRANCH)
create_pr_to_branch() {
    local version="$1"
    local target_branch="$2"
    local source_branch
    source_branch=$(git rev-parse --abbrev-ref HEAD)

    if ! command -v gh >/dev/null 2>&1; then
        log::warn "GIT" "gh CLI not available — skipping PR creation"
        log::info "GIT" "Please manually create PR: $source_branch → $target_branch"
        return 0
    fi

    log::info "GIT" "Creating PR: $source_branch → $target_branch"

    gh pr create \
        --base "$target_branch" \
        --head "$source_branch" \
        --title "chore(release): merge $version into $target_branch" \
        --body "Auto-generated PR to sync release $version changes into \`$target_branch\`." \
        2>&1 || {
            log::warn "GIT" "PR creation failed (may already exist or branch not pushed)"
            return 0
        }

    log::success "GIT" "PR created: $source_branch → $target_branch"
}

# Export functions
export -f ensure_git_clean create_branch delete_branch tag_exists create_tag push_branch push_tag fetch_remote msp_git_delete_tag msp_git_delete_remote_branch create_pr_to_branch 2>/dev/null || true


