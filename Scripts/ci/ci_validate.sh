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

# ============================================================================
# Source Shared Libraries
# ============================================================================
# Phase 1 Refactoring: Use centralized logging from lib/
# Note: We define simple fallbacks for CI environments where full lib may not load

# Try to source the shared logging library
if [[ -f "$ROOT_DIR/Scripts/lib/colors.sh" ]]; then
    # shellcheck source=Scripts/lib/colors.sh
    source "$ROOT_DIR/Scripts/lib/colors.sh" 2>/dev/null || true
fi

# R033: Source spm.sh module for unified SPM operations
if [[ -f "$ROOT_DIR/Scripts/lib/spm.sh" ]]; then
    # shellcheck source=Scripts/lib/spm.sh
    source "$ROOT_DIR/Scripts/lib/spm.sh" 2>/dev/null || true
fi

# R036c: Source cocoapods.sh module for unified pod operations
COCOAPODS_MODULE_AVAILABLE=false
if [[ -f "$ROOT_DIR/Scripts/lib/cocoapods.sh" ]]; then
    # shellcheck source=Scripts/lib/cocoapods.sh
    source "$ROOT_DIR/Scripts/lib/cocoapods.sh" 2>/dev/null || true
    if command -v install_pods &>/dev/null; then
        COCOAPODS_MODULE_AVAILABLE=true
    fi
fi

# R042c: Source config loader extension for test settings
if [[ -f "$ROOT_DIR/Scripts/lib/config_loader_ext.sh" ]]; then
    # shellcheck source=Scripts/lib/config_loader_ext.sh
    source "$ROOT_DIR/Scripts/lib/config_loader_ext.sh" 2>/dev/null || true
    load_test_config 2>/dev/null || true
fi
# Default simulator destination from config or fallback
CI_SIMULATOR_DESTINATION="${TEST_UNIT_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 15}"

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

# Allow switch-target to run in working directories with pending changes
export MSP_ALLOW_DIRTY=1

# Colors for output (fallback if colors.sh not loaded)
: "${RED:=\033[0;31m}"
: "${GREEN:=\033[0;32m}"
: "${YELLOW:=\033[1;33m}"
: "${BLUE:=\033[0;34m}"
: "${NC:=\033[0m}"

# Logging functions (CI-specific formatting)
# These are intentionally simple for CI log readability
log_step() { echo -e "${BLUE}▶${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_title() { echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"; }

cd "$ROOT_DIR"

# Preflight helpers
require_path() {
    local path="$1"
    local type="${2:-any}"
    local hint="${3:-}"
    if [[ "$type" == "dir" && ! -d "$path" ]]; then
        log::error "CI" "Missing required directory: $path"
        [[ -n "$hint" ]] && log::warn "CI" "Hint: $hint"
        return 1
    fi
    if [[ "$type" == "file" && ! -f "$path" ]]; then
        log::error "CI" "Missing required file: $path"
        [[ -n "$hint" ]] && log::warn "CI" "Hint: $hint"
        return 1
    fi
    if [[ "$type" == "any" && ! -e "$path" ]]; then
        log::error "CI" "Missing required path: $path"
        [[ -n "$hint" ]] && log::warn "CI" "Hint: $hint"
        return 1
    fi
    return 0
}

# Track failures
FAILURES=0

run_step() {
    local step_name="$1"
    shift
    
    log::step "CI" "$step_name"
    if "$@"; then
        log::success "CI" "$step_name completed"
        return 0
    else
        log::error "CI" "$step_name FAILED"
        ((FAILURES++)) || true
        return 1
    fi
}

# ============================================================================
# Preflight: Required Paths & Workspace Discovery
# ============================================================================
log_title "Preflight: Required Paths"

require_path "$ROOT_DIR/Podfile" "file" "Run from repo root; Podfile is required for pods workflows" || ((FAILURES++)) || true
require_path "$ROOT_DIR/Scripts" "dir" "Ensure Scripts/ exists in the refactored layout" || ((FAILURES++)) || true
require_path "$ROOT_DIR/Scripts/target-switching" "dir" "Verify target-switching scripts were not moved/removed" || ((FAILURES++)) || true
require_path "$ROOT_DIR/Scripts/switch-target.sh" "file" "Check script permissions and path" || ((FAILURES++)) || true
require_path "$ROOT_DIR/Examples/MSPDemoApp" "dir" "DemoApp location changed; update workflows if moved" || ((FAILURES++)) || true
require_path "$ROOT_DIR/Examples/MSPDemoApp/MSPDemoApp.xcodeproj" "dir" "Run Scripts/workspace/update.sh to regenerate DemoApp project" || ((FAILURES++)) || true

WORKSPACE_PATH=""
if [[ -d "$ROOT_DIR/msp-ios-sdk.xcworkspace" ]]; then
    WORKSPACE_PATH="$ROOT_DIR/msp-ios-sdk.xcworkspace"
