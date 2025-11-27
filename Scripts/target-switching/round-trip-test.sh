#!/usr/bin/env bash
# ============================================================================
# Round-Trip Test Script (Three-Mode Architecture)
# ============================================================================
# Purpose: Validates switching between all three modes works correctly:
#          pods-dev → pods-release → spm-release → pods-dev
#
# Final Architecture:
#   - pods-dev:     All modules as SOURCE (development)
#   - pods-release: Core modules as BINARY, Adapters as SOURCE
#   - spm-release:  Core modules as BINARY, Adapters as SOURCE
#
# IMPORTANT:
#   - Adapters are SOURCE-ONLY in all modes (never require XCFrameworks)
#   - Only 5 core XCFrameworks are required: MSPCore, MSPiOSCore,
#     MSPSharedLibraries, MSPOMSDK, NovaCore
#
# Usage:   ./Scripts/target-switching/round-trip-test.sh [options]
#
# Options:
#   --skip-build      Skip actual Xcode builds (validation only)
#   --loops=N         Run N complete cycles (default: 1)
#   --verbose         Enable verbose output
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
# Colors and Formatting
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================================================
# Report Output Functions (Structured Format)
# ============================================================================

report() {
    echo -e "$1"
}

report_section() {
    echo ""
    echo "=================================================="
    echo "$1"
    echo "=================================================="
}

report_switch() {
    local mode="$1"
    local status="$2"
    if [[ "$status" == "OK" ]]; then
        echo -e "[RoundTrip] Switching → ${GREEN}$mode${NC} ... ${GREEN}OK${NC}"
    else
        echo -e "[${RED}ERROR${NC}] Mode switch failed: $mode"
    fi
}

report_check() {
    local item="$1"
    local status="$2"
    if [[ "$status" == "OK" ]]; then
        echo -e "[Check] Generated ${GREEN}$item${NC} OK"
    else
        echo -e "[${RED}ERROR${NC}] Missing: $item"
    fi
}

report_build() {
    local mode="$1"
    local desc="$2"
    local status="$3"
    if [[ "$status" == "OK" ]]; then
        echo -e "[Build] ${GREEN}$mode${NC} $desc ... ${GREEN}OK${NC}"
    else
        echo -e "[${RED}ERROR${NC}] $mode $desc ... FAILED"
    fi
}

report_warning() {
    echo -e "[${YELLOW}Warning${NC}] $1"
}

report_git() {
    local status="$1"
    if [[ "$status" == "OK" ]]; then
        echo -e "[Git] No diffs after switch → ${GREEN}OK${NC}"
    else
        echo -e "[${RED}ERROR${NC}] Git diff detected:"
    fi
}

report_loop() {
    local current="$1"
    local total="$2"
    echo ""
    echo -e "[${GREEN}Loop $current/$total Completed Successfully${NC}]"
}

# ============================================================================
# Parse Arguments
# ============================================================================
SKIP_BUILD=false
LOOPS=1
VERBOSE=false

for arg in "$@"; do
    case "$arg" in
        --skip-build)
            SKIP_BUILD=true
            ;;
        --loops=*)
            LOOPS="${arg#*=}"
            if ! [[ "$LOOPS" =~ ^[0-9]+$ ]] || [[ "$LOOPS" -lt 1 ]]; then
                echo "[ERROR] Invalid --loops value: $LOOPS (must be positive integer)"
                exit 1
            fi
            ;;
        --verbose)
            VERBOSE=true
            ;;
        -h|--help)
            echo "Usage: $0 [--skip-build] [--loops=N] [--verbose]"
            echo ""
            echo "Options:"
            echo "  --skip-build   Skip actual Xcode builds (validation only)"
            echo "  --loops=N      Run N complete cycles (default: 1)"
            echo "  --verbose      Enable verbose output"
            echo ""
            echo "Test Cycle: pods-dev → pods-release → spm-release → pods-dev"
            exit 0
            ;;
        *)
            echo "[ERROR] Unknown option: $arg"
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

