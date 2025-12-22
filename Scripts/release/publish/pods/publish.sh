#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

# Modular CocoaPods Release Script
# Follows the exact release workflow: MSPSharedLibraries → Adapters → MSPCore
#
# Phase 2 Step 4: Config-driven release
# This script now uses environment variables from msp-release.sh instead of CLI arguments.

# Ensure UTF-8 encoding for CocoaPods
export LANG=en_US.UTF-8

set -e

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
# Release order: MSPiOSCore → MSPSharedLibraries → Adapters → MSPCore
DEFAULT_PODS_MODULES="MSPiOSCore MSPSharedLibraries MSPPrebidAdapter MSPCore MSPGoogleAdapter MSPFacebookAdapter NovaAdapter AmazonAdapter"
PODS_MODULES="${PODS_MODULES:-$DEFAULT_PODS_MODULES}"

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
    
    # Skip MSPGoogleAdapter and MSPFacebookAdapter as they read SDK version from external sources
    if [[ "$adapter" == "MSPGoogleAdapter" || "$adapter" == "MSPFacebookAdapter" ]]; then
        log_info "Skipping getSDKVersion() update for $adapter (reads from external sources)"
        return 0
    fi
    
    log_step "Updating getSDKVersion() in $adapter"
    
    # Find Swift files in the adapter directory
    local adapter_dir="${adapter}/${adapter}"
    if [[ -d "$adapter_dir" ]]; then
        find "$adapter_dir" -name "*.swift" -exec grep -l "getSDKVersion" {} \; | while read -r file; do
            # Update getSDKVersion function to return the new version
            sed -i '' "s|return \".*\"|return \"${version}\"|g" "$file"
            log_info "Updated getSDKVersion in $file"
        done
    else
        log_warning "Adapter directory not found: $adapter_dir"
    fi
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
    
    # Update MSPOMSDK dependency (keep without version constraint) - handle both with and without version
    if grep -q "spec\.dependency.*MSPOMSDK" "$podspec"; then
        # Remove any existing version(s) and comments, keep it without version constraint
        sed -i '' "s|spec\.dependency 'MSPOMSDK'[^#]*|spec.dependency 'MSPOMSDK'|g" "$podspec"
        log_info "Updated MSPOMSDK dependency to remove version constraint"
    fi
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
        if ! git tag "$tag" "$target_commit_sha"; then
            log_error "Failed to create local tag: $tag"
            return 1
        fi
        log_success "Created local tag: $tag at commit $target_commit_sha"
    fi

    # Push tag to origin if it doesn't exist or was deleted
    if [[ "$tag_exists_on_origin" == "false" ]]; then
        log_info "Pushing tag to origin: $tag"
        if ! git push origin "refs/tags/$tag"; then
            log_error "Failed to push tag to origin: $tag"
            return 1
        fi
        log_success "Pushed tag to origin: $tag"
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
        if ! git push public "refs/tags/$tag"; then
            log_error "Failed to push tag to public: $tag"
            # If MSP_ALLOW_PUBLIC_PUSH_FAILURE is set, continue anyway
            if [[ "${MSP_ALLOW_PUBLIC_PUSH_FAILURE:-0}" == "1" ]]; then
                log_warning "MSP_ALLOW_PUBLIC_PUSH_FAILURE=1: Continuing despite tag push failure"
            else
                return 1
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

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would create GitHub release for $pod version $version"
        return 0
    fi

    # Stage A: In release tier, create GitHub release and upload binary zip
    # HTTP binary distribution requires zip to be available before pod trunk push
    if [[ "${MSP_RELEASE_TIER:-}" == "release" ]]; then
        log_info "Release tier: Creating GitHub release and uploading binary zip (HTTP distribution)"
        
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
        
        # Stage A: Calculate SHA256 checksum for podspec
        local zip_checksum
        if command -v shasum >/dev/null 2>&1; then
            zip_checksum=$(shasum -a 256 "$ROOT_DIR/$zip_name" 2>/dev/null | cut -d' ' -f1)
            log_info "Calculated SHA256 checksum: $zip_checksum"
        else
            log_error "shasum command not available, cannot calculate checksum"
            rm -f "$ROOT_DIR/$zip_name"
            return 1
        fi
        
        # Stage A: Update podspec with checksum (podspec already generated, add checksum to HTTP source)
        local podspec="$ROOT_DIR/Build/ReleasePodspecs/${pod}.podspec"
        if [[ -f "$podspec" ]]; then
            log_step "Updating podspec with SHA256 checksum"
            # Use Ruby to properly insert checksum into source hash (more robust than sed)
            local zip_url="https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/${pod}-${version}.zip"
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
            log_success "Updated podspec with checksum: $zip_checksum"
        else
            log_warning "Podspec not found for checksum update: $podspec"
        fi
        
        # Create or update GitHub release
        local gh_release_created=false
        if gh release view "$version" --repo "ParticleMedia/msp-ios-sdk-public" &>/dev/null; then
            log_info "Release $version already exists, uploading assets"
            if gh release upload "$version" "$ROOT_DIR/$zip_name" --repo "ParticleMedia/msp-ios-sdk-public" --clobber; then
                gh_release_created=true
            fi
        else
            log_info "Creating new release $version"
            if gh release create "$version" "$ROOT_DIR/$zip_name" --repo "ParticleMedia/msp-ios-sdk-public" --title "Release $version" --notes "Release $version"; then
                gh_release_created=true
            fi
        fi
        
        # Clean up zip file
        rm -f "$ROOT_DIR/$zip_name"
        
        if [[ "$gh_release_created" == "true" ]]; then
            log_success "GitHub release created and zip uploaded for $pod"
            
            # Track GitHub release creation in state
            if command -v msp_state_mark_git_flag &>/dev/null; then
                msp_state_mark_git_flag "github_release_created" true
                if command -v msp_state_set_tag_name &>/dev/null; then
                    msp_state_set_tag_name "$version"
                fi
            fi
        else
            log_error "Failed to create/update GitHub release for $pod"
            return 1
        fi

        return 0
    fi

    # Create zip file
    local zip_name="${pod}-${version}.zip"
    if [[ -d "$pod" ]]; then
        zip -r "$zip_name" "$pod" >/dev/null 2>&1
        log_info "Created zip file: $zip_name"
    else
        log_error "Pod directory not found: $pod"
        return 1
    fi
    
    # Create or update GitHub release
    local gh_release_created=false
    if gh release view "$version" --repo "ParticleMedia/msp-ios-sdk-public" &>/dev/null; then
        log_info "Release $version already exists, uploading assets"
        if gh release upload "$version" "$zip_name" --repo "ParticleMedia/msp-ios-sdk-public" --clobber; then
            gh_release_created=true
        fi
    else
        log_info "Creating new release $version"
        if gh release create "$version" "$zip_name" --repo "ParticleMedia/msp-ios-sdk-public" --title "Release $version" --notes "Release $version"; then
            gh_release_created=true
        fi
    fi
    
    # Clean up zip file
    rm -f "$zip_name"
    
    if [[ "$gh_release_created" == "true" ]]; then
        log_success "GitHub release created for $pod"
        
        # Track GitHub release creation in state
        if command -v msp_state_mark_git_flag &>/dev/null; then
            msp_state_mark_git_flag "github_release_created" true
            if command -v msp_state_set_tag_name &>/dev/null; then
                # Ensure tag_name is set if not already set
                msp_state_set_tag_name "$version"
            fi
        fi
    else
        log_error "Failed to create/update GitHub release for $pod"
        return 1
    fi
}

