#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

# Modular Release Orchestrator
# Orchestrates the complete release process: create branch → CocoaPods → SPM → push
#
# Phase 2 Step 4: Config-driven orchestrator
# This script now uses environment variables from msp-release.sh instead of CLI arguments.


# ============================================================================
# Release Mode Detection
# ============================================================================
# Normalize release mode; default to cli for backward compatibility
# Phase 5: Added 'simple' and 'full' modes (FR-007)
# - simple: Skip verification phase (default for Phase 5)
# - full: Include verification phase
_msp_release_get_mode() {
    local mode="${MSP_RELEASE_MODE:-cli}"

    case "$mode" in
        ci|CI)
            echo "ci"
            ;;
        cli|CLI|"")
            echo "cli"
            ;;
        simple|SIMPLE)
            # Phase 5: Simple mode - skips verification
            echo "simple"
            ;;
        full|FULL)
            # Phase 5: Full mode - includes verification
            echo "full"
            ;;
        *)
            # Unknown mode: fallback to cli but log a warning
            echo "cli"
            >&2 echo "[MSP][ORCH][WARN] Unknown MSP_RELEASE_MODE='$mode', falling back to 'cli'"
            ;;
    esac
}

# Source path helpers and common library
# shellcheck source=Scripts/lib/path-helpers.sh
source "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/path-helpers.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set BUILD_ENVIRONMENT default before sourcing release-common.sh
# This prevents "parameter not set" errors when release-common.sh uses set -u
export BUILD_ENVIRONMENT="${BUILD_ENVIRONMENT:-local}"

source "$ROOT_DIR/Scripts/lib/release-common.sh"
# Config-driven gating is now standard - no need for tier helper checks
set +e  # Temporarily disabled - will re-enable after identifying failing command

# Source state management utility (state.sh is already loaded by release-common.sh, but we can source it again if needed)
# Use absolute path to ensure correct location
if [[ -f "$ROOT_DIR/Scripts/release/utils/state.sh" ]]; then
    source "$ROOT_DIR/Scripts/release/utils/state.sh" 2>/dev/null || true
fi

# R012b: Source time_utils.sh for unified duration calculation
if [[ -f "$ROOT_DIR/Scripts/lib/shared/time_utils.sh" ]]; then
    # shellcheck source=Scripts/lib/shared/time_utils.sh
    source "$ROOT_DIR/Scripts/lib/shared/time_utils.sh" 2>/dev/null || true
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

# Source shared validation library for centralized branch validation
if [[ -f "$ROOT_DIR/Scripts/lib/validation.sh" ]]; then
    source "$ROOT_DIR/Scripts/lib/validation.sh" 2>/dev/null || true
fi

# ============================================================================
# Source Shared Modules (DRY Principle)
# ============================================================================
# These modules provide reusable functionality across release scripts

# Shared step lifecycle (step, step_done, step_fail, mark_step_*)
if [[ -f "$ROOT_DIR/Scripts/lib/shared/step_lifecycle.sh" ]]; then
    source "$ROOT_DIR/Scripts/lib/shared/step_lifecycle.sh"
fi

# Shared input validation (version, branch validation)
if [[ -f "$ROOT_DIR/Scripts/lib/shared/input_validation.sh" ]]; then
    source "$ROOT_DIR/Scripts/lib/shared/input_validation.sh"
fi

# Shared CDN verification (wait, verify URLs)
if [[ -f "$ROOT_DIR/Scripts/lib/shared/cdn_verify.sh" ]]; then
    source "$ROOT_DIR/Scripts/lib/shared/cdn_verify.sh"
fi

# Orchestrator-specific verification functions
if [[ -f "$SCRIPT_DIR/lib/verification.sh" ]]; then
    source "$SCRIPT_DIR/lib/verification.sh"
fi

# Orchestrator summary functions (DRY extraction)
if [[ -f "$SCRIPT_DIR/lib/summary.sh" ]]; then
    source "$SCRIPT_DIR/lib/summary.sh"
fi

# Orchestrator notification builder functions (DRY extraction)
if [[ -f "$SCRIPT_DIR/lib/notify_builder.sh" ]]; then
    source "$SCRIPT_DIR/lib/notify_builder.sh"
fi

# Note: step_skip, mark_step_*, fail_step functions are now provided by
# Scripts/lib/shared/step_lifecycle.sh (DRY principle)

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
                log::error "MODULAR" "VERSION not provided. Expected: $0 <MODE> <VERSION> [OPTIONS]"
                log::info "MODULAR" "Usage: msp-release.sh run <VERSION>"
                log::info "MODULAR" "   or: $0 <MODE> <VERSION> [OPTIONS]  (direct call for debugging)"
                exit 1
            fi
        fi
    else
        log::error "MODULAR" "RELEASE_VERSION not set. Did you forget to run via msp-release.sh?"
        log::info "MODULAR" "Usage: msp-release.sh run <VERSION>"
        log::info "MODULAR" "   or: $0 <MODE> <VERSION> [OPTIONS]  (direct call for debugging)"
        exit 1
    fi
fi

