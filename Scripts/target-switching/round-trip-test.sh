#!/usr/bin/env bash
# ============================================================================
# Round-Trip Test Script (Enhanced with Build Validation)
# ============================================================================
# Purpose: Validates that switching between Pods and SPM modes works correctly
#          by performing full round-trip tests with mandatory build verification.
#
# RULE: Every mode switch MUST be followed by a successful build.
#       If any build fails, the test STOPS immediately.
#
# Usage:   ./Scripts/target-switching/round-trip-test.sh [options]
#
# Options:
#   --skip-build      Skip actual Xcode builds (only test mode switching)
#   --stress=N        Run N complete cycles (default: 1)
#                     Example: --stress=5 runs 5 full Pods↔SPM cycles
#
# Exit codes:
#   0 - Round-trip test passed (all cycles completed with successful builds)
#   1 - Round-trip test failed (build or validation failed)
# ============================================================================

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/target-switching/common.sh
source "$SCRIPT_DIR/common.sh"

ensure_repo_root

# ============================================================================
# Colors and Formatting
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_banner() {
    local text="$1"
    local color="${2:-$BLUE}"
    echo ""
    echo -e "${color}╔════════════════════════════════════════════════════════════════════╗${NC}"
    printf "${color}║${NC} ${BOLD}%-66s${NC} ${color}║${NC}\n" "$text"
    echo -e "${color}╚════════════════════════════════════════════════════════════════════╝${NC}"
}

print_section() {
    local text="$1"
    echo ""
    echo -e "${CYAN}===== $text =====${NC}"
}

print_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

print_fail() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}▶${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# ============================================================================
# Parse Arguments
# ============================================================================
SKIP_BUILD=false
STRESS_CYCLES=1

for arg in "$@"; do
    case "$arg" in
        --skip-build)
            SKIP_BUILD=true
            ;;
        --stress=*)
            STRESS_CYCLES="${arg#*=}"
            if ! [[ "$STRESS_CYCLES" =~ ^[0-9]+$ ]] || [[ "$STRESS_CYCLES" -lt 1 ]]; then
                print_fail "Invalid --stress value: $STRESS_CYCLES (must be positive integer)"
                exit 1
            fi
            ;;
        -h|--help)
            echo "Usage: $0 [--skip-build] [--stress=N]"
            echo ""
            echo "Options:"
            echo "  --skip-build   Skip actual Xcode builds (validation only)"
            echo "  --stress=N     Run N complete cycles (default: 1)"
            echo ""
            echo "Examples:"
            echo "  $0                    # Run 1 cycle with builds"
            echo "  $0 --stress=5         # Run 5 cycles with builds"
            echo "  $0 --stress=3 --skip-build  # Run 3 cycles without builds"
            exit 0
            ;;
        *)
            print_fail "Unknown option: $arg"
            exit 1
            ;;
    esac
done

# ============================================================================
# Test Configuration
# ============================================================================
BUILD_LOG_DIR="$ROOT_DIR/BuildReports"
mkdir -p "$BUILD_LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$BUILD_LOG_DIR/round-trip-test-$TIMESTAMP.log"
PODS_BUILD_LOG="$BUILD_LOG_DIR/pods-build-$TIMESTAMP.log"
SPM_BUILD_LOG="$BUILD_LOG_DIR/spm-build-$TIMESTAMP.log"

# Track cycle results
declare -a CYCLE_TIMES=()
declare -a CYCLE_RESULTS=()
TOTAL_START_TIME=$(date +%s)

# ============================================================================
# Validation Functions
# ============================================================================

