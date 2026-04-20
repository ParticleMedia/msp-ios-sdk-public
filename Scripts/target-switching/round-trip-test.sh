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
# ============================================================================
# Round-Trip Test Script (Three-Mode Architecture)
# ============================================================================
# Purpose: Internal consistency test for mode switching logic.
#          Verifies that all 3 modes can switch correctly without requiring
#          XCFrameworks to exist (unlike release validation).
#
# Test Cycle: pods-dev → pods-release → spm-release → pods-dev
#
# IMPORTANT:
#   - This is an INTERNAL CONSISTENCY TEST, not a release gate
#   - Missing XCFrameworks are WARNINGS, not FAILURES
#   - Only pods-dev mode builds DemoApp
#   - pods-release and spm-release are SOFT checks (warn on missing XCFrameworks)
#
# Usage:   ./Scripts/target-switching/round-trip-test.sh [--loops=N] [--fix]
#
# Options:
#   --loops=N    Run N complete cycles (default: 1)
#   --fix        Auto-repair mode: retry failed switches, regenerate configs
#
# Exit codes:
#   0 - Round-trip test passed
#   1 - Round-trip test failed
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/target-switching/common.sh
source "$SCRIPT_DIR/common.sh"

# R042c: Source config loader extension for test settings
if [[ -f "$ROOT_DIR/Scripts/lib/config_loader_ext.sh" ]]; then
    # shellcheck source=Scripts/lib/config_loader_ext.sh
    source "$ROOT_DIR/Scripts/lib/config_loader_ext.sh" 2>/dev/null || true
    load_test_config 2>/dev/null || true
fi
# Default integration test destination from config or fallback
# Note: OS version must match available simulators (check with `xcrun simctl list`)
TEST_DESTINATION="${TEST_INTEGRATION_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 15,OS=18.5}"

ensure_repo_root

# ============================================================================
# Colors (sourced from common.sh via colors.sh, fallback just in case)
# ============================================================================
: "${RED:='\033[0;31m'}"
: "${GREEN:='\033[0;32m'}"
: "${YELLOW:='\033[1;33m'}"
: "${BLUE:='\033[0;34m'}"
: "${BOLD:='\033[1m'}"
: "${NC:='\033[0m'}"

# Source unified logging system if available (for log::* API)
# Note: Unset guard first to ensure functions are available in subprocess
if [[ -f "$ROOT_DIR/Scripts/release/utils/logger.sh" ]]; then
    unset MSP_LOGGER_LOADED
    # shellcheck source=Scripts/release/utils/logger.sh
    source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true
fi
if [[ -f "$ROOT_DIR/Scripts/lib/common.sh" ]]; then
    # shellcheck source=Scripts/lib/common.sh
    source "$ROOT_DIR/Scripts/lib/common.sh" 2>/dev/null || true
fi

# ============================================================================
# Parse Arguments
# ============================================================================
LOOPS=1
AUTO_FIX=false

for arg in "$@"; do
    case "$arg" in
        --loops=*)
            LOOPS="${arg#*=}"
            if ! [[ "$LOOPS" =~ ^[0-9]+$ ]] || [[ "$LOOPS" -lt 1 ]]; then
                echo -e "${RED}[ERROR]${NC} Invalid --loops value: $LOOPS (must be positive integer)"
                exit 1
            fi
            ;;
        --fix)
            AUTO_FIX=true
            ;;
        -h|--help)
            echo "Usage: $0 [--loops=N] [--fix]"
            echo ""
            echo "Options:"
            echo "  --loops=N    Run N complete cycles (default: 1)"
            echo "  --fix        Auto-repair mode: retry failed switches, regenerate configs"
            echo ""
            echo "Test Cycle: pods-dev → pods-release → spm-release → pods-dev"
            exit 0
            ;;
        *)
            echo -e "${RED}[ERROR]${NC} Unknown option: $arg"
            exit 1
            ;;
    esac