# Required Core XCFrameworks (ONLY these 5 are validated)
CORE_XCFRAMEWORKS_LIST=(
    "MSPCore"
    "MSPiOSCore"
    "MSPSharedLibraries"
    "MSPOMSDK"
    "NovaCore"
)

# ============================================================================
# Validation Functions
# ============================================================================

# Validate generated files exist
validate_generated_files() {
    local mode="$1"
    local errors=0
    
    # workspace.yml
    if [[ -f "$ROOT_DIR/workspace.yml" ]]; then
        report_check "workspace.yml" "OK"
    else
        report_check "workspace.yml" "MISSING"
        ((errors++)) || true
    fi
    
    # project.yml
    if [[ -f "$ROOT_DIR/Examples/MSPDemoApp/project.yml" ]]; then
        report_check "project.yml" "OK"
    else
        report_check "project.yml" "MISSING"
        ((errors++)) || true
    fi
    
    # Package.swift (only for spm-release)
    if [[ "$mode" == "spm-release" ]]; then
        if [[ -f "$ROOT_DIR/Package.swift" ]]; then
            report_check "Package.swift" "OK"
        else
            report_check "Package.swift" "MISSING"
            ((errors++)) || true
        fi
    fi
    
    return $errors
}

# Validate ONLY the 5 core XCFrameworks (for pods-release and spm-release)
validate_core_xcframeworks() {
    local errors=0
    local xcf_dir="$ROOT_DIR/Build/XCFrameworks"
    local bin_dir="$ROOT_DIR/Binary"
    
    # Check Binary/ first, fall back to Build/XCFrameworks/
    if [[ -d "$bin_dir" ]] && [[ "$(ls -A "$bin_dir" 2>/dev/null)" ]]; then
        xcf_dir="$bin_dir"
    fi
    
    for xcf in "${CORE_XCFRAMEWORKS_LIST[@]}"; do
        if [[ -d "$xcf_dir/${xcf}.xcframework" ]]; then
            echo -e "  [Check] ${GREEN}$xcf.xcframework${NC} OK"
        else
            echo -e "  [${RED}ERROR${NC}] Missing: $xcf.xcframework"
            ((errors++)) || true
        fi
    done
    
    return $errors
}

