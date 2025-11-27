#!/usr/bin/env bash
# ============================================================================
# Round-Trip Test Script (Three-Mode Architecture)
# ============================================================================
# Purpose: Validates switching between all three modes works correctly:
#          pods-dev → pods-release → spm-release
#
# Final Architecture:
#   - pods-dev:     All modules as SOURCE, builds DemoApp
#   - pods-release: Validates 5 core XCFrameworks only (NO build)
#   - spm-release:  Validates Package.swift + 5 XCFrameworks
#
# IMPORTANT:
#   - Adapters are SOURCE-ONLY in all modes (never require XCFrameworks)
#   - Only 5 core XCFrameworks are required
#   - DemoApp is ONLY built in pods-dev mode
#
# Usage:   ./Scripts/target-switching/round-trip-test.sh [options]
#
# Options:
#   --skip-build      Skip DemoApp build in pods-dev (validation only)
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
                echo -e "${RED}[ERROR]${NC} Invalid --loops value: $LOOPS (must be positive integer)"
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
            echo "  --skip-build   Skip DemoApp build in pods-dev (validation only)"
            echo "  --loops=N      Run N complete cycles (default: 1)"
            echo "  --verbose      Enable verbose output"
            echo ""
            echo "Test Cycle: pods-dev → pods-release → spm-release"
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

# The 5 required core XCFrameworks (adapters are SOURCE-ONLY)
CORE_XCFRAMEWORKS=(
    "MSPCore"
    "MSPiOSCore"
    "MSPSharedLibraries"
    "MSPOMSDK"
    "NovaCore"
)

# ============================================================================
# Helper Functions
# ============================================================================

log_header() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                         $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

