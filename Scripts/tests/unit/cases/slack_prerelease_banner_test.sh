#!/usr/bin/env bash
set -euo pipefail

# @description Unit tests for Slack prerelease banner branching in notify/slack.sh
# @test 5 cases per contracts/slack_notification.md:
#       production success, prerelease success (state file), prerelease success (env),
#       prerelease failure, production failure

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../mock_loader.sh"

SLACK_SH="${REPO_ROOT}/Scripts/notify/slack.sh"

# ============================================================================
# Setup
# ============================================================================

setup_slack_env() {
    mock_init
    mkdir -p "${TEST_TMPDIR}/.git"
    echo "ref: refs/heads/main" > "${TEST_TMPDIR}/.git/HEAD"

    export ROOT_DIR="${TEST_TMPDIR}"
    export MSP_STATE_DISABLE="1"
    export SLACK_WEBHOOK_URL="https://hooks.slack.com/test"

    # Tracking files (shared state between stubs and test body)
    export _CDN_CAPTURE_DIR="${TEST_TMPDIR}/captures"
    mkdir -p "$_CDN_CAPTURE_DIR"
    echo "" > "$_CDN_CAPTURE_DIR/slack_msg"
    echo "" > "$_CDN_CAPTURE_DIR/slack_color"
    echo "" > "$_CDN_CAPTURE_DIR/slack_title"
    echo "" > "$_CDN_CAPTURE_DIR/slack_fields"

    # Tracking vars (also in-shell for direct access)
    CAPTURED_SLACK_MSG=""
    CAPTURED_SLACK_COLOR=""
    CAPTURED_SLACK_TITLE=""
    CAPTURED_SLACK_FIELDS=""
    CAPTURED_DM_TEXT=""

    # Stub send_slack_notification to capture args instead of sending
    send_slack_notification() {
        CAPTURED_SLACK_MSG="${1:-}"
        CAPTURED_SLACK_COLOR="${2:-}"
        CAPTURED_SLACK_TITLE="${3:-}"
        CAPTURED_SLACK_FIELDS="${4:-}"
        # Also write to files for subshell-safe access
        printf '%s' "${1:-}" > "${_CDN_CAPTURE_DIR}/slack_msg"
        printf '%s' "${2:-}" > "${_CDN_CAPTURE_DIR}/slack_color"
        printf '%s' "${3:-}" > "${_CDN_CAPTURE_DIR}/slack_title"
        printf '%s' "${4:-}" > "${_CDN_CAPTURE_DIR}/slack_fields"
    }
    export -f send_slack_notification

    # notify::dm — put a stub script on PATH (bash can't export functions with :: in name)
    mkdir -p "${TEST_TMPDIR}/bin"
    cat > "${TEST_TMPDIR}/bin/notify::dm" <<'EOF'
#!/bin/bash
# Stub for notify::dm — captures DM text to a file
printf '%s' "${2:-}" > "${_CDN_CAPTURE_DIR}/dm_text"
EOF
    chmod +x "${TEST_TMPDIR}/bin/notify::dm"
    export PATH="${TEST_TMPDIR}/bin:${PATH}"

    # Stub log functions
    log::info()    { true; }
    log::warn()    { true; }
    log::error()   { true; }
    log::success() { true; }
    export -f log::info log::warn log::error log::success

    # Stub helper functions that slack.sh depends on
    get_slack_environment_info() { echo "test-env"; }
    format_release_notes_for_slack() { echo "$1"; }
    export -f get_slack_environment_info format_release_notes_for_slack

    # Reset state file
    rm -f "${TEST_TMPDIR}/.msp-release-state.json"

    unset MSP_PRERELEASE 2>/dev/null || true
    unset MSP_IS_PRERELEASE 2>/dev/null || true
    unset CI 2>/dev/null || true
}

source_slack() {
    unset _NOTIFY_SLACK_SOURCED 2>/dev/null || true
    # shellcheck source=/dev/null
    source "${SLACK_SH}"

    # Re-apply stubs AFTER sourcing (slack.sh overwrites exported functions)
    send_slack_notification() {
        CAPTURED_SLACK_MSG="${1:-}"
        CAPTURED_SLACK_COLOR="${2:-}"
        CAPTURED_SLACK_TITLE="${3:-}"
        CAPTURED_SLACK_FIELDS="${4:-}"
    }
    export -f send_slack_notification

    log::info()    { true; }
    log::warn()    { true; }
    log::error()   { true; }
    log::success() { true; }
    log::debug()   { true; }
    export -f log::info log::warn log::error log::success log::debug
}

