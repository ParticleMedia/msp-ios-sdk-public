#!/usr/bin/env bash
# ============================================================================
# CI Quick Validation Script
# ============================================================================
# Purpose: Fast, non-build validation checks for PR feedback (~5 min)
# Usage:   bash Scripts/ci/ci-validate-quick.sh
#
# Checks performed:
#   1. Shell syntax validation (bash -n)
#   2. CI config YAML validation
#   3. Asset verification
#   4. Test case validation (YAML test cases)
#   5. Bash unit tests
#   6. Bash integration tests
#   7. Podspec lint
#   8. Swift package resolution (if Package.swift exists)
#
# Exit codes:
#   0 - All validations passed
#   1 - One or more validations failed
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source step lifecycle for structured logging
if [[ -f "$ROOT_DIR/Scripts/lib/shared/step_lifecycle.sh" ]]; then
    # shellcheck source=Scripts/lib/shared/step_lifecycle.sh
    source "$ROOT_DIR/Scripts/lib/shared/step_lifecycle.sh"
fi

cd "$ROOT_DIR"

# ============================================================================
# State Tracking
# ============================================================================

FAILURES=0
STEP_RESULTS=()
TOTAL_START=$SECONDS

run_step() {
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
        step_fail "$step_name" $?
        local elapsed=$(( SECONDS - start ))
        STEP_RESULTS+=("FAIL  ${elapsed}s  $step_name")
        (( FAILURES++ )) || true
        return 1
    fi
}

# ============================================================================
# Step 1: Shell Syntax Check
# ============================================================================

validate_shell_syntax() {
    if [[ -x "$ROOT_DIR/Scripts/ci/validate-shell-syntax.sh" ]]; then
        bash "$ROOT_DIR/Scripts/ci/validate-shell-syntax.sh" Scripts
    else
        echo "[validate] Inline shell syntax check..."
        local fail=0
        while IFS= read -r script; do
            if ! bash -n "$script"; then
                echo "Shell syntax error: $script" >&2
                fail=1
            fi
        done < <(find Scripts -name "*.sh" -type f)
        return "$fail"
    fi
}

# ============================================================================
# Step 2: CI Config YAML Validation
# ============================================================================

validate_ci_config() {
    local fail=0

    # Verify release.yaml exists and is parseable
    if [[ ! -f "$ROOT_DIR/Scripts/config/release.yaml" ]]; then
        echo "Missing: Scripts/config/release.yaml" >&2
        return 1
    fi

    # Use ruby to parse YAML (available on macOS)
    if ! ruby -e "require 'yaml'; YAML.load_file('Scripts/config/release.yaml')" 2>/dev/null; then
        echo "Invalid YAML: Scripts/config/release.yaml" >&2
        fail=1
    fi

    # Verify test-config.yaml
    if [[ -f "$ROOT_DIR/Scripts/config/test-config.yaml" ]]; then
        if ! ruby -e "require 'yaml'; YAML.load_file('Scripts/config/test-config.yaml')" 2>/dev/null; then
            echo "Invalid YAML: Scripts/config/test-config.yaml" >&2
            fail=1
        fi
    fi

    # Verify ci-framework-deps.yml
    if [[ -f "$ROOT_DIR/Scripts/config/ci-framework-deps.yml" ]]; then
        if ! ruby -e "require 'yaml'; YAML.load_file('Scripts/config/ci-framework-deps.yml')" 2>/dev/null; then
            echo "Invalid YAML: Scripts/config/ci-framework-deps.yml" >&2
            fail=1
        fi
    fi

    return "$fail"
}

# ============================================================================
# Step 3: Asset Verification
# ============================================================================

validate_assets() {
    if [[ -f "$ROOT_DIR/Scripts/lib/asset_validation.sh" ]]; then
        bash "$ROOT_DIR/Scripts/lib/asset_validation.sh"
    else
        echo "[validate] Asset validation script not available, skipping"
    fi
}

# ============================================================================
# Step 4: Test Case Validation
# ============================================================================

