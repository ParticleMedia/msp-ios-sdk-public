#!/usr/bin/env bash
# ============================================================================
# CI Validation Script (Hardened Version)
# ============================================================================
# Purpose: Complete CI validation pipeline for msp-ios-sdk
#          Tests both CocoaPods and SPM builds with proper mode isolation
#
# Usage:   ./Scripts/ci/ci_validate.sh [--stress=N] [--skip-build]
#
# Options:
#   --stress=N     Number of round-trip stress cycles (default: 2)
#   --skip-build   Skip actual builds, only test mode switching
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
SKIP_BUILD=false
for arg in "$@"; do
    case "$arg" in
        --stress=*)
            STRESS_CYCLES="${arg#*=}"
            ;;
        --skip-build)
            SKIP_BUILD=true
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
        ((FAILURES++)) || true
        return 1
    fi
}

# ============================================================================
# Package.swift State Validation Functions
# ============================================================================

validate_pods_mode_state() {
    log_step "Validating Pods mode state..."
    local errors=0
    
    # Package.swift must NOT exist
    if [[ -f "$ROOT_DIR/Package.swift" ]]; then
        log_error "❌ ERROR: Package.swift should NOT exist in Pods mode"
        log_error "   This causes Xcode to auto-detect SPM packages"
        ((errors++)) || true
    else
        log_success "✓ Package.swift correctly absent"
    fi
    
    # Package.swift.disabled must exist
    if [[ ! -f "$ROOT_DIR/Package.swift.disabled" ]]; then
        log_error "❌ ERROR: Package.swift.disabled missing in Pods mode"
        ((errors++)) || true
    else
        log_success "✓ Package.swift.disabled present"
    fi
    
    # Pods directory must exist
    if [[ ! -d "$ROOT_DIR/Pods" ]]; then
        log_error "❌ ERROR: Pods/ directory missing"
        ((errors++)) || true
    else
        log_success "✓ Pods/ directory present"
    fi
    
    # project.yml must have packages: {}
    if [[ -f "$ROOT_DIR/Examples/MSPDemoApp/project.yml" ]]; then
        if ! grep -q "^packages: {}$" "$ROOT_DIR/Examples/MSPDemoApp/project.yml" 2>/dev/null; then
            if grep -q "msp-ios-sdk" "$ROOT_DIR/Examples/MSPDemoApp/project.yml" 2>/dev/null; then
                log_error "❌ ERROR: project.yml contains SPM package references"
                ((errors++)) || true
            fi
        else
            log_success "✓ project.yml has empty packages block"
        fi
    fi
    
    # workspace must only contain MSPDemoApp + Pods
    if [[ -f "$ROOT_DIR/msp-ios-sdk.xcworkspace/contents.xcworkspacedata" ]]; then
        local project_count
        project_count=$(grep -c "FileRef" "$ROOT_DIR/msp-ios-sdk.xcworkspace/contents.xcworkspacedata" 2>/dev/null || echo "0")
        if [[ "$project_count" -gt 3 ]]; then
            log_warn "⚠️ WARNING: workspace contains $project_count projects (expected 2)"
        else
            log_success "✓ workspace contains correct number of projects"
        fi
    fi
    
    return $errors
}

validate_spm_mode_state() {
    log_step "Validating SPM mode state..."
    local errors=0
    
    # Package.swift must exist
    if [[ ! -f "$ROOT_DIR/Package.swift" ]]; then
        log_error "❌ ERROR: Package.swift missing in SPM mode"
        ((errors++)) || true
    else
        log_success "✓ Package.swift present"
    fi
    
    # Package.swift.disabled must NOT exist
    if [[ -f "$ROOT_DIR/Package.swift.disabled" ]]; then
        log_error "❌ ERROR: Package.swift.disabled should NOT exist in SPM mode"
        ((errors++)) || true
    else
        log_success "✓ Package.swift.disabled correctly absent"
    fi
    
    # Pods directory must NOT exist
    if [[ -d "$ROOT_DIR/Pods" ]]; then
        log_error "❌ ERROR: Pods/ directory exists in SPM mode"
        ((errors++)) || true
    else
        log_success "✓ Pods/ directory absent"
    fi
    
    # project.yml must have SPM target
    if [[ -f "$ROOT_DIR/Examples/MSPDemoApp/project.yml" ]]; then
        if ! grep -q "MSPDemoApp-SPM:" "$ROOT_DIR/Examples/MSPDemoApp/project.yml" 2>/dev/null; then
            log_error "❌ ERROR: project.yml missing MSPDemoApp-SPM target"
            ((errors++)) || true
        else
            log_success "✓ project.yml has MSPDemoApp-SPM target"
        fi
    fi
    
    return $errors
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
# Step 2: Sync from Pods (prepare for both modes)
# ============================================================================
log_title "Step 2: CocoaPods Installation & Sync"

# First, ensure Package.swift exists (restore if disabled)
if [[ -f "$ROOT_DIR/Package.swift.disabled" ]] && [[ ! -f "$ROOT_DIR/Package.swift" ]]; then
    log_step "Restoring Package.swift for initial sync..."
    mv "$ROOT_DIR/Package.swift.disabled" "$ROOT_DIR/Package.swift"
fi

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
        ((FAILURES++)) || true
    }
