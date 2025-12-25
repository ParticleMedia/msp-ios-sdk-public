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
# Config-driven gating is now standard - no need for tier helper checks
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

# Source safety checks for Release tier protections
if [[ -f "$ROOT_DIR/Scripts/release/utils/safety.sh" ]]; then
    source "$ROOT_DIR/Scripts/release/utils/safety.sh" 2>/dev/null || true
fi

# Source unified logging system (if not already loaded)
if [[ -f "$ROOT_DIR/Scripts/release/utils/logger.sh" ]]; then
    source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true
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
    local full_msg="$1"
    echo "[CI][STEP] $full_msg: SKIPPED" >&2

    # Extract step name and reason from format: "step_name (reason)"
    if [[ "$full_msg" =~ ^([a-z_]+)[[:space:]]*\((.+)\)[[:space:]]*$ ]]; then
        local step_name="${BASH_REMATCH[1]}"
        local reason="${BASH_REMATCH[2]}"

        # Record in state.json
        if command -v msp_state_mark_step_skipped &>/dev/null; then
            msp_state_mark_step_skipped "$step_name" "$reason"
        fi
    fi
}

# ============================================================================
# Unified Step Lifecycle API
# ============================================================================

mark_step_start() {
    local step="$1"
    if command -v msp_state_mark_step_running &>/dev/null; then
        msp_state_mark_step_running "$step"
    fi
}

mark_step_success() {
    local step="$1"
    if command -v msp_state_mark_step_success &>/dev/null; then
        msp_state_mark_step_success "$step"
    fi
}

mark_step_error() {
    local step="$1"
    local reason="$2"
    if command -v msp_state_mark_step_failed &>/dev/null; then
        msp_state_mark_step_failed "$step" "$reason"
    fi
}

mark_step_skipped() {
    local step="$1"
    local reason="$2"
    if command -v msp_state_mark_step_skipped &>/dev/null; then
        msp_state_mark_step_skipped "$step" "$reason"
    fi
}

