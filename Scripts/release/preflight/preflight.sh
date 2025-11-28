#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/lib/release-common.sh
source "$ROOT_DIR/Scripts/lib/release-common.sh"

# Load release state utilities
source "$SCRIPT_DIR/../utils/state.sh"

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
        log_info "Resuming: skipping preflight_static (status already success/skipped)"
        return 0
    fi
    
    msp_state_mark_step_running "preflight_static"
    
    log_section "Preflight (Static Checks)"
    
    local errors=0
    local warnings=0
    
    # 1) Clean working tree check
    log_step "Checking git working tree"
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_warn "Working tree is not clean (DRY RUN mode - continuing)"
            ((warnings++))
        else
            log_error "Working tree is not clean. Please commit or stash changes."
            ((errors++))
        fi
    else
        log_info "Working tree is clean"
    fi
    
    # 2) Branch consistency
    log_step "Checking branch consistency"
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    local base_branch="${BASE_BRANCH:-}"
    local release_branch="${RELEASE_BRANCH:-}"
    
    if [[ -n "$base_branch" && "$current_branch" != "$base_branch" ]] && \
       [[ -n "$release_branch" && "$current_branch" != "$release_branch" ]]; then
        log_warn "Current branch '$current_branch' does not match BASE_BRANCH='$base_branch' or RELEASE_BRANCH='$release_branch'"
        ((warnings++))
    else
        log_info "Branch check passed (current: $current_branch)"
    fi
    
    # 3) Version validation
    log_step "Validating release version"
    local version="${RELEASE_VERSION:-}"
    if [[ -z "$version" ]]; then
        log_warn "RELEASE_VERSION is not set (version check skipped)"
        ((warnings++))
    elif [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+.*$ ]]; then
        log_warn "Version '$version' does not match semver pattern (X.Y.Z)"
        ((warnings++))
    else
        log_info "Version validation passed: $version"
    fi
    
    # 4) Binary directory existence
    log_step "Checking Binary directory"
    if [[ ! -d "$ROOT_DIR/Binary" ]]; then
        log_warn "Binary directory not found at $ROOT_DIR/Binary"
        ((warnings++))
    else
        log_info "Binary directory exists"
    fi
    
    # 5) Light XCFramework existence check
    log_step "Checking core XCFrameworks"
    local xcframeworks_dir="$ROOT_DIR/Build/XCFrameworks"
    local required_frameworks=(
        "MSPSharedLibraries"
        "MSPOMSDK"
        "MSPCore"
        "MSPiOSCore"
        "NovaCore"
    )
    
    local found_count=0
    for framework in "${required_frameworks[@]}"; do
        if [[ -d "$xcframeworks_dir/${framework}.xcframework" ]]; then
            log_info "Found: ${framework}.xcframework"
            ((found_count++))
        else
            log_warn "Missing: ${framework}.xcframework"
        fi
    done
    
    if [[ $found_count -eq ${#required_frameworks[@]} ]]; then
        log_info "All 5 core XCFrameworks found"
    elif [[ $found_count -gt 0 ]]; then
        log_warn "Only $found_count/${#required_frameworks[@]} core XCFrameworks found"
    else
        log_warn "No core XCFrameworks found (build preflight will enforce)"
    fi
    
    # 6) Command availability check
    log_step "Checking required commands"
    
    # git (required)
    if command -v git &>/dev/null; then
        log_info "git: available"
    else
        log_error "git: not found (required)"
        ((errors++))
    fi
    
    # pod (warn only)
    if command -v pod &>/dev/null; then
        log_info "pod: available"
    else
        log_warn "pod: not found (CocoaPods releases will fail)"
        ((warnings++))
    fi
    
    # xcodebuild (warn only)
    if command -v xcodebuild &>/dev/null; then
        log_info "xcodebuild: available"
    else
        log_warn "xcodebuild: not found (builds will fail)"
        ((warnings++))
    fi
    
    # Final summary
    local exit_code=0
    if [[ $errors -gt 0 ]]; then
        log_error "Static preflight checks failed with $errors error(s) and $warnings warning(s)"
        exit_code=1
    elif [[ $warnings -gt 0 ]]; then
        log_warn "Static preflight checks passed with $warnings warning(s)"
        log_success "Static preflight checks passed (with warnings)"
        exit_code=0
    else
        log_success "Static preflight checks passed"
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
        log_info "Resuming: skipping preflight_build (status already success/skipped)"
        return 0
    fi
    
    msp_state_mark_step_running "preflight_build"
    
    log_section "Preflight (Build / Round-trip Checks)"
    
    # 1) DRY_RUN shortcut
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Skipping build preflight"
        msp_state_mark_step_skipped "preflight_build" "preflight build skipped due to DRY_RUN"
        return 0
    fi
    
    # 2) Round-trip test
    local round_trip_script="$ROOT_DIR/Scripts/target-switching/round-trip-test.sh"
    
    if [[ ! -f "$round_trip_script" ]]; then
        log_warn "Round-trip test script not found at $round_trip_script"
        log_warn "Skipping build preflight (script missing)"
        msp_state_mark_step_skipped "preflight_build" "preflight build skipped due to missing round-trip script"
        return 0
    fi
    
    log_step "Running round-trip test"
    local cmd="$round_trip_script --loops=1"
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Command: $cmd"
    fi
    
    if ! bash "$round_trip_script" --loops=1; then
        log_error "Round-trip test failed"
        msp_state_mark_step_failed "preflight_build" "preflight build checks failed" "1"
        return 1
    fi
    
    log_success "Build preflight checks passed"
    msp_state_mark_step_success "preflight_build"
    return 0
}

# ============================================================================
# Main Preflight Dispatcher
# ============================================================================
run_preflight_main() {
    # Initialize state for standalone preflight
    msp_state_init "preflight"
    
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
                log_warn "Unknown flag: $1"
                shift
                ;;
        esac
    done
    
    # Run checks
    if [[ "$build_only" == "true" ]]; then
        # Only build checks
        msp_state_mark_step_skipped "preflight_static" "preflight static skipped due to --build-only"
        if ! preflight_build; then
            return 1
        fi
    elif [[ "$static_only" == "true" ]]; then
        # Only static checks
        if ! preflight_static; then
            return 1
        fi
        msp_state_mark_step_skipped "preflight_build" "preflight build skipped due to --static-only"
    else
        # Default: both checks
        if ! preflight_static; then
            log_error "Static preflight failed"
            return 1
        fi
        
        if ! preflight_build; then
            log_error "Build preflight failed"
            return 1
        fi
    fi
    
    log_success "All preflight checks passed"
    return 0
}

# Execute when run directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    run_preflight_main "$@"
fi

# Export functions
export -f preflight_static preflight_build run_preflight_main

