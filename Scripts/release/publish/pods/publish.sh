#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

# Modular CocoaPods Release Script
# Follows the exact release workflow: MSPiOSCore → MSPSharedLibraries → Adapters → MSPCore
#
# Phase 2 Step 4: Config-driven release
# This script now uses environment variables from msp-release.sh instead of CLI arguments.

# ============================================================================
# Release Architecture: Two Independent Dimensions
# ============================================================================
#
# DIMENSION 1: RELEASE ORDER (based on dependency relationships)
# ─────────────────────────────────────────────────────────────
# Step 0: MSPiOSCore             (foundation - no dependencies)
# Step 1: MSPSharedLibraries     (depends on: MSPiOSCore)
# Step 2: Adapters (parallel)    (depends on: MSPSharedLibraries + MSPiOSCore)
#     ├─ MSPPrebidAdapter
#     ├─ MSPGoogleAdapter
#     ├─ MSPFacebookAdapter
#     ├─ NovaAdapter            (binary distribution, but in Adapters phase)
#     └─ AmazonAdapter
# Step 3: MSPCore                (depends on: MSPSharedLibraries + MSPPrebidAdapter)
#
# Why this order?
# - MSPCore depends on MSPPrebidAdapter → MSPCore MUST come after Adapters
# - Adapters depend on MSPSharedLibraries → Adapters come after MSPSharedLibraries
# - MSPSharedLibraries depends on MSPiOSCore → MSPSharedLibraries comes after MSPiOSCore
#
# DIMENSION 2: DISTRIBUTION METHOD (implementation detail)
# ─────────────────────────────────────────────────────────────
# Binary Distribution (HTTP zip source from GitHub Releases):
#     - MSPiOSCore, MSPSharedLibraries, MSPCore, NovaAdapter
#
# Source Distribution (git+tag source):
#     - MSPPrebidAdapter, MSPGoogleAdapter, MSPFacebookAdapter, AmazonAdapter
#
# Why NovaAdapter is binary?
# - NovaAdapter includes private NovaCore.xcframework (not in git repo)
# - Must use HTTP zip to bundle Binary/NovaCore.xcframework
# - But release order remains in Adapters phase (Step 2)
#
# Key Point: Distribution method does NOT affect release order!
# ============================================================================

# Ensure UTF-8 encoding for CocoaPods
export LANG=en_US.UTF-8

set -e
set -o pipefail

# Source the common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

# ============================================================================
# Load Notification Functions
# ============================================================================
# Load Slack notification functions if available
if [[ -f "$ROOT_DIR/Scripts/notify/slack.sh" ]]; then
    # shellcheck source=Scripts/notify/slack.sh
    source "$ROOT_DIR/Scripts/notify/slack.sh"
    log_debug "[NOTIFY] Loaded Slack notification functions from: Scripts/notify/slack.sh" 2>/dev/null || true
else
    # Define stub functions to prevent errors (backward compatibility)
    log_debug "[NOTIFY] Slack notification functions not found, using stub functions" 2>/dev/null || true
    notify_release_failure() { :; }
    notify_release_success() { :; }
    notify_release_success_with_summary() { :; }
    notify_release_warning() { :; }
fi

# Source new notification system (supports DM-only, templates, smart routing)
if [[ -f "$ROOT_DIR/Scripts/release/utils/notify.sh" ]]; then
    # shellcheck source=Scripts/release/utils/notify.sh
    source "$ROOT_DIR/Scripts/release/utils/notify.sh" 2>/dev/null || true
    log_debug "[NOTIFY] Loaded new notification system (notify.sh)" 2>/dev/null || true
else
    log_warning "[NOTIFY] New notification system not found: $ROOT_DIR/Scripts/release/utils/notify.sh"
fi

# Source unified logging system (if not already loaded)
if [[ -f "$ROOT_DIR/Scripts/release/utils/logger.sh" ]]; then
    # shellcheck source=Scripts/release/utils/logger.sh
    source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true
fi

# ============================================================================
# Slack Notification Environment Diagnostics
# ============================================================================
if [[ "${MSP_LOG_LEVEL:-1}" -le 0 ]] || [[ "${VERBOSE:-false}" == "true" ]]; then
    echo "[DIAG] Slack notification environment check:" >&2
    if [[ -n "${SLACK_BOT_TOKEN:-}" ]]; then
        echo "[DIAG]   SLACK_BOT_TOKEN: SET (${SLACK_BOT_TOKEN:0:20}...)" >&2
    else
        echo "[DIAG]   SLACK_BOT_TOKEN: NOT SET" >&2
    fi
    echo "[DIAG]   MSP_SLACK_DM_OVERRIDE: ${MSP_SLACK_DM_OVERRIDE:-NOT SET}" >&2
    echo "[DIAG]   MSP_SLACK_ALERT_ENV: ${MSP_SLACK_ALERT_ENV:-prod (default)}" >&2
    echo "[DIAG]   SLACK_WEBHOOK_URL: ${SLACK_WEBHOOK_URL:+SET}${SLACK_WEBHOOK_URL:-NOT SET}" >&2
fi

source "$ROOT_DIR/Scripts/lib/release-common.sh"
# Before sourcing cocoapods.sh, ensure PODFILE is unset
unset PODFILE 2>/dev/null || true
source "$ROOT_DIR/Scripts/lib/cocoapods.sh"


# After sourcing cocoapods.sh, override PODFILE with project Podfile
PODFILE="$ROOT_DIR/Podfile"
export PODFILE
echo "[PODS][INFO] Using PODFILE path: $PODFILE"
# Load release state utilities (state.sh is already loaded by release-common.sh, but we can source it again if needed)
# Use absolute path to ensure correct location
if [[ -f "$ROOT_DIR/Scripts/release/utils/state.sh" ]]; then
    source "$ROOT_DIR/Scripts/release/utils/state.sh" 2>/dev/null || true
fi

# ============================================================================
# Environment Variable Validation
# ============================================================================
# Check if required environment variables are set (from msp-release.sh)
# If not set, fall back to CLI argument parsing for backward compatibility

if [[ -z "${RELEASE_VERSION:-}" ]]; then
    # Backward compatibility: extract from CLI if called directly
    if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
        RELEASE_VERSION="$1"
        shift
    else
        log_error "RELEASE_VERSION not set. Did you forget to run via msp-release.sh?"
        log_info "Usage: msp-release.sh pods <VERSION>"
        log_info "   or: $0 <VERSION> [OPTIONS]  (direct call for debugging)"
        exit 1
    fi
fi

# Use environment variables with CLI fallback for backward compatibility
VERSION="${RELEASE_VERSION:-}"
RELEASE_BRANCH="${RELEASE_BRANCH:-}"
DRY_RUN="${DRY_RUN:-false}"
SKIP_VALIDATION="${SKIP_VALIDATION:-false}"
VERBOSE="${VERBOSE:-false}"
RELEASE_NOTES_SOURCE="${RELEASE_NOTES_SOURCE:-auto}"
RELEASE_NOTES_TEMPLATE="${RELEASE_NOTES_TEMPLATE:-}"
RELEASE_NOTES="${RELEASE_NOTES:-}"

# Default pod modules if PODS_MODULES not set (backward compatibility)
# Release order: MSPiOSCore → MSPSharedLibraries → MSPGoogleAdsTypes → Adapters → MSPCore
DEFAULT_PODS_MODULES="MSPiOSCore MSPSharedLibraries MSPGoogleAdsTypes MSPPrebidAdapter MSPCore MSPGoogleAdapter MSPFacebookAdapter NovaAdapter AmazonAdapter"
PODS_MODULES="${PODS_MODULES:-$DEFAULT_PODS_MODULES}"

# ============================================================================
# Binary Distribution Detection
# ============================================================================
# Check if a pod uses binary distribution (HTTP zip source from GitHub Releases).
# This is a DISTRIBUTION METHOD check, NOT a release order check.
#
# Binary Distribution Pods:
# - MSPiOSCore: Foundation framework (binary only)
# - MSPSharedLibraries: Contains multiple XCFrameworks + PrebidMobile
# - MSPCore: Main framework (binary distribution)
# - NovaAdapter: Includes private NovaCore.xcframework (binary only)
#
# Note: Must match BINARY_DISTRIBUTION_PODS in generate_podspec.sh
# ============================================================================
is_binary_distribution() {
    local pod="$1"
    case "$pod" in
        MSPiOSCore|MSPSharedLibraries|MSPGoogleAdsTypes|MSPCore|NovaAdapter|MSPPrebidAdapter|MSPGoogleAdapter|MSPFacebookAdapter|AmazonAdapter)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ============================================================================
# Backward Compatibility: CLI Argument Parsing
# ============================================================================
# Only used if script is called directly (not via msp-release.sh)
parse_arguments() {
    # Only parse if we have remaining CLI args (backward compatibility)
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                echo "Modular CocoaPods Release Script v2.0.0-phase2"
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
            --skip-validation)
                SKIP_VALIDATION="true"
                shift
                ;;
            --verbose)
                VERBOSE="true"
                shift
                ;;
            --release-notes-source)
                RELEASE_NOTES_SOURCE="$2"
                shift 2
                ;;
            --release-notes-template)
                RELEASE_NOTES_TEMPLATE="$2"
                shift 2
                ;;
            --release-notes)
                RELEASE_NOTES="$2"
                shift 2
                ;;
            *)
                # Unknown argument - ignore (already processed VERSION above)
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
    echo "  --release-branch BRANCH       Release branch to work on (default: release/VERSION)"
    echo "  --dry-run                     Show what would be done without executing"
    echo "  --skip-validation             Skip podspec validation"
    echo "  --verbose                     Enable verbose output"
    echo "  --release-notes-source SOURCE Release notes source (auto, git, template, prompt)"
    echo "  --release-notes-template FILE Custom release notes template file"
    echo "  --release-notes NOTES        Custom release notes text"
    echo "  --help, -h                    Show this help message"
    echo "  --version, -v                 Show version information"
    echo ""
    echo "Release Workflow:"
    echo "  1. Publish MSPSharedLibraries (foundation dependency)"
    echo "  2. Wait for MSPSharedLibraries to be released"
    echo "  3. Publish Adapters (MSPFacebookAdapter, MSPGoogleAdapter, NovaAdapter, AmazonAdapter, PrebidAdapter)"
    echo "  4. Wait for Adapters to be released"
    echo "  5. Publish MSPCore (main framework)"
    echo "  6. Commit all changes to release branch"
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
    
    log_info "CocoaPods release configuration:"
    log_info "  Version: $VERSION"
    log_info "  Release Branch: $RELEASE_BRANCH"
    log_info "  Dry Run: $DRY_RUN"
    log_info "  Skip Validation: $SKIP_VALIDATION"
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

# Update podspec version and source
update_podspec_for_release() {
    local pod="$1"
    local version="$2"

    log_step "Generating release podspec for $pod version $version"

    # Call the podspec generator script
    if [[ ! -x "$ROOT_DIR/Scripts/release/generate_podspec.sh" ]]; then
        log_error "Podspec generator script not found or not executable"
        return 1
    fi

    # Generate the release podspec
    if ! "$ROOT_DIR/Scripts/release/generate_podspec.sh" "$pod" "$version"; then
        log_error "Failed to generate release podspec for $pod"
        return 1
    fi

    log_success "Generated release podspec for $pod at Build/ReleasePodspecs/${pod}.podspec"
}

# Update adapter SDK version
update_adapter_sdk_version() {
    local adapter="$1"
    local version="$2"
    
    # Skip adapters that read SDK version from external sources
    if [[ "$adapter" == "MSPGoogleAdapter" || "$adapter" == "MSPFacebookAdapter" ]]; then
        log_info "PUBLISH" "Skipping getSDKVersion() update for $adapter (reads from external sources)"
        return 0
    fi
    
    log_info "PUBLISH" "Updating getSDKVersion() in $adapter to version $version"

    # Fix: Use full path from project root
    local adapter_dir="${ROOT_DIR}/Sources/Adapters/${adapter}/${adapter}"

    # Validate directory exists
    if [[ ! -d "$adapter_dir" ]]; then
        log_error "PUBLISH" "Adapter directory not found: $adapter_dir"
        log_error "PUBLISH" "Expected structure: Sources/Adapters/$adapter/$adapter/*.swift"
        return 1
    fi

    # Find and update Swift files containing getSDKVersion
    local updated_count=0
    local failed=false

    while IFS= read -r file; do
        # Verify file contains getSDKVersion function
        if grep -q "func getSDKVersion()" "$file"; then
            log_info "PUBLISH" "Updating $file"

            # Update the return statement
            # Pattern: return "any.version.string" → return "new.version"
            if sed -i '' 's|return "[^"]*"|return "'"${version}"'"|g' "$file"; then
                log_info "PUBLISH" "✓ Updated getSDKVersion in $(basename "$file")"
                updated_count=$((updated_count + 1))
            else
                log_error "PUBLISH" "✗ Failed to update getSDKVersion in $file"
                failed=true
            fi
        fi
    done < <(find "$adapter_dir" -name "*.swift" -type f)

    # Check results
    if [[ "$failed" == "true" ]]; then
        log_error "PUBLISH" "Failed to update some files in $adapter"
        return 1
    fi

    if [[ $updated_count -eq 0 ]]; then
        log_warn "PUBLISH" "No getSDKVersion() function found in $adapter"
        log_warn "PUBLISH" "This may be expected if adapter doesn't implement getSDKVersion()"
        # Not a failure - some adapters may not have this function
        return 0
    fi

    log_info "PUBLISH" "✓ Successfully updated getSDKVersion() in $updated_count file(s) for $adapter"
    return 0
}

# Update MSPCore version
update_mspcore_version() {
    local version="$1"
    
    log_info "Skipping MSPCore version property update (reads from Config.plist)"
    # MSP class version is read from Config.plist, so we don't need to update the code
    # The version will be updated via update_config_plist_version function instead
}

# Update podspec dependencies
# Local version for adapter release (2 params: pod, version)
# Renamed to avoid conflict with utils/podspec.sh version (3 params)
update_adapter_podspec_dependencies() {
    local pod="$1"
    local version="$2"

    # ========================================================================
    # DEBUG: Diagnose ROOT_DIR issue in subprocess
    # ========================================================================
    log_info "[DEBUG] update_adapter_podspec_dependencies called for: $pod"
    log_info "[DEBUG] ROOT_DIR value: '${ROOT_DIR:-<EMPTY>}'"
    log_info "[DEBUG] PWD: $(pwd)"

    # CRITICAL FIX: Ensure ROOT_DIR is set (same logic as release_single_adapter)
    if [[ -z "${ROOT_DIR:-}" ]]; then
        log_warn "[DEBUG] ROOT_DIR is empty, attempting to resolve..."

        # Try git method first
        if command -v git >/dev/null 2>&1; then
            ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
            if [[ -n "$ROOT_DIR" ]]; then
                log_info "[DEBUG] ROOT_DIR resolved via git: $ROOT_DIR"
            fi
        fi

        # Fallback to relative path
        if [[ -z "${ROOT_DIR:-}" ]]; then
            # This function is called from release_single_adapter
            # which is in Scripts/release/publish/pods/publish.sh
            ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
            log_info "[DEBUG] ROOT_DIR resolved via relative path: $ROOT_DIR"
        fi

        export ROOT_DIR
    else
        log_info "[DEBUG] ROOT_DIR already set: $ROOT_DIR"
    fi

    # Use generated podspec from Build/ReleasePodspecs/ (not source podspec)
    local podspec="$ROOT_DIR/Build/ReleasePodspecs/${pod}.podspec"

    log_info "[DEBUG] Constructed podspec path: $podspec"
    log_info "[DEBUG] Checking if file exists..."
    
    if [[ ! -f "$podspec" ]]; then
        log_error "Podspec file not found: $podspec"
        log_error "[DEBUG] File does not exist at expected location"
        log_error "[DEBUG] Listing Build/ReleasePodspecs/ contents:"
        if [[ -d "$ROOT_DIR/Build/ReleasePodspecs/" ]]; then
            ls -la "$ROOT_DIR/Build/ReleasePodspecs/" 2>/dev/null || echo "  Failed to list directory"
        else
            log_error "[DEBUG] Directory does not exist: $ROOT_DIR/Build/ReleasePodspecs/"
        fi
        log_error "Make sure update_podspec_for_release() was called first"
        return 1
    fi

    log_info "[DEBUG] ✅ Podspec file found: $podspec"
    # ========================================================================
    # END DEBUG
    # ========================================================================
    
    log_step "Updating dependencies in $podspec"
    
    # Update MSPSharedLibraries dependency - handle both with and without version
    if grep -q "spec\.dependency.*MSPSharedLibraries" "$podspec"; then
        # Remove any existing version(s) and comments, then add the new one
        sed -i '' "s|spec\.dependency 'MSPSharedLibraries'[^#]*|spec.dependency 'MSPSharedLibraries'|g" "$podspec"
        sed -i '' "s|spec\.dependency 'MSPSharedLibraries'|spec.dependency 'MSPSharedLibraries', '${version}'|g" "$podspec"
        log_info "Updated MSPSharedLibraries dependency to $version"
    fi
    
    # Update PrebidAdapter dependency - handle both with and without version
    if grep -q "spec\.dependency.*PrebidAdapter" "$podspec"; then
        # Remove any existing version(s) and comments, then add the new one
        sed -i '' "s|spec\.dependency 'PrebidAdapter'[^#]*|spec.dependency 'PrebidAdapter'|g" "$podspec"
        sed -i '' "s|spec\.dependency 'PrebidAdapter'|spec.dependency 'PrebidAdapter', '${version}'|g" "$podspec"
        log_info "Updated PrebidAdapter dependency to $version"
    fi
    
    # Stage B: MSPOMSDK removed - OMSDK now embedded in NovaCore
    # No longer need to handle MSPOMSDK dependency
}