done

# ============================================================================
# Configuration
# ============================================================================
BUILD_LOG_DIR="$ROOT_DIR/BuildReports"
mkdir -p "$BUILD_LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# ============================================================================
# Structured Logging Functions (RTT-specific namespace)
# ============================================================================
# Use log::* API if available, otherwise use local formatting

if command -v log::step &>/dev/null; then
    # Use unified logging API
    rtt_log::step()    { log::step "$1" "$2"; }
    rtt_log::success() { log::success "$1" "$2"; }
    rtt_log::warn()    { log::warn "$1" "$2"; }
    rtt_log::error()   { log::error "$1" "$2"; }
else
    # Fallback to local formatting
    rtt_log::step()    { echo "  $2"; }
    rtt_log::success() { echo -e "  ${GREEN}✓${NC} $2"; }
    rtt_log::warn()    { echo -e "  ${YELLOW}⚠${NC} $2"; }
    rtt_log::error()   { echo -e "  ${RED}✗${NC} $2"; }
fi

rtt_log_step() {
    echo "  $1"
}

rtt_log_success() {
    echo -e "  ${GREEN}✓${NC} $1"
}

rtt_log_fail() {
    echo -e "  ${RED}✗${NC} $1"
}

rtt_log_warning() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

# Legacy logging functions (for backward compatibility)
log_header() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

log_step() {
    rtt_log::step "TARGET" "$1"
}

log_ok() {
    rtt_log::success "TARGET" "$1"
}

log_fail() {
    rtt_log_fail "$1"
}

log_warn() {
    rtt_log::warn "TARGET" "$1"
}

log_info() {
    echo -e "  ${BLUE}→${NC} $1"
}

# Check if switch failure is due to missing XCFrameworks (non-fatal for RTT)
is_xcframework_missing_error() {
    local output="$1"
    if echo "$output" | grep -qE "Missing required XCFramework|XCFramework.*missing|Cannot switch.*without XCFrameworks"; then
        return 0
    fi
    return 1
}

# Check if switch failure is a hard error (path, script missing, etc.)
is_hard_error() {
    local output="$1"
    if echo "$output" | grep -qE "No such file|command not found|Permission denied|Cannot find|script.*missing"; then
        return 0
    fi
    return 1
}

# Validate workspace symlink exists
validate_workspace_symlink() {
    local symlink="$ROOT_DIR/msp-ios-sdk.xcworkspace"
    
    if [[ -L "$symlink" ]] || [[ -d "$symlink" ]]; then
        return 0
    else
        return 1
    fi
}

# Validate YAML files exist
validate_yaml_files() {
    local errors=0
    
    if [[ ! -f "$ROOT_DIR/workspace.yml" ]]; then
        ((errors++)) || true
    fi
    
    if [[ ! -f "$ROOT_DIR/Examples/MSPDemoApp/project.yml" ]]; then
        ((errors++)) || true
    fi
    
    return $errors
}

