#!/usr/bin/env bash
# ============================================================================
# CI Full Pipeline Script
# ============================================================================
# Purpose: Complete build + test pipeline for self-hosted CI runner
# Usage:   bash Scripts/ci/ci-pipeline.sh
#
# Pipeline steps:
#   1. Environment validation (Xcode, Ruby, CocoaPods, XcodeGen)
#   2. Workspace generation + Pod install
#   3. Pre-build Pod dependencies (for Core module builds)
#   4. Build all XCFrameworks (from release.yaml SSOT)
#   5. Build DemoApp
#   6. Pods/SPM consistency check
#   7. Swift unit tests + coverage
#   8. Summary
#
# Exit codes:
#   0 - All steps passed
#   1 - One or more critical steps failed
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source step lifecycle for structured logging
if [[ -f "$ROOT_DIR/Scripts/lib/shared/step_lifecycle.sh" ]]; then
    # shellcheck source=Scripts/lib/shared/step_lifecycle.sh
    source "$ROOT_DIR/Scripts/lib/shared/step_lifecycle.sh"
fi

# Source config loader for test settings
if [[ -f "$ROOT_DIR/Scripts/lib/config_loader_ext.sh" ]]; then
    # shellcheck source=Scripts/lib/config_loader_ext.sh
    source "$ROOT_DIR/Scripts/lib/config_loader_ext.sh" 2>/dev/null || true
    load_test_config 2>/dev/null || true
fi

cd "$ROOT_DIR"

# ============================================================================
# State Tracking
# ============================================================================

CRITICAL_FAILURES=0
NON_CRITICAL_FAILURES=0
STEP_RESULTS=()
TOTAL_START=$SECONDS

run_critical_step() {
    local step_name="$1"
    shift
    local start=$SECONDS

    step "$step_name"
    if "$@"; then
        step_done "$step_name"
        local elapsed=$(( SECONDS - start ))
        STEP_RESULTS+=("PASS  ${elapsed}s  $step_name")
        return 0
    else
        local code=$?
        step_fail "$step_name" "$code"
        local elapsed=$(( SECONDS - start ))
        STEP_RESULTS+=("FAIL  ${elapsed}s  $step_name")
        (( CRITICAL_FAILURES++ )) || true
        return 1
    fi
}

run_optional_step() {
    local step_name="$1"
    shift
    local start=$SECONDS

    step "$step_name"
    if "$@"; then
        step_done "$step_name"
        local elapsed=$(( SECONDS - start ))
        STEP_RESULTS+=("PASS  ${elapsed}s  $step_name")
        return 0
    else
        local code=$?
        step_fail "$step_name" "$code"
        local elapsed=$(( SECONDS - start ))
        STEP_RESULTS+=("WARN  ${elapsed}s  $step_name (non-critical)")
        (( NON_CRITICAL_FAILURES++ )) || true
        return 1
    fi
}

# ============================================================================
# Step 1: Environment Validation
# ============================================================================

validate_environment() {
    local fail=0
    echo "[env] Checking build environment..."

    # Xcode
    if command -v xcodebuild &>/dev/null; then
        local xcode_version
        xcode_version=$(xcodebuild -version | head -1)
        echo "[env] Xcode: $xcode_version"
    else
        echo "[env] ERROR: xcodebuild not found" >&2
        fail=1
    fi

    # Ruby
    if command -v ruby &>/dev/null; then
        echo "[env] Ruby: $(ruby --version)"
    else
        echo "[env] ERROR: ruby not found" >&2
        fail=1
    fi

    # CocoaPods
    if command -v pod &>/dev/null; then
        echo "[env] CocoaPods: $(pod --version)"
    elif [[ -f "Gemfile" ]] && command -v bundle &>/dev/null; then
        echo "[env] CocoaPods: $(bundle exec pod --version) (via Bundler)"
    else
        echo "[env] ERROR: CocoaPods not found" >&2
        fail=1
    fi

    # XcodeGen (install if missing)
    if ! command -v xcodegen &>/dev/null; then
        echo "[env] XcodeGen not found, attempting install..."
        if [[ -x "$ROOT_DIR/Scripts/ci/ensure-xcodegen.sh" ]]; then
            bash "$ROOT_DIR/Scripts/ci/ensure-xcodegen.sh"
        else
            echo "[env] ERROR: XcodeGen not found and ensure-xcodegen.sh missing" >&2
            fail=1
        fi
    else
        echo "[env] XcodeGen: $(xcodegen --version 2>/dev/null || echo 'installed')"
    fi

    # Python 3
    if command -v python3 &>/dev/null; then
        echo "[env] Python: $(python3 --version)"
    else
        echo "[env] WARNING: python3 not found (some validations may be skipped)"
    fi

    # jq
    if command -v jq &>/dev/null; then
        echo "[env] jq: $(jq --version)"
    else
        echo "[env] WARNING: jq not found (some features may be limited)"
    fi

    # Verify release.yaml (SSOT for module list)
    if [[ ! -f "$ROOT_DIR/Scripts/config/release.yaml" ]]; then
        echo "[env] ERROR: Scripts/config/release.yaml not found" >&2
        fail=1
    fi

    return $fail
}

