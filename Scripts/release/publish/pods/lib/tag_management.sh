#!/usr/bin/env bash
# ============================================================================
# Tag Management Module
# ============================================================================
# Module: tag_management.sh
# Purpose: Git tag creation, verification, and remote pushing
# Extracted from: publish.sh (T103)
#
# Functions:
#   - ensure_release_tag_exists_and_pushed: Create and push tag to remotes
#   - wait_for_remote_tag: Wait for tag propagation on remote
#
# Dependencies:
#   - git CLI
#   - Logging functions (log_info, log_error, log_success, log_warning, log_step)
#   - create_or_verify_github_release from github_release.sh (for auto-release)
#
# Environment Variables:
#   - DRY_RUN: Skip actual git operations (default: false)
#   - SKIP_PUBLIC_REMOTE_PUSH: Skip pushing to public remote (default: 0)
#   - MSP_ALLOW_PUBLIC_PUSH_FAILURE: Continue on public push failure (default: 0)
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_TAG_MANAGEMENT_SOURCED:-}" ]] && return 0
readonly _TAG_MANAGEMENT_SOURCED=1

# ============================================================================
# Filtered Public Push (bypasses GitHub Push Protection)
# ============================================================================
# Creates a temporary clone, scrubs known secret patterns from history via
# git-filter-repo, then pushes branch/tag to the public remote.
# This avoids GitHub Push Protection blocks caused by historical secrets
# in the private repo without requiring history rewrites on origin.

