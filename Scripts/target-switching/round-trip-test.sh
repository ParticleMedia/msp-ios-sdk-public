#!/usr/bin/env bash
# ============================================================================
# Round-Trip Test Script
# ============================================================================
# Purpose: Validates that switching between Pods and SPM modes works correctly
#          by performing a full round-trip test: Pods → SPM → Pods
#
# Usage:   ./Scripts/target-switching/round-trip-test.sh [options]
#
# Options:
#   --skip-build      Skip actual Xcode builds (only test mode switching)
#   --stress=N        Run N complete cycles (default: 1)
#                     Example: --stress=3 runs Pods→SPM→Pods→SPM→Pods→SPM
#
# Exit codes:
#   0 - Round-trip test passed
#   1 - Round-trip test failed
# ============================================================================

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/target-switching/common.sh
source "$SCRIPT_DIR/common.sh"

ensure_repo_root

# Parse arguments
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
                log_error "Invalid --stress value: $STRESS_CYCLES (must be positive integer)"
                exit 1
            fi
            ;;
        -h|--help)
            echo "Usage: $0 [--skip-build] [--stress=N]"
            echo ""
            echo "Options:"
            echo "  --skip-build   Skip actual Xcode builds"
            echo "  --stress=N     Run N complete cycles (default: 1)"
            exit 0
            ;;
        *)
            log_error "Unknown option: $arg"
            exit 1
            ;;
    esac
done

# ============================================================================
# Test Configuration
# ============================================================================

REPORT_FILE="$ROOT_DIR/BuildReports/round-trip-test-$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$(dirname "$REPORT_FILE")"

# Test results
declare -A RESULTS

# ============================================================================
# Helper Functions
# ============================================================================

log_to_report() {
    echo "$1" | tee -a "$REPORT_FILE"
}

run_stage() {
    local stage_name="$1"
    local stage_cmd="$2"
    
    log_section "Stage: $stage_name"
    log_to_report "$(date '+%Y-%m-%d %H:%M:%S') - Starting: $stage_name"
    
    local start_time=$(date +%s)
    
    if eval "$stage_cmd" >> "$REPORT_FILE" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        RESULTS["$stage_name"]="PASS (${duration}s)"
        log_success "$stage_name: PASSED (${duration}s)"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        RESULTS["$stage_name"]="FAIL (${duration}s)"
        log_error "$stage_name: FAILED (${duration}s)"
        return 1
    fi
}

build_pods_app() {
    if [[ "$SKIP_BUILD" == "true" ]]; then
        log_info "Skipping build (--skip-build)"
        return 0
    fi
    
    log_info "Building MSPDemoApp (Pods mode)..."
    cd "$ROOT_DIR/Examples/MSPDemoApp"
    xcodebuild -workspace ../../msp-ios-sdk.xcworkspace \
        -scheme MSPDemoApp \
        -configuration Debug \
        -destination "platform=iOS Simulator,name=iPhone 16" \
        -quiet \
        build
}

build_spm_app() {
    if [[ "$SKIP_BUILD" == "true" ]]; then
        log_info "Skipping build (--skip-build)"
        return 0
    fi
    
    log_info "Building MSPDemoApp-SPM (SPM mode)..."
    cd "$ROOT_DIR/Examples/MSPDemoApp"
    xcodebuild -project MSPDemoApp.xcodeproj \
        -scheme MSPDemoApp-SPM \
        -configuration Debug \
        -destination "platform=iOS Simulator,name=iPhone 16" \
        -quiet \
        build
}

validate_pods_mode() {
    log_info "Validating Pods mode..."
    
    # Check Pods/ exists
    if [[ ! -d "$ROOT_DIR/Pods" ]]; then
        log_error "Pods/ directory missing"
        return 1
    fi
    
    # Check Podfile.lock exists
    if [[ ! -f "$ROOT_DIR/Podfile.lock" ]]; then
        log_error "Podfile.lock missing"
        return 1
    fi
    
    # Check workspace contains Pods
    if [[ -d "$ROOT_DIR/msp-ios-sdk.xcworkspace" ]]; then
        if ! grep -q "Pods/Pods.xcodeproj" "$ROOT_DIR/msp-ios-sdk.xcworkspace/contents.xcworkspacedata" 2>/dev/null; then
            log_error "Workspace doesn't contain Pods project"
            return 1
        fi
    else
        log_error "Workspace missing"
        return 1
    fi
    
    # Check no SPM artifacts
    if find "$ROOT_DIR" -type d -name ".swiftpm" ! -path "*/Pods/*" ! -path "*/.git/*" -print -quit 2>/dev/null | grep -q .; then
        log_error "SPM artifacts (.swiftpm) found in Pods mode"
        return 1
    fi
    
    log_success "Pods mode validation passed"
    return 0
}