validate_pods_mode_state() {
    print_info "Validating Pods mode state..."
    local errors=0
    
    # Package.swift must NOT exist
    if [[ -f "$ROOT_DIR/Package.swift" ]]; then
        print_fail "Package.swift should NOT exist in Pods mode"
        ((errors++)) || true
    else
        print_pass "Package.swift correctly absent"
    fi
    
    # Package.swift.template must exist (developer-maintained)
    if [[ ! -f "$ROOT_DIR/Package.swift.template" ]]; then
        print_fail "Package.swift.template missing (developer-maintained)"
        ((errors++)) || true
    else
        print_pass "Package.swift.template present"
    fi
    
    # Pods directory must exist
    if [[ ! -d "$ROOT_DIR/Pods" ]]; then
        print_fail "Pods/ directory missing"
        ((errors++)) || true
    else
        print_pass "Pods/ directory present"
    fi
    
    # Podfile.lock must exist
    if [[ ! -f "$ROOT_DIR/Podfile.lock" ]]; then
        print_fail "Podfile.lock missing"
        ((errors++)) || true
    else
        print_pass "Podfile.lock present"
    fi
    
    # Workspace must contain Pods
    if [[ -d "$ROOT_DIR/msp-ios-sdk.xcworkspace" ]]; then
        if grep -q "Pods/Pods.xcodeproj" "$ROOT_DIR/msp-ios-sdk.xcworkspace/contents.xcworkspacedata" 2>/dev/null; then
            print_pass "Workspace contains Pods project"
        else
            print_fail "Workspace doesn't contain Pods project"
            ((errors++)) || true
        fi
    else
        print_fail "Workspace missing"
        ((errors++)) || true
    fi
    
    # project.yml must have packages: {}
    if [[ -f "$ROOT_DIR/Examples/MSPDemoApp/project.yml" ]]; then
        if grep -q "^packages: {}$" "$ROOT_DIR/Examples/MSPDemoApp/project.yml" 2>/dev/null; then
            print_pass "project.yml has empty packages block"
        elif grep -q "msp-ios-sdk" "$ROOT_DIR/Examples/MSPDemoApp/project.yml" 2>/dev/null; then
            print_fail "project.yml contains SPM package references"
            ((errors++)) || true
        else
            print_pass "project.yml has no SPM packages"
        fi
    fi
    
    # Info.plist must contain GADApplicationIdentifier (required for Google Ads)
    if [[ -f "$ROOT_DIR/Examples/MSPDemoApp/MSPDemoApp/Info.plist" ]]; then
        if grep -q "GADApplicationIdentifier" "$ROOT_DIR/Examples/MSPDemoApp/MSPDemoApp/Info.plist" 2>/dev/null; then
            print_pass "Info.plist contains GADApplicationIdentifier"
        else
            print_fail "Info.plist missing GADApplicationIdentifier"
            ((errors++)) || true
        fi
    else
        print_fail "Info.plist not found"
        ((errors++)) || true
    fi
    
    if [[ $errors -eq 0 ]]; then
        print_pass "Pods mode validation PASSED"
        return 0
    else
        print_fail "Pods mode validation FAILED ($errors error(s))"
        return 1
    fi
}

validate_spm_mode_state() {
    print_info "Validating SPM mode state..."
    local errors=0
    
    # Package.swift must exist
    if [[ ! -f "$ROOT_DIR/Package.swift" ]]; then
        print_fail "Package.swift missing in SPM mode"
        ((errors++)) || true
    else
        print_pass "Package.swift present"
    fi
    
    # Package.swift.template must exist (developer-maintained)
    if [[ ! -f "$ROOT_DIR/Package.swift.template" ]]; then
        print_fail "Package.swift.template missing (developer-maintained)"
        ((errors++)) || true
    else
        print_pass "Package.swift.template present"
    fi
    
    # Pods directory must NOT exist
    if [[ -d "$ROOT_DIR/Pods" ]]; then
        print_fail "Pods/ directory exists in SPM mode"
        ((errors++)) || true
    else
        print_pass "Pods/ directory absent"
    fi
    
    # project.yml must have SPM target
    if [[ -f "$ROOT_DIR/Examples/MSPDemoApp/project.yml" ]]; then
        if grep -q "MSPDemoApp-SPM:" "$ROOT_DIR/Examples/MSPDemoApp/project.yml" 2>/dev/null; then
            print_pass "project.yml has MSPDemoApp-SPM target"
        else
            print_fail "project.yml missing MSPDemoApp-SPM target"
            ((errors++)) || true
        fi
    fi
    
    # Validate XCFrameworks exist
    if [[ -x "$SCRIPT_DIR/validate_xcframeworks.sh" ]]; then
        if "$SCRIPT_DIR/validate_xcframeworks.sh" >/dev/null 2>&1; then
            print_pass "XCFrameworks validated"
        else
            print_fail "XCFramework validation failed"
            ((errors++)) || true
        fi
    fi
    
    # Info.plist must contain GADApplicationIdentifier (required for Google Ads)
    if [[ -f "$ROOT_DIR/Examples/MSPDemoApp/MSPDemoApp/Info.plist" ]]; then
        if grep -q "GADApplicationIdentifier" "$ROOT_DIR/Examples/MSPDemoApp/MSPDemoApp/Info.plist" 2>/dev/null; then
            print_pass "Info.plist contains GADApplicationIdentifier"
        else
            print_fail "Info.plist missing GADApplicationIdentifier"
            ((errors++)) || true
        fi
    else
        print_fail "Info.plist not found"
        ((errors++)) || true
    fi
    
    if [[ $errors -eq 0 ]]; then
        print_pass "SPM mode validation PASSED"
        return 0
    else
        print_fail "SPM mode validation FAILED ($errors error(s))"
        return 1
    fi
}