# Validate Package.swift exists and is syntactically valid
validate_package_swift() {
    if [[ ! -f "$ROOT_DIR/Package.swift" ]]; then
        return 1
    fi
    
    # Lightweight validation using swift package describe
    cd "$ROOT_DIR"
    if swift package describe >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Git Clean Gate: Strict check after mode switch (FAILS RTT if dirty)
check_git_clean() {
    cd "$ROOT_DIR"
    local git_status
    git_status=$(git status --porcelain 2>/dev/null || true)
    
    if [[ -z "$git_status" ]]; then
        return 0
    else
        return 1
    fi
}

# Get git status output for display
get_git_status() {
    cd "$ROOT_DIR"
    git status --porcelain 2>/dev/null | head -10 || echo ""
}

# Resolve DemoApp build destination for RTT.
# Default to generic simulator — works on all Xcode versions.
resolve_demoapp_destination() {
    if [[ -n "${RTT_SIMULATOR_DESTINATION:-}" ]]; then
        echo "$RTT_SIMULATOR_DESTINATION"
    else
        echo "generic/platform=iOS Simulator"
    fi
}

# Build DemoApp
build_demoapp() {
    local mode="$1"
    local log_file="$BUILD_LOG_DIR/${mode}-build-${TIMESTAMP}.log"
    local destination
    destination="$(resolve_demoapp_destination)"
    # Restrict compilation to the native CPU architecture via the ARCHS build
    # setting. generic/platform=iOS Simulator otherwise builds both arm64 and
    # x86_64 slices; on Apple Silicon CI the x86_64 slice may fail even when
    # arm64 succeeds. ARCHS env var can override this when needed.
    local build_archs="${ARCHS:-$(uname -m)}"

    cd "$ROOT_DIR"
    # Pipe full output to log file; show last 3 lines while building.
    # On failure, grep the log for actual compiler errors so they appear in CI output.
    xcodebuild -workspace msp-ios-sdk.xcworkspace \
        -scheme MSPDemoApp \
        -configuration Debug \
        -destination "$destination" \
        ARCHS="$build_archs" \
        build 2>&1 | tee "$log_file" | tail -3

    if grep -q "BUILD SUCCEEDED" "$log_file"; then
        return 0
    else
        echo "--- Build errors ---"
        grep -E "error:|BUILD FAILED" "$log_file" | grep -v "^$" | head -40 | sed 's/^/    /'
        echo "--- End of errors (full log: $log_file) ---"
        return 1
    fi
}

# ============================================================================
# Mode Verification Functions
# ============================================================================

# Verify mode signature in project.yml
verify_project_yml_mode() {
    local expected_mode="$1"
    local project_yml="$ROOT_DIR/Examples/MSPDemoApp/project.yml"
    
    if [[ ! -f "$project_yml" ]]; then
        return 1
    fi
    
    case "$expected_mode" in
        pods-dev)
            # Should have MSPDemoApp target, no MSPDemoApp-SPM
            if grep -q "^  MSPDemoApp:$" "$project_yml" 2>/dev/null && \
               ! grep -q "^  MSPDemoApp-SPM:$" "$project_yml" 2>/dev/null; then
                return 0
            fi
            ;;
        pods-release)
            # Should have MSPDemoApp target with XCFramework phases
            if grep -q "^  MSPDemoApp:$" "$project_yml" 2>/dev/null && \
               grep -q "\[CP\] Copy XCFrameworks" "$project_yml" 2>/dev/null; then
                return 0
            fi
            ;;
        spm-release)
            # Should have MSPDemoApp-SPM target, no MSPDemoApp
            if grep -q "^  MSPDemoApp-SPM:$" "$project_yml" 2>/dev/null && \
               ! grep -q "^  MSPDemoApp:$" "$project_yml" 2>/dev/null; then
                return 0
            fi
            ;;
    esac
    return 1
}

# Verify workspace.yml exists and is regenerated
verify_workspace_yml() {
    local workspace_yml="$ROOT_DIR/workspace.yml"
    
    if [[ ! -f "$workspace_yml" ]]; then
        return 1
    fi
    
    # Check if file is recent (regenerated)
    # For RTT purposes, existence is sufficient
    return 0
}

# Verify Package.swift mode signature
verify_package_swift_mode() {
    local expected_mode="$1"
    local package_swift="$ROOT_DIR/Package.swift"
    
    case "$expected_mode" in
        pods-dev|pods-release)
            # Package.swift must NOT exist
            if [[ ! -f "$package_swift" ]]; then
                return 0
            fi
            return 1
            ;;
        spm-release)
            # Package.swift must exist and be valid
            if [[ -f "$package_swift" ]]; then
                cd "$ROOT_DIR"
                if swift package describe >/dev/null 2>&1; then
                    return 0
                fi
            fi
            return 1
            ;;
    esac
    return 1
}