# Stage A: Probe zip URL availability before publishing
probe_zip_url() {
    local pod="$1"
    local version="$2"
    local max_attempts=6
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

# Publish pod to CocoaPods
publish_pod_to_cocoapods() {
    local pod="$1"
    local version="$2"

    # Use generated podspec from Build/ReleasePodspecs/ (Phase R1.7: use absolute path)
    local podspec="$ROOT_DIR/Build/ReleasePodspecs/${pod}.podspec"

    log_step "Publishing $pod to CocoaPods using generated podspec"

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
        local core_modules=("MSPSharedLibraries" "MSPCore" "MSPiOSCore" "MSPOMSDK")
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
        # Phase R1.13-A: Skip podspec validation in release tier (binary distribution)
        if [[ "${MSP_RELEASE_TIER:-}" == "release" ]]; then
            log_info "Release tier: Skipping podspec validation (binary distribution)"
        else
            if ! validate_podspec_with_retry "$podspec"; then
                log_error "Podspec validation failed for $pod"
                return 1
            fi
        fi
    fi

    # Publish to CocoaPods
    if ! publish_podspec_with_retry "$podspec"; then
        log_error "Failed to publish $pod to CocoaPods"
        return 1
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

    # Check if MSPiOSCore is already published (idempotency)
    if [[ "$DRY_RUN" != "true" ]]; then
        if check_pod_availability "MSPiOSCore" "$VERSION"; then
            log_info "MSPiOSCore $VERSION is already published to CocoaPods, skipping release"
            log_success "MSPiOSCore $VERSION already available"
            return 0
        fi
    fi

    # Update podspec
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

    log_success "MSPiOSCore released successfully"
    return 0
}

# ============================================================================
# Release MSPSharedLibraries (Step 1)
# ============================================================================
release_msp_shared_libraries() {
    log_section "Step 1: Releasing MSPSharedLibraries (foundation dependency)"

    # Update podspec
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

    log_success "MSPSharedLibraries released successfully"
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

    # Update podspec
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
    
    # Extract adapters from PODS_MODULES (exclude MSPSharedLibraries and MSPCore)
    # Adapters are all modules that are not core modules
    # Note: NovaCore is not included - it's embedded via vendored_frameworks, not published separately
    local core_modules=("MSPSharedLibraries" "MSPCore" "MSPiOSCore" "MSPOMSDK")
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

    # Update podspec
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
            notify_release_failure "CocoaPods" "$VERSION" "MSPiOSCore release failed" "Foundation Release"
        fi
        msp_state_mark_step_failed "pods_publish" "MSPiOSCore release failed" "1"
        # Task 3: Preflight mode allows soft-fail, release/production requires hard-fail
        if [[ "$release_tier" == "release" ]] || [[ "$release_tier" == "production" ]]; then
            log_error "[MSP][ORCH] Release tier ($release_tier): MSPiOSCore release failure - aborting"
            log_error "[MSP][ORCH] All other modules depend on MSPiOSCore. Cannot proceed."
            exit 1
        else
            log_warn "[MSP][ORCH] Preflight mode: CocoaPods release failed, continuing with other steps"
        fi
    fi
    
    # Step 1: Release MSPSharedLibraries
    if release_msp_shared_libraries; then
        ((successful_pods++))
    else
        ((failed_pods++))
        failed_pod_names+=("MSPSharedLibraries")
        if [[ "$DRY_RUN" != "true" ]]; then
            notify_release_failure "CocoaPods" "$VERSION" "MSPSharedLibraries release failed" "Foundation Release"
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
            notify_release_failure "CocoaPods" "$VERSION" "Adapter release failed" "Adapter Release"
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
            notify_release_failure "CocoaPods" "$VERSION" "MSPCore release failed" "Main Framework Release"
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
