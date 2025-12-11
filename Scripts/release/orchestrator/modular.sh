#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
echo "[DIAG] modular.sh starting" >&2
echo "[DIAG] Script path: $0" >&2
echo "[DIAG] Arguments: $*" >&2

# Modular Release Orchestrator
# Orchestrates the complete release process: create branch → CocoaPods → SPM → push
#
# Phase 2 Step 4: Config-driven orchestrator
# This script now uses environment variables from msp-release.sh instead of CLI arguments.


# ============================================================================
# Release Mode Detection
# ============================================================================
# Normalize release mode; default to cli for backward compatibility
_msp_release_get_mode() {
    local mode="${MSP_RELEASE_MODE:-cli}"
    
    case "$mode" in
        ci|CI)
            echo "ci"
            ;;
        cli|CLI|"")
            echo "cli"
            ;;
        *)
            # Unknown mode: fallback to cli but log a warning
            echo "cli"
            >&2 echo "[MSP][ORCH][WARN] Unknown MSP_RELEASE_MODE='$mode', falling back to 'cli'"
            ;;
    esac
}

# Source the common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[DIAG] SCRIPT_DIR set" >&2
# ============================================
# Unified ROOT_DIR resolution (final version)
# ============================================
if [[ -z "${ROOT_DIR:-}" ]]; then
    # First try Git repo root (most reliable)
    if command -v git >/dev/null 2>&1; then
echo "[DIAG] git command check passed" >&2
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
echo "[DIAG] ROOT_DIR exported: $ROOT_DIR" >&2

# Set BUILD_ENVIRONMENT default before sourcing release-common.sh
# This prevents "parameter not set" errors when release-common.sh uses set -u
export BUILD_ENVIRONMENT="${BUILD_ENVIRONMENT:-local}"
echo "[DIAG] BUILD_ENVIRONMENT set" >&2

source "$ROOT_DIR/Scripts/lib/release-common.sh"
# Ensure tier helpers are available
if ! command -v is_preflight_tier &>/dev/null; then
    # Tier helpers should be in release-common.sh, but reload if missing
    source "$ROOT_DIR/Scripts/lib/release-common.sh" 2>/dev/null || true
fi
set +e  # Temporarily disabled - will re-enable after identifying failing command

# Source state management utility (state.sh is already loaded by release-common.sh, but we can source it again if needed)
# Use absolute path to ensure correct location
if [[ -f "$ROOT_DIR/Scripts/release/utils/state.sh" ]]; then
    source "$ROOT_DIR/Scripts/release/utils/state.sh" 2>/dev/null || true
fi

# Source notification utilities for Slack integration
if [[ -f "$ROOT_DIR/Scripts/release/utils/notify.sh" ]]; then
    source "$ROOT_DIR/Scripts/release/utils/notify.sh" 2>/dev/null || true
fi

# Source email notification utilities
if [[ -f "$ROOT_DIR/Scripts/notify/email.sh" ]]; then
    source "$ROOT_DIR/Scripts/notify/email.sh" 2>/dev/null || true
fi

# ============================================================================
# STEP-Level Logging Functions
# ============================================================================
# These functions provide structured logging for each CI step
step() {
    echo "[CI][STEP] $1..." >&2
}

step_done() {
    echo "[CI][STEP] $1: OK" >&2
}

step_fail() {
    echo "[CI][STEP] $1: FAILED (code=$2)" >&2
}

step_skip() {
    echo "[CI][STEP] $1: SKIPPED" >&2
}

# ============================================================================
# Environment Variable Validation
# ============================================================================
# Check if required environment variables are set (from msp-release.sh)
# If not set, fall back to CLI argument parsing for backward compatibility

if [[ -z "${RELEASE_VERSION:-}" ]]; then
    # Backward compatibility: extract MODE and VERSION from CLI if called directly
    # Expected format: bash modular.sh <MODE> <VERSION> [OPTIONS...]
    # Example: bash modular.sh run 0.0.1-preflight-test
    if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
        # First argument is MODE (e.g., "run"), skip it
        shift
        # Second argument is VERSION (e.g., "0.0.1-preflight-test")
        if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
            RELEASE_VERSION="$1"
            shift
        else
            log_error "VERSION not provided. Expected: $0 <MODE> <VERSION> [OPTIONS]"
            log_info "Usage: msp-release.sh run <VERSION>"
            log_info "   or: $0 <MODE> <VERSION> [OPTIONS]  (direct call for debugging)"
            exit 1
        fi
    else
        log_error "RELEASE_VERSION not set. Did you forget to run via msp-release.sh?"
        log_info "Usage: msp-release.sh run <VERSION>"
        log_info "   or: $0 <MODE> <VERSION> [OPTIONS]  (direct call for debugging)"
        exit 1
    fi
fi

# Use environment variables with CLI fallback for backward compatibility
VERSION="${RELEASE_VERSION:-}"
BASE_BRANCH="${BASE_BRANCH:-}"
RELEASE_BRANCH="${RELEASE_BRANCH:-}"
DRY_RUN="${DRY_RUN:-false}"
SKIP_PUSH="${SKIP_PUSH:-false}"
SKIP_CODE_SIGN="${SKIP_CODE_SIGN:-false}"
VERBOSE="${VERBOSE:-false}"
RELEASE_NOTES="${RELEASE_NOTES:-}"

# Use PODS_ENABLED and SPM_ENABLED from environment (normalized by msp-release.sh)
# Convert to SKIP flags for internal use
if [[ "${PODS_ENABLED:-true}" == "false" ]]; then
    SKIP_COCOAPODS="true"
else
    SKIP_COCOAPODS="false"
fi

if [[ "${SPM_ENABLED:-true}" == "false" ]]; then
    SKIP_SPM="true"
else
    SKIP_SPM="false"
fi

# Release tracking variables
RELEASE_START_TIME=""
RELEASE_END_TIME=""
COCOAPODS_SUCCESS=()
COCOAPODS_FAILED=()
SPM_SUCCESS=()
SPM_FAILED=()
GITHUB_RELEASES_SUCCESS=()
GITHUB_RELEASES_FAILED=()
OVERALL_SUCCESS="true"

# ============================================================================
# Backward Compatibility: CLI Argument Parsing
# ============================================================================
# Only used if script is called directly (not via msp-release.sh)
# This allows debugging and direct execution for backward compatibility
parse_arguments() {
    # Only parse if we have remaining CLI args (backward compatibility)
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                echo "Modular Release Orchestrator v2.0.0-phase2"
                exit 0
                ;;
            --base-branch)
                BASE_BRANCH="$2"
                shift 2
                ;;
            --release-branch)
                RELEASE_BRANCH="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --skip-cocoapods|--skip-pods)
                SKIP_COCOAPODS="true"
                shift
                ;;
            --skip-spm)
                SKIP_SPM="true"
                shift
                ;;
            --skip-push)
                SKIP_PUSH="true"
                shift
                ;;
            --skip-code-sign)
                SKIP_CODE_SIGN="true"
                shift
                ;;
            --enable-code-sign)
                SKIP_CODE_SIGN="false"
                shift
                ;;
            --verbose)
                VERBOSE="true"
                shift
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
    echo "  --base-branch BRANCH    Base branch to create release from (default: current branch)"
    echo "  --release-branch BRANCH Release branch name (default: release/VERSION)"
    echo "  --dry-run               Show what would be done without executing"
    echo "  --skip-cocoapods        Skip CocoaPods release"
    echo "  --skip-spm              Skip SPM release"
    echo "  --skip-push             Skip pushing release branch"
    echo "  --skip-code-sign        Skip code signing (default: false)"
    echo "  --enable-code-sign      Enable code signing"
    echo "  --verbose               Enable verbose output"
    echo "  --release-notes NOTES   Custom release notes for notifications"
    echo "  --help, -h              Show this help message"
    echo "  --version, -v           Show version information"
    echo ""
    echo "Complete Release Workflow:"
    echo "  1. Create release branch from base branch"
    echo "  2. Release CocoaPods (MSPSharedLibraries → Adapters → MSPCore)"
    echo "  3. Release SPM (NovaCore → NovaAdapter)"
    echo "  4. Push release branch to remote"
    echo ""
    echo "Examples:"
    echo "  $0 0.0.2-migration-spm"
    echo "  $0 --dry-run 0.0.2-migration-spm"
    echo "  $0 --skip-spm 0.0.2-migration-spm"
}

