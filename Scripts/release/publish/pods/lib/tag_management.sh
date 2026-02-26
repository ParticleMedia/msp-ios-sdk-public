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

    # Push commit to public remote BEFORE pushing tag
    if [[ "${SKIP_PUBLIC_REMOTE_PUSH:-0}" == "1" ]]; then
        log::warn "PODS" "SKIP_PUBLIC_REMOTE_PUSH=1: Skipping public remote push"
    elif git remote | grep -q "^public$"; then
        log::info "PODS" "Ensuring commit $target_commit_sha exists on public remote"

        # Get current branch (or use HEAD if detached)
        local current_branch
        current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "HEAD")

        # Check if commit exists on public remote
        if ! git branch -r --contains "$target_commit_sha" | grep -q "public/"; then
            log::warn "PODS" "Commit $target_commit_sha not found on public remote, pushing..."

            # Push current branch/HEAD to public remote
            if [[ "$current_branch" == "HEAD" ]]; then
                # Detached HEAD - push commit directly
                log::info "PODS" "Detached HEAD detected, pushing commit directly to public"
                if ! git push public "$target_commit_sha:refs/heads/temp-release-$tag" 2>/dev/null; then
                    log::warn "PODS" "Failed to push commit to temp branch, trying force push"
                    if ! git push public HEAD:refs/heads/release-temp 2>/dev/null; then
                        log::error "PODS" "Failed to push commit to public remote"
                        if [[ "${MSP_ALLOW_PUBLIC_PUSH_FAILURE:-0}" == "1" ]]; then
                            log::warn "PODS" "MSP_ALLOW_PUBLIC_PUSH_FAILURE=1: Continuing despite failure"
                        else
                            return 1
                        fi
                    fi
                fi
            else
                # Normal branch - push branch to public
                log::info "PODS" "Pushing branch $current_branch to public"
                if ! git push public "$current_branch" 2>/dev/null; then
                    log::warn "PODS" "Normal push failed, trying with -u flag"
                    if ! git push -u public "$current_branch" 2>/dev/null; then
                        log::error "PODS" "Failed to push branch to public remote"
                        if [[ "${MSP_ALLOW_PUBLIC_PUSH_FAILURE:-0}" == "1" ]]; then
                            log::warn "PODS" "MSP_ALLOW_PUBLIC_PUSH_FAILURE=1: Continuing despite failure"
                        else
                            return 1
                        fi
                    fi
                fi
            fi

            log::success "PODS" "Commit pushed to public remote"
        else
            log::info "PODS" "Commit $target_commit_sha already exists on public remote"
        fi

        # Verify commit is now accessible on public remote
        sleep 2
        if ! git ls-remote public "$target_commit_sha" >/dev/null 2>&1; then
            if ! git branch -r --contains "$target_commit_sha" 2>/dev/null | grep -q "public/"; then
                log::error "PODS" "Commit verification failed: $target_commit_sha not accessible on public"
                if [[ "${MSP_ALLOW_PUBLIC_PUSH_FAILURE:-0}" == "1" ]]; then
                    log::warn "PODS" "MSP_ALLOW_PUBLIC_PUSH_FAILURE=1: Continuing despite verification failure"
                else
                    return 1
                fi
            fi
        fi

        log::success "PODS" "Commit $target_commit_sha verified on public remote"
    fi

    # Push tag to public if it doesn't exist or was deleted
    if [[ "${SKIP_PUBLIC_REMOTE_PUSH:-0}" == "1" ]]; then
        log::warn "PODS" "SKIP_PUBLIC_REMOTE_PUSH=1: Skipping tag push to public remote"
    elif [[ "$tag_exists_on_public" == "false" ]] && git remote | grep -q "^public$"; then
        log::info "PODS" "Pushing tag to public: $tag"

        # Retry logic: up to 3 attempts with 2-second delays
        local max_public_attempts=3
        local public_attempt=1
        local public_push_success=false
        local push_output=""
        local push_exit_code=1

        while [[ $public_attempt -le $max_public_attempts ]]; do
            push_output=$(git push public "refs/tags/$tag" 2>&1)
            push_exit_code=$?

            if [[ $push_exit_code -eq 0 ]]; then
                public_push_success=true
                log::success "PODS" "Pushed tag to public: $tag"

                # Immediately create/verify GitHub Release after tag push
                log::info "PODS" "Ensuring GitHub Release is Published for tag: $tag"
                sleep 2

                # Use unified GitHub Release function if available
                if command -v create_or_verify_github_release &>/dev/null; then
                    if ! create_or_verify_github_release "$tag"; then
                        log::warn "PODS" "Failed to create/verify GitHub Release (non-blocking)"
                    fi
                fi

                break
            else
                log::warn "PODS" "Attempt $public_attempt/$max_public_attempts failed: push to public failed"
            fi

            if [[ $public_attempt -lt $max_public_attempts ]]; then
                log::info "PODS" "Retrying in 2 seconds..."
                sleep 2
            fi

            ((public_attempt++)) || true
        done

        if [[ "$public_push_success" == "false" ]]; then
            log::warn "PODS" "Failed to push tag to public after $max_public_attempts attempts: $tag"

            # Check if GitHub Push Protection blocked the push
            if echo "$push_output" | grep -qi "push protection"; then
                log::error "PODS" "GitHub Push Protection detected secrets in commit history"
                log::error "PODS" "Visit GitHub Web UI and click 'Allow this secret'"
                log::error "PODS" "Then re-run the release script"

                if [[ "${MSP_ALLOW_PUBLIC_PUSH_FAILURE:-0}" != "1" ]]; then
                    return 1
                fi
            else
                log::error "PODS" "Push output:"
                echo "$push_output"

                if [[ "${MSP_ALLOW_PUBLIC_PUSH_FAILURE:-0}" != "1" ]]; then
                    return 1
                fi
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

export -f ensure_release_tag_exists_and_pushed
export -f wait_for_remote_tag