# ============================================================================
# Build Functions
# ============================================================================

build_pods_app() {
    local log_file="$1"
    
    if [[ "$SKIP_BUILD" == "true" ]]; then
        print_warn "Skipping build (--skip-build)"
        return 0
    fi
    
    print_info "Building MSPDemoApp (Pods mode)..."
    print_info "Log: $log_file"
    
    cd "$ROOT_DIR"
    
    local build_start=$(date +%s)
    
    # Use predictable derivedDataPath so xcframeworks can be pre-staged
    local derived_data_path="${HOME}/Library/Developer/Xcode/DerivedData/msp-ios-sdk-roundtrip"
    
    if xcodebuild -workspace msp-ios-sdk.xcworkspace \
        -scheme MSPDemoApp \
        -configuration Debug \
        -destination "platform=iOS Simulator,name=iPhone 16" \
        -derivedDataPath "$derived_data_path" \
        build 2>&1 | tee "$log_file"; then
        
        local build_end=$(date +%s)
        local build_duration=$((build_end - build_start))
        print_pass "Pods build SUCCEEDED (${build_duration}s)"
        return 0
    else
        local build_end=$(date +%s)
        local build_duration=$((build_end - build_start))
        echo ""
        print_fail "❌ BUILD FAILED in Pods mode (${build_duration}s)"
        echo ""
        echo -e "${RED}Last 40 lines of build log:${NC}"
        echo "────────────────────────────────────────────────────────────────────"
        tail -40 "$log_file"
        echo "────────────────────────────────────────────────────────────────────"
        echo ""
        print_info "Full log: $log_file"
        return 1
    fi
}

build_spm_app() {
    local log_file="$1"
    
    if [[ "$SKIP_BUILD" == "true" ]]; then
        print_warn "Skipping build (--skip-build)"
        return 0
    fi
    
    print_info "Building MSPDemoApp-SPM (SPM mode)..."
    print_info "Log: $log_file"
    
    cd "$ROOT_DIR"
    
    local build_start=$(date +%s)
    
    # Use predictable derivedDataPath for SPM builds as well
    local derived_data_path="${HOME}/Library/Developer/Xcode/DerivedData/msp-ios-sdk-roundtrip"
    
    if xcodebuild -project Examples/MSPDemoApp/MSPDemoApp.xcodeproj \
        -scheme MSPDemoApp-SPM \
        -configuration Debug \
        -destination "platform=iOS Simulator,name=iPhone 16" \
        -derivedDataPath "$derived_data_path" \
        build 2>&1 | tee "$log_file"; then
        
        local build_end=$(date +%s)
        local build_duration=$((build_end - build_start))
        print_pass "SPM build SUCCEEDED (${build_duration}s)"
        return 0
    else
        local build_end=$(date +%s)
        local build_duration=$((build_end - build_start))
        echo ""
        print_fail "❌ BUILD FAILED in SPM mode (${build_duration}s)"
        echo ""
        echo -e "${RED}Last 40 lines of build log:${NC}"
        echo "────────────────────────────────────────────────────────────────────"
        tail -40 "$log_file"
        echo "────────────────────────────────────────────────────────────────────"
        echo ""
        print_info "Full log: $log_file"
        return 1
    fi
}

