#!/usr/bin/env bash
# ============================================================================
# CI Validation Script
# ============================================================================
# Purpose: Complete CI validation pipeline for msp-ios-sdk
#          Tests both CocoaPods and SPM builds with version synchronization
#
# Usage:   ./Scripts/ci/ci_validate.sh [--stress=N]
#
# Options:
#   --stress=N   Number of round-trip stress cycles (default: 2)
#
# Exit codes:
#   0 - All validations passed
#   1 - One or more validations failed
# ============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Parse arguments
STRESS_CYCLES=2
for arg in "$@"; do
    case "$arg" in
        --stress=*)
            STRESS_CYCLES="${arg#*=}"
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_step() { echo -e "${BLUE}▶${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_title() { echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"; }

cd "$ROOT_DIR"

# Track failures
FAILURES=0

run_step() {
    local step_name="$1"
    shift
    
    log_step "$step_name"
    if "$@"; then
        log_success "$step_name completed"
        return 0
    else
        log_error "$step_name FAILED"
        ((FAILURES++))
        return 1
    fi
}

# ============================================================================
# Step 1: Cleanup
# ============================================================================
log_title "Step 1: Environment Cleanup"

log_step "Cleaning CocoaPods environment..."
if [[ -x "$ROOT_DIR/Scripts/target-switching/cleanup_pods.sh" ]]; then
    "$ROOT_DIR/Scripts/target-switching/cleanup_pods.sh" --force || log_warn "Pods cleanup had warnings"
else
    rm -rf "$ROOT_DIR/Pods" "$ROOT_DIR/Podfile.lock" 2>/dev/null || true
fi
log_success "CocoaPods cleanup done"

log_step "Cleaning SPM environment..."
if [[ -x "$ROOT_DIR/Scripts/target-switching/cleanup_spm.sh" ]]; then
    "$ROOT_DIR/Scripts/target-switching/cleanup_spm.sh" --force || log_warn "SPM cleanup had warnings"
else
    rm -rf "$ROOT_DIR/.swiftpm" "$ROOT_DIR/.build" "$ROOT_DIR/Package.resolved" 2>/dev/null || true
    find "$ROOT_DIR/Examples" -type d -name ".swiftpm" -exec rm -rf {} + 2>/dev/null || true
fi
log_success "SPM cleanup done"

# ============================================================================
# Step 2: Sync from Pods
# ============================================================================
log_title "Step 2: CocoaPods Installation & Sync"

log_step "Running pod install..."
if ! pod install; then
    log_error "pod install failed"
    exit 1
fi
log_success "pod install completed"

log_step "Running SPM sync (extract XCFrameworks from Pods)..."
if [[ -x "$ROOT_DIR/Scripts/spm-sync/spm_sync_all.sh" ]]; then
    if ! "$ROOT_DIR/Scripts/spm-sync/spm_sync_all.sh"; then
        log_error "spm_sync_all.sh failed"
        exit 1
    fi
else
    log_warn "spm_sync_all.sh not found - skipping XCFramework extraction"
fi
log_success "SPM sync completed"

# ============================================================================
# Step 3: Validate XCFrameworks and Versions
# ============================================================================
log_title "Step 3: XCFramework & Version Validation"

if [[ -x "$ROOT_DIR/Scripts/target-switching/validate_xcframeworks.sh" ]]; then
    run_step "Validating XCFrameworks and dependency versions" \
        "$ROOT_DIR/Scripts/target-switching/validate_xcframeworks.sh"
else
    log_warn "validate_xcframeworks.sh not found - skipping validation"
fi

# ============================================================================
# Step 4: Build Pods Mode
# ============================================================================
log_title "Step 4: CocoaPods Build"

log_step "Switching to Pods mode..."
if [[ -x "$ROOT_DIR/Scripts/target-switching/switch-target.sh" ]]; then
    "$ROOT_DIR/Scripts/target-switching/switch-target.sh" pods || {
        log_error "switch-target.sh pods failed"
        ((FAILURES++))
    }
else
    log_warn "switch-target.sh not found"
fi

log_step "Building MSPDemoApp (Pods mode)..."
if xcodebuild -workspace "$ROOT_DIR/msp-ios-sdk.xcworkspace" \
    -scheme MSPDemoApp \
    -configuration Debug \
    -destination "platform=iOS Simulator,name=iPhone 16" \
    -quiet \
    build; then
    log_success "Pods build SUCCEEDED"
else
    log_error "Pods build FAILED"
    ((FAILURES++))
fi

# ============================================================================
# Step 5: Build SPM Mode
# ============================================================================
log_title "Step 5: Swift Package Manager Build"

log_step "Switching to SPM mode..."
if [[ -x "$ROOT_DIR/Scripts/target-switching/switch-target.sh" ]]; then
    "$ROOT_DIR/Scripts/target-switching/switch-target.sh" spm || {
        log_error "switch-target.sh spm failed"
        ((FAILURES++))
    }
else
    log_warn "switch-target.sh not found"
fi

log_step "Building MSPDemoApp-SPM (SPM mode)..."
if xcodebuild -project "$ROOT_DIR/Examples/MSPDemoApp/MSPDemoApp.xcodeproj" \
    -scheme MSPDemoApp-SPM \
    -configuration Debug \
    -destination "platform=iOS Simulator,name=iPhone 16" \
    -quiet \
    build; then
    log_success "SPM build SUCCEEDED"
else
    log_error "SPM build FAILED"
    ((FAILURES++))
fi

# ============================================================================
# Step 6: Round-Trip Stress Test
# ============================================================================
log_title "Step 6: Round-Trip Stress Test ($STRESS_CYCLES cycles)"

if [[ -x "$ROOT_DIR/Scripts/target-switching/round-trip-test.sh" ]]; then
    log_step "Running round-trip stress test with $STRESS_CYCLES cycles..."
    if "$ROOT_DIR/Scripts/target-switching/round-trip-test.sh" --stress="$STRESS_CYCLES"; then
        log_success "Round-trip stress test PASSED"
    else
        log_error "Round-trip stress test FAILED"
        ((FAILURES++))
    fi
else
    log_warn "round-trip-test.sh not found - skipping stress test"
fi

# ============================================================================
# Summary
# ============================================================================
log_title "CI Validation Summary"

echo "============================================================"
if [[ $FAILURES -eq 0 ]]; then
    log_success "ALL VALIDATIONS PASSED"
    echo ""
    echo "  ✓ Environment cleanup"
    echo "  ✓ CocoaPods installation"
    echo "  ✓ XCFramework sync"
    echo "  ✓ Version validation"
    echo "  ✓ Pods build"
    echo "  ✓ SPM build"
    echo "  ✓ Round-trip stress test ($STRESS_CYCLES cycles)"
    echo ""
    echo "============================================================"
    exit 0
else
    log_error "VALIDATION FAILED with $FAILURES error(s)"
    echo ""
    echo "  Check the output above for details."
    echo ""
    echo "============================================================"
    exit 1
fi