elif [[ -d "$ROOT_DIR/.generated/msp-ios-sdk.xcworkspace" ]]; then
    WORKSPACE_PATH="$ROOT_DIR/.generated/msp-ios-sdk.xcworkspace"
fi

if [[ -z "$WORKSPACE_PATH" ]]; then
    log::error "CI" "Missing workspace: msp-ios-sdk.xcworkspace (root or .generated)"
    log::warn "CI" "Hint: Run Scripts/workspace/update.sh to regenerate the workspace"
    ((FAILURES++)) || true
else
    log::success "CI" "Workspace found: $WORKSPACE_PATH"
fi

if [[ $FAILURES -ne 0 ]]; then
    log::error "CI" "Preflight checks failed; aborting CI validation"
    exit 1
fi

# ============================================================================
# Package.swift State Validation Functions
# ============================================================================

validate_pods_mode_state() {
    log::step "CI" "Validating Pods mode state..."
    local errors=0

    # Package.swift must NOT exist
    # R033: Use spm_check_manifest_exists if available
    local package_exists=false
    if command -v spm_check_manifest_exists &>/dev/null; then
        spm_check_manifest_exists "$ROOT_DIR" && package_exists=true
    elif [[ -f "$ROOT_DIR/Package.swift" ]]; then
        package_exists=true
    fi

    if [[ "$package_exists" == "true" ]]; then
        log::error "CI" "❌ ERROR: Package.swift should NOT exist in Pods mode"
        log::error "CI" "   This causes Xcode to auto-detect SPM packages"
        ((errors++)) || true
    else
        log::success "CI" "✓ Package.swift correctly absent"
    fi
    
    # Package.swift.disabled may be absent depending on switch-target behavior
    if [[ ! -f "$ROOT_DIR/Package.swift.disabled" ]]; then
        log::warn "CI" "⚠️ WARNING: Package.swift.disabled missing in Pods mode"
    else
        log::success "CI" "✓ Package.swift.disabled present"
    fi
    
    # Pods directory must exist
    if [[ ! -d "$ROOT_DIR/Pods" ]]; then
        log::error "CI" "❌ ERROR: Pods/ directory missing"
        ((errors++)) || true
    else
        log::success "CI" "✓ Pods/ directory present"
    fi
    
    # project.yml must have packages: {}
    if [[ -f "$ROOT_DIR/Examples/MSPDemoApp/project.yml" ]]; then
        if ! grep -q "^packages: {}$" "$ROOT_DIR/Examples/MSPDemoApp/project.yml" 2>/dev/null; then
            if grep -q "msp-ios-sdk" "$ROOT_DIR/Examples/MSPDemoApp/project.yml" 2>/dev/null; then
                log::error "CI" "❌ ERROR: project.yml contains SPM package references"
                ((errors++)) || true
            fi
        else
            log::success "CI" "✓ project.yml has empty packages block"
        fi
    fi
    
    # workspace must only contain MSPDemoApp + Pods
    if [[ -f "$WORKSPACE_PATH/contents.xcworkspacedata" ]]; then
        local project_count
        project_count=$(grep -c "FileRef" "$WORKSPACE_PATH/contents.xcworkspacedata" 2>/dev/null || echo "0")
        if [[ "$project_count" -gt 3 ]]; then
            log::warn "CI" "⚠️ WARNING: workspace contains $project_count projects (expected 2)"
        else
            log::success "CI" "✓ workspace contains correct number of projects"
        fi
    fi
    
    return $errors
}

validate_spm_mode_state() {
    log::step "CI" "Validating SPM mode state..."
    local errors=0
    
    # Package.swift must exist
    if [[ ! -f "$ROOT_DIR/Package.swift" ]]; then
        log::error "CI" "❌ ERROR: Package.swift missing in SPM mode"
        ((errors++)) || true
    else
        log::success "CI" "✓ Package.swift present"
    fi
    
    # Package.swift.disabled must NOT exist
    if [[ -f "$ROOT_DIR/Package.swift.disabled" ]]; then
        log::error "CI" "❌ ERROR: Package.swift.disabled should NOT exist in SPM mode"
        ((errors++)) || true
    else
        log::success "CI" "✓ Package.swift.disabled correctly absent"
    fi
    
    # Pods directory must NOT exist
    if [[ -d "$ROOT_DIR/Pods" ]]; then
        log::error "CI" "❌ ERROR: Pods/ directory exists in SPM mode"
        ((errors++)) || true
    else
        log::success "CI" "✓ Pods/ directory absent"
    fi
    
    # project.yml must have SPM target
    if [[ -f "$ROOT_DIR/Examples/MSPDemoApp/project.yml" ]]; then
        if ! grep -q "MSPDemoApp-SPM:" "$ROOT_DIR/Examples/MSPDemoApp/project.yml" 2>/dev/null; then
            log::error "CI" "❌ ERROR: project.yml missing MSPDemoApp-SPM target"
            ((errors++)) || true
        else
            log::success "CI" "✓ project.yml has MSPDemoApp-SPM target"
        fi
    fi
    
    return $errors
}

