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

set -euo pipefail

# Log exit reason on failure (helps debug silent failures from set -e or subshells)
_log_exit_reason() {
  local e=$?
  if [[ $e -ne 0 ]]; then
    local red=""
    local nc=""
    if [[ -t 2 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
      red="\033[1;31m"
      nc="\033[0m"
    fi
    echo -e "${red}ERROR: $(basename "$0") exiting with code $e.${nc}" >&2
    if [[ -n "${LAST_ERROR:-}" ]]; then
      echo -e "${red}ERROR MESSAGE: ${LAST_ERROR}${nc}" >&2
    fi
  fi
  exit $e
}
trap _log_exit_reason EXIT

# Source path helpers and common library
# shellcheck source=Scripts/lib/path-helpers.sh
source "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/path-helpers.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# Load Notification Functions
# ============================================================================
# Load Slack notification functions if available
if [[ -f "$ROOT_DIR/Scripts/notify/slack.sh" ]]; then
    # shellcheck source=Scripts/notify/slack.sh
    source "$ROOT_DIR/Scripts/notify/slack.sh"
    log::debug "PODS" "[NOTIFY] Loaded Slack notification functions from: Scripts/notify/slack.sh" 2>/dev/null || true
else
    # Define stub functions to prevent errors (backward compatibility)
    log::debug "PODS" "[NOTIFY] Slack notification functions not found, using stub functions" 2>/dev/null || true
    notify_release_failure() { :; }
    notify_release_success() { :; }
    notify_release_success_with_summary() { :; }
    notify_release_warning() { :; }
fi

# Source new notification system (supports DM-only, templates, smart routing)
if [[ -f "$ROOT_DIR/Scripts/release/utils/notify.sh" ]]; then
    # shellcheck source=Scripts/release/utils/notify.sh
    source "$ROOT_DIR/Scripts/release/utils/notify.sh" 2>/dev/null || true
    log::debug "PODS" "[NOTIFY] Loaded new notification system (notify.sh)" 2>/dev/null || true
else
    log::warn "PODS" "[NOTIFY] New notification system not found: $ROOT_DIR/Scripts/release/utils/notify.sh"
fi

# Source unified logging system (if not already loaded)
if [[ -f "$ROOT_DIR/Scripts/release/utils/logger.sh" ]]; then
    # shellcheck source=Scripts/release/utils/logger.sh
    source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true
fi

# ============================================================================
# Slack Notification Environment Diagnostics
# ============================================================================
_msp_log_level_num="${MSP_LOG_LEVEL:-1}"
case "$_msp_log_level_num" in debug) _msp_log_level_num=0 ;; info) _msp_log_level_num=1 ;; warn) _msp_log_level_num=2 ;; error) _msp_log_level_num=3 ;; esac
if [[ "$_msp_log_level_num" -le 0 ]] || [[ "${VERBOSE:-false}" == "true" ]]; then
    echo "[DIAG] Slack notification environment check:" >&2
    if [[ -n "${SLACK_BOT_TOKEN:-}" ]]; then
        echo "[DIAG]   SLACK_BOT_TOKEN: SET (${SLACK_BOT_TOKEN:0:20}...)" >&2
    else
        echo "[DIAG]   SLACK_BOT_TOKEN: NOT SET" >&2
    fi
    echo "[DIAG]   MSP_SLACK_DM_OVERRIDE: ${MSP_SLACK_DM_OVERRIDE:-NOT SET}" >&2
    echo "[DIAG]   SLACK_WEBHOOK_URL: ${SLACK_WEBHOOK_URL:+SET}${SLACK_WEBHOOK_URL:-NOT SET}" >&2
fi

source "$ROOT_DIR/Scripts/lib/release-common.sh"

# Source process utilities (timeout and cleanup functions)
if [[ -f "$ROOT_DIR/Scripts/lib/process_utils.sh" ]]; then
    # shellcheck source=Scripts/lib/process_utils.sh
    source "$ROOT_DIR/Scripts/lib/process_utils.sh"
else
    log::error "PODS" "process_utils.sh not found"
    exit 1
fi

# Before sourcing cocoapods.sh, ensure PODFILE is unset
unset PODFILE 2>/dev/null || true
source "$ROOT_DIR/Scripts/lib/cocoapods.sh"

# Source cross-platform lock mechanism (T070)
if [[ -f "$ROOT_DIR/Scripts/lib/lock.sh" ]]; then
    source "$ROOT_DIR/Scripts/lib/lock.sh" 2>/dev/null || true
fi

# R015a: Source step lifecycle module for unified step management
if [[ -f "$ROOT_DIR/Scripts/lib/shared/step_lifecycle.sh" ]]; then
    source "$ROOT_DIR/Scripts/lib/shared/step_lifecycle.sh" 2>/dev/null || true
    log::debug "PODS" "[PUBLISH] Loaded step_lifecycle.sh module"
fi