# Use environment variables with CLI fallback for backward compatibility
VERSION="${RELEASE_VERSION:-}"
BASE_BRANCH="${BASE_BRANCH:-}"
RELEASE_BRANCH="${RELEASE_BRANCH:-}"
DRY_RUN="${DRY_RUN:-false}"
export DRY_RUN  # Export immediately so is_enabled() can read correct tier
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
    echo "  2. Release CocoaPods (MSPiOSCore → MSPSharedLibraries+MSPGoogleAdsTypes → Adapters → MSPCore)"
    echo "  3. Release SPM"
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
        log::error "MODULAR" "Version is required"
        show_help
        exit 1
    fi
    
    # Set base branch to current branch if not provided
    if [[ -z "$BASE_BRANCH" ]]; then
        BASE_BRANCH="$(git branch --show-current)"
        if [[ -z "$BASE_BRANCH" ]]; then
            log::error "MODULAR" "Could not determine current branch. Please specify BASE_BRANCH environment variable or --base-branch"
            exit 1
        fi
    fi
    
    # Set release branch if not provided
    if [[ -z "$RELEASE_BRANCH" ]]; then
        RELEASE_BRANCH="release/$VERSION"
    fi
    
    # Phase 4 TASK 0: Branch validity check for production releases
    # Use centralized branch validation from validation.sh (DRY principle)
    # This ensures consistency between safety.sh and modular.sh
    local current_branch
    current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
    if [[ -z "$current_branch" ]]; then
        log::error "MODULAR" "Could not determine current git branch"
        exit 1
    fi

    # Phase B: Use DRY_RUN instead of MSP_RELEASE_TIER
    local dry_run="${DRY_RUN:-true}"
    if [[ "$dry_run" == "false" ]]; then
        # Local release mode: Allow local execution (defaults to enabled)
        # MSP_ALLOW_LOCAL_RELEASE defaults to 1 for local development
        # Will be set to 0 in Jenkins CI environment
        if [[ "${MSP_ALLOW_LOCAL_RELEASE:-1}" == "1" ]]; then
            log::info "MODULAR" "[MSP][ORCH] 本地发布模式已启用 (Local release mode enabled)"
            log::info "MODULAR" "[MSP][ORCH] Branch validation bypassed for local development"
        # Production mode branch validation (CI only)
        elif ! validate_release_branch; then
            log::error "MODULAR" "[MSP][ORCH][ERROR] Branch validation failed"
            log::error "MODULAR" "Current branch: $current_branch"
            log::error "MODULAR" "Please switch to a valid branch, or use DRY_RUN=true for dry-run releases"
            exit 1
        fi

        if [[ "$current_branch" =~ ^feature/ ]]; then
            log::info "MODULAR" "[MSP][ORCH] Production mode: on feature branch '$current_branch'"
            log::info "MODULAR" "[MSP][ORCH] A release branch will be created in Step 1 from this base"
        else
            log::info "MODULAR" "[MSP][ORCH] Production mode: branch validation passed ($current_branch)"
        fi
    else
        log::info "MODULAR" "[MSP][ORCH] Dry-run mode: no branch restriction (current: $current_branch)"
    fi
    
    log::info "MODULAR" "Release orchestrator configuration:"
    log::info "MODULAR" "  Version: $VERSION"
    log::info "MODULAR" "  Base Branch: $BASE_BRANCH"
    log::info "MODULAR" "  Release Branch: $RELEASE_BRANCH"
    log::info "MODULAR" "  Dry Run: $DRY_RUN"
    log::info "MODULAR" "  Pods Enabled: $(is_enabled "pods.enabled" && echo "true" || echo "false")"
    log::info "MODULAR" "  SPM Enabled: $(is_enabled "spm.enabled" && echo "true" || echo "false")"
    log::info "MODULAR" "  Verify Local: $(is_enabled "verify.local" && echo "true" || echo "false")"
    log::info "MODULAR" "  Verify Remote: $(is_enabled "verify.remote" && echo "true" || echo "false")"
    log::info "MODULAR" "  Verify XCFramework: $(is_enabled "verify.xcframework" && echo "true" || echo "false")"
    if [[ -n "${PODS_MODULES:-}" ]]; then
        log::info "MODULAR" "  Pods Modules: $PODS_MODULES"
    fi
    if [[ -n "${SPM_PACKAGES:-}" ]]; then
        log::info "MODULAR" "  SPM Packages: $SPM_PACKAGES"
    fi
    log::info "MODULAR" "  Skip Push: $SKIP_PUSH"
}