else
    log_warn "switch-target.sh not found"
fi

# Validate Pods mode state
log_title "Step 4.1: Pods Mode State Validation"
if ! validate_pods_mode_state; then
    log_error "Pods mode state validation FAILED"
    ((FAILURES++)) || true
fi

if [[ "$SKIP_BUILD" == "false" ]]; then
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
        ((FAILURES++)) || true
    fi
else
    log_warn "Skipping build (--skip-build)"
fi

# ============================================================================
# Step 5: Build SPM Mode
# ============================================================================
log_title "Step 5: Swift Package Manager Build"

log_step "Switching to SPM mode..."
if [[ -x "$ROOT_DIR/Scripts/target-switching/switch-target.sh" ]]; then
    "$ROOT_DIR/Scripts/target-switching/switch-target.sh" spm || {
        log_error "switch-target.sh spm failed"
        ((FAILURES++)) || true
    }
else
    log_warn "switch-target.sh not found"
fi

# Validate SPM mode state
log_title "Step 5.1: SPM Mode State Validation"
if ! validate_spm_mode_state; then
    log_error "SPM mode state validation FAILED"
    ((FAILURES++)) || true
fi

if [[ "$SKIP_BUILD" == "false" ]]; then
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
        ((FAILURES++)) || true
    fi
else
    log_warn "Skipping build (--skip-build)"
fi

# ============================================================================
# Step 6: Round-Trip Stress Test
# ============================================================================
log_title "Step 6: Round-Trip Stress Test ($STRESS_CYCLES cycles)"

if [[ -x "$ROOT_DIR/Scripts/target-switching/round-trip-test.sh" ]]; then
    log_step "Running round-trip stress test with $STRESS_CYCLES cycles..."
    ROUND_TRIP_ARGS="--stress=$STRESS_CYCLES"
    if [[ "$SKIP_BUILD" == "true" ]]; then
        ROUND_TRIP_ARGS="$ROUND_TRIP_ARGS --skip-build"
    fi
    if "$ROOT_DIR/Scripts/target-switching/round-trip-test.sh" $ROUND_TRIP_ARGS; then
        log_success "Round-trip stress test PASSED"
    else
        log_error "Round-trip stress test FAILED"
        ((FAILURES++)) || true
    fi
else
    log_warn "round-trip-test.sh not found - skipping stress test"
fi

# ============================================================================
# Step 7: Final State Validation (end in Pods mode)
# ============================================================================
log_title "Step 7: Final State Validation"

log_step "Switching back to Pods mode..."
if [[ -x "$ROOT_DIR/Scripts/target-switching/switch-target.sh" ]]; then
    "$ROOT_DIR/Scripts/target-switching/switch-target.sh" pods || {
        log_error "Final switch-target.sh pods failed"
        ((FAILURES++)) || true
    }
fi

log_step "Final Pods mode state validation..."
if ! validate_pods_mode_state; then
    log_error "Final Pods mode state validation FAILED"
    ((FAILURES++)) || true
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
    echo "  ✓ Pods mode state validation"
    if [[ "$SKIP_BUILD" == "false" ]]; then
        echo "  ✓ Pods build"
    else
        echo "  - Pods build (skipped)"
    fi
    echo "  ✓ SPM mode state validation"
    if [[ "$SKIP_BUILD" == "false" ]]; then
        echo "  ✓ SPM build"
    else
        echo "  - SPM build (skipped)"
    fi
    echo "  ✓ Round-trip stress test ($STRESS_CYCLES cycles)"
    echo "  ✓ Final state validation"
    echo ""
    echo "============================================================"
    exit 0
else
    log_error "VALIDATION FAILED with $FAILURES error(s)"
    echo ""
    echo "  Check the output above for details."
    echo ""
    echo "  Common fixes:"
    echo "  - If Package.swift state is wrong: The switching script should auto-fix"
    echo "  - If SPM targets appear in Pods: Check generate_workspace.sh"
    echo "  - If build fails: Check that all XCFrameworks exist"
    echo ""
    echo "============================================================"
    exit 1
fi