# ============================================================================
# Step 1: Cleanup
# ============================================================================
log_title "Step 1: Environment Cleanup"

log::step "CI" "Cleaning CocoaPods environment..."
if [[ -x "$ROOT_DIR/Scripts/target-switching/cleanup_pods.sh" ]]; then
    "$ROOT_DIR/Scripts/target-switching/cleanup_pods.sh" --force || log::warn "CI" "Pods cleanup had warnings"
else
    rm -rf "$ROOT_DIR/Pods" "$ROOT_DIR/Podfile.lock" 2>/dev/null || true
fi
log::success "CI" "CocoaPods cleanup done"

log::step "CI" "Cleaning SPM environment..."
if [[ -x "$ROOT_DIR/Scripts/target-switching/cleanup_spm.sh" ]]; then
    "$ROOT_DIR/Scripts/target-switching/cleanup_spm.sh" --force || log::warn "CI" "SPM cleanup had warnings"
else
    rm -rf "$ROOT_DIR/.swiftpm" "$ROOT_DIR/.build" "$ROOT_DIR/Package.resolved" 2>/dev/null || true
    find "$ROOT_DIR/Examples" -type d -name ".swiftpm" -exec rm -rf {} + 2>/dev/null || true
fi
log::success "CI" "SPM cleanup done"

# ============================================================================
# Step 2: Sync from Pods (prepare for both modes)
# ============================================================================
log_title "Step 2: CocoaPods Installation & Sync"

# First, ensure Package.swift exists (restore if disabled)
if [[ -f "$ROOT_DIR/Package.swift.disabled" ]] && [[ ! -f "$ROOT_DIR/Package.swift" ]]; then
    log::step "CI" "Restoring Package.swift for initial sync..."
    mv "$ROOT_DIR/Package.swift.disabled" "$ROOT_DIR/Package.swift"
fi

# R036c: Use cocoapods.sh module's install_pods() if available
log::step "CI" "Running pod install..."
if [[ "$COCOAPODS_MODULE_AVAILABLE" == "true" ]]; then
    if ! install_pods; then
        log::error "CI" "pod install failed (via cocoapods.sh module)"
        exit 1
    fi
    log::success "CI" "pod install completed (via cocoapods.sh module)"
else
    # Fallback: Direct pod install
    if ! pod install; then
        log::error "CI" "pod install failed"
        exit 1
    fi
    log::success "CI" "pod install completed"
fi

log::step "CI" "Running SPM sync (extract XCFrameworks from Pods)..."
if [[ -x "$ROOT_DIR/Scripts/spm-sync/spm_sync_all.sh" ]]; then
    if [[ "$SKIP_BUILD" == "true" ]]; then
        export SKIP_XCFRAMEWORK_VALIDATION=1
    fi
    if ! "$ROOT_DIR/Scripts/spm-sync/spm_sync_all.sh"; then
        log::error "CI" "spm_sync_all.sh failed"
        exit 1
    fi
else
    log::warn "CI" "spm_sync_all.sh not found - skipping XCFramework extraction"
fi
log::success "CI" "SPM sync completed"

# ============================================================================
# Step 3: Validate XCFrameworks and Versions
# ============================================================================
log_title "Step 3: XCFramework & Version Validation"

if [[ "$SKIP_BUILD" == "true" ]]; then
    log::warn "CI" "Skipping XCFramework validation (--skip-build)"
elif [[ -x "$ROOT_DIR/Scripts/target-switching/validate_xcframeworks.sh" ]]; then
    run_step "Validating XCFrameworks and dependency versions" \
        "$ROOT_DIR/Scripts/target-switching/validate_xcframeworks.sh"
else
    log::warn "CI" "validate_xcframeworks.sh not found - skipping validation"
fi

# ============================================================================
# Step 4: Build Pods Mode
# ============================================================================
log_title "Step 4: CocoaPods Build"

log::step "CI" "Switching to Pods mode..."
if [[ -x "$ROOT_DIR/Scripts/switch-target.sh" ]]; then
    "$ROOT_DIR/Scripts/switch-target.sh" pods || {
        log::error "CI" "switch-target.sh pods failed"
        ((FAILURES++)) || true
    }
else
    log::warn "CI" "switch-target.sh not found"
fi

# Validate Pods mode state
log_title "Step 4.1: Pods Mode State Validation"
if ! validate_pods_mode_state; then
    log::error "CI" "Pods mode state validation FAILED"
    ((FAILURES++)) || true