# Export function for parallel subprocess access
export -f update_adapter_podspec_dependencies

# Phase R1.11: Ensure git tag exists and is pushed to remote (for podspec validation)
ensure_release_tag_exists_and_pushed() {
    local tag="$1"
    local target_commit="${2:-HEAD}"

    if [[ -z "$tag" ]]; then
        log_error "ensure_release_tag_exists_and_pushed: tag parameter is required"
        return 1
    fi

    # Resolve target commit to full SHA
    local target_commit_sha
    if ! target_commit_sha=$(git rev-parse "$target_commit" 2>/dev/null); then
        log_error "Failed to resolve target commit: $target_commit"
            return 1
        fi

    log_info "Ensuring tag $tag points to commit $target_commit_sha"

    # Check if tag exists locally and verify commit
    local tag_exists_locally=false
    local tag_commit_sha=""
    if git rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1; then
        tag_exists_locally=true
        tag_commit_sha=$(git rev-parse "refs/tags/$tag" 2>/dev/null || echo "")
        
        if [[ -n "$tag_commit_sha" ]]; then
            if [[ "$tag_commit_sha" == "$target_commit_sha" ]]; then
                log_info "Local tag $tag already exists and points to correct commit: $target_commit_sha"
            else
                log_warning "Local tag $tag exists but points to wrong commit: $tag_commit_sha (expected: $target_commit_sha)"
                log_info "Deleting incorrect local tag: $tag"
                git tag -d "$tag" 2>/dev/null || true

                # Wait for Git cache to clear (critical for avoiding "tag already exists" error)
                log_info "Waiting 2 seconds for Git cache to clear..."
                sleep 2

                # Verify deletion
                if git rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1; then
                    log_error "Failed to delete local tag: $tag (still exists after deletion)"
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
                log_info "Origin tag $tag already exists and points to correct commit: $target_commit_sha"
                tag_exists_on_origin=true
            else
                log_warning "Origin tag $tag exists but points to wrong commit: $origin_tag_sha (expected: $target_commit_sha)"
                log_info "Deleting incorrect origin tag: $tag"
                git push --delete origin "refs/tags/$tag" 2>/dev/null || true

                # Wait for remote to process deletion
                log_info "Waiting 2 seconds for origin to process tag deletion..."
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
                    log_info "Public tag $tag already exists and points to correct commit: $target_commit_sha"
                    tag_exists_on_public=true
                else
                    log_warning "Public tag $tag exists but points to wrong commit: $public_tag_sha (expected: $target_commit_sha)"
                    log_info "Deleting incorrect public tag: $tag"
                    git push --delete public "refs/tags/$tag" 2>/dev/null || true

                    # Wait for remote to process deletion
                    log_info "Waiting 2 seconds for public to process tag deletion..."
                    sleep 2

                    tag_exists_on_public=false
                fi
            fi
        fi
    fi

    # Skip all Git operations in DRY_RUN mode
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Would create/push tag $tag at commit $target_commit_sha"
        log_info "DRY RUN: Would push commit to public remote"
        log_info "DRY RUN: Would push tag to public remote"
        return 0
    fi

    # Create local tag if it doesn't exist or was deleted
    if [[ "$tag_exists_locally" == "false" ]]; then
        log_info "Creating local git tag: $tag at commit $target_commit_sha"

        # Retry logic: up to 3 attempts with 2-second delays
        local max_attempts=3
        local attempt=1
        local tag_created=false

        while [[ $attempt -le $max_attempts ]]; do
            if git tag "$tag" "$target_commit_sha" 2>/dev/null; then
                tag_created=true
                log_success "Created local tag: $tag at commit $target_commit_sha"

                # Verify tag points to correct commit
                local verify_sha
                verify_sha=$(git rev-parse "refs/tags/$tag" 2>/dev/null || echo "")
                if [[ "$verify_sha" == "$target_commit_sha" ]]; then
                    log_success "Tag verification passed: $tag → $target_commit_sha"
                    break
                else
                    log_error "Tag verification failed: $tag points to $verify_sha (expected: $target_commit_sha)"
                    git tag -d "$tag" 2>/dev/null || true
                    tag_created=false
                fi
            else
                log_warning "Attempt $attempt/$max_attempts failed: tag creation failed"
            fi

            if [[ $attempt -lt $max_attempts ]]; then
                log_info "Retrying in 2 seconds..."
                sleep 2
            fi

            ((attempt++))
        done

        if [[ "$tag_created" == "false" ]]; then
            log_error "Failed to create local tag after $max_attempts attempts: $tag"
            return 1
        fi
    fi

    # Push tag to origin if it doesn't exist or was deleted
    if [[ "$tag_exists_on_origin" == "false" ]]; then
        log_info "Pushing tag to origin: $tag"

        # Retry logic: up to 3 attempts with 2-second delays
        local max_push_attempts=3
        local push_attempt=1
        local push_success=false

        while [[ $push_attempt -le $max_push_attempts ]]; do
            if git push origin "refs/tags/$tag" 2>/dev/null; then
                push_success=true
                log_success "Pushed tag to origin: $tag"
                break
            else
                log_warning "Attempt $push_attempt/$max_push_attempts failed: push to origin failed"
            fi

            if [[ $push_attempt -lt $max_push_attempts ]]; then
                log_info "Retrying in 2 seconds..."
                sleep 2
            fi

            ((push_attempt++))
        done

        if [[ "$push_success" == "false" ]]; then
            log_error "Failed to push tag to origin after $max_push_attempts attempts: $tag"
            return 1
        fi
    fi

    # ========================================================================
    # CRITICAL: Push commit to public remote BEFORE pushing tag
    # ========================================================================
    # CocoaPods will checkout the tag from public repo, so the commit
    # containing source files must exist in public repo first
    # 
    # NOTE: If SKIP_PUBLIC_REMOTE_PUSH is set, skip this step (for cases where
    # GitHub Push Protection blocks the push due to secrets in commit history)
    if [[ "${SKIP_PUBLIC_REMOTE_PUSH:-0}" == "1" ]]; then
        log_warning "SKIP_PUBLIC_REMOTE_PUSH=1: Skipping public remote push (secrets may be in commit history)"
        log_warning "CocoaPods may fail if tag is not accessible on public remote"
    elif git remote | grep -q "^public$"; then
        log_info "Ensuring commit $target_commit_sha exists on public remote"

        # Get current branch (or use HEAD if detached)
        local current_branch
        current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "HEAD")

        # Check if commit exists on public remote
        if ! git branch -r --contains "$target_commit_sha" | grep -q "public/"; then
            log_warning "Commit $target_commit_sha not found on public remote, pushing..."

            # Push current branch/HEAD to public remote
            # This ensures the commit and its history are available
            if [[ "$current_branch" == "HEAD" ]]; then
                # Detached HEAD - push commit directly
                log_info "Detached HEAD detected, pushing commit directly to public"
                if ! git push public "$target_commit_sha:refs/heads/temp-release-$tag" 2>/dev/null; then
                    log_warning "Failed to push commit to temp branch, trying force push to current branch"
                    # Try to push to a temporary ref
                    if ! git push public HEAD:refs/heads/release-temp 2>/dev/null; then
                        log_error "Failed to push commit to public remote"
                        # If MSP_ALLOW_PUBLIC_PUSH_FAILURE is set, continue anyway
                        if [[ "${MSP_ALLOW_PUBLIC_PUSH_FAILURE:-0}" == "1" ]]; then
                            log_warning "MSP_ALLOW_PUBLIC_PUSH_FAILURE=1: Continuing despite public remote push failure"
                        else
                            return 1
                        fi
                    fi
                fi
            else
                # Normal branch - push branch to public
                log_info "Pushing branch $current_branch to public"
                if ! git push public "$current_branch" 2>/dev/null; then
                    # If push fails (e.g., branch doesn't track public), try force push
                    log_warning "Normal push failed, trying with -u flag"
                    if ! git push -u public "$current_branch" 2>/dev/null; then
                        log_error "Failed to push branch to public remote"
                        # If MSP_ALLOW_PUBLIC_PUSH_FAILURE is set, continue anyway
                        if [[ "${MSP_ALLOW_PUBLIC_PUSH_FAILURE:-0}" == "1" ]]; then
                            log_warning "MSP_ALLOW_PUBLIC_PUSH_FAILURE=1: Continuing despite public remote push failure"
                        else
                            return 1
                        fi
                    fi
                fi
            fi

            log_success "Commit pushed to public remote"
        else
            log_info "Commit $target_commit_sha already exists on public remote"
        fi

        # Verify commit is now accessible on public remote
        sleep 2  # Brief wait for git server to process
        if ! git ls-remote public "$target_commit_sha" >/dev/null 2>&1; then
            # Try alternative verification
            if ! git branch -r --contains "$target_commit_sha" 2>/dev/null | grep -q "public/"; then
                log_error "Commit verification failed: $target_commit_sha not accessible on public"
                # If MSP_ALLOW_PUBLIC_PUSH_FAILURE is set, continue anyway
                if [[ "${MSP_ALLOW_PUBLIC_PUSH_FAILURE:-0}" == "1" ]]; then
                    log_warning "MSP_ALLOW_PUBLIC_PUSH_FAILURE=1: Continuing despite verification failure"
                else
                    return 1
                fi
            fi
        fi

        log_success "Commit $target_commit_sha verified on public remote"
    fi
    # ========================================================================

    # Push tag to public if it doesn't exist or was deleted
    if [[ "${SKIP_PUBLIC_REMOTE_PUSH:-0}" == "1" ]]; then
        log_warning "SKIP_PUBLIC_REMOTE_PUSH=1: Skipping tag push to public remote"
    elif [[ "$tag_exists_on_public" == "false" ]] && git remote | grep -q "^public$"; then
        log_info "Pushing tag to public: $tag"

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
                log_success "Pushed tag to public: $tag"
                break
            else
                log_warning "Attempt $public_attempt/$max_public_attempts failed: push to public failed"
            fi

            if [[ $public_attempt -lt $max_public_attempts ]]; then
                log_info "Retrying in 2 seconds..."
                sleep 2
            fi

            ((public_attempt++))
        done

        if [[ "$public_push_success" == "false" ]]; then
            log_warning "Failed to push tag to public after $max_public_attempts attempts: $tag"
            # Don't fail hard - public might not be accessible
        fi

        if [[ $push_exit_code -ne 0 ]]; then
            log_error "Failed to push tag to public: $tag"

            # Check if GitHub Push Protection blocked the push
            if echo "$push_output" | grep -qi "push protection"; then
                log_error "════════════════════════════════════════════════════════════"
                log_error "  GitHub Push Protection detected secrets in commit history"
                log_error "════════════════════════════════════════════════════════════"
                log_error ""
                log_error "解决方案 / Solutions:"
                log_error "  1. 访问 GitHub Web 界面，点击 'Allow this secret'"
                log_error "     Visit GitHub Web UI and click 'Allow this secret'"
                log_error ""
                log_error "  2. 检查推送输出中的 URL 链接"
                log_error "     Check the URL in the push output below:"
                log_error ""
                echo "$push_output"
                log_error ""
                log_error "  3. 完成授权后，运行修复命令:"
                log_error "     After authorization, run: ./Scripts/msp-release.sh fix-public-tag $tag"
                log_error ""
                log_error "  4. 然后重新运行发布脚本"
                log_error "     Then re-run the release script"
                log_error ""
                log_error "════════════════════════════════════════════════════════════"

                # Do NOT continue - force user to fix the issue
                if [[ "${MSP_ALLOW_PUBLIC_PUSH_FAILURE:-0}" == "1" ]]; then
                    log_warning "⚠️  MSP_ALLOW_PUBLIC_PUSH_FAILURE=1 已设置，但这会导致 CocoaPods 验证失败"
                    log_warning "⚠️  建议: 修复 GitHub Push Protection 问题后重新运行"
                    log_warning "⚠️  继续执行可能导致适配器模块发布失败..."
                    sleep 5  # Give user time to read the warning
                else
                    log_error "🛑 停止执行，请先解决 GitHub Push Protection 问题"
                    return 1
                fi
            else
                # Other push errors
                log_error "Push output:"
                echo "$push_output"

                if [[ "${MSP_ALLOW_PUBLIC_PUSH_FAILURE:-0}" == "1" ]]; then
                    log_warning "MSP_ALLOW_PUBLIC_PUSH_FAILURE=1: Continuing despite tag push failure"
                else
                    return 1
                fi
            fi
        else
            log_success "Pushed tag to public: $tag"
        fi
    fi

    # Final verification
    local final_tag_sha
    final_tag_sha=$(git rev-parse "refs/tags/$tag" 2>/dev/null || echo "")
    if [[ "$final_tag_sha" != "$target_commit_sha" ]]; then
        log_error "Tag verification failed: tag $tag points to $final_tag_sha, expected $target_commit_sha"
        return 1
    fi

    log_success "Tag $tag verified: points to commit $target_commit_sha"
    return 0
}

# Phase R1.18: Wait for remote tag to be resolvable (tag propagation timing fix)
wait_for_remote_tag() {
    local tag="$1"
    local max_attempts="${2:-12}"    # Default: 12 attempts
    local sleep_seconds="${3:-5}"    # Default: 5 seconds between attempts

    if [[ -z "$tag" ]]; then
        log_error "wait_for_remote_tag: tag parameter is required"
        return 1
    fi

    log_step "Waiting for remote tag '$tag' to be resolvable (Phase R1.18 timing fix)"

    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        log_info "Checking remote tag visibility (attempt $attempt/$max_attempts)..."

        # Check if tag is resolvable from origin
        if git ls-remote --tags origin "refs/tags/$tag" 2>/dev/null | grep -q "refs/tags/$tag"; then
            log_success "Remote tag '$tag' is now visible and resolvable"

            # Additional verification: try to fetch the tag reference
            if git fetch --tags --force origin "refs/tags/$tag:refs/tags/$tag" >/dev/null 2>&1; then
                log_success "Remote tag '$tag' fetch verification passed"
                return 0
            else
                log_warn "Tag visible but fetch verification failed (attempt $attempt/$max_attempts)"
            fi
        else
            log_info "Tag '$tag' not yet visible on remote"
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            log_info "Waiting ${sleep_seconds}s before next attempt..."
            sleep "$sleep_seconds"
        else
            # Phase R1.18: Fail-fast on timeout in release tier
            if [[ "${MSP_RELEASE_TIER:-}" == "release" ]]; then
                log_error "[FAIL-FAST] Timeout waiting for remote tag '$tag' to be resolvable after $max_attempts attempts"
                log_error "Tag was pushed but not yet propagated to all GitHub servers"
                log_error "This is a timing/availability issue, not a code bug"
                return 1
            else
                log_warn "Timeout waiting for remote tag (preflight tier - non-blocking)"
                return 0
            fi
        fi

        ((attempt++))
    done

    return 1
}