# ============================================================================
# Single Cycle Execution
# ============================================================================

run_single_cycle() {
    local cycle_num="$1"
    local cycle_start=$(date +%s)
    local pods_log="$BUILD_LOG_DIR/cycle${cycle_num}-pods-$TIMESTAMP.log"
    local spm_log="$BUILD_LOG_DIR/cycle${cycle_num}-spm-$TIMESTAMP.log"
    
    print_banner "CYCLE $cycle_num of $STRESS_CYCLES" "$CYAN"
    
    # =========================================
    # PHASE 1: Switch to Pods Mode
    # =========================================
    print_section "Switching to Pods Mode"
    
    if ! "$SCRIPT_DIR/switch-target.sh" pods 2>&1 | tee -a "$REPORT_FILE"; then
        print_fail "Failed to switch to Pods mode"
        CYCLE_RESULTS+=("FAIL:switch-pods")
        return 1
    fi
    
    # =========================================
    # PHASE 2: Validate Pods Mode State
    # =========================================
    print_section "Validating Pods Mode State"
    
    if ! validate_pods_mode_state; then
        print_fail "Pods mode validation failed"
        CYCLE_RESULTS+=("FAIL:validate-pods")
        return 1
    fi
    
    # =========================================
    # PHASE 3: Build Pods App
    # =========================================
    print_section "Building Pods Mode"
    
    if ! build_pods_app "$pods_log"; then
        print_fail "Pods build failed - STOPPING"
        CYCLE_RESULTS+=("FAIL:build-pods")
        return 1
    fi
    
    # =========================================
    # PHASE 4: Switch to SPM Mode
    # =========================================
    print_section "Switching to SPM Mode"
    
    if ! "$SCRIPT_DIR/switch-target.sh" spm 2>&1 | tee -a "$REPORT_FILE"; then
        print_fail "Failed to switch to SPM mode"
        CYCLE_RESULTS+=("FAIL:switch-spm")
        return 1
    fi
    
    # =========================================
    # PHASE 5: Validate SPM Mode State
    # =========================================
    print_section "Validating SPM Mode State"
    
    if ! validate_spm_mode_state; then
        print_fail "SPM mode validation failed"
        CYCLE_RESULTS+=("FAIL:validate-spm")
        return 1
    fi
    
    # =========================================
    # PHASE 6: Build SPM App
    # =========================================
    print_section "Building SPM Mode"
    
    if ! build_spm_app "$spm_log"; then
        print_fail "SPM build failed - STOPPING"
        CYCLE_RESULTS+=("FAIL:build-spm")
        return 1
    fi
    
    # =========================================
    # Cycle Complete
    # =========================================
    local cycle_end=$(date +%s)
    local cycle_duration=$((cycle_end - cycle_start))
    
    CYCLE_TIMES+=("$cycle_duration")
    CYCLE_RESULTS+=("PASS")
    
    echo ""
    print_pass "━━━ CYCLE $cycle_num PASSED (${cycle_duration}s) ━━━"
    echo ""
    
    return 0
}

# ============================================================================
# Print Summary Table
# ============================================================================