# Step 0: Pre-release setup (build frameworks)
pre_release_setup() {
    export CURRENT_STEP="pre_release_setup"
    mark_step_start "pre_release_setup"
    log_section "Step 0: Pre-release setup (building frameworks)"


    if [[ "$DRY_RUN" == "true" ]]; then
        log::info "MODULAR" "DRY RUN: Would run build scripts to ensure frameworks are up-to-date"
        mark_step_success "pre_release_setup"
        return 0
    fi

    # Build all frameworks using the unified build scripts
    log::step "MODULAR" "Building core frameworks using unified build script"

    # Build core XCFrameworks
    local BUILD_CORE_SCRIPT="$ROOT_DIR/Scripts/xcframeworks/build-core.sh"
    if [[ ! -f "$BUILD_CORE_SCRIPT" ]]; then
        log::warn "MODULAR" "Build script not found at $BUILD_CORE_SCRIPT, skipping framework build"
        log::info "MODULAR" "Frameworks may need to be built manually before release"
        mark_step_success "pre_release_setup"
        return 0
    fi

    if ! bash "$BUILD_CORE_SCRIPT"; then
        fail_step "pre_release_setup" "core framework build failed"
        return 1
    fi

    # Build adapter XCFrameworks (for binary distribution)
    log::step "MODULAR" "Building adapter frameworks for binary distribution"
    local BUILD_ADAPTERS_SCRIPT="$ROOT_DIR/Scripts/xcframeworks/build-adapters.sh"
    if [[ -f "$BUILD_ADAPTERS_SCRIPT" ]]; then
        if ! bash "$BUILD_ADAPTERS_SCRIPT"; then
            log::warn "MODULAR" "Adapter framework build failed, but continuing (adapters are optional)"
        fi
    else
        log::warn "MODULAR" "Adapter build script not found at $BUILD_ADAPTERS_SCRIPT"
    fi

    log::success "MODULAR" "Pre-release setup completed successfully"
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

    log::info "MODULAR" "Executing: $create_branch_cmd"

    if ! eval "$create_branch_cmd"; then
        fail_step "create_release_branch" "branch creation script failed"
        return 1
    fi

    log::success "MODULAR" "Release branch created successfully"
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

    # Ensure all required XCFrameworks are built before release
    # This prevents "XCFramework not found" errors during packaging
    if [[ -f "$ROOT_DIR/Scripts/release/utils/ensure_xcframeworks.sh" ]]; then
        log::step "MODULAR" "Ensuring binary adapter XCFrameworks are built..."
        if ! "$ROOT_DIR/Scripts/release/utils/ensure_xcframeworks.sh" ensure; then
            log::error "MODULAR" "Failed to ensure XCFrameworks are built"
            return 1
        fi
        log::success "MODULAR" "All binary adapter XCFrameworks are ready"
    fi

    export CURRENT_STEP="release_cocoapods"
    mark_step_start "release_cocoapods"
    log_section "Step 2: Releasing CocoaPods"
    local current_mode="${MSP_RELEASE_MODE:-cli}"
    local current_mode_upper=$(echo "$current_mode" | tr '[:lower:]' '[:upper:]' 2>/dev/null || echo "${current_mode}" | awk '{print toupper($0)}')
    log::info "MODULAR" "[MSP][ORCH] Mode: ${current_mode_upper} — releasing CocoaPods"
    
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
    
    log::info "MODULAR" "Calling cocoapods.sh with environment variables:"
    log::info "MODULAR" "  RELEASE_VERSION=$RELEASE_VERSION"
    log::info "MODULAR" "  RELEASE_BRANCH=$RELEASE_BRANCH"
    log::info "MODULAR" "  PODS_MODULES=$PODS_MODULES"
    
    # Call pods/publish.sh directly (no CLI arguments)
    local COCOAPODS_SCRIPT="$ROOT_DIR/Scripts/release/publish/pods/publish.sh"
    if [[ ! -f "$COCOAPODS_SCRIPT" ]]; then
        fail_step "release_cocoapods" "publish script not found at $COCOAPODS_SCRIPT"
        return 1
    fi
    if bash "$COCOAPODS_SCRIPT"; then
        log::success "MODULAR" "CocoaPods released successfully"
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
                log::info "MODULAR" "[VERIFY] Auto-configured Pods verification: $github_url @ $VERSION"
            else
                log::warn "MODULAR" "[VERIFY] Could not auto-configure Pods verification"
            fi
        fi

        # Track success based on PODS_MODULES if available
        if [[ "$DRY_RUN" != "true" && -n "${PODS_MODULES:-}" ]]; then
            # Split PODS_MODULES space-separated string into array
            # shellcheck disable=SC2086 -- intentional word-splitting: PODS_MODULES is a space-delimited name list
            for module in $PODS_MODULES; do
                COCOAPODS_SUCCESS+=("$module")
            done
        elif [[ "$DRY_RUN" != "true" ]]; then
            # Fallback to default list if PODS_MODULES not set
            COCOAPODS_SUCCESS+=("MSPiOSCore" "MSPSharedLibraries" "MSPGoogleAdsTypes" "MSPPrebidAdapter" "MSPGoogleAdapter" "MSPFacebookAdapter" "MSPNovaAdapter" "MSPAmazonAdapter" "MSPMolocoAdapter" "MSPLiftoffAdapter" "MSPCore")
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
    log::info "MODULAR" "[MSP][ORCH] Mode: ${current_mode_upper} — releasing SPM"
    
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
    
    log::info "MODULAR" "Calling spm.sh with environment variables:"
    log::info "MODULAR" "  RELEASE_VERSION=$RELEASE_VERSION"
    log::info "MODULAR" "  RELEASE_BRANCH=$RELEASE_BRANCH"
    log::info "MODULAR" "  SPM_PACKAGES=$SPM_PACKAGES"
    
    # Call spm/publish.sh directly (no CLI arguments)
    local SPM_SCRIPT="$ROOT_DIR/Scripts/release/publish/spm/publish.sh"
    if [[ ! -f "$SPM_SCRIPT" ]]; then
        fail_step "release_spm" "publish script not found at $SPM_SCRIPT"
        return 1
    fi
    if bash "$SPM_SCRIPT"; then
        log::success "MODULAR" "SPM released successfully"
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
                log::info "MODULAR" "[VERIFY] Auto-configured SPM verification: $github_url @ $VERSION"
            else
                log::warn "MODULAR" "[VERIFY] Could not auto-configure SPM verification"
            fi
        fi

        # Track success based on SPM_PACKAGES if available
        if [[ "$DRY_RUN" != "true" && -n "${SPM_PACKAGES:-}" ]]; then
            # Split SPM_PACKAGES space-separated string into array
            # shellcheck disable=SC2086 -- intentional word-splitting: SPM_PACKAGES is a space-delimited name list
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
        log::info "MODULAR" "DRY RUN: Would push release branch $RELEASE_BRANCH to remote"
        mark_step_success "push_release_branch"
        return 0
    fi

    # Ensure we're on release branch (skip in dry-run mode)
    if [[ "$DRY_RUN" != "true" ]]; then
        git checkout "$RELEASE_BRANCH"
    fi

    # Push release branch
    if git push origin "$RELEASE_BRANCH"; then
        log::success "MODULAR" "Release branch pushed successfully"
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
# Note: This function contains project-specific arrays (COCOAPODS_SUCCESS, SPM_SUCCESS, etc.)
# that require the inline implementation. The summary module provides reusable helpers.
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
        log::success "MODULAR" "🎉 Release $VERSION completed successfully!"
    else
        log::error "MODULAR" "❌ Release $VERSION completed with errors"
    fi
    
    echo ""
    log::info "MODULAR" "Release Details:"
    log::info "MODULAR" "  Version: $VERSION"
    log::info "MODULAR" "  Release Branch: $RELEASE_BRANCH"
    log::info "MODULAR" "  Base Branch: $BASE_BRANCH"
    log::info "MODULAR" "  Start Time: $RELEASE_START_TIME"
    log::info "MODULAR" "  End Time: $RELEASE_END_TIME"
    if [[ -n "$duration" ]]; then
        log::info "MODULAR" "  Duration: $duration"
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
            log::success "MODULAR" "✅ Successfully Released:"
            for pod in "${COCOAPODS_SUCCESS[@]}"; do
                log::info "MODULAR" "  - $pod"
            done
            echo ""
        fi

        if [[ ${#COCOAPODS_FAILED[@]} -gt 0 ]]; then
            log::error "MODULAR" "❌ Failed to Release:"
            for pod in "${COCOAPODS_FAILED[@]}"; do
                log::info "MODULAR" "  - $pod"
            done
            echo ""
        fi
    fi

    # SPM Module Results (if executed)
    if is_enabled "spm.enabled" && [[ "$SKIP_SPM" != "true" ]]; then
        print_subsection "SPM Module Results"

        if [[ ${#SPM_SUCCESS[@]} -gt 0 ]]; then
            log::success "MODULAR" "✅ Successfully Released:"
            for package in "${SPM_SUCCESS[@]}"; do
                log::info "MODULAR" "  - $package"
            done
            echo ""
        fi

        if [[ ${#SPM_FAILED[@]} -gt 0 ]]; then
            log::error "MODULAR" "❌ Failed to Release:"
            for package in "${SPM_FAILED[@]}"; do
                log::info "MODULAR" "  - $package"
            done
            echo ""
        fi
    fi
    
    # GitHub Releases Results
    print_subsection "GitHub Releases Results"
    
    if [[ ${#GITHUB_RELEASES_SUCCESS[@]} -gt 0 ]]; then
        log::success "MODULAR" "✅ Successfully Created:"
        for release in "${GITHUB_RELEASES_SUCCESS[@]}"; do
            log::info "MODULAR" "  - $release"
        done
        echo ""
    fi
    
    if [[ ${#GITHUB_RELEASES_FAILED[@]} -gt 0 ]]; then
        log::error "MODULAR" "❌ Failed to Create:"
        for release in "${GITHUB_RELEASES_FAILED[@]}"; do
            log::info "MODULAR" "  - $release"
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
            log::success "MODULAR" "SPM:   PASS  (repo: $spm_url, version: $spm_version)"
        else
            log::error "MODULAR" "SPM:   FAIL  (repo: $spm_url, version: $spm_version)"
        fi
    elif [[ -z "${MSP_VERIFY_SPM_URL:-}" ]] || [[ -z "${MSP_VERIFY_SPM_VERSION:-}" ]]; then
        log::info "MODULAR" "SPM:   N/A   (not configured)"
    else
        log::info "MODULAR" "SPM:   SKIPPED"
    fi
    
    # CocoaPods Remote Verification
    if [[ "${REMOTE_PODS_EXECUTED:-0}" == "1" ]]; then
        local pods_url="${MSP_VERIFY_PODS_URL:-N/A}"
        local pods_version="${MSP_VERIFY_PODS_VERSION:-N/A}"
        if [[ "${REMOTE_PODS_SUCCESS:-0}" == "1" ]]; then
            log::success "MODULAR" "Pods:  PASS  (repo: $pods_url, version: $pods_version)"
        else
            log::error "MODULAR" "Pods:  FAIL  (repo: $pods_url, version: $pods_version)"
        fi
    elif [[ -z "${MSP_VERIFY_PODS_URL:-}" ]] || [[ -z "${MSP_VERIFY_PODS_VERSION:-}" ]]; then
        log::info "MODULAR" "Pods:  N/A   (not configured)"
    else
        log::info "MODULAR" "Pods:  SKIPPED"
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
        log::success "MODULAR" "Executed: yes"
        log::success "MODULAR" "Result: PASS"
    elif [[ "$local_status" == "error" ]] || [[ "$local_status" == "failed" ]]; then
        log::info "MODULAR" "Executed: yes"
        log::error "MODULAR" "Result: FAIL"
    elif [[ "$local_status" == "skipped" ]]; then
        log::info "MODULAR" "Executed: no"
        log::info "MODULAR" "Result: SKIPPED"
    else
        log::info "MODULAR" "Executed: no"
        log::info "MODULAR" "Mode: N/A"
        log::info "MODULAR" "Result: SKIPPED"
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
        log::success "MODULAR" "Executed: yes"
        log::success "MODULAR" "Result: PASS"
    elif [[ "$device_status" == "error" ]] || [[ "$device_status" == "failed" ]]; then
        log::info "MODULAR" "Executed: yes"
        log::error "MODULAR" "Result: FAIL"
    elif [[ "$device_status" == "skipped" ]]; then
        log::info "MODULAR" "Executed: no"
        log::info "MODULAR" "Result: SKIPPED"
    else
        log::info "MODULAR" "Executed: no"
        log::info "MODULAR" "Mode: N/A"
        log::info "MODULAR" "Archive: N/A"
        log::info "MODULAR" "IPA: N/A"
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
        log::info "MODULAR" "Executed: yes"
        if [[ "$xcf_status" == "success" ]]; then
            log::success "MODULAR" "Result: PASS"
        else
            log::error "MODULAR" "Result: FAIL"
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
                log::info "MODULAR" "Summary: $passed_modules passed, $failed_modules failed (total: $total_modules)"

                # Show top 5 failed modules with details
                if [[ "$failed_modules" != "0" ]]; then
                    echo ""
                    log::info "MODULAR" "Failed modules (showing up to 5):"
                    local modules
                    modules="$(jq -r '.steps.run_xcframework_verification.modules | to_entries[] | select(.value.success == 0) | .key' "$state_file" 2>/dev/null || echo "")"
                    if [[ -n "$modules" ]]; then
                        local count=0
                        while IFS= read -r module && [[ $count -lt 5 ]]; do
                            local failed_scans
                            failed_scans="$(jq -r ".steps.run_xcframework_verification.modules[\"$module\"].failed_scans | join(\", \")" "$state_file" 2>/dev/null || echo "unknown")"
                            if [[ -n "$failed_scans" ]] && [[ "$failed_scans" != "null" ]] && [[ "$failed_scans" != "" ]]; then
                                log::error "MODULAR" "  - $module: failed scans: $failed_scans"
                            else
                                log::error "MODULAR" "  - $module"
                            fi
                            count=$((count + 1))
                        done <<< "$modules"

                        if [[ "$failed_modules" -gt 5 ]]; then
                            local remaining=$((failed_modules - 5))
                            log::info "MODULAR" "  ... and $remaining more"
                        fi
                    fi
                fi
            fi
        fi
    else
        log::info "MODULAR" "Executed: no"
    fi
    echo ""
    
    # Next Steps
    print_subsection "Next Steps"
    
    if [[ "$OVERALL_SUCCESS" == "true" ]]; then
        log::info "MODULAR" "1. Verify the release on GitHub: https://github.com/ParticleMedia/msp-ios-sdk-public/releases/tag/$VERSION"
        log::info "MODULAR" "2. Test CocoaPods installation: pod 'MSPCore', '~> $VERSION'"
        log::info "MODULAR" "3. Test SPM installation: .package(url: \"https://github.com/ParticleMedia/msp-ios-sdk-public.git\", from: \"$VERSION\")"
        log::info "MODULAR" "4. Create pull request to merge release branch if needed"
    else
        log::info "MODULAR" "1. Review the failed components above"
        log::info "MODULAR" "2. Fix any issues and retry the release"
        log::info "MODULAR" "3. Check logs for detailed error information"
    fi
    echo ""
}

# ============================================================================
# Verification Functions (Wrappers)
# ============================================================================
# These are thin wrappers around the extracted module functions in lib/verification.sh
# Kept for backward compatibility with main() calling conventions

# Step 5: Run remote verification
run_remote_verification() {
    if command -v orch_run_remote_verification &>/dev/null; then
        orch_run_remote_verification
    else
        log::warn "MODULAR" "orch_run_remote_verification not available, skipping"
        return 0
    fi
}

# Step 7: Run device verification
run_device_verification() {
    if command -v orch_run_device_verification &>/dev/null; then
        orch_run_device_verification
    else
        log::warn "MODULAR" "orch_run_device_verification not available, skipping"
        return 0
    fi
}

# Step 8: Run XCFramework deep verification
run_xcframework_verification() {
    if command -v orch_run_xcframework_verification &>/dev/null; then
        orch_run_xcframework_verification
    else
        log::warn "MODULAR" "orch_run_xcframework_verification not available, skipping"
        return 0
    fi
}

# Error handler for state tracking and failure notification
_handle_main_error() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        local failed_step="${CURRENT_STEP:-unknown}"
        
        log::error "MODULAR" "Release failed at step: $failed_step (exit code: $exit_code)"
        
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
            log::info "MODULAR" "Sending failure notification via Slack..."
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
            log::warn "MODULAR" "notify_failure function not available, skipping notification"
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
    
    # Phase B Step 4: Use DRY_RUN instead of MSP_RELEASE_TIER
    local dry_run="${DRY_RUN:-true}"
    local mode_label="dry-run"
    if [[ "$dry_run" == "false" ]]; then
        mode_label="production"
    fi
    if command -v log::info &>/dev/null; then
        log::info "ORCH" "Running in ${mode_label} mode"
    else
        log::info "MODULAR" "[MODE] Running in ${mode_label} mode"
    fi

    # Phase 3: Release Tier Safety Checks (must run before any operations)
    # Note: VERSION is already set at script level (line ~180) from RELEASE_VERSION
    # Use that value as fallback since arguments may have been shifted
    VERSION="${1:-$VERSION}"
    if command -v msp_release_safety_check &>/dev/null; then
        if ! msp_release_safety_check "$VERSION"; then
            log::error "MODULAR" "[SAFETY] Safety checks failed. Aborting release."
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
        
        log::info "MODULAR" "[CONFIG] Branch: $current_branch"
        log::info "MODULAR" "[CONFIG] allow_real_publish = $allow_real"
        log::info "MODULAR" "[CONFIG] allow_test_publish = $allow_test"
        log::info "MODULAR" "[CONFIG] allow_preflight = $allow_preflight"
        
        # Block real publish if not allowed
        # Local release mode: Bypass config-driven branch restrictions
        # Phase B: Use DRY_RUN instead of RELEASE_TIER
        # MSP_ALLOW_LOCAL_RELEASE defaults to 1 for local development
        # Will be set to 0 in Jenkins CI environment
        if [[ "$dry_run" == "false" ]] && ! should_real_publish; then
            if [[ "${MSP_ALLOW_LOCAL_RELEASE:-1}" == "1" ]]; then
                log::warn "MODULAR" "[BLOCKED] ⚠️ Config-driven publish check bypassed (local release mode)"
            else
            log::error "MODULAR" "[BLOCKED] Real publish not allowed on branch: $current_branch"
            log::error "MODULAR" "[BLOCKED] Check Scripts/config/release.yaml for branch policy"
            exit 1
            fi
        fi
    fi
    log::info "MODULAR" "[MODE] Running in ${mode_label} mode"
    # Phase B: Removed MSP_RELEASE_TIER export, use DRY_RUN directly
    echo "[MSP][ORCH] Release mode: ${mode_label}"
    
    # Phase 4 TASK 5: Security protection mechanisms
    log_section "Phase 4: Security Checks"
    
    # Check git working directory is clean
    # For preflight mode and DRY_RUN mode, allow uncommitted changes (warn only)
    local dry_run="${DRY_RUN:-false}"
    if [[ "$dry_run" == "true" ]]; then
        log::info "MODULAR" "[MSP][ORCH] DRY RUN mode: Allowing uncommitted changes"
    elif ! git diff --exit-code >/dev/null 2>&1 || ! git diff --cached --exit-code >/dev/null 2>&1; then
        # Phase B: Use DRY_RUN instead of RELEASE_TIER
        if [[ "$dry_run" == "true" ]]; then
            log::warn "MODULAR" "[MSP][ORCH][WARN] Git working directory is not clean (dry-run mode - continuing)"
            git status --short || true
        else
            log::error "MODULAR" "[MSP][ORCH][ERROR] Git working directory is not clean"
            log::error "MODULAR" "Please commit or stash all changes before releasing"
            git status --short || true
            exit 1
        fi
    else
        log::success "MODULAR" "Git working directory is clean"
    fi
    
    # Check if tag exists (unless override allowed or DRY_RUN mode)
    if [[ -n "$VERSION" ]] && [[ "${DRY_RUN:-false}" != "true" ]]; then
        if git rev-parse "v${VERSION}" >/dev/null 2>&1 || git rev-parse "$VERSION" >/dev/null 2>&1; then
            if [[ "${MSP_ALLOW_EXISTING_TAG:-0}" != "1" && "${MSP_ALLOW_EXISTING_TAG:-false}" != "true" ]]; then
                log::error "MODULAR" "[MSP][ORCH][ERROR] Tag already exists: $VERSION"
                log::error "MODULAR" "Use MSP_ALLOW_EXISTING_TAG=1 to override (not recommended)"
                exit 1
            else
                log::warn "MODULAR" "Tag $VERSION already exists (override allowed)"
            fi
        fi
    elif [[ "${DRY_RUN:-false}" == "true" ]]; then
        log::info "MODULAR" "[MSP][ORCH] DRY RUN: Skipping tag existence check"
    fi
    
    # Phase B Step 4: Production mode validation (DRY_RUN=false)
    if [[ "$dry_run" == "false" ]]; then
        # Version must be >= 1.0.0 for production releases
        if [[ "$VERSION" =~ ^0\. ]]; then
            log::error "MODULAR" "[MSP][ORCH][ERROR] Production mode requires version >= 1.0.0"
            log::error "MODULAR" "Current version: $VERSION"
            log::error "MODULAR" "Use DRY_RUN=true for pre-release versions"
            exit 1
        fi
        
        # CI mode cannot do production releases
        if [[ "$RELEASE_MODE" == "ci" ]]; then
            log::error "MODULAR" "[MSP][ORCH][ERROR] CI mode cannot perform production releases"
            log::error "MODULAR" "Production releases must be done via CLI with manual confirmation"
            exit 1
        fi
        
        log::info "MODULAR" "[MSP][ORCH] Production release confirmed (non-interactive)"
    else
        # Dry-run mode: version validation warnings
        if [[ ! "$VERSION" =~ ^0\. ]] && [[ ! "$VERSION" =~ -preflight ]] && [[ ! "$VERSION" =~ -.* ]]; then
            log::warn "MODULAR" "[MSP][ORCH] Dry-run mode with version >= 1.0.0: $VERSION"
            log::warn "MODULAR" "Consider using DRY_RUN=false for production releases"
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

    # Verification is controlled by MSP_RELEASE_MODE (full vs simple) in Phase 4 below
    # No separate kill-switch — mode determines behavior
    
    # Export verification flags (true = run verification, false = skip)
    # Invert skip_* to verify_* (skip=true → verify=false)
    export MSP_VERIFY_LOCAL="$([[ "$skip_local_verification" == "true" ]] && echo "false" || echo "true")"
    export MSP_VERIFY_DEVICE="$([[ "$skip_device_verification" == "true" ]] && echo "false" || echo "true")"
    export MSP_VERIFY_PODS="$([[ "$skip_pods_verification" == "true" ]] && echo "false" || echo "true")"
    export MSP_VERIFY_SPM="$([[ "$skip_spm_local_build" == "true" ]] && echo "false" || echo "true")"
    export MSP_VERIFY_XCF="$([[ "$skip_xcf_verify" == "true" ]] && echo "false" || echo "true")"
    
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
        # Phase B: In dry-run mode, allow pre_release_setup to fail gracefully
        if [[ "$dry_run" == "true" ]]; then
            log::warn "MODULAR" "Pre-release setup failed in dry-run mode, continuing anyway"
            step_skip "pre_release_setup (mode: dry-run soft-fail)"
            # Mark overall as failed to prevent success notification
            OVERALL_SUCCESS="false"
        else
            step_fail "pre_release_setup" $?
            return 10
        fi
    fi
    
    # ========================================================================
    # Phase 3: Publish (Steps 1-4)
    # ========================================================================
    if command -v log_phase_start &>/dev/null; then
        log_phase_start "$PHASE_PUBLISH"
    fi

    # Step 1: Create release branch
    step "create_release_branch"
    # In preflight/release mode, allow branch creation to fail gracefully
    # Check if we're already on a release branch or if skip flag is set
    local skip_branch_creation=false
    local skip_reason=""
    if [[ "${SKIP_CREATE_RELEASE_BRANCH:-false}" == "true" ]]; then
        skip_branch_creation=true
        skip_reason="CLI: --skip-create-release-branch"
        log::warn "MODULAR" "Skipping branch creation (--skip-create-release-branch flag set)"
    else
        # Phase B: In any mode, check if already on a release branch
        local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
        if [[ "$current_branch" =~ ^release/ ]]; then
            skip_branch_creation=true
            skip_reason="mode: already on release branch"
            log::warn "MODULAR" "Already on release branch '$current_branch', skipping branch creation"
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
            # Phase B: In dry-run mode, allow branch creation to fail gracefully
            if [[ "$dry_run" == "true" ]]; then
                log::warn "MODULAR" "Branch creation failed in dry-run mode, continuing anyway"
                step_skip "create_release_branch (mode: dry-run soft-fail)"
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
            log::warn "MODULAR" "[ORCH] release_cocoapods failed but pods.enabled=false (non-fatal)"
            step_skip "release_cocoapods (config soft-fail)"
            if command -v msp_state_mark_step_skipped &>/dev/null; then
                msp_state_mark_step_skipped "release_cocoapods" "Skipped due to failure with pods.enabled=false"
            fi
        else
            step_fail "release_cocoapods" $?
            # Phase B: Dry-run mode allows CocoaPods failure to continue with other steps
            # Production mode: hard-fail (exit entire release)
            if [[ "$dry_run" == "false" ]]; then
                log::error "MODULAR" "[MSP][ORCH] Production mode: CocoaPods release failure - aborting"
                return 12
            else
                log::warn "MODULAR" "[MSP][ORCH] Dry-run mode: CocoaPods release failed, continuing with other steps"
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
        # SPM failure is non-fatal: CocoaPods is the primary distribution channel.
        # Allow release to continue so Phase 4 verification can still validate pods.
        if ! is_enabled "spm.enabled"; then
            log::warn "MODULAR" "[ORCH] release_spm failed but spm.enabled=false (non-fatal)"
            step_skip "release_spm (config soft-fail)"
            if command -v msp_state_mark_step_skipped &>/dev/null; then
                msp_state_mark_step_skipped "release_spm" "Skipped due to failure with spm.enabled=false"
            fi
        else
            step_fail "release_spm" $?
            log::warn "MODULAR" "[ORCH] SPM release failed (non-fatal) — continuing to push branch and verification"
            OVERALL_SUCCESS="false"
            if command -v msp_state_mark_step_failed &>/dev/null; then
                msp_state_mark_step_failed "release_spm" "SPM release failed" "1"
            fi
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

    # End Phase 3: Publish
    if command -v log_phase_end &>/dev/null; then
        log_phase_end "success"
    fi

    # Clear error trap on success
    trap - ERR

    # Show comprehensive summary
    show_comprehensive_release_summary

    # ========================================================================
    # Phase 4: Verification (only in Full mode)
    # ========================================================================
    # Phase 5: Simple vs Full release modes (FR-007)
    # - Simple mode (default): Skip all verification, finish after Publish
    # - Full mode (--full): Include verification phase
    if [[ "${MSP_RELEASE_MODE:-simple}" != "full" ]]; then
        # Simple mode: skip verification phase entirely
        if command -v log_phase_start &>/dev/null; then
            log_phase_start "$PHASE_VERIFY"
        fi
        log::info "MODULAR" "Skipping verification phase (simple mode)"
        log::info "MODULAR" "Use --full flag for full release with verification"
        step_skip "run_remote_verification (simple mode)"
        step_skip "run_local_verification (simple mode)"
        step_skip "run_device_verification (simple mode)"
        step_skip "run_xcframework_verification (simple mode)"
        if command -v log_phase_end &>/dev/null; then
            log_phase_end "skipped"
        fi
    else
        # Full mode: run verification phase
        if command -v log_phase_start &>/dev/null; then
            log_phase_start "$PHASE_VERIFY"
        fi

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
    elif [[ "${MSP_VERIFY_LOCAL:-true}" != "true" ]]; then
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
    if [[ "${MSP_VERIFY_DEVICE:-true}" != "true" ]]; then
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
    
    # Step 8: Run XCFramework deep verification (hard-fail, blocks release)
    step "run_xcframework_verification"
    export CURRENT_STEP="run_xcframework_verification"
    # Config-driven gating
    if ! is_enabled "verify.xcframework"; then
        step_skip "run_xcframework_verification (config: verify.xcframework=false)"
    elif [[ "${MSP_VERIFY_XCF:-true}" != "true" ]]; then
        step_skip "run_xcframework_verification (tier: CI mode or xcodebuild not available)"
    else
        mark_step_start "run_xcframework_verification"
        if run_xcframework_verification; then
            step_done "run_xcframework_verification"
            mark_step_success "run_xcframework_verification"
        else
            step_fail "run_xcframework_verification" $?
            fail_step "run_xcframework_verification" "XCFramework verification failed"
            return 1
        fi
    fi

    # End Phase 4: Verification (full mode)
    if command -v log_phase_end &>/dev/null; then
        log_phase_end "success"
    fi

    fi  # End of full mode verification block

    # Global success notifications (only if release succeeded)
    if [[ "$OVERALL_SUCCESS" == "true" ]]; then
        # Build module list from successful releases (DRY: uses notify_builder.sh)
        local all_modules=()
        [[ ${#COCOAPODS_SUCCESS[@]} -gt 0 ]] && all_modules+=("${COCOAPODS_SUCCESS[@]}")
        [[ ${#SPM_SUCCESS[@]} -gt 0 ]] && all_modules+=("${SPM_SUCCESS[@]}")
        local module_list
        module_list=$(orch_build_module_list ${all_modules[@]+"${all_modules[@]}"})

        # Calculate duration (DRY: uses summary.sh)
        local duration=""
        duration=$(orch_calculate_duration "$RELEASE_START_TIME" "$RELEASE_END_TIME")

        # Build verification status strings (DRY: uses notify_builder.sh)
        local state_file="$ROOT_DIR/.msp-release-state.json"
        local remote_status local_status device_status xcf_status verify_status
        remote_status=$(orch_build_remote_status)
        local_status=$(orch_build_local_status "$state_file" "${LOCAL_VERIFY_MODE:-unknown}")
        device_status=$(orch_build_device_status "$state_file" "${DEVICE_VERIFY_MODE:-unknown}")
        xcf_status=$(orch_build_xcf_status "$state_file")
        verify_status=$(orch_build_verify_status "$remote_status" "$local_status" "$device_status" "$xcf_status")

        # Export combined status for notifications
        export REMOTE_VERIFY_STATUS="$verify_status"

        # Build unified notification data JSON (DRY: uses notify_builder.sh)
        local modules_json remote_verify_json local_verify_json device_verify_json xcf_verify_json
        modules_json=$(orch_build_modules_json "$VERSION" ${all_modules[@]+"${all_modules[@]}"})
        remote_verify_json=$(orch_build_remote_verify_json)
        local_verify_json=$(orch_build_local_verify_json "$state_file" "${LOCAL_VERIFY_MODE:-unknown}")
        device_verify_json=$(orch_build_device_verify_json "$state_file" "${DEVICE_VERIFY_MODE:-unknown}")
        xcf_verify_json=$(orch_build_xcf_verify_json "$state_file")

        # Build complete notification JSON
        local notify_data
        notify_data=$(orch_build_notify_json \
            "$VERSION" \
            "${MSP_AUTHOR_EMAIL:-unknown}" \
            "${duration:-unknown}" \
            "$modules_json" \
            "$remote_verify_json" \
            "$local_verify_json" \
            "$device_verify_json" \
            "$xcf_verify_json")
        export NOTIFY_DATA_JSON="$notify_data"
        
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
    log::step "MODULAR" "Generating release markdown report"
    local report_generator="$ROOT_DIR/Scripts/release/generate_release_md.sh"
    local state_file="$ROOT_DIR/.msp-release-state.json"
    local report_file="$ROOT_DIR/Releases/release-$VERSION.md"
    
    if [[ ! -f "$report_generator" ]]; then
        log::warn "MODULAR" "Report generator not found: $report_generator"
    elif [[ ! -f "$state_file" ]]; then
        log::warn "MODULAR" "State file not found: $state_file (release.md will not be generated)"
    else
        log::info "MODULAR" "Generating release report: Releases/release-$VERSION.md"
        if bash "$report_generator" \
            --state-file "$state_file" \
            --output "$report_file" 2>&1; then
            if [[ -f "$report_file" ]]; then
                log::success "MODULAR" "Release report generated: Releases/release-$VERSION.md"
            else
                log::warn "MODULAR" "Report generation completed but file not found: $report_file"
            fi
    else
        log::warn "MODULAR" "Report generation failed (soft-fail, continuing)"
    fi
fi

    # Task 5: Post-release cleanup — remove backup files, commit release report
    log::step "MODULAR" "Post-release cleanup"
    _post_release_cleanup "$VERSION"

    # End timing and generate metrics report
    if command -v metrics::end &>/dev/null; then
        metrics::end "orchestrator_main"
        metrics::end "orchestrator_total"
        metrics::report
        metrics::save
    fi

}

# ============================================================================
# Post-release cleanup
# ============================================================================
# @description Removes backup files created during release and commits the
#              release report. Runs after all publish phases complete.
# @param $1 version - The release version
_post_release_cleanup() {
    local version="$1"
    local root_dir="${ROOT_DIR:-.}"
    local cleanup_count=0

    # 1. Remove backup files (created by version.sh and spm/publish.sh)
    local -a backup_patterns=(
        "$root_dir/Package.swift.backup-"*
        "$root_dir/Sources/Core/MSPCore/MSPCore/Resources/Config.plist.backup"
    )

    for pattern in "${backup_patterns[@]}"; do
        # shellcheck disable=SC2086
        for backup_file in $pattern; do
            if [[ -f "$backup_file" ]]; then
                rm -f "$backup_file"
                log::info "MODULAR" "Removed backup: ${backup_file##"$root_dir"/}"
                cleanup_count=$((cleanup_count + 1))
            fi
        done
    done

    if [[ "$cleanup_count" -gt 0 ]]; then
        log::success "MODULAR" "Cleaned up $cleanup_count backup file(s)"
    else
        log::info "MODULAR" "No backup files to clean up"
    fi

    # 2. Commit release report if it exists
    local report_file="$root_dir/Releases/release-$version.md"
    if [[ -f "$report_file" ]]; then
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log::info "MODULAR" "[DRY-RUN] Would commit release report: Releases/release-$version.md"
        else
            log::step "MODULAR" "Committing release report"
            (
                cd "$root_dir"
                git add "Releases/release-$version.md"
                git commit -m "chore(release): add release report for $version" 2>/dev/null
            ) && log::success "MODULAR" "Committed release report: Releases/release-$version.md" \
              || log::warn "MODULAR" "Failed to commit release report (non-fatal)"
        fi
    fi
}

# Entry point
# Check if VERSION is set (either from RELEASE_VERSION env var or CLI arguments)
# If not set, show help and exit
if [[ -z "${VERSION:-}" && $# -eq 0 ]]; then
    echo "[DIAG] About to call main" >&2
    echo "[DIAG] RELEASE_VERSION=${RELEASE_VERSION:-}" >&2
    echo "[DIAG] VERSION=${VERSION:-}" >&2
    echo "[DIAG] Arguments: $*" >&2
    show_help
    exit 1
fi

# Run main function with all arguments
main "$@"