# Create GitHub release and upload zip
create_github_release_for_pod() {
    local pod="$1"
    local version="$2"

    log_step "Creating GitHub release for $pod"
    
    # Start timing
    if command -v metrics::start &>/dev/null; then
        metrics::start "publish_${pod}_github_release"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would create GitHub release for $pod version $version"
        if command -v metrics::end &>/dev/null; then
            metrics::end "publish_${pod}_github_release"
        fi
        return 0
    fi

    # Stage A: All tiers (test/release) create GitHub release and upload binary zip for binary distribution pods
    # HTTP binary distribution requires zip to be available before pod trunk push
    if is_binary_distribution "$pod"; then
        log_info "[${MSP_RELEASE_TIER:-test} tier] Creating GitHub release and uploading binary zip (HTTP distribution)"
        
        # Create zip file from XCFramework
        local zip_name="${pod}-${version}.zip"
        local xcframework_path="$ROOT_DIR/Build/XCFrameworks/${pod}.xcframework"
        local temp_zip_dir="/tmp/msp_release_zip_$$"
        
        mkdir -p "$temp_zip_dir/Binary"
        
        if [[ ! -d "$xcframework_path" ]]; then
            log_error "XCFramework not found: $xcframework_path"
            rm -rf "$temp_zip_dir"
            return 1
        fi

        # Copy XCFramework to temp directory structure
        cp -R "$xcframework_path" "$temp_zip_dir/Binary/${pod}.xcframework"
        
        # Handle MSPSharedLibraries special case (includes PrebidMobile and source files for hybrid mode)
        if [[ "$pod" == "MSPSharedLibraries" ]]; then
            local prebid_path="$ROOT_DIR/Build/XCFrameworks/PrebidMobile.xcframework"
            if [[ -d "$prebid_path" ]]; then
                mkdir -p "$temp_zip_dir/ThirdParty/PrebidMobile"
                cp -R "$prebid_path" "$temp_zip_dir/ThirdParty/PrebidMobile/PrebidMobile.xcframework"
            fi
            
            # Include MSPiOSCore.xcframework (embedded in MSPSharedLibraries)
            local mspioscore_path="$ROOT_DIR/Build/XCFrameworks/MSPiOSCore.xcframework"
            if [[ -d "$mspioscore_path" ]]; then
                cp -R "$mspioscore_path" "$temp_zip_dir/Binary/MSPiOSCore.xcframework"
                log_info "Included MSPiOSCore.xcframework in zip"
            else
                log_warning "MSPiOSCore.xcframework not found: $mspioscore_path"
            fi
            
            # Hybrid mode: Include source files for MSPSharedLibraries
            # This allows CocoaPods to compile source and properly expose MSPiOSCore module
            local source_path="$ROOT_DIR/Sources/Core/MSPSharedLibraries"
            if [[ -d "$source_path" ]]; then
                mkdir -p "$temp_zip_dir/Sources/Core"
                cp -R "$source_path" "$temp_zip_dir/Sources/Core/MSPSharedLibraries"
                log_info "Included source files in zip: Sources/Core/MSPSharedLibraries/"
            else
                log_warning "Source path not found: $source_path (hybrid mode may not work)"
            fi
    fi

    # Create zip file
        (cd "$temp_zip_dir" && zip -r "$ROOT_DIR/$zip_name" . >/dev/null 2>&1)
        rm -rf "$temp_zip_dir"
        
        if [[ ! -f "$ROOT_DIR/$zip_name" ]]; then
            log_error "Failed to create zip file: $zip_name"
            return 1
        fi
        
        log_info "Created zip file: $zip_name"
    
    # Create or update GitHub release
    local gh_release_created=false
    if gh release view "$version" --repo "ParticleMedia/msp-ios-sdk-public" &>/dev/null; then
        log_info "Release $version already exists, uploading assets"
            if gh release upload "$version" "$ROOT_DIR/$zip_name" --repo "ParticleMedia/msp-ios-sdk-public" --clobber; then
            gh_release_created=true
                # Ensure release is published (not draft) and set as latest
                gh release edit "$version" --repo "ParticleMedia/msp-ios-sdk-public" --draft=false --latest 2>/dev/null || true
        fi
    else
        log_info "Creating new release $version"
            if gh release create "$version" "$ROOT_DIR/$zip_name" --repo "ParticleMedia/msp-ios-sdk-public" --title "Release $version" --notes "Release $version" --latest; then
            gh_release_created=true
                # Ensure release is published (not draft)
                gh release edit "$version" --repo "ParticleMedia/msp-ios-sdk-public" --draft=false 2>/dev/null || true
        fi
    fi
    
    # Clean up zip file
        rm -f "$ROOT_DIR/$zip_name"
    
    if [[ "$gh_release_created" == "true" ]]; then
            log_success "GitHub release created and zip uploaded for $pod"
        
        # FIX: Calculate checksum from GitHub Release zip file (after upload) to ensure consistency
        # This ensures podspec checksum matches the actual zip file on GitHub Release
        log_step "Calculating SHA256 checksum from GitHub Release zip file"
        local zip_url="https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/${pod}-${version}.zip"
        local zip_checksum=""
        local temp_zip_dir="/tmp/msp-checksum-verify-$$"
        mkdir -p "$temp_zip_dir"
        
        # Wait for GitHub to process the upload (may take a few seconds)
        log_info "Waiting for GitHub to process upload (5 seconds)..."
        sleep 5
        
        # Download zip from GitHub Release and calculate checksum
        local download_attempt=1
        local max_download_attempts=3
        while [[ $download_attempt -le $max_download_attempts ]]; do
            log_info "Downloading zip from GitHub Release to verify checksum (attempt $download_attempt/$max_download_attempts)..."
            if curl -L -f -s -o "$temp_zip_dir/$zip_name" "$zip_url" 2>/dev/null; then
                local file_size=$(stat -f%z "$temp_zip_dir/$zip_name" 2>/dev/null || stat -c%s "$temp_zip_dir/$zip_name" 2>/dev/null || echo "0")
                if [[ $file_size -gt 0 ]]; then
                    if command -v shasum >/dev/null 2>&1; then
                        zip_checksum=$(shasum -a 256 "$temp_zip_dir/$zip_name" 2>/dev/null | cut -d' ' -f1)
                        if [[ -n "$zip_checksum" && ${#zip_checksum} -eq 64 ]]; then
                            log_success "Calculated SHA256 checksum from GitHub Release: $zip_checksum"
                            rm -rf "$temp_zip_dir"
                            break
                        else
                            log_warning "Invalid checksum format, retrying..."
                        fi
                    else
                        log_error "shasum command not available, cannot calculate checksum"
                        rm -rf "$temp_zip_dir"
                        return 1
                    fi
                else
                    log_warning "Downloaded zip file is empty, retrying..."
                fi
            else
                log_warning "Failed to download zip from GitHub Release, retrying..."
            fi
            
            if [[ $download_attempt -lt $max_download_attempts ]]; then
                sleep 5
            fi
            download_attempt=$((download_attempt + 1))
        done
        
        rm -rf "$temp_zip_dir"
        
        if [[ -z "$zip_checksum" ]] || [[ ${#zip_checksum} -ne 64 ]]; then
            log_error "Failed to calculate checksum from GitHub Release zip file"
            log_error "Podspec checksum may be incorrect. Please verify manually."
            # Continue anyway - podspec may already have correct checksum from generate_podspec.sh
        else
            # Update podspec with checksum from GitHub Release
            local podspec="$ROOT_DIR/Build/ReleasePodspecs/${pod}.podspec"
            if [[ -f "$podspec" ]]; then
                log_step "Updating podspec with SHA256 checksum from GitHub Release"
                # Use Ruby to properly insert checksum into source hash (more robust than sed)
                ruby <<RUBY_SCRIPT
podspec_path = '$podspec'
zip_url = '$zip_url'
zip_checksum = '$zip_checksum'

podspec_content = File.read(podspec_path)
# Replace the source block with checksum included
# Match the exact structure: spec.source = { ... } where ... can be any content including newlines
new_source = "  spec.source = {\n    :http => \"#{zip_url}\",\n    :type => \"zip\",\n    :sha256 => \"#{zip_checksum}\"\n  }"
# Use multiline mode and match from spec.source = { to closing brace with proper indentation
podspec_content.gsub!(/  spec\.source = \{.*?\n  \}/m, new_source)
File.write(podspec_path, podspec_content)
RUBY_SCRIPT
                log_success "Updated podspec with checksum from GitHub Release: $zip_checksum"
            else
                log_warning "Podspec not found for checksum update: $podspec"
            fi
        fi
        
        # Track GitHub release creation in state
        if command -v msp_state_mark_git_flag &>/dev/null; then
            msp_state_mark_git_flag "github_release_created" true
            if command -v msp_state_set_tag_name &>/dev/null; then
                msp_state_set_tag_name "$version"
            fi
        fi
            
            # End timing
            if command -v metrics::end &>/dev/null; then
                metrics::end "publish_${pod}_github_release"
            fi
    else
        log_error "Failed to create/update GitHub release for $pod"
            if command -v metrics::end &>/dev/null; then
                metrics::end "publish_${pod}_github_release"
            fi
            return 1
        fi

        return 0
    fi

    # For non-core modules (adapters), no GitHub release needed
    # They use git+tag source in podspec
    log_info "[${MSP_RELEASE_TIER:-test} tier] Non-core module $pod, skipping GitHub release creation"
    if command -v metrics::end &>/dev/null; then
        metrics::end "publish_${pod}_github_release"
    fi
    return 0
}

# Stage A: Probe zip URL availability before publishing
probe_zip_url() {
    local pod="$1"
    local version="$2"
    local max_attempts=12
    local sleep_seconds=5
    
    local zip_url="https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/${pod}-${version}.zip"
    
    log_step "Probing zip URL availability: $zip_url"
    
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if curl -sSfL --head "$zip_url" >/dev/null 2>&1; then
            log_success "Zip URL is accessible: $zip_url"
            return 0
        else
            if [[ $attempt -lt $max_attempts ]]; then
                log_info "Zip URL not yet accessible (attempt $attempt/$max_attempts), waiting ${sleep_seconds}s..."
                sleep "$sleep_seconds"
            else
                log_error "[FAIL-FAST] Zip URL not accessible after $max_attempts attempts: $zip_url"
                log_error "Binary zip must be available before pod trunk push (HTTP distribution)"
                return 1
            fi
        fi
        ((attempt++))
    done
    
    return 1
}

# ============================================================================
# Ensure zip file exists for binary distribution pod (Resume-safe)
# ============================================================================
# If a pod is marked as "published" but its zip file is missing from GitHub
# Release, this function will recreate and reupload the zip file to ensure
# podspec generation can proceed (checksum calculation requires zip file).
#
# This provides script-level guarantee that Resume can always complete even
# if previous releases were incomplete (e.g., zip upload failed but podspec
# was pushed to Trunk).
#
# Args:
#   $1: pod - Pod name
#   $2: version - Release version
#
# Returns:
#   0 if zip file exists or was successfully recreated
#   1 if zip file cannot be created (XCFramework missing)
# ============================================================================
ensure_zip_file_exists_for_pod() {
    local pod="$1"
    local version="$2"

    # Only check binary distribution pods
    if ! is_binary_distribution "$pod"; then
        return 0
    fi

    log_step "Ensuring zip file exists for $pod $version"

    local zip_url="https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/${pod}-${version}.zip"
    local zip_name="${pod}-${version}.zip"

    # ========================================================================
    # Force Re-upload Mode (MSP_FORCE_ZIP_REUPLOAD)
    # ========================================================================
    # When MSP_FORCE_ZIP_REUPLOAD=1, always delete and re-upload zip files
    # This helps clear CDN caches and ensures fresh uploads
    if [[ "${MSP_FORCE_ZIP_REUPLOAD:-0}" == "1" ]]; then
        log_warning "MSP_FORCE_ZIP_REUPLOAD=1: Forcing zip file re-upload"

        # Check if zip exists on GitHub Release
        if curl -L -f -I -s "$zip_url" >/dev/null 2>&1; then
            log_info "Deleting existing zip file from GitHub Release..."

            # Delete the asset using gh CLI
            if gh release delete-asset "$version" "$zip_name" \
                --repo "ParticleMedia/msp-ios-sdk-public" \
                --yes 2>/dev/null; then
                log_success "✅ Deleted existing zip file"

                # Wait for CDN to propagate deletion
                log_info "Waiting 10 seconds for CDN to clear cache..."
                sleep 10
            else
                log_warning "Failed to delete existing zip (may not exist or permission issue)"
            fi
        else
            log_info "No existing zip file to delete"
        fi

        # Continue with normal re-upload process
    fi

    # Check if zip file exists on GitHub Release
    log_info "Checking zip file: $zip_url"

    if curl -L -f -I -s "$zip_url" >/dev/null 2>&1; then
        log_success "✅ Zip file exists on GitHub Release"
        return 0
    fi

    log_warning "⚠️  Zip file not found on GitHub Release"
    log_info "Will recreate and reupload zip file (script-level guarantee)"

    # DRY_RUN mode: skip actual zip creation and upload
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Would recreate zip from XCFramework"
        log_info "DRY RUN: Would upload to GitHub Release"
        log_info "DRY RUN: Would verify upload"
        log_success "DRY RUN: Zip file would be verified/recreated"
        return 0
    fi

    # Check GitHub CLI authentication before proceeding
    if ! command -v gh &>/dev/null; then
        log_error "❌ GitHub CLI (gh) not found"
        log_error "Please install GitHub CLI: brew install gh"
        log_error "Then authenticate: gh auth login"
        return 1
    fi

    log_info "Checking GitHub CLI authentication..."
    if ! gh auth status &>/dev/null; then
        log_error "❌ GitHub CLI authentication failed"
        log_error "Please authenticate: gh auth login"
        log_error "Required scopes: repo, workflow"
        return 1
    fi

    log_info "✅ GitHub CLI authenticated"

    # Check if XCFramework exists locally
    local xcframework_path="$ROOT_DIR/Build/XCFrameworks/${pod}.xcframework"

    if [[ ! -d "$xcframework_path" ]]; then
        log_error "❌ XCFramework not found: $xcframework_path"
        log_error "Cannot recreate zip file without XCFramework"
        log_error "Expected location: $xcframework_path"
        log_error "Please ensure XCFramework was built successfully"
        return 1
    fi

    # Verify XCFramework is not empty
    if [[ ! -s "$xcframework_path/Info.plist" ]] && [[ ! -f "$xcframework_path/$(ls -A "$xcframework_path" | head -1)/Info.plist" ]]; then
        log_error "❌ XCFramework appears to be empty or corrupted: $xcframework_path"
        log_error "Please rebuild the XCFramework"
        return 1
    fi

    log_info "✅ XCFramework found and verified: $xcframework_path"

    # Create zip file from XCFramework
    log_info "Creating zip file from XCFramework..."

    local temp_zip_dir="/tmp/msp_zip_recovery_$$"
    mkdir -p "$temp_zip_dir"

    # Copy XCFramework to temp directory (same structure as original release)
    cp -R "$xcframework_path" "$temp_zip_dir/"

    # Check if zip command is available
    if ! command -v zip &>/dev/null; then
        log_error "❌ zip command not found"
        log_error "Please install zip utility"
        rm -rf "$temp_zip_dir"
        return 1
    fi

    # Create zip with detailed error output
    log_info "Zipping: $pod.xcframework → $zip_name"

    local zip_error_output
    zip_error_output=$(mktemp)
    
    (
        cd "$temp_zip_dir" || exit 1
        if zip -r "$zip_name" "${pod}.xcframework" >/dev/null 2>"$zip_error_output"; then
            log_success "✅ Zip file created: $zip_name"
        else
            log_error "❌ Failed to create zip file"
            log_error "Zip error output:"
            cat "$zip_error_output" >&2
            rm -f "$zip_error_output"
            exit 1
        fi
    )

    local zip_exit_code=$?
    rm -f "$zip_error_output"

    if [[ $zip_exit_code -ne 0 ]]; then
        rm -rf "$temp_zip_dir"
        return 1
    fi

    # Verify zip file was created and is not empty
    if [[ ! -f "$temp_zip_dir/$zip_name" ]]; then
        log_error "❌ Zip file was not created: $temp_zip_dir/$zip_name"
        rm -rf "$temp_zip_dir"
        return 1
    fi

    local zip_size
    zip_size=$(stat -f%z "$temp_zip_dir/$zip_name" 2>/dev/null || stat -c%s "$temp_zip_dir/$zip_name" 2>/dev/null || echo "0")
    
    if [[ $zip_size -eq 0 ]]; then
        log_error "❌ Zip file is empty: $temp_zip_dir/$zip_name"
        rm -rf "$temp_zip_dir"
        return 1
    fi

    log_info "✅ Zip file created successfully (size: $zip_size bytes)"

    # Move zip to Build/Zips for consistency
    mkdir -p "$ROOT_DIR/Build/Zips"
    mv "$temp_zip_dir/$zip_name" "$ROOT_DIR/Build/Zips/"

    # Cleanup temp directory
    rm -rf "$temp_zip_dir"

    log_success "✅ Zip file created: Build/Zips/$zip_name"

    # Calculate checksum for verification
    local checksum
    checksum=$(shasum -a 256 "$ROOT_DIR/Build/Zips/$zip_name" 2>/dev/null | awk '{print $1}')
    log_info "SHA256: $checksum"

    # Upload to GitHub Release
    log_info "Uploading zip file to GitHub Release..."

    # Check if release exists
    if ! gh release view "$version" --repo "ParticleMedia/msp-ios-sdk-public" &>/dev/null; then
        log_warning "GitHub Release $version does not exist, creating..."

        if ! gh release create "$version" \
            --repo "ParticleMedia/msp-ios-sdk-public" \
            --title "Release $version" \
            --notes "MSP iOS SDK Release $version" \
            --draft=false \
            --latest; then
            log_error "Failed to create GitHub Release"
            return 1
        fi

        log_success "✅ GitHub Release created"
    fi

    # Upload zip with retry mechanism (use --clobber to overwrite if exists)
    local upload_attempt=1
    local max_upload_attempts=3
    local upload_success=false

    while [[ $upload_attempt -le $max_upload_attempts ]]; do
        log_info "Uploading zip file to GitHub Release (attempt $upload_attempt/$max_upload_attempts)..."
        
        if gh release upload "$version" "$ROOT_DIR/Build/Zips/$zip_name" \
            --repo "ParticleMedia/msp-ios-sdk-public" \
            --clobber 2>&1; then
            log_success "✅ Zip file uploaded to GitHub Release"
            upload_success=true
            break
        else
            log_warning "⚠️  Upload attempt $upload_attempt failed"
            if [[ $upload_attempt -lt $max_upload_attempts ]]; then
                log_info "Retrying in 5 seconds..."
                sleep 5
            fi
            upload_attempt=$((upload_attempt + 1))
        fi
    done

    if [[ "$upload_success" != "true" ]]; then
        log_error "❌ Failed to upload zip file after $max_upload_attempts attempts"
        log_error "Local zip file preserved at: $ROOT_DIR/Build/Zips/$zip_name"
        log_error "You can manually upload it with:"
        log_error "  gh release upload $version $ROOT_DIR/Build/Zips/$zip_name --repo ParticleMedia/msp-ios-sdk-public --clobber"
        log_warning "Continuing anyway (local zip exists for checksum calculation)"
        return 0  # Return success to allow checksum calculation with local zip
    fi

    # ========================================================================
    # Verify upload with CDN cache invalidation
    # ========================================================================
    # Problem: GitHub CDN may cache old versions of zip files
    # Solution: Wait longer and verify checksum stability
    log_info "Verifying upload and waiting for CDN propagation..."

    # Increased wait time for CDN propagation (from 10s to 15s)
    local cdn_wait_time=15
    log_info "Waiting $cdn_wait_time seconds for CDN to update..."
    sleep $cdn_wait_time

    # Verify zip file is accessible
    if ! curl -L -f -I -s "$zip_url" >/dev/null 2>&1; then
        log_warning "⚠️  Zip file not immediately accessible (GitHub processing delay)"
        log_info "Waiting additional 10 seconds..."
        sleep 10

        if ! curl -L -f -I -s "$zip_url" >/dev/null 2>&1; then
            log_error "❌ Zip file still not accessible after 25 seconds"
            log_error "This may indicate upload failure or GitHub API delay"
            return 1
        fi
    fi

    # ========================================================================
    # Checksum Stability Verification (CDN Cache Invalidation)
    # ========================================================================
    # Verify that the zip file checksum is stable across multiple downloads
    # This ensures CDN has fully propagated the new version
    log_info "Verifying checksum stability (CDN cache check)..."

    local expected_checksum
    expected_checksum=$(shasum -a 256 "$ROOT_DIR/Build/Zips/$zip_name" 2>/dev/null | awk '{print $1}')

    log_info "Expected checksum: $expected_checksum"

    local stable=false
    local max_attempts=3
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        log_info "Checksum verification attempt $attempt/$max_attempts..."

        # Download and calculate checksum
        local temp_verify="/tmp/msp-verify-$$-$attempt"
        mkdir -p "$temp_verify"

        if curl -L -f -s -o "$temp_verify/verify.zip" "$zip_url" 2>/dev/null; then
            local actual_checksum
            actual_checksum=$(shasum -a 256 "$temp_verify/verify.zip" 2>/dev/null | awk '{print $1}')

            rm -rf "$temp_verify"

            if [[ "$actual_checksum" == "$expected_checksum" ]]; then
                log_success "✅ Checksum verified: $actual_checksum"
                stable=true
                break
            else
                log_warning "⚠️  Checksum mismatch (CDN may still be serving old version)"
                log_warning "   Expected: $expected_checksum"
                log_warning "   Got:      $actual_checksum"

                if [[ $attempt -lt $max_attempts ]]; then
                    log_info "Waiting 10 seconds for CDN to catch up..."
                    sleep 10
                fi
            fi
        else
            log_error "Failed to download zip for verification"
            rm -rf "$temp_verify"

            if [[ $attempt -lt $max_attempts ]]; then
                sleep 5
            fi
        fi

        ((attempt++))
    done

    if [[ "$stable" != "true" ]]; then
        log_error "❌ Checksum verification failed after $max_attempts attempts"
        log_error "CDN may be caching old version or upload is corrupted"
        log_error "This will likely cause CocoaPods validation to fail"

        if [[ "${MSP_RELEASE_TIER:-}" == "release" ]]; then
            log_error "[FAIL-FAST] Cannot proceed with unstable checksum in release mode"
            return 1
        else
            log_warning "Continuing in non-release mode (may fail during pod trunk push)"
        fi
    else
        log_success "✅ Zip file upload verified with stable checksum"
    fi

    return 0
}

# ============================================================================
# CocoaPods Trunk Verification (Resume Mechanism)
# ============================================================================

# Check if a specific pod version exists on CocoaPods Trunk
# Args: pod_name, version
# Returns: 0 if exists, 1 if not found
check_pod_published_on_trunk() {
    local pod="$1"
    local version="$2"

    log_info "🔍 Checking if $pod $version is published on CocoaPods Trunk..."

    # Method 1: pod trunk info (fastest and most reliable)
    if pod trunk info "$pod" 2>/dev/null | grep -q -- "- $version"; then
        log_success "✅ $pod $version found on Trunk (via trunk info)"
        return 0
    fi

    # Method 2: pod search (fallback)
    if pod search "$pod" --simple 2>/dev/null | grep -q -- "-> $version"; then
        log_success "✅ $pod $version found on Trunk (via search)"
        return 0
    fi

    # Method 3: Check pod spec repo (last resort)
    if pod spec cat "$pod" 2>/dev/null | grep -q -- "version.*$version"; then
        log_success "✅ $pod $version found in spec repo"
        return 0
    fi

    log_warning "⚠️  $pod $version not found on Trunk"
    return 1
}

# Verify all pods in list are published
# Args: version, pod_list (space-separated)
verify_all_pods_on_trunk() {
    local version="$1"
    shift
    local pods=("$@")

    log_info "🔍 Verifying ${#pods[@]} pods on CocoaPods Trunk..."

    local all_found=true
    for pod in "${pods[@]}"; do
        if ! check_pod_published_on_trunk "$pod" "$version"; then
            all_found=false
        fi
    done

    if [[ "$all_found" == "true" ]]; then
        log_success "✅ All pods verified on Trunk"
        return 0
    else
        log_error "❌ Some pods not found on Trunk"
        return 1
    fi
}

# ============================================================================
# Resume-Aware Pod Publishing
# ============================================================================

# Publish pod with resume support (three-tier verification)
# Args: pod_name, version, podspec_path
# Returns: 0 if published or already exists, 1 if failed
publish_pod_with_resume() {
    local pod="$1"
    local version="$2"
    local podspec="$3"

    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "📦 Publishing: $pod $version"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Tier 1: Check local state (fast path)
    local local_status
    if command -v msp_state_get_pod_status &>/dev/null; then
        local_status=$(msp_state_get_pod_status "$pod")
        log_info "📝 Local state: $local_status"
    else
        local_status="unknown"
    fi

    if [[ "$local_status" == "published" ]]; then
        log_info "ℹ️  Local state indicates pod was published"

        # Tier 2: Verify with Trunk (authoritative)
        if check_pod_published_on_trunk "$pod" "$version"; then
            log_success "⏭️  Skipping $pod $version (already published on Trunk)"
            return 0
        else
            log_warning "⚠️  Local state says published, but not found on Trunk"
            log_warning "   This may indicate:"
            log_warning "   - Trunk indexing delay (wait a few minutes)"
            log_warning "   - Local state corruption"
            log_warning "   - Pod was deleted from Trunk"
            log_info "ℹ️  Will retry publishing..."

            # Mark as inconsistent
            if command -v msp_state_mark_pod_status &>/dev/null; then
                msp_state_mark_pod_status "$pod" "inconsistent"
            fi
        fi
    fi

    # ========================================================================
    # Auto-Build Missing XCFrameworks for Binary Distribution Adapters
    # ========================================================================
    # For binary distribution adapters, automatically build missing XCFrameworks
    # to avoid manual intervention and ensure script-level guarantees.
    #
    # Applies to: MSPPrebidAdapter, MSPGoogleAdapter, MSPFacebookAdapter, AmazonAdapter
    # Does NOT apply to:
    # - NovaAdapter: Uses pre-packaged Binary/NovaCore.xcframework
    # - Core pods: Require pre-built XCFrameworks from build pipeline
    # ========================================================================
    if is_binary_distribution "$pod"; then
        case "$pod" in
            MSPPrebidAdapter|MSPGoogleAdapter|MSPFacebookAdapter|AmazonAdapter)
                local xcframework_path="$ROOT_DIR/Build/XCFrameworks/${pod}.xcframework"

                if [[ ! -d "$xcframework_path" ]]; then
                    log_warning "XCFramework missing for $pod, auto-building..."
                    log_info "Path: $xcframework_path"

                    # Build the missing XCFramework
                    local build_script="$ROOT_DIR/Scripts/xcframeworks/build_module.sh"

                    if [[ ! -x "$build_script" ]]; then
                        log_error "Build script not found or not executable: $build_script"
                        log_error "Cannot auto-build XCFramework for $pod"
                        return 1
                    fi

                    log_info "Running: $build_script $pod"

                    if "$build_script" "$pod" 2>&1 | tee "/tmp/auto-build-${pod}.log"; then
                        log_success "✅ Auto-built XCFramework: $pod"

                        # Verify build result
                        if [[ -d "$xcframework_path" ]]; then
                            log_info "Verified: $xcframework_path exists"
                            local size
                            size=$(du -sh "$xcframework_path" 2>/dev/null | cut -f1)
                            log_info "Size: $size"
                        else
                            log_error "Build reported success but XCFramework not found: $xcframework_path"
                            return 1
                        fi
                    else
                        log_error "❌ Failed to auto-build XCFramework for $pod"
                        log_error "Build log: /tmp/auto-build-${pod}.log"
                        log_error "Please check the build errors above"
                        return 1
                    fi
                else
                    log_debug "XCFramework exists: $xcframework_path"
                fi
                ;;
            NovaAdapter)
                log_debug "NovaAdapter uses pre-packaged Binary/, skipping XCFramework check"
                ;;
            MSPiOSCore|MSPSharedLibraries|MSPCore)
                log_debug "Core pod $pod requires pre-built XCFramework from build pipeline"
                ;;
        esac
    fi

    # ========================================================================
    # GitHub Release Lock Mechanism (Concurrent Control)
    # ========================================================================
    # Prevents multiple pods from simultaneously modifying the same GitHub Release
    acquire_github_release_lock() {
        local version_tag="$1"
        local timeout="${2:-60}"  # Default 60 seconds timeout
        local lock_file="/tmp/msp-release-github-${version_tag}.lock"
        local wait_interval=2
        local elapsed=0

        # Open lock file descriptor
        exec 200>"$lock_file"

        log_debug "LOCK" "Attempting to acquire lock for GitHub Release: $version_tag"

        # Check if flock is available (Linux) or use fallback (macOS)
        if ! command -v flock >/dev/null 2>&1; then
            # macOS: flock not available, skip locking (acceptable for single-process releases)
            log_debug "LOCK" "flock not available (macOS), skipping file locking"
            return 0
        fi

        while true; do
            # Try to acquire exclusive lock (non-blocking)
            if flock -x -n 200; then
                # Lock acquired, write lock info
                echo "$$:$(date -u +%Y-%m-%dT%H:%M:%SZ):$(hostname)" >&200
                export GITHUB_RELEASE_LOCK_FD=200
                log_info "LOCK" "✓ Acquired lock for GitHub Release: $version_tag"
                return 0
            fi

            # Check timeout
            if [[ $elapsed -ge $timeout ]]; then
                # Read lock holder info
                local lock_holder
                lock_holder=$(cat "$lock_file" 2>/dev/null || echo "unknown")
                log_error "LOCK" "Failed to acquire lock for $version_tag after ${timeout}s (holder: $lock_holder)"
                return 1
            fi

            # Wait and retry
            log_debug "LOCK" "Lock busy, waiting... (${elapsed}/${timeout}s)"
            sleep $wait_interval
            elapsed=$((elapsed + wait_interval))
        done
    }

    release_github_release_lock() {
        if ! command -v flock >/dev/null 2>&1; then
            # macOS: No lock to release
            return 0
        fi

        if [[ -n "${GITHUB_RELEASE_LOCK_FD:-}" ]]; then
            # Release lock by closing file descriptor
            eval "exec ${GITHUB_RELEASE_LOCK_FD}>&-"
            unset GITHUB_RELEASE_LOCK_FD
            log_info "LOCK" "✓ Released GitHub Release lock"
        fi
    }

    # ========================================================================
    # GitHub Release Asset Backup/Restore (Binary File Recovery)
    # ========================================================================
    # Preserves binary assets (XCFramework zips) when recreating Release
    backup_github_release_assets() {
        local version_tag="$1"
        local release_repo="$2"
        local backup_dir="/tmp/msp-release-assets-backup-${version_tag}-$$"

        log_info "BACKUP" "Backing up GitHub Release assets for $version_tag..."

        # Create backup directory
        mkdir -p "$backup_dir"

        # Get list of assets
        local assets
        assets=$(gh release view "$version_tag" --repo "$release_repo" --json assets --jq '.assets[].name' 2>/dev/null || echo "")

        if [[ -z "$assets" ]]; then
            log_debug "BACKUP" "No assets to backup"
            echo "$backup_dir"
            return 0
        fi

        # Download each asset
        local asset_count=0
        while IFS= read -r asset_name; do
            [[ -z "$asset_name" ]] && continue

            log_debug "BACKUP" "Downloading asset: $asset_name"
            if gh release download "$version_tag" \
                --repo "$release_repo" \
                --pattern "$asset_name" \
                --dir "$backup_dir" \
                --clobber 2>/dev/null; then
                asset_count=$((asset_count + 1))
                log_debug "BACKUP" "✓ Backed up: $asset_name"
            else
                log_warn "BACKUP" "Failed to backup: $asset_name"
            fi
        done <<< "$assets"

        log_info "BACKUP" "✓ Backed up $asset_count asset(s) to: $backup_dir"
        echo "$backup_dir"
    }

    restore_github_release_assets() {
        local version_tag="$1"
        local release_repo="$2"
        local backup_dir="$3"

        # Check if backup directory exists and has files
        if [[ ! -d "$backup_dir" ]] || [[ -z "$(ls -A "$backup_dir" 2>/dev/null)" ]]; then
            log_debug "RESTORE" "No assets to restore from: $backup_dir"
            return 0
        fi

        log_info "RESTORE" "Restoring assets to GitHub Release: $version_tag..."

        # Upload each backed up file
        local restored_count=0
        for asset_file in "$backup_dir"/*; do
            [[ ! -f "$asset_file" ]] && continue

            local asset_name
            asset_name=$(basename "$asset_file")

            log_debug "RESTORE" "Uploading asset: $asset_name"
            if gh release upload "$version_tag" \
                --repo "$release_repo" \
                "$asset_file" \
                --clobber 2>/dev/null; then
                restored_count=$((restored_count + 1))
                log_debug "RESTORE" "✓ Restored: $asset_name"
            else
                log_warn "RESTORE" "Failed to restore: $asset_name"
            fi
        done

        log_info "RESTORE" "✓ Restored $restored_count asset(s)"

        # Cleanup backup directory
        rm -rf "$backup_dir"
        log_debug "RESTORE" "Cleaned up backup directory"
    }

    # ========================================================================
    # Checksum Issue Auto-Fix Helper
    # ========================================================================
    # Detects and fixes checksum verification errors for source-based adapters
    # Root cause: GitHub Release's auto-generated source code zip conflicts with git tag
    auto_fix_checksum_issue() {
        local pod_name="$1"
        local version_tag="$2"
        local error_output="$3"

        # Check if this is a checksum verification error
        if ! echo "$error_output" | grep -q "Verification checksum was incorrect"; then
            return 1  # Not a checksum issue
        fi

        log_warn "PUBLISH" "Detected checksum verification error for $pod_name"
        log_info "PUBLISH" "This usually happens when GitHub Release source code zip doesn't match git tag"

        # Check if pod is source-based (Adapters use git+tag)
        local podspec_file="${ROOT_DIR}/Build/ReleasePodspecs/${pod_name}.podspec"
        if [[ ! -f "$podspec_file" ]]; then
            log_error "PUBLISH" "Podspec not found: $podspec_file"
            return 1
        fi

        # Verify this is a source-based distribution (has git: in source)
        if ! grep -q "git:" "$podspec_file"; then
            log_warn "PUBLISH" "Not a source-based distribution, cannot auto-fix"
            return 1
        fi

        log_info "PUBLISH" "Confirmed: $pod_name is source-based (git+tag)"
        log_info "PUBLISH" "Source-based adapters use main tag: $version_tag"
        log_info "PUBLISH" "Attempting automatic fix..."

        # Source-based adapters use the main tag (e.g., 0.3.0-rc.13), not pod-specific tags
        # Check if main GitHub Release exists
        local release_repo="ParticleMedia/msp-ios-sdk-public"
        if ! gh release view "$version_tag" --repo "$release_repo" &>/dev/null; then
            log_warn "PUBLISH" "GitHub Release $version_tag doesn't exist in $release_repo"
            log_info "PUBLISH" "Creating new GitHub Release for main tag..."
            
            # Create new release from tag
            local release_notes="MSP iOS SDK ${version_tag}

This release includes source code for all adapters.
Source code is distributed via git tag.

Automatically created to resolve checksum verification issue."

            if ! gh release create "$version_tag" \
                --repo "$release_repo" \
                --title "MSP iOS SDK $version_tag" \
                --notes "$release_notes" \
                --target "release/${version_tag}"; then
                log_error "PUBLISH" "Failed to create GitHub Release $version_tag"
                return 1
            fi

            log_info "PUBLISH" "✓ Created GitHub Release $version_tag"
        else
            log_info "PUBLISH" "Found existing GitHub Release: $version_tag"
            log_info "PUBLISH" "Deleting and recreating to match current git tag..."

            # ═══════════════════════════════════════════════════════════════
            # CONCURRENT CONTROL: Acquire lock to prevent race conditions
            # ═══════════════════════════════════════════════════════════════
            if ! acquire_github_release_lock "$version_tag" 120; then
                log_error "PUBLISH" "Failed to acquire lock for GitHub Release operation"
                return 1
            fi

            # Setup cleanup trap to ensure lock is released on error
            trap 'release_github_release_lock' EXIT ERR

            # ═══════════════════════════════════════════════════════════════
            # ASSET BACKUP: Preserve binary files before deletion
            # ═══════════════════════════════════════════════════════════════
            local backup_dir
            backup_dir=$(backup_github_release_assets "$version_tag" "$release_repo")

            # Delete the conflicting release (keep tag)
            if ! gh release delete "$version_tag" --repo "$release_repo" --yes; then
                log_error "PUBLISH" "Failed to delete GitHub Release $version_tag"
                release_github_release_lock
                return 1
            fi

            log_info "PUBLISH" "✓ Deleted GitHub Release $version_tag"

            # Wait for GitHub to process deletion
            sleep 2

            # Recreate release from current tag
            local release_notes="MSP iOS SDK ${version_tag}

This release includes source code for all adapters.
Source code is distributed via git tag.

Automatically recreated to resolve checksum verification issue."

            if ! gh release create "$version_tag" \
                --repo "$release_repo" \
                --title "MSP iOS SDK $version_tag" \
                --notes "$release_notes" \
                --target "release/${version_tag}"; then
                log_error "PUBLISH" "Failed to recreate GitHub Release $version_tag"
                release_github_release_lock
                return 1
            fi

            log_info "PUBLISH" "✓ Recreated GitHub Release $version_tag"

            # ═══════════════════════════════════════════════════════════════
            # ASSET RESTORE: Restore binary files to new Release
            # ═══════════════════════════════════════════════════════════════
            restore_github_release_assets "$version_tag" "$release_repo" "$backup_dir"

            # ═══════════════════════════════════════════════════════════════
            # Release lock after successful operation
            # ═══════════════════════════════════════════════════════════════
            release_github_release_lock
            trap - EXIT ERR  # Clear trap after successful completion
        fi

        # Wait for GitHub to generate new source code zip
        log_info "PUBLISH" "Waiting for GitHub to generate source code archive..."
        sleep 5

        log_info "PUBLISH" "✓ Checksum issue fixed automatically"
        log_info "PUBLISH" "CocoaPods Trunk will now download fresh source code zip"

        return 0
    }

    # ========================================================================
    # CRITICAL: Ensure binary distribution pods have valid checksum
    # ========================================================================
    if is_binary_distribution "$pod"; then
        local podspec="$ROOT_DIR/Build/ReleasePodspecs/${pod}.podspec"

        # Check if podspec has sha256
        if [[ -f "$podspec" ]] && ! grep -q ":sha256" "$podspec"; then
            log_warn "Binary distribution pod $pod missing sha256, updating..."

            # Calculate checksum from GitHub release
            local zip_url="https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/${pod}-${version}.zip"
            local zip_checksum

            # Download and calculate checksum
            zip_checksum=$(curl -sL "$zip_url" 2>/dev/null | shasum -a 256 2>/dev/null | cut -d' ' -f1)

            if [[ -n "$zip_checksum" ]]; then
                log_info "Calculated checksum from GitHub: $zip_checksum"

                # Update podspec using Ruby (FIXED - use heredoc with single quotes)
                # Export variables for Ruby to access via ENV
                export PODSPEC_PATH="$podspec"
                export ZIP_CHECKSUM="$zip_checksum"

                # Use <<'RUBY_SCRIPT' (with quotes) to prevent shell interpretation
                if ruby <<'RUBY_SCRIPT'
require 'pathname'

podspec_path = ENV['PODSPEC_PATH']
zip_checksum = ENV['ZIP_CHECKSUM']

podspec_content = File.read(podspec_path)

# Use block form to avoid shell escaping issues
# Pattern: :type => "zip"\n  }
# Replace: :type => "zip",\n    :sha256 => "checksum"\n  }
if podspec_content.sub!(/(:type\s*=>\s*"zip")(\s*\n\s*\})/) do
  "#{$1},\n    :sha256 => \"#{zip_checksum}\"#{$2}"
end
  File.write(podspec_path, podspec_content)
  puts "✅ Updated #{Pathname.new(podspec_path).basename} with sha256"
  exit 0
else
  puts "❌ Could not find :type => \"zip\" in podspec"
  exit 1
end
RUBY_SCRIPT
                then
                    log_success "Updated $pod podspec with sha256: $zip_checksum"
                else
                    log_error "Ruby script failed to update podspec"
                    return 1
                fi
            else
                log_error "Failed to calculate checksum for $pod from $zip_url"
                log_error "Ensure the zip file exists in GitHub release"
                return 1
            fi
        elif [[ -f "$podspec" ]]; then
            # Verify existing checksum matches GitHub
            local existing_checksum=$(grep ":sha256" "$podspec" | sed 's/.*"\(.*\)".*/\1/')
            local zip_url="https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/${pod}-${version}.zip"
            local actual_checksum=$(curl -sL "$zip_url" 2>/dev/null | shasum -a 256 2>/dev/null | cut -d' ' -f1)

            if [[ -n "$actual_checksum" ]] && [[ "$existing_checksum" != "$actual_checksum" ]]; then
                log_warn "Checksum mismatch for $pod! Updating..."
                log_info "  Existing: $existing_checksum"
                log_info "  Actual:   $actual_checksum"

                # Update with correct checksum
                sed -i.backup "s/:sha256 => \".*\"/:sha256 => \"$actual_checksum\"/" "$podspec"
                log_success "Updated $pod podspec checksum"
            elif [[ -n "$actual_checksum" ]]; then
                log_info "Checksum verified for $pod: $existing_checksum"
            fi
        fi
    fi

    # Tier 3: Attempt to publish
    log_info "📦 Publishing $pod $version to CocoaPods Trunk..."

    # Create temp log file
    local log_file
    log_file=$(mktemp)

    # Construct skip-tests flag based on environment variable
    local skip_tests_flag=""
    if [[ "${MSP_SKIP_TRUNK_TESTS:-0}" == "1" ]]; then
        skip_tests_flag="--skip-tests"
        log_info "PUBLISH" "Using --skip-tests (MSP_SKIP_TRUNK_TESTS=1) - skipping dependency validation"
    else
        log_info "PUBLISH" "Using full validation (MSP_SKIP_TRUNK_TESTS=0) - validating all dependencies"
    fi

    # Publish with captured output
    local publish_output
    publish_output=$(pod trunk push "$podspec" --allow-warnings $skip_tests_flag 2>&1 | tee "$log_file"; echo "${PIPESTATUS[0]}")
    local publish_exit_code="${publish_output##*$'\n'}"
    publish_output="${publish_output%$'\n'*}"

    if [[ "$publish_exit_code" == "0" ]]; then
        log_success "✅ $pod $version published successfully"

        # Update state
        if command -v msp_state_mark_pod_status &>/dev/null; then
            msp_state_mark_pod_status "$pod" "published"
            msp_state_set_pod_trunk_verified "$pod" "true"
        fi

        rm -f "$log_file"
        return 0
    else
        # ========================================================================
        # Auto-fix: Checksum verification error
        # ========================================================================
        # Check if this is a checksum issue and auto-fix if possible
        if auto_fix_checksum_issue "$pod" "$version" "$publish_output"; then
            log_info "PUBLISH" "Checksum issue fixed, retrying publication..."

            # Retry publication after fix (reuse skip_tests_flag from above)
            publish_output=$(pod trunk push "$podspec" --allow-warnings $skip_tests_flag 2>&1 | tee "$log_file"; echo "${PIPESTATUS[0]}")
            publish_exit_code="${publish_output##*$'\n'}"
            publish_output="${publish_output%$'\n'*}"

            if [[ "$publish_exit_code" == "0" ]]; then
                log_info "PUBLISH" "✓ Publication succeeded after auto-fix"
                # Update state
                if command -v msp_state_mark_pod_status &>/dev/null; then
                    msp_state_mark_pod_status "$pod" "published"
                    msp_state_set_pod_trunk_verified "$pod" "true"
                fi
                rm -f "$log_file"
                return 0
            else
                log_error "PUBLISH" "❌ Publication still failed after auto-fix"
                log_error "PUBLISH" "Error details:"
                echo "$publish_output" | while IFS= read -r line; do
                    # Filter out empty lines to reduce log noise
                    [[ -n "$line" ]] &&
                    log_error "PUBLISH" "  $line"
                done
                rm -f "$log_file"
                return 1
            fi
        fi

        # Check if error is "version already exists"
        if grep -q "already exists" "$log_file" || grep -q "Unable to accept duplicate entry" "$log_file"; then
            log_warning "⚠️  $pod $version already exists on Trunk"
            log_info "ℹ️  This is expected if resuming after partial failure"

            # Verify it's actually there
            sleep 2  # Brief pause for Trunk indexing
            if check_pod_published_on_trunk "$pod" "$version"; then
                log_success "✅ Verified: $pod $version is on Trunk"

                # Update local state to match Trunk
                if command -v msp_state_mark_pod_status &>/dev/null; then
                    msp_state_mark_pod_status "$pod" "published"
                    msp_state_set_pod_trunk_verified "$pod" "true"
                fi

                rm -f "$log_file"
                return 0
            fi
        fi

        # Real failure
        log_error "❌ Failed to publish $pod $version"

        # Save error context
        if command -v msp_state_mark_pod_status &>/dev/null; then
            msp_state_mark_pod_status "$pod" "failed"
        fi

        # Show error details
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error "Error details:"
        tail -20 "$log_file" | sed 's/^/  /'
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        rm -f "$log_file"
        return 1
    fi
}

# Publish pod to CocoaPods
publish_pod_to_cocoapods() {
    local pod="$1"
    local version="$2"

    # Use generated podspec from Build/ReleasePodspecs/ (Phase R1.7: use absolute path)
    local podspec="$ROOT_DIR/Build/ReleasePodspecs/${pod}.podspec"

    log_step "Publishing $pod to CocoaPods using generated podspec"
    
    # Start timing for trunk push
    if command -v metrics::start &>/dev/null; then
        metrics::start "publish_${pod}_trunk_push"
    fi

    if [[ ! -f "$podspec" ]]; then
        log_error "Generated podspec not found: $podspec"
        log_error "Make sure update_podspec_for_release() was called first"

        # Phase R1.7: Fail-fast in release tier to prevent infinite wait loops
        if [[ "${MSP_RELEASE_TIER:-}" == "release" ]]; then
            log_error "[FAIL-FAST] Podspec not found in release tier. Aborting to prevent wait loop."
            msp_state_mark_step_failed "pods_publish" "Podspec not found: $podspec" "1"
            exit 1
        fi
        return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would publish $pod version $version to CocoaPods using $podspec"
        return 0
    fi

    # Stage A: Probe zip URL availability in release tier (HTTP distribution)
    # Only check for binary distribution pods (core modules)
        if [[ "${MSP_RELEASE_TIER:-}" == "release" ]]; then
        # Check if this pod uses binary distribution (needs GitHub release zip)
        # Note: NovaCore is not included - it's embedded via vendored_frameworks, not published separately
        # Stage B: MSPOMSDK removed - OMSDK now embedded in NovaCore
        local core_modules=("MSPSharedLibraries" "MSPGoogleAdsTypes" "MSPCore" "MSPiOSCore")
        local is_binary=false
        
        # Check if it's a core module
        for core in "${core_modules[@]}"; do
            if [[ "$pod" == "$core" ]]; then
                is_binary=true
                break
            fi
        done
        
        if [[ "$is_binary" == "true" ]]; then
            log_info "$pod: Verifying binary zip availability (HTTP distribution)"
            if ! probe_zip_url "$pod" "$version"; then
                log_error "[FAIL-FAST] Binary zip not available, cannot publish to CocoaPods"
                msp_state_mark_step_failed "pods_publish" "Binary zip not available: ${pod}-${version}.zip" "1"
                exit 1
            fi
        else
            log_info "$pod: Skipping zip verification (source-based distribution via git+tag)"
        fi
    fi

    # Validate podspec if not skipped
    if [[ "$SKIP_VALIDATION" != "true" ]]; then
        # ═══════════════════════════════════════════════════════════════
        # All tiers: Skip LOCAL validation (HTTP zip not available yet)
        # Validation will be done by CocoaPods Trunk server
        # ═══════════════════════════════════════════════════════════════
        log_info "[$MSP_RELEASE_TIER tier] Skipping local podspec validation"
        log_info "Reason: HTTP zip source requires GitHub Release to be created first"
        log_info "Validation will be performed by CocoaPods Trunk during publication"
        log_info ""
        log_info "If publication fails, check:"
        log_info "  1. GitHub Release exists: gh release view $VERSION"
        log_info "  2. Zip file uploaded: gh release view $VERSION --json assets"
        log_info "  3. Zip URL accessible: curl -I \$ZIP_URL"
    fi

    # Publish to CocoaPods (use resume-aware function if in resume mode)
    # Note: MSP_RESUME_MODE is set to "1" in msp-release.sh resume command
    if [[ "${MSP_RESUME_MODE:-0}" == "1" ]]; then
        # Resume mode: use resume-aware publish function
        if ! publish_pod_with_resume "$pod" "$version" "$podspec"; then
            log_error "Failed to publish $pod to CocoaPods"
            return 1
        fi
    else
        # Normal mode: use standard publish function
        # Mark as pending before publishing
        if command -v msp_state_mark_pod_status &>/dev/null; then
            msp_state_mark_pod_status "$pod" "pending"
        fi

    if ! publish_podspec_with_retry "$podspec"; then
        log_error "Failed to publish $pod to CocoaPods"
            # Mark as failed
            if command -v msp_state_mark_pod_status &>/dev/null; then
                msp_state_mark_pod_status "$pod" "failed"
            fi
            # End timing even on failure
            if command -v metrics::end &>/dev/null; then
                metrics::end "publish_${pod}_trunk_push"
                metrics::record "cocoapods_failure_count" 1 "count"
            fi
        return 1
        fi

        # Mark as published on success
        if command -v msp_state_mark_pod_status &>/dev/null; then
            msp_state_mark_pod_status "$pod" "published"
            msp_state_set_pod_trunk_verified "$pod" "true"
        fi
        
        # End timing for trunk push
        if command -v metrics::end &>/dev/null; then
            metrics::end "publish_${pod}_trunk_push"
        fi
    fi

    log_success "Published $pod to CocoaPods"
}

# Wait for pod to be available
wait_for_pod_availability() {
    local pod="$1"
    local version="$2"
    local max_attempts=12  # Increased from 8 to 12 for longer waiting period
    local base_delay=20  # Increased from 15 to 20 seconds for better CDN propagation coverage
    
    log_step "Waiting for $pod version $version to be available"
    
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if check_pod_availability "$pod" "$version"; then
            log_success "$pod version $version is now available"
            return 0
        else
            if [[ $attempt -lt $max_attempts ]]; then
                local delay=$((base_delay * (1 << (attempt - 1))))
                log_info "Waiting ${delay}s for $pod to be published (attempt $attempt/$max_attempts)..."
                sleep $delay
            else
                log_error "Timeout waiting for $pod version $version to be published"
                return 1
            fi
        fi
        ((attempt++))
    done
    
    return 1
}

# ============================================================================
# Release MSPiOSCore (foundation - required by all modules)
# ============================================================================
release_msp_ioscore() {
    log_section "Step 0: Releasing MSPiOSCore (foundation - required by all modules)"
    
    # Start timing
    if command -v metrics::start &>/dev/null; then
        metrics::start "pod_MSPiOSCore"
    fi

    # Check if MSPiOSCore is already published (idempotency)
    if [[ "$DRY_RUN" != "true" ]]; then
        if check_pod_availability "MSPiOSCore" "$VERSION"; then
            log_info "MSPiOSCore $VERSION is already published to CocoaPods, skipping release"
            log_success "MSPiOSCore $VERSION already available"
            if command -v metrics::end &>/dev/null; then
                metrics::end "pod_MSPiOSCore"
            fi
            return 0
        fi
    fi

    # Ensure zip file exists for binary distribution pods (Resume-safe)
    # This provides script-level guarantee that podspec generation will succeed
    # even if previous release was incomplete (zip missing but pod published)
    if is_binary_distribution "MSPiOSCore"; then
        log_info "Verifying zip file exists for binary distribution pod..."

        if ! ensure_zip_file_exists_for_pod "MSPiOSCore" "$VERSION"; then
            log_error "Failed to ensure zip file exists for MSPiOSCore"

            if [[ "${MSP_RELEASE_TIER:-}" == "release" ]]; then
                log_error "[FAIL-FAST] Cannot proceed without zip file. Aborting."
                exit 1
            fi

            return 1
        fi

        log_success "Zip file verified/recreated for MSPiOSCore"
    fi

    # Update podspec (now guaranteed to succeed if binary distribution)
    if ! update_podspec_for_release "MSPiOSCore" "$VERSION"; then
        # FAIL-FAST: Immediately abort if podspec generation fails (release tier only)
        if [[ "${MSP_RELEASE_TIER:-}" == "release" ]]; then
            log_error "[FAIL-FAST] Podspec generation failed for MSPiOSCore. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Podspec generation failed for MSPiOSCore" "1"
            exit 1
        fi
        return 1
    fi

    # FAIL-FAST: Verify generated podspec exists (release tier only)
    local podspec_path="$ROOT_DIR/Build/ReleasePodspecs/MSPiOSCore.podspec"
    if [[ "${MSP_RELEASE_TIER:-}" == "release" ]] && [[ ! -f "$podspec_path" ]]; then
        log_error "[FAIL-FAST] Generated podspec not found: $podspec_path. Aborting release."
        msp_state_mark_step_failed "pods_publish" "Generated podspec not found: $podspec_path" "1"
        exit 1
    fi

    # Create GitHub release
    create_github_release_for_pod "MSPiOSCore" "$VERSION"

    # Publish to CocoaPods
    # Phase R1.11: Fail-fast if publication fails (prevent wait loop)
    if ! publish_pod_to_cocoapods "MSPiOSCore" "$VERSION"; then
        if [[ "${MSP_RELEASE_TIER:-}" == "release" ]]; then
            log_error "[FAIL-FAST] Failed to publish MSPiOSCore to CocoaPods. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Failed to publish MSPiOSCore" "1"
            exit 1
        fi
        return 1
    fi

    # Wait for availability (skip in dry-run mode)
    if [[ "$DRY_RUN" != "true" ]]; then
        smart_wait_for_pod_availability "MSPiOSCore" "$VERSION" "foundation module required by all other modules"
    fi

    # End timing
    if command -v metrics::end &>/dev/null; then
        metrics::end "pod_MSPiOSCore"
        metrics::record "cocoapods_success_count" 1 "count"
    fi

    log_success "MSPiOSCore released successfully"
    return 0
}

# ============================================================================
# Release MSPSharedLibraries (Step 1)
# ============================================================================
release_msp_shared_libraries() {
    log_section "Step 1: Releasing MSPSharedLibraries (foundation dependency)"

    # Ensure zip file exists for binary distribution pods (Resume-safe)
    # This provides script-level guarantee that podspec generation will succeed
    # even if previous release was incomplete (zip missing but pod published)
    if is_binary_distribution "MSPSharedLibraries"; then
        log_info "Verifying zip file exists for binary distribution pod..."

        if ! ensure_zip_file_exists_for_pod "MSPSharedLibraries" "$VERSION"; then
            log_error "Failed to ensure zip file exists for MSPSharedLibraries"

            if [[ "${MSP_RELEASE_TIER:-}" == "release" ]]; then
                log_error "[FAIL-FAST] Cannot proceed without zip file. Aborting."
                exit 1
            fi

            return 1
        fi

        log_success "Zip file verified/recreated for MSPSharedLibraries"
    fi

    # Update podspec (now guaranteed to succeed if binary distribution)
    if ! update_podspec_for_release "MSPSharedLibraries" "$VERSION"; then
        # FAIL-FAST: Immediately abort if podspec generation fails (release tier only)
        if [[ "${MSP_RELEASE_TIER:-}" == "release" ]]; then
            log_error "[FAIL-FAST] Podspec generation failed for MSPSharedLibraries. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Podspec generation failed for MSPSharedLibraries" "1"
            exit 1
        fi
        return 1
    fi

    # FAIL-FAST: Verify generated podspec exists (release tier only)
    local podspec_path="$ROOT_DIR/Build/ReleasePodspecs/MSPSharedLibraries.podspec"
    if [[ "${MSP_RELEASE_TIER:-}" == "release" ]] && [[ ! -f "$podspec_path" ]]; then
        log_error "[FAIL-FAST] Generated podspec not found: $podspec_path. Aborting release."
        msp_state_mark_step_failed "pods_publish" "Generated podspec not found: $podspec_path" "1"
        exit 1
    fi

    # Create GitHub release
    create_github_release_for_pod "MSPSharedLibraries" "$VERSION"

    # Publish to CocoaPods
    # Phase R1.11: Fail-fast if publication fails (prevent wait loop)
    if ! publish_pod_to_cocoapods "MSPSharedLibraries" "$VERSION"; then
        if [[ "${MSP_RELEASE_TIER:-}" == "release" ]]; then
            log_error "[FAIL-FAST] Failed to publish MSPSharedLibraries to CocoaPods. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Failed to publish MSPSharedLibraries" "1"
            exit 1
        fi
        return 1
    fi

    # Wait for availability (skip in dry-run mode)
    if [[ "$DRY_RUN" != "true" ]]; then
        smart_wait_for_pod_availability "MSPSharedLibraries" "$VERSION" "foundation dependency required by adapters and MSPCore"
    fi

    # End timing
    if command -v metrics::end &>/dev/null; then
        metrics::end "pod_MSPSharedLibraries"
        metrics::record "cocoapods_success_count" 1 "count"
    fi

    log_success "MSPSharedLibraries released successfully"
}

# ============================================================================
# Release MSPGoogleAdsTypes (Step 1.5)
# ============================================================================
release_msp_googleadstypes() {
    log_section "Step 1.5: Releasing MSPGoogleAdsTypes (required by MSPGoogleAdapter and AmazonAdapter)"

    # Start timing
    if command -v metrics::start &>/dev/null; then
        metrics::start "pod_MSPGoogleAdsTypes"
    fi

    # Check if MSPGoogleAdsTypes is already published (idempotency)
    if [[ "$DRY_RUN" != "true" ]]; then
        if check_pod_availability "MSPGoogleAdsTypes" "$VERSION"; then
            log_info "MSPGoogleAdsTypes $VERSION is already published to CocoaPods, skipping release"
            log_success "MSPGoogleAdsTypes $VERSION already available"
            if command -v metrics::end &>/dev/null; then
                metrics::end "pod_MSPGoogleAdsTypes"
            fi
            return 0
        fi
    fi

    # Ensure zip file exists for binary distribution pods (Resume-safe)
    # This provides script-level guarantee that podspec generation will succeed
    # even if previous release was incomplete (zip missing but pod published)
    if is_binary_distribution "MSPGoogleAdsTypes"; then
        log_info "Verifying zip file exists for binary distribution pod..."

        if ! ensure_zip_file_exists_for_pod "MSPGoogleAdsTypes" "$VERSION"; then
            log_error "Failed to ensure zip file exists for MSPGoogleAdsTypes"

            if [[ "${MSP_RELEASE_TIER:-}" == "release" ]]; then
                log_error "[FAIL-FAST] Cannot proceed without zip file. Aborting."
                exit 1
            fi

            return 1
        fi

        log_success "Zip file verified/recreated for MSPGoogleAdsTypes"
    fi

    # Update podspec (now guaranteed to succeed if binary distribution)
    if ! update_podspec_for_release "MSPGoogleAdsTypes" "$VERSION"; then
        # FAIL-FAST: Immediately abort if podspec generation fails (release tier only)
        if [[ "${MSP_RELEASE_TIER:-}" == "release" ]]; then
            log_error "[FAIL-FAST] Podspec generation failed for MSPGoogleAdsTypes. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Podspec generation failed for MSPGoogleAdsTypes" "1"
            exit 1
        fi
        return 1
    fi

    # FAIL-FAST: Verify generated podspec exists (release tier only)
    local podspec_path="$ROOT_DIR/Build/ReleasePodspecs/MSPGoogleAdsTypes.podspec"
    if [[ "${MSP_RELEASE_TIER:-}" == "release" ]] && [[ ! -f "$podspec_path" ]]; then
        log_error "[FAIL-FAST] Generated podspec not found: $podspec_path. Aborting release."
        msp_state_mark_step_failed "pods_publish" "Generated podspec not found: $podspec_path" "1"
        exit 1
    fi

    # Create GitHub release
    create_github_release_for_pod "MSPGoogleAdsTypes" "$VERSION"

    # Publish to CocoaPods
    # Phase R1.11: Fail-fast if publication fails (prevent wait loop)
    if ! publish_pod_to_cocoapods "MSPGoogleAdsTypes" "$VERSION"; then
        if [[ "${MSP_RELEASE_TIER:-}" == "release" ]]; then
            log_error "[FAIL-FAST] Failed to publish MSPGoogleAdsTypes to CocoaPods. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Failed to publish MSPGoogleAdsTypes" "1"
            exit 1
        fi
        return 1
    fi

    # Wait for availability (skip in dry-run mode)
    if [[ "$DRY_RUN" != "true" ]]; then
        smart_wait_for_pod_availability "MSPGoogleAdsTypes" "$VERSION" "required by MSPGoogleAdapter and AmazonAdapter"
    fi

    # End timing
    if command -v metrics::end &>/dev/null; then
        metrics::end "pod_MSPGoogleAdsTypes"
        metrics::record "cocoapods_success_count" 1 "count"
    fi

    log_success "MSPGoogleAdsTypes released successfully"
}

# Release single adapter (helper function for parallel processing)
release_single_adapter() {
    local adapter="$1"
    local version="$2"
    local result_file="$3"

    # Ensure ROOT_DIR is set in subprocess (parallel execution)
    if [[ -z "${ROOT_DIR:-}" ]]; then
        if command -v git >/dev/null 2>&1; then
            ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
        fi
        if [[ -z "${ROOT_DIR:-}" ]]; then
            ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
        fi
        export ROOT_DIR
    fi

    log_section "Releasing $adapter"

    # Ensure zip file exists for binary distribution pods (Resume-safe)
    # This provides script-level guarantee that podspec generation will succeed
    # even if previous release was incomplete (zip missing but pod published)
    if is_binary_distribution "$adapter"; then
        log_info "Verifying zip file exists for binary distribution pod..."

        if ! ensure_zip_file_exists_for_pod "$adapter" "$version"; then
            log_error "Failed to ensure zip file exists for $adapter"
            echo "ERROR: Failed to ensure zip file exists for $adapter" > "$result_file"

            if [[ "${MSP_RELEASE_TIER:-}" == "release" ]]; then
                log_error "[FAIL-FAST] Cannot proceed without zip file. Aborting."
                exit 1
            fi

            return 1
        fi

        log_success "Zip file verified/recreated for $adapter"
    fi

    # Update podspec (now guaranteed to succeed if binary distribution)
    if ! update_podspec_for_release "$adapter" "$version"; then
        echo "ERROR: Failed to update podspec for $adapter" > "$result_file"
        # FAIL-FAST: Immediately abort if podspec generation fails (release tier only)
        if [[ "${MSP_RELEASE_TIER:-}" == "release" ]]; then
            log_error "[FAIL-FAST] Podspec generation failed for $adapter. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Podspec generation failed for $adapter" "1"
            exit 1
        fi
        return 1
    fi

    # ========================================================================
    # DEBUG & CRITICAL FIX: Ensure ROOT_DIR before podspec verification
    # ========================================================================
    log_info "[DEBUG] Before podspec verification for $adapter"
    log_info "[DEBUG] ROOT_DIR current value: '${ROOT_DIR:-<EMPTY>}'"

    # CRITICAL: Re-ensure ROOT_DIR is set (defensive programming)
    if [[ -z "${ROOT_DIR:-}" ]]; then
        log_error "[CRITICAL] ROOT_DIR is EMPTY before podspec verification!"
        log_error "[CRITICAL] This should not happen - attempting emergency resolution..."

        # Try git method
        if command -v git >/dev/null 2>&1; then
            ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
            if [[ -n "$ROOT_DIR" ]]; then
                log_info "[CRITICAL] ROOT_DIR resolved via git: $ROOT_DIR"
                export ROOT_DIR
            fi
        fi

        # Fallback
        if [[ -z "${ROOT_DIR:-}" ]]; then
            ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
            log_info "[CRITICAL] ROOT_DIR resolved via fallback: $ROOT_DIR"
            export ROOT_DIR
        fi
    else
        log_info "[DEBUG] ROOT_DIR is set: $ROOT_DIR"
    fi
    # ========================================================================

    # FAIL-FAST: Verify generated podspec exists (release tier only)
    local podspec_path="$ROOT_DIR/Build/ReleasePodspecs/${adapter}.podspec"

    log_info "[DEBUG] Constructed podspec_path: $podspec_path"
    log_info "[DEBUG] Checking if file exists: [[ -f \"$podspec_path\" ]]"

    if [[ "${MSP_RELEASE_TIER:-}" == "release" ]] && [[ ! -f "$podspec_path" ]]; then
        log_error "[DEBUG] File check FAILED"
        log_error "[DEBUG] ROOT_DIR: '${ROOT_DIR}'"
        log_error "[DEBUG] adapter: '$adapter'"
        log_error "[DEBUG] podspec_path: '$podspec_path'"
        log_error "[DEBUG] Listing Build/ReleasePodspecs/:"
        if [[ -d "$ROOT_DIR/Build/ReleasePodspecs/" ]]; then
            ls -la "$ROOT_DIR/Build/ReleasePodspecs/" 2>/dev/null || log_error "[DEBUG] Failed to list"
        else
            log_error "[DEBUG] Directory does not exist: $ROOT_DIR/Build/ReleasePodspecs/"
        fi

        echo "ERROR: Generated podspec not found: $podspec_path" > "$result_file"
        log_error "[FAIL-FAST] Generated podspec not found: $podspec_path. Aborting release."
        msp_state_mark_step_failed "pods_publish" "Generated podspec not found: $podspec_path" "1"
        exit 1
    fi

    log_info "[DEBUG] ✅ Podspec file exists: $podspec_path"
    
    # Update dependencies
    log_info "[DEBUG] About to call update_adapter_podspec_dependencies for $adapter"
    log_info "[DEBUG] ROOT_DIR before call: '${ROOT_DIR:-<EMPTY>}'"

    if ! update_adapter_podspec_dependencies "$adapter" "$version"; then
        echo "ERROR: Failed to update dependencies for $adapter" > "$result_file"
        log_error "[DEBUG] update_adapter_podspec_dependencies failed for $adapter"
        return 1
    fi

    log_info "[DEBUG] update_adapter_podspec_dependencies succeeded for $adapter"
    
    # Update SDK version in adapter code
    if ! update_adapter_sdk_version "$adapter" "$version"; then
        echo "ERROR: Failed to update SDK version for $adapter" > "$result_file"
        return 1
    fi
    
    # Adapters use source-based distribution (git+tag), no GitHub release needed
    log_info "$adapter: Skipping GitHub release (source-based distribution via git+tag)"
    
    # Publish to CocoaPods
    if ! publish_pod_to_cocoapods "$adapter" "$version"; then
        echo "ERROR: Failed to publish $adapter to CocoaPods" > "$result_file"
        return 1
    fi
    
    # Note: Availability checking is done after ALL adapters are released
    echo "SUCCESS: $adapter released successfully" > "$result_file"
    return 0
}

# Release Adapters (Step 2) - Parallel Processing
release_adapters() {
    log_section "Step 2: Releasing Adapters that depend on MSPSharedLibraries (in parallel)"
    
    # Ensure MSPSharedLibraries is available before adapter releases
    log_step "Verifying MSPSharedLibraries availability before adapter releases..."
    if ! smart_wait_for_pod_availability "MSPSharedLibraries" "$VERSION" "before parallel adapter releases"; then
        log_error "MSPSharedLibraries $VERSION not available, cannot proceed with adapter releases"
        return 1
    fi

    # CRITICAL: Also ensure MSPiOSCore is available (adapters depend on it)
    log_step "Verifying MSPiOSCore availability before adapter releases..."
    if ! smart_wait_for_pod_availability "MSPiOSCore" "$VERSION" "required by all adapters"; then
        log_error "MSPiOSCore $VERSION not available, cannot proceed with adapter releases"
        log_error "All adapters depend on MSPiOSCore. Please wait for CDN sync and retry."
        return 1
    fi

    log_success "Both MSPSharedLibraries and MSPiOSCore are available, proceeding with parallel adapter releases"
    
    # Extract adapters from PODS_MODULES (exclude MSPSharedLibraries, MSPGoogleAdsTypes, and MSPCore)
    # Adapters are all modules that are not core modules
    # Note: NovaCore is not included - it's embedded via vendored_frameworks, not published separately
    # Stage B: MSPOMSDK removed - OMSDK now embedded in NovaCore
    local core_modules=("MSPSharedLibraries" "MSPGoogleAdsTypes" "MSPCore" "MSPiOSCore")
    local adapters=()
    
    # Split PODS_MODULES space-separated string and filter out core modules
    for module in $PODS_MODULES; do
        local is_core=false
        for core in "${core_modules[@]}"; do
            if [[ "$module" == "$core" ]]; then
                is_core=true
                break
            fi
        done
        if [[ "$is_core" == "false" ]]; then
            adapters+=("$module")
        fi
    done
    
    if [[ ${#adapters[@]} -eq 0 ]]; then
        log_warn "No adapters found in PODS_MODULES. Using default adapter list for backward compatibility."
        adapters=("MSPFacebookAdapter" "MSPGoogleAdapter" "NovaAdapter" "AmazonAdapter" "MSPPrebidAdapter")
    fi
    
    log_info "Releasing adapters from PODS_MODULES: ${adapters[*]}"
    
    local pids=()
    local result_files=()
    local temp_dir="/tmp/msp_parallel_release_$$"
    
    # Create temporary directory for result files
    mkdir -p "$temp_dir"
    
    # Start all adapter releases in parallel
    for adapter in "${adapters[@]}"; do
        local result_file="$temp_dir/${adapter}_result.txt"
        result_files+=("$result_file")
        
        # Start adapter release in background
        release_single_adapter "$adapter" "$VERSION" "$result_file" &
        local pid=$!
        pids+=("$pid")
        
        log_info "Started parallel release of $adapter (PID: $pid)"
    done
    
    # Wait for all parallel processes to complete
    log_info "Waiting for all adapters to complete..."
    local success_count=0
    local failure_count=0
    local failed_adapters=()
    
    for i in "${!pids[@]}"; do
        local pid="${pids[$i]}"
        local adapter="${adapters[$i]}"
        local result_file="${result_files[$i]}"
        
        # Wait for this specific process
        if wait "$pid"; then
            # Process completed successfully
            if [[ -f "$result_file" ]] && grep -q "SUCCESS" "$result_file"; then
                log_success "$adapter released successfully"
                ((success_count++))
            else
                log_error "$adapter release failed"
                ((failure_count++))
                failed_adapters+=("$adapter")
            fi
        else
            # Process failed
            log_error "$adapter release failed (exit code: $?)"
            ((failure_count++))
            failed_adapters+=("$adapter")
        fi
        
        # Show result details
        if [[ -f "$result_file" ]]; then
            local result_content
            result_content=$(cat "$result_file")
            if [[ "$result_content" == *"ERROR"* ]]; then
                log_error "$adapter: $result_content"
            else
                log_info "$adapter: $result_content"
            fi
        fi
    done
    
    # Clean up temporary files
    rm -rf "$temp_dir"
    
    # Report final results
    log_section "Parallel adapter release completed:"
    log_info "  ✅ Successful: $success_count"
    log_info "  ❌ Failed: $failure_count"
    
    if [[ $failure_count -gt 0 ]]; then
        log_error "Failed adapters: ${failed_adapters[*]}"
        return 1
    fi
    
    log_success "All adapters released successfully in parallel"
    
    # Step 2.5: Check availability of MSPSharedLibraries and PrebidAdapter before MSPCore release
    if [[ "$DRY_RUN" != "true" ]]; then
        log_section "Step 2.5: Checking availability of dependencies for MSPCore"
        
        # Update specs repository once
        log_info "Updating CocoaPods specs repository..."
        if ! update_specs_repo; then
            log_error "Failed to update specs repository"
            return 1
        fi
        
        # Check MSPSharedLibraries availability
        log_info "Checking MSPSharedLibraries availability..."
        if ! smart_wait_for_pod_availability "MSPSharedLibraries" "$VERSION" "before parallel adapter releases"; then
            log_error "MSPSharedLibraries not available, cannot proceed with MSPCore release"
            return 1
        fi
        
        # Check MSPPrebidAdapter availability (MSPCore depends on it)
        # Only check if MSPPrebidAdapter is in PODS_MODULES
        if echo "$PODS_MODULES" | grep -q "MSPPrebidAdapter"; then
            log_info "Checking MSPPrebidAdapter availability..."
            if ! smart_wait_for_pod_availability "MSPPrebidAdapter" "$VERSION" "required by MSPCore"; then
                log_error "MSPPrebidAdapter not available, cannot proceed with MSPCore release"
                return 1
            fi
        else
            log_info "MSPPrebidAdapter not in PODS_MODULES, skipping availability check"
        fi
        
        log_success "All dependencies available for MSPCore release"
    fi
    
    return 0
}

# Release MSPCore (Step 3)
release_msp_core() {
    log_section "Step 3: Releasing MSPCore (main framework)"

    # Ensure zip file exists for binary distribution pods (Resume-safe)
    # This provides script-level guarantee that podspec generation will succeed
    # even if previous release was incomplete (zip missing but pod published)
    if is_binary_distribution "MSPCore"; then
        log_info "Verifying zip file exists for binary distribution pod..."

        if ! ensure_zip_file_exists_for_pod "MSPCore" "$VERSION"; then
            log_error "Failed to ensure zip file exists for MSPCore"

            if [[ "${MSP_RELEASE_TIER:-}" == "release" ]]; then
                log_error "[FAIL-FAST] Cannot proceed without zip file. Aborting."
                exit 1
            fi

            return 1
        fi

        log_success "Zip file verified/recreated for MSPCore"
    fi

    # Update podspec (now guaranteed to succeed if binary distribution)
    if ! update_podspec_for_release "MSPCore" "$VERSION"; then
        # FAIL-FAST: Immediately abort if podspec generation fails (release tier only)
        if [[ "${MSP_RELEASE_TIER:-}" == "release" ]]; then
            log_error "[FAIL-FAST] Podspec generation failed for MSPCore. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Podspec generation failed for MSPCore" "1"
            exit 1
        fi
        return 1
    fi

    # FAIL-FAST: Verify generated podspec exists (release tier only)
    local podspec_path="$ROOT_DIR/Build/ReleasePodspecs/MSPCore.podspec"
    if [[ "${MSP_RELEASE_TIER:-}" == "release" ]] && [[ ! -f "$podspec_path" ]]; then
        log_error "[FAIL-FAST] Generated podspec not found: $podspec_path. Aborting release."
        msp_state_mark_step_failed "pods_publish" "Generated podspec not found: $podspec_path" "1"
        exit 1
    fi

    # Update dependencies
    update_adapter_podspec_dependencies "MSPCore" "$VERSION"
    
    # Update MSPCore version in Config.plist
    update_config_plist_version "$VERSION"
    
    # Create GitHub release
    create_github_release_for_pod "MSPCore" "$VERSION"
    
    # Publish to CocoaPods
    publish_pod_to_cocoapods "MSPCore" "$VERSION"
    
    # Wait for availability (skip in dry-run mode)
    if [[ "$DRY_RUN" != "true" ]]; then
        smart_wait_for_pod_availability "MSPCore" "$VERSION" "final integration module"
    fi
    
    log_success "MSPCore released successfully"
}

# Commit all changes to release branch
commit_release_changes() {
    log_step "Committing all release changes to release branch"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would commit all changes"
        return 0
    fi
    
    # Add all changes
    git add .
    
    # Check if there are changes to commit
    if git diff --cached --quiet; then
        log_info "No changes to commit"
        return 0
    fi
    
    # Commit changes
    git commit -m "Release version $VERSION - Update podspecs and version numbers"
    
    log_success "Committed all release changes"
}

# Main function
main() {
    # Initialize state for standalone pods flow
    msp_state_init "run"
    
    # Check if pods publish should be skipped
    if [[ "${PODS_ENABLED:-true}" == "false" ]] || [[ "${SKIP_PODS:-false}" == "true" ]]; then
        msp_state_mark_step_skipped "pods_publish" "pods publish skipped due to PODS_ENABLED=false or SKIP_PODS=true"
        log_info "Pods publish skipped"
        return 0
    fi
    
    # Backward compatibility: parse remaining CLI arguments if any
    # (Only used if script is called directly, not via msp-release.sh)
    if [[ $# -gt 0 ]]; then
        parse_arguments "$@"
    fi
    
    # Validate inputs
    validate_inputs
    
    # Ensure we're in the project root
    ensure_project_root
    
    # Check release branch
    check_release_branch
    
    # Record start time for duration calculation
    local start_time=$(date +%s)
    
    # Check if we should skip this step in resume mode
    if [[ "${MSP_RESUME_MODE:-0}" == "1" ]]; then
        local status
        status="$(msp_state_get_step_status "pods_publish" 2>/dev/null || echo "unknown")"
        if [[ "$status" == "success" || "$status" == "skipped" ]]; then
            log_info "Resuming: skipping pods_publish (status already ${status})"
            return 0
        fi
    fi
    
    # Mark pods_publish step as running
    msp_state_mark_step_running "pods_publish"
    
    print_section "Starting CocoaPods Release Process for Version: $VERSION"
    
    # Phase 4 TASK 1: CocoaPods release strong validation
    local release_mode="${MSP_RELEASE_MODE:-cli}"
    local release_tier="${MSP_RELEASE_TIER:-preflight}"
    local release_mode_upper=$(echo "$release_mode" | tr '[:lower:]' '[:upper:]' 2>/dev/null || echo "$release_mode" | awk '{print toupper($0)}')
    echo "[MSP][ORCH] Mode: ${release_mode_upper} — linting pods spec"
    
    # Check CocoaPods installation
    if ! command -v pod >/dev/null 2>&1; then
        log_error "CocoaPods is not installed. Please install it with: sudo gem install cocoapods"
        # Task 3: Preflight mode allows soft-fail
        if [[ "$release_tier" == "release" ]] || [[ "$release_tier" == "production" ]]; then
            log_error "[MSP][ORCH] Release tier ($release_tier): CocoaPods not installed - aborting"
            exit 1
        else
            log_warn "[MSP][ORCH] Preflight mode: CocoaPods not installed, skipping CocoaPods release"
            msp_state_mark_step_failed "pods_publish" "CocoaPods not installed" "1"
            return 0
        fi
    fi
    
    # Check trunk session status (stronger check)
    log_step "Checking CocoaPods trunk session"
    local trunk_check
    trunk_check=$(pod trunk me 2>&1 || echo "ERROR")
    if [[ "$trunk_check" =~ "No session" ]] || [[ "$trunk_check" =~ "authentication" ]] || [[ "$trunk_check" =~ "ERROR" ]]; then
        log_error "CocoaPods trunk session is not valid"
        log_error "Please run: pod trunk register <email> <name>"
        # Task 3: Preflight mode allows soft-fail
        if [[ "$release_tier" == "release" ]] || [[ "$release_tier" == "production" ]]; then
            log_error "[MSP][ORCH] Release tier ($release_tier): CocoaPods trunk session invalid - aborting"
            exit 1
        else
            log_warn "[MSP][ORCH] Preflight mode: CocoaPods trunk session invalid, skipping CocoaPods release"
            msp_state_mark_step_failed "pods_publish" "CocoaPods trunk session invalid" "1"
            return 0
        fi
    fi
    log_success "CocoaPods trunk session is valid"
    
    # Phase 4: Strong lint validation for production releases
    if [[ "$release_tier" == "release" ]] || [[ "$release_tier" == "production" ]]; then
        log_section "Phase 4: Release/Production - Strong Podspec Validation"
        
        # Validate all podspecs before publishing
        local lint_errors=0
        local lint_warnings=0
        
        for module in "${cocoapods_pods[@]}"; do
            local podspec="${module}.podspec"
            if [[ ! -f "$podspec" ]]; then
                log_error "Podspec file not found: $podspec"
                lint_errors=$((lint_errors + 1))
                continue
            fi
            
            log_step "Linting $podspec (production mode - strict)"
            
            # Run pod spec lint with strict mode
            local lint_output
            lint_output=$(pod spec lint "$podspec" --skip-tests --allow-warnings 2>&1 || echo "LINT_FAILED")
            
            if [[ "$lint_output" =~ "LINT_FAILED" ]] || [[ "$lint_output" =~ "error:" ]]; then
                log_error "Podspec lint FAILED for $podspec"
                echo "$lint_output" | grep -E "error:" | head -5
                lint_errors=$((lint_errors + 1))
                
                # Hard fail for release/production
                if [[ "$release_tier" == "release" ]] || [[ "$release_tier" == "production" ]]; then
                    log_error "[MSP][ORCH] Release tier ($release_tier): podspec lint errors are not allowed"
                    exit 1
                fi
            elif [[ "$lint_output" =~ "warning:" ]]; then
                log_warn "Podspec lint warnings for $podspec (non-blocking)"
                lint_warnings=$((lint_warnings + 1))
            else
                log_success "Podspec lint passed for $podspec"
            fi
        done
        
        # Record lint results in state
        if command -v msp_state_is_enabled &>/dev/null && msp_state_is_enabled; then
            local state_file="$ROOT_DIR/.msp-release-state.json"
            if [[ -f "$state_file" ]] && command -v jq >/dev/null 2>&1; then
                jq ".steps.pods.lint_errors = $lint_errors | .steps.pods.lint_warnings = $lint_warnings" \
                    "$state_file" > "${state_file}.tmp" 2>/dev/null && \
                    mv "${state_file}.tmp" "$state_file" 2>/dev/null || true
            fi
        fi
        
        if [[ $lint_errors -gt 0 ]]; then
            log_error "Podspec lint failed for $lint_errors podspec(s). Production release aborted."
            exit 1
        fi
        
        log_success "All podspecs passed lint validation ($lint_warnings warnings, non-blocking)"
    fi
    
    # Generate release notes
    local release_notes=""
    if [[ -n "$RELEASE_NOTES" ]]; then
        release_notes="$RELEASE_NOTES"
        log_info "Using provided release notes"
    else
        log_step "Generating release notes from source: $RELEASE_NOTES_SOURCE"
        release_notes=$(get_release_notes "$VERSION" "CocoaPods" "$RELEASE_NOTES_SOURCE" "$RELEASE_NOTES_TEMPLATE")
    fi
    
    # Create CocoaPods-specific pod list from PODS_MODULES
    # Convert space-separated PODS_MODULES to array
    local cocoapods_pods=()
    for module in $PODS_MODULES; do
        cocoapods_pods+=("$module")
    done
    
    if [[ ${#cocoapods_pods[@]} -eq 0 ]]; then
        log_warn "PODS_MODULES is empty. Using default pod list for backward compatibility."
        cocoapods_pods=("MSPSharedLibraries" "MSPFacebookAdapter" "MSPGoogleAdapter" "NovaAdapter" "AmazonAdapter" "MSPPrebidAdapter" "MSPCore")
    fi
    
    log_info "Releasing pods from PODS_MODULES: ${cocoapods_pods[*]}"

    # ============================================================================
    # CRITICAL: Ensure release tag exists and is pushed BEFORE creating releases
    # ============================================================================
    log_section "Pre-Release: Creating and pushing release tag"

    # Ensure the release tag exists locally and is pushed to remotes
    # This MUST happen before GitHub Release creation to avoid draft releases
    if ! ensure_release_tag_exists_and_pushed "$VERSION" "HEAD"; then
        log_error "Failed to create/push release tag: $VERSION"
        msp_state_mark_step_failed "pods_publish" "Failed to create release tag: $VERSION" "1"

        # FAIL-FAST in release tier
        if [[ "${MSP_RELEASE_TIER:-}" == "release" ]] || [[ "${MSP_RELEASE_TIER:-}" == "production" ]]; then
            log_error "[FAIL-FAST] Tag creation failed in release tier. Aborting."
            exit 1
        fi
        return 1
    fi

    log_success "Release tag $VERSION created and pushed to all remotes"

    # Wait for tag propagation (GitHub may need time to make tag available)
    log_info "Waiting 5 seconds for tag propagation..."
    sleep 5

    # Verify tag is accessible on public remote (skip in DRY_RUN mode)
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Skipping tag verification on public remote"
    elif [[ "${SKIP_PUBLIC_REMOTE_PUSH:-0}" == "1" ]]; then
        log_warning "SKIP_PUBLIC_REMOTE_PUSH=1: Skipping tag verification on public remote"
    elif git remote | grep -q "^public$"; then
        if ! git ls-remote --tags public "refs/tags/$VERSION" 2>/dev/null | grep -q "$VERSION"; then
            log_error "Tag $VERSION not found on public remote after push"
            log_error "GitHub Release creation will fail or create draft release"

            # FAIL-FAST in release tier (unless MSP_ALLOW_PUBLIC_PUSH_FAILURE is set)
            if [[ "${MSP_RELEASE_TIER:-}" == "release" ]] || [[ "${MSP_RELEASE_TIER:-}" == "production" ]]; then
                if [[ "${MSP_ALLOW_PUBLIC_PUSH_FAILURE:-0}" == "1" ]]; then
                    log_warning "MSP_ALLOW_PUBLIC_PUSH_FAILURE=1: Continuing despite tag verification failure"
                else
                    log_error "[FAIL-FAST] Tag not accessible on public remote. Aborting."
                    exit 1
                fi
            else
                return 1
            fi
        else
            log_success "Tag $VERSION verified on public remote"

            # CRITICAL: Verify tag points to correct commit
            local public_tag_sha
            public_tag_sha=$(git ls-remote --tags public "refs/tags/$VERSION" 2>/dev/null | awk '{print $1}')
            local local_tag_sha
            local_tag_sha=$(git rev-parse "refs/tags/$VERSION" 2>/dev/null)

            if [[ -n "$public_tag_sha" ]] && [[ -n "$local_tag_sha" ]] && [[ "$public_tag_sha" != "$local_tag_sha" ]]; then
                log_error "════════════════════════════════════════════════════════════"
                log_error "  ❌ Public Remote Tag SHA Mismatch!"
                log_error "════════════════════════════════════════════════════════════"
                log_error ""
                log_error "Tag: $VERSION"
                log_error "本地 Local:  $local_tag_sha"
                log_error "远程 Public: $public_tag_sha"
                log_error ""
                log_error "这意味着 public remote 上的 tag 指向错误的 commit！"
                log_error "CocoaPods 验证将会失败（source_files 找不到）"
                log_error ""
                log_error "解决方案:"
                log_error "  1. 强制更新 public remote tag:"
                log_error "     git push public :refs/tags/$VERSION"
                log_error "     git push public refs/tags/$VERSION"
                log_error ""
                log_error "  2. 或者运行修复命令:"
                log_error "     ./Scripts/msp-release.sh fix-public-tag $VERSION"
                log_error ""
                log_error "════════════════════════════════════════════════════════════"

                if [[ "${MSP_ALLOW_PUBLIC_PUSH_FAILURE:-0}" == "1" ]]; then
                    log_warning "⚠️  MSP_ALLOW_PUBLIC_PUSH_FAILURE=1: 继续执行但可能失败"
                else
                    log_error "🛑 停止执行"
                    exit 1
                fi
            elif [[ -n "$public_tag_sha" ]] && [[ -n "$local_tag_sha" ]] && [[ "$public_tag_sha" == "$local_tag_sha" ]]; then
                log_success "✅ Tag SHA verified: local and public match"
            fi
        fi
    else
        log_warning "Public remote not found, skipping tag verification"
    fi
    # ============================================================================
    
    # Skip individual start notifications - only send final success/failure
    
    # Track release statistics
    local total_pods=${#cocoapods_pods[@]}
    local successful_pods=0
    local failed_pods=0
    local failed_pod_names=()

    # Step 0: Release MSPiOSCore (foundation - required by all modules)
    if release_msp_ioscore; then
        ((successful_pods++))
    else
        ((failed_pods++))
        failed_pod_names+=("MSPiOSCore")
        if [[ "$DRY_RUN" != "true" ]]; then
            # Use new notification system: DM only (no channel spam)
            if command -v notify::module_error &>/dev/null; then
                notify::module_error "MSPiOSCore" "$VERSION" "Foundation release failed: MSPiOSCore publication to CocoaPods Trunk failed"
            else
                log_warning "New notification system not available, skipping failure notification"
            fi
        fi
        msp_state_mark_step_failed "pods_publish" "MSPiOSCore release failed" "1"

        # MSPiOSCore is foundation module - all other modules depend on it
        log_error "[MSP][ORCH] MSPiOSCore release failed (foundation module)"
        log_error "[MSP][ORCH] All other modules depend on MSPiOSCore. Stopping CocoaPods release."

        # Release tier: hard-fail (exit entire release)
        if [[ "$release_tier" == "release" ]] || [[ "$release_tier" == "production" ]]; then
            log_error "[MSP][ORCH] Release tier: aborting entire release"
            exit 1
        else
            # Test/preflight tier: stop CocoaPods release but continue with other steps (SPM, verification)
            log_warn "[MSP][ORCH] $release_tier tier: stopping CocoaPods release, will continue with other steps"
            # Return early to avoid publishing other pods (they will fail anyway)
            return 1
        fi
    fi
    
    # Step 1: Release MSPSharedLibraries
    if release_msp_shared_libraries; then
        ((successful_pods++))
    else
        ((failed_pods++))
        failed_pod_names+=("MSPSharedLibraries")
        if [[ "$DRY_RUN" != "true" ]]; then
            # Use new notification system: DM only (no channel spam)
            if command -v notify::module_error &>/dev/null; then
                notify::module_error "MSPSharedLibraries" "$VERSION" "Foundation release failed: MSPSharedLibraries publication to CocoaPods Trunk failed"
            else
                log_warning "New notification system not available, skipping failure notification"
            fi
        fi
        msp_state_mark_step_failed "pods_publish" "MSPSharedLibraries release failed" "1"
        # Task 3: Preflight mode allows soft-fail, release/production requires hard-fail
        if [[ "$release_tier" == "release" ]] || [[ "$release_tier" == "production" ]]; then
            log_error "[MSP][ORCH] Release tier ($release_tier): MSPSharedLibraries release failure - aborting"
            exit 1
        else
            log_warn "[MSP][ORCH] Preflight mode: CocoaPods release failed, continuing with other steps"
        fi
    fi
    
    # Step 1.5: Release MSPGoogleAdsTypes (required by MSPGoogleAdapter and AmazonAdapter)
    if release_msp_googleadstypes; then
        ((successful_pods++))
    else
        ((failed_pods++))
        failed_pod_names+=("MSPGoogleAdsTypes")
        if [[ "$DRY_RUN" != "true" ]]; then
            # Use new notification system: DM only (no channel spam)
            if command -v notify::module_error &>/dev/null; then
                notify::module_error "MSPGoogleAdsTypes" "$VERSION" "Foundation release failed: MSPGoogleAdsTypes publication to CocoaPods Trunk failed"
            else
                log_warning "New notification system not available, skipping failure notification"
            fi
        fi
        msp_state_mark_step_failed "pods_publish" "MSPGoogleAdsTypes release failed" "1"
        # Task 3: Preflight mode allows soft-fail, release/production requires hard-fail
        if [[ "$release_tier" == "release" ]] || [[ "$release_tier" == "production" ]]; then
            log_error "[MSP][ORCH] Release tier ($release_tier): MSPGoogleAdsTypes release failure - aborting"
            log_error "[MSP][ORCH] MSPGoogleAdapter and AmazonAdapter depend on MSPGoogleAdsTypes. Cannot proceed."
            exit 1
        else
            log_warn "[MSP][ORCH] Preflight mode: CocoaPods release failed, continuing with other steps"
        fi
    fi
    
    # Step 2: Release Adapters
    if release_adapters; then
        # Count successful adapters (assuming all adapters in POD_RELEASE_ORDER except MSPSharedLibraries and MSPCore)
        local adapter_count=$((${#POD_RELEASE_ORDER[@]} - 2))  # Subtract MSPSharedLibraries and MSPCore
        successful_pods=$((successful_pods + adapter_count))
    else
        # Count failed adapters
        local adapter_count=$((${#POD_RELEASE_ORDER[@]} - 2))
        failed_pods=$((failed_pods + adapter_count))
        failed_pod_names+=("Adapters")
        if [[ "$DRY_RUN" != "true" ]]; then
            # Use new notification system: DM only (no channel spam)
            if command -v notify::module_error &>/dev/null; then
                notify::module_error "Adapters" "$VERSION" "Adapters release failed: One or more adapters failed to publish to CocoaPods Trunk"
            else
                log_warning "New notification system not available, skipping failure notification"
            fi
        fi
        msp_state_mark_step_failed "pods_publish" "Adapter release failed" "1"
        # Task 3: Preflight mode allows soft-fail, release/production requires hard-fail
        if [[ "$release_tier" == "release" ]] || [[ "$release_tier" == "production" ]]; then
            log_error "[MSP][ORCH] Release tier ($release_tier): Adapters release failure - aborting"
            log_error "[MSP][ORCH] Cannot proceed to MSPCore (depends on MSPPrebidAdapter)"
            exit 1
        else
            log_warn "[MSP][ORCH] Preflight mode: CocoaPods release failed, continuing with other steps"
        fi
    fi
    
    # Step 3: Release MSPCore
    if release_msp_core; then
        ((successful_pods++))
    else
        ((failed_pods++))
        failed_pod_names+=("MSPCore")
        if [[ "$DRY_RUN" != "true" ]]; then
            # Use new notification system: DM only (no channel spam)
            if command -v notify::module_error &>/dev/null; then
                notify::module_error "MSPCore" "$VERSION" "Main framework release failed: MSPCore publication to CocoaPods Trunk failed"
            else
                log_warning "New notification system not available, skipping failure notification"
            fi
        fi
        msp_state_mark_step_failed "pods_publish" "MSPCore release failed" "1"
        # Task 3: Preflight mode allows soft-fail, release/production requires hard-fail
        if [[ "$release_tier" == "release" ]] || [[ "$release_tier" == "production" ]]; then
            log_error "[MSP][ORCH] Release tier ($release_tier): MSPCore release failure - aborting"
            exit 1
        else
            log_warn "[MSP][ORCH] Preflight mode: CocoaPods release failed, continuing with other steps"
        fi
    fi
    
    # Commit all changes
    commit_release_changes
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local duration_formatted=$(printf "%02d:%02d:%02d" $((duration/3600)) $((duration%3600/60)) $((duration%60)))
    
    print_section "CocoaPods Release Process Completed Successfully"
    log_success "All pods released successfully for version: $VERSION"
    log_info "Release branch '$RELEASE_BRANCH' is ready to be pushed"
    
    # Send single comprehensive success notification (skip in dry-run mode)
    if [[ "$DRY_RUN" != "true" ]]; then
        local pods_list=$(IFS=", "; echo "${cocoapods_pods[*]}")
        notify_release_success_with_summary "CocoaPods" "$VERSION" "$pods_list" "$duration_formatted" "$release_notes" "$total_pods" "$successful_pods" "$failed_pods" "$RELEASE_BRANCH"
    fi
    
    # Mark pods_publish step as successful
    msp_state_mark_step_success "pods_publish"
}

# Entry point
# If RELEASE_VERSION is set from environment (via msp-release.sh), use it directly
# Otherwise, require CLI arguments for backward compatibility
if [[ -z "${RELEASE_VERSION:-}" && $# -eq 0 ]]; then
    show_help
    exit 1
fi

# Run main function with all arguments
main "$@"