# After sourcing cocoapods.sh, override PODFILE with project Podfile
PODFILE="$ROOT_DIR/Podfile"
export PODFILE
echo "[PODS][INFO] Using PODFILE path: $PODFILE"
# Load release state utilities (state.sh is already loaded by release-common.sh, but we can source it again if needed)
# Use absolute path to ensure correct location
if [[ -f "$ROOT_DIR/Scripts/release/utils/state.sh" ]]; then
    source "$ROOT_DIR/Scripts/release/utils/state.sh" 2>/dev/null || true
fi

# Source modular components (T100-T104: Script Modularization FR-072~076)
# These modules extract independent functionality from this file
if [[ -f "$SCRIPT_DIR/lib/github_release.sh" ]]; then
    source "$SCRIPT_DIR/lib/github_release.sh"
    log::debug "PODS" "[PUBLISH] Loaded github_release.sh module"
fi

# T101: Pod Trunk verification and availability checking
if [[ -f "$SCRIPT_DIR/lib/pod_trunk.sh" ]]; then
    source "$SCRIPT_DIR/lib/pod_trunk.sh"
    log::debug "PODS" "[PUBLISH] Loaded pod_trunk.sh module"
fi

# T103: Tag management (create, push, verify)
if [[ -f "$SCRIPT_DIR/lib/tag_management.sh" ]]; then
    source "$SCRIPT_DIR/lib/tag_management.sh"
    log::debug "PODS" "[PUBLISH] Loaded tag_management.sh module"
fi

# ZIP management (create, staleness check, verification)
if [[ -f "$SCRIPT_DIR/lib/zip_management.sh" ]]; then
    source "$SCRIPT_DIR/lib/zip_management.sh"
    log::debug "PODS" "[PUBLISH] Loaded zip_management.sh module"
fi

# CDN verification (propagation waiting, availability checks)
# R001: Migrated to shared module (DRY refactor)
_PODS_ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
if [[ -f "$_PODS_ROOT_DIR/Scripts/lib/shared/cdn_verify.sh" ]]; then
    source "$_PODS_ROOT_DIR/Scripts/lib/shared/cdn_verify.sh"
    log::debug "PODS" "[PUBLISH] Loaded shared/cdn_verify.sh module"
fi

# Version management (adapter SDK versions, podspec updates)
if [[ -f "$SCRIPT_DIR/lib/version_management.sh" ]]; then
    source "$SCRIPT_DIR/lib/version_management.sh"
    log::debug "PODS" "[PUBLISH] Loaded version_management.sh module"
fi

# Version commit (git commit operations for version updates)
if [[ -f "$SCRIPT_DIR/lib/version_commit.sh" ]]; then
    source "$SCRIPT_DIR/lib/version_commit.sh"
    log::debug "PODS" "[PUBLISH] Loaded version_commit.sh module"
fi

# Distribution utilities (pod type checking, module lists)
if [[ -f "$SCRIPT_DIR/lib/distribution_utils.sh" ]]; then
    source "$SCRIPT_DIR/lib/distribution_utils.sh"
    log::debug "PODS" "[PUBLISH] Loaded distribution_utils.sh module"
fi

# GitHub release extended (preparation, verification, pod-specific)
if [[ -f "$SCRIPT_DIR/lib/github_release_ext.sh" ]]; then
    source "$SCRIPT_DIR/lib/github_release_ext.sh"
    log::debug "PODS" "[PUBLISH] Loaded github_release_ext.sh module"
fi

# Release utilities (auth checks, commits, workspace, binary rebuilds)
if [[ -f "$SCRIPT_DIR/lib/release_utils.sh" ]]; then
    source "$SCRIPT_DIR/lib/release_utils.sh"
    log::debug "PODS" "[PUBLISH] Loaded release_utils.sh module"
fi

# Input validation (CLI parsing, help, validation, branch checks)
if [[ -f "$SCRIPT_DIR/lib/input_validation.sh" ]]; then
    source "$SCRIPT_DIR/lib/input_validation.sh"
    log::debug "PODS" "[PUBLISH] Loaded input_validation.sh module"
fi

# NovaCore build (XCFramework build and deployment)
if [[ -f "$SCRIPT_DIR/lib/novacore_build.sh" ]]; then
    source "$SCRIPT_DIR/lib/novacore_build.sh"
    log::debug "PODS" "[PUBLISH] Loaded novacore_build.sh module"
fi

# Pod publishing (resume-aware publishing to CocoaPods Trunk)
if [[ -f "$SCRIPT_DIR/lib/pod_publish.sh" ]]; then
    source "$SCRIPT_DIR/lib/pod_publish.sh"
    log::debug "PODS" "[PUBLISH] Loaded pod_publish.sh module"
fi