# Validate Package.swift syntax
validate_package_swift_syntax() {
    if [[ ! -f "$ROOT_DIR/Package.swift" ]]; then
        return 1
    fi
    
    # Basic syntax check using swift package dump-package
    cd "$ROOT_DIR"
    if swift package dump-package >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Check git cleanliness (tracked files only)
check_git_clean() {
    cd "$ROOT_DIR"
    local git_status
    git_status=$(git status --porcelain 2>/dev/null | grep -v "^??" || true)
    
    if [[ -z "$git_status" ]]; then
        report_git "OK"
        return 0
    else
        report_git "DIRTY"
        echo "$git_status" | head -20
        return 1
    fi
}

# ============================================================================
# Mode Switch and Validation Functions
# ============================================================================

# Switch to pods-dev mode and validate
switch_pods_dev() {
    report_section "1. Mode Switch Status"
    
    if MSP_RELEASE=0 "$SCRIPT_DIR/switch-target.sh" pods-dev >/dev/null 2>&1; then
        report_switch "pods-dev" "OK"
    else
        report_switch "pods-dev" "FAILED"
        return 1
    fi
    
    report_section "2. Generated File Validation"
    if ! validate_generated_files "pods-dev"; then
        return 1
    fi
    
    # Validate that workspace actually exists
    # The workspace is generated at .generated/msp-ios-sdk.xcworkspace
    # We need to create a symlink at root for xcodebuild to work properly
    local GENERATED_WORKSPACE="$ROOT_DIR/.generated/msp-ios-sdk.xcworkspace"
    local ROOT_WORKSPACE="$ROOT_DIR/msp-ios-sdk.xcworkspace"
    
    if [[ -d "$GENERATED_WORKSPACE" ]]; then
        # Ensure symlink exists at root pointing to generated workspace
        if [[ ! -L "$ROOT_WORKSPACE" ]] || [[ ! -e "$ROOT_WORKSPACE" ]]; then
            rm -f "$ROOT_WORKSPACE" 2>/dev/null || true
            ln -sf ".generated/msp-ios-sdk.xcworkspace" "$ROOT_WORKSPACE"
        fi
        report_check "msp-ios-sdk.xcworkspace" "OK"
    elif [[ -d "$ROOT_WORKSPACE" ]]; then
        # Workspace exists directly at root (legacy)
        report_check "msp-ios-sdk.xcworkspace" "OK"
    else
        report_check "msp-ios-sdk.xcworkspace" "MISSING"
        echo -e "[${RED}ERROR${NC}] pods-dev workspace not found at:"
        echo "  - $GENERATED_WORKSPACE"
        echo "  - $ROOT_WORKSPACE"
        return 1
    fi
    
    report_section "3. Build / Lint Validation"
    if [[ "$SKIP_BUILD" == "true" ]]; then
        report_warning "Build skipped (--skip-build)"
        report_build "pods-dev" "DemoApp build" "OK"
    else
        echo "[Build] pods-dev DemoApp build ..."
        echo "  Workspace: $ROOT_WORKSPACE"
        echo "  Scheme: MSPDemoApp"
        local log_file="$BUILD_LOG_DIR/pods-dev-$TIMESTAMP.log"
        
        cd "$ROOT_DIR"
        # MANDATORY: pods-dev MUST build the DemoApp successfully
        # This is a real xcodebuild that validates all source code compiles
        if xcodebuild -workspace msp-ios-sdk.xcworkspace \
            -scheme MSPDemoApp \
            -configuration Debug \
            -destination "platform=iOS Simulator,name=iPhone 16" \
            build 2>&1 | tee "$log_file" | tail -5; then
            report_build "pods-dev" "DemoApp build" "OK"
        else
            report_build "pods-dev" "DemoApp build" "FAILED"
            echo ""
            echo -e "[${RED}ERROR${NC}] pods-dev build failed"
            echo ""
            echo "Last 40 lines of build log:"
            tail -40 "$log_file"
            return 1
        fi
    fi
    
    return 0
}

# Switch to pods-release mode and validate
switch_pods_release() {
    report_section "1. Mode Switch Status"
    
    if MSP_RELEASE=1 "$SCRIPT_DIR/switch-target.sh" pods-release >/dev/null 2>&1; then
        report_switch "pods-release" "OK"
    else
        report_switch "pods-release" "FAILED"
        return 1
    fi
    
    report_section "2. Generated File Validation"
    if ! validate_generated_files "pods-release"; then
        return 1
    fi
    
    report_section "3. Build / Lint Validation"
    echo "[Build] pods-release validating core XCFrameworks ..."
    echo ""
    echo "Checking 5 required core XCFrameworks:"
    
    if validate_core_xcframeworks; then
        echo ""
        report_build "pods-release" "found core XCFrameworks" "OK"
    else
        echo ""
        report_build "pods-release" "found core XCFrameworks" "FAILED"
        echo ""
        report_warning "Missing core XCFrameworks. Run: ./Scripts/xcframeworks/build-core.sh"
        return 1
    fi
    
    # NOTE: We do NOT build DemoApp in pods-release mode
    # Only validate that core XCFrameworks exist and templates generated correctly
    
    return 0
}

# Switch to spm-release mode and validate
switch_spm_release() {
    report_section "1. Mode Switch Status"
    
    if "$SCRIPT_DIR/switch-target.sh" spm-release >/dev/null 2>&1; then
        report_switch "spm-release" "OK"
    else
        report_switch "spm-release" "FAILED"
        return 1
    fi
    
    report_section "2. Generated File Validation"
    if ! validate_generated_files "spm-release"; then
        return 1
    fi
    
    report_section "3. Build / Lint Validation"
    echo "[Build] spm-release validating Package.swift syntax ..."
    
    if validate_package_swift_syntax; then
        report_build "spm-release" "Package.swift lint" "OK"
    else
        report_build "spm-release" "Package.swift lint" "FAILED"
        return 1
    fi
    
    # Also validate core XCFrameworks for spm-release
    echo ""
    echo "Checking 5 required core XCFrameworks:"
    if validate_core_xcframeworks; then
        echo ""
        report_build "spm-release" "found core XCFrameworks" "OK"
    else
        echo ""
        report_build "spm-release" "found core XCFrameworks" "FAILED"
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
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                      LOOP $loop_num of $LOOPS                              ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    
    # =========================================
    # STEP 1: pods-dev
    # =========================================
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                         PODS-DEV MODE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if ! switch_pods_dev; then
        echo ""
        echo -e "[${RED}ERROR${NC}] pods-dev mode failed"
        return 1
    fi
    
    # =========================================
    # STEP 2: pods-release
    # =========================================
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                       PODS-RELEASE MODE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if ! switch_pods_release; then
        echo ""
        echo -e "[${RED}ERROR${NC}] pods-release mode failed"
        return 1
    fi
    
    # =========================================
    # STEP 3: spm-release
    # =========================================
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                        SPM-RELEASE MODE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if ! switch_spm_release; then
        echo ""
        echo -e "[${RED}ERROR${NC}] spm-release mode failed"
        return 1
    fi
    
    # =========================================
    # STEP 4: Return to pods-dev
    # =========================================
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                    RETURNING TO PODS-DEV"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    report_section "1. Mode Switch Status"
    
    if MSP_RELEASE=0 "$SCRIPT_DIR/switch-target.sh" pods-dev >/dev/null 2>&1; then
        report_switch "pods-dev (final)" "OK"
    else
        report_switch "pods-dev (final)" "FAILED"
        return 1
    fi
    
    # =========================================
    # STEP 5: Git Cleanliness Check
    # =========================================
    report_section "5. Git Cleanliness Check"
    
    if ! check_git_clean; then
        report_warning "Git has uncommitted changes after round-trip"
        # Note: This is a warning, not a failure
    fi
    
    # =========================================
    # Loop Complete
    # =========================================
    report_loop "$loop_num" "$LOOPS"
    
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
    echo "  Skip Build: $SKIP_BUILD"
    echo ""
    echo "Core XCFrameworks Required (5):"
    for xcf in "${CORE_XCFRAMEWORKS_LIST[@]}"; do
        echo "  - $xcf"
    done
    echo ""
    echo "NOTE: Adapters are SOURCE-ONLY in all modes."
    echo "      Adapter XCFrameworks are NEVER required."
    echo ""
    
    local failed_loops=0
    local passed_loops=0
    
    for ((loop=1; loop<=LOOPS; loop++)); do
        if run_single_loop "$loop"; then
            ((passed_loops++)) || true
        else
            ((failed_loops++)) || true
            echo ""
            echo -e "[${RED}ERROR${NC}] Loop $loop FAILED"
            break
        fi
    done
    
    # =========================================
    # Final Summary
    # =========================================
    report_section "6. Loop Summary"
    
    echo ""
    echo "┌─────────────────────────────────────────┐"
    echo "│           ROUND-TRIP SUMMARY            │"
    echo "├─────────────────────────────────────────┤"
    printf "│  Total Loops:   %-22d │\n" "$LOOPS"
    printf "│  Passed:        ${GREEN}%-22d${NC} │\n" "$passed_loops"
    printf "│  Failed:        ${RED}%-22d${NC} │\n" "$failed_loops"
    echo "├─────────────────────────────────────────┤"
    
    if [[ $failed_loops -eq 0 ]]; then
        echo -e "│  Status:        ${GREEN}ALL PASSED${NC}              │"
        echo "└─────────────────────────────────────────┘"
        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                                                                    ║${NC}"
        echo -e "${GREEN}║        ✓ Round-trip test PASSED! ($passed_loops loop(s))                    ║${NC}"
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