# ============================================================================
# Validate Inputs
# ============================================================================
validate_inputs() {
    # VERSION should already be set from RELEASE_VERSION
    if [[ -z "$VERSION" ]]; then
        log_error "Version is required"
        show_help
        exit 1
    fi
    
    # Set base branch to current branch if not provided
    if [[ -z "$BASE_BRANCH" ]]; then
        BASE_BRANCH="$(git branch --show-current)"
        if [[ -z "$BASE_BRANCH" ]]; then
            log_error "Could not determine current branch. Please specify BASE_BRANCH environment variable or --base-branch"
            exit 1
        fi
    fi
    
    # Set release branch if not provided
    if [[ -z "$RELEASE_BRANCH" ]]; then
        RELEASE_BRANCH="release/$VERSION"
    fi
    
    # Phase 4 TASK 0: Branch validity check for production releases
    local current_branch
    current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
    if [[ -z "$current_branch" ]]; then
        log_error "Could not determine current git branch"
        exit 1
    fi
    
    local release_tier="${MSP_RELEASE_TIER:-preflight}"
    if [[ "$release_tier" == "production" ]]; then
        # Production release: only allowed on main or release/* branches
        if [[ "$current_branch" != "main" ]] && [[ ! "$current_branch" =~ ^release/ ]]; then
            log_error "[MSP][ORCH][ERROR] Production release requires branch 'main' or 'release/*'"
            log_error "Current branch: $current_branch"
            log_error "Please switch to 'main' or a 'release/*' branch, or use MSP_RELEASE_TIER=preflight for preflight releases"
            exit 1
        fi
        log_info "[MSP][ORCH] Production release: branch validation passed ($current_branch)"
    else
        log_info "[MSP][ORCH] Preflight release: no branch restriction (current: $current_branch)"
    fi
    
    log_info "Release orchestrator configuration:"
    log_info "  Version: $VERSION"
    log_info "  Base Branch: $BASE_BRANCH"
    log_info "  Release Branch: $RELEASE_BRANCH"
    log_info "  Dry Run: $DRY_RUN"
    log_info "  Pods Enabled: $([ "$SKIP_COCOAPODS" == "true" ] && echo "false" || echo "true")"
    log_info "  SPM Enabled: $([ "$SKIP_SPM" == "true" ] && echo "false" || echo "true")"
    if [[ -n "${PODS_MODULES:-}" ]]; then
        log_info "  Pods Modules: $PODS_MODULES"
    fi
    if [[ -n "${SPM_PACKAGES:-}" ]]; then
        log_info "  SPM Packages: $SPM_PACKAGES"
    fi
    log_info "  Skip Push: $SKIP_PUSH"
}

# Step 0: Pre-release setup (build frameworks)
pre_release_setup() {
    log_section "Step 0: Pre-release setup (building frameworks)"
    
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would run build scripts to ensure frameworks are up-to-date"
        return 0
    fi
    
    # Build all frameworks using the unified build script
    log_step "Building all frameworks using unified build script"
    
    # Use the xcframeworks build script
    local BUILD_SCRIPT="$ROOT_DIR/Scripts/xcframeworks/build-core.sh"
    if [[ ! -f "$BUILD_SCRIPT" ]]; then
        log_warn "Build script not found at $BUILD_SCRIPT, skipping framework build"
        log_info "Frameworks may need to be built manually before release"
        return 0
    fi
    
    if ! bash "$BUILD_SCRIPT"; then
        log_error "Failed to build frameworks"
        exit 1
    fi
    
    log_success "Pre-release setup completed successfully"
}

# Step 1: Create release branch
create_release_branch() {
    log_section "Step 1: Creating release branch"
    
    local create_branch_cmd="$ROOT_DIR/Scripts/release/orchestrator/branch.sh"
    if [[ "$DRY_RUN" == "true" ]]; then
        create_branch_cmd="$create_branch_cmd --dry-run"
    fi
    create_branch_cmd="$create_branch_cmd --base-branch $BASE_BRANCH $VERSION"
    
    log_info "Executing: $create_branch_cmd"
    
    if ! eval "$create_branch_cmd"; then
        log_error "Failed to create release branch"
        exit 1
    fi
    
    log_success "Release branch created successfully"
}

# Step 2: Release CocoaPods
release_cocoapods() {
    if [[ "$SKIP_COCOAPODS" == "true" ]]; then
        step_skip "release_cocoapods (SKIP_COCOAPODS=true)"
        return 0
    fi
    
    log_section "Step 2: Releasing CocoaPods"
    local current_mode="${MSP_RELEASE_MODE:-cli}"
    local current_mode_upper=$(echo "$current_mode" | tr '[:lower:]' '[:upper:]' 2>/dev/null || echo "${current_mode}" | awk '{print toupper($0)}')
    log_info "[MSP][ORCH] Mode: ${current_mode_upper} — releasing CocoaPods"
    
    # Checkout release branch (skip in dry-run mode)
    if [[ "$DRY_RUN" != "true" ]]; then
        git checkout "$RELEASE_BRANCH"
    fi
    
    # Export environment variables for cocoapods.sh
    # Child script should NOT parse CLI arguments, only use environment variables
    export RELEASE_VERSION="$VERSION"
    export RELEASE_BRANCH="$RELEASE_BRANCH"
    export DRY_RUN="$DRY_RUN"
    export VERBOSE="$VERBOSE"
    export PODS_MODULES="${PODS_MODULES:-}"
    export RELEASE_NOTES="${RELEASE_NOTES:-}"
    
    log_info "Calling cocoapods.sh with environment variables:"
    log_info "  RELEASE_VERSION=$RELEASE_VERSION"
    log_info "  RELEASE_BRANCH=$RELEASE_BRANCH"
    log_info "  PODS_MODULES=$PODS_MODULES"
    
    # Call pods/publish.sh directly (no CLI arguments)
    local COCOAPODS_SCRIPT="$ROOT_DIR/Scripts/release/publish/pods/publish.sh"
    if [[ ! -f "$COCOAPODS_SCRIPT" ]]; then
        log_error "CocoaPods publish script not found at $COCOAPODS_SCRIPT"
        return 1
    fi
    if bash "$COCOAPODS_SCRIPT"; then
        log_success "CocoaPods released successfully"
        # Track success based on PODS_MODULES if available
        if [[ "$DRY_RUN" != "true" && -n "${PODS_MODULES:-}" ]]; then
            # Split PODS_MODULES space-separated string into array
            for module in $PODS_MODULES; do
                COCOAPODS_SUCCESS+=("$module")
            done
        elif [[ "$DRY_RUN" != "true" ]]; then
            # Fallback to default list if PODS_MODULES not set
            COCOAPODS_SUCCESS+=("MSPSharedLibraries" "MSPFacebookAdapter" "MSPGoogleAdapter" "NovaAdapter" "AmazonAdapter" "MSPPrebidAdapter" "MSPCore")
        fi
    else
        log_error "Failed to release CocoaPods"
        OVERALL_SUCCESS="false"
        COCOAPODS_FAILED+=("CocoaPods release failed")
    fi
}