# Unified Error Model
fail_step() {
    local step="$1"
    local reason="$2"

    log_error "[ERROR] Step '$step' failed: $reason"
    mark_step_error "$step" "$reason"

    # Check if fail_fast is enabled (default: true)
    if is_enabled "behavior.fail_fast" 2>/dev/null || [[ "${MSP_FAIL_FAST:-true}" == "true" ]]; then
        return 1
    fi

    return 1
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
    # OR: bash modular.sh <VERSION> [OPTIONS...] (when called from msp-release.sh resume)
    if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
        # Check if first argument looks like a version (contains dots or dashes)
        # If it does, treat it as VERSION directly (resume mode from msp-release.sh)
        if [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
            # First argument is VERSION (e.g., "0.3.0-rc.13")
            RELEASE_VERSION="$1"
            shift
        else
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
    log_info "  Pods Enabled: $(is_enabled "pods.enabled" && echo "true" || echo "false")"
    log_info "  SPM Enabled: $(is_enabled "spm.enabled" && echo "true" || echo "false")"
    log_info "  Verify Local: $(is_enabled "verify.local" && echo "true" || echo "false")"
    log_info "  Verify Remote: $(is_enabled "verify.remote" && echo "true" || echo "false")"
    log_info "  Verify XCFramework: $(is_enabled "verify.xcframework" && echo "true" || echo "false")"
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
    export CURRENT_STEP="pre_release_setup"
    mark_step_start "pre_release_setup"
    log_section "Step 0: Pre-release setup (building frameworks)"


    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would run build scripts to ensure frameworks are up-to-date"
        mark_step_success "pre_release_setup"
        return 0
    fi

    # Build all frameworks using the unified build script
    log_step "Building all frameworks using unified build script"

    # Use the xcframeworks build script
    local BUILD_SCRIPT="$ROOT_DIR/Scripts/xcframeworks/build-core.sh"
    if [[ ! -f "$BUILD_SCRIPT" ]]; then
        log_warn "Build script not found at $BUILD_SCRIPT, skipping framework build"
        log_info "Frameworks may need to be built manually before release"
        mark_step_success "pre_release_setup"
        return 0
    fi

    if ! bash "$BUILD_SCRIPT"; then
        fail_step "pre_release_setup" "framework build failed"
        return 1
    fi

    log_success "Pre-release setup completed successfully"
    mark_step_success "pre_release_setup"
}

# Step 1: Create release branch
create_release_branch() {
    # Config-driven gating
    if ! is_enabled "branch.create"; then
        step_skip "create_release_branch (config: branch.create=false)"
        return 0
    fi

    export CURRENT_STEP="create_release_branch"
    mark_step_start "create_release_branch"
    log_section "Step 1: Creating release branch"

    local create_branch_cmd="$ROOT_DIR/Scripts/release/orchestrator/branch.sh"
    if [[ "$DRY_RUN" == "true" ]]; then
        create_branch_cmd="$create_branch_cmd --dry-run"
    fi
    create_branch_cmd="$create_branch_cmd --base-branch $BASE_BRANCH $VERSION"

    log_info "Executing: $create_branch_cmd"

    if ! eval "$create_branch_cmd"; then
        fail_step "create_release_branch" "branch creation script failed"
        return 1
    fi

    log_success "Release branch created successfully"
    mark_step_success "create_release_branch"
}

# Step 2: Release CocoaPods
release_cocoapods() {
    # Step-C: Hard protection - config-driven gating
    if ! is_enabled "pods.enabled"; then
        step_skip "release_cocoapods (config: pods.enabled=false)"
        return 0
    fi

    if [[ "$SKIP_COCOAPODS" == "true" ]]; then
        step_skip "release_cocoapods (CLI: --skip-cocoapods)"
        return 0
    fi

    export CURRENT_STEP="release_cocoapods"
    mark_step_start "release_cocoapods"
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
        fail_step "release_cocoapods" "publish script not found at $COCOAPODS_SCRIPT"
        return 1
    fi
    if bash "$COCOAPODS_SCRIPT"; then
        log_success "CocoaPods released successfully"
        mark_step_success "release_cocoapods"

        # Auto-configure Pods remote verification environment variables
        if [[ "$DRY_RUN" != "true" ]]; then
            local github_url
            github_url="$(git remote get-url origin 2>/dev/null || echo "")"

            # Convert git@ format to https://
            if [[ "$github_url" =~ ^git@github\.com:(.+)\.git$ ]]; then
                github_url="https://github.com/${BASH_REMATCH[1]}"
            elif [[ "$github_url" =~ ^git@github\.com:(.+)$ ]]; then
                github_url="https://github.com/${BASH_REMATCH[1]}"
            fi

            # Remove .git suffix
            github_url="${github_url%.git}"

            if [[ -n "$github_url" && -n "$VERSION" ]]; then
                export MSP_VERIFY_PODS_URL="$github_url"
                export MSP_VERIFY_PODS_VERSION="$VERSION"
                log_info "[VERIFY] Auto-configured Pods verification: $github_url @ $VERSION"
            else
                log_warn "[VERIFY] Could not auto-configure Pods verification"
            fi
        fi

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
        fail_step "release_cocoapods" "publish script execution failed"
        OVERALL_SUCCESS="false"
        COCOAPODS_FAILED+=("CocoaPods release failed")
        return 1
    fi
}

# Step 3: Release SPM
release_spm() {
    # Step-C: Hard protection - config-driven gating
    if ! is_enabled "spm.enabled"; then
        step_skip "release_spm (config: spm.enabled=false)"
        return 0
    fi

    if [[ "$SKIP_SPM" == "true" ]]; then
        step_skip "release_spm (CLI: --skip-spm)"
        return 0
    fi

    export CURRENT_STEP="release_spm"
    mark_step_start "release_spm"
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
        fail_step "release_spm" "publish script not found at $SPM_SCRIPT"
        return 1
    fi
    if bash "$SPM_SCRIPT"; then
        log_success "SPM released successfully"
        mark_step_success "release_spm"

        # Auto-configure SPM remote verification environment variables
        if [[ "$DRY_RUN" != "true" ]]; then
            local github_url
            github_url="$(git remote get-url origin 2>/dev/null || echo "")"

            # Convert git@ format to https://
            if [[ "$github_url" =~ ^git@github\.com:(.+)\.git$ ]]; then
                github_url="https://github.com/${BASH_REMATCH[1]}"
            elif [[ "$github_url" =~ ^git@github\.com:(.+)$ ]]; then
                github_url="https://github.com/${BASH_REMATCH[1]}"
            fi

            # Remove .git suffix
            github_url="${github_url%.git}"

            if [[ -n "$github_url" && -n "$VERSION" ]]; then
                export MSP_VERIFY_SPM_URL="$github_url"
                export MSP_VERIFY_SPM_VERSION="$VERSION"
                log_info "[VERIFY] Auto-configured SPM verification: $github_url @ $VERSION"
            else
                log_warn "[VERIFY] Could not auto-configure SPM verification"
            fi
        fi

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
        fail_step "release_spm" "publish script execution failed"
        OVERALL_SUCCESS="false"
        SPM_FAILED+=("SPM release failed")
        return 1
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
        step_skip "push_release_branch (CLI: --skip-push)"
        return 0
    fi

    export CURRENT_STEP="push_release_branch"
    mark_step_start "push_release_branch"
    log_section "Step 4: Pushing release branch"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would push release branch $RELEASE_BRANCH to remote"
        mark_step_success "push_release_branch"
        return 0
    fi

    # Ensure we're on release branch (skip in dry-run mode)
    if [[ "$DRY_RUN" != "true" ]]; then
        git checkout "$RELEASE_BRANCH"
    fi

    # Push release branch
    if git push origin "$RELEASE_BRANCH"; then
        log_success "Release branch pushed successfully"
        mark_step_success "push_release_branch"
        GITHUB_RELEASES_SUCCESS+=("Release branch $RELEASE_BRANCH")

        # Track release branch push in state
        if command -v msp_state_mark_git_flag &>/dev/null; then
            msp_state_mark_git_flag "release_branch_pushed" true
        fi
    else
        fail_step "push_release_branch" "git push failed"
        OVERALL_SUCCESS="false"
        GITHUB_RELEASES_FAILED+=("Release branch $RELEASE_BRANCH")
        return 1
    fi
}

# Print a single step summary line
print_step_summary() {
    local step_num="$1"
    local step_name="$2"
    local description="$3"

    local status="unknown"
    local reason=""

    # Try to get status from state.json
    if command -v msp_state_get_step_status &>/dev/null; then
        status=$(msp_state_get_step_status "$step_name" 2>/dev/null || echo "unknown")

        # Get notes/reason from state.json
        if command -v jq &>/dev/null && msp_state_is_enabled 2>/dev/null; then
            local state_file
            state_file="$ROOT_DIR/.msp-release-state.json"
            if [[ -f "$state_file" ]]; then
                reason=$(jq -r ".steps[\"$step_name\"].notes // \"\"" "$state_file" 2>/dev/null || echo "")
            fi
        fi
    fi

    # Format the output line
    if [[ "$status" == "skipped" ]]; then
        if [[ -n "$reason" ]]; then
            printf "  Step %-2s: %-28s SKIP (%s)\n" "$step_num" "$description" "$reason"
        else
            printf "  Step %-2s: %-28s SKIP\n" "$step_num" "$description"
        fi
    elif [[ "$status" == "success" ]]; then
        printf "  Step %-2s: %-28s RUN (success)\n" "$step_num" "$description"
    elif [[ "$status" == "error" ]] || [[ "$status" == "failed" ]]; then
        if [[ -n "$reason" ]]; then
            printf "  Step %-2s: %-28s RUN (error: %s)\n" "$step_num" "$description" "$reason"
        else
            printf "  Step %-2s: %-28s RUN (error)\n" "$step_num" "$description"
        fi
    elif [[ "$status" == "running" ]]; then
        printf "  Step %-2s: %-28s RUNNING\n" "$step_num" "$description"
    else
        printf "  Step %-2s: %-28s UNKNOWN\n" "$step_num" "$description"
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

    # Step-by-Step Execution Summary
    print_subsection "Step Execution Summary"
    print_step_summary "0" "pre_release_setup" "Pre-release Setup"
    print_step_summary "1" "create_release_branch" "Create Release Branch"
    print_step_summary "2" "release_cocoapods" "Release CocoaPods"
    print_step_summary "3" "release_spm" "Release SPM"
    print_step_summary "4" "push_release_branch" "Push Release Branch"
    print_step_summary "5" "run_remote_verification" "Remote Verification"
    print_step_summary "6" "run_local_verification" "Local Verification"
    print_step_summary "7" "run_device_verification" "Device Verification"
    print_step_summary "8" "run_xcframework_verification" "XCFramework Verification"
    echo ""

    # CocoaPods Module Results (if executed)
    if is_enabled "pods.enabled" && [[ "$SKIP_COCOAPODS" != "true" ]]; then
        print_subsection "CocoaPods Module Results"

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
    fi

    # SPM Module Results (if executed)
    if is_enabled "spm.enabled" && [[ "$SKIP_SPM" != "true" ]]; then
        print_subsection "SPM Module Results"

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

    # Read status from state.json
    local local_status="unknown"
    if command -v jq >/dev/null 2>&1 && [[ -f "$ROOT_DIR/.msp-release-state.json" ]]; then
        local_status="$(jq -r '.steps.run_local_verification.status // "unknown"' "$ROOT_DIR/.msp-release-state.json" 2>/dev/null || echo "unknown")"
    fi

    if [[ "$local_status" == "success" ]]; then
        log_success "Executed: yes"
        log_success "Result: PASS"
    elif [[ "$local_status" == "error" ]] || [[ "$local_status" == "failed" ]]; then
        log_info "Executed: yes"
        log_error "Result: FAIL"
    elif [[ "$local_status" == "skipped" ]]; then
        log_info "Executed: no"
        log_info "Result: SKIPPED"
    else
        log_info "Executed: no"
        log_info "Mode: N/A"
        log_info "Result: SKIPPED"
    fi
    echo ""
    
    # Device Verification Results
    print_subsection "Device Verification"

    # Read status from state.json
    local device_status="unknown"
    if command -v jq >/dev/null 2>&1 && [[ -f "$ROOT_DIR/.msp-release-state.json" ]]; then
        device_status="$(jq -r '.steps.run_device_verification.status // "unknown"' "$ROOT_DIR/.msp-release-state.json" 2>/dev/null || echo "unknown")"
    fi

    if [[ "$device_status" == "success" ]]; then
        log_success "Executed: yes"
        log_success "Result: PASS"
    elif [[ "$device_status" == "error" ]] || [[ "$device_status" == "failed" ]]; then
        log_info "Executed: yes"
        log_error "Result: FAIL"
    elif [[ "$device_status" == "skipped" ]]; then
        log_info "Executed: no"
        log_info "Result: SKIPPED"
    else
        log_info "Executed: no"
        log_info "Mode: N/A"
        log_info "Archive: N/A"
        log_info "IPA: N/A"
    fi
    echo ""
    
    # XCFramework Verification Results
    print_subsection "XCFramework Verification"

    # Read status and modules from state.json
    local xcf_status="unknown"
    local state_file="$ROOT_DIR/.msp-release-state.json"
    if command -v jq >/dev/null 2>&1 && [[ -f "$state_file" ]]; then
        xcf_status="$(jq -r '.steps.run_xcframework_verification.status // "unknown"' "$state_file" 2>/dev/null || echo "unknown")"
    fi

    if [[ "$xcf_status" == "success" ]] || [[ "$xcf_status" == "error" ]] || [[ "$xcf_status" == "failed" ]]; then
        log_info "Executed: yes"
        if [[ "$xcf_status" == "success" ]]; then
            log_success "Result: PASS"
        else
            log_error "Result: FAIL"
        fi

        # Read summary stats from state.json
        if command -v jq >/dev/null 2>&1 && [[ -f "$state_file" ]]; then
            local total_modules
            local passed_modules
            local failed_modules
            total_modules="$(jq -r '.steps.run_xcframework_verification.summary.total // 0' "$state_file" 2>/dev/null || echo "0")"
            passed_modules="$(jq -r '.steps.run_xcframework_verification.summary.passed // 0' "$state_file" 2>/dev/null || echo "0")"
            failed_modules="$(jq -r '.steps.run_xcframework_verification.summary.failed // 0' "$state_file" 2>/dev/null || echo "0")"

            if [[ "$total_modules" != "0" ]]; then
                log_info "Summary: $passed_modules passed, $failed_modules failed (total: $total_modules)"

                # Show top 5 failed modules with details
                if [[ "$failed_modules" != "0" ]]; then
                    echo ""
                    log_info "Failed modules (showing up to 5):"
                    local modules
                    modules="$(jq -r '.steps.run_xcframework_verification.modules | to_entries[] | select(.value.success == 0) | .key' "$state_file" 2>/dev/null || echo "")"
                    if [[ -n "$modules" ]]; then
                        local count=0
                        while IFS= read -r module && [[ $count -lt 5 ]]; do
                            local failed_scans
                            failed_scans="$(jq -r ".steps.run_xcframework_verification.modules[\"$module\"].failed_scans | join(\", \")" "$state_file" 2>/dev/null || echo "unknown")"
                            if [[ -n "$failed_scans" ]] && [[ "$failed_scans" != "null" ]] && [[ "$failed_scans" != "" ]]; then
                                log_error "  - $module: failed scans: $failed_scans"
                            else
                                log_error "  - $module"
                            fi
                            count=$((count + 1))
                        done <<< "$modules"

                        if [[ "$failed_modules" -gt 5 ]]; then
                            local remaining=$((failed_modules - 5))
                            log_info "  ... and $remaining more"
                        fi
                    fi
                fi
            fi
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
    export CURRENT_STEP="run_remote_verification"
    # Config-driven gating
    if ! is_enabled "verify.remote"; then
        step_skip "run_remote_verification (config: verify.remote=false)"
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
    export CURRENT_STEP="run_device_verification"
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
            # Read status from state.json instead of env vars
            local device_status
            device_status="$(jq -r '.steps.run_device_verification.status // "unknown"' "$state_file" 2>/dev/null || echo "unknown")"

            # Map status to executed/success booleans
            local executed=false
            local success=false
            if [[ "$device_status" == "success" ]]; then
                executed=true
                success=true
            elif [[ "$device_status" == "error" ]] || [[ "$device_status" == "failed" ]]; then
                executed=true
                success=false
            fi

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
                executed: $executed,
                success: $success,
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
    export CURRENT_STEP="run_xcframework_verification"
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
            # Read modules data from environment (populated by run_xcf.sh)
            local modules_json="${XCF_VERIFY_MODULES_JSON:-{}}"

            # Calculate summary stats if modules data exists
            local total_modules=0
            local passed_modules=0
            local failed_modules=0
            if [[ -n "$modules_json" ]] && [[ "$modules_json" != "{}" ]]; then
                total_modules=$(echo "$modules_json" | jq 'length' 2>/dev/null || echo "0")
                passed_modules=$(echo "$modules_json" | jq '[.[] | select(.success == 1)] | length' 2>/dev/null || echo "0")
                # Clean whitespace and ensure numeric values
                total_modules=$(echo "${total_modules}" | tr -d '[:space:]' || echo "0")
                passed_modules=$(echo "${passed_modules}" | tr -d '[:space:]' || echo "0")
                # Ensure default values and calculate
                total_modules="${total_modules:-0}"
                passed_modules="${passed_modules:-0}"
                failed_modules=$(( ${total_modules:-0} - ${passed_modules:-0} ))
            fi

            # Write modules data to state.json under run_xcframework_verification
            jq ".steps.run_xcframework_verification.modules = $modules_json |
                .steps.run_xcframework_verification.summary = {
                  total: $total_modules,
                  passed: $passed_modules,
                  failed: $failed_modules
                } |
                .timestamps.updated_at = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"" \
                "$state_file" > "${state_file}.tmp" 2>/dev/null && \
                mv "${state_file}.tmp" "$state_file" 2>/dev/null || true
        fi
    fi
    
    return 0
}

# Error handler for state tracking and failure notification
_handle_main_error() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        local failed_step="${CURRENT_STEP:-unknown}"
        
        log_error "Release failed at step: $failed_step (exit code: $exit_code)"
        
        # Update state file
        msp_state_mark_step_failed "run" "orchestrator failed (see logs)" "$exit_code" || true
        
        # Get failure details from state file
        local failure_msg="Unknown error"
        local state_file="${STATE_FILE:-.msp-release-state.json}"
        if [[ -f "$state_file" ]] && command -v jq >/dev/null 2>&1; then
            failure_msg=$(jq -r '.last_error.message // .last_error.step // "Unknown error"' "$state_file" 2>/dev/null || echo "Unknown error")
        fi
        
        # Send Slack failure notification
        if command -v notify_failure &>/dev/null; then
            log_info "Sending failure notification via Slack..."
            local resume_cmd="./Scripts/msp-release.sh resume ${VERSION:-unknown}"
            
            # Use notify_failure function from notify.sh
            notify_failure "MSP iOS SDK" "${VERSION:-unknown}" "$failure_msg" "$failed_step" || true
            
            # Also try to send DM if MSP_SLACK_DM_OVERRIDE is set
            if [[ -n "${MSP_SLACK_DM_OVERRIDE:-}" ]] && command -v notify::_send_dm &>/dev/null; then
                local dm_message=$(cat <<EOF
🚨 *MSP iOS SDK Release Failed*

*Version*: ${VERSION:-unknown}
*Failed Step*: ${failed_step}
*Exit Code*: ${exit_code}
*Error*: ${failure_msg}

*To Resume*:
\`\`\`
cd ${ROOT_DIR}
${resume_cmd}
\`\`\`

*Logs*: Check \`${LOG_FILE:-/tmp/msp-release.log}\`
EOF
)
                notify::_send_dm "${MSP_SLACK_DM_OVERRIDE}" "$dm_message" || true
            fi
        else
            log_warning "notify_failure function not available, skipping notification"
        fi
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
    
    # Start timing for orchestrator
    if command -v metrics::start &>/dev/null; then
        metrics::start "orchestrator_total"
    fi
    
    # Set error trap for state tracking
    trap '_handle_main_error' ERR
    
    # Detect and log release mode
    local RELEASE_MODE
    RELEASE_MODE="$(_msp_release_get_mode)"
    echo "[MSP][ORCH] Release mode: ${RELEASE_MODE}"
    
    # Phase 4 TASK 4: Preflight / Production mode detection
    local RELEASE_TIER="${MSP_RELEASE_TIER:-preflight}"
    export MSP_RELEASE_TIER="$RELEASE_TIER"
    if command -v log::info &>/dev/null; then
        log::info "ORCH" "Running in ${RELEASE_TIER} tier"
    else
        log_info "[TIER] Running in ${RELEASE_TIER} tier"
    fi

    # Phase 3: Release Tier Safety Checks (must run before any operations)
    VERSION="$1"
    if command -v msp_release_safety_check &>/dev/null; then
        if ! msp_release_safety_check "$VERSION"; then
            log_error "[SAFETY] Safety checks failed. Aborting release."
            exit 1
        fi
    fi

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
        # Local release mode: Bypass config-driven branch restrictions
        if [[ "$RELEASE_TIER" != "preflight" ]] && ! should_real_publish; then
            if [[ "${MSP_ALLOW_LOCAL_RELEASE:-0}" == "1" ]]; then
                log_warn "[BLOCKED] ⚠️ Config-driven publish check bypassed (local release mode)"
            else
            log_error "[BLOCKED] Real publish not allowed on branch: $current_branch"
            log_error "[BLOCKED] Check Scripts/release/config/release_config.yaml for branch policy"
            exit 1
            fi
        fi
    fi
    log_info "[TIER] Running in ${RELEASE_TIER} tier"
    export MSP_RELEASE_TIER="$RELEASE_TIER"
    echo "[MSP][ORCH] Release tier: ${RELEASE_TIER}"
    
    # Phase 4 TASK 5: Security protection mechanisms
    log_section "Phase 4: Security Checks"
    
    # Check git working directory is clean
    # For preflight mode and DRY_RUN mode, allow uncommitted changes (warn only)
    local dry_run="${DRY_RUN:-false}"
    if [[ "$dry_run" == "true" ]]; then
        log_info "[MSP][ORCH] DRY RUN mode: Allowing uncommitted changes"
    elif ! git diff --exit-code >/dev/null 2>&1 || ! git diff --cached --exit-code >/dev/null 2>&1; then
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
    
    # Check if tag exists (unless override allowed or DRY_RUN mode)
    if [[ -n "$VERSION" ]] && [[ "${DRY_RUN:-false}" != "true" ]]; then
        if git rev-parse "v${VERSION}" >/dev/null 2>&1 || git rev-parse "$VERSION" >/dev/null 2>&1; then
            if [[ "${MSP_ALLOW_EXISTING_TAG:-0}" != "1" ]]; then
                log_error "[MSP][ORCH][ERROR] Tag already exists: $VERSION"
                log_error "Use MSP_ALLOW_EXISTING_TAG=1 to override (not recommended)"
                exit 1
            else
                log_warn "Tag $VERSION already exists (override allowed)"
            fi
        fi
    elif [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[MSP][ORCH] DRY RUN: Skipping tag existence check"
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
    
    # Start timing for orchestrator main execution
    if command -v metrics::start &>/dev/null; then
        metrics::start "orchestrator_main"
    fi
    
    # Step 0: Pre-release setup (build frameworks)
    step "pre_release_setup"
    export CURRENT_STEP="pre_release_setup"
    if command -v metrics::start &>/dev/null; then
        metrics::start "pre_release_setup"
    fi
    if pre_release_setup; then
        if command -v metrics::end &>/dev/null; then
            metrics::end "pre_release_setup"
        fi
        step_done "pre_release_setup"
    else
        # In preflight mode, allow pre_release_setup to fail gracefully
        if [[ "$RELEASE_TIER" == "preflight" ]]; then
            log_warn "Pre-release setup failed in preflight mode, continuing anyway"
            step_skip "pre_release_setup (tier: preflight soft-fail)"
            # Mark overall as failed to prevent success notification
            OVERALL_SUCCESS="false"
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
    local skip_reason=""
    if [[ "${SKIP_CREATE_RELEASE_BRANCH:-false}" == "true" ]]; then
        skip_branch_creation=true
        skip_reason="CLI: --skip-create-release-branch"
        log_warn "Skipping branch creation (--skip-create-release-branch flag set)"
    elif [[ "$RELEASE_TIER" == "preflight" ]]; then
        # In preflight, check if already on a release branch
        local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
        if [[ "$current_branch" =~ ^release/ ]]; then
            skip_branch_creation=true
            skip_reason="tier: already on release branch"
            log_warn "Already on release branch '$current_branch', skipping branch creation in preflight mode"
        fi
    fi

    if [[ "$skip_branch_creation" == "true" ]]; then
        step_skip "create_release_branch ($skip_reason)"
    else
        export CURRENT_STEP="create_release_branch"
        if command -v metrics::start &>/dev/null; then
            metrics::start "create_release_branch"
        fi
        if create_release_branch; then
            if command -v metrics::end &>/dev/null; then
                metrics::end "create_release_branch"
            fi
            step_done "create_release_branch"
        else
            if [[ "$RELEASE_TIER" == "preflight" ]]; then
                log_warn "Branch creation failed in preflight mode, continuing anyway"
                step_skip "create_release_branch (tier: preflight soft-fail)"
            else
                step_fail "create_release_branch" $?
                return 11
            fi
        fi
    fi
    
    # Step 2: Release CocoaPods
    step "release_cocoapods"
    export CURRENT_STEP="release_cocoapods"
    if command -v metrics::start &>/dev/null; then
        metrics::start "release_cocoapods"
    fi
    if release_cocoapods; then
        if command -v metrics::end &>/dev/null; then
            metrics::end "release_cocoapods"
        fi
        step_done "release_cocoapods"
        if command -v msp_state_mark_step_success &>/dev/null; then
            msp_state_mark_step_success "release_cocoapods"
        fi
    else
        # Config-driven soft-fail: if pods are disabled, failure is non-fatal
        if ! is_enabled "pods.enabled"; then
            log_warn "[ORCH] release_cocoapods failed but pods.enabled=false (non-fatal)"
            step_skip "release_cocoapods (config soft-fail)"
            if command -v msp_state_mark_step_skipped &>/dev/null; then
                msp_state_mark_step_skipped "release_cocoapods" "Skipped due to failure with pods.enabled=false"
            fi
        else
            step_fail "release_cocoapods" $?
            # Test/preflight tier: allow CocoaPods failure to continue with other steps
            # Release/production tier: hard-fail (exit entire release)
            local release_tier="${MSP_RELEASE_TIER:-preflight}"
            if [[ "$release_tier" == "release" ]] || [[ "$release_tier" == "production" ]]; then
                log_error "[MSP][ORCH] Release tier ($release_tier): CocoaPods release failure - aborting"
                return 12
            else
                log_warn "[MSP][ORCH] $release_tier tier: CocoaPods release failed, continuing with other steps"
                # Continue execution - don't return
            fi
        fi
    fi
    
    # Step 3: Release SPM
    step "release_spm"
    export CURRENT_STEP="release_spm"
    if command -v metrics::start &>/dev/null; then
        metrics::start "release_spm"
    fi
    if release_spm; then
        if command -v metrics::end &>/dev/null; then
            metrics::end "release_spm"
        fi
        step_done "release_spm"
        if command -v msp_state_mark_step_success &>/dev/null; then
            msp_state_mark_step_success "release_spm"
        fi
    else
        # Config-driven soft-fail: if spm is disabled, failure is non-fatal
        if ! is_enabled "spm.enabled"; then
            log_warn "[ORCH] release_spm failed but spm.enabled=false (non-fatal)"
            step_skip "release_spm (config soft-fail)"
            if command -v msp_state_mark_step_skipped &>/dev/null; then
                msp_state_mark_step_skipped "release_spm" "Skipped due to failure with spm.enabled=false"
            fi
        else
            step_fail "release_spm" $?
            return 13
        fi
    fi
    
    # Step 4: Push release branch
    step "push_release_branch"
    export CURRENT_STEP="push_release_branch"
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
    export CURRENT_STEP="run_local_verification"
    # Config-driven gating
    if ! is_enabled "verify.local"; then
        step_skip "run_local_verification (config: verify.local=false)"
    elif [[ "$MSP_SKIP_LOCAL_VERIFY" == "true" ]]; then
        step_skip "run_local_verification (tier: CI mode)"
    else
        mark_step_start "run_local_verification"
        local verify_script="$ROOT_DIR/Scripts/release/verify_local/run_local.sh"
        if [[ -f "$verify_script" ]]; then
            if source "$verify_script" && run_local_verification; then
                step_done "run_local_verification"
                mark_step_success "run_local_verification"
            else
                step_fail "run_local_verification" $?
                fail_step "run_local_verification" "verification script failed"
                # Soft-fail: continue anyway
            fi
        else
            step_skip "run_local_verification (config: script not found)"
        fi
    fi
    
    # Step 7: Run device verification (soft-fail, never breaks release)
    step "run_device_verification"
    export CURRENT_STEP="run_device_verification"
    if [[ "$MSP_SKIP_DEVICE_VERIFY" == "true" ]]; then
        step_skip "run_device_verification (tier: CI mode)"
    else
        mark_step_start "run_device_verification"
        if run_device_verification; then
            step_done "run_device_verification"
            mark_step_success "run_device_verification"
        else
            step_fail "run_device_verification" $?
            fail_step "run_device_verification" "device verification failed"
            # Soft-fail: continue anyway
        fi
    fi
    
    # Step 8: Run XCFramework deep verification (soft-fail, never breaks release)
    step "run_xcframework_verification"
    export CURRENT_STEP="run_xcframework_verification"
    # Config-driven gating
    if ! is_enabled "verify.xcframework"; then
        step_skip "run_xcframework_verification (config: verify.xcframework=false)"
    elif [[ "$MSP_SKIP_XCF_VERIFY" == "true" ]]; then
        step_skip "run_xcframework_verification (tier: CI mode or xcodebuild not available)"
    else
        mark_step_start "run_xcframework_verification"
        if run_xcframework_verification; then
            step_done "run_xcframework_verification"
            mark_step_success "run_xcframework_verification"
        else
            step_fail "run_xcframework_verification" $?
            fail_step "run_xcframework_verification" "XCFramework verification failed"
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
        if [[ -f "$ROOT_DIR/.msp-release-state.json" ]] && command -v jq >/dev/null 2>&1; then
            local local_step_status
            local_step_status="$(jq -r '.steps.run_local_verification.status // "unknown"' "$ROOT_DIR/.msp-release-state.json" 2>/dev/null || echo "unknown")"
            if [[ "$local_step_status" == "success" ]] || [[ "$local_step_status" == "error" ]] || [[ "$local_step_status" == "failed" ]]; then
                local mode="${LOCAL_VERIFY_MODE:-unknown}"
                if [[ "$local_step_status" == "success" ]]; then
                    local_status="    - Local ($mode): PASS"
                else
                    local_status="    - Local ($mode): FAIL"
                fi
            fi
        fi

        # Build device verification status for notifications
        local device_status=""
        if [[ -f "$ROOT_DIR/.msp-release-state.json" ]] && command -v jq >/dev/null 2>&1; then
            local device_step_status
            device_step_status="$(jq -r '.steps.run_device_verification.status // "unknown"' "$ROOT_DIR/.msp-release-state.json" 2>/dev/null || echo "unknown")"
            if [[ "$device_step_status" == "success" ]] || [[ "$device_step_status" == "error" ]] || [[ "$device_step_status" == "failed" ]]; then
                local mode="${DEVICE_VERIFY_MODE:-unknown}"
                if [[ "$device_step_status" == "success" ]]; then
                    device_status="    - Device ($mode): PASS"
                else
                    device_status="    - Device ($mode): FAIL"
                fi
            fi
        fi

        # Build XCFramework verification status for notifications
        local xcf_status=""
        if [[ -f "$ROOT_DIR/.msp-release-state.json" ]] && command -v jq >/dev/null 2>&1; then
            local xcf_step_status
            xcf_step_status="$(jq -r '.steps.run_xcframework_verification.status // "unknown"' "$ROOT_DIR/.msp-release-state.json" 2>/dev/null || echo "unknown")"
            if [[ "$xcf_step_status" != "unknown" ]] && [[ "$xcf_step_status" != "skipped" ]]; then
                local modules
                modules="$(jq -r '.steps.run_xcframework_verification.modules // {} | keys[]' "$ROOT_DIR/.msp-release-state.json" 2>/dev/null || echo "")"
                if [[ -n "$modules" ]]; then
                    while IFS= read -r module; do
                        local success
                        success="$(jq -r ".steps.run_xcframework_verification.modules[\"$module\"].success" "$ROOT_DIR/.msp-release-state.json" 2>/dev/null || echo "0")"
                        local warnings
                        warnings="$(jq -r ".steps.run_xcframework_verification.modules[\"$module\"].warnings" "$ROOT_DIR/.msp-release-state.json" 2>/dev/null || echo "0")"

                        local module_status=""
                        if [[ "$success" == "1" ]]; then
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
            local local_step_status_json="unknown"
            if [[ -f "$ROOT_DIR/.msp-release-state.json" ]] && command -v jq >/dev/null 2>&1; then
                local_step_status_json="$(jq -r '.steps.run_local_verification.status // "unknown"' "$ROOT_DIR/.msp-release-state.json" 2>/dev/null || echo "unknown")"
            fi
            local local_executed="false"
            local local_success="false"
            if [[ "$local_step_status_json" == "success" ]]; then
                local_executed="true"
                local_success="true"
            elif [[ "$local_step_status_json" == "error" ]] || [[ "$local_step_status_json" == "failed" ]]; then
                local_executed="true"
                local_success="false"
            fi
            local_verify_json="$local_verify_json\"executed\":$local_executed,"
            local_verify_json="$local_verify_json\"success\":$local_success,"
            local_verify_json="$local_verify_json\"mode\":\"${LOCAL_VERIFY_MODE:-unknown}\""
            local_verify_json="$local_verify_json}"
            
            # Build device verification JSON
            local device_verify_json="{"
            local device_step_status_json="unknown"
            if [[ -f "$ROOT_DIR/.msp-release-state.json" ]] && command -v jq >/dev/null 2>&1; then
                device_step_status_json="$(jq -r '.steps.run_device_verification.status // "unknown"' "$ROOT_DIR/.msp-release-state.json" 2>/dev/null || echo "unknown")"
            fi
            local device_executed="false"
            local device_success="false"
            if [[ "$device_step_status_json" == "success" ]]; then
                device_executed="true"
                device_success="true"
            elif [[ "$device_step_status_json" == "error" ]] || [[ "$device_step_status_json" == "failed" ]]; then
                device_executed="true"
                device_success="false"
            fi
            device_verify_json="$device_verify_json\"executed\":$device_executed,"
            device_verify_json="$device_verify_json\"success\":$device_success,"
            device_verify_json="$device_verify_json\"mode\":\"${DEVICE_VERIFY_MODE:-unknown}\","
            device_verify_json="$device_verify_json\"archive\":\"$([[ -n "${DEVICE_VERIFY_ARCHIVE_PATH:-}" ]] && echo "pass" || echo "fail")\","
            device_verify_json="$device_verify_json\"ipa\":\"$([[ -n "${DEVICE_VERIFY_IPA_PATH:-}" ]] && echo "pass" || echo "fail")\""
            device_verify_json="$device_verify_json}"

            # Build XCFramework verification JSON
            local xcf_verify_json="{"
            local xcf_step_status_json="unknown"
            if [[ -f "$ROOT_DIR/.msp-release-state.json" ]] && command -v jq >/dev/null 2>&1; then
                xcf_step_status_json="$(jq -r '.steps.run_xcframework_verification.status // "unknown"' "$ROOT_DIR/.msp-release-state.json" 2>/dev/null || echo "unknown")"
            fi
            local xcf_executed="false"
            if [[ "$xcf_step_status_json" != "unknown" ]] && [[ "$xcf_step_status_json" != "skipped" ]]; then
                xcf_executed="true"
            fi
            local xcf_modules_json="{}"
            if [[ -f "$ROOT_DIR/.msp-release-state.json" ]] && command -v jq >/dev/null 2>&1; then
                xcf_modules_json="$(jq -c '.steps.run_xcframework_verification.modules // {}' "$ROOT_DIR/.msp-release-state.json" 2>/dev/null || echo "{}")"
            fi
            xcf_verify_json="$xcf_verify_json\"executed\":$xcf_executed,"
            xcf_verify_json="$xcf_verify_json\"modules\":$xcf_modules_json"
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

    # End timing and generate metrics report
    if command -v metrics::end &>/dev/null; then
        metrics::end "orchestrator_main"
        metrics::end "orchestrator_total"
        metrics::report
        metrics::save
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
