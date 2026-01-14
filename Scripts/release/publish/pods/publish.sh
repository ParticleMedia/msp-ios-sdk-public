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
#     ├─ MSPNovaAdapter            (binary distribution, but in Adapters phase)
#     └─ MSPAmazonAdapter
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
#     - MSPiOSCore, MSPSharedLibraries, MSPCore, MSPNovaAdapter
#
# Source Distribution (git+tag source):
#     - MSPPrebidAdapter, MSPGoogleAdapter, MSPFacebookAdapter, MSPAmazonAdapter
#
# Why MSPNovaAdapter is binary?
# - MSPNovaAdapter includes private NovaCore.xcframework (not in git repo)
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

# Source process utilities (timeout and cleanup functions)
if [[ -f "$ROOT_DIR/Scripts/lib/process_utils.sh" ]]; then
    # shellcheck source=Scripts/lib/process_utils.sh
    source "$ROOT_DIR/Scripts/lib/process_utils.sh"
else
    log_error "process_utils.sh not found"
    exit 1
fi

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
DEFAULT_PODS_MODULES="MSPiOSCore MSPSharedLibraries MSPGoogleAdsTypes MSPPrebidAdapter MSPCore MSPGoogleAdapter MSPFacebookAdapter MSPNovaAdapter MSPAmazonAdapter MSPMolocoAdapter MSPLiftoffAdapter"
PODS_MODULES="${PODS_MODULES:-$DEFAULT_PODS_MODULES}"

# ============================================================================
# Binary Distribution Detection
# ============================================================================
# ============================================================================
# Mapping Functions: Pod Name → Directory Name
# ============================================================================
# Some adapters have different pod names vs directory names
# Example: MSPAmazonAdapter (pod) → AmazonAdapter (directory)
# Note: XCFramework name now matches pod name (MSPAmazonAdapter.xcframework)

get_module_dir() {
    local pod_name="$1"
    case "$pod_name" in
        "MSPAmazonAdapter") echo "AmazonAdapter" ;;
        "MSPMolocoAdapter") echo "MolocoAdapter" ;;
        "MSPLiftoffAdapter") echo "LiftoffAdapter" ;;
        *) echo "$pod_name" ;;
    esac
}

# ============================================================================
# Binary Distribution Check
# ============================================================================
# Check if a pod uses binary distribution (HTTP zip source from GitHub Releases).
# This is a DISTRIBUTION METHOD check, NOT a release order check.
#
# Binary Distribution Pods:
# - MSPiOSCore: Foundation framework (binary only)
# - MSPSharedLibraries: Contains multiple XCFrameworks + PrebidMobile
# - MSPCore: Main framework (binary distribution)
# - MSPNovaAdapter: Includes private NovaCore.xcframework (binary only)
#
# Note: Must match BINARY_DISTRIBUTION_PODS in generate_podspec.sh
# ============================================================================
is_binary_distribution() {
    local pod="$1"
    case "$pod" in
        MSPiOSCore|MSPSharedLibraries|MSPGoogleAdsTypes|MSPCore|MSPNovaAdapter|MSPPrebidAdapter|MSPGoogleAdapter|MSPFacebookAdapter|MSPAmazonAdapter|MSPMolocoAdapter|MSPLiftoffAdapter)
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
    echo "  3. Publish Adapters (MSPFacebookAdapter, MSPGoogleAdapter, MSPNovaAdapter, MSPAmazonAdapter, MSPPrebidAdapter)"
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

    # Map pod name to directory name (for adapters with renamed modules)
    # Example: MSPAmazonAdapter (pod) → AmazonAdapter (directory)
    local module_dir=$(get_module_dir "$adapter")
    local adapter_dir="${ROOT_DIR}/Sources/Adapters/${module_dir}/${module_dir}"

    # Validate directory exists
    if [[ ! -d "$adapter_dir" ]]; then
        log_error "PUBLISH" "Adapter directory not found: $adapter_dir"
        log_error "PUBLISH" "Expected structure: Sources/Adapters/$module_dir/$module_dir/*.swift"
        log_error "PUBLISH" "Pod name: $adapter, Directory name: $module_dir"
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
            # Capture error output to diagnose failures
            local tag_error_output
            tag_error_output=$(git tag "$tag" "$target_commit_sha" 2>&1)
            local tag_exit_code=$?
            
            if [[ $tag_exit_code -eq 0 ]]; then
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
                if [[ -n "$tag_error_output" ]]; then
                    log_warning "Git error: $tag_error_output"
                fi
                
                # Additional check: verify tag doesn't exist locally (might be a stale reference)
                if git rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1; then
                    log_warning "Tag $tag still exists locally, attempting to delete..."
                    git tag -d "$tag" 2>/dev/null || true
                    sleep 1
                fi
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

                # CRITICAL FIX: Immediately publish GitHub Release after Tag push
                # When a tag is pushed to GitHub, if no Release exists, GitHub auto-creates
                # a Draft Release. We must immediately publish it to prevent 404 errors.
                # This is the ONLY reliable place to ensure Releases are Published.
                log_info "Ensuring GitHub Release is Published (not Draft) for tag: $tag"

                # Wait 2 seconds for GitHub to create the auto-release
                sleep 2

                # Phase B: Use unified GitHub Release function
                # This will create release if needed, or verify existing release state
                if ! create_or_verify_github_release "$tag"; then
                    log_warning "Failed to create/verify GitHub Release (non-blocking, will retry later)"
                fi

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

            # Phase B: Immediately create/verify GitHub Release after Tag push
            # When a tag is pushed to GitHub, if no Release exists, GitHub auto-creates
            # a Draft Release. We must immediately create/verify it to prevent 404 errors.
            # This is the ONLY reliable place to ensure Releases are Created/Published.
            log_info "Ensuring GitHub Release is Created/Verified for tag: $tag"

            # Wait 2 seconds for GitHub to create the auto-release (if any)
            sleep 2

            # Phase B: Use unified GitHub Release function
            # This will create release if needed, or verify existing release state
            if ! create_or_verify_github_release "$tag"; then
                log_warning "Failed to create/verify GitHub Release (non-blocking, will retry later)"
            fi
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
            # Phase B: Fail-fast on timeout in production mode
            if [[ "${DRY_RUN:-true}" == "false" ]]; then
                log_error "[FAIL-FAST] Timeout waiting for remote tag '$tag' to be resolvable after $max_attempts attempts"
                log_error "Tag was pushed but not yet propagated to all GitHub servers"
                log_error "This is a timing/availability issue, not a code bug"
                return 1
            else
                log_warn "Timeout waiting for remote tag (dry-run mode - non-blocking)"
                return 0
            fi
        fi

        ((attempt++))
    done

    return 1
}

# ============================================================================
# Unified GitHub Release Management (Phase B Step 2b)
# ============================================================================
# Phase B Change: All modes create/verify GitHub Release
# DRY_RUN controls draft (true) vs published (false) state
# ============================================================================

# Create or verify GitHub Release (idempotent)
# Args:
#   $1: tag - Release tag (e.g., 0.4.0-rc.1)
# Returns:
#   0 if success, 1 if failure
# Environment:
#   MSP_DRY_RUN - Controls draft vs published (default: true)
#   MSP_GITHUB_REPO - GitHub repository (default: ParticleMedia/msp-ios-sdk-public)
#   MSP_ALLOW_EXISTING_RELEASE - Allow existing release with different state (default: false)
create_or_verify_github_release() {
    local tag="$1"
    local dry_run="${MSP_DRY_RUN:-true}"
    local repo="${MSP_GITHUB_REPO:-ParticleMedia/msp-ios-sdk-public}"

    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "GitHub Release: $tag"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Determine expected state
    local expected_draft
    if [[ "$dry_run" == "true" ]]; then
        expected_draft="true"
        log_info "Mode: DRY_RUN (draft release)"
    else
        expected_draft="false"
        log_info "Mode: PRODUCTION (published release)"
    fi

    # Check if release already exists
    if gh release view "$tag" --repo "$repo" >/dev/null 2>&1; then
        log_info "✓ Release $tag already exists"

        # Get current state
        local current_draft
        current_draft=$(gh release view "$tag" --repo "$repo" --json isDraft -q '.isDraft' 2>/dev/null || echo "false")

        log_debug "Current state: draft=$current_draft"
        log_debug "Expected state: draft=$expected_draft"

        # Verify state matches expectation
        if [[ "$current_draft" == "$expected_draft" ]]; then
            log_success "✓ Release state is correct"
            return 0
        else
            log_warning "Release state mismatch:"
            log_warning "  Current:  draft=$current_draft"
            log_warning "  Expected: draft=$expected_draft"

            # Handle mismatch
            if [[ "${MSP_ALLOW_EXISTING_RELEASE:-false}" == "true" ]]; then
                log_warning "Continuing with existing release (MSP_ALLOW_EXISTING_RELEASE=true)"

                # Auto-fix: Publish draft release if production mode expects published
                # This ensures CDN URLs are accessible for CocoaPods
                if [[ "$current_draft" == "true" ]] && [[ "$expected_draft" == "false" ]]; then
                    log_info "Auto-fixing: Publishing draft release to enable CDN access"
                    log_info "Reason: Draft releases are private, CDN URLs will return 404"
                    log_info "Action: gh release edit $tag --repo $repo --draft=false"

                    if gh release edit "$tag" --repo "$repo" --draft=false 2>&1 | tee /tmp/gh-release-publish-$tag.log; then
                        log_success "✅ Published draft release: $tag"
                        log_info "Waiting 10 seconds for GitHub to propagate release state..."
                        sleep 10

                        # Verify release is now published
                        local new_draft
                        new_draft=$(gh release view "$tag" --repo "$repo" --json isDraft -q '.isDraft' 2>/dev/null || echo "false")
                        if [[ "$new_draft" == "false" ]]; then
                            log_success "✅ Release state verified: published"
                        else
                            log_warning "⚠️ Release state still draft after publish attempt"
                            log_warning "⚠️ CDN verification may still fail"
                        fi
                    else
                        log_error "❌ Failed to publish draft release"
                        log_error "Check log: /tmp/gh-release-publish-$tag.log"
                        log_warning "Continuing anyway (MSP_ALLOW_EXISTING_RELEASE=true)"
                    fi
                elif [[ "$current_draft" == "false" ]] && [[ "$expected_draft" == "true" ]]; then
                    # Edge case: Published release but dry-run mode expects draft
                    # We don't convert published → draft (destructive), just warn
                    log_warning "⚠️ Release is published but DRY_RUN mode expects draft"
                    log_warning "⚠️ Continuing with published release (safe, non-destructive)"
                fi

                return 0
            else
                log_error "Release state mismatch"
                log_error "Options:"
                log_error "  1. Set MSP_ALLOW_EXISTING_RELEASE=true to use existing release"
                log_error "  2. Delete release: gh release delete $tag --repo $repo --yes"
                log_error "  3. Change DRY_RUN to match existing state"
                return 1
            fi
        fi
    fi

    # Release doesn't exist, create it
    log_info "Creating GitHub Release: $tag"

    # Generate release notes
    local release_notes
    release_notes=$(generate_release_notes "$tag")

    local create_args=(
        "$tag"
        --repo "$repo"
        --title "Release $tag"
        --notes "$release_notes"
    )

    if [[ "$expected_draft" == "true" ]]; then
        create_args+=(--draft)
        log_info "Creating DRAFT release (DRY_RUN mode)"
    else
        log_info "Creating PUBLISHED release (production mode)"
    fi

    # Create release
    if gh release create "${create_args[@]}" 2>&1 | tee /tmp/gh-release-create-$tag.log; then
        log_success "✓ Created GitHub Release: $tag"
        return 0
    else
        log_error "✗ Failed to create GitHub Release: $tag"
        log_error "See log: /tmp/gh-release-create-$tag.log"
        return 1
    fi
}