# @description Push a ref to public remote via a filtered temporary clone
# @param $1 push_type - "branch" or "tag"
# @param $2 ref_name  - branch name or tag name to push
# @param $3 tag_commit_sha - (tag mode only) commit SHA the tag should point to
# @return 0 on success, 1 on failure
_filtered_push_to_public() {
    local push_type="$1"
    local ref_name="$2"
    local tag_commit_sha="${3:-}"

    if ! command -v git-filter-repo &>/dev/null; then
        log::error "PODS" "git-filter-repo is required for filtered public push"
        log::error "PODS" "Install: brew install git-filter-repo"
        return 1
    fi

    local origin_url
    origin_url=$(git remote get-url origin 2>/dev/null)
    local public_url
    public_url=$(git remote get-url public 2>/dev/null)
    # Convert HTTPS to SSH to avoid OAuth workflow scope issues
    if [[ "$public_url" == https://github.com/* ]]; then
        public_url="git@github.com:${public_url#https://github.com/}"
    fi

    local tmp_dir
    tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/msp-filtered-push.XXXXXX")

    log::info "PODS" "Using filtered push to public (scrubbing secrets from history)"

    # Clone only the branch we need
    local clone_branch="$ref_name"
    if [[ "$push_type" == "tag" ]]; then
        clone_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "HEAD")
        if [[ "$clone_branch" == "HEAD" ]]; then
            clone_branch=$(git branch -r --contains "$tag_commit_sha" 2>/dev/null \
                | grep 'origin/' | head -1 | sed 's|.*origin/||' | xargs)
        fi
    fi

    if ! git clone --single-branch --branch "$clone_branch" "$origin_url" "$tmp_dir/repo" 2>/dev/null; then
        log::error "PODS" "Failed to clone for filtered push"
        rm -rf "$tmp_dir"
        return 1
    fi

    # Build regex replacements for known secret patterns
    printf '%s\n' \
        'regex:https://hooks\.slack\.com/services/[A-Za-z0-9/]+==>https://hooks.slack.com/services/REDACTED' \
        'regex:xoxb-[0-9]+-[0-9]+-[A-Za-z0-9]+==>xoxb-REDACTED' \
        > "$tmp_dir/replacements.txt"

    # Scrub secrets from history
    if ! git -C "$tmp_dir/repo" filter-repo --replace-text "$tmp_dir/replacements.txt" --force --quiet 2>/dev/null; then
        log::error "PODS" "git-filter-repo failed"
        rm -rf "$tmp_dir"
        return 1
    fi

    # Add public remote to temp clone
    git -C "$tmp_dir/repo" remote add public "$public_url"

    local push_result=0
    if [[ "$push_type" == "branch" ]]; then
        if ! git -C "$tmp_dir/repo" push public "$clone_branch" --force 2>/dev/null; then
            log::error "PODS" "Filtered push of branch $clone_branch to public failed"
            push_result=1
        fi
    elif [[ "$push_type" == "tag" ]]; then
        # Recreate the tag at the rewritten HEAD
        git -C "$tmp_dir/repo" tag -f "$ref_name" HEAD 2>/dev/null
        if ! git -C "$tmp_dir/repo" push public "refs/tags/$ref_name" --force 2>/dev/null; then
            log::error "PODS" "Filtered push of tag $ref_name to public failed"
            push_result=1
        fi
    fi

    rm -rf "$tmp_dir"
    return "$push_result"
}

# ============================================================================
# Module Initialization
# ============================================================================

_tag_management_init() {
    # Verify git CLI is available
    if ! command -v git &>/dev/null; then
        echo "[ERROR] git CLI is not installed" >&2
        return 1
    fi

    # Verify logging functions are available
    if ! command -v log_info &>/dev/null; then
        echo "[ERROR] Logging functions not available. Source logger.sh first." >&2
        return 1
    fi

    return 0
}

# ============================================================================
# Public API
# ============================================================================

# Ensure git tag exists and is pushed to remotes
# @description Creates tag locally and pushes to origin and public remotes
# @param $1 tag - Tag name (e.g., "1.0.0")
# @param $2 target_commit - Commit to tag (default: HEAD)
# @return 0 if success, 1 if failure
# @env DRY_RUN - Skip actual operations
# @env SKIP_PUBLIC_REMOTE_PUSH - Skip public remote
# @env MSP_ALLOW_PUBLIC_PUSH_FAILURE - Continue on failure
ensure_release_tag_exists_and_pushed() {
    local tag="$1"
    local target_commit="${2:-HEAD}"

    if [[ -z "$tag" ]]; then
        log::error "PODS" "ensure_release_tag_exists_and_pushed: tag parameter is required"
        return 1
    fi

    # Resolve target commit to full SHA
    local target_commit_sha
    if ! target_commit_sha=$(git rev-parse "$target_commit" 2>/dev/null); then
        log::error "PODS" "Failed to resolve target commit: $target_commit"
        return 1
    fi

    log::info "PODS" "Ensuring tag $tag points to commit $target_commit_sha"

    # Check if tag exists locally and verify commit
    local tag_exists_locally=false
    local tag_commit_sha=""
    if git rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1; then
        tag_exists_locally=true
        tag_commit_sha=$(git rev-parse "refs/tags/$tag" 2>/dev/null || echo "")

        if [[ -n "$tag_commit_sha" ]]; then
            if [[ "$tag_commit_sha" == "$target_commit_sha" ]]; then
                log::info "PODS" "Local tag $tag already exists and points to correct commit: $target_commit_sha"
            else
                log::warn "PODS" "Local tag $tag exists but points to wrong commit: $tag_commit_sha (expected: $target_commit_sha)"
                log::info "PODS" "Deleting incorrect local tag: $tag"
                git tag -d "$tag" 2>/dev/null || true

                # Wait for Git cache to clear
                log::info "PODS" "Waiting 2 seconds for Git cache to clear..."
                sleep 2

                # Verify deletion
                if git rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1; then
                    log::error "PODS" "Failed to delete local tag: $tag (still exists after deletion)"
                    return 1
                fi

                tag_exists_locally=false
            fi
        fi
    fi

    # Check if tag exists on origin and verify commit
    local tag_exists_on_origin=false
    local origin_tag_sha=""
    if git ls-remote --tags origin "refs/tags/$tag" 2>/dev/null | grep -q "refs/tags/$tag"; then
        origin_tag_sha=$(git ls-remote --tags origin "refs/tags/$tag" 2>/dev/null | cut -f1)
        if [[ -n "$origin_tag_sha" ]]; then
            if [[ "$origin_tag_sha" == "$target_commit_sha" ]]; then
                log::info "PODS" "Origin tag $tag already exists and points to correct commit: $target_commit_sha"
                tag_exists_on_origin=true
            else
                log::warn "PODS" "Origin tag $tag exists but points to wrong commit: $origin_tag_sha (expected: $target_commit_sha)"
                log::info "PODS" "Deleting incorrect origin tag: $tag"
                git push --delete origin "refs/tags/$tag" 2>/dev/null || true

                # Wait for remote to process deletion
                log::info "PODS" "Waiting 2 seconds for origin to process tag deletion..."
                sleep 2

                tag_exists_on_origin=false
            fi
        fi
    fi

    # Check if tag exists on public and verify commit
    local tag_exists_on_public=false
    local public_tag_sha=""
    if git remote | grep -q "^public$"; then
        if git ls-remote --tags public "refs/tags/$tag" 2>/dev/null | grep -q "refs/tags/$tag"; then
            public_tag_sha=$(git ls-remote --tags public "refs/tags/$tag" 2>/dev/null | cut -f1)
            if [[ -n "$public_tag_sha" ]]; then
                if [[ "$public_tag_sha" == "$target_commit_sha" ]]; then
                    log::info "PODS" "Public tag $tag already exists and points to correct commit: $target_commit_sha"
                    tag_exists_on_public=true
                else
                    log::warn "PODS" "Public tag $tag exists but points to wrong commit: $public_tag_sha (expected: $target_commit_sha)"
                    log::info "PODS" "Deleting incorrect public tag: $tag"
                    git push --delete public "refs/tags/$tag" 2>/dev/null || true

                    # Wait for remote to process deletion
                    log::info "PODS" "Waiting 2 seconds for public to process tag deletion..."
                    sleep 2

                    tag_exists_on_public=false
                fi
            fi
        fi
    fi

    # Skip all Git operations in DRY_RUN mode
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log::info "PODS" "DRY RUN: Would create/push tag $tag at commit $target_commit_sha"
        log::info "PODS" "DRY RUN: Would push commit to public remote"
        log::info "PODS" "DRY RUN: Would push tag to public remote"
        return 0
    fi

    # Create local tag if it doesn't exist or was deleted
    if [[ "$tag_exists_locally" == "false" ]]; then
        log::info "PODS" "Creating local git tag: $tag at commit $target_commit_sha"

        # Retry logic: up to 3 attempts with 2-second delays
        local max_attempts=3
        local attempt=1
        local tag_created=false

        while [[ $attempt -le $max_attempts ]]; do
            # Capture error output to diagnose failures
            local tag_error_output
            tag_error_output=$(git tag "$tag" "$target_commit_sha" 2>&1)
            local tag_exit_code=$?

            if [[ $tag_exit_code -eq 0 ]]; then
                tag_created=true
                log::success "PODS" "Created local tag: $tag at commit $target_commit_sha"

                # Verify tag points to correct commit
                local verify_sha
                verify_sha=$(git rev-parse "refs/tags/$tag" 2>/dev/null || echo "")
                if [[ "$verify_sha" == "$target_commit_sha" ]]; then
                    log::success "PODS" "Tag verification passed: $tag -> $target_commit_sha"
                    break
                else
                    log::error "PODS" "Tag verification failed: $tag points to $verify_sha (expected: $target_commit_sha)"
                    git tag -d "$tag" 2>/dev/null || true
                    tag_created=false
                fi
            else
                log::warn "PODS" "Attempt $attempt/$max_attempts failed: tag creation failed"
                if [[ -n "$tag_error_output" ]]; then
                    log::warn "PODS" "Git error: $tag_error_output"
                fi

                # Additional check: verify tag doesn't exist locally
                if git rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1; then
                    log::warn "PODS" "Tag $tag still exists locally, attempting to delete..."
                    git tag -d "$tag" 2>/dev/null || true
                    sleep 1
                fi
            fi

            if [[ $attempt -lt $max_attempts ]]; then
                log::info "PODS" "Retrying in 2 seconds..."
                sleep 2
            fi

            ((attempt++)) || true
        done

        if [[ "$tag_created" == "false" ]]; then
            log::error "PODS" "Failed to create local tag after $max_attempts attempts: $tag"
            return 1
        fi
    fi

    # Push tag to origin if it doesn't exist or was deleted
    if [[ "$tag_exists_on_origin" == "false" ]]; then
        log::info "PODS" "Pushing tag to origin: $tag"

        # Retry logic: up to 3 attempts with 2-second delays
        local max_push_attempts=3
        local push_attempt=1
        local push_success=false

        while [[ $push_attempt -le $max_push_attempts ]]; do
            if git push origin "refs/tags/$tag" 2>/dev/null; then
                push_success=true
                log::success "PODS" "Pushed tag to origin: $tag"
                break
            else
                log::warn "PODS" "Attempt $push_attempt/$max_push_attempts failed: push to origin failed"
            fi

            if [[ $push_attempt -lt $max_push_attempts ]]; then
                log::info "PODS" "Retrying in 2 seconds..."
                sleep 2
            fi

            ((push_attempt++)) || true
        done

        if [[ "$push_success" == "false" ]]; then
            log::error "PODS" "Failed to push tag to origin after $max_push_attempts attempts: $tag"
            return 1
        fi
    fi

    # Push branch + tag to public remote
    if [[ "${SKIP_PUBLIC_REMOTE_PUSH:-0}" == "1" ]]; then
        log::warn "PODS" "SKIP_PUBLIC_REMOTE_PUSH=1: Skipping public remote push"
    elif git remote | grep -q "^public$"; then
        local current_branch
        current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "HEAD")

        # --- Push branch to public ---
        if ! git branch -r --contains "$target_commit_sha" 2>/dev/null | grep -q "public/"; then
            log::info "PODS" "Pushing branch $current_branch to public"

            # Try direct push first
            local branch_pushed=false
            if git push public "$current_branch" 2>/dev/null; then
                branch_pushed=true
            elif git push -u public "$current_branch" 2>/dev/null; then
                branch_pushed=true
            fi

            # Fallback: filtered push (scrubs secrets from history)
            if [[ "$branch_pushed" == "false" ]]; then
                log::warn "PODS" "Direct push failed, trying filtered push (scrubbing secrets)..."
                if _filtered_push_to_public "branch" "$current_branch"; then
                    branch_pushed=true
                fi
            fi

            if [[ "$branch_pushed" == "true" ]]; then
                log::success "PODS" "Branch pushed to public remote"
            else
                log::error "PODS" "Failed to push branch to public remote"
                if [[ "${MSP_ALLOW_PUBLIC_PUSH_FAILURE:-0}" != "1" ]]; then
                    return 1
                fi
                log::warn "PODS" "MSP_ALLOW_PUBLIC_PUSH_FAILURE=1: Continuing despite failure"
            fi
        else
            log::info "PODS" "Commit $target_commit_sha already exists on public remote"
        fi

        # --- Push tag to public ---
        if [[ "$tag_exists_on_public" == "false" ]]; then
            log::info "PODS" "Pushing tag to public: $tag"

            local tag_pushed=false
            if git push public "refs/tags/$tag" 2>/dev/null; then
                tag_pushed=true
            fi

            # Fallback: filtered push
            if [[ "$tag_pushed" == "false" ]]; then
                log::warn "PODS" "Direct tag push failed, trying filtered push..."
                if _filtered_push_to_public "tag" "$tag" "$target_commit_sha"; then
                    tag_pushed=true
                fi
            fi

            if [[ "$tag_pushed" == "true" ]]; then
                log::success "PODS" "Pushed tag to public: $tag"

                # Create/verify GitHub Release after tag push
                sleep 2
                if command -v create_or_verify_github_release &>/dev/null; then
                    if ! create_or_verify_github_release "$tag"; then
                        log::warn "PODS" "Failed to create/verify GitHub Release (non-blocking)"
                    fi
                fi
            else
                log::error "PODS" "Failed to push tag to public (direct + filtered)"
                if [[ "${MSP_ALLOW_PUBLIC_PUSH_FAILURE:-0}" != "1" ]]; then
                    return 1
                fi
                log::warn "PODS" "MSP_ALLOW_PUBLIC_PUSH_FAILURE=1: Continuing despite failure"
            fi
        fi
    fi

    # Final verification
    local final_tag_sha
    final_tag_sha=$(git rev-parse "refs/tags/$tag" 2>/dev/null || echo "")
    if [[ "$final_tag_sha" != "$target_commit_sha" ]]; then
        log::error "PODS" "Tag verification failed: tag $tag points to $final_tag_sha, expected $target_commit_sha"
        return 1
    fi

    log::success "PODS" "Tag $tag verified: points to commit $target_commit_sha"
    return 0
}