# Release orchestration (pod release workflow management)
if [[ -f "$SCRIPT_DIR/lib/release_orchestration.sh" ]]; then
    source "$SCRIPT_DIR/lib/release_orchestration.sh"
    log::debug "PODS" "[PUBLISH] Loaded release_orchestration.sh module"
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
        log::error "PODS" "RELEASE_VERSION not set. Did you forget to run via msp-release.sh?"
        log::info "PODS" "Usage: msp-release.sh pods <VERSION>"
        log::info "PODS" "   or: $0 <VERSION> [OPTIONS]  (direct call for debugging)"
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
DEFAULT_PODS_MODULES="MSPiOSCore MSPSharedLibraries MSPGoogleAdsTypes MSPPrebidAdapter MSPCore MSPGoogleAdapter MSPFacebookAdapter MSPNovaAdapter MSPAmazonAdapter MSPMolocoAdapter MSPLiftoffAdapter MSPApplovinMaxAdapter"
PODS_MODULES="${PODS_MODULES:-$DEFAULT_PODS_MODULES}"


# ============================================================================
# Version Management Functions
# ============================================================================
# These functions are now extracted to lib/version_management.sh
# Inline versions kept for backward compatibility when module not loaded
# ============================================================================

if [[ -z "${_VERSION_MANAGEMENT_SOURCED:-}" ]]; then
    log::error "PODS" "FATAL: version_management.sh module not loaded"
    log::error "PODS" "Please ensure lib/version_management.sh exists"
    exit 1
fi

# NOTE: Inline fallback removed - module is now required
# See lib/version_management.sh for function implementations:
#   - update_podspec_for_release
#   - update_adapter_podspec_dependencies

# ============================================================================
# Tag Management Functions
# ============================================================================
# These functions are now extracted to lib/tag_management.sh (T103)
# Inline versions kept for backward compatibility when module not loaded
# ============================================================================

if [[ -z "${_TAG_MANAGEMENT_SOURCED:-}" ]]; then
    log::error "PODS" "FATAL: tag_management.sh module not loaded"
    log::error "PODS" "Please ensure lib/tag_management.sh exists"
    exit 1
fi

# Legacy inline fallback removed - see lib/tag_management.sh
# Removed functions:
#   - ensure_release_tag_exists_and_pushed
#   - wait_for_remote_tag

# Tag management functions provided by lib/tag_management.sh:
#   - ensure_release_tag_exists_and_pushed()
#   - wait_for_remote_tag()

# ============================================================================
# Unified GitHub Release Management (Phase B Step 2b)
# ============================================================================
# NOTE: These functions are now available from lib/github_release.sh module (T100)
# ============================================================================

if [[ -z "${_GITHUB_RELEASE_SOURCED:-}" ]]; then
    log::error "PODS" "FATAL: github_release.sh module not loaded"
    log::error "PODS" "Please ensure lib/github_release.sh exists"
    exit 1
fi


# ============================================================================
# Unified GitHub Release Management (Phase B Step 2b)
# ============================================================================
# NOTE: These functions are now available from lib/github_release.sh module (T100)
# The inline definitions below are kept for backward compatibility.
# They will be removed once all scripts are updated to use the module.
# ============================================================================
# Phase B Change: All modes create/verify GitHub Release
# DRY_RUN controls draft (true) vs published (false) state
# ============================================================================



# ============================================================================
# GitHub Release Extended Functions
# ============================================================================
# These functions are now extracted to lib/github_release_ext.sh
# Inline versions kept for backward compatibility when module not loaded
# ============================================================================