# ============================================================================
# Step 2: Generate Workspace + Install Pods
# ============================================================================

generate_workspace_and_pods() {
    echo "[workspace] Generating workspace and installing Pods..."

    # Switch to pods-dev mode
    if [[ -x "$ROOT_DIR/Scripts/switch-target.sh" ]]; then
        echo "[workspace] Switching to pods-dev mode..."
        "$ROOT_DIR/Scripts/switch-target.sh" pods-dev
    fi

    # Generate workspace
    if [[ -x "$ROOT_DIR/Scripts/ci/generate-workspace.sh" ]]; then
        bash "$ROOT_DIR/Scripts/ci/generate-workspace.sh"
    else
        echo "[workspace] ERROR: generate-workspace.sh not found" >&2
        return 1
    fi

    # Install Pods
    if [[ -x "$ROOT_DIR/Scripts/ci/install-pods.sh" ]]; then
        bash "$ROOT_DIR/Scripts/ci/install-pods.sh"
    else
        echo "[workspace] ERROR: install-pods.sh not found" >&2
        return 1
    fi

    echo "[workspace] Workspace and Pods ready"
}

# ============================================================================
# Step 3: Pre-build Pod Dependencies
# ============================================================================

prebuild_pod_deps() {
    if [[ -x "$ROOT_DIR/Scripts/ci/prebuild-pod-deps.sh" ]]; then
        echo "[prebuild] Pre-building Pod dependencies for Core modules..."
        bash "$ROOT_DIR/Scripts/ci/prebuild-pod-deps.sh"
    else
        echo "[prebuild] prebuild-pod-deps.sh not found, skipping"
    fi
}

# ============================================================================
# Step 4: Build All XCFrameworks
# ============================================================================

