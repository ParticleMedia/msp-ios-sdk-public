#!/usr/bin/env bash
set -euo pipefail

# @description Unit tests for Scripts/utils/setup-release-env.sh
# @test Verifies all profiles, and confirms MSP_SLACK_ALERT_ENV is not exported

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

SETUP_ENV_SH="$REPO_ROOT/Scripts/utils/setup-release-env.sh"

# ============================================================================
# File existence and structure tests
# ============================================================================

test_file_exists() {
    assert_file_exists "$SETUP_ENV_SH" "setup-release-env.sh should exist"
}

test_prevents_direct_execution() {
    local found
    found=$(grep -c 'BASH_SOURCE\[0\].*==.*\${0}' "$SETUP_ENV_SH")
    assert_not_equals "0" "$found" "should prevent direct execution (must be sourced)"
}

# ============================================================================
# MSP_SLACK_ALERT_ENV removal verification
# ============================================================================

test_no_msp_slack_alert_env() {
    local found
    found=$(grep -c 'MSP_SLACK_ALERT_ENV' "$SETUP_ENV_SH" || true)
    assert_equals "0" "$found" "MSP_SLACK_ALERT_ENV should not appear in setup-release-env.sh"
}

test_no_msp_slack_test_webhook() {
    local found
    found=$(grep -c 'MSP_SLACK_TEST_WEBHOOK' "$SETUP_ENV_SH" || true)
    assert_equals "0" "$found" "MSP_SLACK_TEST_WEBHOOK should not appear in setup-release-env.sh"
}

# ============================================================================
# Profile function existence tests
# ============================================================================

test_local_profile_exists() {
    local found
    found=$(grep -c 'setup_local_profile()' "$SETUP_ENV_SH")
    assert_not_equals "0" "$found" "setup_local_profile function should exist"
}

test_ci_profile_exists() {
    local found
    found=$(grep -c 'setup_ci_profile()' "$SETUP_ENV_SH")
    assert_not_equals "0" "$found" "setup_ci_profile function should exist"
}

test_rerelease_profile_exists() {
    local found
    found=$(grep -c 'setup_rerelease_profile()' "$SETUP_ENV_SH")
    assert_not_equals "0" "$found" "setup_rerelease_profile function should exist"
}

test_test_profile_exists() {
    local found
    found=$(grep -c 'setup_test_profile()' "$SETUP_ENV_SH")
    assert_not_equals "0" "$found" "setup_test_profile function should exist"
}

test_resume_profile_exists() {
    local found
    found=$(grep -c 'setup_resume_profile()' "$SETUP_ENV_SH")
    assert_not_equals "0" "$found" "setup_resume_profile function should exist"
}

# ============================================================================
# Profile behavior tests (sourcing in subshell)
# ============================================================================

test_local_profile_exports() {
    # Source local profile in subshell and check exports
    local output
    output=$(bash -c '
        BASH_SOURCE_OVERRIDE=1
        # Override BASH_SOURCE[0] != $0 check by sourcing
        source "'"$SETUP_ENV_SH"'" local 2>/dev/null
        echo "DRY_RUN=$DRY_RUN"
        echo "MSP_ALLOW_LOCAL_RELEASE=$MSP_ALLOW_LOCAL_RELEASE"
        echo "MSP_ALLOW_TRUNK_PUSH=$MSP_ALLOW_TRUNK_PUSH"
    ' 2>/dev/null || true)

    assert_contains "$output" "DRY_RUN=false" "local profile should set DRY_RUN=false"
    assert_contains "$output" "MSP_ALLOW_LOCAL_RELEASE=1" "local profile should set MSP_ALLOW_LOCAL_RELEASE=1"
    assert_contains "$output" "MSP_ALLOW_TRUNK_PUSH=1" "local profile should set MSP_ALLOW_TRUNK_PUSH=1"
}

test_ci_profile_exports() {
    local output
    output=$(bash -c '
        source "'"$SETUP_ENV_SH"'" ci 2>/dev/null
        echo "DRY_RUN=$DRY_RUN"
        echo "MSP_ALLOW_TRUNK_PUSH=$MSP_ALLOW_TRUNK_PUSH"
    ' 2>/dev/null || true)

    assert_contains "$output" "DRY_RUN=false" "ci profile should set DRY_RUN=false"
    assert_contains "$output" "MSP_ALLOW_TRUNK_PUSH=1" "ci profile should set MSP_ALLOW_TRUNK_PUSH=1"
}

test_test_profile_exports() {
    local output
    output=$(bash -c '
        source "'"$SETUP_ENV_SH"'" test 2>/dev/null
        echo "DRY_RUN=$DRY_RUN"
        echo "MSP_ALLOW_TRUNK_PUSH=$MSP_ALLOW_TRUNK_PUSH"
    ' 2>/dev/null || true)

    assert_contains "$output" "DRY_RUN=true" "test profile should set DRY_RUN=true"
    assert_contains "$output" "MSP_ALLOW_TRUNK_PUSH=0" "test profile should set MSP_ALLOW_TRUNK_PUSH=0"
}

test_no_slack_env_in_any_profile() {
    # Verify no profile sets MSP_SLACK_ALERT_ENV
    for profile in local ci rerelease resume test; do
        local output
        output=$(bash -c '
            source "'"$SETUP_ENV_SH"'" '"$profile"' 2>/dev/null
            echo "${MSP_SLACK_ALERT_ENV:-UNSET}"
        ' 2>/dev/null || true)
        assert_contains "$output" "UNSET" "profile '$profile' should not set MSP_SLACK_ALERT_ENV"
    done
}

# ============================================================================
# Profile dispatch tests
# ============================================================================

test_unknown_profile_fails() {
    local found
    found=$(grep -c 'Unknown profile' "$SETUP_ENV_SH")
    assert_not_equals "0" "$found" "should handle unknown profile with error message"
}

test_cleans_up_profile_var() {
    local found
    found=$(grep -c 'unset _MSP_PROFILE' "$SETUP_ENV_SH")
    assert_not_equals "0" "$found" "should clean up _MSP_PROFILE variable after use"
}

# ============================================================================
# Run tests
# ============================================================================

info "Running setup-release-env.sh unit tests..."

test_file_exists
test_prevents_direct_execution
test_no_msp_slack_alert_env
test_no_msp_slack_test_webhook
test_local_profile_exists
test_ci_profile_exists
test_rerelease_profile_exists
test_test_profile_exists
test_resume_profile_exists
test_local_profile_exports
test_ci_profile_exports
test_test_profile_exports
test_no_slack_env_in_any_profile
test_unknown_profile_fails
test_cleans_up_profile_var

echo ""
info "All setup-release-env.sh tests passed!"
