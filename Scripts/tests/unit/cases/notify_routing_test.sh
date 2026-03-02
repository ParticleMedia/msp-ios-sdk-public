#!/usr/bin/env bash
set -euo pipefail

# @description Unit tests for Scripts/release/utils/notify.sh routing after test-mode removal
# @test Verifies notify::dm and notify::resolve_user work without test mode

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

NOTIFY_SH="$REPO_ROOT/Scripts/release/utils/notify.sh"

# ============================================================================
# Test-mode removal verification
# ============================================================================

test_no_is_test_mode_function() {
    # notify::is_test_mode should NOT exist after removal
    local found
    found=$(grep -c 'notify::is_test_mode' "$NOTIFY_SH" || true)
    assert_equals "0" "$found" "notify::is_test_mode should not exist in notify.sh"
}

test_no_msp_slack_alert_env_reference() {
    # No references to MSP_SLACK_ALERT_ENV should exist
    local found
    found=$(grep -c 'MSP_SLACK_ALERT_ENV' "$NOTIFY_SH" || true)
    assert_equals "0" "$found" "MSP_SLACK_ALERT_ENV should not be referenced in notify.sh"
}

test_no_msp_slack_test_webhook_reference() {
    # No references to MSP_SLACK_TEST_WEBHOOK should exist
    local found
    found=$(grep -c 'MSP_SLACK_TEST_WEBHOOK' "$NOTIFY_SH" || true)
    assert_equals "0" "$found" "MSP_SLACK_TEST_WEBHOOK should not be referenced in notify.sh"
}

# ============================================================================
# notify::dm routing tests
# ============================================================================

test_dm_function_exists() {
    local found
    found=$(grep -c 'notify::dm()' "$NOTIFY_SH")
    assert_not_equals "0" "$found" "notify::dm function should exist"
}

test_dm_respects_override() {
    # notify::dm should check MSP_SLACK_DM_OVERRIDE first
    local found
    found=$(grep -A10 'notify::dm()' "$NOTIFY_SH" | grep -c 'MSP_SLACK_DM_OVERRIDE')
    assert_not_equals "0" "$found" "notify::dm should check MSP_SLACK_DM_OVERRIDE"
}

test_dm_resolves_user_when_no_override() {
    # When no override, should call notify::resolve_user
    local found
    found=$(grep -A15 'notify::dm()' "$NOTIFY_SH" | grep -c 'notify::resolve_user')
    assert_not_equals "0" "$found" "notify::dm should call resolve_user when no override"
}

test_dm_returns_zero_on_empty_target() {
    # If target_user is empty, return 0 (no-op)
    local found
    found=$(grep -A20 'notify::dm()' "$NOTIFY_SH" | grep -c '\[\[ -z "\$target_user" \]\] && return 0')
    assert_not_equals "0" "$found" "notify::dm should return 0 when target_user is empty"
}

# ============================================================================
# notify::resolve_user tests
# ============================================================================

test_resolve_user_function_exists() {
    local found
    found=$(grep -c 'notify::resolve_user()' "$NOTIFY_SH")
    assert_not_equals "0" "$found" "notify::resolve_user function should exist"
}

test_resolve_user_checks_email_map() {
    # Should check SLACK_EMAIL_MAP for author email
    local found
    found=$(grep -A20 'notify::resolve_user()' "$NOTIFY_SH" | grep -c 'SLACK_EMAIL_MAP')
    assert_not_equals "0" "$found" "notify::resolve_user should check SLACK_EMAIL_MAP"
}

test_resolve_user_falls_back_to_module_owner() {
    # Should fall back to SLACK_MODULE_OWNER if email not found
    local found
    found=$(grep -A30 'notify::resolve_user()' "$NOTIFY_SH" | grep -c 'SLACK_MODULE_OWNER')
    assert_not_equals "0" "$found" "notify::resolve_user should fall back to SLACK_MODULE_OWNER"
}

test_resolve_user_no_test_mode_bypass() {
    # The old test-mode early return ("return empty") should NOT exist
    # In old code: test-mode returned "" to skip resolution
    # After removal: should always attempt resolution
    local found
    found=$(grep -A5 'notify::resolve_user()' "$NOTIFY_SH" | grep -c 'is_test_mode' || true)
    assert_equals "0" "$found" "notify::resolve_user should not have test-mode bypass"
}

# ============================================================================
# notify::channel tests
# ============================================================================

test_channel_function_exists() {
    local found
    found=$(grep -c 'notify::channel()' "$NOTIFY_SH")
    assert_not_equals "0" "$found" "notify::channel function should exist"
}

test_channel_uses_slack_webhook_url() {
    # Should use SLACK_WEBHOOK_URL from env/slack.conf
    local found
    found=$(grep -A20 'notify::channel()' "$NOTIFY_SH" | grep -c 'SLACK_WEBHOOK_URL')
    assert_not_equals "0" "$found" "notify::channel should use SLACK_WEBHOOK_URL"
}

test_channel_no_test_webhook() {
    # The old test-mode webhook branch should not exist
    local found
    found=$(grep -A30 'notify::channel()' "$NOTIFY_SH" | grep -c 'MSP_SLACK_TEST_WEBHOOK' || true)
    assert_equals "0" "$found" "notify::channel should not reference test webhook"
}

# ============================================================================
# notify::module_error tests
# ============================================================================

test_module_error_uses_prod_env() {
    # After test-mode removal, env should always be "prod"
    local found
    found=$(grep -A10 'notify::module_error()' "$NOTIFY_SH" | grep -c 'env="prod"')
    assert_not_equals "0" "$found" "notify::module_error should hardcode env=prod"
}

# ============================================================================
# Export tests
# ============================================================================

test_exports_required_functions() {
    # Should export key functions
    local found_dm
    found_dm=$(grep -c 'export -f.*notify::dm' "$NOTIFY_SH")
    assert_not_equals "0" "$found_dm" "should export notify::dm"

    local found_resolve
    found_resolve=$(grep -c 'export -f.*notify::resolve_user' "$NOTIFY_SH")
    assert_not_equals "0" "$found_resolve" "should export notify::resolve_user"

    local found_channel
    found_channel=$(grep -c 'export -f.*notify::channel' "$NOTIFY_SH")
    assert_not_equals "0" "$found_channel" "should export notify::channel"
}

test_does_not_export_is_test_mode() {
    local found
    found=$(grep -c 'export -f.*notify::is_test_mode' "$NOTIFY_SH" || true)
    assert_equals "0" "$found" "should not export notify::is_test_mode"
}

# ============================================================================
# Run tests
# ============================================================================

info "Running notify.sh routing unit tests..."

test_no_is_test_mode_function
test_no_msp_slack_alert_env_reference
test_no_msp_slack_test_webhook_reference
test_dm_function_exists
test_dm_respects_override
test_dm_resolves_user_when_no_override
test_dm_returns_zero_on_empty_target
test_resolve_user_function_exists
test_resolve_user_checks_email_map
test_resolve_user_falls_back_to_module_owner
test_resolve_user_no_test_mode_bypass
test_channel_function_exists
test_channel_uses_slack_webhook_url
test_channel_no_test_webhook
test_module_error_uses_prod_env
test_exports_required_functions
test_does_not_export_is_test_mode

echo ""
info "All notify.sh routing tests passed!"