# Wait for remote tag to be resolvable
# @description Waits for tag to propagate on remote server
# @param $1 tag - Tag name
# @param $2 max_attempts - Maximum attempts (default: 12)
# @param $3 sleep_seconds - Seconds between attempts (default: 5)
# @return 0 if tag resolvable, 1 if timeout
wait_for_remote_tag() {
    local tag="$1"
    local max_attempts="${2:-12}"
    local sleep_seconds="${3:-5}"

    if [[ -z "$tag" ]]; then
        log::error "PODS" "wait_for_remote_tag: tag parameter is required"
        return 1
    fi

    log::step "PODS" "Waiting for remote tag '$tag' to be resolvable"

    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        log::info "PODS" "Checking remote tag visibility (attempt $attempt/$max_attempts)..."

        # Check if tag is resolvable from origin
        if git ls-remote --tags origin "refs/tags/$tag" 2>/dev/null | grep -q "refs/tags/$tag"; then
            log::success "PODS" "Remote tag '$tag' is now visible and resolvable"

            # Additional verification: try to fetch the tag reference
            if git fetch --tags --force origin "refs/tags/$tag:refs/tags/$tag" >/dev/null 2>&1; then
                log::success "PODS" "Remote tag '$tag' fetch verification passed"
                return 0
            else
                log::warn "PODS" "Tag visible but fetch verification failed (attempt $attempt/$max_attempts)"
            fi
        else
            log::info "PODS" "Tag '$tag' not yet visible on remote"
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            log::info "PODS" "Waiting ${sleep_seconds}s before next attempt..."
            sleep "$sleep_seconds"
        else
            # Fail-fast on timeout in production mode
            if [[ "${DRY_RUN:-true}" == "false" ]]; then
                log::error "PODS" "Timeout waiting for remote tag '$tag' after $max_attempts attempts"
                return 1
            else
                log::warn "PODS" "Timeout waiting for remote tag (dry-run mode - non-blocking)"
                return 0
            fi
        fi

        ((attempt++)) || true
    done

    return 1
}

# ============================================================================
# Export Functions
# ============================================================================

export -f _filtered_push_to_public
export -f ensure_release_tag_exists_and_pushed
export -f wait_for_remote_tag