# Step 3: Release SPM
release_spm() {
    if [[ "$SKIP_SPM" == "true" ]]; then
        step_skip "release_spm (SKIP_SPM=true)"
        return 0
    fi
    
    log_section "Step 3: Releasing SPM"
    local current_mode="${MSP_RELEASE_MODE:-cli}"
    local current_mode_upper=$(echo "$current_mode" | tr '[:lower:]' '[:upper:]' 2>/dev/null || echo "${current_mode}" | awk '{print toupper($0)}')
    log_info "[MSP][ORCH] Mode: ${current_mode_upper} — releasing SPM"
    
    # Ensure we're on release branch (skip in dry-run mode)
    if [[ "$DRY_RUN" != "true" ]]; then
        git checkout "$RELEASE_BRANCH"
    fi
    
    # Export environment variables for spm.sh
    # Child script should NOT parse CLI arguments, only use environment variables
    export RELEASE_VERSION="$VERSION"
    export RELEASE_BRANCH="$RELEASE_BRANCH"
    export DRY_RUN="$DRY_RUN"
    export VERBOSE="$VERBOSE"
    export SPM_PACKAGES="${SPM_PACKAGES:-}"
    export RELEASE_NOTES="${RELEASE_NOTES:-}"
    
    log_info "Calling spm.sh with environment variables:"
    log_info "  RELEASE_VERSION=$RELEASE_VERSION"
    log_info "  RELEASE_BRANCH=$RELEASE_BRANCH"
    log_info "  SPM_PACKAGES=$SPM_PACKAGES"
    
    # Call spm/publish.sh directly (no CLI arguments)
    local SPM_SCRIPT="$ROOT_DIR/Scripts/release/publish/spm/publish.sh"
    if [[ ! -f "$SPM_SCRIPT" ]]; then
        log_error "SPM publish script not found at $SPM_SCRIPT"
        return 1
    fi
    if bash "$SPM_SCRIPT"; then
        log_success "SPM released successfully"
        # Track success based on SPM_PACKAGES if available
        if [[ "$DRY_RUN" != "true" && -n "${SPM_PACKAGES:-}" ]]; then
            # Split SPM_PACKAGES space-separated string into array
            for package in $SPM_PACKAGES; do
                SPM_SUCCESS+=("$package")
                # Module-level success notifications are disabled (now NO-OP)
            done
        elif [[ "$DRY_RUN" != "true" ]]; then
            # Fallback to default list if SPM_PACKAGES not set
            SPM_SUCCESS+=("NovaCore" "NovaAdapter")
            # Module-level success notifications are disabled (now NO-OP)
        fi
    else
        log_error "Failed to release SPM"
        OVERALL_SUCCESS="false"
        SPM_FAILED+=("SPM release failed")
    fi
}

# Step 4: Push release branch
push_release_branch() {
    # Config-driven gating
    if ! is_enabled "branch.push"; then
        step_skip "push_release_branch (config: branch.push=false)"
        return 0
    fi

    if [[ "$SKIP_PUSH" == "true" ]]; then
        step_skip "push_release_branch (SKIP_PUSH=true)"
        return 0
    fi
    
    log_section "Step 4: Pushing release branch"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would push release branch $RELEASE_BRANCH to remote"
        return 0
    fi
    
    # Ensure we're on release branch (skip in dry-run mode)
    if [[ "$DRY_RUN" != "true" ]]; then
        git checkout "$RELEASE_BRANCH"
    fi
    
    # Push release branch
    if git push origin "$RELEASE_BRANCH"; then
        log_success "Release branch pushed successfully"
        GITHUB_RELEASES_SUCCESS+=("Release branch $RELEASE_BRANCH")
        
        # Track release branch push in state
        if command -v msp_state_mark_git_flag &>/dev/null; then
            msp_state_mark_git_flag "release_branch_pushed" true
        fi
    else
        log_error "Failed to push release branch"
        OVERALL_SUCCESS="false"
        GITHUB_RELEASES_FAILED+=("Release branch $RELEASE_BRANCH")
    fi
}

