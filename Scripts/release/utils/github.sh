#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch M, shared) ---
# shellcheck source=/dev/null
_msp_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$_msp_root" ] && [ -f "$_msp_root/Scripts/lib/worktree_guard.sh" ]; then
  . "$_msp_root/Scripts/lib/worktree_guard.sh"
  msp_enforce_main_repo_or_exit
fi
unset _msp_root
# --- End MSP Worktree Safety Guard (Patch M, shared) ---

# GitHub Utilities for Release Scripts
# Provides functions for GitHub release operations

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

# Fallback logging functions if UI system not available
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
        log::warn "GITHUB" "$@"
    }
fi


if [[ -f "$SCRIPT_DIR/retry.sh" ]]; then
    # shellcheck source=Scripts/release/utils/retry.sh
    source "$SCRIPT_DIR/retry.sh" 2>/dev/null || true
fi

GITHUB_REPO="${GITHUB_REPO:-ParticleMedia/msp-ios-sdk-public}"

github_create_release() {
    local tag="$1"
    local name="${2:-Release $tag}"
    local notes="${3:-}"
    local draft="${4:-false}"
    local prerelease="${5:-false}"
    
    if [[ -z "$tag" ]]; then
        log::error "GITHUB" "Tag is required"
        return 1
    fi
    
    log::step "GITHUB" "Creating GitHub release: $tag"
    
    # Check if gh CLI is available
    if ! command -v gh &>/dev/null; then
        log::error "GITHUB" "GitHub CLI (gh) is not installed"
        return 1
    fi
    
    local gh_cmd=("gh" "release" "create" "$tag" "--repo" "$GITHUB_REPO" "--title" "$name")
    
    if [[ -n "$notes" ]]; then
        gh_cmd+=("--notes" "$notes")
    fi
    
    if [[ "$draft" == "true" ]]; then
        gh_cmd+=("--draft")
    fi
    
    if [[ "$prerelease" == "true" ]]; then
        gh_cmd+=("--prerelease")
    fi
    
    if "${gh_cmd[@]}" 2>/dev/null; then
        log::success "GITHUB" "Created GitHub release: $tag"
        
        # Track GitHub release creation in state
        if command -v msp_state_mark_git_flag &>/dev/null; then
            msp_state_mark_git_flag "github_release_created" true
            if command -v msp_state_set_tag_name &>/dev/null; then
                # Ensure tag_name is set if not already set
                msp_state_set_tag_name "$tag"
            fi
        fi
        
        return 0
    else
        log::error "GITHUB" "Failed to create GitHub release: $tag"
        return 1
    fi
}

github_upload_asset() {
    local tag="$1"
    local asset_path="$2"
    local asset_name="${3:-$(basename "$asset_path")}"
    
    if [[ -z "$tag" || -z "$asset_path" ]]; then
        log::error "GITHUB" "Tag and asset path are required"
        return 1
    fi
    
    if [[ ! -f "$asset_path" ]]; then
        log::error "GITHUB" "Asset file not found: $asset_path"
        return 1
    fi
    
    log::step "GITHUB" "Uploading asset to GitHub release: $tag"
    
    # Check if gh CLI is available
    if ! command -v gh >/dev/null; then
        log::error "GITHUB" "GitHub CLI (gh) is not installed"
        return 1
    fi
    
    if gh release upload "$tag" "$asset_path" --repo "$GITHUB_REPO" --clobber 2>/dev/null; then
        log::success "GITHUB" "Uploaded asset to GitHub release: $tag"
        return 0
    else
        log::error "GITHUB" "Failed to upload asset to GitHub release: $tag"
        return 1
    fi
}

github_release_exists() {
    local tag="$1"
    
    if [[ -z "$tag" ]]; then
        return 1
    fi
    
    # Check if gh CLI is available
    if ! command -v gh >/dev/null; then
        log::warn "GITHUB" "GitHub CLI (gh) is not installed, cannot check release existence"
        return 1
    fi
    
    if gh release view "$tag" --repo "$GITHUB_REPO" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Delete GitHub release
# Usage: github_delete_release <tag_or_release_name>
github_delete_release() {
    local release_name="$1"
    
    if [[ -z "$release_name" ]]; then
        log::warn "GITHUB" "github_delete_release: empty release name, nothing to delete"
        return 0
    fi
    
    if ! command -v gh >/dev/null 2>&1; then
        log::error "GITHUB" "GitHub CLI (gh) is not available; cannot delete GitHub Release ${release_name}"
        return 1
    fi
    
    log::step "GITHUB" "Deleting GitHub release: $release_name"
    
    # --yes to avoid extra prompts; our own rollback flow already confirmed
    if gh release delete "$release_name" --repo "$GITHUB_REPO" --yes 2>/dev/null; then
        log::success "GITHUB" "Deleted GitHub Release: ${release_name}"
        return 0
    else
        log::error "GITHUB" "Failed to delete GitHub Release: ${release_name}"
        return 1
    fi
}

create_github_release_internal() {
    local pod="$1"
    local version="$2"
    
    local zip_name="${pod}-${version}.zip"
    if [[ -d "$pod" ]]; then
        zip -r "$zip_name" "$pod" >/dev/null 2>&1
    else
        log::warn "GITHUB" "Pod directory $pod not found, skipping zip creation"
        return 0
    fi
    
    if github_release_exists "$version"; then
        log::info "GITHUB" "Release $version already exists, uploading assets"
        github_upload_asset "$version" "$zip_name"
    else
        log::info "GITHUB" "Creating new release $version"
        github_create_release "$version" "Release $version"
        github_upload_asset "$version" "$zip_name"
    fi
    
    rm -f "$zip_name"
    
    return 0
}

create_github_release_with_retry() {
    local pod="$1"
    local version="$2"
    local max_attempts=3
    local base_delay=5
    
    log::step "GITHUB" "Creating GitHub release with retry for $pod"
    
    if command -v retry_with_backoff &>/dev/null; then
        retry_with_backoff $max_attempts $base_delay "GitHub release creation" \
            create_github_release_internal "$pod" "$version"
    else
        create_github_release_internal "$pod" "$version"
    fi
}

# Export functions
export -f github_create_release github_upload_asset github_release_exists github_delete_release \
    create_github_release_internal create_github_release_with_retry 2>/dev/null || true

