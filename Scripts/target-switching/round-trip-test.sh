#!/usr/bin/env bash
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
# Usage:   ./Scripts/target-switching/round-trip-test.sh [--loops=N]
#
# Options:
#   --loops=N    Run N complete cycles (default: 1)
#
# Exit codes:
#   0 - Round-trip test passed
#   1 - Round-trip test failed
# ============================================================================

set -eo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/target-switching/common.sh
source "$SCRIPT_DIR/common.sh"

ensure_repo_root

# ============================================================================
# Colors
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================================================
# Parse Arguments
# ============================================================================
LOOPS=1

for arg in "$@"; do
    case "$arg" in
        --loops=*)
            LOOPS="${arg#*=}"
            if ! [[ "$LOOPS" =~ ^[0-9]+$ ]] || [[ "$LOOPS" -lt 1 ]]; then
                echo -e "${RED}[ERROR]${NC} Invalid --loops value: $LOOPS (must be positive integer)"
                exit 1
            fi
            ;;
        -h|--help)
            echo "Usage: $0 [--loops=N]"
            echo ""
            echo "Options:"
            echo "  --loops=N    Run N complete cycles (default: 1)"
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
# Helper Functions
# ============================================================================

log_header() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

log_step() {
    echo "  $1"
}

log_ok() {
    echo -e "  ${GREEN}✓${NC} $1"
}

log_fail() {
    echo -e "  ${RED}✗${NC} $1"
}

log_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
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

# Check git status (tracked files only)
check_git_clean() {
    cd "$ROOT_DIR"
    local git_status
    git_status=$(git status --porcelain 2>/dev/null | grep -v "^??" || true)
    
    if [[ -z "$git_status" ]]; then
        return 0
    else
        return 1
    fi
}

# Build DemoApp
build_demoapp() {
    local mode="$1"
    local log_file="$BUILD_LOG_DIR/${mode}-build-${TIMESTAMP}.log"
    
    cd "$ROOT_DIR"
    if xcodebuild -workspace msp-ios-sdk.xcworkspace \
        -scheme MSPDemoApp \
        -configuration Debug \
        -destination "platform=iOS Simulator,name=iPhone 16" \
        build 2>&1 | tee "$log_file" | tail -3; then
        
        if grep -q "BUILD SUCCEEDED" "$log_file"; then
            return 0
        else
            return 1
        fi
    else
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
    
    log_header "PODS-DEV${is_final:+ (return)}"
    
    # [X.1] Switch mode
    log_step "[${phase_num}.1] Switch mode"
    local switch_output
    switch_output=$("$ROOT_DIR/Scripts/switch-target.sh" pods-dev 2>&1) || {
        log_fail "Switch failed"
        echo "$switch_output" | tail -10 | sed 's/^/    /'
        return 1
    }
    log_ok "Switch → OK"
    
    # [X.2] Validate workspace/YAML
    log_step "[${phase_num}.2] Workspace/YAML validation"
    if ! validate_workspace_symlink; then
        log_fail "Workspace symlink missing"
        ((errors++)) || true
    fi
    
    if ! validate_yaml_files; then
        log_fail "YAML files missing"
        ((errors++)) || true
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_ok "Workspace/YAML → OK"
    else
        return 1
    fi
    
    # [X.3] Build DemoApp (only for pods-dev)
    log_step "[${phase_num}.3] Build DemoApp"
    if build_demoapp "pods-dev"; then
        log_ok "Build DemoApp → OK"
    else
        log_fail "Build DemoApp → FAILED"
        return 1
    fi
    
    # [X.4] Git cleanliness
    log_step "[${phase_num}.4] Git cleanliness"
    if check_git_clean; then
        log_ok "Git → CLEAN"
    else
        log_fail "Git → DIRTY"
        git status --porcelain 2>/dev/null | grep -v "^??" | head -5 | sed 's/^/    /'
        return 1
    fi
    
    return 0
}