log_section() {
    echo ""
    echo "══════════════════════════════════════════════════════════════════════"
    echo "  $1"
    echo "══════════════════════════════════════════════════════════════════════"
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

# ============================================================================
# Validation Functions
# ============================================================================

# Check if workspace symlink exists at project root
validate_workspace_symlink() {
    local symlink="$ROOT_DIR/msp-ios-sdk.xcworkspace"
    
    if [[ -L "$symlink" ]] || [[ -d "$symlink" ]]; then
        log_ok "Workspace symlink exists: msp-ios-sdk.xcworkspace"
        return 0
    else
        log_fail "Workspace symlink missing: msp-ios-sdk.xcworkspace"
        return 1
    fi
}

# Validate only the 5 core XCFrameworks exist
validate_core_xcframeworks() {
    local errors=0
    
    # Check Binary/ first, then Build/XCFrameworks/
    local xcf_dir="$ROOT_DIR/Binary"
    if [[ ! -d "$xcf_dir" ]] || [[ -z "$(ls -A "$xcf_dir" 2>/dev/null)" ]]; then
        xcf_dir="$ROOT_DIR/Build/XCFrameworks"
    fi
    
    echo "  Checking 5 core XCFrameworks in: $xcf_dir"
    
    for xcf in "${CORE_XCFRAMEWORKS[@]}"; do
        if [[ -d "$xcf_dir/${xcf}.xcframework" ]]; then
            log_ok "$xcf.xcframework"
        else
            log_fail "$xcf.xcframework (MISSING)"
            ((errors++)) || true
        fi
    done
    
    return $errors
}

# Validate Package.swift exists and is syntactically valid
validate_package_swift() {
    if [[ ! -f "$ROOT_DIR/Package.swift" ]]; then
        log_fail "Package.swift does not exist"
        return 1
    fi
    
    log_ok "Package.swift exists"
    
    # Validate syntax using swift package dump-package
    cd "$ROOT_DIR"
    if swift package dump-package >/dev/null 2>&1; then
        log_ok "Package.swift syntax is valid"
        return 0
    else
        log_fail "Package.swift has syntax errors"
        return 1
    fi
}

# Check git status (tracked files only)
check_git_clean() {
    cd "$ROOT_DIR"
    local git_status
    git_status=$(git status --porcelain 2>/dev/null | grep -v "^??" || true)
    
    if [[ -z "$git_status" ]]; then
        log_ok "Git status clean (no tracked file changes)"
        return 0
    else
        log_warn "Git has uncommitted changes:"
        echo "$git_status" | head -10 | while read -r line; do
            echo "       $line"
        done
        # Warning only, not a failure
        return 0
    fi
}

# ============================================================================
# Mode Test Functions
# ============================================================================

# Test pods-dev mode
test_pods_dev() {
    log_header "PODS-DEV MODE"
    local errors=0
    
    # Step 1: Switch to pods-dev
    echo ""
    echo "  [1/4] Switching to pods-dev..."
    if MSP_RELEASE=0 "$SCRIPT_DIR/switch-target.sh" pods-dev >/dev/null 2>&1; then
        log_ok "switch-target.sh pods-dev succeeded"
    else
        log_fail "switch-target.sh pods-dev failed"
        return 1
    fi
    
    # Step 2: Validate workspace symlink
    echo ""
    echo "  [2/4] Validating workspace symlink..."
    if ! validate_workspace_symlink; then
        ((errors++)) || true
    fi
    
    # Step 3: Build DemoApp
    echo ""
    echo "  [3/4] Building DemoApp..."
    if [[ "$SKIP_BUILD" == "true" ]]; then
        log_warn "Build skipped (--skip-build)"
    else
        local log_file="$BUILD_LOG_DIR/pods-dev-$TIMESTAMP.log"
        cd "$ROOT_DIR"
        
        if xcodebuild -workspace msp-ios-sdk.xcworkspace \
            -scheme MSPDemoApp \
            -configuration Debug \
            -destination "platform=iOS Simulator,name=iPhone 16" \
            build 2>&1 | tee "$log_file" | tail -3; then
            
            # Check if build succeeded
            if grep -q "BUILD SUCCEEDED" "$log_file"; then
                log_ok "DemoApp build SUCCEEDED"
            else
                log_fail "DemoApp build FAILED"
                echo ""
                echo "  Last 30 lines of build log:"
                tail -30 "$log_file" | sed 's/^/       /'
                return 1
            fi
        else
            log_fail "xcodebuild command failed"
            return 1
        fi
    fi
    
    # Step 4: Check git status
    echo ""
    echo "  [4/4] Checking git status..."
    check_git_clean
    
    if [[ $errors -eq 0 ]]; then
        echo ""
        echo -e "  ${GREEN}━━━ pods-dev: PASSED ━━━${NC}"
        return 0
    else
        echo ""
        echo -e "  ${RED}━━━ pods-dev: FAILED ━━━${NC}"
        return 1
    fi
}

# Test pods-release mode
test_pods_release() {
    log_header "PODS-RELEASE MODE"
    local errors=0
    
    # Step 1: Switch to pods-release
    echo ""
    echo "  [1/3] Switching to pods-release..."
    if MSP_RELEASE=1 "$SCRIPT_DIR/switch-target.sh" pods-release >/dev/null 2>&1; then
        log_ok "switch-target.sh pods-release succeeded"
    else
        log_fail "switch-target.sh pods-release failed"
        echo ""
        log_warn "pods-release requires 5 core XCFrameworks."
        log_warn "Build them first: ./Scripts/xcframeworks/build-core.sh"
        return 1
    fi
    
    # Step 2: Validate ONLY 5 core XCFrameworks (NO DemoApp build!)
    echo ""
    echo "  [2/3] Validating core XCFrameworks..."
    echo "  NOTE: DemoApp is NOT built in pods-release mode"
    if ! validate_core_xcframeworks; then
        log_fail "Core XCFramework validation failed"
        ((errors++)) || true
    fi
    
    # Step 3: Check git status
    echo ""
    echo "  [3/3] Checking git status..."
    check_git_clean
    
    if [[ $errors -eq 0 ]]; then
        echo ""
        echo -e "  ${GREEN}━━━ pods-release: PASSED ━━━${NC}"
        return 0
    else
        echo ""
        echo -e "  ${RED}━━━ pods-release: FAILED ━━━${NC}"
        return 1
    fi
}

# Test spm-release mode
test_spm_release() {
    log_header "SPM-RELEASE MODE"
    local errors=0
    
    # Step 1: Switch to spm-release
    echo ""
    echo "  [1/4] Switching to spm-release..."
    if "$SCRIPT_DIR/switch-target.sh" spm-release >/dev/null 2>&1; then
        log_ok "switch-target.sh spm-release succeeded"
    else
        log_fail "switch-target.sh spm-release failed"
        return 1
    fi
    
    # Step 2: Validate Package.swift
    echo ""
    echo "  [2/4] Validating Package.swift..."
    if ! validate_package_swift; then
        ((errors++)) || true
    fi
    
    # Step 3: Validate core XCFrameworks (also required for SPM)
    echo ""
    echo "  [3/4] Validating core XCFrameworks..."
    if ! validate_core_xcframeworks; then
        ((errors++)) || true
    fi
    
    # Step 4: Check git status
    echo ""
    echo "  [4/4] Checking git status..."
    check_git_clean
    
    if [[ $errors -eq 0 ]]; then
        echo ""
        echo -e "  ${GREEN}━━━ spm-release: PASSED ━━━${NC}"
        return 0
    else
        echo ""
        echo -e "  ${RED}━━━ spm-release: FAILED ━━━${NC}"
        return 1
    fi
}

# ============================================================================
# Main
# ============================================================================

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║           ROUND-TRIP TEST: Three-Mode Architecture                 ║"
    echo "║                                                                    ║"
    echo "║   Cycle: pods-dev → pods-release → spm-release                     ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Configuration:"
    echo "  Repository: $ROOT_DIR"
    echo "  Loops: $LOOPS"
    echo "  Skip Build: $SKIP_BUILD"
    echo ""
    echo "Required Core XCFrameworks (5):"
    for xcf in "${CORE_XCFRAMEWORKS[@]}"; do
        echo "  - $xcf"
    done
    echo ""
    echo "NOTE: Adapters are SOURCE-ONLY in all modes (no XCFrameworks needed)"
    echo "NOTE: DemoApp is ONLY built in pods-dev mode"
    echo ""
    
    local passed_loops=0
    local failed_loops=0
    
    for ((loop=1; loop<=LOOPS; loop++)); do
        log_section "LOOP $loop of $LOOPS"
        
        # Test pods-dev
        if ! test_pods_dev; then
            echo -e "${RED}[FAILED]${NC} Loop $loop failed at pods-dev"
            ((failed_loops++)) || true
            break
        fi
        
        # Test pods-release
        if ! test_pods_release; then
            echo -e "${RED}[FAILED]${NC} Loop $loop failed at pods-release"
            ((failed_loops++)) || true
            break
        fi
        
        # Test spm-release
        if ! test_spm_release; then
            echo -e "${RED}[FAILED]${NC} Loop $loop failed at spm-release"
            ((failed_loops++)) || true
            break
        fi
        
        ((passed_loops++)) || true
        echo ""
        echo -e "${GREEN}[Loop $loop/$LOOPS] ALL MODES PASSED${NC}"
    done
    
    # Final Summary
    log_section "FINAL SUMMARY"
    
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
        echo -e "${GREEN}║        ✓ ALL MODES PASSED SUCCESSFULLY ($passed_loops loop(s))             ║${NC}"
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