# Main function
main() {
    # Initialize state for standalone pods flow
    msp_state_init "run"
    
    # Check if pods publish should be skipped
    if [[ "${PODS_ENABLED:-true}" == "false" ]] || [[ "${SKIP_PODS:-false}" == "true" ]]; then
        msp_state_mark_step_skipped "pods_publish" "pods publish skipped due to PODS_ENABLED=false or SKIP_PODS=true"
        log::info "PODS" "Pods publish skipped"
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

    # Ensure workspace exists early (required for NovaCore rebuild in adapters phase)
    if ! ensure_release_workspace; then
        log::error "PODS" "[MSP][ORCH] Workspace preparation failed - aborting"
        msp_state_mark_step_failed "pods_publish" "Workspace preparation failed" "1"
        exit 1
    fi
    
    # Record start time for duration calculation
    local start_time=$(date +%s)
    
    # Check if we should skip this step in resume mode
    if [[ "${MSP_RESUME_MODE:-0}" == "1" ]]; then
        local status
        status="$(msp_state_get_step_status "pods_publish" 2>/dev/null || echo "unknown")"
        if [[ "$status" == "success" || "$status" == "skipped" ]]; then
            log::info "PODS" "Resuming: skipping pods_publish (status already ${status})"
            return 0
        fi
    fi
    
    # Mark pods_publish step as running
    msp_state_mark_step_running "pods_publish"

    # Force rebuild all binary XCFrameworks for every publish run (including resume)
    if ! rebuild_release_binaries; then
        msp_state_mark_step_failed "pods_publish" "Binary XCFramework rebuild failed" "1"
        exit 1
    fi
    
    print_section "Starting CocoaPods Release Process for Version: $VERSION"
    
    # Phase 4 TASK 1: CocoaPods release strong validation
    # Phase B: Removed release_tier variable, use DRY_RUN directly
    local release_mode="${MSP_RELEASE_MODE:-cli}"
    local release_mode_upper=$(echo "$release_mode" | tr '[:lower:]' '[:upper:]' 2>/dev/null || echo "$release_mode" | awk '{print toupper($0)}')
    echo "[MSP][ORCH] Mode: ${release_mode_upper} — linting pods spec"
    
    # Check CocoaPods installation
    if ! command -v pod >/dev/null 2>&1; then
        log::error "PODS" "CocoaPods is not installed. Please install it with: sudo gem install cocoapods"
        # Phase B: Production mode requires CocoaPods, dry-run allows soft-fail
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log::error "PODS" "[MSP][ORCH] Production mode: CocoaPods not installed - aborting"
            exit 1
        else
            log::warn "PODS" "[MSP][ORCH] Dry-run mode: CocoaPods not installed, skipping CocoaPods release"
            msp_state_mark_step_failed "pods_publish" "CocoaPods not installed" "1"
            return 0
        fi
    fi
    
    # Check trunk session status (stronger check)
    log::step "PODS" "Checking CocoaPods trunk session"
    local trunk_check
    trunk_check=$(pod trunk me 2>&1 || echo "ERROR")
    if [[ "$trunk_check" =~ "No session" ]] || [[ "$trunk_check" =~ "authentication" ]] || [[ "$trunk_check" =~ "ERROR" ]]; then
        log::error "PODS" "CocoaPods trunk session is not valid"
        log::error "PODS" "Please run: pod trunk register <email> <name>"
        # Phase B: Production mode requires valid session, dry-run allows soft-fail
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log::error "PODS" "[MSP][ORCH] Production mode: CocoaPods trunk session invalid - aborting"
            exit 1
        else
            log::warn "PODS" "[MSP][ORCH] Dry-run mode: CocoaPods trunk session invalid, skipping CocoaPods release"
            msp_state_mark_step_failed "pods_publish" "CocoaPods trunk session invalid" "1"
            return 0
        fi
    fi
    log::success "PODS" "CocoaPods trunk session is valid"
    
    # Check GitHub CLI authentication (required for binary distribution pods)
    # This check must happen before any adapter releases that may need to upload zips
    if [[ "${DRY_RUN:-true}" == "false" ]]; then
        log::step "PODS" "Checking GitHub CLI authentication (pre-flight check)"
        if ! unified_github_cli_auth_check; then
            log::error "PODS" "[MSP][ORCH] Production mode: GitHub CLI authentication failed - aborting"
            log::error "PODS" "Please fix GitHub CLI authentication before retrying the release"
            msp_state_mark_step_failed "pods_publish" "GitHub CLI authentication failed" "1"
            exit 1
        fi
    else
        log::info "PODS" "Dry-run mode: Skipping GitHub CLI authentication check"
    fi
    
    # Create CocoaPods-specific pod list from PODS_MODULES
    # Convert space-separated PODS_MODULES to array
    # NOTE: Must be initialized before Phase 4 lint validation which uses it
    local cocoapods_pods=()
    for module in ${PODS_MODULES:-}; do
        cocoapods_pods+=("$module")
    done

    if [[ ${#cocoapods_pods[@]} -eq 0 ]]; then
        log::warn "PODS" "PODS_MODULES is empty. Using default pod list for backward compatibility."
        cocoapods_pods=("MSPSharedLibraries" "MSPFacebookAdapter" "MSPGoogleAdapter" "MSPNovaAdapter" "MSPAmazonAdapter" "MSPPrebidAdapter" "MSPCore")
    fi

    log::info "PODS" "Releasing pods from PODS_MODULES: ${cocoapods_pods[*]}"

    # Phase 4: Podspec file existence validation for production releases
    # NOTE: Full spec lint is skipped here because:
    #   1. Dependencies haven't been pushed to trunk yet at this stage
    #   2. Pre-release versions (e.g., 1.0.4-rc.3) won't resolve via pod spec lint
    #   3. Transitive dependencies (e.g., MSPSnapKit) may not be on public trunk
    #   4. The real validation happens during pod trunk push (Phase 5+)
    if [[ "${DRY_RUN:-true}" == "false" ]]; then
        log_section "Phase 4: Release/Production - Podspec File Validation"

        # Validate all podspec files exist before publishing
        local lint_errors=0
        local lint_warnings=0

        for module in "${cocoapods_pods[@]}"; do
            local podspec="${module}.podspec"
            if [[ ! -f "$podspec" ]]; then
                log::error "PODS" "Podspec file not found: $podspec"
                lint_errors=$((lint_errors + 1))
                continue
            fi

            log::success "PODS" "Podspec file exists: $podspec"
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
            log::error "PODS" "Missing $lint_errors podspec file(s). Production release aborted."
            exit 1
        fi
        
        log::success "PODS" "All podspecs passed lint validation ($lint_warnings warnings, non-blocking)"
    fi
    
    # Generate release notes
    local release_notes=""
    if [[ -n "$RELEASE_NOTES" ]]; then
        release_notes="$RELEASE_NOTES"
        log::info "PODS" "Using provided release notes"
    else
        log::step "PODS" "Generating release notes from source: $RELEASE_NOTES_SOURCE"
        release_notes=$(get_release_notes "$VERSION" "CocoaPods" "$RELEASE_NOTES_SOURCE" "$RELEASE_NOTES_TEMPLATE")
    fi
    
    # ============================================================================
    # CRITICAL: Ensure release tag exists and is pushed BEFORE creating releases
    # ============================================================================
    log_section "Pre-Release: Creating and pushing release tag"

    # Ensure the release tag exists locally and is pushed to remotes
    # This MUST happen before GitHub Release creation to avoid draft releases
    if ! ensure_release_tag_exists_and_pushed "$VERSION" "HEAD"; then
        log::error "PODS" "Failed to create/push release tag: $VERSION"
        msp_state_mark_step_failed "pods_publish" "Failed to create release tag: $VERSION" "1"

        # FAIL-FAST in release tier
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log::error "PODS" "[FAIL-FAST] Tag creation failed in release tier. Aborting."
            exit 1
        fi
        return 1
    fi

    log::success "PODS" "Release tag $VERSION created and pushed to all remotes"

    # Wait for tag propagation (GitHub may need time to make tag available)
    log::info "PODS" "Waiting 5 seconds for tag propagation..."
    sleep 5

    # Verify tag is accessible on public remote (skip in DRY_RUN mode)
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log::info "PODS" "DRY RUN: Skipping tag verification on public remote"
    elif [[ "${SKIP_PUBLIC_REMOTE_PUSH:-0}" == "1" ]]; then
        log::warn "PODS" "SKIP_PUBLIC_REMOTE_PUSH=1: Skipping tag verification on public remote"
    elif git remote | grep -q "^public$"; then
        if ! git ls-remote --tags public "refs/tags/$VERSION" 2>/dev/null | grep -q "$VERSION"; then
            log::error "PODS" "Tag $VERSION not found on public remote after push"
            log::error "PODS" "GitHub Release creation will fail or create draft release"

            # FAIL-FAST in release tier (unless MSP_ALLOW_PUBLIC_PUSH_FAILURE is set)
            if [[ "${DRY_RUN:-true}" == "false" ]]; then
                if [[ "${MSP_ALLOW_PUBLIC_PUSH_FAILURE:-0}" == "1" ]]; then
                    log::warn "PODS" "MSP_ALLOW_PUBLIC_PUSH_FAILURE=1: Continuing despite tag verification failure"
                else
                    log::error "PODS" "[FAIL-FAST] Tag not accessible on public remote. Aborting."
                    exit 1
                fi
            else
                return 1
            fi
        else
            log::success "PODS" "Tag $VERSION verified on public remote"

            # CRITICAL: Verify tag points to correct commit
            local public_tag_sha
            public_tag_sha=$(git ls-remote --tags public "refs/tags/$VERSION" 2>/dev/null | awk '{print $1}')
            local local_tag_sha
            local_tag_sha=$(git rev-parse "refs/tags/$VERSION" 2>/dev/null)

            if [[ -n "$public_tag_sha" ]] && [[ -n "$local_tag_sha" ]] && [[ "$public_tag_sha" != "$local_tag_sha" ]]; then
                if [[ "${MSP_PUBLIC_PUSH_FILTERED:-0}" == "1" ]]; then
                    log::warn "PODS" "Public tag SHA differs from local after filtered push (expected in rewritten history)"
                    log::warn "PODS" "Tag: $VERSION"
                    log::warn "PODS" "本地 Local:  $local_tag_sha"
                    log::warn "PODS" "远程 Public: $public_tag_sha"
                    log::warn "PODS" "Filtered push rewrites commit SHA; skip strict SHA-equality check"
                else
                    log::error "PODS" "════════════════════════════════════════════════════════════"
                    log::error "PODS" "  ❌ Public Remote Tag SHA Mismatch!"
                    log::error "PODS" "════════════════════════════════════════════════════════════"
                    log::error "PODS" ""
                    log::error "PODS" "Tag: $VERSION"
                    log::error "PODS" "本地 Local:  $local_tag_sha"
                    log::error "PODS" "远程 Public: $public_tag_sha"
                    log::error "PODS" ""
                    log::error "PODS" "这意味着 public remote 上的 tag 指向错误的 commit！"
                    log::error "PODS" "CocoaPods 验证将会失败（source_files 找不到）"
                    log::error "PODS" ""
                    log::error "PODS" "解决方案:"
                    log::error "PODS" "  1. 强制更新 public remote tag:"
                    log::error "PODS" "     git push public :refs/tags/$VERSION"
                    log::error "PODS" "     git push public refs/tags/$VERSION"
                    log::error "PODS" ""
                    log::error "PODS" "  2. 或者运行修复命令:"
                    log::error "PODS" "     ./Scripts/msp-release.sh fix-public-tag $VERSION"
                    log::error "PODS" ""
                    log::error "PODS" "════════════════════════════════════════════════════════════"

                    if [[ "${MSP_ALLOW_PUBLIC_PUSH_FAILURE:-0}" == "1" ]]; then
                        log::warn "PODS" "⚠️  MSP_ALLOW_PUBLIC_PUSH_FAILURE=1: 继续执行但可能失败"
                    else
                        log::error "PODS" "🛑 停止执行"
                        exit 1
                    fi
                fi
            elif [[ -n "$public_tag_sha" ]] && [[ -n "$local_tag_sha" ]] && [[ "$public_tag_sha" == "$local_tag_sha" ]]; then
                log::success "PODS" "✅ Tag SHA verified: local and public match"
            fi
        fi
    else
        log::warn "PODS" "Public remote not found, skipping tag verification"
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
        ((successful_pods++)) || true
    else
        ((failed_pods++)) || true
        failed_pod_names+=("MSPiOSCore")
        if [[ "$DRY_RUN" != "true" ]]; then
            # Use new notification system: DM only (no channel spam)
            if command -v notify::module_error &>/dev/null; then
                notify::module_error "MSPiOSCore" "$VERSION" "Foundation release failed: MSPiOSCore publication to CocoaPods Trunk failed"
            else
                log::warn "PODS" "New notification system not available, skipping failure notification"
            fi
        fi
        msp_state_mark_step_failed "pods_publish" "MSPiOSCore release failed" "1"

        # MSPiOSCore is foundation module - all other modules depend on it
        log::error "PODS" "[MSP][ORCH] MSPiOSCore release failed (foundation module)"
        log::error "PODS" "[MSP][ORCH] All other modules depend on MSPiOSCore. Stopping CocoaPods release."

        # Production mode: hard-fail (exit entire release)
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log::error "PODS" "[MSP][ORCH] Production mode: aborting entire release"
            exit 1
        else
            # Dry-run mode: stop CocoaPods release but continue with other steps (SPM, verification)
            log::warn "PODS" "[MSP][ORCH] Dry-run mode: stopping CocoaPods release, will continue with other steps"
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
    log::info "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "PODS" "Parallel Release Strategy:"
    log::info "PODS" "  • MSPSharedLibraries depends on: MSPiOSCore"
    log::info "PODS" "  • MSPGoogleAdsTypes depends on: Google-Mobile-Ads-SDK (external)"
    log::info "PODS" "  • Both can be released simultaneously"
    log::info "PODS" "  • Expected time saving: ~25 minutes"
    log::info "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Pre-flight check: Verify GitHub CLI authentication before parallel release
    if ! unified_github_cli_auth_check; then
        log::error "PODS" "❌ GitHub CLI authentication check failed"
        log::error "PODS" "Cannot proceed with parallel release"
        log::error "PODS" "Please fix authentication and retry"
        return 1
    fi
    
    log::info "PODS" "Starting parallel releases..."
    
    # Start MSPSharedLibraries in background
    log::info "PODS" "Starting MSPSharedLibraries release in background..."
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
    log::info "PODS" "MSPSharedLibraries release started (PID: $SHARED_LIBS_PID)"
    
    # Start MSPGoogleAdsTypes in background
    log::info "PODS" "Starting MSPGoogleAdsTypes release in background..."
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
    log::info "PODS" "MSPGoogleAdsTypes release started (PID: $GOOGLE_ADS_TYPES_PID)"
    
    # Wait for both to complete (parallel wait with timeout)
    log::info "PODS" "Waiting for parallel releases to complete..."
    log::info "PODS" "  - MSPSharedLibraries (PID: $SHARED_LIBS_PID)"
    log::info "PODS" "  - MSPGoogleAdsTypes (PID: $GOOGLE_ADS_TYPES_PID)"

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
                # Use || to prevent set -e from killing the script on non-zero child exit
                shared_libs_exit_code=0
                wait $SHARED_LIBS_PID 2>/dev/null || shared_libs_exit_code=$?
                shared_libs_done=true
                log::info "PODS" "MSPSharedLibraries process completed (exit code: $shared_libs_exit_code)"
            fi
        fi

        # Check if MSPGoogleAdsTypes process is still running
        if [[ "$google_ads_types_done" == "false" ]]; then
            if ! kill -0 $GOOGLE_ADS_TYPES_PID 2>/dev/null; then
                # Process has exited, get its exit code via wait
                # Use || to prevent set -e from killing the script on non-zero child exit
                google_ads_types_exit_code=0
                wait $GOOGLE_ADS_TYPES_PID 2>/dev/null || google_ads_types_exit_code=$?
                google_ads_types_done=true
                log::info "PODS" "MSPGoogleAdsTypes process completed (exit code: $google_ads_types_exit_code)"
            fi
        fi

        # Check if both processes are done
        if [[ "$shared_libs_done" == "true" ]] && [[ "$google_ads_types_done" == "true" ]]; then
            log::success "PODS" "✅ All parallel releases completed"
            break
        fi

        # Progress reporting every minute
        if [[ $((elapsed % 60)) -eq 0 ]] && [[ $elapsed -gt 0 ]]; then
            local remaining=$((timeout_seconds - elapsed))
            log::debug "PODS" "⏱️  Parallel releases: ${elapsed}s elapsed, ${remaining}s remaining"
            if [[ "$shared_libs_done" == "false" ]]; then
                log::debug "PODS" "   - MSPSharedLibraries: still running"
            fi
            if [[ "$google_ads_types_done" == "false" ]]; then
                log::debug "PODS" "   - MSPGoogleAdsTypes: still running"
            fi
        fi

        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done

    # Check for timeout
    if [[ "$shared_libs_done" == "false" ]] || [[ "$google_ads_types_done" == "false" ]]; then
        log::error "PODS" "❌ Parallel releases TIMED OUT after ${timeout_seconds}s"
        if [[ "$shared_libs_done" == "false" ]]; then
            log::error "PODS" "   - MSPSharedLibraries: still running (will be killed)"
            kill -TERM $SHARED_LIBS_PID 2>/dev/null || true
        fi
        if [[ "$google_ads_types_done" == "false" ]]; then
            log::error "PODS" "   - MSPGoogleAdsTypes: still running (will be killed)"
            kill -TERM $GOOGLE_ADS_TYPES_PID 2>/dev/null || true
        fi

        # Mark as failed
        if [[ "$shared_libs_done" == "false" ]]; then
            ((failed_pods++)) || true
            failed_pod_names+=("MSPSharedLibraries")
            msp_state_mark_step_failed "pods_publish" "MSPSharedLibraries release timeout" "124"
        fi
        if [[ "$google_ads_types_done" == "false" ]]; then
            ((failed_pods++)) || true
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
        log::success "PODS" "✅ MSPSharedLibraries released successfully"
        ((successful_pods++)) || true
        shared_libs_success=true

        # Append background log to main log
        if [[ -f "$shared_libs_log" ]]; then
            log::info "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log::info "PODS" "📋 MSPSharedLibraries release log (from background process):"
            log::info "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            cat "$shared_libs_log" | while IFS= read -r line; do
                log::info "PODS" "  [MSPSharedLibraries] $line"
            done
            log::info "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        fi
    else
        log::error "PODS" "❌ MSPSharedLibraries release failed"
        ((failed_pods++)) || true
        failed_pod_names+=("MSPSharedLibraries")

        # Append error log
        if [[ -f "$shared_libs_log" ]]; then
            log::error "PODS" "MSPSharedLibraries release error log:"
            cat "$shared_libs_log" | while IFS= read -r line; do
                log::error "PODS" "  [MSPSharedLibraries] $line"
            done
        fi

        # Check if it was a timeout (process never completed)
        if [[ "$shared_libs_done" == "false" ]]; then
            log::error "PODS" "❌ Reason: Timeout (process did not complete in ${timeout_seconds}s)"
        elif [[ -n "$shared_libs_exit_code" ]] && [[ "$shared_libs_exit_code" != "0" ]]; then
            log::error "PODS" "❌ Reason: Process exit code $shared_libs_exit_code"
        else
            log::error "PODS" "❌ Reason: Result file missing or does not contain SUCCESS"
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
        log::success "PODS" "✅ MSPGoogleAdsTypes released successfully"
        ((successful_pods++)) || true
        google_ads_types_success=true

        # Append background log to main log
        if [[ -f "$google_ads_types_log" ]]; then
            log::info "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log::info "PODS" "📋 MSPGoogleAdsTypes release log (from background process):"
            log::info "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            cat "$google_ads_types_log" | while IFS= read -r line; do
                log::info "PODS" "  [MSPGoogleAdsTypes] $line"
            done
            log::info "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        fi
    else
        log::error "PODS" "❌ MSPGoogleAdsTypes release failed"
        ((failed_pods++)) || true
        failed_pod_names+=("MSPGoogleAdsTypes")

        # Append error log
        if [[ -f "$google_ads_types_log" ]]; then
            log::error "PODS" "MSPGoogleAdsTypes release error log:"
            cat "$google_ads_types_log" | while IFS= read -r line; do
                log::error "PODS" "  [MSPGoogleAdsTypes] $line"
            done
        fi

        # Check if it was a timeout (process never completed)
        if [[ "$google_ads_types_done" == "false" ]]; then
            log::error "PODS" "❌ Reason: Timeout (process did not complete in ${timeout_seconds}s)"
        elif [[ -n "$google_ads_types_exit_code" ]] && [[ "$google_ads_types_exit_code" != "0" ]]; then
            log::error "PODS" "❌ Reason: Process exit code $google_ads_types_exit_code"
        else
            log::error "PODS" "❌ Reason: Result file missing or does not contain SUCCESS"
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
        log::error "PODS" "One or more foundation pods failed. Cannot proceed with adapters."
        
        # Kill background processes if they're still running
        if kill -0 $SHARED_LIBS_PID 2>/dev/null; then
            log::warn "PODS" "Terminating MSPSharedLibraries process (PID: $SHARED_LIBS_PID)"
            kill -TERM $SHARED_LIBS_PID 2>/dev/null || true
        fi
        if kill -0 $GOOGLE_ADS_TYPES_PID 2>/dev/null; then
            log::warn "PODS" "Terminating MSPGoogleAdsTypes process (PID: $GOOGLE_ADS_TYPES_PID)"
            kill -TERM $GOOGLE_ADS_TYPES_PID 2>/dev/null || true
        fi
        
        # Fail-fast in production mode
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log::error "PODS" "[MSP][ORCH] Production mode: Foundation pod failure - aborting"
            exit 1
        else
            log::warn "PODS" "[MSP][ORCH] Dry-run mode: Continuing despite failures"
        fi
    fi
    
    log::success "PODS" "Both MSPSharedLibraries and MSPGoogleAdsTypes released successfully"
    
    # Step 2: Release Adapters
    # Compute adapter count from PODS_MODULES (exclude core modules)
    local _core_mods="MSPiOSCore MSPSharedLibraries MSPGoogleAdsTypes MSPCore"
    local _adapter_count=0
    for _m in $PODS_MODULES; do
        echo "$_core_mods" | grep -qw "$_m" || _adapter_count=$((_adapter_count + 1))
    done

    if release_adapters; then
        successful_pods=$((successful_pods + _adapter_count))
    else
        failed_pods=$((failed_pods + _adapter_count))
        failed_pod_names+=("Adapters")
        if [[ "$DRY_RUN" != "true" ]]; then
            # Use new notification system: DM only (no channel spam)
            if command -v notify::module_error &>/dev/null; then
                notify::module_error "Adapters" "$VERSION" "Adapters release failed: One or more adapters failed to publish to CocoaPods Trunk"
            else
                log::warn "PODS" "New notification system not available, skipping failure notification"
            fi
        fi
        msp_state_mark_step_failed "pods_publish" "Adapter release failed" "1"
        # Phase B: Production mode requires hard-fail, dry-run allows soft-fail
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log::error "PODS" "[MSP][ORCH] Production mode: Adapters release failure - aborting"
            log::error "PODS" "[MSP][ORCH] Cannot proceed to MSPCore (depends on MSPPrebidAdapter)"
            exit 1
        else
            log::warn "PODS" "[MSP][ORCH] Dry-run mode: CocoaPods release failed, continuing with other steps"
        fi
    fi
    
    # Step 3: Release MSPCore
    if release_msp_core; then
        ((successful_pods++)) || true
    else
        ((failed_pods++)) || true
        failed_pod_names+=("MSPCore")
        if [[ "$DRY_RUN" != "true" ]]; then
            # Use new notification system: DM only (no channel spam)
            if command -v notify::module_error &>/dev/null; then
                notify::module_error "MSPCore" "$VERSION" "Main framework release failed: MSPCore publication to CocoaPods Trunk failed"
            else
                log::warn "PODS" "New notification system not available, skipping failure notification"
            fi
        fi
        msp_state_mark_step_failed "pods_publish" "MSPCore release failed" "1"
        # Phase B: Production mode requires hard-fail, dry-run allows soft-fail
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log::error "PODS" "[MSP][ORCH] Production mode: MSPCore release failure - aborting"
            exit 1
        else
            log::warn "PODS" "[MSP][ORCH] Dry-run mode: CocoaPods release failed, continuing with other steps"
        fi
    fi

    # Step 4: Verify all GitHub releases
    log::info "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "PODS" "Step: Verifying GitHub Releases"
    log::info "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ -f "$ROOT_DIR/Scripts/release/publish/pods/lib/github_release_verify.sh" ]]; then
        # shellcheck source=Scripts/release/publish/pods/lib/github_release_verify.sh
        source "$ROOT_DIR/Scripts/release/publish/pods/lib/github_release_verify.sh"

        if verify_all_github_releases "$VERSION"; then
            log::success "PODS" "✅ All GitHub releases verified"
        else
            log::warn "PODS" "⚠️  Some GitHub releases are missing"
            log::warn "PODS" "This won't block the release, but pods may have issues"
            log::warn "PODS" "Run: ./Scripts/msp-release.sh create-github-releases $VERSION"
        fi
    else
        log::warn "PODS" "GitHub release verification script not found, skipping"
    fi

    # Commit all changes
    commit_release_changes
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local duration_formatted=$(printf "%02d:%02d:%02d" $((duration/3600)) $((duration%3600/60)) $((duration%60)))
    
    print_section "CocoaPods Release Process Completed Successfully"
    log::success "PODS" "All pods released successfully for version: $VERSION"
    log::info "PODS" "Release branch '$RELEASE_BRANCH' is ready to be pushed"
    
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