# Comprehensive mode verification
verify_mode_signature() {
    local mode="$1"
    local errors=0
    
    if ! verify_project_yml_mode "$mode"; then
        rtt_log_fail "project.yml mode signature mismatch for $mode"
        ((errors++)) || true
    fi
    
    if ! verify_workspace_yml; then
        rtt_log_fail "workspace.yml missing or not regenerated"
        ((errors++)) || true
    fi
    
    if ! verify_package_swift_mode "$mode"; then
        rtt_log_fail "Package.swift state incorrect for $mode"
        ((errors++)) || true
    fi
    
    return $errors
}

# Auto-repair: Retry switch and regenerate configs
auto_repair_mode() {
    local mode="$1"
    
    rtt_log::warn "TARGET" "Auto-repair: Retrying switch to $mode"
    
    # Retry switch
    if "$ROOT_DIR/Scripts/switch-target.sh" "$mode" >/dev/null 2>&1; then
        rtt_log::success "TARGET" "Auto-repair: Switch retry succeeded"
        return 0
    else
        rtt_log_fail "Auto-repair: Switch retry failed"
        return 1
    fi
}

# ============================================================================
# Mode Test Functions
# ============================================================================

# Test pods-dev mode (STRICT)
test_pods_dev() {
    local phase_num="$1"
    local is_final="$2"
    local errors=0
    local phase_result="PASS"
    
    log_header "PODS-DEV${is_final:+ (return)}"
    
    # [X.0] Pre-flight check: Podfile existence (STEP A)
    rtt_log::step "TARGET" "[${phase_num}.0] Pre-flight: Podfile existence check"
    if [[ ! -f "$ROOT_DIR/Podfile" ]]; then
        rtt_log_fail "Podfile not found at $ROOT_DIR/Podfile — this indicates an environment problem (CocoaPods will not work)."
        phase_result="FAIL"
        return 1
    fi
    rtt_log::success "TARGET" "Podfile exists"
    
    # [X.1] Switch mode (with enhanced logging - STEP B)
    rtt_log::step "TARGET" "[${phase_num}.1] Switch mode"
    local pods_dev_log
    pods_dev_log="$(mktemp)"
    local switch_output
    local switch_retries=0
    switch_output=$("$ROOT_DIR/Scripts/switch-target.sh" pods-dev 2>&1 | tee "$pods_dev_log") || {
        if [[ "$AUTO_FIX" == "true" ]] && [[ $switch_retries -eq 0 ]]; then
            ((switch_retries++)) || true
            if auto_repair_mode "pods-dev"; then
                rtt_log::success "TARGET" "Switch → OK (after auto-repair)"
            else
                rtt_log_fail "Switch failed (auto-repair also failed)"
                echo "---------- POD INSTALL OUTPUT ----------"
                tail -30 "$pods_dev_log" | sed 's/^/    /'
                echo "----------------------------------------"
                # Store log path for final summary (STEP C)
                export RTT_PODS_DEV_LOG="$pods_dev_log"
                phase_result="FAIL"
                return 1
            fi
        else
            rtt_log_fail "Switch failed (see pod install error below):"
            echo "---------- POD INSTALL OUTPUT ----------"
            tail -30 "$pods_dev_log" | sed 's/^/    /'
            echo "----------------------------------------"
            # Store log path for final summary (STEP C)
            export RTT_PODS_DEV_LOG="$pods_dev_log"
            phase_result="FAIL"
            return 1
        fi
    }
    rtt_log::success "TARGET" "Switch → OK"
    # Clean up log file on success (STEP D)
    rm -f "$pods_dev_log" 2>/dev/null || true
    
    # [X.2] Git Clean Gate (immediately after switch)
    rtt_log::step "TARGET" "[${phase_num}.2] Git Clean Gate"
    if ! check_git_clean; then
        rtt_log_fail "Git → DIRTY (RTT FAILURE)"
        get_git_status | sed 's/^/    /'
        phase_result="FAIL"
        return 1
    fi
    rtt_log::success "TARGET" "Git → CLEAN"
    
    # [X.3] Mode Verification
    rtt_log::step "TARGET" "[${phase_num}.3] Mode Verification"
    if ! verify_mode_signature "pods-dev"; then
        rtt_log_fail "Mode signature verification failed"
        ((errors++)) || true
        phase_result="FAIL"
    else
        rtt_log::success "TARGET" "Mode signature → OK"
    fi
    
    # [X.4] Validate workspace/YAML
    rtt_log::step "TARGET" "[${phase_num}.4] Workspace/YAML validation"
    if ! validate_workspace_symlink; then
        rtt_log_fail "Workspace symlink missing"
        ((errors++)) || true
        phase_result="FAIL"
    fi
    
    if ! validate_yaml_files; then
        rtt_log_fail "YAML files missing"
        ((errors++)) || true
        phase_result="FAIL"
    fi
    
    if [[ $errors -eq 0 ]]; then
        rtt_log::success "TARGET" "Workspace/YAML → OK"
    else
        phase_result="FAIL"
        return 1
    fi
    
    # [X.5] Build DemoApp (only for pods-dev)
    rtt_log::step "TARGET" "[${phase_num}.5] Build DemoApp"
    if build_demoapp "pods-dev"; then
        rtt_log::success "TARGET" "Build DemoApp → OK"
    else
        rtt_log_fail "Build DemoApp → FAILED"
        phase_result="FAIL"
        return 1
    fi
    
    # [X.6] Final Git Clean Gate
    rtt_log::step "TARGET" "[${phase_num}.6] Final Git Clean Gate"
    if ! check_git_clean; then
        rtt_log_fail "Git → DIRTY (RTT FAILURE)"
        get_git_status | sed 's/^/    /'
        phase_result="FAIL"
        return 1
    fi
    rtt_log::success "TARGET" "Git → CLEAN"
    
    # Store result for summary
    if [[ "$is_final" == "final" ]]; then
        RTT_PODS_DEV_EXIT="$phase_result"
    else
        RTT_PODS_DEV_ENTRY="$phase_result"
    fi
    
    return 0
}