# Test pods-release mode (SOFT - XCFrameworks missing is OK)
test_pods_release() {
    local phase_num="$1"
    local errors=0
    local switch_succeeded=false
    
    log_header "PODS-RELEASE"
    
    # [X.1] Switch mode
    log_step "[${phase_num}.1] Switch mode"
    local switch_output
    local switch_exit_code=0
    switch_output=$("$ROOT_DIR/Scripts/switch-target.sh" pods-release 2>&1) || switch_exit_code=$?
    
    if [[ $switch_exit_code -eq 0 ]]; then
        log_ok "Switch → OK"
        switch_succeeded=true
    elif is_xcframework_missing_error "$switch_output"; then
        log_warn "Switch → WARN: core XCFrameworks missing (ignored for RTT)"
        # Continue RTT - this is expected
    elif is_hard_error "$switch_output"; then
        log_fail "Switch → FAILED (hard error)"
        echo "$switch_output" | tail -10 | sed 's/^/    /'
        return 1
    else
        log_fail "Switch → FAILED (unknown error)"
        echo "$switch_output" | tail -10 | sed 's/^/    /'
        return 1
    fi
    
    # [X.2] YAML/workspace validation (only if switch succeeded)
    if [[ "$switch_succeeded" == "true" ]]; then
        log_step "[${phase_num}.2] Workspace/YAML validation"
        if validate_workspace_symlink && validate_yaml_files; then
            log_ok "Workspace/YAML → OK"
        else
            log_fail "Workspace/YAML → FAILED"
            ((errors++)) || true
        fi
    else
        log_step "[${phase_num}.2] Workspace/YAML validation"
        log_info "Skipped (switch failed due to missing XCFrameworks)"
    fi
    
    # [X.3] Git cleanliness
    log_step "[${phase_num}.3] Git cleanliness"
    if check_git_clean; then
        log_ok "Git → CLEAN"
    else
        log_fail "Git → DIRTY"
        git status --porcelain 2>/dev/null | grep -v "^??" | head -5 | sed 's/^/    /'
        return 1
    fi
    
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
    
    log_header "SPM-RELEASE"
    
    # [X.1] Switch mode
    log_step "[${phase_num}.1] Switch mode"
    local switch_output
    local switch_exit_code=0
    switch_output=$("$ROOT_DIR/Scripts/switch-target.sh" spm-release 2>&1) || switch_exit_code=$?
    
    if [[ $switch_exit_code -eq 0 ]]; then
        log_ok "Switch → OK"
        switch_succeeded=true
    elif is_xcframework_missing_error "$switch_output"; then
        log_warn "Switch → WARN: core XCFrameworks missing (ignored for RTT)"
        # Continue RTT - this is expected
    elif is_hard_error "$switch_output"; then
        log_fail "Switch → FAILED (hard error)"
        echo "$switch_output" | tail -10 | sed 's/^/    /'
        return 1
    else
        log_fail "Switch → FAILED (unknown error)"
        echo "$switch_output" | tail -10 | sed 's/^/    /'
        return 1
    fi
    
    # [X.2] Package.swift validation (only if switch succeeded)
    if [[ "$switch_succeeded" == "true" ]]; then
        log_step "[${phase_num}.2] Package.swift validation"
        if validate_package_swift; then
            log_ok "Package.swift → OK"
        else
            log_fail "Package.swift → FAILED (missing or invalid)"
            ((errors++)) || true
        fi
    else
        log_step "[${phase_num}.2] Package.swift validation"
        log_info "Skipped (switch failed due to missing XCFrameworks)"
    fi
    
    # [X.3] Git cleanliness
    log_step "[${phase_num}.3] Git cleanliness"
    if check_git_clean; then
        log_ok "Git → CLEAN"
    else
        log_fail "Git → DIRTY"
        git status --porcelain 2>/dev/null | grep -v "^??" | head -5 | sed 's/^/    /'
        return 1
    fi
    
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
    
    # Final Summary
    echo ""
    echo "══════════════════════════════════════════════════════════════════════"
    echo "  FINAL SUMMARY"
    echo "══════════════════════════════════════════════════════════════════════"
    echo ""
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
        exit 1
    fi
}

main "$@"