# Show comprehensive release summary
show_comprehensive_release_summary() {
    print_section "Release Process Summary"
    
    # Calculate duration
    local duration=""
    if [[ -n "$RELEASE_START_TIME" && -n "$RELEASE_END_TIME" ]]; then
        local start_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$RELEASE_START_TIME" "+%s" 2>/dev/null || date -d "$RELEASE_START_TIME" "+%s" 2>/dev/null)
        local end_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$RELEASE_END_TIME" "+%s" 2>/dev/null || date -d "$RELEASE_END_TIME" "+%s" 2>/dev/null)
        if [[ -n "$start_epoch" && -n "$end_epoch" ]]; then
            local duration_seconds=$((end_epoch - start_epoch))
            local minutes=$((duration_seconds / 60))
            local seconds=$((duration_seconds % 60))
            duration="${minutes}m ${seconds}s"
        fi
    fi
    
    # Overall status
    if [[ "$OVERALL_SUCCESS" == "true" ]]; then
        log_success "🎉 Release $VERSION completed successfully!"
    else
        log_error "❌ Release $VERSION completed with errors"
    fi
    
    echo ""
    log_info "Release Details:"
    log_info "  Version: $VERSION"
    log_info "  Release Branch: $RELEASE_BRANCH"
    log_info "  Base Branch: $BASE_BRANCH"
    log_info "  Start Time: $RELEASE_START_TIME"
    log_info "  End Time: $RELEASE_END_TIME"
    if [[ -n "$duration" ]]; then
        log_info "  Duration: $duration"
    fi
    echo ""
    
    # CocoaPods Results
    if [[ "$SKIP_COCOAPODS" != "true" ]]; then
        print_subsection "CocoaPods Release Results"
        
        if [[ ${#COCOAPODS_SUCCESS[@]} -gt 0 ]]; then
            log_success "✅ Successfully Released:"
            for pod in "${COCOAPODS_SUCCESS[@]}"; do
                log_info "  - $pod"
            done
            echo ""
        fi
        
        if [[ ${#COCOAPODS_FAILED[@]} -gt 0 ]]; then
            log_error "❌ Failed to Release:"
            for pod in "${COCOAPODS_FAILED[@]}"; do
                log_info "  - $pod"
            done
            echo ""
        fi
    else
        log_info "CocoaPods release skipped (--skip-cocoapods flag)"
        echo ""
    fi
    
    # SPM Results
    if [[ "$SKIP_SPM" != "true" ]]; then
        print_subsection "SPM Release Results"
        
        if [[ ${#SPM_SUCCESS[@]} -gt 0 ]]; then
            log_success "✅ Successfully Released:"
            for package in "${SPM_SUCCESS[@]}"; do
                log_info "  - $package"
            done
            echo ""
        fi
        
        if [[ ${#SPM_FAILED[@]} -gt 0 ]]; then
            log_error "❌ Failed to Release:"
            for package in "${SPM_FAILED[@]}"; do
                log_info "  - $package"
            done
            echo ""
        fi
    else
        log_info "SPM release skipped (--skip-spm flag)"
        echo ""
    fi
    
    # GitHub Releases Results
    print_subsection "GitHub Releases Results"
    
    if [[ ${#GITHUB_RELEASES_SUCCESS[@]} -gt 0 ]]; then
        log_success "✅ Successfully Created:"
        for release in "${GITHUB_RELEASES_SUCCESS[@]}"; do
            log_info "  - $release"
        done
        echo ""
    fi
    
    if [[ ${#GITHUB_RELEASES_FAILED[@]} -gt 0 ]]; then
        log_error "❌ Failed to Create:"
        for release in "${GITHUB_RELEASES_FAILED[@]}"; do
            log_info "  - $release"
        done
        echo ""
    fi
    
    # Remote Verification Results
    print_subsection "Remote Verification"
    
    # SPM Remote Verification
    if [[ "${REMOTE_SPM_EXECUTED:-0}" == "1" ]]; then
        local spm_url="${MSP_VERIFY_SPM_URL:-N/A}"
        local spm_version="${MSP_VERIFY_SPM_VERSION:-N/A}"
        if [[ "${REMOTE_SPM_SUCCESS:-0}" == "1" ]]; then
            log_success "SPM:   PASS  (repo: $spm_url, version: $spm_version)"
        else
            log_error "SPM:   FAIL  (repo: $spm_url, version: $spm_version)"
        fi
    elif [[ -z "${MSP_VERIFY_SPM_URL:-}" ]] || [[ -z "${MSP_VERIFY_SPM_VERSION:-}" ]]; then
        log_info "SPM:   N/A   (not configured)"
    else
        log_info "SPM:   SKIPPED"
    fi
    
    # CocoaPods Remote Verification
    if [[ "${REMOTE_PODS_EXECUTED:-0}" == "1" ]]; then
        local pods_url="${MSP_VERIFY_PODS_URL:-N/A}"
        local pods_version="${MSP_VERIFY_PODS_VERSION:-N/A}"
        if [[ "${REMOTE_PODS_SUCCESS:-0}" == "1" ]]; then
            log_success "Pods:  PASS  (repo: $pods_url, version: $pods_version)"
        else
            log_error "Pods:  FAIL  (repo: $pods_url, version: $pods_version)"
        fi
    elif [[ -z "${MSP_VERIFY_PODS_URL:-}" ]] || [[ -z "${MSP_VERIFY_PODS_VERSION:-}" ]]; then
        log_info "Pods:  N/A   (not configured)"
    else
        log_info "Pods:  SKIPPED"
    fi
    echo ""
    
    # Local Verification Results
    print_subsection "Local Verification"
    
    if [[ "${LOCAL_VERIFY_EXECUTED:-0}" == "1" ]]; then
        local mode="${LOCAL_VERIFY_MODE:-unknown}"
        if [[ "${LOCAL_VERIFY_SUCCESS:-0}" == "1" ]]; then
            log_success "Executed: yes"
            log_success "Mode: $mode"
            log_success "Result: PASS"
        else
            log_info "Executed: yes"
            log_info "Mode: $mode"
            log_error "Result: FAIL"
        fi
    else
        log_info "Executed: no"
        log_info "Mode: N/A"
        log_info "Result: SKIPPED"
    fi
    echo ""
    
    # Device Verification Results
    print_subsection "Device Verification"
    
    if [[ "${DEVICE_VERIFY_EXECUTED:-0}" == "1" ]]; then
        local device_mode="${DEVICE_VERIFY_MODE:-unknown}"
        local archive_status="FAIL"
        local ipa_status="FAIL"
        
        if [[ -n "${DEVICE_VERIFY_ARCHIVE_PATH:-}" ]] && [[ -d "${DEVICE_VERIFY_ARCHIVE_PATH}" ]]; then
            archive_status="PASS"
        fi
        
        if [[ -n "${DEVICE_VERIFY_IPA_PATH:-}" ]] && [[ -f "${DEVICE_VERIFY_IPA_PATH}" ]]; then
            ipa_status="PASS"
        fi
        
        if [[ "${DEVICE_VERIFY_SUCCESS:-0}" == "1" ]]; then
            log_success "Executed: yes"
            log_success "Mode: $device_mode"
            log_success "Archive: $archive_status"
            log_success "IPA: $ipa_status"
        else
            log_info "Executed: yes"
            log_info "Mode: $device_mode"
            if [[ "$archive_status" == "PASS" ]]; then
                log_success "Archive: $archive_status"
            else
                log_error "Archive: $archive_status"
            fi
            if [[ "$ipa_status" == "PASS" ]]; then
                log_success "IPA: $ipa_status"
            else
                log_error "IPA: $ipa_status"
            fi
        fi
    else
        log_info "Executed: no"
        log_info "Mode: N/A"
        log_info "Archive: N/A"
        log_info "IPA: N/A"
    fi
    echo ""
    
    # XCFramework Verification Results
    print_subsection "XCFramework Verification"
    
    if [[ "${XCF_VERIFY_EXECUTED:-0}" == "1" ]]; then
        # Parse module results from JSON (if available)
        if [[ -n "${XCF_VERIFY_MODULES_JSON:-}" ]] && command -v jq >/dev/null 2>&1; then
            local modules
            modules="$(echo "$XCF_VERIFY_MODULES_JSON" | jq -r 'keys[]' 2>/dev/null || echo "")"
            if [[ -n "$modules" ]]; then
                while IFS= read -r module; do
                    local success
                    success="$(echo "$XCF_VERIFY_MODULES_JSON" | jq -r ".\"$module\".success" 2>/dev/null || echo "false")"
                    local warnings
                    warnings="$(echo "$XCF_VERIFY_MODULES_JSON" | jq -r ".\"$module\".warnings" 2>/dev/null || echo "0")"
                    
                    if [[ "$success" == "true" ]]; then
                        if [[ "$warnings" == "0" ]]; then
                            log_success "$module: PASS (0 warnings)"
                        else
                            log_success "$module: PASS ($warnings warnings)"
                        fi
                    else
                        log_error "$module: FAIL ($warnings warnings)"
                    fi
                done <<< "$modules"
            fi
        else
            log_info "Module results not available"
        fi
    else
        log_info "Executed: no"
    fi
    echo ""
    
    # Next Steps
    print_subsection "Next Steps"
    
    if [[ "$OVERALL_SUCCESS" == "true" ]]; then
        log_info "1. Verify the release on GitHub: https://github.com/ParticleMedia/msp-ios-sdk-public/releases/tag/$VERSION"
        log_info "2. Test CocoaPods installation: pod 'MSPCore', '~> $VERSION'"
        log_info "3. Test SPM installation: .package(url: \"https://github.com/ParticleMedia/msp-ios-sdk-public.git\", from: \"$VERSION\")"
        log_info "4. Create pull request to merge release branch if needed"
    else
        log_info "1. Review the failed components above"
        log_info "2. Fix any issues and retry the release"
        log_info "3. Check logs for detailed error information"
    fi
    echo ""
}

# Step 5: Run remote verification
run_remote_verification() {
    # Config-driven gating
    if ! is_enabled "verify.remote"; then
        log_info "[REMOTE] Skipping remote verification (config: verify.remote=false)"
        if command -v msp_state_mark_step_skipped &>/dev/null; then
            msp_state_mark_step_skipped "remote_verify_spm" "Skipped (config: verify.remote=false)"
            msp_state_mark_step_skipped "remote_verify_pods" "Skipped (config: verify.remote=false)"
        fi
        return 0
    fi
    # Check if remote verification is enabled (default: enabled)
    local verify_enabled="${MSP_REMOTE_VERIFY_ENABLED:-1}"
    if [[ "$verify_enabled" != "1" ]]; then
        log_info "Remote verification disabled (MSP_REMOTE_VERIFY_ENABLED != 1)"
        return 0
    fi
    
    log_section "Step 5: Remote Verification"
    
    # Source remote verification runner
    local verify_script="$ROOT_DIR/Scripts/release/verify_remote/run_all.sh"
    if [[ ! -f "$verify_script" ]]; then
        log_warn "Remote verification script not found, skipping"
        return 0
    fi
    
    # Run remote verification (soft-fail: never breaks release)
    if source "$verify_script" && run_all_remote_verification; then
        log_info "Remote verification completed"
    else
        log_warn "Remote verification encountered errors (non-blocking)"
    fi
    
    # Write remote verification results to state file
    if command -v msp_state_is_enabled &>/dev/null && msp_state_is_enabled; then
        local state_file
        state_file="$ROOT_DIR/.msp-release-state.json"
        if [[ -f "$state_file" ]] && command -v jq >/dev/null 2>&1; then
            # Update state with remote verification results
            local spm_executed="${REMOTE_SPM_EXECUTED:-0}"
            local spm_success="${REMOTE_SPM_SUCCESS:-0}"
            local pods_executed="${REMOTE_PODS_EXECUTED:-0}"
            local pods_success="${REMOTE_PODS_SUCCESS:-0}"
            
            jq ".remote_verify = {
                spm: {executed: ($spm_executed == 1), success: ($spm_success == 1)},
                pods: {executed: ($pods_executed == 1), success: ($pods_success == 1)}
            } | .timestamps.updated_at = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"" \
                "$state_file" > "${state_file}.tmp" 2>/dev/null && \
                mv "${state_file}.tmp" "$state_file" 2>/dev/null || true
        fi
    fi
    
    return 0
}

# Step 7: Run device verification
run_device_verification() {
    # Phase 3: Skip in CI mode
    if [[ "${MSP_SKIP_DEVICE_VERIFY:-false}" == "true" ]]; then
        log_info "[MSP][ORCH] Mode: CI — skipping device verification"
        return 0
    fi
    
    # Check if device verification is enabled (default: enabled)
    local verify_enabled="${MSP_DEVICE_VERIFY_ENABLED:-1}"
    if [[ "$verify_enabled" != "1" ]]; then
        log_info "Device verification disabled (MSP_DEVICE_VERIFY_ENABLED != 1)"
        return 0
    fi
    
    log_section "Step 7: Device Verification"
    log_info "[MSP][ORCH] Mode: CLI — running device verification"
    
    # Source device verification runner
    local verify_script="$ROOT_DIR/Scripts/release/verify_local_device/run_device.sh"
    if [[ ! -f "$verify_script" ]]; then
        log_warn "Device verification script not found, skipping"
        return 0
    fi
    
    # Run device verification (soft-fail: never breaks release)
    if source "$verify_script" && run_device_verification; then
        log_info "Device verification completed"
    else
        log_warn "Device verification encountered errors (non-blocking)"
    fi
    
    # Write device verification results to state file
    if command -v msp_state_is_enabled &>/dev/null && msp_state_is_enabled; then
        local state_file
        state_file="$ROOT_DIR/.msp-release-state.json"
        if [[ -f "$state_file" ]] && command -v jq >/dev/null 2>&1; then
            # Update state with device verification results
            local executed="${DEVICE_VERIFY_EXECUTED:-0}"
            local success="${DEVICE_VERIFY_SUCCESS:-0}"
            local mode="${DEVICE_VERIFY_MODE:-unknown}"
            local archive_path="${DEVICE_VERIFY_ARCHIVE_PATH:-}"
            local ipa_path="${DEVICE_VERIFY_IPA_PATH:-}"
            
            local mode_json
            mode_json="\"$mode\""
            local archive_json
            archive_json="\"$archive_path\""
            local ipa_json
            ipa_json="\"$ipa_path\""
            
            jq ".device_verify = {
                executed: ($executed == 1),
                success: ($success == 1),
                mode: $mode_json,
                archive_path: $archive_json,
                ipa_path: $ipa_json
            } | .timestamps.updated_at = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"" \
                "$state_file" > "${state_file}.tmp" 2>/dev/null && \
                mv "${state_file}.tmp" "$state_file" 2>/dev/null || true
        fi
    fi
    
    return 0
}

# Step 8: Run XCFramework deep verification
run_xcframework_verification() {
    local current_mode="${MSP_RELEASE_MODE:-cli}"
    local current_mode_upper=$(echo "$current_mode" | tr '[:lower:]' '[:upper:]' 2>/dev/null || echo "${current_mode}" | awk '{print toupper($0)}')
    
    # Phase 3: Skip if flag is set or xcodebuild not available
    if [[ "${MSP_SKIP_XCF_VERIFY:-false}" == "true" ]]; then
        log_info "[MSP][ORCH] Mode: ${current_mode_upper} — skipping XCF verify (xcodebuild not available)"
        return 0
    fi
    
    # Check if XCFramework verification is enabled (default: enabled)
    local verify_enabled="${MSP_XCF_VERIFY_ENABLED:-1}"
    if [[ "$verify_enabled" != "1" ]]; then
        log_info "XCFramework verification disabled (MSP_XCF_VERIFY_ENABLED != 1)"
        return 0
    fi
    
    # Check if xcodebuild exists
    if ! command -v xcodebuild >/dev/null 2>&1; then
        log_info "[MSP][ORCH] Mode: ${current_mode_upper} — xcodebuild not found, skipping XCF verify"
        return 0
    fi
    
    log_section "Step 8: XCFramework Deep Verification"
    log_info "[MSP][ORCH] Mode: ${current_mode_upper} — running XCF verify"
    
    # Source XCFramework verification runner
    local verify_script="$ROOT_DIR/Scripts/release/verify_xcframework/run_xcf.sh"
    if [[ ! -f "$verify_script" ]]; then
        log_warn "XCFramework verification script not found, skipping"
        return 0
    fi
    
    # Run XCFramework verification (soft-fail: never breaks release)
    if source "$verify_script" && run_xcframework_verification; then
        log_info "XCFramework verification completed"
    else
        log_warn "XCFramework verification encountered errors (non-blocking)"
    fi
    
    # Write XCFramework verification results to state file
    if command -v msp_state_is_enabled &>/dev/null && msp_state_is_enabled; then
        local state_file
        state_file="$ROOT_DIR/.msp-release-state.json"
        if [[ -f "$state_file" ]] && command -v jq >/dev/null 2>&1; then
            # Update state with XCFramework verification results
            local executed="${XCF_VERIFY_EXECUTED:-0}"
            local modules_json="${XCF_VERIFY_MODULES_JSON:-{}}"
            
            # Parse modules JSON and write to state
            jq ".xcframework_verify = {
                executed: ($executed == 1),
                modules: $modules_json
            } | .timestamps.updated_at = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"" \
                "$state_file" > "${state_file}.tmp" 2>/dev/null && \
                mv "${state_file}.tmp" "$state_file" 2>/dev/null || true
        fi
    fi
    
    return 0
}

# Error handler for state tracking
_handle_main_error() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        msp_state_mark_step_failed "run" "orchestrator failed (see logs)" "$exit_code" || true
    fi
    exit $exit_code
}

# Main function
main() {
    echo "[DIAG] ========================================" >&2
    echo "[DIAG] MAIN FUNCTION STARTED" >&2
    echo "[DIAG] ========================================" >&2
    echo "[DIAG] Starting main function" >&2
    echo "[DIAG] Current directory: $(pwd)" >&2
    echo "[DIAG] Shell: $0" >&2
    echo "[DIAG] PATH: $PATH" >&2
    echo "[DIAG] Arguments: $*" >&2
    # Set error trap for state tracking
    trap '_handle_main_error' ERR
    
    # Detect and log release mode
    local RELEASE_MODE
    RELEASE_MODE="$(_msp_release_get_mode)"
    echo "[MSP][ORCH] Release mode: ${RELEASE_MODE}"
    
    # Phase 4 TASK 4: Preflight / Production mode detection
    local RELEASE_TIER="${MSP_RELEASE_TIER:-preflight}"
    export MSP_RELEASE_TIER="$RELEASE_TIER"
    log_info "[TIER] Running in ${RELEASE_TIER} tier"
    
    # Load and log configuration (Patch M+CONFIG)
    if [[ -f "$ROOT_DIR/Scripts/release/lib/config.sh" ]]; then
        source "$ROOT_DIR/Scripts/release/lib/config.sh" 2>/dev/null || true
        msp_load_release_config 2>/dev/null || true
        
        local current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
        local allow_real="$(should_real_publish && echo true || echo false)"
        local allow_test="$(should_test_publish && echo true || echo false)"
        local allow_preflight="$(should_preflight_run && echo true || echo false)"
        
        log_info "[CONFIG] Branch: $current_branch"
        log_info "[CONFIG] allow_real_publish = $allow_real"
        log_info "[CONFIG] allow_test_publish = $allow_test"
        log_info "[CONFIG] allow_preflight = $allow_preflight"
        
        # Block real publish if not allowed
        if [[ "$RELEASE_TIER" != "preflight" ]] && ! should_real_publish; then
            log_error "[BLOCKED] Real publish not allowed on branch: $current_branch"
            log_error "[BLOCKED] Check Scripts/release/config/release_config.yaml for branch policy"
            exit 1
        fi
    fi
    log_info "[TIER] Running in ${RELEASE_TIER} tier"
    export MSP_RELEASE_TIER="$RELEASE_TIER"
    echo "[MSP][ORCH] Release tier: ${RELEASE_TIER}"
    
    # Phase 4 TASK 5: Security protection mechanisms
    log_section "Phase 4: Security Checks"
    
    # Check git working directory is clean
    # For preflight mode, allow uncommitted changes (warn only)
    if ! git diff --exit-code >/dev/null 2>&1 || ! git diff --cached --exit-code >/dev/null 2>&1; then
        if [[ "$RELEASE_TIER" == "preflight" ]]; then
            log_warn "[MSP][ORCH][WARN] Git working directory is not clean (preflight mode - continuing)"
            git status --short || true
        else
            log_error "[MSP][ORCH][ERROR] Git working directory is not clean"
            log_error "Please commit or stash all changes before releasing"
            git status --short || true
            exit 1
        fi
    else
        log_success "Git working directory is clean"
    fi
    
    # Check if tag exists (unless override allowed)
    if [[ -n "$VERSION" ]]; then
        if git rev-parse "v${VERSION}" >/dev/null 2>&1 || git rev-parse "$VERSION" >/dev/null 2>&1; then
            if [[ "${MSP_ALLOW_EXISTING_TAG:-0}" != "1" ]]; then
                log_error "[MSP][ORCH][ERROR] Tag already exists: $VERSION"
                log_error "Use MSP_ALLOW_EXISTING_TAG=1 to override (not recommended)"
                exit 1
            else
                log_warn "Tag $VERSION already exists (override allowed)"
            fi
        fi
    fi
    
    # Production release validation
    if [[ "$RELEASE_TIER" == "production" ]]; then
        # Version must be >= 1.0.0
        if [[ "$VERSION" =~ ^0\. ]]; then
            log_error "[MSP][ORCH][ERROR] Production release requires version >= 1.0.0"
            log_error "Current version: $VERSION"
            log_error "Use MSP_RELEASE_TIER=preflight for pre-release versions"
            exit 1
        fi
        
        # CI mode cannot do production releases
        if [[ "$RELEASE_MODE" == "ci" ]]; then
            log_error "[MSP][ORCH][ERROR] CI mode cannot perform production releases"
            log_error "Production releases must be done via CLI with manual confirmation"
            exit 1
        fi
        
        # CLI mode: require manual confirmation
        if [[ "$RELEASE_MODE" == "cli" ]] && [[ -t 0 ]]; then
            echo ""
            echo "═══════════════════════════════════════════════════════════════════"
            echo "⚠️  PRODUCTION RELEASE CONFIRMATION"
            echo "═══════════════════════════════════════════════════════════════════"
            echo "Version: $VERSION"
            echo "Branch: $(git rev-parse --abbrev-ref HEAD)"
            echo ""
            echo "This is a PRODUCTION release. All validations will be STRICT."
            echo "═══════════════════════════════════════════════════════════════════"
            echo ""
            read -p "[MSP][CLI] Confirm production release? (y/N): " confirm
            local confirm_upper=$(echo "$confirm" | tr '[:lower:]' '[:upper:]' 2>/dev/null || echo "$confirm" | awk '{print toupper($0)}')
            if [[ "$confirm_upper" != "Y" ]] && [[ "$confirm_upper" != "YES" ]]; then
                log_info "Production release cancelled by user"
                exit 0
            fi
        fi
    else
        # Preflight: version must be 0.x.y-* or 0.x.y-preflight*
        if [[ ! "$VERSION" =~ ^0\. ]] && [[ ! "$VERSION" =~ -preflight ]] && [[ ! "$VERSION" =~ -.* ]]; then
            log_warn "[MSP][ORCH] Preflight release with version >= 1.0.0: $VERSION"
            log_warn "Consider using MSP_RELEASE_TIER=production for production releases"
        fi
    fi
    
    # Phase 3: CI/CLI behavior differentiation
    local skip_local_verification=false
    local skip_device_verification=false
    local skip_pods_verification=false
    local skip_spm_local_build=false
    local skip_xcf_verify=false
    
    if [[ "$RELEASE_MODE" == "ci" ]]; then
        skip_local_verification=true
        skip_device_verification=true
        skip_pods_verification=true
        skip_spm_local_build=true
        
        # Check if xcodebuild exists for XCF verify
        if ! command -v xcodebuild >/dev/null 2>&1; then
            skip_xcf_verify=true
            echo "[MSP][ORCH] Mode: CI — xcodebuild not found, skipping XCF verify"
        fi
        
        # Check if pod exists for Pods verification
        if ! command -v pod >/dev/null 2>&1; then
            echo "[MSP][ORCH] Mode: CI — pod not found, skipping all Pods local verification"
        fi
        
        echo "[MSP][ORCH] Mode: CI — skipping local verification steps"
    else
        skip_local_verification=false
        skip_device_verification=false
        skip_pods_verification=false
        skip_spm_local_build=false
        echo "[MSP][ORCH] Mode: CLI — running full verification"
    fi
    
    # Export skip flags for use in verification functions
    export MSP_SKIP_LOCAL_VERIFY="$skip_local_verification"
    export MSP_SKIP_DEVICE_VERIFY="$skip_device_verification"
    export MSP_SKIP_PODS_VERIFY="$skip_pods_verification"
    export MSP_SKIP_SPM_LOCAL_BUILD="$skip_spm_local_build"
    export MSP_SKIP_XCF_VERIFY="$skip_xcf_verify"
    
    # Backward compatibility: parse remaining CLI arguments if any
    # (Only used if script is called directly, not via msp-release.sh)
    if [[ $# -gt 0 ]]; then
        parse_arguments "$@"
    fi
    
    # Validate inputs
    validate_inputs
    
    # Ensure we're in the project root
    ensure_project_root
    
    # Initialize state tracking
    msp_state_init "run"
    msp_state_mark_step_running "run"
    
    print_section "Starting Complete Release Process for Version: $VERSION"
    
    # Record start time
    RELEASE_START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Step 0: Pre-release setup (build frameworks)
    step "pre_release_setup"
    if pre_release_setup; then
        step_done "pre_release_setup"
    else
        # In preflight mode, allow pre_release_setup to fail gracefully
        if [[ "$RELEASE_TIER" == "preflight" ]]; then
            log_warn "Pre-release setup failed in preflight mode, continuing anyway"
            step_skip "pre_release_setup"
        else
            step_fail "pre_release_setup" $?
            return 10
        fi
    fi
    
    # Step 1: Create release branch
    step "create_release_branch"
    # In preflight mode, allow branch creation to fail gracefully
    # Check if we're already on a release branch or if skip flag is set
    local skip_branch_creation=false
    if [[ "${SKIP_CREATE_RELEASE_BRANCH:-false}" == "true" ]]; then
        skip_branch_creation=true
        log_warn "Skipping branch creation (--skip-create-release-branch flag set)"
    elif [[ "$RELEASE_TIER" == "preflight" ]]; then
        # In preflight, check if already on a release branch
        local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
        if [[ "$current_branch" =~ ^release/ ]]; then
            skip_branch_creation=true
            log_warn "Already on release branch '$current_branch', skipping branch creation in preflight mode"
        fi
    fi
    
    if [[ "$skip_branch_creation" == "true" ]]; then
        step_skip "create_release_branch"
    elif create_release_branch; then
        step_done "create_release_branch"
    else
        if [[ "$RELEASE_TIER" == "preflight" ]]; then
            log_warn "Branch creation failed in preflight mode, continuing anyway"
            step_skip "create_release_branch"
        else
            step_fail "create_release_branch" $?
            return 11
        fi
    fi
    
    # Step 2: Release CocoaPods
    step "release_cocoapods"
    if release_cocoapods; then
        step_done "release_cocoapods"
        if command -v msp_state_mark_step_success &>/dev/null; then
            msp_state_mark_step_success "release_cocoapods"
        fi
    else
        if is_preflight_tier; then
            log_warn "[ORCH] release_cocoapods failed in preflight tier (non-fatal)"
            step_skip "release_cocoapods (preflight soft-fail)"
            if command -v msp_state_mark_step_skipped &>/dev/null; then
                msp_state_mark_step_skipped "release_cocoapods" "Skipped in preflight tier"
            fi
        else
            step_fail "release_cocoapods" $?
            return 12
        fi
    fi
    
    # Step 3: Release SPM
    step "release_spm"
    if release_spm; then
        step_done "release_spm"
        if command -v msp_state_mark_step_success &>/dev/null; then
            msp_state_mark_step_success "release_spm"
        fi
    else
        if is_preflight_tier; then
            log_warn "[ORCH] release_spm failed in preflight tier (non-fatal)"
            step_skip "release_spm (preflight soft-fail)"
            if command -v msp_state_mark_step_skipped &>/dev/null; then
                msp_state_mark_step_skipped "release_spm" "Skipped in preflight tier"
            fi
        else
            step_fail "release_spm" $?
            return 13
        fi
    fi
    
    # Step 4: Push release branch
    step "push_release_branch"
    if push_release_branch; then
        step_done "push_release_branch"
    else
        step_fail "push_release_branch" $?
        return 14
    fi
    
    # Record end time
    RELEASE_END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Mark run as successful
    msp_state_mark_step_success "run"
    
    # Clear error trap on success
    trap - ERR
    
    # Show comprehensive summary
    show_comprehensive_release_summary
    
    # Step 5: Run remote verification (soft-fail, never breaks release)
    step "run_remote_verification"
    if run_remote_verification; then
        step_done "run_remote_verification"
    else
        step_fail "run_remote_verification" $?
        # Soft-fail: continue anyway
    fi
    
    # Step 6: Run local verification (soft-fail, never breaks release)
    step "run_local_verification"
    local release_mode_upper=$(echo "$RELEASE_MODE" | tr '[:lower:]' '[:upper:]' 2>/dev/null || echo "$RELEASE_MODE" | awk '{print toupper($0)}')
    if [[ "$MSP_SKIP_LOCAL_VERIFY" == "true" ]]; then
        echo "[MSP][ORCH] Mode: ${release_mode_upper} — skipping local verification"
        step_skip "run_local_verification (skipped in CI mode)"
    else
        local verify_script="$ROOT_DIR/Scripts/release/verify_local/run_local.sh"
        if [[ -f "$verify_script" ]]; then
            echo "[MSP][ORCH] Mode: ${release_mode_upper} — running local verification"
            if source "$verify_script" && run_local_verification; then
                step_done "run_local_verification"
            else
                step_fail "run_local_verification" $?
                # Soft-fail: continue anyway
            fi
        else
            step_skip "run_local_verification (script not found)"
        fi
    fi
    
    # Step 7: Run device verification (soft-fail, never breaks release)
    step "run_device_verification"
    if [[ "$MSP_SKIP_DEVICE_VERIFY" == "true" ]]; then
        echo "[MSP][ORCH] Mode: ${release_mode_upper} — skipping device verification"
        step_skip "run_device_verification (skipped in CI mode)"
    else
        if run_device_verification; then
            step_done "run_device_verification"
        else
            step_fail "run_device_verification" $?
            # Soft-fail: continue anyway
        fi
    fi
    
    # Step 8: Run XCFramework deep verification (soft-fail, never breaks release)
    step "run_xcframework_verification"
    if [[ "$MSP_SKIP_XCF_VERIFY" == "true" ]]; then
        echo "[MSP][ORCH] Mode: ${release_mode_upper} — skipping XCF verify"
        step_skip "run_xcframework_verification (skipped in CI mode or xcodebuild not available)"
    else
        if run_xcframework_verification; then
            step_done "run_xcframework_verification"
        else
            step_fail "run_xcframework_verification" $?
            # Soft-fail: continue anyway
        fi
    fi
    
    # Global success notifications (only if release succeeded)
    if [[ "$OVERALL_SUCCESS" == "true" ]]; then
        # Build module list from successful releases
        local module_list=""
        
        # Add CocoaPods modules
        if [[ ${#COCOAPODS_SUCCESS[@]} -gt 0 ]]; then
            for pod in "${COCOAPODS_SUCCESS[@]}"; do
                if [[ -z "$module_list" ]]; then
                    module_list="    - $pod"
                else
                    module_list="$module_list"$'\n'"    - $pod"
                fi
            done
        fi
        
        # Add SPM modules
        if [[ ${#SPM_SUCCESS[@]} -gt 0 ]]; then
            for package in "${SPM_SUCCESS[@]}"; do
                if [[ -z "$module_list" ]]; then
                    module_list="    - $package"
                else
                    module_list="$module_list"$'\n'"    - $package"
                fi
            done
        fi
        
        # If no modules, use placeholder
        if [[ -z "$module_list" ]]; then
            module_list="    - (none)"
        fi
        
        # Calculate duration for email
        local duration=""
        if [[ -n "$RELEASE_START_TIME" && -n "$RELEASE_END_TIME" ]]; then
            local start_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$RELEASE_START_TIME" "+%s" 2>/dev/null || date -d "$RELEASE_START_TIME" "+%s" 2>/dev/null)
            local end_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$RELEASE_END_TIME" "+%s" 2>/dev/null || date -d "$RELEASE_END_TIME" "+%s" 2>/dev/null)
            if [[ -n "$start_epoch" && -n "$end_epoch" ]]; then
                local duration_seconds=$((end_epoch - start_epoch))
                local minutes=$((duration_seconds / 60))
                local seconds=$((duration_seconds % 60))
                duration="${minutes}m ${seconds}s"
            fi
        fi
        
        # Build remote verification status for notifications
        local remote_status=""
        if [[ "${REMOTE_SPM_EXECUTED:-0}" == "1" ]]; then
            if [[ "${REMOTE_SPM_SUCCESS:-0}" == "1" ]]; then
                remote_status="    - SPM: PASS"
            else
                remote_status="    - SPM: FAIL"
            fi
        elif [[ -n "${MSP_VERIFY_SPM_URL:-}" ]] && [[ -n "${MSP_VERIFY_SPM_VERSION:-}" ]]; then
            remote_status="    - SPM: SKIPPED"
        fi
        
        if [[ "${REMOTE_PODS_EXECUTED:-0}" == "1" ]]; then
            if [[ "${REMOTE_PODS_SUCCESS:-0}" == "1" ]]; then
                if [[ -z "$remote_status" ]]; then
                    remote_status="    - Pods: PASS"
                else
                    remote_status="$remote_status"$'\n'"    - Pods: PASS"
                fi
            else
                if [[ -z "$remote_status" ]]; then
                    remote_status="    - Pods: FAIL"
                else
                    remote_status="$remote_status"$'\n'"    - Pods: FAIL"
                fi
            fi
        elif [[ -n "${MSP_VERIFY_PODS_URL:-}" ]] && [[ -n "${MSP_VERIFY_PODS_VERSION:-}" ]]; then
            if [[ -z "$remote_status" ]]; then
                remote_status="    - Pods: SKIPPED"
            else
                remote_status="$remote_status"$'\n'"    - Pods: SKIPPED"
            fi
        fi
        
        # Build local verification status for notifications
        local local_status=""
        if [[ "${LOCAL_VERIFY_EXECUTED:-0}" == "1" ]]; then
            local mode="${LOCAL_VERIFY_MODE:-unknown}"
            if [[ "${LOCAL_VERIFY_SUCCESS:-0}" == "1" ]]; then
                local_status="    - Local ($mode): PASS"
            else
                local_status="    - Local ($mode): FAIL"
            fi
        fi
        
        # Build XCFramework verification status for notifications
        local xcf_status=""
        if [[ "${XCF_VERIFY_EXECUTED:-0}" == "1" ]] && [[ -n "${XCF_VERIFY_MODULES_JSON:-}" ]] && command -v jq >/dev/null 2>&1; then
            local modules
            modules="$(echo "${XCF_VERIFY_MODULES_JSON}" | jq -r 'keys[]' 2>/dev/null || echo "")"
            if [[ -n "$modules" ]]; then
                while IFS= read -r module; do
                    local success
                    success="$(echo "${XCF_VERIFY_MODULES_JSON}" | jq -r ".\"$module\".success" 2>/dev/null || echo "false")"
                    local warnings
                    warnings="$(echo "${XCF_VERIFY_MODULES_JSON}" | jq -r ".\"$module\".warnings" 2>/dev/null || echo "0")"
                    
                    local module_status=""
                    if [[ "$success" == "true" ]]; then
                        if [[ "$warnings" == "0" ]]; then
                            module_status="    - XCFramework $module: PASS"
                        else
                            module_status="    - XCFramework $module: WARN ($warnings warnings)"
                        fi
                    else
                        module_status="    - XCFramework $module: FAIL"
                    fi
                    
                    if [[ -z "$xcf_status" ]]; then
                        xcf_status="$module_status"
                    else
                        xcf_status="$xcf_status"$'\n'"$module_status"
                    fi
                done <<< "$modules"
            fi
        fi
        
        # Combine verification status
        local verify_status="$remote_status"
        if [[ -n "$local_status" ]]; then
            if [[ -z "$verify_status" ]]; then
                verify_status="$local_status"
            else
                verify_status="$verify_status"$'\n'"$local_status"
            fi
        fi
        if [[ -n "$device_status" ]]; then
            if [[ -z "$verify_status" ]]; then
                verify_status="$device_status"
            else
                verify_status="$verify_status"$'\n'"$device_status"
            fi
        fi
        if [[ -n "$xcf_status" ]]; then
            if [[ -z "$verify_status" ]]; then
                verify_status="$xcf_status"
            else
                verify_status="$verify_status"$'\n'"$xcf_status"
            fi
        fi
        
        # Export combined status for notifications
        export REMOTE_VERIFY_STATUS="$verify_status"
        
        # Build unified notification data (JSON)
        build_notify_data_json() {
            # Build modules JSON
            local modules_json="{"
            local first_module=1
            if [[ ${#COCOAPODS_SUCCESS[@]} -gt 0 ]]; then
                for pod in "${COCOAPODS_SUCCESS[@]}"; do
                    if [[ $first_module -eq 1 ]]; then
                        first_module=0
                    else
                        modules_json="$modules_json,"
                    fi
                    modules_json="$modules_json\"$pod\":\"$VERSION\""
                done
            fi
            if [[ ${#SPM_SUCCESS[@]} -gt 0 ]]; then
                for package in "${SPM_SUCCESS[@]}"; do
                    if [[ $first_module -eq 1 ]]; then
                        first_module=0
                    else
                        modules_json="$modules_json,"
                    fi
                    modules_json="$modules_json\"$package\":\"$VERSION\""
                done
            fi
            modules_json="$modules_json}"
            
            # Build remote verification JSON
            local remote_verify_json="{"
            local first_remote=1
            if [[ "${REMOTE_SPM_EXECUTED:-0}" == "1" ]]; then
                first_remote=0
                remote_verify_json="$remote_verify_json\"spm\":{\"executed\":true,\"success\":$([[ "${REMOTE_SPM_SUCCESS:-0}" == "1" ]] && echo "true" || echo "false"),\"url\":\"${MSP_VERIFY_SPM_URL:-}\",\"version\":\"${MSP_VERIFY_SPM_VERSION:-}\"}"
            fi
            if [[ "${REMOTE_PODS_EXECUTED:-0}" == "1" ]]; then
                if [[ $first_remote -eq 0 ]]; then
                    remote_verify_json="$remote_verify_json,"
                fi
                remote_verify_json="$remote_verify_json\"pods\":{\"executed\":true,\"success\":$([[ "${REMOTE_PODS_SUCCESS:-0}" == "1" ]] && echo "true" || echo "false"),\"url\":\"${MSP_VERIFY_PODS_URL:-}\",\"version\":\"${MSP_VERIFY_PODS_VERSION:-}\"}"
            fi
            remote_verify_json="$remote_verify_json}"
            
            # Build local verification JSON
            local local_verify_json="{"
            local_verify_json="$local_verify_json\"executed\":$([[ "${LOCAL_VERIFY_EXECUTED:-0}" == "1" ]] && echo "true" || echo "false"),"
            local_verify_json="$local_verify_json\"success\":$([[ "${LOCAL_VERIFY_SUCCESS:-0}" == "1" ]] && echo "true" || echo "false"),"
            local_verify_json="$local_verify_json\"mode\":\"${LOCAL_VERIFY_MODE:-unknown}\""
            local_verify_json="$local_verify_json}"
            
            # Build device verification JSON
            local device_verify_json="{"
            device_verify_json="$device_verify_json\"executed\":$([[ "${DEVICE_VERIFY_EXECUTED:-0}" == "1" ]] && echo "true" || echo "false"),"
            device_verify_json="$device_verify_json\"success\":$([[ "${DEVICE_VERIFY_SUCCESS:-0}" == "1" ]] && echo "true" || echo "false"),"
            device_verify_json="$device_verify_json\"mode\":\"${DEVICE_VERIFY_MODE:-unknown}\","
            device_verify_json="$device_verify_json\"archive\":\"$([[ -n "${DEVICE_VERIFY_ARCHIVE_PATH:-}" ]] && echo "pass" || echo "fail")\","
            device_verify_json="$device_verify_json\"ipa\":\"$([[ -n "${DEVICE_VERIFY_IPA_PATH:-}" ]] && echo "pass" || echo "fail")\""
            device_verify_json="$device_verify_json}"
            
            # Build XCFramework verification JSON
            local xcf_verify_json="{"
            xcf_verify_json="$xcf_verify_json\"executed\":$([[ "${XCF_VERIFY_EXECUTED:-0}" == "1" ]] && echo "true" || echo "false"),"
            xcf_verify_json="$xcf_verify_json\"modules\":${XCF_VERIFY_MODULES_JSON:-{}}"
            xcf_verify_json="$xcf_verify_json}"
            
            # Build failure JSON
            local failure_json="{"
            failure_json="$failure_json\"occurred\":false"
            failure_json="$failure_json}"
            
            # Combine into final JSON
            local notify_data
            notify_data=$(cat <<EOF
{
  "version": "$VERSION",
  "author": "${MSP_AUTHOR_EMAIL:-unknown}",
  "duration": "${duration:-unknown}",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "modules": $modules_json,
  "remote_verify": $remote_verify_json,
  "local_verify": $local_verify_json,
  "device_verify": $device_verify_json,
  "xcframework_verify": $xcf_verify_json,
  "failure": $failure_json
}
EOF
)
            export NOTIFY_DATA_JSON="$notify_data"
        }
        
        # Build notification data
        build_notify_data_json
        
        # Send unified notifications via clean API
        if command -v notify::send_release_summary &>/dev/null; then
            source "${ROOT_DIR:-.}/Scripts/notify/notify_core.sh" 2>/dev/null || true
            notify::send_release_summary "$NOTIFY_DATA_JSON" || true
        else
            # Fallback to old notification system if new API not available
            if command -v notify::release_success_dm &>/dev/null; then
                notify::release_success_dm "$VERSION" || true
            fi
            if command -v notify::release_success_channel &>/dev/null; then
                notify::release_success_channel "$VERSION" || true
            fi
            if command -v notify::email::send_success_email &>/dev/null; then
                notify::email::send_success_email "$VERSION" "${MSP_AUTHOR_EMAIL:-unknown}" "$module_list" "${duration:-unknown}" "${REMOTE_VERIFY_STATUS:-}" || true
            fi
        fi
    fi
    
    # Task 4: Generate release.md report (always, even if some steps failed)
    log_step "Generating release markdown report"
    local report_generator="$ROOT_DIR/Scripts/release/generate_release_md.sh"
    local state_file="$ROOT_DIR/.msp-release-state.json"
    local report_file="$ROOT_DIR/Releases/release-$VERSION.md"
    
    if [[ ! -f "$report_generator" ]]; then
        log_warn "Report generator not found: $report_generator"
    elif [[ ! -f "$state_file" ]]; then
        log_warn "State file not found: $state_file (release.md will not be generated)"
    else
        log_info "Generating release report: Releases/release-$VERSION.md"
        if bash "$report_generator" \
            --state-file "$state_file" \
            --output "$report_file" 2>&1; then
            if [[ -f "$report_file" ]]; then
                log_success "Release report generated: Releases/release-$VERSION.md"
            else
                log_warn "Report generation completed but file not found: $report_file"
            fi
    else
        log_warn "Report generation failed (soft-fail, continuing)"
    fi
fi

}

# Entry point
# If RELEASE_VERSION is set from environment (via msp-release.sh), use it directly
# Otherwise, require CLI arguments for backward compatibility
if [[ -z "${RELEASE_VERSION:-}" && $# -eq 0 ]]; then
echo "[DIAG] About to call main" >&2
echo "[DIAG] RELEASE_VERSION=${RELEASE_VERSION:-}" >&2
echo "[DIAG] VERSION=${VERSION:-}" >&2
echo "[DIAG] Arguments: $*" >&2
    show_help
    exit 1
fi

# Run main function with all arguments
main "$@"