# Test pods-release mode (SOFT - XCFrameworks missing is OK)
test_pods_release() {
    local phase_num="$1"
    local errors=0
    local switch_succeeded=false
    local phase_result="PASS"
    
    log_header "PODS-RELEASE"
    
    # [X.1] Switch mode
    rtt_log::step "TARGET" "[${phase_num}.1] Switch mode"
    local switch_output
    local switch_exit_code=0
    switch_output=$("$ROOT_DIR/Scripts/switch-target.sh" pods-release 2>&1) || switch_exit_code=$?
    
    if [[ $switch_exit_code -eq 0 ]]; then
        rtt_log::success "TARGET" "Switch → OK"
        switch_succeeded=true
    elif is_xcframework_missing_error "$switch_output"; then
        rtt_log::warn "TARGET" "Switch → WARN: core XCFrameworks missing (ignored for RTT)"
        # Continue RTT - this is expected
    elif is_hard_error "$switch_output"; then
        if [[ "$AUTO_FIX" == "true" ]]; then
            if auto_repair_mode "pods-release"; then
                switch_succeeded=true
                rtt_log::success "TARGET" "Switch → OK (after auto-repair)"
            else
                rtt_log_fail "Switch → FAILED (hard error, auto-repair failed)"
                echo "$switch_output" | tail -60 | sed 's/^/    /'
                phase_result="FAIL"
                return 1
            fi
        else
            rtt_log_fail "Switch → FAILED (hard error)"
            echo "$switch_output" | tail -60 | sed 's/^/    /'
            phase_result="FAIL"
            return 1
        fi
    else
        rtt_log_fail "Switch → FAILED (unknown error)"
        echo "$switch_output" | tail -60 | sed 's/^/    /'
        phase_result="FAIL"
        return 1
    fi
    
    # [X.2] Git Clean Gate (immediately after switch)
    rtt_log::step "TARGET" "[${phase_num}.2] Git Clean Gate"
    if ! check_git_clean; then
        rtt_log_fail "Git → DIRTY (RTT FAILURE)"
        get_git_status | sed 's/^/    /'
        phase_result="FAIL"
        return 1
    fi
    rtt_log::success "TARGET" "Git → CLEAN"
    
    # [X.3] Mode Verification (only if switch succeeded)
    if [[ "$switch_succeeded" == "true" ]]; then
        rtt_log::step "TARGET" "[${phase_num}.3] Mode Verification"
        if ! verify_mode_signature "pods-release"; then
            rtt_log_fail "Mode signature verification failed"
            ((errors++)) || true
            phase_result="FAIL"
        else
            rtt_log::success "TARGET" "Mode signature → OK"
        fi
        
        # [X.4] YAML/workspace validation
        rtt_log::step "TARGET" "[${phase_num}.4] Workspace/YAML validation"
        if validate_workspace_symlink && validate_yaml_files; then
            rtt_log::success "TARGET" "Workspace/YAML → OK"
        else
            rtt_log_fail "Workspace/YAML → FAILED"
            ((errors++)) || true
            phase_result="FAIL"
        fi
    else
        rtt_log::step "TARGET" "[${phase_num}.3] Mode Verification"
        log::info "TARGET" "Skipped (switch failed due to missing XCFrameworks)"
        rtt_log::step "TARGET" "[${phase_num}.4] Workspace/YAML validation"
        log::info "TARGET" "Skipped (switch failed due to missing XCFrameworks)"
    fi
    
    # [X.5] Final Git Clean Gate
    rtt_log::step "TARGET" "[${phase_num}.5] Final Git Clean Gate"
    if ! check_git_clean; then
        rtt_log_fail "Git → DIRTY (RTT FAILURE)"
        get_git_status | sed 's/^/    /'
        phase_result="FAIL"
        return 1
    fi
    rtt_log::success "TARGET" "Git → CLEAN"
    
    # Store result for summary
    RTT_PODS_RELEASE="$phase_result"
    
    if [[ $errors -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# Test spm-release mode (SOFT - XCFrameworks missing is OK)
test_spm_release() {
    local phase_num="$1"
    local errors=0
    local switch_succeeded=false
    local phase_result="PASS"
    
    log_header "SPM-RELEASE"
    
    # [X.1] Switch mode
    rtt_log::step "TARGET" "[${phase_num}.1] Switch mode"
    local switch_output
    local switch_exit_code=0
    switch_output=$("$ROOT_DIR/Scripts/switch-target.sh" spm-release 2>&1) || switch_exit_code=$?
    
    if [[ $switch_exit_code -eq 0 ]]; then
        rtt_log::success "TARGET" "Switch → OK"
        switch_succeeded=true
    elif is_xcframework_missing_error "$switch_output"; then
        rtt_log::warn "TARGET" "Switch → WARN: core XCFrameworks missing (ignored for RTT)"
        # Continue RTT - this is expected
    elif is_hard_error "$switch_output"; then
        if [[ "$AUTO_FIX" == "true" ]]; then
            if auto_repair_mode "spm-release"; then
                switch_succeeded=true
                rtt_log::success "TARGET" "Switch → OK (after auto-repair)"
            else
                rtt_log_fail "Switch → FAILED (hard error, auto-repair failed)"
                echo "$switch_output" | tail -60 | sed 's/^/    /'
                phase_result="FAIL"
                return 1
            fi
        else
            rtt_log_fail "Switch → FAILED (hard error)"
            echo "$switch_output" | tail -60 | sed 's/^/    /'
            phase_result="FAIL"
            return 1
        fi
    else
        rtt_log_fail "Switch → FAILED (unknown error)"
        echo "$switch_output" | tail -60 | sed 's/^/    /'
        phase_result="FAIL"
        return 1
    fi
    
    # [X.2] Git Clean Gate (immediately after switch)
    rtt_log::step "TARGET" "[${phase_num}.2] Git Clean Gate"
    if ! check_git_clean; then
        rtt_log_fail "Git → DIRTY (RTT FAILURE)"
        get_git_status | sed 's/^/    /'
        phase_result="FAIL"
        return 1
    fi
    rtt_log::success "TARGET" "Git → CLEAN"
    
    # [X.3] Mode Verification (only if switch succeeded)
    if [[ "$switch_succeeded" == "true" ]]; then
        rtt_log::step "TARGET" "[${phase_num}.3] Mode Verification"
        if ! verify_mode_signature "spm-release"; then
            rtt_log_fail "Mode signature verification failed"
            ((errors++)) || true
            phase_result="FAIL"
        else
            rtt_log::success "TARGET" "Mode signature → OK"
        fi
        
        # [X.4] Package.swift validation
        rtt_log::step "TARGET" "[${phase_num}.4] Package.swift validation"
        if validate_package_swift; then
            rtt_log::success "TARGET" "Package.swift → OK"
        else
            rtt_log_fail "Package.swift → FAILED (missing or invalid)"
            ((errors++)) || true
            phase_result="FAIL"
        fi
    else
        rtt_log::step "TARGET" "[${phase_num}.3] Mode Verification"
        log::info "TARGET" "Skipped (switch failed due to missing XCFrameworks)"
        rtt_log::step "TARGET" "[${phase_num}.4] Package.swift validation"
        log::info "TARGET" "Skipped (switch failed due to missing XCFrameworks)"
    fi
    
    # [X.5] Final Git Clean Gate
    rtt_log::step "TARGET" "[${phase_num}.5] Final Git Clean Gate"
    if ! check_git_clean; then
        rtt_log_fail "Git → DIRTY (RTT FAILURE)"
        get_git_status | sed 's/^/    /'
        phase_result="FAIL"
        return 1
    fi
    rtt_log::success "TARGET" "Git → CLEAN"
    
    # Store result for summary
    RTT_SPM_RELEASE="$phase_result"
    
    if [[ $errors -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# ============================================================================
# Single Loop Execution
# ============================================================================

run_single_loop() {
    local loop_num="$1"
    
    # Initialize phase results
    RTT_PODS_DEV_ENTRY=""
    RTT_PODS_RELEASE=""
    RTT_SPM_RELEASE=""
    RTT_PODS_DEV_EXIT=""
    
    echo ""
    echo "══════════════════════════════════════════════════════════════════════"
    echo "  ROUND-TRIP TEST (Loop $loop_num/$LOOPS)"
    echo "══════════════════════════════════════════════════════════════════════"
    
    # Phase 1: pods-dev (entry)
    if ! test_pods_dev "1" ""; then
        echo ""
        echo -e "${RED}[FAILED]${NC} Loop $loop_num failed at pods-dev (entry)"
        return 1
    fi
    
    # Phase 2: pods-release
    if ! test_pods_release "2"; then
        echo ""
        echo -e "${RED}[FAILED]${NC} Loop $loop_num failed at pods-release"
        return 1
    fi
    
    # Phase 3: spm-release
    if ! test_spm_release "3"; then
        echo ""
        echo -e "${RED}[FAILED]${NC} Loop $loop_num failed at spm-release"
        return 1
    fi
    
    # Phase 4: pods-dev (return)
    if ! test_pods_dev "4" "final"; then
        echo ""
        echo -e "${RED}[FAILED]${NC} Loop $loop_num failed at pods-dev (return)"
        return 1
    fi
    
    echo ""
    echo -e "${GREEN}[Loop $loop_num/$LOOPS] All phases completed${NC}"
    
    # Verify final state: RTT fully reversible
    if check_git_clean; then
        rtt_log::success "TARGET" "RTT fully reversible (git clean)"
    else
        rtt_log_fail "RTT not fully reversible (git dirty)"
        return 1
    fi
    
    return 0
}

# ============================================================================
# Main
# ============================================================================

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║           ROUND-TRIP TEST: Three-Mode Architecture                 ║"
    echo "║                                                                    ║"
    echo "║   Cycle: pods-dev → pods-release → spm-release → pods-dev         ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Configuration:"
    echo "  Repository: $ROOT_DIR"
    echo "  Loops: $LOOPS"
    echo ""
    echo "NOTE: This is an INTERNAL CONSISTENCY TEST."
    echo "      Missing XCFrameworks are WARNINGS, not FAILURES."
    echo ""
    
    local passed_loops=0
    local failed_loops=0
    
    for ((loop=1; loop<=LOOPS; loop++)); do
        if run_single_loop "$loop"; then
            ((passed_loops++)) || true
        else
            ((failed_loops++)) || true
            break
        fi
    done
    
    # Final Summary Block (Enhanced)
    echo ""
    echo "══════════════════════════════════════════════════════════════════════"
    echo "  RTT SUMMARY"
    echo "══════════════════════════════════════════════════════════════════════"
    echo ""
    
    # Per-phase results (from last successful loop)
    if [[ $passed_loops -gt 0 ]]; then
        echo "RTT Summary:"
        printf "  pods-dev (entry): %s\n" "${RTT_PODS_DEV_ENTRY:-UNKNOWN}"
        printf "  pods-release:     %s\n" "${RTT_PODS_RELEASE:-UNKNOWN}"
        printf "  spm-release:      %s\n" "${RTT_SPM_RELEASE:-UNKNOWN}"
        printf "  pods-dev (exit):   %s\n" "${RTT_PODS_DEV_EXIT:-UNKNOWN}"
        echo ""
    fi
    
    # STEP C: Show pod install failure details if pods-dev failed
    if [[ -n "${RTT_PODS_DEV_LOG:-}" ]] && [[ -f "${RTT_PODS_DEV_LOG:-}" ]]; then
        echo "RTT PODS-DEV FAILURE:"
        head -30 "$RTT_PODS_DEV_LOG" | sed 's/^/  /'
        echo ""
        rm -f "$RTT_PODS_DEV_LOG" 2>/dev/null || true
    fi
    
    echo "┌─────────────────────────────────────────┐"
    echo "│           ROUND-TRIP SUMMARY            │"
    echo "├─────────────────────────────────────────┤"
    printf "│  Total Loops:   %-22d │\n" "$LOOPS"
    printf "│  Passed:        %-22d │\n" "$passed_loops"
    printf "│  Failed:        %-22d │\n" "$failed_loops"
    echo "├─────────────────────────────────────────┤"
    
    if [[ $failed_loops -eq 0 ]]; then
        echo -e "│  Status:        ${GREEN}ALL PASSED${NC}              │"
        echo "└─────────────────────────────────────────┘"
        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                                                                    ║${NC}"
        echo -e "${GREEN}║        ✓ Round-trip test PASSED ($passed_loops loop(s))                    ║${NC}"
        echo -e "${GREEN}║                                                                    ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "RTT RESULT: SUCCESS"
        exit 0
    else
        echo -e "│  Status:        ${RED}FAILED${NC}                  │"
        echo "└─────────────────────────────────────────┘"
        echo ""
        echo -e "${RED}╔════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║                                                                    ║${NC}"
        echo -e "${RED}║        ✗ Round-trip test FAILED                                   ║${NC}"
        echo -e "${RED}║                                                                    ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "RTT RESULT: FAILURE"
        echo "Details logged above."
        exit 1
    fi
}

main "$@"