validate_test_cases() {
    if [[ -x "$ROOT_DIR/Scripts/tools/test-cases.py" ]]; then
        python3 "$ROOT_DIR/Scripts/tools/test-cases.py" validate
    else
        echo "[validate] test-cases.py not found, skipping"
    fi
}

# ============================================================================
# Step 5: Bash Unit Tests
# ============================================================================

run_bash_unit_tests() {
    if [[ -x "$ROOT_DIR/Scripts/tests/unit/run_all.sh" ]]; then
        bash "$ROOT_DIR/Scripts/tests/unit/run_all.sh"
    else
        echo "[validate] Bash unit test runner not found, skipping"
    fi
}

# ============================================================================
# Step 6: Bash Integration Tests
# ============================================================================

run_bash_integration_tests() {
    if [[ -x "$ROOT_DIR/Scripts/tests/release_state/run_all.sh" ]]; then
        bash "$ROOT_DIR/Scripts/tests/release_state/run_all.sh"
    else
        echo "[validate] Bash integration test runner not found, skipping"
    fi
}

# ============================================================================
# Step 7: Podspec Lint
# ============================================================================

run_podspec_lint() {
    if [[ -x "$ROOT_DIR/Scripts/ci/lint-podspecs.sh" ]]; then
        bash "$ROOT_DIR/Scripts/ci/lint-podspecs.sh" --allow-warnings
    else
        echo "[validate] lint-podspecs.sh not found, skipping"
    fi
}

# ============================================================================
# Step 8: Swift Package Resolution
# ============================================================================

resolve_swift_package() {
    if [[ -f "$ROOT_DIR/Package.swift" ]]; then
        swift package resolve
    else
        echo "[validate] No Package.swift found, skipping SPM resolve"
    fi
}

# ============================================================================
# Execute All Steps
# ============================================================================

echo "========================================"
echo "  CI Quick Validation"
echo "========================================"
echo ""

run_step "Shell syntax check"      validate_shell_syntax     || true
run_step "CI config validation"    validate_ci_config        || true
run_step "Asset verification"      validate_assets           || true
run_step "Test case validation"    validate_test_cases       || true
run_step "Bash unit tests"         run_bash_unit_tests       || true
run_step "Bash integration tests"  run_bash_integration_tests || true
run_step "Podspec lint"            run_podspec_lint           || true
run_step "Swift package resolve"   resolve_swift_package      || true

# ============================================================================
# Summary
# ============================================================================

TOTAL_ELAPSED=$(( SECONDS - TOTAL_START ))

echo ""
echo "========================================"
echo "  Validation Summary"
echo "========================================"
echo ""
printf "%-6s %-6s %s\n" "Result" "Time" "Step"
printf "%-6s %-6s %s\n" "------" "-----" "----"
for result in "${STEP_RESULTS[@]}"; do
    echo "$result"
done
echo ""
echo "Total time: ${TOTAL_ELAPSED}s"
echo "Failures:   $FAILURES"
echo ""

# Write to GitHub Actions step summary if available
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
        echo "## Quick Validation Results"
        echo ""
        echo "| Result | Time | Step |"
        echo "|--------|------|------|"
        for result in "${STEP_RESULTS[@]}"; do
            # Parse "PASS  5s  Step name" into table row
            local_result="${result%%  *}"
            local_rest="${result#*  }"
            local_time="${local_rest%%  *}"
            local_name="${local_rest#*  }"
            if [[ "$local_result" == "PASS" ]]; then
                echo "| :white_check_mark: | $local_time | $local_name |"
            else
                echo "| :x: | $local_time | $local_name |"
            fi
        done
        echo ""
        echo "**Total time**: ${TOTAL_ELAPSED}s | **Failures**: $FAILURES"
    } >> "$GITHUB_STEP_SUMMARY"
fi

if [[ $FAILURES -ne 0 ]]; then
    echo "VALIDATION FAILED ($FAILURES failures)"
    exit 1
fi

echo "ALL VALIDATIONS PASSED"
exit 0