print_summary_table() {
    local total_end=$(date +%s)
    local total_duration=$((total_end - TOTAL_START_TIME))
    
    print_banner "ROUND-TRIP TEST SUMMARY"
    
    echo ""
    echo "┌──────────┬──────────┬──────────────────┐"
    echo "│  Cycle   │  Result  │    Duration      │"
    echo "├──────────┼──────────┼──────────────────┤"
    
    local passed=0
    local failed=0
    
    for ((i=0; i<${#CYCLE_RESULTS[@]}; i++)); do
        local cycle_num=$((i + 1))
        local result="${CYCLE_RESULTS[$i]}"
        local duration="${CYCLE_TIMES[$i]:-N/A}"
        
        if [[ "$result" == "PASS" ]]; then
            printf "│    %2d    │  ${GREEN}PASS${NC}    │    %5ss        │\n" "$cycle_num" "$duration"
            ((passed++)) || true
        else
            local fail_reason="${result#FAIL:}"
            printf "│    %2d    │  ${RED}FAIL${NC}    │    %-12s  │\n" "$cycle_num" "$fail_reason"
            ((failed++)) || true
        fi
    done
    
    echo "├──────────┴──────────┴──────────────────┤"
    printf "│  Total: %-3d cycles in %5ds            │\n" "${#CYCLE_RESULTS[@]}" "$total_duration"
    printf "│  Passed: ${GREEN}%-3d${NC}  Failed: ${RED}%-3d${NC}              │\n" "$passed" "$failed"
    echo "└─────────────────────────────────────────┘"
    echo ""
    
    if [[ "$SKIP_BUILD" == "true" ]]; then
        print_warn "Note: Builds were skipped (--skip-build)"
    fi
    
    print_info "Full report: $REPORT_FILE"
    echo ""
}

# ============================================================================
# Main
# ============================================================================

main() {
    local cycle_label=""
    if [[ "$STRESS_CYCLES" -gt 1 ]]; then
        cycle_label=" (Stress Test: $STRESS_CYCLES cycles)"
    fi
    
    print_banner "ROUND-TRIP TEST: Pods ↔ SPM$cycle_label" "$BLUE"
    
    echo ""
    print_info "Repository: $ROOT_DIR"
    print_info "Report: $REPORT_FILE"
    print_info "Cycles: $STRESS_CYCLES"
    
    if [[ "$SKIP_BUILD" == "true" ]]; then
        print_warn "Build steps will be skipped (--skip-build)"
    else
        print_info "Each mode switch will be validated with a full build"
    fi
    
    # Write header to report
    {
        echo "============================================================"
        echo "Round-Trip Test Started: $(date)"
        echo "Stress Cycles: $STRESS_CYCLES"
        echo "Skip Build: $SKIP_BUILD"
        echo "============================================================"
    } >> "$REPORT_FILE"
    
    # Run all cycles
    for ((cycle=1; cycle<=STRESS_CYCLES; cycle++)); do
        if ! run_single_cycle "$cycle"; then
            echo ""
            print_fail "Round-trip test ABORTED at cycle $cycle"
            print_summary_table
            
            {
                echo ""
                echo "============================================================"
                echo "Round-Trip Test FAILED at cycle $cycle: $(date)"
                echo "============================================================"
            } >> "$REPORT_FILE"
            
            exit 1
        fi
    done
    
    # Final: End in Pods mode
    print_banner "FINAL STATE: Returning to Pods Mode" "$BLUE"
    
    print_section "Final Switch to Pods Mode"
    if ! "$SCRIPT_DIR/switch-target.sh" pods 2>&1 | tee -a "$REPORT_FILE"; then
        print_fail "Final switch to Pods mode failed"
        print_summary_table
        exit 1
    fi
    
    print_section "Final Pods Mode Validation"
    if ! validate_pods_mode_state; then
        print_fail "Final Pods mode validation failed"
        print_summary_table
        exit 1
    fi
    
    # Success!
    {
        echo ""
        echo "============================================================"
        echo "Round-Trip Test PASSED: $(date)"
        echo "Cycles Completed: $STRESS_CYCLES"
        echo "============================================================"
    } >> "$REPORT_FILE"
    
    print_summary_table
    
    echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║                                                                    ║${NC}"
    printf "${GREEN}${BOLD}║${NC}     ${GREEN}✓ Round-trip test PASSED! (%d cycle(s))${NC}                       ${GREEN}${BOLD}║${NC}\n" "$STRESS_CYCLES"
    echo -e "${GREEN}${BOLD}║                                                                    ║${NC}"
    echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    exit 0
}

main "$@"