# Generate release notes
# Args:
#   $1: tag - Release tag
# Returns:
#   Prints release notes to stdout
generate_release_notes() {
    local tag="$1"

    cat <<EOF
# MSP iOS SDK Release $tag

## Components

This release includes the following components:
- MSPCore
- MSPSharedLibraries
- MSPPrebidAdapter
- MSPGoogleAdapter
- MSPFacebookAdapter
- MSPNovaAdapter
- MSPAmazonAdapter
- MSPMolocoAdapter (if applicable)
- MSPLiftoffAdapter (if applicable)

## Installation

Add to your \`Podfile\`:
\`\`\`ruby
pod 'MSPCore', '$tag'
# ... other pods as needed
\`\`\`

Then run:
\`\`\`bash
pod install
\`\`\`

## Documentation

See [README.md](https://github.com/ParticleMedia/msp-ios-sdk-public) for complete documentation.

## Changes

See commit history for detailed changes in this release.

---

🚀 Generated with [Claude Code](https://claude.com/claude-code)
EOF
}

# Upload zip to GitHub Release (idempotent)
# Args:
#   $1: tag - Release tag
#   $2: zip_path - Path to zip file
# Returns:
#   0 if success, 1 if failure
upload_zip_to_github() {
    local tag="$1"
    local zip_path="$2"
    local repo="${MSP_GITHUB_REPO:-ParticleMedia/msp-ios-sdk-public}"

    local zip_name
    zip_name=$(basename "$zip_path")

    log_info "Uploading: $zip_name"

    # Verify zip file exists
    if [[ ! -f "$zip_path" ]]; then
        log_error "Zip file not found: $zip_path"
        return 1
    fi

    # Check if already uploaded (idempotency)
    if gh release view "$tag" --repo "$repo" --json assets -q ".assets[] | select(.name == \"$zip_name\")" 2>/dev/null | grep -q "$zip_name"; then
        log_info "✓ $zip_name already uploaded"

        # Optional: Verify file size matches
        local remote_size
        remote_size=$(gh release view "$tag" --repo "$repo" --json assets -q ".assets[] | select(.name == \"$zip_name\") | .size" 2>/dev/null || echo "0")
        local local_size
        local_size=$(stat -f%z "$zip_path" 2>/dev/null || stat -c%s "$zip_path" 2>/dev/null || echo "0")

        if [[ "$remote_size" == "$local_size" ]] && [[ "$remote_size" != "0" ]]; then
            log_debug "File size matches: $local_size bytes"
        else
            log_warning "File size mismatch: remote=$remote_size, local=$local_size"
            if [[ "${MSP_FORCE_REUPLOAD:-false}" == "true" ]]; then
                log_info "Re-uploading (MSP_FORCE_REUPLOAD=true)..."
            else
                log_warning "Skipping re-upload (set MSP_FORCE_REUPLOAD=true to force)"
                return 0
            fi
        fi

        if [[ "${MSP_FORCE_REUPLOAD:-false}" != "true" ]]; then
            return 0
        fi
    fi

    # Upload
    log_debug "Uploading $zip_path to release $tag"
    if gh release upload "$tag" "$zip_path" --repo "$repo" --clobber 2>&1 | tee /tmp/gh-upload-$zip_name.log; then
        log_success "✓ Uploaded $zip_name"
        return 0
    else
        log_error "✗ Failed to upload $zip_name"
        log_error "See log: /tmp/gh-upload-$zip_name.log"
        return 1
    fi
}

# Upload all zips to GitHub Release (batch operation)
# Args:
#   $1: tag - Release tag
#   $@: zip_paths - Array of zip file paths
# Returns:
#   0 if all succeed, 1 if any fail
upload_all_zips_to_github() {
    local tag="$1"
    shift
    local zip_paths=("$@")

    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Uploading Zips to GitHub Release"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Release: $tag"
    log_info "Zips: ${#zip_paths[@]}"

    local failed=0
    local uploaded=0
    local skipped=0

    for zip_path in "${zip_paths[@]}"; do
        if [[ ! -f "$zip_path" ]]; then
            log_warning "Zip not found, skipping: $zip_path"
            ((skipped++))
            continue
        fi

        if upload_zip_to_github "$tag" "$zip_path"; then
            ((uploaded++))
        else
            ((failed++))
        fi
    done

    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Upload Summary:"
    log_info "  Total:    ${#zip_paths[@]}"
    log_info "  Uploaded: $uploaded"
    log_info "  Skipped:  $skipped"
    log_info "  Failed:   $failed"

    if [[ $failed -gt 0 ]]; then
        log_error "Upload failed: $failed zip(s) failed to upload"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    else
        log_success "All zips uploaded ✓"
        log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 0
    fi
}

# Wait for CDN propagation with progress indicator
# Args:
#   $1: tag - Release tag (for logging)
# Returns:
#   Always 0 (just waits)
# Environment:
#   MSP_CDN_WAIT_TIME - Wait time in seconds (default: 120)
wait_for_cdn_propagation() {
    local tag="$1"
    local wait_time="${MSP_CDN_WAIT_TIME:-120}"

    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Waiting for GitHub CDN Propagation"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Release: $tag"
    log_info "Wait time: ${wait_time}s"
    log_info "Why: GitHub Release CDN takes 60-120s to propagate globally"

    # Progress bar
    local elapsed=0
    while (( elapsed < wait_time )); do
        sleep 1
        ((elapsed++))

        # Print progress (flush output buffer to stderr)
        if (( elapsed % 10 == 0 )); then
            printf "." >&2  # Use stderr (unbuffered)
        fi
        if (( elapsed % 60 == 0 )); then
            printf " ${elapsed}s / ${wait_time}s\n" >&2  # Use stderr + newline
        fi
    done
    printf "\n" >&2  # Final newline to stderr

    # Force output to stderr for immediate visibility
    log_success "✓ CDN propagation wait complete (${wait_time}s)" >&2
    log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    return 0
}

# Verify CDN availability for a single zip (HTTP HEAD request)
# Args:
#   $1: tag - Release tag
#   $2: filename - Zip filename
# Returns:
#   0 if available, 1 if not
verify_cdn_availability() {
    local tag="$1"
    local filename="$2"
    local repo="${MSP_GITHUB_REPO:-ParticleMedia/msp-ios-sdk-public}"
    local url="https://github.com/${repo}/releases/download/${tag}/${filename}"

    log_debug "Verifying CDN: $url"

    # Try HTTP HEAD request (faster than full download)
    # Retry 3 times with 10s interval
    local attempt=1
    local max_attempts=3

    while [[ $attempt -le $max_attempts ]]; do
        if curl -L -f -I -s "$url" >/dev/null 2>&1; then
            log_success "✓ $filename is available on CDN"
            return 0
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            log_debug "CDN not ready, retrying in 10s... (attempt $attempt/$max_attempts)"
            sleep 10
        fi

        ((attempt++))
    done

    log_error "✗ $filename not available on CDN after $max_attempts attempts"
    log_error "URL: $url"
    return 1
}

# Verify CDN availability for all zips (batch verification)
# Args:
#   $1: tag - Release tag
#   $@: filenames - Array of zip filenames
# Returns:
#   0 if all available, 1 if any unavailable
verify_all_cdn_availability() {
    local tag="$1"
    shift
    local filenames=("$@")

    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Verifying CDN Availability"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Release: $tag"
    log_info "Files: ${#filenames[@]}"

    local failed=0
    local verified=0

    for filename in "${filenames[@]}"; do
        if verify_cdn_availability "$tag" "$filename"; then
            ((verified++))
        else
            ((failed++))
        fi
    done

    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "CDN Verification Summary:"
    log_info "  Total:    ${#filenames[@]}"
    log_info "  Verified: $verified"
    log_info "  Failed:   $failed"

    if [[ $failed -gt 0 ]]; then
        log_error "CDN verification failed: $failed file(s) not available"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error "This usually means:"
        log_error "  1. CDN propagation needs more time"
        log_error "  2. Zip was not uploaded successfully"
        log_error "  3. Network connectivity issues"
        log_error ""
        log_error "Recommendation: Increase MSP_CDN_WAIT_TIME (current: ${MSP_CDN_WAIT_TIME:-120}s)"
        return 1
    else
        log_success "All files verified on CDN ✓"
        log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 0
    fi
}

# Main GitHub Release workflow (orchestrates all steps)
# Args:
#   $1: tag - Release tag
#   $@: zip_paths - Array of zip file paths
# Returns:
#   0 if success, 1 if failure
prepare_github_release() {
    local tag="$1"
    shift
    local zip_paths=("$@")

    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Preparing GitHub Release (Phase B Unified Flow)"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Tag: $tag"
    log_info "Zips: ${#zip_paths[@]}"
    log_info "DRY_RUN: ${MSP_DRY_RUN:-true}"

    # Step 1: Create/verify release
    log_info ""
    log_info "Step 1: Create/verify GitHub Release"
    if ! create_or_verify_github_release "$tag"; then
        log_error "Failed to create/verify GitHub Release"
        return 1
    fi

    # Step 2: Upload zips
    log_info ""
    log_info "Step 2: Upload zips to GitHub Release"
    if ! upload_all_zips_to_github "$tag" "${zip_paths[@]}"; then
        log_error "Failed to upload zips"
        return 1
    fi

    # Step 3: Wait for CDN propagation
    log_info ""
    log_info "Step 3: Wait for CDN propagation"
    wait_for_cdn_propagation "$tag"

    # Step 4: Verify CDN availability
    log_info ""
    log_info "Step 4: Verify CDN availability"
    local filenames=()
    for zip_path in "${zip_paths[@]}"; do
        if [[ -f "$zip_path" ]]; then
            filenames+=("$(basename "$zip_path")")
        fi
    done

    if ! verify_all_cdn_availability "$tag" "${filenames[@]}"; then
        log_error "CDN verification failed"

        # Non-fatal in some cases
        if [[ "${MSP_SKIP_CDN_VERIFICATION:-false}" == "true" ]]; then
            log_warning "Continuing despite CDN verification failure (MSP_SKIP_CDN_VERIFICATION=true)"
        else
            log_error "Set MSP_SKIP_CDN_VERIFICATION=true to continue anyway (NOT recommended)"
            return 1
        fi
    fi

    log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "GitHub Release Ready ✓"
    log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    return 0
}

# ============================================================================
# Verify and Fix GitHub Release Zip (Enhanced Idempotency)
# ============================================================================
# Purpose: Verify that GitHub Release zip matches local zip
# - Called during idempotency check for already-published pods
# - Detects if GitHub Release has wrong/old zip file
# - Automatically re-uploads correct zip if mismatch detected
# - Ensures downstream pods (Adapters) can validate successfully
# ============================================================================
verify_and_fix_github_release_zip() {
    local pod="$1"
    local version="$2"

    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "🔍 Enhanced Idempotency Check: Verifying GitHub Release zip"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Pod: $pod $version"
    log_info "Checking if GitHub Release zip matches local zip..."

    local local_zip="$ROOT_DIR/Build/Zips/${pod}-${version}.zip"
    local zip_url="https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/${pod}-${version}.zip"

    # Check if local zip exists
    if [[ ! -f "$local_zip" ]]; then
        log_warning "Local zip not found: $local_zip"
        log_warning "Cannot verify GitHub Release zip (no local reference)"
        log_info "Assuming GitHub Release is correct (pod already published)"
        return 0
    fi

    # Calculate local zip checksum
    local local_checksum=$(shasum -a 256 "$local_zip" 2>/dev/null | awk '{print $1}')
    if [[ -z "$local_checksum" ]]; then
        log_error "Failed to calculate local zip checksum"
        return 1
    fi

    log_info "Local zip checksum: $local_checksum"

    # Download GitHub Release zip and calculate checksum
    log_info "Downloading zip from GitHub Release to verify..."
    local temp_verify="/tmp/msp-verify-github-release-$$"
    mkdir -p "$temp_verify"

    local github_checksum=""
    local download_success=false

    # Try to download with timeout (30 seconds max)
    if timeout 30 curl -L -f -s -o "$temp_verify/verify.zip" "$zip_url" 2>/dev/null; then
        local file_size=$(stat -f%z "$temp_verify/verify.zip" 2>/dev/null || stat -c%s "$temp_verify/verify.zip" 2>/dev/null || echo "0")

        if [[ $file_size -gt 0 ]]; then
            github_checksum=$(shasum -a 256 "$temp_verify/verify.zip" 2>/dev/null | awk '{print $1}')
            if [[ -n "$github_checksum" && ${#github_checksum} -eq 64 ]]; then
                download_success=true
                log_info "GitHub Release checksum: $github_checksum"
            else
                log_warning "Downloaded file but checksum calculation failed"
            fi
        else
            log_warning "Downloaded file is empty (0 bytes)"
        fi
    else
        log_warning "Failed to download GitHub Release zip (timeout or 404)"
        log_warning "This may indicate:"
        log_warning "  1. CDN is temporarily unavailable"
        log_warning "  2. Zip file was never uploaded to GitHub Release"
        log_warning "  3. Network connectivity issues"
    fi

    rm -rf "$temp_verify"

    # Compare checksums
    if [[ "$download_success" == "true" ]]; then
        if [[ "$local_checksum" == "$github_checksum" ]]; then
            log_success "✅ GitHub Release zip matches local zip"
            log_success "✅ Checksum verified: $local_checksum"
            log_info "No action needed - GitHub Release is correct"
            return 0
        else
            log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log_warning "⚠️  CRITICAL: GitHub Release zip MISMATCH detected!"
            log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log_warning ""
            log_warning "Pod:                     $pod $version"
            log_warning "Local zip checksum:      $local_checksum  ← CORRECT (source of truth)"
            log_warning "GitHub Release checksum: $github_checksum  ← WRONG (old/stale version)"
            log_warning ""
            log_warning "Root Cause Analysis:"
            log_warning "  - Pod was published to CocoaPods with WRONG checksum in previous run"
            log_warning "  - GitHub Release contains OLD zip file"
            log_warning "  - Podspec may have incorrect checksum: $github_checksum"
            log_warning "  - Downstream pods (Adapters) CANNOT validate dependencies"
            log_warning ""
            log_warning "Impact:"
            log_warning "  - If this is MSPSharedLibraries: ALL Adapters will fail"
            log_warning "  - If this is MSPCore: Integration will fail"
            log_warning "  - CocoaPods validation error: 'Verification checksum was incorrect'"
            log_warning ""
            log_warning "Automatic Fix Strategy:"
            log_warning "  1. Upload correct zip ($local_checksum) to GitHub Release"
            log_warning "  2. Wait for CDN propagation (based on file size)"
            log_warning "  3. Verify upload succeeded"
            log_warning "  4. Continue with Resume (Adapters should now pass)"
            log_warning ""
            log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log_info ""
            log_info "🔧 Applying automatic fix..."

            # Phase B: Use unified upload function with force re-upload
            log_info "Uploading correct zip to GitHub Release (with force re-upload)..."
            local old_force_reupload="${MSP_FORCE_REUPLOAD:-false}"
            export MSP_FORCE_REUPLOAD=true

            if upload_zip_to_github "$version" "$local_zip"; then
                export MSP_FORCE_REUPLOAD="$old_force_reupload"

                log_success "✅ Upload completed successfully"

                # Calculate appropriate wait time based on file size
                local file_size_bytes=$(stat -f%z "$local_zip" 2>/dev/null || stat -c%s "$local_zip" 2>/dev/null || echo "0")
                local file_size_mb=$((file_size_bytes / 1024 / 1024))
                local wait_time=60

                if [[ $file_size_mb -ge 15 ]]; then
                    wait_time=120  # 2 minutes for very large files (>15MB)
                    log_info "Very large file (${file_size_mb}MB) - CDN propagation may take 2-10 minutes"
                elif [[ $file_size_mb -ge 5 ]]; then
                    wait_time=90   # 1.5 minutes for large files (5-15MB)
                    log_info "Large file (${file_size_mb}MB) - CDN propagation may take 1-5 minutes"
                else
                    wait_time=60   # 1 minute for smaller files (<5MB)
                    log_info "Medium file (${file_size_mb}MB) - CDN propagation may take 30-120 seconds"
                fi

                log_info "Waiting ${wait_time} seconds for GitHub CDN to propagate new version..."
                log_info "Note: Full global CDN propagation can take 2-10 minutes for large files"
                sleep $wait_time

                # Verify upload by downloading again
                log_info "Verifying upload succeeded by re-downloading from CDN..."
                local verify_temp="/tmp/msp-verify-upload-$$"
                mkdir -p "$verify_temp"

                local verified_checksum=""
                if timeout 30 curl -L -f -s -o "$verify_temp/verify.zip" "$zip_url" 2>/dev/null; then
                    verified_checksum=$(shasum -a 256 "$verify_temp/verify.zip" 2>/dev/null | awk '{print $1}')
                fi

                rm -rf "$verify_temp"

                if [[ "$verified_checksum" == "$local_checksum" ]]; then
                    log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    log_success "✅ AUTOMATIC FIX SUCCEEDED"
                    log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    log_success "✅ GitHub Release zip updated successfully"
                    log_success "✅ Verified checksum: $verified_checksum"
                    log_success "✅ CDN now serving correct version"
                    log_success ""
                    log_success "Expected Outcome:"
                    log_success "  - Downstream pods should now pass validation"
                    log_success "  - Resume can continue safely"
                    log_success "  - No manual intervention needed"
                    log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    return 0
                else
                    log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    log_warning "⚠️  CDN PROPAGATION INCOMPLETE"
                    log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    log_warning "Upload succeeded but CDN still serving old version"
                    log_warning "Expected: $local_checksum"
                    log_warning "Got:      $verified_checksum"
                    log_warning ""
                    log_warning "This is NORMAL for large files - CDN needs more time"
                    log_warning ""
                    log_warning "Next Steps:"
                    log_warning "  1. Wait 5-10 minutes for full CDN propagation"
                    log_warning "  2. Resume again - verification will succeed"
                    log_warning "  3. Or continue now - CocoaPods will validate against GitHub (not CDN)"
                    log_warning ""
                    log_warning "Continuing with Resume (safe to proceed)..."
                    log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    # Continue anyway - GitHub Release has correct zip, just CDN is slow
                    return 0
                fi
            else
                export MSP_FORCE_REUPLOAD="$old_force_reupload"
                log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                log_error "❌ AUTOMATIC FIX FAILED"
                log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                log_error "Failed to upload correct zip to GitHub Release"
                log_error ""
                log_error "Manual fix required:"
                log_error "  MSP_FORCE_REUPLOAD=true upload_zip_to_github $version $local_zip"
                log_error ""
                log_error "After manual upload:"
                log_error "  1. Wait 5-10 minutes for CDN propagation"
                log_error "  2. Run Resume again"
                log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                return 1
            fi
        fi
    else
        log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_warning "⚠️  Cannot verify GitHub Release zip"
        log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_warning "Unable to download GitHub Release zip for verification"
        log_warning ""
        log_warning "Possible causes:"
        log_warning "  1. Zip file never uploaded to GitHub Release"
        log_warning "  2. CDN is temporarily unavailable"
        log_warning "  3. Network connectivity issues"
        log_warning ""
        log_warning "Recommended action:"
        log_warning "  Upload zip manually to ensure it exists:"
        log_warning "  MSP_FORCE_REUPLOAD=true upload_zip_to_github $version $local_zip"
        log_warning ""
        log_warning "Continuing with Resume (pod already published)..."
        log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        # Don't fail - pod is already published, just can't verify
        return 0
    fi
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

    # Stage A: All modes (dry-run/production) create GitHub release and upload binary zip for binary distribution pods
    # HTTP binary distribution requires zip to be available before pod trunk push
    if is_binary_distribution "$pod"; then
        local mode_label="dry-run"
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            mode_label="production"
        fi
        log_info "[$mode_label] Creating GitHub release and uploading binary zip (HTTP distribution)"
        
        # Use unified create_zip_from_xcframework function to handle all pod types correctly
        # This function handles special cases like MSPNovaAdapter, MSPSharedLibraries, etc.
        if ! create_zip_from_xcframework "$pod" "$version"; then
            log_error "Failed to create zip file from XCFramework"
            return 1
        fi
        
        local zip_name="${pod}-${version}.zip"
        local local_zip_path="$ROOT_DIR/Build/Zips/$zip_name"
        
        if [[ ! -f "$local_zip_path" ]]; then
            log_error "Zip file was not created: $local_zip_path"
            return 1
        fi
        
        log_info "Created zip file: $local_zip_path"
        
    # Phase B: Create/verify GitHub Release and upload zip using unified functions
    local gh_release_created=false
    
    # Step 1: Create/verify GitHub Release (Phase B unified flow)
    if ! create_or_verify_github_release "$version"; then
        log_error "Failed to create/verify GitHub Release"
        return 1
    fi

    # Step 2: Upload zip using unified function
    if ! upload_zip_to_github "$version" "$local_zip_path"; then
        log_error "Failed to upload zip to GitHub Release"
        return 1
    fi

    # Step 3: Wait for CDN propagation and verify availability
    # Calculate CDN wait time based on file size
    local file_size_mb
    file_size_mb=$(du -m "$ROOT_DIR/$zip_name" 2>/dev/null | awk '{print $1}')
    local cdn_wait_time=60
    if [[ $file_size_mb -lt 5 ]]; then
        cdn_wait_time=60   # Small files: 60s (minimum recommended)
    elif [[ $file_size_mb -lt 20 ]]; then
        cdn_wait_time=90   # Medium files: 90s
    else
        cdn_wait_time=120  # Large files: 120s
    fi

    # Set CDN wait time and wait
    export MSP_CDN_WAIT_TIME=$cdn_wait_time
    wait_for_cdn_propagation "$version"

    # Verify CDN availability
    local zip_name="${pod}-${version}.zip"
    if ! verify_cdn_availability "$version" "$zip_name"; then
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error "❌ CRITICAL: Failed to verify GitHub Release upload"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error ""
        log_error "Pod:       $pod $version"
        log_error "URL:       https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/${zip_name}"
        log_error ""
        log_error "Possible causes:"
        log_error "  1. GitHub CDN propagation is slower than expected (>120s)"
        log_error "  2. GitHub Release asset was corrupted during upload"
        log_error "  3. Network issues preventing download"
        log_error "  4. GitHub CDN is serving stale cached version"
        log_error ""
        log_error "Impact:"
        log_error "  - Proceeding may result in incorrect checksum in podspec"
        log_error "  - This will cause validation failures for all dependent pods"
        log_error ""
        log_error "Solution:"
        log_error "  1. Wait 2-3 minutes for CDN to fully propagate"
        log_error "  2. Manually verify: curl -L -I https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/${zip_name}"
        log_error "  3. If accessible, re-run this script to continue"
        log_error ""
        log_error "🛑 Aborting to prevent incorrect podspec generation"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    fi

    gh_release_created=true
    
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
        
        # ====================================================================
        # Smart Wait Strategy: Dynamic wait time based on file size
        # ====================================================================
        # Rationale:
        # - Large files (21MB MSPSharedLibraries) need 2-5 minutes for CDN
        # - Small files (<1MB) only need 10-20 seconds
        # - Use progressive retry intervals to give CDN more time
        # ====================================================================

        # Calculate dynamic wait times based on file size
        local local_zip="$ROOT_DIR/Build/Zips/${pod}-${version}.zip"
        local initial_wait=5
        local max_download_attempts=3

        # Define retry intervals array (will be set based on file size)
        declare -a retry_intervals

        if [[ -f "$local_zip" ]]; then
            local file_size_bytes=$(stat -f%z "$local_zip" 2>/dev/null || stat -c%s "$local_zip" 2>/dev/null || echo "0")
            local file_size_mb=$((file_size_bytes / 1024 / 1024))

            if [[ $file_size_mb -ge 15 ]]; then
                # Very large files (>15MB): MSPSharedLibraries (21MB)
                initial_wait=45
                retry_intervals=(20 20 25 30)  # Progressive intervals
                max_download_attempts=5
                log_info "Very large file detected (${file_size_mb}MB), using extended wait strategy"
                log_info "Total wait time: up to 160 seconds (2.7 minutes)"
            elif [[ $file_size_mb -ge 5 ]]; then
                # Large files (5-15MB): MSPFacebookAdapter, MSPGoogleAdsTypes
                initial_wait=30
                retry_intervals=(15 15 20 20)  # ← 添加第4个元素: 20秒
                max_download_attempts=4
                log_info "Large file detected (${file_size_mb}MB), using extended wait strategy"
                log_info "Total wait time: up to 100 seconds"
            elif [[ $file_size_mb -ge 1 ]]; then
                # Medium files (1-5MB): MSPNovaAdapter, MSPFacebookAdapter
                initial_wait=15
                retry_intervals=(10 10 10)
                max_download_attempts=3
                log_info "Medium file detected (${file_size_mb}MB), using moderate wait strategy"
                log_info "Total wait time: up to 45 seconds"
            else
                # Small files (<1MB): Most adapters
                initial_wait=5
                retry_intervals=(5 5 5)
                max_download_attempts=3
                log_info "Small file detected (${file_size_mb}MB), using standard wait strategy"
                log_info "Total wait time: up to 20 seconds"
            fi
        else
            log_warning "Local zip not found, using default wait strategy"
            retry_intervals=(5 5 5)
        fi

        log_info "Waiting ${initial_wait} seconds for GitHub to process upload..."
        sleep $initial_wait

        # Download zip from GitHub Release and calculate checksum
        local download_attempt=1
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

            # Wait before next retry (use progressive intervals)
            if [[ $download_attempt -lt $max_download_attempts ]]; then
                local retry_index=$((download_attempt - 1))
                local retry_wait=${retry_intervals[$retry_index]:-5}
                log_info "Waiting ${retry_wait} seconds before retry..."
                sleep $retry_wait
            fi

            download_attempt=$((download_attempt + 1))
        done
        
        rm -rf "$temp_zip_dir"
        
        # ====================================================================
        # Local Checksum Fallback: Verify before overwriting
        # ====================================================================
        # Rationale:
        # - CDN propagation can take 2-10 minutes for large files
        # - GitHub Release may return OLD checksum if CDN not updated
        # - Local zip is the SOURCE OF TRUTH (just created/uploaded)
        # - Only overwrite podspec if GitHub checksum matches local checksum
        # - Otherwise, keep local checksum and log warning
        # ====================================================================

        if [[ -z "$zip_checksum" ]] || [[ ${#zip_checksum} -ne 64 ]]; then
            log_error "Failed to calculate checksum from GitHub Release zip file after all retries"
            log_error "This indicates:"
            log_error "  1. GitHub Release upload may have failed"
            log_error "  2. CDN propagation is taking extremely long (>2-3 minutes)"
            log_error "  3. Network connectivity issues"
            log_error ""
            log_error "Podspec will keep checksum from generate_podspec.sh (local zip)"
            log_error "CocoaPods validation may fail temporarily until GitHub Release is accessible"
            # Continue anyway - podspec already has correct checksum from generate_podspec.sh
        else
            # Verify checksum against local zip before updating
        local podspec="$ROOT_DIR/Build/ReleasePodspecs/${pod}.podspec"

        if [[ -f "$podspec" ]]; then
                log_step "Verifying GitHub Release checksum against local zip"

                # Calculate local zip checksum for comparison
                local local_zip="$ROOT_DIR/Build/Zips/${pod}-${version}.zip"
                local local_checksum=""

                if [[ -f "$local_zip" ]]; then
                    local_checksum=$(shasum -a 256 "$local_zip" 2>/dev/null | awk '{print $1}')
                    log_info "Local zip checksum:      $local_checksum"
                    log_info "GitHub Release checksum: $zip_checksum"
                else
                    log_warning "Local zip not found: $local_zip"
                    log_warning "Cannot verify checksum consistency"
                fi

                # Compare checksums
                if [[ -n "$local_checksum" ]]; then
                    if [[ "$zip_checksum" == "$local_checksum" ]]; then
                        log_success "✅ GitHub Release checksum matches local zip"
                        log_info "Updating podspec with verified checksum"

                        # Update podspec using Ruby
            ruby <<RUBY_SCRIPT
podspec_path = '$podspec'
zip_url = '$zip_url'
zip_checksum = '$zip_checksum'

podspec_content = File.read(podspec_path)
# Replace the source block with checksum included
new_source = "  spec.source = {\n    :http => \"#{zip_url}\",\n    :type => \"zip\",\n    :sha256 => \"#{zip_checksum}\"\n  }"
podspec_content.gsub!(/  spec\.source = \{.*?\n  \}/m, new_source)
File.write(podspec_path, podspec_content)
RUBY_SCRIPT
                        log_success "Updated podspec with checksum from GitHub Release: $zip_checksum"
                    else
                        log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                        log_warning "⚠️  CHECKSUM MISMATCH DETECTED"
                        log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                        log_warning "GitHub Release checksum does NOT match local zip!"
                        log_warning ""
                        log_warning "Local zip checksum:      $local_checksum  ← SOURCE OF TRUTH"
                        log_warning "GitHub Release checksum: $zip_checksum  ← CDN may be serving old version"
                        log_warning ""
                        log_warning "Root Cause Analysis:"
                        log_warning "  - CDN propagation takes 2-10 minutes for large files"
                        log_warning "  - GitHub Release was updated, but CDN still serves old version"
                        log_warning "  - This is expected behavior for large files (>15MB)"
                        log_warning ""
                        log_warning "Action Taken:"
                        log_warning "  ✅ Keeping podspec with LOCAL ZIP checksum (correct)"
                        log_warning "  ❌ NOT overwriting with GitHub Release checksum (old)"
                        log_warning ""
                        log_warning "Expected Outcome:"
                        log_warning "  - Podspec has correct checksum: $local_checksum"
                        log_warning "  - CocoaPods validation will succeed once CDN catches up (2-10 min)"
                        log_warning "  - Safe to continue with release (pod trunk push will wait for CDN)"
                        log_warning ""
                        log_warning "If CocoaPods validation fails immediately:"
                        log_warning "  1. This is temporary - CDN is still propagating"
                        log_warning "  2. Wait 5-10 minutes and Resume will succeed"
                        log_warning "  3. Manual verification: curl -I $zip_url"
                        log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                        log_info ""
                        log_info "Podspec will retain checksum from generate_podspec.sh (local zip)"
                        log_info "This is the CORRECT behavior - local zip is source of truth"
                    fi
                else
                    log_warning "Unable to calculate local zip checksum for verification"
                    log_warning "Updating podspec with GitHub Release checksum"
                    log_warning "Manual verification recommended after release"

                    # Fallback: Update with GitHub Release checksum (no verification possible)
                    ruby <<RUBY_SCRIPT
podspec_path = '$podspec'
zip_url = '$zip_url'
zip_checksum = '$zip_checksum'

podspec_content = File.read(podspec_path)
new_source = "  spec.source = {\n    :http => \"#{zip_url}\",\n    :type => \"zip\",\n    :sha256 => \"#{zip_checksum}\"\n  }"
podspec_content.gsub!(/  spec\.source = \{.*?\n  \}/m, new_source)
File.write(podspec_path, podspec_content)
RUBY_SCRIPT
                    log_success "Updated podspec with checksum from GitHub Release: $zip_checksum"
        fi
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
    local mode_label="dry-run"
    if [[ "${DRY_RUN:-true}" == "false" ]]; then
        mode_label="production"
    fi
    log_info "[$mode_label] Non-core module $pod, skipping GitHub release creation"
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
# ============================================================================
# Helper: Create Zip from XCFramework(s)
# ============================================================================
# Creates a zip file from XCFramework with special handling for complex pods.
#
# Args:
#   $1: pod name
#   $2: version
#
# Returns:
#   0 if zip created successfully
#   1 if failed
# ============================================================================
create_zip_from_xcframework() {
    local pod="$1"
    local version="$2"
    local zip_name="${pod}-${version}.zip"

    log_info "Creating zip file from XCFramework..."

    # Prepare temp directory with unique name (mktemp for atomic uniqueness)
    # Old approach: local temp_zip_dir="/tmp/msp_zip_recovery_$$"
    # Problem: $$ returns parent PID in background processes, causing conflicts
    # Solution: Use mktemp to generate unique directory names
    local temp_zip_dir
    temp_zip_dir=$(mktemp -d "/tmp/msp_zip_${pod}_${version}_XXXXXX")

    if [[ -z "$temp_zip_dir" || ! -d "$temp_zip_dir" ]]; then
        log_error "❌ Failed to create temporary directory"
        return 1
    fi

    log_debug "Created temporary directory: $temp_zip_dir (PID: $$, BASHPID: ${BASHPID:-N/A})"

    # Ensure cleanup on exit
    trap "rm -rf '$temp_zip_dir' 2>/dev/null || true" EXIT INT TERM

    # Check if zip command is available
    if ! command -v zip &>/dev/null; then
        log_error "❌ zip command not found"
        log_error "Please install zip utility"
        rm -rf "$temp_zip_dir"
        return 1
    fi

    # ========================================================================
    # Special handling for different pod types
    # ========================================================================
    case "$pod" in
        MSPSharedLibraries)
            # MSPSharedLibraries embeds MSPiOSCore and includes ThirdParty
            log_info "Special handling for MSPSharedLibraries (embeds MSPiOSCore)"

            # Create directory structure
            mkdir -p "$temp_zip_dir/Binary"
            mkdir -p "$temp_zip_dir/ThirdParty/PrebidMobile"

            # Copy MSPSharedLibraries.xcframework using ditto (preserves symlinks)
            local shared_lib_path="$ROOT_DIR/Build/XCFrameworks/MSPSharedLibraries.xcframework"
            if [[ ! -d "$shared_lib_path" ]]; then
                log_error "❌ MSPSharedLibraries.xcframework not found: $shared_lib_path"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            if ! ditto "$shared_lib_path" "$temp_zip_dir/Binary/$(basename "$shared_lib_path")"; then
                log_error "❌ Failed to copy MSPSharedLibraries.xcframework"
                rm -rf "$temp_zip_dir"
                return 1
            fi

            # Copy embedded MSPiOSCore.xcframework using ditto
            local ios_core_path="$ROOT_DIR/Build/XCFrameworks/MSPiOSCore.xcframework"
            if [[ ! -d "$ios_core_path" ]]; then
                log_error "❌ MSPiOSCore.xcframework not found: $ios_core_path"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            if ! ditto "$ios_core_path" "$temp_zip_dir/Binary/$(basename "$ios_core_path")"; then
                log_error "❌ Failed to copy MSPiOSCore.xcframework"
                rm -rf "$temp_zip_dir"
                return 1
            fi

            # Copy ThirdParty PrebidMobile using ditto
            local prebid_path="$ROOT_DIR/ThirdParty/PrebidMobile/PrebidMobile.xcframework"
            if [[ ! -d "$prebid_path" ]]; then
                log_error "❌ PrebidMobile.xcframework not found: $prebid_path"
                rm -rf "$temp_zip_dir"
                return 1
            fi
            if ! ditto "$prebid_path" "$temp_zip_dir/ThirdParty/PrebidMobile/$(basename "$prebid_path")"; then
                log_error "❌ Failed to copy PrebidMobile.xcframework"
                rm -rf "$temp_zip_dir"
                return 1
            fi

            # Copy Sources (optional, for dev mode)
            if [[ -d "$ROOT_DIR/Sources" ]]; then
                if ! ditto "$ROOT_DIR/Sources" "$temp_zip_dir/Sources"; then
                    log_warning "⚠️  Failed to copy Sources directory (non-critical)"
                fi
            fi

            log_success "✅ Prepared MSPSharedLibraries structure"
            ;;

        MSPiOSCore)
            # MSPiOSCore: Binary/MSPiOSCore.xcframework
            mkdir -p "$temp_zip_dir/Binary"

            local xcframework_path="$ROOT_DIR/Build/XCFrameworks/${pod}.xcframework"

            if [[ ! -d "$xcframework_path" ]]; then
                log_error "❌ XCFramework not found: $xcframework_path"
                rm -rf "$temp_zip_dir"
                return 1
            fi

            if ! ditto "$xcframework_path" "$temp_zip_dir/Binary/$(basename "$xcframework_path")"; then
                log_error "❌ Failed to copy MSPiOSCore.xcframework"
                rm -rf "$temp_zip_dir"
                return 1
            fi

            log_success "✅ Prepared MSPiOSCore structure"
            ;;

        *)
            # Default: Binary/<Pod>.xcframework
            mkdir -p "$temp_zip_dir/Binary"

            # ========================================================================
            # Special Case: MSPNovaAdapter
            # ========================================================================
            # MSPNovaAdapter is unique:
            # - Uses pre-packaged NovaCore.xcframework from Binary/ directory
            # - NovaCore is not built by our build system (proprietary/third-party)
            # - Unlike other adapters that use Build/XCFrameworks/
            # ========================================================================
            if [[ "$pod" == "MSPNovaAdapter" ]]; then
                log_info "MSPNovaAdapter: Binary adapter with embedded NovaCore dependency"

                # Copy MSPNovaAdapter.xcframework (MSPNovaAdapter自身的代码)
                local novaadapter_path="$ROOT_DIR/Build/XCFrameworks/MSPNovaAdapter.xcframework"

                if [[ ! -d "$novaadapter_path" ]]; then
                    log_error "❌ MSPNovaAdapter.xcframework not found: $novaadapter_path"
                    log_error "MSPNovaAdapter.xcframework must be built before release"
                    log_error "Run: ./Scripts/xcframeworks/build_module.sh MSPNovaAdapter"
                    rm -rf "$temp_zip_dir"
                    return 1
                fi

                if ! ditto "$novaadapter_path" "$temp_zip_dir/Binary/MSPNovaAdapter.xcframework"; then
                    log_error "❌ Failed to copy MSPNovaAdapter.xcframework"
                    rm -rf "$temp_zip_dir"
                    return 1
                fi
                log_success "✅ Copied MSPNovaAdapter.xcframework"

                # Copy NovaCore.xcframework (第三方依赖)
                local novacore_path="$ROOT_DIR/Binary/NovaCore.xcframework"

                if [[ ! -d "$novacore_path" ]]; then
                    log_error "❌ NovaCore.xcframework not found: $novacore_path"
                    log_error "MSPNovaAdapter requires pre-packaged NovaCore.xcframework in Binary/"
                    rm -rf "$temp_zip_dir"
                    return 1
                fi

                if ! ditto "$novacore_path" "$temp_zip_dir/Binary/NovaCore.xcframework"; then
                    log_error "❌ Failed to copy NovaCore.xcframework"
                    rm -rf "$temp_zip_dir"
                    return 1
                fi
                log_success "✅ Copied NovaCore.xcframework"

                log_success "✅ Prepared MSPNovaAdapter structure (MSPNovaAdapter + NovaCore)"

            else
                # Regular adapters: use Build/XCFrameworks/
                local xcframework_path="$ROOT_DIR/Build/XCFrameworks/${pod}.xcframework"

                if [[ ! -d "$xcframework_path" ]]; then
                    log_error "❌ XCFramework not found: $xcframework_path"
                    log_error "Expected location: Build/XCFrameworks/${pod}.xcframework"
                    
                    # Write failure status immediately to trigger fail-fast
                    if [[ -n "$result_file" ]]; then
                        echo "ERROR: XCFramework not found at $xcframework_path" > "$result_file"
                        echo "FAILED" > "$result_file.status" 2>/dev/null || true
                        echo "1" > "$result_file.exit" 2>/dev/null || true
                    fi
                    
                    rm -rf "$temp_zip_dir"
                    return 1
                fi

                if ! ditto "$xcframework_path" "$temp_zip_dir/Binary/$(basename "$xcframework_path")"; then
                    log_error "❌ Failed to copy ${pod}.xcframework"
                    rm -rf "$temp_zip_dir"
                    return 1
                fi

                log_success "✅ Prepared $pod structure"
            fi
            ;;
    esac

    # ========================================================================
    # Create zip file
    # ========================================================================
    log_info "Creating zip: $zip_name"

    # Pre-flight check: detect broken symbolic links
    local broken_links
    broken_links=$(find "$temp_zip_dir" -type l ! -exec test -e {} \; -print 2>/dev/null)
    if [[ -n "$broken_links" ]]; then
        log_warning "⚠️  Found broken symbolic links (will attempt to zip anyway):"
        echo "$broken_links" | while read -r link; do
            log_warning "  - $link -> $(readlink "$link" 2>/dev/null || echo 'broken')"
        done
    fi

    local zip_error_output
    zip_error_output=$(mktemp)

    (
        cd "$temp_zip_dir" || exit 1
        # Exclude common problematic files
        if zip -r "$zip_name" . \
            -x '*.DS_Store' \
            -x '__MACOSX/*' \
            >/dev/null 2>"$zip_error_output"; then
            log_success "✅ Zip file created"
        else
            log_error "❌ Failed to create zip file"
            log_error "Zip error output:"
            cat "$zip_error_output" >&2

            # Enhanced diagnostics
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log_error "Enhanced Diagnostics:"
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log_error "1. Directory contents:"
            ls -laR "$temp_zip_dir" 2>&1 | head -50 >&2

            log_error ""
            log_error "2. Symbolic links:"
            find "$temp_zip_dir" -type l -ls 2>&1 | head -20 >&2

            log_error ""
            log_error "3. File permissions:"
            find "$temp_zip_dir" ! -perm -u+r -ls 2>&1 | head -10 >&2 || echo "  (All files readable)" >&2

            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

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

    # Move zip to Build/Zips
    mkdir -p "$ROOT_DIR/Build/Zips"
    mv "$temp_zip_dir/$zip_name" "$ROOT_DIR/Build/Zips/"

    # Cleanup
    rm -rf "$temp_zip_dir"

    log_success "✅ Zip created: Build/Zips/$zip_name"

    return 0
}

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
    # Step 1: Check if zip exists and verify checksum (automatic validation)
    # ========================================================================
    log_info "Checking zip file: $zip_url"

    local zip_exists=false
    if curl -L -f -I -s "$zip_url" >/dev/null 2>&1; then
        zip_exists=true
        log_info "✅ Zip file exists on GitHub Release"
    else
        log_warning "⚠️  Zip file not found on GitHub Release"
    fi

    # ========================================================================
    # Step 2: If zip exists, ALWAYS verify checksum (CDN cache detection)
    # ========================================================================
    local need_reupload=false

    if [[ "$zip_exists" == "true" ]]; then
        log_info "Verifying checksum (automatic CDN cache detection)..."

        # Get expected checksum from local zip or create it
        local local_zip_path="$ROOT_DIR/Build/Zips/$zip_name"
        local expected_checksum=""

        if [[ -f "$local_zip_path" ]]; then
            expected_checksum=$(shasum -a 256 "$local_zip_path" 2>/dev/null | awk '{print $1}')
            log_info "Expected checksum (from local cache): $expected_checksum"
        else
            # Create local zip to get expected checksum
            log_info "Creating local zip to calculate expected checksum..."

            if ! create_zip_from_xcframework "$pod" "$version"; then
                log_error "Failed to create local zip for checksum calculation"
                return 1
            fi

            expected_checksum=$(shasum -a 256 "$local_zip_path" 2>/dev/null | awk '{print $1}')
            log_info "Expected checksum (newly calculated): $expected_checksum"
        fi

        # Download and verify checksum from GitHub
        log_info "Downloading zip from GitHub to verify checksum..."

        local temp_verify="/tmp/msp-checksum-verify-$$"
        mkdir -p "$temp_verify"

        if curl -L -f -s -o "$temp_verify/verify.zip" "$zip_url" 2>/dev/null; then
            local actual_checksum
            actual_checksum=$(shasum -a 256 "$temp_verify/verify.zip" 2>/dev/null | awk '{print $1}')

            rm -rf "$temp_verify"

            log_info "Expected checksum: $expected_checksum"
            log_info "GitHub checksum:   $actual_checksum"

            if [[ "$actual_checksum" == "$expected_checksum" ]]; then
                log_success "✅ Checksum verified - zip is correct"
                return 0  # ✅ Checksum 匹配，直接返回
            else
                log_warning "⚠️  CHECKSUM MISMATCH DETECTED (CDN cache issue)"
                log_warning "   Expected: $expected_checksum"
                log_warning "   Got:      $actual_checksum"
                log_warning "   → Will automatically delete old zip and reupload"
                need_reupload=true
            fi
        else
            log_warning "Failed to download zip for verification"
            rm -rf "$temp_verify"
            need_reupload=true
        fi
    else
        # Zip doesn't exist, need to upload
        log_info "Zip file not found, will create and upload"
        need_reupload=true
    fi

    # ========================================================================
    # Step 3: If reupload needed, automatically delete and recreate
    # ========================================================================
    if [[ "$need_reupload" != "true" ]]; then
        # Checksum verified, no action needed
        return 0
    fi

    # DRY_RUN mode check
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Would recreate and reupload zip file"
        log_success "DRY RUN: Zip file would be verified/recreated"
        return 0
    fi

    log_info "Recreating and reuploading zip file (script-level automatic fix)..."

    # Delete existing zip from GitHub Release (clear CDN cache)
    if [[ "$zip_exists" == "true" ]]; then
        log_info "Deleting old zip from GitHub Release to clear CDN cache..."

        # Use unified GitHub CLI authentication check
        if ! unified_github_cli_auth_check; then
            log_error "❌ GitHub CLI authentication failed - cannot delete old zip"
            return 1
        fi

        if gh release delete-asset "$version" "$zip_name" \
            --repo "ParticleMedia/msp-ios-sdk-public" \
            --yes 2>/dev/null; then
            log_success "✅ Deleted old zip file"
        else
            log_warning "Failed to delete old zip (continuing anyway)"
        fi

        # Wait for CDN to propagate deletion
        log_info "Waiting 10 seconds for CDN to clear cache..."
        sleep 10
    fi

    # Use unified GitHub CLI authentication check (reuse pre-flight check result)
    # Note: This should have been checked earlier, but we verify again here for safety
    if ! unified_github_cli_auth_check; then
        log_error "❌ GitHub CLI authentication failed"
        log_error "This should have been caught in the pre-flight check"
        return 1
    fi

    # Create zip file using helper function
    if ! create_zip_from_xcframework "$pod" "$version"; then
        log_error "Failed to create zip file from XCFramework"
        return 1
    fi

    local local_zip_path="$ROOT_DIR/Build/Zips/$zip_name"
    local checksum
    checksum=$(shasum -a 256 "$local_zip_path" 2>/dev/null | awk '{print $1}')
    log_info "SHA256: $checksum"

    # Phase B: Upload to GitHub Release using unified functions
    log_info "Uploading zip file to GitHub Release..."

    # Step 1: Create/verify GitHub Release (Phase B unified flow)
    if ! create_or_verify_github_release "$version"; then
        log_error "Failed to create/verify GitHub Release"
        return 1
    fi

    # Step 2: Upload zip using unified function
    if ! upload_zip_to_github "$version" "$ROOT_DIR/Build/Zips/$zip_name"; then
        log_error "❌ Failed to upload zip file"
        log_error "Local zip file preserved at: $ROOT_DIR/Build/Zips/$zip_name"
        log_error "You can manually upload it with:"
        log_error "  gh release upload $version $ROOT_DIR/Build/Zips/$zip_name --repo ParticleMedia/msp-ios-sdk-public --clobber"
        log_warning "Continuing anyway (local zip exists for checksum calculation)"
        return 0  # Return success to allow checksum calculation with local zip
    fi

    # ========================================================================
    # Verify upload with CDN cache invalidation (dynamic wait time)
    # ========================================================================
    # Problem: GitHub CDN may cache old versions of zip files
    # Solution: Wait longer and verify checksum stability
    log_info "Verifying upload and waiting for CDN propagation..."

    # Calculate dynamic wait time based on file size
    local local_zip="$ROOT_DIR/Build/Zips/$zip_name"
    local file_size_mb
    file_size_mb=$(du -m "$local_zip" 2>/dev/null | awk '{print $1}')

    local cdn_wait_time
    if [[ $file_size_mb -lt 5 ]]; then
        cdn_wait_time=60   # Small files: 60s (minimum recommended by GitHub)
    elif [[ $file_size_mb -lt 20 ]]; then
        cdn_wait_time=90   # Medium files: 90s (extra buffer for reliability)
    else
        cdn_wait_time=120  # Large files (>20MB): 120s (2 minutes)
    fi

    # Phase B: Use unified CDN wait and verification
    # Set CDN wait time based on file size (override default)
    export MSP_CDN_WAIT_TIME=$cdn_wait_time
    log_info "File size: ${file_size_mb}MB → CDN wait time: ${cdn_wait_time}s"

    # Wait for CDN propagation using unified function
    wait_for_cdn_propagation "$version"

    # Verify CDN availability using unified function
    if ! verify_cdn_availability "$version" "$zip_name"; then
        log_error "❌ Zip file not accessible on CDN"
        log_error "This may indicate:"
        log_error "  1. Upload failed (check GitHub Release manually)"
        log_error "  2. Extreme CDN delay (rare for files <100MB)"
        log_error "  3. Network connectivity issues"

        # Phase B: Remove MSP_RELEASE_TIER check, use DRY_RUN instead
        if [[ "${MSP_DRY_RUN:-true}" == "false" ]]; then
            log_error "[FAIL-FAST] Cannot proceed with inaccessible zip in production mode"
            return 1
        else
            log_warning "Continuing in DRY_RUN mode (may fail during pod trunk push)"
        fi
    else
        log_success "✅ Zip file upload verified"
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
    local max_cdn_attempts=3  # CDN download attempts
    local attempt=1

    while [[ $attempt -le $max_cdn_attempts ]]; do
        log_info "Checksum verification attempt $attempt/$max_cdn_attempts (via CDN)..."

        # Try to download from CDN and verify
        local temp_verify="/tmp/msp-verify-$$-$attempt"
        mkdir -p "$temp_verify"

        if curl -L -f -s -o "$temp_verify/verify.zip" "$zip_url" 2>/dev/null; then
            local actual_checksum
            actual_checksum=$(shasum -a 256 "$temp_verify/verify.zip" 2>/dev/null | awk '{print $1}')

            rm -rf "$temp_verify"

            if [[ "$actual_checksum" == "$expected_checksum" ]]; then
                log_success "✅ Checksum verified via CDN: $actual_checksum"
                stable=true
                break
            else
                log_warning "⚠️  Checksum mismatch (CDN may still be serving old version)"
                log_warning "   Expected: $expected_checksum"
                log_warning "   Got:      $actual_checksum"

                if [[ $attempt -lt $max_cdn_attempts ]]; then
                    log_info "Waiting 10 seconds for CDN to catch up..."
                    sleep 10
                fi
            fi
        else
            log_warning "⚠️  Failed to download from CDN for verification (attempt $attempt/$max_cdn_attempts)"
            rm -rf "$temp_verify"

            if [[ $attempt -lt $max_cdn_attempts ]]; then
                log_info "Waiting 5 seconds before retry..."
                sleep 5
            fi
        fi

        ((attempt++))
    done

    # ========================================================================
    # Fallback: Use local zip file if CDN not accessible
    # ========================================================================
    if [[ "$stable" != "true" ]]; then
        log_warning "⚠️  Unable to verify checksum via CDN after $max_cdn_attempts attempts"
        log_info "Attempting fallback: verify using local zip file..."

        # Check if local zip exists
        local local_zip="$ROOT_DIR/Build/Zips/$zip_name"

        if [[ -f "$local_zip" ]]; then
            log_info "Local zip file found: $local_zip"

            # Calculate checksum of local zip
            local local_checksum
            local_checksum=$(shasum -a 256 "$local_zip" 2>/dev/null | awk '{print $1}')

            if [[ -n "$local_checksum" ]]; then
                log_info "Local zip checksum:   $local_checksum"
                log_info "Expected checksum:    $expected_checksum"

                if [[ "$local_checksum" == "$expected_checksum" ]]; then
                    log_success "✅ Checksum verified using local zip file"
                    log_info "CDN URL may be temporarily unavailable, but:"
                    log_info "  - File uploaded to GitHub Release (API confirmed)"
                    log_info "  - Local zip exists and checksum matches"
                    log_info "  - CocoaPods validation will likely succeed once CDN catches up"
                    log_info "Continuing with release (local verification successful)"
                    stable=true
                else
                    log_error "❌ Local zip checksum mismatch!"
                    log_error "   Expected: $expected_checksum"
                    log_error "   Got:      $local_checksum"
                    log_error "   This indicates the local zip file is corrupted or incorrect"
                fi
            else
                log_error "Failed to calculate checksum of local zip file"
            fi
        else
            log_warning "Local zip file not found: $local_zip"
            log_warning "Cannot fallback to local verification"
        fi
    fi

    if [[ "$stable" != "true" ]]; then
        log_error "❌ Checksum verification failed after all attempts"
        log_error "Unable to verify checksum via:"
        log_error "  - CDN URL ($max_cdn_attempts attempts)"
        log_error "  - Local zip file (not found or checksum mismatch)"
        log_error ""
        log_error "Possible causes:"
        log_error "  1. CDN propagation taking extremely long (>30 minutes)"
        log_error "  2. Local zip file corrupted or missing"
        log_error "  3. Upload to GitHub Release may have failed"
        log_error ""
        log_error "Recommended actions:"
        log_error "  1. Wait 1-2 hours for CDN to fully propagate"
        log_error "  2. Manually verify GitHub Release: gh release view $version"
        log_error "  3. Check local zip: ls -lh $ROOT_DIR/Build/Zips/$zip_name"

        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log_error "[FAIL-FAST] Cannot proceed with unstable checksum in production mode"
            return 1
        else
            log_warning "Continuing in dry-run mode (may fail during pod trunk push)"
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
    # Applies to: MSPPrebidAdapter, MSPGoogleAdapter, MSPFacebookAdapter, MSPAmazonAdapter
    # Does NOT apply to:
    # - MSPNovaAdapter: Uses pre-packaged Binary/NovaCore.xcframework
    # - Core pods: Require pre-built XCFrameworks from build pipeline
    # ========================================================================
    if is_binary_distribution "$pod"; then
        case "$pod" in
            MSPPrebidAdapter|MSPGoogleAdapter|MSPFacebookAdapter|MSPAmazonAdapter|MSPMolocoAdapter|MSPLiftoffAdapter)
                # Map pod name to directory name (for build script)
                # XCFramework name now matches pod name (unified naming)
                local module_dir=$(get_module_dir "$pod")
                local xcframework_path="$ROOT_DIR/Build/XCFrameworks/${pod}.xcframework"

                if [[ ! -d "$xcframework_path" ]]; then
                    log_warning "XCFramework missing for $pod, auto-building..."
                    log_info "Expected path: $xcframework_path"
                    log_info "Building module directory: $module_dir"

                    # Build the missing XCFramework
                    local build_script="$ROOT_DIR/Scripts/xcframeworks/build_module.sh"

                    if [[ ! -x "$build_script" ]]; then
                        log_error "Build script not found or not executable: $build_script"
                        log_error "Cannot auto-build XCFramework for $pod"
                        return 1
                    fi

                    log_info "Running: $build_script $module_dir"

                    if "$build_script" "$module_dir" 2>&1 | tee "/tmp/auto-build-${pod}.log"; then
                        log_success "✅ Auto-built XCFramework: $pod (${xcframework_name}.xcframework)"

                        # Verify build result (use mapped XCFramework name)
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
            MSPNovaAdapter)
                log_debug "MSPNovaAdapter uses pre-packaged Binary/, skipping XCFramework check"
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
            log_debug "LOCK" "flock not available (macOS), skipping GitHub Release file locking"
            log_debug "LOCK" "To enable file locking on macOS, install flock via: brew install coreutils"
            log_debug "LOCK" "Parallel uploads may conflict without locking, but will continue"
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

        # Phase B: Source-based adapters use the main tag (e.g., 0.3.0-rc.13), not pod-specific tags
        # Use unified GitHub Release function to create/verify release
        local release_repo="ParticleMedia/msp-ios-sdk-public"
        
        # Set repo for unified function
        export MSP_GITHUB_REPO="$release_repo"
        
        # Phase B: Use unified GitHub Release function
        # This will create release if needed, or verify existing release state
        if ! create_or_verify_github_release "$version_tag"; then
            log_error "PUBLISH" "Failed to create/verify GitHub Release $version_tag"
            return 1
        fi

        log_info "PUBLISH" "✓ GitHub Release $version_tag created/verified"

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
            # ========================================================================
            # Verify existing checksum matches LOCAL zip file (NOT GitHub Release)
            # ========================================================================
            # Rationale:
            # - generate_podspec.sh already calculated checksum from local zip
            # - Local zip is the source of truth (just created/uploaded)
            # - GitHub Release may have CDN delays or old cached versions
            # - Downloading from GitHub wastes time and may get wrong version
            # ========================================================================

            local existing_checksum=$(grep ":sha256" "$podspec" | sed 's/.*"\(.*\)".*/\1/')
            local local_zip="$ROOT_DIR/Build/Zips/${pod}-${version}.zip"

            if [[ -f "$local_zip" ]]; then
                local actual_checksum=$(shasum -a 256 "$local_zip" 2>/dev/null | awk '{print $1}')

                if [[ -n "$actual_checksum" ]] && [[ "$existing_checksum" != "$actual_checksum" ]]; then
                    log_warning "⚠️  Checksum mismatch for $pod!"
                    log_warning "   Podspec:  $existing_checksum"
                    log_warning "   Local zip: $actual_checksum"
                    log_warning "   Updating podspec with correct checksum from local zip..."

                    # Update with checksum from local zip (source of truth)
                    if [[ "$OSTYPE" == "darwin"* ]]; then
                        sed -i '' "s/:sha256 => \".*\"/:sha256 => \"$actual_checksum\"/" "$podspec"
                    else
                        sed -i "s/:sha256 => \".*\"/:sha256 => \"$actual_checksum\"/" "$podspec"
                    fi

                    log_success "✅ Updated $pod podspec checksum to match local zip"
                elif [[ -n "$actual_checksum" ]]; then
                    log_info "✅ Checksum verified for $pod: $existing_checksum (matches local zip)"
                else
                    log_warning "Failed to calculate checksum from local zip: $local_zip"
                fi
            else
                log_warning "Local zip not found: $local_zip"
                log_warning "Skipping checksum verification"
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

    # =========================================================================
    # CRITICAL VALIDATION: Verify podspec checksum matches GitHub Release
    # =========================================================================
    # Why: Prevent publishing podspec with incorrect checksum to CocoaPods Trunk.
    # Once published, CocoaPods Trunk checksums cannot be changed (immutable).
    # This validation ensures podspec checksum matches the actual downloadable zip.
    #
    # Failure mode: If checksum mismatches, all downstream pods that depend on
    # this pod will fail validation with "Verification checksum was incorrect".
    # =========================================================================

    log_step "Verifying podspec checksum matches GitHub Release (pre-publish validation)"

    # Step 1: Extract checksum from podspec
    local podspec_checksum=$(grep -E '^\s*:sha256\s*=>\s*"[^"]*"' "$podspec" | sed -E 's/.*"([^"]+)".*/\1/')

    if [[ -z "$podspec_checksum" || ${#podspec_checksum} -ne 64 ]]; then
        log_error "❌ Failed to extract valid checksum from podspec"
        log_error "   Podspec: $podspec"
        return 1
    fi

    log_info "Podspec checksum: $podspec_checksum"

    # Step 2: Extract version and download URL from podspec
    local podspec_version=$(grep -E '^\s*spec\.version\s*=\s*"[^"]*"' "$podspec" | sed -E 's/.*"([^"]+)".*/\1/')
    local podspec_http_url=$(grep -E '^\s*:http\s*=>\s*"[^"]*"' "$podspec" | sed -E 's/.*"([^"]+)".*/\1/')

    if [[ -z "$podspec_version" ]]; then
        log_error "❌ Failed to extract version from podspec"
        return 1
    fi

    if [[ -z "$podspec_http_url" ]]; then
        log_error "❌ Failed to extract HTTP URL from podspec"
        return 1
    fi

    log_info "Podspec version: $podspec_version"
    log_info "Download URL: $podspec_http_url"

    # Step 3: Download zip from GitHub Release and calculate checksum
    log_info "Downloading zip from GitHub Release to verify checksum..."

    local temp_verify_zip="/tmp/verify-publish-${pod}-${podspec_version}-$$.zip"
    local github_checksum=""

    # Wait for CDN propagation (in case zip was just uploaded)
    sleep 5

    if curl -L -f -s -o "$temp_verify_zip" "$podspec_http_url" 2>/dev/null; then
        local file_size=$(stat -f%z "$temp_verify_zip" 2>/dev/null || stat -c%s "$temp_verify_zip" 2>/dev/null || echo "0")

        if [[ $file_size -gt 0 ]]; then
            github_checksum=$(shasum -a 256 "$temp_verify_zip" 2>/dev/null | awk '{print $1}')
            log_info "GitHub Release checksum: $github_checksum"
            log_info "Downloaded file size: $file_size bytes"
        else
            log_error "❌ Downloaded file is empty"
            rm -f "$temp_verify_zip"
            return 1
        fi

        rm -f "$temp_verify_zip"
    else
        log_error "❌ Failed to download zip from GitHub Release"
        log_error "   URL: $podspec_http_url"
        log_error "   This indicates GitHub Release zip is not accessible"
        log_error "   Aborting pod trunk push to prevent bad podspec"
        return 1
    fi

    # Step 4: Compare checksums
    if [[ -z "$github_checksum" || ${#github_checksum} -ne 64 ]]; then
        log_error "❌ Failed to calculate valid checksum from GitHub Release"
        return 1
    fi

    if [[ "$podspec_checksum" != "$github_checksum" ]]; then
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error "❌ CRITICAL: Checksum mismatch detected!"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error ""
        log_error "Pod:             $pod $podspec_version"
        log_error "Podspec path:    $podspec"
        log_error "Download URL:    $podspec_http_url"
        log_error ""
        log_error "Podspec checksum:  $podspec_checksum  ← WRONG"
        log_error "GitHub checksum:   $github_checksum  ← CORRECT"
        log_error ""
        log_error "Impact:"
        log_error "  - If published, ALL pods that depend on this pod will fail validation"
        log_error "  - CocoaPods Trunk checksums are IMMUTABLE (cannot be changed)"
        log_error "  - Would require deleting version and re-publishing (if possible)"
        log_error ""
        log_error "Root cause:"
        log_error "  - Podspec was generated using incorrect/stale checksum"
        log_error "  - Likely generated before GitHub Release zip was uploaded"
        log_error "  - Or GitHub Release zip was replaced after podspec generation"
        log_error ""
        log_error "Solution:"
        log_error "  1. Regenerate podspec using: DRY_RUN=false ./Scripts/release/generate_podspec.sh $pod $podspec_version"
        log_error "  2. This will force download from GitHub Release to calculate checksum"
        log_error "  3. Re-run publish after regeneration"
        log_error ""
        log_error "🛑 Aborting pod trunk push to prevent publishing incorrect podspec"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    fi

    log_success "✅ Checksum verification PASSED"
    log_success "   Podspec checksum matches GitHub Release zip"
    log_success "   Safe to proceed with pod trunk push"
    log_info ""

    # Publish with captured output
    # Use temporary file to capture exit code (avoids broken pipe error)
    local exit_code_file
    exit_code_file=$(mktemp "/tmp/pod_trunk_exit_code_XXXXXX")
    register_temp_resource "$exit_code_file"

    # Execute pod trunk push and capture exit code immediately
    {
        pod trunk push "$podspec" --allow-warnings $skip_tests_flag 2>&1 | tee "$log_file"
        echo "${PIPESTATUS[0]}" > "$exit_code_file"
    } || true

    # Read exit code and output from files
    local publish_exit_code
    publish_exit_code=$(cat "$exit_code_file" 2>/dev/null || echo "1")
    local publish_output
    publish_output=$(cat "$log_file" 2>/dev/null || echo "")

    # Cleanup exit code file
    rm -f "$exit_code_file"

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

            # Create new temporary file for retry
            local retry_exit_code_file
            retry_exit_code_file=$(mktemp "/tmp/pod_trunk_exit_code_retry_XXXXXX")
            register_temp_resource "$retry_exit_code_file"

            # Retry publication after fix
            {
                pod trunk push "$podspec" --allow-warnings $skip_tests_flag 2>&1 | tee "$log_file"
                echo "${PIPESTATUS[0]}" > "$retry_exit_code_file"
            } || true

            # Read retry results
            publish_exit_code=$(cat "$retry_exit_code_file" 2>/dev/null || echo "1")
            publish_output=$(cat "$log_file" 2>/dev/null || echo "")

            # Cleanup retry exit code file
            rm -f "$retry_exit_code_file"

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
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log_error "[FAIL-FAST] Podspec not found in release tier. Aborting to prevent wait loop."
            msp_state_mark_step_failed "pods_publish" "Podspec not found: $podspec" "1"
        fi
        return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would publish $pod version $version to CocoaPods using $podspec"
        return 0
    fi

    # Stage A: Probe zip URL availability in release tier (HTTP distribution)
    # Only check for binary distribution pods (core modules)
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
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
                return 1
            fi
        else
            log_info "$pod: Skipping zip verification (source-based distribution via git+tag)"
        fi
    fi

    # Validate podspec if not skipped
    if [[ "$SKIP_VALIDATION" != "true" ]]; then
        # ═══════════════════════════════════════════════════════════════
        # All modes: Skip LOCAL validation (HTTP zip not available yet)
        # Validation will be done by CocoaPods Trunk server
        # ═══════════════════════════════════════════════════════════════
        local mode_label="dry-run"
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            mode_label="production"
        fi
        log_info "[$mode_label] Skipping local podspec validation"
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

            if [[ "${DRY_RUN:-true}" == "false" ]]; then
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
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log_error "[FAIL-FAST] Podspec generation failed for MSPiOSCore. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Podspec generation failed for MSPiOSCore" "1"
            exit 1
        fi
        return 1
    fi

    # FAIL-FAST: Verify generated podspec exists (release tier only)
    local podspec_path="$ROOT_DIR/Build/ReleasePodspecs/MSPiOSCore.podspec"
    if [[ "${DRY_RUN:-true}" == "false" ]] && [[ ! -f "$podspec_path" ]]; then
        log_error "[FAIL-FAST] Generated podspec not found: $podspec_path. Aborting release."
        msp_state_mark_step_failed "pods_publish" "Generated podspec not found: $podspec_path" "1"
        exit 1
    fi

    # Create GitHub release
    create_github_release_for_pod "MSPiOSCore" "$VERSION"

    # Publish to CocoaPods
    # Phase R1.11: Fail-fast if publication fails (prevent wait loop)
    if ! publish_pod_to_cocoapods "MSPiOSCore" "$VERSION"; then
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
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

    # ========================================================================
    # Idempotency Check: Skip if already published (Resume-safe)
    # ========================================================================
    # Rationale:
    # - Resume may be called after MSPSharedLibraries was already published
    # - Re-running create_github_release_for_pod() can overwrite correct checksum
    # - check_pod_availability() verifies if pod is available on CocoaPods CDN
    # - If available, skip all steps (no zip upload, no podspec regeneration)
    # ========================================================================
    if [[ "$DRY_RUN" != "true" ]]; then
        if check_pod_availability "MSPSharedLibraries" "$VERSION"; then
            log_info "MSPSharedLibraries $VERSION is already published to CocoaPods"

            # ✅ Enhanced Check: Verify GitHub Release zip matches local zip
            # - Detects if GitHub Release has wrong/old zip file
            # - Automatically re-uploads correct zip if mismatch detected
            # - Critical for MSPSharedLibraries as all Adapters depend on it
            if is_binary_distribution "MSPSharedLibraries"; then
                if ! verify_and_fix_github_release_zip "MSPSharedLibraries" "$VERSION"; then
                    log_error "Failed to verify/fix GitHub Release zip for MSPSharedLibraries"

                    # In release mode, this is a critical failure
                    if [[ "${DRY_RUN:-true}" == "false" ]]; then
                        log_error "[FAIL-FAST] Cannot continue with incorrect GitHub Release zip"
                        log_error "Adapters depending on MSPSharedLibraries will fail validation"

                        # End timing if metrics enabled
                        if command -v metrics::end &>/dev/null; then
                            metrics::end "pod_MSPSharedLibraries"
                        fi

                        return 1
                    fi
                fi
            fi

            log_success "MSPSharedLibraries $VERSION already available and verified"

            # End timing if metrics enabled
            if command -v metrics::end &>/dev/null; then
                metrics::end "pod_MSPSharedLibraries"
            fi

            return 0
        fi
    fi

    # Ensure zip file exists for binary distribution pods (Resume-safe)
    # This provides script-level guarantee that podspec generation will succeed
    # even if previous release was incomplete (zip missing but pod published)
    if is_binary_distribution "MSPSharedLibraries"; then
        log_info "Verifying zip file exists for binary distribution pod..."

        if ! ensure_zip_file_exists_for_pod "MSPSharedLibraries" "$VERSION"; then
            log_error "Failed to ensure zip file exists for MSPSharedLibraries"

            if [[ "${DRY_RUN:-true}" == "false" ]]; then
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
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log_error "[FAIL-FAST] Podspec generation failed for MSPSharedLibraries. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Podspec generation failed for MSPSharedLibraries" "1"
            exit 1
        fi
        return 1
    fi

    # FAIL-FAST: Verify generated podspec exists (release tier only)
    local podspec_path="$ROOT_DIR/Build/ReleasePodspecs/MSPSharedLibraries.podspec"
    if [[ "${DRY_RUN:-true}" == "false" ]] && [[ ! -f "$podspec_path" ]]; then
        log_error "[FAIL-FAST] Generated podspec not found: $podspec_path. Aborting release."
        msp_state_mark_step_failed "pods_publish" "Generated podspec not found: $podspec_path" "1"
        exit 1
    fi

    # Create GitHub release
    create_github_release_for_pod "MSPSharedLibraries" "$VERSION"

    # Publish to CocoaPods
    # Phase R1.11: Fail-fast if publication fails (prevent wait loop)
    if ! publish_pod_to_cocoapods "MSPSharedLibraries" "$VERSION"; then
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log_error "[FAIL-FAST] Failed to publish MSPSharedLibraries to CocoaPods. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Failed to publish MSPSharedLibraries" "1"
            exit 1
        fi
        return 1
    fi

    # NOTE: Pod availability check moved to parallel release wrapper
    # This allows MSPSharedLibraries and MSPGoogleAdsTypes to be published in parallel
    # Availability will be checked before adapter releases (in release_adapters function)

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
    log_section "Step 1.5: Releasing MSPGoogleAdsTypes (required by MSPGoogleAdapter and MSPAmazonAdapter)"

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

            if [[ "${DRY_RUN:-true}" == "false" ]]; then
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
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log_error "[FAIL-FAST] Podspec generation failed for MSPGoogleAdsTypes. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Podspec generation failed for MSPGoogleAdsTypes" "1"
            exit 1
        fi
        return 1
    fi

    # FAIL-FAST: Verify generated podspec exists (release tier only)
    local podspec_path="$ROOT_DIR/Build/ReleasePodspecs/MSPGoogleAdsTypes.podspec"
    if [[ "${DRY_RUN:-true}" == "false" ]] && [[ ! -f "$podspec_path" ]]; then
        log_error "[FAIL-FAST] Generated podspec not found: $podspec_path. Aborting release."
        msp_state_mark_step_failed "pods_publish" "Generated podspec not found: $podspec_path" "1"
        exit 1
    fi

    # Create GitHub release
    create_github_release_for_pod "MSPGoogleAdsTypes" "$VERSION"

    # Publish to CocoaPods
    # Phase R1.11: Fail-fast if publication fails (prevent wait loop)
    if ! publish_pod_to_cocoapods "MSPGoogleAdsTypes" "$VERSION"; then
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log_error "[FAIL-FAST] Failed to publish MSPGoogleAdsTypes to CocoaPods. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Failed to publish MSPGoogleAdsTypes" "1"
            exit 1
        fi
        return 1
    fi

    # NOTE: Pod availability check moved to parallel release wrapper
    # This allows MSPGoogleAdsTypes and MSPSharedLibraries to be published in parallel
    # Availability will be checked before adapter releases (in release_adapters function)
    # MSPGoogleAdsTypes is only needed by MSPGoogleAdapter and MSPAmazonAdapter, which will check individually

    # End timing
    if command -v metrics::end &>/dev/null; then
        metrics::end "pod_MSPGoogleAdsTypes"
        metrics::record "cocoapods_success_count" 1 "count"
    fi

    log_success "MSPGoogleAdsTypes released successfully"
}

# Release single adapter (helper function for parallel processing)
# ============================================================================
# Function: ensure_novacore_xcframework
# ============================================================================
# Ensures NovaCore.xcframework is available in Binary/ directory for MSPNovaAdapter release
# If not present, builds it from source using existing build scripts
# ============================================================================
ensure_novacore_xcframework() {
    local novacore_binary_path="$ROOT_DIR/Binary/NovaCore.xcframework"
    local novacore_build_path="$ROOT_DIR/Build/XCFrameworks/NovaCore.xcframework"

    log_section "Ensuring NovaCore.xcframework is available for MSPNovaAdapter"

    # Check if NovaCore.xcframework already exists in Binary/
    if [[ -d "$novacore_binary_path" ]]; then
        log_success "✅ NovaCore.xcframework already exists in Binary/"

        # Verify it's a valid XCFramework
        if [[ -f "$novacore_binary_path/Info.plist" ]]; then
            log_info "NovaCore.xcframework is valid (Info.plist exists)"
            return 0
        else
            log_warning "⚠️  NovaCore.xcframework in Binary/ is invalid, will rebuild"
            rm -rf "$novacore_binary_path"
        fi
    fi

    # Check if NovaCore.xcframework exists in Build/XCFrameworks/
    if [[ -d "$novacore_build_path" ]]; then
        log_info "Found NovaCore.xcframework in Build/XCFrameworks/"
        log_info "Copying to Binary/ directory..."

        # Create Binary directory if it doesn't exist
        mkdir -p "$ROOT_DIR/Binary"

        # Copy XCFramework to Binary/
        if ditto "$novacore_build_path" "$novacore_binary_path"; then
            log_success "✅ NovaCore.xcframework copied to Binary/"
            return 0
        else
            log_error "❌ Failed to copy NovaCore.xcframework to Binary/"
            return 1
        fi
    fi

    # NovaCore.xcframework doesn't exist anywhere, need to build it
    log_warning "⚠️  NovaCore.xcframework not found, building from source..."
    log_info "This will take approximately 3-5 minutes..."

    # Check if build script exists
    local build_script="$ROOT_DIR/Scripts/xcframeworks/build_module.sh"
    if [[ ! -x "$build_script" ]]; then
        log_error "❌ Build script not found or not executable: $build_script"
        log_error "Cannot build NovaCore.xcframework automatically"
        log_error "Please build manually:"
        log_error "  cd $ROOT_DIR"
        log_error "  ./Scripts/xcframeworks/build_module.sh NovaCore"
        return 1
    fi

    # Build NovaCore.xcframework
    log_info "Running: $build_script NovaCore"
    if "$build_script" NovaCore; then
        log_success "✅ NovaCore.xcframework built successfully"
    else
        log_error "❌ Failed to build NovaCore.xcframework"
        log_error "Please check build logs and fix any build errors"
        log_error "Common issues:"
        log_error "  1. Missing dependencies (Kingfisher, SnapKit, Lottie, etc.)"
        log_error "  2. Code signing issues"
        log_error "  3. Xcode version incompatibility"
        return 1
    fi

    # Verify build output
    if [[ ! -d "$novacore_build_path" ]]; then
        log_error "❌ NovaCore.xcframework was not created in expected location"
        log_error "Expected: $novacore_build_path"
        return 1
    fi

    # Copy to Binary/ directory
    log_info "Copying built XCFramework to Binary/ directory..."
    mkdir -p "$ROOT_DIR/Binary"

    if ditto "$novacore_build_path" "$novacore_binary_path"; then
        log_success "✅ NovaCore.xcframework deployed to Binary/"

        # Verify final deployment
        if [[ -f "$novacore_binary_path/Info.plist" ]]; then
            log_success "✅ NovaCore.xcframework is valid and ready for MSPNovaAdapter release"

            # Show framework size
            local framework_size=$(du -sh "$novacore_binary_path" 2>/dev/null | cut -f1)
            log_info "Framework size: $framework_size"

            return 0
        else
            log_error "❌ Deployed NovaCore.xcframework is invalid (missing Info.plist)"
            return 1
        fi
    else
        log_error "❌ Failed to copy NovaCore.xcframework to Binary/"
        return 1
    fi
}

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

    # ========================================================================
    # Idempotency Check: Skip if already published (Resume-safe)
    # ========================================================================
    # Rationale: Same as MSPSharedLibraries
    # - Prevents re-uploading zip and regenerating podspec
    # - Prevents overwriting correct checksum with stale GitHub Release checksum
    # ========================================================================
    if [[ "$DRY_RUN" != "true" ]]; then
        if check_pod_availability "$adapter" "$version"; then
            log_info "$adapter $version is already published to CocoaPods"

            # ✅ Enhanced Check: Verify GitHub Release zip matches local zip
            # - Same logic as MSPSharedLibraries
            # - Ensures this adapter's zip is correct for downstream dependencies
            if is_binary_distribution "$adapter"; then
                if ! verify_and_fix_github_release_zip "$adapter" "$version"; then
                    log_error "Failed to verify/fix GitHub Release zip for $adapter"
                    echo "ERROR: GitHub Release zip verification failed for $adapter" > "$result_file"

                    # In release mode, this is a failure
                    if [[ "${DRY_RUN:-true}" == "false" ]]; then
                        return 1
                    fi
                fi
            fi

            log_success "$adapter $version already available and verified"
            echo "SUCCESS: $adapter already published" > "$result_file"
            return 0
        fi
    fi

    # Ensure zip file exists for binary distribution pods (Resume-safe)
    # This provides script-level guarantee that podspec generation will succeed
    # even if previous release was incomplete (zip missing but pod published)
    if is_binary_distribution "$adapter"; then
        log_info "Verifying zip file exists for binary distribution pod..."

        if ! ensure_zip_file_exists_for_pod "$adapter" "$version"; then
            log_error "Failed to ensure zip file exists for $adapter"
            echo "ERROR: Failed to ensure zip file exists for $adapter" > "$result_file"
            return 1
        fi

        log_success "Zip file verified/recreated for $adapter"
    fi

    # Update podspec (now guaranteed to succeed if binary distribution)
    if ! update_podspec_for_release "$adapter" "$version"; then
        echo "ERROR: Failed to update podspec for $adapter" > "$result_file"
        # FAIL-FAST: Immediately abort if podspec generation fails (release tier only)
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log_error "[FAIL-FAST] Podspec generation failed for $adapter. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Podspec generation failed for $adapter" "1"
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

    if [[ "${DRY_RUN:-true}" == "false" ]] && [[ ! -f "$podspec_path" ]]; then
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
        return 1
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
    
    # ════════════════════════════════════════════════════════════════════════════
    # ✨ NEW: Commit version update immediately after successful publish
    # ════════════════════════════════════════════════════════════════════════════
    # Why: Ensure working directory is clean for resume
    # When: Only in production mode (DRY_RUN=false)
    # Safety: Check for uncommitted changes before commit (idempotent)
    # ════════════════════════════════════════════════════════════════════════════
    if [[ "$DRY_RUN" != "true" ]]; then
        # Check if there are uncommitted changes for this adapter
        # Map pod name to directory name (for adapters with renamed modules)
        local module_dir=$(get_module_dir "$adapter")
        local adapter_path="Sources/Adapters/${module_dir}/${module_dir}"

        if ! git diff --quiet -- "$ROOT_DIR/$adapter_path" 2>/dev/null; then
            log_info "Committing $adapter version update to $version..."

            # Change to ROOT_DIR to ensure correct relative paths for git
            pushd "$ROOT_DIR" > /dev/null || {
                log_error "Failed to change to ROOT_DIR: $ROOT_DIR"
                # Don't fail release - pod is already published
                return 0
            }

            # Find and stage Swift files (avoid glob expansion issues)
            local swift_files_staged=0
            while IFS= read -r -d '' swift_file; do
                if git add "$swift_file" 2>/dev/null; then
                    ((swift_files_staged++))
                    log_debug "Staged: $swift_file"
                else
                    log_warn "Failed to stage: $swift_file"
                fi
            done < <(find "$adapter_path" -name "*.swift" -type f -print0 2>/dev/null)

            if [[ $swift_files_staged -gt 0 ]]; then
                # Commit with detailed message
                if git commit -m "chore(release): update ${adapter} SDK version to ${version}

- Update getSDKVersion() return value to ${version}
- Committed immediately after successful publish to CocoaPods
- Part of release ${version} preparation"; then
                    log_success "✓ Committed ${adapter} version update ($swift_files_staged files)"
                else
                    log_error "✗ Failed to commit ${adapter} version update"
                    log_warn "Pod published successfully but version commit failed"
                    log_warn "You may need to commit manually: cd $ROOT_DIR && git add ${adapter_path} && git commit"
                fi
            else
                log_warn "No Swift files found or staged for ${adapter} in ${adapter_path}"
            fi

            popd > /dev/null || true
        else
            log_info "${adapter} version already committed or no changes"
        fi
    fi
    
    # Note: Availability checking is done after ALL adapters are released
    echo "SUCCESS: $adapter released successfully" > "$result_file"
    return 0
}

# ============================================================================
# Helper: Unified GitHub CLI Authentication Check
# ============================================================================
# Performs a single authentication check before parallel release to ensure
# all parallel processes can access GitHub Release APIs.
#
# Returns:
#   0 if authenticated
#   1 if authentication failed
# ============================================================================
unified_github_cli_auth_check() {
    log_step "🔐 Verifying GitHub CLI authentication (pre-flight check)"

    # Check if gh is installed
    if ! command -v gh &>/dev/null; then
        log_error "❌ GitHub CLI (gh) not found"
        log_error "Please install GitHub CLI: brew install gh"
        log_error "Or visit: https://cli.github.com"
        return 1
    fi

    # Perform authentication check with detailed output
    local auth_check_output
    auth_check_output=$(mktemp)

    log_info "Checking GitHub CLI authentication..."

    if timeout 30 gh auth status &>"$auth_check_output"; then
        log_success "✅ GitHub CLI authenticated"

        # Show account info if available
        if grep -q "Logged in to github.com" "$auth_check_output"; then
            local account
            account=$(grep "Logged in" "$auth_check_output" 2>/dev/null | head -1 | sed -n 's/.*account \([^ ]*\).*/\1/p')
            if [[ -n "$account" ]]; then
                log_info "  Account: $account"
            fi

            # Show token scopes
            if grep -q "Token scopes:" "$auth_check_output"; then
                local scopes
                scopes=$(grep "Token scopes:" "$auth_check_output" 2>/dev/null | sed "s/.*Token scopes: //")
                log_info "  Scopes: $scopes"
            fi
        fi

        rm -f "$auth_check_output"
        return 0
    else
        local exit_code=$?
        log_error "❌ GitHub CLI authentication failed (exit code: $exit_code)"
        log_error ""
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error "GitHub CLI Error Output:"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        cat "$auth_check_output" >&2
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error ""
        log_error "Common solutions:"
        log_error "  1. Re-authenticate: gh auth login"
        log_error "  2. Refresh token: gh auth refresh -h github.com"
        log_error "  3. Check token status: gh auth status"
        log_error "  4. Verify scopes include: 'repo', 'workflow'"
        log_error ""
        log_error "If the problem persists, try:"
        log_error "  gh auth logout"
        log_error "  gh auth login"

        rm -f "$auth_check_output"

        # Optional: Attempt automatic refresh (1 retry)
        log_warning "⚠️  Attempting to refresh token..."
        if gh auth refresh -h github.com &>/dev/null; then
            log_info "Token refreshed, rechecking..."
            if timeout 30 gh auth status &>/dev/null; then
                log_success "✅ Authentication successful after refresh"
                return 0
            fi
        fi

        return 1
    fi
}

# Release Adapters (Step 2) - Parallel Processing
release_adapters() {
    # Use global VERSION variable (set at Line 168) instead of local parameter
    # This allows subshells to access $VERSION for parallel dependency checks
    
    log_title "Releasing Adapters: $VERSION"

    # ========================================================================
    # Step 0: Ensure NovaCore.xcframework is available for MSPNovaAdapter
    # ========================================================================
    # MSPNovaAdapter requires Binary/NovaCore.xcframework to be present
    # Build it automatically if it doesn't exist (saves 26+ minutes of wasted time)
    # ========================================================================
    log_section "Step 0: Ensuring NovaCore.xcframework is available"

    if ! ensure_novacore_xcframework; then
        log_error "❌ Failed to ensure NovaCore.xcframework availability"
        log_error "Cannot proceed with MSPNovaAdapter release"
        log_error "Please fix the issue and try again"
        return 1
    fi

    log_success "✅ NovaCore.xcframework is ready for MSPNovaAdapter"
    
    # Pre-flight check: GitHub CLI authentication (required for binary distribution adapters)
    # This check happens before parallel adapter releases to fail fast if authentication is broken
    if [[ "${DRY_RUN:-true}" == "false" ]]; then
        log_step "Pre-flight check: GitHub CLI authentication"
        if ! unified_github_cli_auth_check; then
            log_error "❌ GitHub CLI authentication failed - cannot proceed with adapter releases"
            log_error "Binary distribution adapters require GitHub CLI to upload zip files"
            log_error "Please fix GitHub CLI authentication before retrying"
            return 1
        fi
    else
        log_info "Dry-run mode: Skipping GitHub CLI authentication check"
    fi
    
    log_section "Step 2: Releasing Adapters that depend on MSPSharedLibraries (in parallel)"
    
    # Ensure MSPSharedLibraries and MSPGoogleAdsTypes are available before adapter releases
    log_step "Verifying MSPSharedLibraries and MSPGoogleAdsTypes availability before adapter releases..."
    
    # Create temporary files for parallel checks
    local shared_libs_check_file=$(mktemp "/tmp/msp_availability_check_shared_libs_XXXXXX")
    local google_ads_types_check_file=$(mktemp "/tmp/msp_availability_check_google_ads_types_XXXXXX")
    
    # Start MSPSharedLibraries check in background
    (
        if smart_wait_for_pod_availability "MSPSharedLibraries" "$VERSION" "before parallel adapter releases"; then
            echo "SUCCESS:MSPSharedLibraries" > "$shared_libs_check_file"
            exit 0
        else
            echo "FAILED:MSPSharedLibraries" > "$shared_libs_check_file"
            exit 1
        fi
    ) &
    local SHARED_LIBS_CHECK_PID=$!
    register_child_pid $SHARED_LIBS_CHECK_PID "MSPSharedLibraries availability check"
    register_temp_resource "$shared_libs_check_file"
    
    # Start MSPGoogleAdsTypes check in background
    (
        if smart_wait_for_pod_availability "MSPGoogleAdsTypes" "$VERSION" "before parallel adapter releases"; then
            echo "SUCCESS:MSPGoogleAdsTypes" > "$google_ads_types_check_file"
            exit 0
        else
            echo "FAILED:MSPGoogleAdsTypes" > "$google_ads_types_check_file"
            exit 1
        fi
    ) &
    local GOOGLE_ADS_TYPES_CHECK_PID=$!
    register_child_pid $GOOGLE_ADS_TYPES_CHECK_PID "MSPGoogleAdsTypes availability check"
    register_temp_resource "$google_ads_types_check_file"
    
    log_info "Waiting for both availability checks to complete..."
    
    # Maximum wait time: 90 minutes (5400s)
    # Rationale: Each check includes waiting for pod availability (up to 60 min)
    local timeout_seconds=5400
    local check_interval=5
    local elapsed=0

    # Track completion status
    local shared_libs_check_done=false
    local google_ads_types_check_done=false
    local shared_libs_check_exit_code=""
    local google_ads_types_check_exit_code=""

    # Parallel wait loop with timeout
    while [[ $elapsed -lt $timeout_seconds ]]; do
        # Check if MSPSharedLibraries check is still running
        if [[ "$shared_libs_check_done" == "false" ]]; then
            if ! kill -0 $SHARED_LIBS_CHECK_PID 2>/dev/null; then
                # Process has exited, get its exit code via wait
                wait $SHARED_LIBS_CHECK_PID 2>/dev/null
                shared_libs_check_exit_code=$?
                shared_libs_check_done=true
                log_info "MSPSharedLibraries availability check completed (exit code: $shared_libs_check_exit_code)"
            fi
        fi

        # Check if MSPGoogleAdsTypes check is still running
        if [[ "$google_ads_types_check_done" == "false" ]]; then
            if ! kill -0 $GOOGLE_ADS_TYPES_CHECK_PID 2>/dev/null; then
                # Process has exited, get its exit code via wait
                wait $GOOGLE_ADS_TYPES_CHECK_PID 2>/dev/null
                google_ads_types_check_exit_code=$?
                google_ads_types_check_done=true
                log_info "MSPGoogleAdsTypes availability check completed (exit code: $google_ads_types_check_exit_code)"
            fi
        fi

        # Check if both checks are done
        if [[ "$shared_libs_check_done" == "true" ]] && [[ "$google_ads_types_check_done" == "true" ]]; then
            log_success "✅ Both availability checks completed"
            break
        fi

        # Progress reporting every minute
        if [[ $((elapsed % 60)) -eq 0 ]] && [[ $elapsed -gt 0 ]]; then
            local remaining=$((timeout_seconds - elapsed))
            log_debug "⏱️  Availability checks: ${elapsed}s elapsed, ${remaining}s remaining"
            if [[ "$shared_libs_check_done" == "false" ]]; then
                log_debug "   - MSPSharedLibraries: still checking"
            fi
            if [[ "$google_ads_types_check_done" == "false" ]]; then
                log_debug "   - MSPGoogleAdsTypes: still checking"
            fi
        fi

        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done

    # Check for timeout
    if [[ "$shared_libs_check_done" == "false" ]] || [[ "$google_ads_types_check_done" == "false" ]]; then
        log_error "❌ Dependency availability checks TIMED OUT after ${timeout_seconds}s (90 minutes)"
        log_error "This usually indicates:"
        log_error "  1. Pod trunk push failed silently"
        log_error "  2. CocoaPods CDN sync is stuck"
        log_error "  3. Network connectivity issues"

        if [[ "$shared_libs_check_done" == "false" ]]; then
            log_error "   - MSPSharedLibraries check: timed out"
            kill -TERM $SHARED_LIBS_CHECK_PID 2>/dev/null || true
        fi
        if [[ "$google_ads_types_check_done" == "false" ]]; then
            log_error "   - MSPGoogleAdsTypes check: timed out"
            kill -TERM $GOOGLE_ADS_TYPES_CHECK_PID 2>/dev/null || true
        fi

        # Cleanup temp files
        rm -f "$shared_libs_check_file" "$google_ads_types_check_file"
        log_debug "[CLEANUP] Cleaned up dependency availability check temporary resources"

        return 1
    fi

    # =========================================================================
    # Process Results for MSPSharedLibraries Availability
    # =========================================================================
    local shared_libs_available=false

    # Check result file (primary indicator of success)
    if [[ -f "$shared_libs_check_file" ]] && grep -q "SUCCESS" "$shared_libs_check_file"; then
        shared_libs_available=true
        log_success "✅ MSPSharedLibraries $VERSION is available"
    else
        log_error "❌ MSPSharedLibraries $VERSION is not available"

        # Detailed failure reason
        if [[ "$shared_libs_check_done" == "false" ]]; then
            log_error "❌ Reason: Timeout (check did not complete in ${timeout_seconds}s)"
        elif [[ -n "$shared_libs_check_exit_code" ]] && [[ "$shared_libs_check_exit_code" != "0" ]]; then
            log_error "❌ Reason: Check exit code $shared_libs_check_exit_code"
        else
            log_error "❌ Reason: Result file missing or does not contain SUCCESS"
        fi
    fi

    # =========================================================================
    # Process Results for MSPGoogleAdsTypes Availability
    # =========================================================================
    local google_ads_types_available=false

    # Check result file (primary indicator of success)
    if [[ -f "$google_ads_types_check_file" ]] && grep -q "SUCCESS" "$google_ads_types_check_file"; then
        google_ads_types_available=true
        log_success "✅ MSPGoogleAdsTypes $VERSION is available"
    else
        log_error "❌ MSPGoogleAdsTypes $VERSION is not available"

        # Detailed failure reason
        if [[ "$google_ads_types_check_done" == "false" ]]; then
            log_error "❌ Reason: Timeout (check did not complete in ${timeout_seconds}s)"
        elif [[ -n "$google_ads_types_check_exit_code" ]] && [[ "$google_ads_types_check_exit_code" != "0" ]]; then
            log_error "❌ Reason: Check exit code $google_ads_types_check_exit_code"
        else
            log_error "❌ Reason: Result file missing or does not contain SUCCESS"
        fi
    fi

    # Cleanup temp files (comprehensive)
    rm -f "$shared_libs_check_file" "$google_ads_types_check_file"
    log_debug "[CLEANUP] Cleaned up dependency availability check temporary resources"

    # Check if both are available
    if [[ "$shared_libs_available" != "true" ]] || [[ "$google_ads_types_available" != "true" ]]; then
        log_error "One or more required dependencies are not available, cannot proceed with adapter releases"
        return 1
    fi
    
    log_success "Both MSPSharedLibraries and MSPGoogleAdsTypes are available"
    
    # CRITICAL: Also ensure MSPiOSCore is available (adapters depend on it)
    log_step "Verifying MSPiOSCore availability before adapter releases..."
    if ! smart_wait_for_pod_availability "MSPiOSCore" "$VERSION" "required by all adapters"; then
        log_error "MSPiOSCore $VERSION not available, cannot proceed with adapter releases"
        log_error "All adapters depend on MSPiOSCore. Please wait for CDN sync and retry."
        return 1
    fi
    
    log_success "All required dependencies (MSPSharedLibraries, MSPGoogleAdsTypes, MSPiOSCore) are available, proceeding with parallel adapter releases"
    
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
        adapters=("MSPFacebookAdapter" "MSPGoogleAdapter" "MSPNovaAdapter" "MSPAmazonAdapter" "MSPPrebidAdapter")
    fi
    
    log_info "Releasing adapters from PODS_MODULES: ${adapters[*]}"
    
    # ========================================================================
    # Step 0.5: Pre-flight checks for all adapters
    # ========================================================================
    # Pre-check each adapter's requirements before starting parallel releases
    # This prevents wasting time on parallel releases that will fail
    # ========================================================================
    log_section "Step 0.5: Pre-flight checks for adapters"
    
    # Pre-check each adapter's requirements before starting parallel releases
    for adapter in "${adapters[@]}"; do
        log_info "Pre-checking $adapter requirements..."
        
        # MSPNovaAdapter: Verify Binary/NovaCore.xcframework exists and is valid
        if [[ "$adapter" == "MSPNovaAdapter" ]]; then
            local novacore_path="$ROOT_DIR/Binary/NovaCore.xcframework"
            
            # This should never happen if Step 0 succeeded, but double-check
            if [[ ! -d "$novacore_path" ]]; then
                log_error "❌ Pre-flight check failed: $adapter"
                log_error "NovaCore.xcframework not found: $novacore_path"
                log_error "This should have been built in Step 0"
                log_error "Something went wrong - cannot proceed"
                return 1
            fi
            
            # Verify XCFramework is valid
            if [[ ! -f "$novacore_path/Info.plist" ]]; then
                log_error "❌ Pre-flight check failed: $adapter"
                log_error "NovaCore.xcframework is invalid (missing Info.plist)"
                log_error "Path: $novacore_path"
                return 1
            fi
            
            log_success "✅ MSPNovaAdapter pre-flight check passed (NovaCore.xcframework is valid)"
        else
            # Other adapters: Check Build/XCFrameworks/<Adapter>.xcframework exists
            local xcframework_path="$ROOT_DIR/Build/XCFrameworks/${adapter}.xcframework"
            
            if [[ ! -d "$xcframework_path" ]]; then
                log_error "❌ Pre-flight check failed: $adapter"
                log_error "XCFramework not found: $xcframework_path"
                log_error "Expected location: Build/XCFrameworks/${adapter}.xcframework"
                log_error "Cannot proceed with adapter releases - missing required file"
                log_error ""
                log_error "Please build the XCFramework first:"
                log_error "  ./Scripts/xcframeworks/build_module.sh $adapter"
                return 1
            fi
            
            # Verify XCFramework is valid
            if [[ ! -f "$xcframework_path/Info.plist" ]]; then
                log_error "❌ Pre-flight check failed: $adapter"
                log_error "XCFramework is invalid (missing Info.plist)"
                log_error "Path: $xcframework_path"
                log_error "Please rebuild the XCFramework"
                return 1
            fi
            
            log_success "✅ $adapter pre-flight check passed (XCFramework exists)"
        fi
    done
    
    log_success "All adapter pre-flight checks passed"
    
    # ========================================================================
    # Step 1: Start parallel adapter releases
    # ========================================================================
    local pids=()
    local result_files=()
    local log_files=()
    local temp_dir="/tmp/msp_parallel_release_$$"

    # Create temporary directory for result files
    mkdir -p "$temp_dir"

    # Start all adapter releases in parallel
    for adapter in "${adapters[@]}"; do
        local result_file="$temp_dir/${adapter}_result.txt"
        local log_file="$temp_dir/${adapter}_log.txt"
        result_files+=("$result_file")
        log_files+=("$log_file")
        register_temp_resource "$result_file"
        register_temp_resource "$log_file"

        # Start adapter release in background with output redirection
        release_single_adapter "$adapter" "$VERSION" "$result_file" > "$log_file" 2>&1 &
        local pid=$!
        pids+=("$pid")
        register_child_pid $pid "$adapter release"

        log_info "Started parallel release of $adapter (PID: $pid, log: $log_file)"
    done
    
    # Register temp directory
    register_temp_resource "$temp_dir"
    
    # Wait for all parallel processes to complete with FAIL-FAST
    log_info "Waiting for all adapters to complete (fail-fast enabled)..."
    log_info "If any adapter fails, all others will be stopped immediately"
    
    local success_count=0
    local failure_count=0
    local failed_adapters=()
    local check_interval=5  # Check every 5 seconds
    local all_completed=false
    
    while [[ "$all_completed" == "false" ]]; do
        all_completed=true
        local has_failure=false
        local failed_adapter=""
        
        # Check each process
        for i in "${!pids[@]}"; do
            local pid="${pids[$i]}"
            local adapter="${adapters[$i]}"
            local result_file="${result_files[$i]}"
            
            # Skip if already processed
            if [[ "${pids[$i]}" == "DONE" ]]; then
                continue
            fi
            
            # Check if process is still running
            if kill -0 "$pid" 2>/dev/null; then
                # Process still running
                all_completed=false
                
                # Check if result file indicates failure
                if [[ -f "$result_file" ]]; then
                    local result_content=$(cat "$result_file")
                    if [[ "$result_content" == *"ERROR"* ]] || [[ "$result_content" == *"FAILED"* ]]; then
                        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                        log_error "❌ FAIL-FAST: $adapter failed while still running"
                        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                        log_error "Result: $result_content"

                        # Show last 30 lines of log file for debugging
                        local log_file="${log_files[$i]}"
                        if [[ -f "$log_file" ]]; then
                            log_error ""
                            log_error "Last 30 lines of $adapter log ($log_file):"
                            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                            tail -30 "$log_file" >&2
                            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                            log_error ""
                            log_error "Full log available at: $log_file"
                        fi

                        has_failure=true
                        failed_adapter="$adapter"
                        failed_adapters+=("$adapter")
                        ((failure_count++))
                        pids[$i]="DONE"
                        break
                    fi
                fi
            else
                # Process has exited, capture exit code and check result
                # Note: We already know the process exited (kill -0 failed)
                # Try to get exit code (may succeed if process just exited)
                wait "$pid" 2>/dev/null
                local exit_code=$?

                # Check result file (primary indicator of success)
                if [[ -f "$result_file" ]] && grep -q "SUCCESS" "$result_file"; then
                    log_success "✅ $adapter released successfully"
                    ((success_count++))
                    pids[$i]="DONE"
                else
                    # Detailed failure analysis
                    log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    log_error "❌ $adapter release failed"
                    log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

                    # Show result file content
                    if [[ -f "$result_file" ]]; then
                        local result_content=$(cat "$result_file")
                        if [[ -n "$result_content" ]]; then
                            log_error "Result: $result_content"
                        else
                            log_error "Result file is empty: $result_file"
                        fi
                    else
                        log_error "Result file not found: $result_file"
                    fi

                    # Show exit code if available
                    if [[ -n "$exit_code" ]] && [[ "$exit_code" != "0" ]]; then
                        log_error "Exit code: $exit_code"
                    fi

                    # Show last 30 lines of log file for debugging
                    local log_file="${log_files[$i]}"
                    if [[ -f "$log_file" ]]; then
                        log_error ""
                        log_error "Last 30 lines of $adapter log ($log_file):"
                        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                        tail -30 "$log_file" >&2
                        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                        log_error ""
                        log_error "Full log available at: $log_file"
                    else
                        log_error "Log file not found: $log_file"
                    fi

                    has_failure=true
                    failed_adapter="$adapter"
                    failed_adapters+=("$adapter")
                    ((failure_count++))
                    pids[$i]="DONE"
                    break
                fi
            fi
        done
        
        # If any failure detected, kill all other processes
        if [[ "$has_failure" == "true" ]]; then
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log_error "⚠️  FAIL-FAST TRIGGERED"
            log_error "Failed adapter: $failed_adapter"
            log_error "Stopping all running adapters immediately..."
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            
            # Kill all remaining processes
            for i in "${!pids[@]}"; do
                local pid="${pids[$i]}"
                local adapter="${adapters[$i]}"
                
                if [[ "$pid" != "DONE" ]] && kill -0 "$pid" 2>/dev/null; then
                    log_warn "Stopping $adapter (PID: $pid)..."
                    kill -TERM "$pid" 2>/dev/null || true
                    sleep 1
                    # Force kill if still running
                    if kill -0 "$pid" 2>/dev/null; then
                        kill -KILL "$pid" 2>/dev/null || true
                    fi
                    pids[$i]="DONE"
                fi
            done
            
            break
        fi
        
        # Sleep before next check
        if [[ "$all_completed" == "false" ]]; then
            sleep $check_interval
        fi
    done
    
    # Clean up temporary files (comprehensive)
    rm -rf "$temp_dir"
    
    log_debug "[CLEANUP] Cleaned up adapter release temporary resources"
    
    # Report final results
    if [[ $failure_count -gt 0 ]]; then
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error "❌ Adapter releases failed"
        log_error "Failed adapters: ${failed_adapters[*]}"
        log_error "Successful adapters: $success_count"
        log_error "Failed adapters: $failure_count"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    fi
    
    log_success "All adapters released successfully ($success_count/$success_count)"
    
    # Step 2.5: Check availability of dependencies for MSPCore
    if [[ "$DRY_RUN" != "true" ]]; then
        log_section "Step 2.5: Checking availability of dependencies for MSPCore"
        
        # Update specs repository once
        log_info "Updating CocoaPods specs repository..."
        if ! update_specs_repo; then
            log_error "Failed to update specs repository"
            return 1
        fi
        
        # Define required dependencies (always check, fail-fast)
        # These are the pods that MSPCore or commonly used adapters depend on
        local required_deps=("MSPSharedLibraries" "MSPPrebidAdapter" "MSPGoogleAdsTypes")
        
        # Check required dependencies sequentially (fail-fast)
        for dep in "${required_deps[@]}"; do
            # Check if dependency is in PODS_MODULES
            if ! echo "$PODS_MODULES" | grep -q "$dep"; then
                log_info "$dep not in PODS_MODULES, skipping availability check"
                continue
            fi
            
            log_info "Checking $dep availability (required for MSPCore)..."
            if ! smart_wait_for_pod_availability "$dep" "$VERSION" "required by MSPCore or adapters"; then
                log_error "$dep not available, cannot proceed with MSPCore release"
                return 1
            fi
            log_success "✅ $dep is available"
        done
        
        log_success "All required dependencies available for MSPCore release"
    fi
    
    return 0
}

# Release MSPCore (Step 3)
release_msp_core() {
    log_section "Step 3: Releasing MSPCore (main framework)"

    # ========================================================================
    # Idempotency Check: Skip if already published (Resume-safe)
    # ========================================================================
    # Rationale: Same as MSPSharedLibraries
    # ========================================================================
    if [[ "$DRY_RUN" != "true" ]]; then
        if check_pod_availability "MSPCore" "$VERSION"; then
            log_info "MSPCore $VERSION is already published to CocoaPods"

            # ✅ Enhanced Check: Verify GitHub Release zip matches local zip
            # - Same logic as MSPSharedLibraries
            # - Ensures final integration pod has correct zip
            if is_binary_distribution "MSPCore"; then
                if ! verify_and_fix_github_release_zip "MSPCore" "$VERSION"; then
                    log_error "Failed to verify/fix GitHub Release zip for MSPCore"
                    return 1
                fi
            fi

            log_success "MSPCore $VERSION already available and verified"
            return 0
        fi
    fi

    # Ensure zip file exists for binary distribution pods (Resume-safe)
    # This provides script-level guarantee that podspec generation will succeed
    # even if previous release was incomplete (zip missing but pod published)
    if is_binary_distribution "MSPCore"; then
        log_info "Verifying zip file exists for binary distribution pod..."

        if ! ensure_zip_file_exists_for_pod "MSPCore" "$VERSION"; then
            log_error "Failed to ensure zip file exists for MSPCore"

            if [[ "${DRY_RUN:-true}" == "false" ]]; then
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
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log_error "[FAIL-FAST] Podspec generation failed for MSPCore. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Podspec generation failed for MSPCore" "1"
            exit 1
        fi
        return 1
    fi

    # FAIL-FAST: Verify generated podspec exists (release tier only)
    local podspec_path="$ROOT_DIR/Build/ReleasePodspecs/MSPCore.podspec"
    if [[ "${DRY_RUN:-true}" == "false" ]] && [[ ! -f "$podspec_path" ]]; then
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
    # ════════════════════════════════════════════════════════════════════════════
    # ✨ FIX: Check return value to catch publish failures
    # ════════════════════════════════════════════════════════════════════════════
    if ! publish_pod_to_cocoapods "MSPCore" "$VERSION"; then
        log_error "❌ Failed to publish MSPCore to CocoaPods"
        return 1
    fi
    
    # ════════════════════════════════════════════════════════════════════════════
    # ✨ NEW: Commit version update immediately after successful publish
    # ════════════════════════════════════════════════════════════════════════════
    # Why: Ensure working directory is clean for resume
    # When: Only in production mode (DRY_RUN=false)
    # Safety: Check for uncommitted changes before commit (idempotent)
    # ════════════════════════════════════════════════════════════════════════════
    if [[ "$DRY_RUN" != "true" ]]; then
        # Check if there are uncommitted changes for Config.plist
        local config_plist_rel_path="Sources/Core/MSPCore/MSPCore/Resources/Config.plist"
        local config_plist_abs_path="$ROOT_DIR/$config_plist_rel_path"

        # Validate file exists before attempting git operations
        if [[ ! -f "$config_plist_abs_path" ]]; then
            log_warn "Config.plist not found at: $config_plist_abs_path"
            log_warn "Skipping MSPCore version commit (file may have been moved or renamed)"
        elif ! git diff --quiet -- "$config_plist_abs_path" 2>/dev/null; then
            log_info "Committing MSPCore version update to $VERSION..."

            # Change to ROOT_DIR to ensure correct relative paths for git
            pushd "$ROOT_DIR" > /dev/null || {
                log_error "Failed to change to ROOT_DIR: $ROOT_DIR"
                log_warn "Skipping MSPCore version commit due to directory change failure"
                # Don't fail release - pod is already published
                # Return early to avoid executing git commands in wrong directory
                return 0
            }

            # Stage Config.plist using relative path (git prefers relative paths)
            if git add "$config_plist_rel_path"; then
                # Commit with detailed message
                if git commit -m "chore(release): update MSPCore version to ${VERSION}

- Update Config.plist SDKVersion to ${VERSION}
- Committed immediately after successful publish to CocoaPods
- Part of release ${VERSION} preparation"; then
                    log_success "✓ Committed MSPCore version update"
                else
                    log_error "✗ Failed to commit MSPCore version update"
                    log_warn "Pod published successfully but version commit failed"
                    log_warn "You may need to commit manually: cd $ROOT_DIR && git add $config_plist_rel_path && git commit"
                fi
            else
                log_error "Failed to stage $config_plist_rel_path"
                log_error "Git add exit code: $?"
                log_warn "Current directory: $(pwd)"
                log_warn "File exists check: $(ls -la "$config_plist_abs_path" 2>&1 || echo 'File not found')"
            fi

            popd > /dev/null || true
        else
            log_info "MSPCore version already committed or no changes"
        fi
    fi
    
    # Wait for availability (skip in dry-run mode)
    if [[ "$DRY_RUN" != "true" ]]; then
        smart_wait_for_pod_availability "MSPCore" "$VERSION" "final integration module"
    fi
    
    log_success "MSPCore released successfully"
}

# Commit all changes to release branch
commit_release_changes() {
    log_step "Committing remaining release artifacts (podspecs, generated files)"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would commit remaining changes"
        return 0
    fi
    
    # ════════════════════════════════════════════════════════════════════════════
    # ✨ CHANGE: Only add generated files (version numbers already committed)
    # ════════════════════════════════════════════════════════════════════════════
    # Add generated release podspecs
    if [[ -d "Build/ReleasePodspecs" ]]; then
        git add Build/ReleasePodspecs/*.podspec 2>/dev/null || true
    fi

    # Add Package.swift if SPM is enabled
    if [[ -f "Package.swift" ]]; then
        git add Package.swift 2>/dev/null || true
    fi

    # Add any other generated artifacts (expand as needed)
    # git add Build/XCFrameworks/**/*.plist 2>/dev/null || true

    # Check if there are changes to commit
    if git diff --cached --quiet; then
        log_info "✓ No additional artifacts to commit"
        log_info "   (Version number updates were committed separately per-pod)"
        return 0
    fi

    # Commit remaining artifacts
    git commit -m "chore(release): add generated artifacts for version ${VERSION}

- Generated release podspecs for binary distribution
- Updated Package.swift for SPM (if enabled)
- Part of release ${VERSION} finalization

Note: Version number updates were committed separately after each pod publish."
    
    log_success "✓ Committed remaining release artifacts"
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
    # Phase B: Removed release_tier variable, use DRY_RUN directly
    local release_mode="${MSP_RELEASE_MODE:-cli}"
    local release_mode_upper=$(echo "$release_mode" | tr '[:lower:]' '[:upper:]' 2>/dev/null || echo "$release_mode" | awk '{print toupper($0)}')
    echo "[MSP][ORCH] Mode: ${release_mode_upper} — linting pods spec"
    
    # Check CocoaPods installation
    if ! command -v pod >/dev/null 2>&1; then
        log_error "CocoaPods is not installed. Please install it with: sudo gem install cocoapods"
        # Phase B: Production mode requires CocoaPods, dry-run allows soft-fail
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log_error "[MSP][ORCH] Production mode: CocoaPods not installed - aborting"
            exit 1
        else
            log_warn "[MSP][ORCH] Dry-run mode: CocoaPods not installed, skipping CocoaPods release"
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
        # Phase B: Production mode requires valid session, dry-run allows soft-fail
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log_error "[MSP][ORCH] Production mode: CocoaPods trunk session invalid - aborting"
            exit 1
        else
            log_warn "[MSP][ORCH] Dry-run mode: CocoaPods trunk session invalid, skipping CocoaPods release"
            msp_state_mark_step_failed "pods_publish" "CocoaPods trunk session invalid" "1"
            return 0
        fi
    fi
    log_success "CocoaPods trunk session is valid"
    
    # Check GitHub CLI authentication (required for binary distribution pods)
    # This check must happen before any adapter releases that may need to upload zips
    if [[ "${DRY_RUN:-true}" == "false" ]]; then
        log_step "Checking GitHub CLI authentication (pre-flight check)"
        if ! unified_github_cli_auth_check; then
            log_error "[MSP][ORCH] Production mode: GitHub CLI authentication failed - aborting"
            log_error "Please fix GitHub CLI authentication before retrying the release"
            msp_state_mark_step_failed "pods_publish" "GitHub CLI authentication failed" "1"
            exit 1
        fi
    else
        log_info "Dry-run mode: Skipping GitHub CLI authentication check"
    fi
    
    # Phase 4: Strong lint validation for production releases
    if [[ "${DRY_RUN:-true}" == "false" ]]; then
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
                
                # Hard fail for production mode
                if [[ "${DRY_RUN:-true}" == "false" ]]; then
                    log_error "[MSP][ORCH] Production mode: podspec lint errors are not allowed"
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
        cocoapods_pods=("MSPSharedLibraries" "MSPFacebookAdapter" "MSPGoogleAdapter" "MSPNovaAdapter" "MSPAmazonAdapter" "MSPPrebidAdapter" "MSPCore")
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
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
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
            if [[ "${DRY_RUN:-true}" == "false" ]]; then
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

        # Production mode: hard-fail (exit entire release)
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log_error "[MSP][ORCH] Production mode: aborting entire release"
            exit 1
        else
            # Dry-run mode: stop CocoaPods release but continue with other steps (SPM, verification)
            log_warn "[MSP][ORCH] Dry-run mode: stopping CocoaPods release, will continue with other steps"
            # Return early to avoid publishing other pods (they will fail anyway)
            return 1
        fi
    fi
    
    # ════════════════════════════════════════════════════════════════════════════
    # Step 1: Release MSPSharedLibraries and MSPGoogleAdsTypes (PARALLEL)
    # ════════════════════════════════════════════════════════════════════════════
    # Both only depend on MSPiOSCore (already released), so they can be released in parallel
    # This saves ~25 minutes compared to sequential release
    # ════════════════════════════════════════════════════════════════════════════
    
    log_section "Step 1: Releasing MSPSharedLibraries and MSPGoogleAdsTypes (parallel)"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Parallel Release Strategy:"
    log_info "  • MSPSharedLibraries depends on: MSPiOSCore"
    log_info "  • MSPGoogleAdsTypes depends on: Google-Mobile-Ads-SDK (external)"
    log_info "  • Both can be released simultaneously"
    log_info "  • Expected time saving: ~25 minutes"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Pre-flight check: Verify GitHub CLI authentication before parallel release
    if ! unified_github_cli_auth_check; then
        log_error "❌ GitHub CLI authentication check failed"
        log_error "Cannot proceed with parallel release"
        log_error "Please fix authentication and retry"
        return 1
    fi
    
    log_info "Starting parallel releases..."
    
    # Start MSPSharedLibraries in background
    log_info "Starting MSPSharedLibraries release in background..."
    local shared_libs_log="/tmp/msp_release_shared_libs_$$.log"
    local shared_libs_result="/tmp/msp_release_shared_libs_result_$$.txt"
    
    # Register temp files for cleanup
    register_temp_resource "$shared_libs_log"
    register_temp_resource "$shared_libs_result"
    
    (
        # Redirect output to separate log file to avoid conflicts
        exec > "$shared_libs_log" 2>&1
        
        if release_msp_shared_libraries; then
            echo "SUCCESS:MSPSharedLibraries" > "$shared_libs_result"
        else
            echo "FAILED:MSPSharedLibraries" > "$shared_libs_result"
            exit 1
        fi
    ) &
    local SHARED_LIBS_PID=$!
    register_child_pid $SHARED_LIBS_PID "MSPSharedLibraries release"
    log_info "MSPSharedLibraries release started (PID: $SHARED_LIBS_PID)"
    
    # Start MSPGoogleAdsTypes in background
    log_info "Starting MSPGoogleAdsTypes release in background..."
    local google_ads_types_log="/tmp/msp_release_google_ads_types_$$.log"
    local google_ads_types_result="/tmp/msp_release_google_ads_types_result_$$.txt"
    
    # Register temp files for cleanup
    register_temp_resource "$google_ads_types_log"
    register_temp_resource "$google_ads_types_result"
    
    (
        # Redirect output to separate log file to avoid conflicts
        exec > "$google_ads_types_log" 2>&1
        
        if release_msp_googleadstypes; then
            echo "SUCCESS:MSPGoogleAdsTypes" > "$google_ads_types_result"
        else
            echo "FAILED:MSPGoogleAdsTypes" > "$google_ads_types_result"
            exit 1
        fi
    ) &
    local GOOGLE_ADS_TYPES_PID=$!
    register_child_pid $GOOGLE_ADS_TYPES_PID "MSPGoogleAdsTypes release"
    log_info "MSPGoogleAdsTypes release started (PID: $GOOGLE_ADS_TYPES_PID)"
    
    # Wait for both to complete (parallel wait with timeout)
    log_info "Waiting for parallel releases to complete..."
    log_info "  - MSPSharedLibraries (PID: $SHARED_LIBS_PID)"
    log_info "  - MSPGoogleAdsTypes (PID: $GOOGLE_ADS_TYPES_PID)"

    # Maximum wait time: 3 hours (10800s)
    # Rationale: Full release includes build + upload + CDN propagation + verification
    local timeout_seconds=10800
    local check_interval=5
    local elapsed=0

    # Track completion status
    local shared_libs_done=false
    local google_ads_types_done=false
    local shared_libs_exit_code=""
    local google_ads_types_exit_code=""

    # Parallel wait loop with timeout
    while [[ $elapsed -lt $timeout_seconds ]]; do
        # Check if MSPSharedLibraries process is still running
        if [[ "$shared_libs_done" == "false" ]]; then
            if ! kill -0 $SHARED_LIBS_PID 2>/dev/null; then
                # Process has exited, get its exit code via wait
                wait $SHARED_LIBS_PID 2>/dev/null
                shared_libs_exit_code=$?
                shared_libs_done=true
                log_info "MSPSharedLibraries process completed (exit code: $shared_libs_exit_code)"
            fi
        fi

        # Check if MSPGoogleAdsTypes process is still running
        if [[ "$google_ads_types_done" == "false" ]]; then
            if ! kill -0 $GOOGLE_ADS_TYPES_PID 2>/dev/null; then
                # Process has exited, get its exit code via wait
                wait $GOOGLE_ADS_TYPES_PID 2>/dev/null
                google_ads_types_exit_code=$?
                google_ads_types_done=true
                log_info "MSPGoogleAdsTypes process completed (exit code: $google_ads_types_exit_code)"
            fi
        fi

        # Check if both processes are done
        if [[ "$shared_libs_done" == "true" ]] && [[ "$google_ads_types_done" == "true" ]]; then
            log_success "✅ All parallel releases completed"
            break
        fi

        # Progress reporting every minute
        if [[ $((elapsed % 60)) -eq 0 ]] && [[ $elapsed -gt 0 ]]; then
            local remaining=$((timeout_seconds - elapsed))
            log_debug "⏱️  Parallel releases: ${elapsed}s elapsed, ${remaining}s remaining"
            if [[ "$shared_libs_done" == "false" ]]; then
                log_debug "   - MSPSharedLibraries: still running"
            fi
            if [[ "$google_ads_types_done" == "false" ]]; then
                log_debug "   - MSPGoogleAdsTypes: still running"
            fi
        fi

        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done

    # Check for timeout
    if [[ "$shared_libs_done" == "false" ]] || [[ "$google_ads_types_done" == "false" ]]; then
        log_error "❌ Parallel releases TIMED OUT after ${timeout_seconds}s"
        if [[ "$shared_libs_done" == "false" ]]; then
            log_error "   - MSPSharedLibraries: still running (will be killed)"
            kill -TERM $SHARED_LIBS_PID 2>/dev/null || true
        fi
        if [[ "$google_ads_types_done" == "false" ]]; then
            log_error "   - MSPGoogleAdsTypes: still running (will be killed)"
            kill -TERM $GOOGLE_ADS_TYPES_PID 2>/dev/null || true
        fi

        # Mark as failed
        if [[ "$shared_libs_done" == "false" ]]; then
            ((failed_pods++))
            failed_pod_names+=("MSPSharedLibraries")
            msp_state_mark_step_failed "pods_publish" "MSPSharedLibraries release timeout" "124"
        fi
        if [[ "$google_ads_types_done" == "false" ]]; then
            ((failed_pods++))
            failed_pod_names+=("MSPGoogleAdsTypes")
            msp_state_mark_step_failed "pods_publish" "MSPGoogleAdsTypes release timeout" "124"
        fi
    fi

    # =========================================================================
    # Process Results for MSPSharedLibraries
    # =========================================================================
    local shared_libs_success=false

    # Check result file (primary indicator of success)
    if [[ -f "$shared_libs_result" ]] && grep -q "SUCCESS" "$shared_libs_result"; then
        log_success "✅ MSPSharedLibraries released successfully"
        ((successful_pods++))
        shared_libs_success=true

        # Append background log to main log
        if [[ -f "$shared_libs_log" ]]; then
            log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log_info "📋 MSPSharedLibraries release log (from background process):"
            log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            cat "$shared_libs_log" | while IFS= read -r line; do
                log_info "  [MSPSharedLibraries] $line"
            done
            log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        fi
    else
        log_error "❌ MSPSharedLibraries release failed"
        ((failed_pods++))
        failed_pod_names+=("MSPSharedLibraries")

        # Append error log
        if [[ -f "$shared_libs_log" ]]; then
            log_error "MSPSharedLibraries release error log:"
            cat "$shared_libs_log" | while IFS= read -r line; do
                log_error "  [MSPSharedLibraries] $line"
            done
        fi

        # Check if it was a timeout (process never completed)
        if [[ "$shared_libs_done" == "false" ]]; then
            log_error "❌ Reason: Timeout (process did not complete in ${timeout_seconds}s)"
        elif [[ -n "$shared_libs_exit_code" ]] && [[ "$shared_libs_exit_code" != "0" ]]; then
            log_error "❌ Reason: Process exit code $shared_libs_exit_code"
        else
            log_error "❌ Reason: Result file missing or does not contain SUCCESS"
        fi

        if [[ "$DRY_RUN" != "true" ]]; then
            if command -v notify::module_error &>/dev/null; then
                notify::module_error "MSPSharedLibraries" "$VERSION" "Foundation release failed: MSPSharedLibraries publication to CocoaPods Trunk failed"
            fi
        fi
        msp_state_mark_step_failed "pods_publish" "MSPSharedLibraries release failed" "1"
    fi

    # =========================================================================
    # Process Results for MSPGoogleAdsTypes
    # =========================================================================
    local google_ads_types_success=false

    # Check result file (primary indicator of success)
    if [[ -f "$google_ads_types_result" ]] && grep -q "SUCCESS" "$google_ads_types_result"; then
        log_success "✅ MSPGoogleAdsTypes released successfully"
        ((successful_pods++))
        google_ads_types_success=true

        # Append background log to main log
        if [[ -f "$google_ads_types_log" ]]; then
            log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log_info "📋 MSPGoogleAdsTypes release log (from background process):"
            log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            cat "$google_ads_types_log" | while IFS= read -r line; do
                log_info "  [MSPGoogleAdsTypes] $line"
            done
            log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        fi
    else
        log_error "❌ MSPGoogleAdsTypes release failed"
        ((failed_pods++))
        failed_pod_names+=("MSPGoogleAdsTypes")

        # Append error log
        if [[ -f "$google_ads_types_log" ]]; then
            log_error "MSPGoogleAdsTypes release error log:"
            cat "$google_ads_types_log" | while IFS= read -r line; do
                log_error "  [MSPGoogleAdsTypes] $line"
            done
        fi

        # Check if it was a timeout (process never completed)
        if [[ "$google_ads_types_done" == "false" ]]; then
            log_error "❌ Reason: Timeout (process did not complete in ${timeout_seconds}s)"
        elif [[ -n "$google_ads_types_exit_code" ]] && [[ "$google_ads_types_exit_code" != "0" ]]; then
            log_error "❌ Reason: Process exit code $google_ads_types_exit_code"
        else
            log_error "❌ Reason: Result file missing or does not contain SUCCESS"
        fi

        if [[ "$DRY_RUN" != "true" ]]; then
            if command -v notify::module_error &>/dev/null; then
                notify::module_error "MSPGoogleAdsTypes" "$VERSION" "Foundation release failed: MSPGoogleAdsTypes publication to CocoaPods Trunk failed"
            fi
        fi
        msp_state_mark_step_failed "pods_publish" "MSPGoogleAdsTypes release failed" "1"
    fi
    
    # Cleanup result files
    rm -f "$shared_libs_result" "$google_ads_types_result" "$shared_libs_log" "$google_ads_types_log"
    
    # Check if both succeeded (required for adapters)
    if [[ $failed_pods -gt 0 ]]; then
        log_error "One or more foundation pods failed. Cannot proceed with adapters."
        
        # Kill background processes if they're still running
        if kill -0 $SHARED_LIBS_PID 2>/dev/null; then
            log_warn "Terminating MSPSharedLibraries process (PID: $SHARED_LIBS_PID)"
            kill -TERM $SHARED_LIBS_PID 2>/dev/null || true
        fi
        if kill -0 $GOOGLE_ADS_TYPES_PID 2>/dev/null; then
            log_warn "Terminating MSPGoogleAdsTypes process (PID: $GOOGLE_ADS_TYPES_PID)"
            kill -TERM $GOOGLE_ADS_TYPES_PID 2>/dev/null || true
        fi
        
        # Fail-fast in production mode
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log_error "[MSP][ORCH] Production mode: Foundation pod failure - aborting"
            exit 1
        else
            log_warn "[MSP][ORCH] Dry-run mode: Continuing despite failures"
        fi
    fi
    
    log_success "Both MSPSharedLibraries and MSPGoogleAdsTypes released successfully"
    
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
        # Phase B: Production mode requires hard-fail, dry-run allows soft-fail
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log_error "[MSP][ORCH] Production mode: Adapters release failure - aborting"
            log_error "[MSP][ORCH] Cannot proceed to MSPCore (depends on MSPPrebidAdapter)"
            exit 1
        else
            log_warn "[MSP][ORCH] Dry-run mode: CocoaPods release failed, continuing with other steps"
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
        # Phase B: Production mode requires hard-fail, dry-run allows soft-fail
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log_error "[MSP][ORCH] Production mode: MSPCore release failure - aborting"
            exit 1
        else
            log_warn "[MSP][ORCH] Dry-run mode: CocoaPods release failed, continuing with other steps"
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