validate_spm_mode() {
    log_info "Validating SPM mode..."
    
    # Check Pods/ doesn't exist
    if [[ -d "$ROOT_DIR/Pods" ]]; then
        log_error "Pods/ directory exists in SPM mode"
        return 1
    fi
    
    # Check Package.swift exists
    if [[ ! -f "$ROOT_DIR/Package.swift" ]]; then
        log_error "Package.swift missing"
        return 1
    fi
    
    # Check required XCFrameworks exist
    if ! "$SCRIPT_DIR/validate_xcframeworks.sh" >/dev/null 2>&1; then
        log_error "XCFramework validation failed"
        return 1
    fi
    
    log_success "SPM mode validation passed"
    return 0
}

# ============================================================================
# Main Test Sequence
# ============================================================================

run_single_cycle() {
    local cycle_num="$1"
    local stage_prefix="Cycle $cycle_num"
    local failed=0
    
    log_section "$stage_prefix: Pods → SPM → Pods"
    
    # Switch to Pods
    if ! run_stage "$stage_prefix.1 Switch to Pods" "$SCRIPT_DIR/switch-target.sh pods"; then
        ((failed++))
    fi
    
    # Validate Pods mode
    if ! run_stage "$stage_prefix.2 Validate Pods Mode" "validate_pods_mode"; then
        ((failed++))
    fi
    
    # Build Pods app
    if ! run_stage "$stage_prefix.3 Build Pods App" "build_pods_app"; then
        ((failed++))
    fi
    
    # Switch to SPM
    if ! run_stage "$stage_prefix.4 Switch to SPM" "$SCRIPT_DIR/switch-target.sh spm"; then
        ((failed++))
    fi
    
    # Validate SPM mode
    if ! run_stage "$stage_prefix.5 Validate SPM Mode" "validate_spm_mode"; then
        ((failed++))
    fi
    
    # Build SPM app
    if ! run_stage "$stage_prefix.6 Build SPM App" "build_spm_app"; then
        ((failed++))
    fi
    
    return $failed
}

main() {
    local cycle_label=""
    if [[ "$STRESS_CYCLES" -gt 1 ]]; then
        cycle_label=" (Stress Test: $STRESS_CYCLES cycles)"
    fi
    
    log_title "Round-Trip Test: Pods → SPM → Pods$cycle_label"
    log_info "Repository: $ROOT_DIR"
    log_info "Report: $REPORT_FILE"
    log_info "Cycles: $STRESS_CYCLES"
    
    if [[ "$SKIP_BUILD" == "true" ]]; then
        log_warn "Build steps will be skipped (--skip-build)"
    fi
    
    echo "" >> "$REPORT_FILE"
    echo "============================================================" >> "$REPORT_FILE"
    echo "Round-Trip Test Started: $(date)" >> "$REPORT_FILE"
    echo "Stress Cycles: $STRESS_CYCLES" >> "$REPORT_FILE"
    echo "============================================================" >> "$REPORT_FILE"
    
    local total_failed=0
    
    # Run stress cycles
    for ((cycle=1; cycle<=STRESS_CYCLES; cycle++)); do
        log_title "━━━ Starting Cycle $cycle of $STRESS_CYCLES ━━━"
        
        if ! run_single_cycle "$cycle"; then
            cycle_errors=$?
            ((total_failed += cycle_errors))
            log_warn "Cycle $cycle completed with $cycle_errors error(s)"
        else
            log_success "Cycle $cycle completed successfully"
        fi
    done
    
    # Final validation: ensure we end in Pods mode
    log_section "Final State Verification"
    if ! run_stage "Final: Switch to Pods" "$SCRIPT_DIR/switch-target.sh pods"; then
        ((total_failed++))
    fi
    
    if ! run_stage "Final: Validate Pods Mode" "validate_pods_mode"; then
        ((total_failed++))
    fi
    
    if ! run_stage "Final: Build Pods App" "build_pods_app"; then
        ((total_failed++))
    fi
    
    # Summary
    log_title "Round-Trip Test Summary"
    
    echo ""
    echo "============================================================"
    echo "Test Results:"
    echo "============================================================"
    
    for stage in "${!RESULTS[@]}"; do
        result="${RESULTS[$stage]}"
        if [[ "$result" == PASS* ]]; then
            echo "  ✓ $stage: $result"
        else
            echo "  ✗ $stage: $result"
        fi
    done | sort
    
    echo "============================================================"
    
    echo "" >> "$REPORT_FILE"
    echo "============================================================" >> "$REPORT_FILE"
    echo "Round-Trip Test Completed: $(date)" >> "$REPORT_FILE"
    echo "Stress Cycles Completed: $STRESS_CYCLES" >> "$REPORT_FILE"
    echo "Total Failures: $total_failed" >> "$REPORT_FILE"
    echo "============================================================" >> "$REPORT_FILE"
    
    if [[ $total_failed -eq 0 ]]; then
        log_success "Round-trip test PASSED! ($STRESS_CYCLES cycle(s))"
        log_info "Full report: $REPORT_FILE"
        exit 0
    else
        log_error "Round-trip test FAILED with $total_failed error(s) across $STRESS_CYCLES cycle(s)"
        log_info "Full report: $REPORT_FILE"
        exit 1
    fi
}

main "$@"