build_all_xcframeworks() {
    echo "[build] Reading module list from release.yaml (SSOT)..."

    # Read modules from release.yaml (Article I.3: SSOT)
    local modules
    modules=$(ruby -e "
        require 'yaml'
        config = YAML.load_file('Scripts/config/release.yaml')
        modules = config.dig('pods', 'modules') || []
        puts modules.join(' ')
    ")

    if [[ -z "$modules" ]]; then
        echo "[build] ERROR: No modules found in release.yaml" >&2
        return 1
    fi

    echo "[build] Modules to build: $modules"
    local module_count=0
    local module_total
    # shellcheck disable=SC2086
    module_total=$(echo $modules | wc -w | tr -d ' ')

    # shellcheck disable=SC2086
    for module in $modules; do
        (( module_count++ )) || true
        echo ""
        echo "========================================"
        echo "  Building [$module_count/$module_total]: $module"
        echo "========================================"

        # Build the module
        if ! bash "$ROOT_DIR/Scripts/xcframeworks/build_module.sh" "$module"; then
            echo "[build] CRITICAL: Failed to build $module" >&2
            return 1
        fi

        # Verify the built XCFramework
        if [[ -x "$ROOT_DIR/Scripts/ci/verify-xcframework.sh" ]]; then
            if ! bash "$ROOT_DIR/Scripts/ci/verify-xcframework.sh" "$module"; then
                echo "[build] CRITICAL: Verification failed for $module" >&2
                return 1
            fi
        fi

        echo "[build] $module: OK"
    done

    echo ""
    echo "[build] All $module_total modules built and verified successfully"
}

# ============================================================================
# Step 5: Build DemoApp
# ============================================================================

build_demoapp() {
    echo "[demoapp] Building MSPDemoApp..."

    local destination="${TEST_UNIT_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 15}"

    # Find workspace
    local workspace=""
    if [[ -d "$ROOT_DIR/msp-ios-sdk.xcworkspace" ]]; then
        workspace="$ROOT_DIR/msp-ios-sdk.xcworkspace"
    elif [[ -d "$ROOT_DIR/.generated/msp-ios-sdk.xcworkspace" ]]; then
        workspace="$ROOT_DIR/.generated/msp-ios-sdk.xcworkspace"
    fi

    if [[ -z "$workspace" ]]; then
        echo "[demoapp] WARNING: No workspace found, skipping DemoApp build" >&2
        return 1
    fi

    xcodebuild \
        -workspace "$workspace" \
        -scheme MSPDemoApp \
        -configuration Debug \
        -destination "$destination" \
        -quiet \
        build

    echo "[demoapp] DemoApp build succeeded"
}

# ============================================================================
# Step 6: Pods/SPM Consistency Check
# ============================================================================

run_consistency_check() {
    echo "[consistency] Running Pods/SPM consistency check..."

    if [[ -x "$ROOT_DIR/Scripts/target-switching/round-trip-test.sh" ]]; then
        "$ROOT_DIR/Scripts/target-switching/round-trip-test.sh" --stress=1
    else
        echo "[consistency] round-trip-test.sh not found, skipping"
    fi
}

# ============================================================================
# Step 7: Swift Unit Tests
# ============================================================================

run_unit_tests() {
    echo "[test] Running Swift unit tests..."

    local destination="${TEST_UNIT_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 15}"

    # Find workspace
    local workspace=""
    if [[ -d "$ROOT_DIR/msp-ios-sdk.xcworkspace" ]]; then
        workspace="$ROOT_DIR/msp-ios-sdk.xcworkspace"
    elif [[ -d "$ROOT_DIR/.generated/msp-ios-sdk.xcworkspace" ]]; then
        workspace="$ROOT_DIR/.generated/msp-ios-sdk.xcworkspace"
    fi

    if [[ -z "$workspace" ]]; then
        echo "[test] WARNING: No workspace found, skipping unit tests" >&2
        return 1
    fi

    # Clean previous results
    rm -rf "$ROOT_DIR/build/TestResults.xcresult"
    mkdir -p "$ROOT_DIR/build"

    xcodebuild \
        test \
        -workspace "$workspace" \
        -scheme MSPTests \
        -destination "$destination" \
        -resultBundlePath "$ROOT_DIR/build/TestResults.xcresult" \
        -enableCodeCoverage YES

    echo "[test] Unit tests passed"

    # Generate coverage report if xcrun xccov is available
    if [[ -d "$ROOT_DIR/build/TestResults.xcresult" ]]; then
        echo "[test] Generating coverage report..."
        if xcrun xccov view --report --json "$ROOT_DIR/build/TestResults.xcresult" \
            > "$ROOT_DIR/build/coverage.json" 2>/dev/null; then
            echo "[test] Coverage report generated: build/coverage.json"
        else
            echo "[test] WARNING: Failed to generate coverage report"
        fi
    fi
}

# ============================================================================
# Execute Pipeline
# ============================================================================

echo "========================================"
echo "  CI Full Pipeline"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
echo ""

# Critical steps — fail fast on these
run_critical_step "Environment validation"     validate_environment    || {
    echo ""
    echo "PIPELINE ABORTED: Environment validation failed"
    exit 1
}

run_critical_step "Workspace + Pod install"    generate_workspace_and_pods || {
    echo ""
    echo "PIPELINE ABORTED: Workspace generation failed"
    exit 1
}

run_critical_step "Pre-build Pod dependencies" prebuild_pod_deps || {
    echo ""
    echo "PIPELINE ABORTED: Pod dependency pre-build failed"
    exit 1
}

run_critical_step "Build all XCFrameworks"     build_all_xcframeworks || {
    echo ""
    echo "PIPELINE ABORTED: XCFramework build failed"
    exit 1
}

# Non-critical steps — collect errors but continue
run_optional_step "Build DemoApp"              build_demoapp           || true
run_optional_step "Consistency check"          run_consistency_check   || true
run_critical_step "Unit tests"                 run_unit_tests          || true

# ============================================================================
# Summary
# ============================================================================

TOTAL_ELAPSED=$(( SECONDS - TOTAL_START ))
echo ""
echo "========================================"
echo "  Pipeline Summary"
echo "========================================"
echo ""
printf "%-6s %-8s %s\n" "Result" "Time" "Step"
printf "%-6s %-8s %s\n" "------" "--------" "----"
for result in "${STEP_RESULTS[@]}"; do
    echo "$result"
done
echo ""
echo "Total time:          ${TOTAL_ELAPSED}s ($(( TOTAL_ELAPSED / 60 ))m $(( TOTAL_ELAPSED % 60 ))s)"
echo "Critical failures:   $CRITICAL_FAILURES"
echo "Non-critical issues: $NON_CRITICAL_FAILURES"
echo ""

# Write to GitHub Actions step summary if available
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
        echo "## CI Pipeline Results"
        echo ""
        echo "| Result | Time | Step |"
        echo "|--------|------|------|"
        for result in "${STEP_RESULTS[@]}"; do
            # Parse result line into table columns
            local_result="${result%%  *}"
            local_rest="${result#*  }"
            local_time="${local_rest%%  *}"
            local_name="${local_rest#*  }"
            case "$local_result" in
                PASS) echo "| :white_check_mark: | $local_time | $local_name |" ;;
                FAIL) echo "| :x: | $local_time | $local_name |" ;;
                WARN) echo "| :warning: | $local_time | $local_name |" ;;
                *)    echo "| $local_result | $local_time | $local_name |" ;;
            esac
        done
        echo ""
        echo "**Total time**: $(( TOTAL_ELAPSED / 60 ))m $(( TOTAL_ELAPSED % 60 ))s"
        echo "**Critical failures**: $CRITICAL_FAILURES | **Non-critical**: $NON_CRITICAL_FAILURES"
    } >> "$GITHUB_STEP_SUMMARY"
fi

if [[ $CRITICAL_FAILURES -ne 0 ]]; then
    echo "PIPELINE FAILED ($CRITICAL_FAILURES critical failures)"
    exit 1
fi

if [[ $NON_CRITICAL_FAILURES -ne 0 ]]; then
    echo "PIPELINE PASSED with $NON_CRITICAL_FAILURES non-critical issues"
    exit 0
fi

echo "PIPELINE PASSED - All steps successful"
exit 0