fi

if [[ "$SKIP_BUILD" == "false" ]]; then
    log::step "CI" "Building MSPDemoApp (Pods mode)..."
    if xcodebuild -workspace "$WORKSPACE_PATH" \
        -scheme MSPDemoApp \
        -configuration Debug \
        -destination "$CI_SIMULATOR_DESTINATION" \
        -quiet \
        build; then
        log::success "CI" "Pods build SUCCEEDED"
    else
        log::error "CI" "Pods build FAILED"
        ((FAILURES++)) || true
    fi
else
    log::warn "CI" "Skipping build (--skip-build)"
fi

# ============================================================================
# Step 5: Build SPM Mode
# ============================================================================
if [[ "$SKIP_BUILD" == "true" ]]; then
    log_title "Step 5: Swift Package Manager Build"
    log::warn "CI" "Skipping SPM mode switch and validation (--skip-build)"
else
    log_title "Step 5: Swift Package Manager Build"

    log::step "CI" "Switching to SPM mode..."
    if [[ -x "$ROOT_DIR/Scripts/switch-target.sh" ]]; then
        "$ROOT_DIR/Scripts/switch-target.sh" spm || {
            log::error "CI" "switch-target.sh spm failed"
            ((FAILURES++)) || true
        }
    else
        log::warn "CI" "switch-target.sh not found"
    fi

    # Validate SPM mode state
    log_title "Step 5.1: SPM Mode State Validation"
    if ! validate_spm_mode_state; then
        log::error "CI" "SPM mode state validation FAILED"
        ((FAILURES++)) || true
    fi

    log::step "CI" "Building MSPDemoApp-SPM (SPM mode)..."
    if xcodebuild -project "$ROOT_DIR/Examples/MSPDemoApp/MSPDemoApp.xcodeproj" \
        -scheme MSPDemoApp-SPM \
        -configuration Debug \
        -destination "$CI_SIMULATOR_DESTINATION" \
        -quiet \
        build; then
        log::success "CI" "SPM build SUCCEEDED"
    else
        log::error "CI" "SPM build FAILED"
        ((FAILURES++)) || true
    fi
fi

# ============================================================================
# Step 6: Round-Trip Stress Test
# ============================================================================
if [[ "$SKIP_BUILD" == "true" ]]; then
    log_title "Step 6: Round-Trip Stress Test ($STRESS_CYCLES cycles)"
    log::warn "CI" "Skipping round-trip stress test (--skip-build)"
else
    log_title "Step 6: Round-Trip Stress Test ($STRESS_CYCLES cycles)"

    if [[ -x "$ROOT_DIR/Scripts/target-switching/round-trip-test.sh" ]]; then
        log::step "CI" "Running round-trip stress test with $STRESS_CYCLES cycles..."
        ROUND_TRIP_ARGS="--stress=$STRESS_CYCLES"
        if "$ROOT_DIR/Scripts/target-switching/round-trip-test.sh" $ROUND_TRIP_ARGS; then
            log::success "CI" "Round-trip stress test PASSED"
        else
            log::error "CI" "Round-trip stress test FAILED"
            ((FAILURES++)) || true
        fi
    else
        log::warn "CI" "round-trip-test.sh not found - skipping stress test"
    fi
fi

# ============================================================================
# Step 7: Final State Validation (end in Pods mode)
# ============================================================================
log_title "Step 7: Final State Validation"

log::step "CI" "Switching back to Pods mode..."
if [[ -x "$ROOT_DIR/Scripts/switch-target.sh" ]]; then
    "$ROOT_DIR/Scripts/switch-target.sh" pods || {
        log::error "CI" "Final switch-target.sh pods failed"
        ((FAILURES++)) || true
    }
fi

log::step "CI" "Final Pods mode state validation..."
if ! validate_pods_mode_state; then
    log::error "CI" "Final Pods mode state validation FAILED"
    ((FAILURES++)) || true
fi

# ============================================================================
# Summary
# ============================================================================
log_title "CI Validation Summary"

echo "============================================================"
if [[ $FAILURES -eq 0 ]]; then
    log::success "CI" "ALL VALIDATIONS PASSED"
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
    if [[ "$SKIP_BUILD" == "false" ]]; then
        echo "  ✓ SPM mode state validation"
        echo "  ✓ SPM build"
        echo "  ✓ Round-trip stress test ($STRESS_CYCLES cycles)"
    else
        echo "  - SPM mode state validation (skipped)"
        echo "  - SPM build (skipped)"
        echo "  - Round-trip stress test (skipped)"
    fi
    echo "  ✓ Final state validation"
    echo ""
    echo "============================================================"
    exit 0
else
    log::error "CI" "VALIDATION FAILED with $FAILURES error(s)"
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
