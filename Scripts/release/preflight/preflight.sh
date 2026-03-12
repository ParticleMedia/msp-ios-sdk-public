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

# Load path helpers (sets ROOT_DIR)
# shellcheck source=Scripts/lib/path-helpers.sh
source "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/path-helpers.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=Scripts/lib/release-common.sh
source "$ROOT_DIR/Scripts/lib/release-common.sh"

# Load release state utilities
source "$ROOT_DIR/Scripts/release/utils/state.sh"

# Load unified logging system (if not already loaded)
if [[ -f "$ROOT_DIR/Scripts/release/utils/logger.sh" ]]; then
    source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true
fi

# ============================================================================
# Resume Helper
# ============================================================================
_msp_preflight_should_skip_step() {
    local step="$1"
    
    if [[ "${MSP_RESUME_MODE:-0}" != "1" ]]; then
        return 1
    fi
    
    local status
    status="$(msp_state_get_step_status "$step" 2>/dev/null || echo "unknown")"
    
    if [[ "$status" == "success" || "$status" == "skipped" ]]; then
        return 0
    fi
    
    return 1
}

# ============================================================================
# Preflight Static Checks (Fast, No Builds)
# ============================================================================
preflight_static() {
    # Check if we should skip this step in resume mode
    if _msp_preflight_should_skip_step "preflight_static"; then
        log::info "PREFLIGHT" "Resuming: skipping preflight_static (status already success/skipped)"
        return 0
    fi
    
    msp_state_mark_step_running "preflight_static"
    
    log_section "Preflight (Static Checks)"
    
    local errors=0
    local warnings=0
    
    # 1) Clean working tree check
    log::step "PREFLIGHT" "Checking git working tree"
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log::warn "PREFLIGHT" "Working tree is not clean (DRY RUN mode - continuing)"
            ((warnings++)) || true
        else
            log::error "PREFLIGHT" "Working tree is not clean. Please commit or stash changes."
            ((errors++)) || true
        fi
    else
        log::info "PREFLIGHT" "Working tree is clean"
    fi
    
    # 2) Branch consistency
    log::step "PREFLIGHT" "Checking branch consistency"
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    local base_branch="${BASE_BRANCH:-}"
    local release_branch="${RELEASE_BRANCH:-}"

    if [[ -n "$base_branch" && "$current_branch" != "$base_branch" ]] && \
       [[ -n "$release_branch" && "$current_branch" != "$release_branch" ]]; then
        log::warn "PREFLIGHT" "Current branch '$current_branch' does not match BASE_BRANCH='$base_branch' or RELEASE_BRANCH='$release_branch'"
        ((warnings++)) || true
    else
        log::info "PREFLIGHT" "Branch check passed (current: $current_branch)"
    fi

    # 2.5) Auto-push unpushed commits
    #      Prevents "branch not pushed" failures later in the release pipeline.
    if [[ "$current_branch" != "unknown" && "$current_branch" != "HEAD" ]]; then
        log::step "PREFLIGHT" "Checking for unpushed commits"
        local unpushed_count=0
        if git rev-parse --verify "origin/$current_branch" &>/dev/null; then
            unpushed_count=$(git rev-list "origin/$current_branch..HEAD" --count 2>/dev/null || echo "0")
        else
            # Remote tracking branch does not exist yet — all local commits are unpushed
            unpushed_count=$(git rev-list HEAD --count 2>/dev/null || echo "0")
        fi

        if [[ "$unpushed_count" -gt 0 ]]; then
            log::info "PREFLIGHT" "$unpushed_count unpushed commit(s) on '$current_branch', pushing to origin..."
            if [[ "${DRY_RUN:-false}" == "true" ]]; then
                log::info "PREFLIGHT" "DRY RUN: Would run 'git push -u origin $current_branch'"
            else
                if git push -u origin "$current_branch" 2>&1; then
                    log::success "PREFLIGHT" "Pushed $unpushed_count commit(s) to origin/$current_branch"
                else
                    log::warn "PREFLIGHT" "Failed to push to origin/$current_branch (will continue)"
                    ((warnings++)) || true
                fi
            fi
        else
            log::info "PREFLIGHT" "Branch is up to date with origin"
        fi
    fi

    # 3) Version validation
    log::step "PREFLIGHT" "Validating release version"
    local version="${RELEASE_VERSION:-}"
    if [[ -z "$version" ]]; then
        log::warn "PREFLIGHT" "RELEASE_VERSION is not set (version check skipped)"
        ((warnings++)) || true
    elif [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+.*$ ]]; then
        log::warn "PREFLIGHT" "Version '$version' does not match semver pattern (X.Y.Z)"
        ((warnings++)) || true
    else
        log::info "PREFLIGHT" "Version validation passed: $version"
    fi
    
    # 4) ReleaseArtifacts Binary directory existence
    log::step "PREFLIGHT" "Checking ReleaseArtifacts/Binary directory"
    if [[ ! -d "$ROOT_DIR/Build/ReleaseArtifacts/Binary" ]]; then
        log::warn "PREFLIGHT" "ReleaseArtifacts/Binary directory not found at $ROOT_DIR/Build/ReleaseArtifacts/Binary"
        ((warnings++)) || true
    else
        log::info "PREFLIGHT" "ReleaseArtifacts/Binary directory exists"
    fi
    
    # 5) Light XCFramework existence check
    log::step "PREFLIGHT" "Checking core XCFrameworks"
    local xcframeworks_dir="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks"
    # Stage B: MSPOMSDK removed - OMSDK now embedded in NovaCore
    local required_frameworks=(
        "MSPSharedLibraries"
        "MSPCore"
        "MSPiOSCore"
        "NovaCore"
    )
    
    local found_count=0
    for framework in "${required_frameworks[@]}"; do
        if [[ -d "$xcframeworks_dir/${framework}.xcframework" ]]; then
            log::info "PREFLIGHT" "Found: ${framework}.xcframework"
            ((found_count++)) || true
        else
            log::warn "PREFLIGHT" "Missing: ${framework}.xcframework"
        fi
    done
    
    if [[ $found_count -eq ${#required_frameworks[@]} ]]; then
        log::info "PREFLIGHT" "All ${#required_frameworks[@]} core XCFrameworks found"
    elif [[ $found_count -gt 0 ]]; then
        log::warn "PREFLIGHT" "Only $found_count/${#required_frameworks[@]} core XCFrameworks found"
    else
        log::warn "PREFLIGHT" "No core XCFrameworks found (build preflight will enforce)"
    fi
    
    # 6) Command availability check
    log::step "PREFLIGHT" "Checking required commands"
    
    # git (required)
    if command -v git &>/dev/null; then
        log::info "PREFLIGHT" "git: available"
    else
        log::error "PREFLIGHT" "git: not found (required)"
        ((errors++)) || true
    fi
    
    # pod (warn only)
    if command -v pod &>/dev/null; then
        log::info "PREFLIGHT" "pod: available"
    else
        log::warn "PREFLIGHT" "pod: not found (CocoaPods releases will fail)"
        ((warnings++)) || true
    fi
    
    # xcodebuild (warn only)
    if command -v xcodebuild &>/dev/null; then
        log::info "PREFLIGHT" "xcodebuild: available"
    else
        log::warn "PREFLIGHT" "xcodebuild: not found (builds will fail)"
        ((warnings++)) || true
    fi
    
    # Final summary
    local exit_code=0
    if [[ $errors -gt 0 ]]; then
        log::error "PREFLIGHT" "Static preflight checks failed with $errors error(s) and $warnings warning(s)"
        exit_code=1
    elif [[ $warnings -gt 0 ]]; then
        log::warn "PREFLIGHT" "Static preflight checks passed with $warnings warning(s)"
        log::success "PREFLIGHT" "Static preflight checks passed (with warnings)"
        exit_code=0
    else
        log::success "PREFLIGHT" "Static preflight checks passed"
        exit_code=0
    fi
    
    if [[ $exit_code -ne 0 ]]; then
        msp_state_mark_step_failed "preflight_static" "preflight static checks failed" "$exit_code"
        return $exit_code
    fi
    
    msp_state_mark_step_success "preflight_static"
    return 0
}

# ============================================================================
# Preflight Build Checks (Slow, With Round-trip/Build Validation)
# ============================================================================
preflight_build() {
    # Check if we should skip this step in resume mode
    if _msp_preflight_should_skip_step "preflight_build"; then
        log::info "PREFLIGHT" "Resuming: skipping preflight_build (status already success/skipped)"
        return 0
    fi
    
    msp_state_mark_step_running "preflight_build"
    
    log_section "Preflight (Build / Round-trip Checks)"
    
    # 1) DRY_RUN shortcut
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log::info "PREFLIGHT" "DRY RUN: Skipping build preflight"
        msp_state_mark_step_skipped "preflight_build" "preflight build skipped due to DRY_RUN"
        return 0
    fi
    
    # 2) Ensure XCFrameworks for binary distribution adapters
    log::step "PREFLIGHT" "Ensuring XCFrameworks for binary distribution adapters"
    local ensure_xcfw_script="$ROOT_DIR/Scripts/release/utils/ensure_xcframeworks.sh"

    if [[ -f "$ensure_xcfw_script" ]] && [[ -x "$ensure_xcfw_script" ]]; then
        if ! "$ensure_xcfw_script" ensure; then
            log::error "PREFLIGHT" "Failed to ensure XCFrameworks"
            msp_state_mark_step_failed "preflight_build" "failed to ensure XCFrameworks for binary adapters" "1"
            return 1
        fi
        log::success "PREFLIGHT" "All required XCFrameworks ready"
    else
        log::warn "PREFLIGHT" "XCFramework ensure script not found or not executable: $ensure_xcfw_script"
        log::warn "PREFLIGHT" "Skipping auto-build of missing XCFrameworks"
    fi

    # 3) Round-trip test
    local round_trip_script="$ROOT_DIR/Scripts/target-switching/round-trip-test.sh"

    if [[ ! -f "$round_trip_script" ]]; then
        log::warn "PREFLIGHT" "Round-trip test script not found at $round_trip_script"
        log::warn "PREFLIGHT" "Skipping build preflight (script missing)"
        msp_state_mark_step_skipped "preflight_build" "preflight build skipped due to missing round-trip script"
        return 0
    fi

    log::step "PREFLIGHT" "Running round-trip test"
    local cmd="$round_trip_script --loops=1"
    
    if [[ "$VERBOSE" == "true" ]]; then
        log::info "PREFLIGHT" "Command: $cmd"
    fi
    
    if ! bash "$round_trip_script" --loops=1; then
        log::error "PREFLIGHT" "Round-trip test failed"
        msp_state_mark_step_failed "preflight_build" "preflight build checks failed" "1"
        return 1
    fi
    
    log::success "PREFLIGHT" "Build preflight checks passed"
    msp_state_mark_step_success "preflight_build"
    return 0
}

# ============================================================================
# Main Preflight Dispatcher
# ============================================================================
run_preflight_main() {
    # Initialize state for standalone preflight
    msp_state_init "preflight"

    # Start Phase 1: Preflight
    if command -v log_phase_start &>/dev/null; then
        log_phase_start "$PHASE_PREFLIGHT"
    fi

    local static_only=false
    local build_only=false
    
    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --static-only)
                static_only=true
                shift
                ;;
            --build-only)
                build_only=true
                shift
                ;;
            *)
                log::warn "PREFLIGHT" "Unknown flag: $1"
                shift
                ;;
        esac
    done
    
    # Run checks
    if [[ "$build_only" == "true" ]]; then
        # Only build checks
        msp_state_mark_step_skipped "preflight_static" "preflight static skipped due to --build-only"
        if ! preflight_build; then
            if command -v log_phase_end &>/dev/null; then
                log_phase_end "failed"
            fi
            return 1
        fi
    elif [[ "$static_only" == "true" ]]; then
        # Only static checks
        if ! preflight_static; then
            if command -v log_phase_end &>/dev/null; then
                log_phase_end "failed"
            fi
            return 1
        fi
        msp_state_mark_step_skipped "preflight_build" "preflight build skipped due to --static-only"
    else
        # Default: both checks
        if ! preflight_static; then
            log::error "PREFLIGHT" "Static preflight failed"
            if command -v log_phase_end &>/dev/null; then
                log_phase_end "failed"
            fi
            return 1
        fi

        if ! preflight_build; then
            log::error "PREFLIGHT" "Build preflight failed"
            if command -v log_phase_end &>/dev/null; then
                log_phase_end "failed"
            fi
            return 1
        fi
    fi

    log::success "PREFLIGHT" "All preflight checks passed"

    # End Phase 1: Preflight
    if command -v log_phase_end &>/dev/null; then
        log_phase_end "success"
    fi

    return 0
}

# Execute when run directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    run_preflight_main "$@"
fi

# Export functions
export -f preflight_static preflight_build run_preflight_main