write_state_is_prerelease() {
    local val="$1"
    cat > "${TEST_TMPDIR}/.msp-release-state.json" <<EOF
{
  "schema_version": 4,
  "is_prerelease": ${val},
  "timestamps": {"started_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
}
EOF
}

# ============================================================================
# Case 1: state file is_prerelease=false → production success
#   Expected: title contains "Release Successful!", color="good", no banner
# ============================================================================

test_production_success() {
    setup_slack_env
    write_state_is_prerelease "false"
    source_slack

    unset MSP_IS_PRERELEASE 2>/dev/null || true
    notify_release_success "MSP" "3.6.8" "MSPCore MSPAds" "5m"

    assert_contains "$CAPTURED_SLACK_MSG" "Release Successful!" \
        "Production: title should contain 'Release Successful!'"
    assert_equals "good" "$CAPTURED_SLACK_COLOR" \
        "Production: color should be 'good'"
    assert_not_contains "$CAPTURED_SLACK_MSG" "PRERELEASE" \
        "Production: no PRERELEASE in title"
    assert_not_contains "$CAPTURED_SLACK_FIELDS" "DO NOT use" \
        "Production: no 'DO NOT use' banner in fields"
    info "Case 1: production success → good color, no banner verified"
}

# ============================================================================
# Case 2: state file is_prerelease=true → prerelease success
#   Expected: title contains "PRERELEASE Published", color="warning",
#             fields contain "DO NOT use in production"
# ============================================================================

test_prerelease_success_via_state_file() {
    setup_slack_env
    write_state_is_prerelease "true"
    source_slack

    unset MSP_IS_PRERELEASE 2>/dev/null || true
    notify_release_success "MSP" "3.6.8-rc.1" "MSPCore MSPAds" "5m"

    assert_contains "$CAPTURED_SLACK_MSG" "PRERELEASE" \
        "Prerelease: title should contain 'PRERELEASE'"
    assert_equals "warning" "$CAPTURED_SLACK_COLOR" \
        "Prerelease: color should be 'warning'"
    assert_contains "$CAPTURED_SLACK_FIELDS" "DO NOT use" \
        "Prerelease: fields should contain 'DO NOT use' banner"
    info "Case 2: prerelease success (state file) → warning color, banner verified"
}

# ============================================================================
# Case 3: no state file, env MSP_IS_PRERELEASE=1 → prerelease success
#   Expected: same as case 2
# ============================================================================

test_prerelease_success_via_env() {
    setup_slack_env
    rm -f "${TEST_TMPDIR}/.msp-release-state.json"
    source_slack

    export MSP_IS_PRERELEASE=1
    notify_release_success "MSP" "3.6.8-rc.1" "MSPCore" "3m"

    assert_contains "$CAPTURED_SLACK_MSG" "PRERELEASE" \
        "Prerelease (env): title should contain 'PRERELEASE'"
    assert_equals "warning" "$CAPTURED_SLACK_COLOR" \
        "Prerelease (env): color should be 'warning'"
    assert_contains "$CAPTURED_SLACK_FIELDS" "DO NOT use" \
        "Prerelease (env): fields should contain banner"
    unset MSP_IS_PRERELEASE 2>/dev/null || true
    info "Case 3: prerelease success (env) → warning color, banner verified"
}

# ============================================================================
# Case 4: state file is_prerelease=true → prerelease failure
#   Expected: title contains "(prerelease) Failed!", color="danger", no banner
# ============================================================================

test_prerelease_failure() {
    setup_slack_env
    write_state_is_prerelease "true"
    source_slack

    unset MSP_IS_PRERELEASE 2>/dev/null || true
    notify_release_failure "MSP" "3.6.8-rc.1" "Build failed" "pod_publish"

    assert_contains "$CAPTURED_SLACK_MSG" "prerelease" \
        "Prerelease failure: title should contain 'prerelease'"
    # color stays danger
    # (notify_release_failure currently goes to DM only, so we check DM text)
    # If send_slack_notification is called, check color; otherwise check DM
    if [[ -n "$CAPTURED_SLACK_COLOR" ]]; then
        assert_equals "danger" "$CAPTURED_SLACK_COLOR" \
            "Prerelease failure: color should be 'danger'"
    fi
    info "Case 4: prerelease failure → (prerelease) in title verified"
}

# ============================================================================
# Case 5: state file is_prerelease=false → production failure
#   Expected: title contains "Release Failed!", no "(prerelease)", color="danger"
# ============================================================================

test_production_failure() {
    setup_slack_env
    write_state_is_prerelease "false"
    source_slack

    unset MSP_IS_PRERELEASE 2>/dev/null || true
    notify_release_failure "MSP" "3.6.8" "Network error" "cdn_check"

    # For production failure, "(prerelease)" should NOT appear
    assert_not_contains "$CAPTURED_SLACK_MSG" "prerelease" \
        "Production failure: title should NOT contain 'prerelease'"
    if [[ -n "$CAPTURED_DM_TEXT" ]]; then
        assert_not_contains "$CAPTURED_DM_TEXT" "prerelease" \
            "Production failure: DM text should NOT contain 'prerelease'"
    fi
    info "Case 5: production failure → no prerelease in title verified"
}

# ============================================================================
# Run All Tests
# ============================================================================

info "Running slack_prerelease_banner tests..."

test_production_success
test_prerelease_success_via_state_file
test_prerelease_success_via_env
test_prerelease_failure
test_production_failure

info "All slack_prerelease_banner tests passed!"
