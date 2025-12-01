#!/usr/bin/env bash

set -euo pipefail

# Test Case 10: TEST MODE requires TEST webhook

repo_root="$(pwd)"

# Source helpers
# shellcheck source=Scripts/tests/release_state/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

echo "Test: TEST MODE requires TEST webhook"

# Set TEST MODE environment variables (NO test webhook, NO SLACK_BOT_TOKEN)
export MSP_SLACK_ALERT_ENV="test"
export MSP_SLACK_DM_OVERRIDE="U0910UJPD7B"

# Explicitly unset test webhook and SLACK_BOT_TOKEN
unset MSP_SLACK_TEST_WEBHOOK
unset SLACK_BOT_TOKEN

# Clear mock log
clear_mock_log

# Source notify.sh to test functions directly
# Set ROOT_DIR if not already set (required by notify.sh)
export ROOT_DIR="${ROOT_DIR:-$repo_root}"

# Source notify.sh
# shellcheck source=Scripts/release/utils/notify.sh
if [[ -f "${repo_root}/Scripts/release/utils/notify.sh" ]]; then
    source "${repo_root}/Scripts/release/utils/notify.sh" 2>/dev/null || true
fi

# Test notification routing directly (notifications aren't sent in --dry-run mode)
# Capture stderr to check for warnings
output=""
if command -v notify::module_success &>/dev/null; then
    # Call notify::module_success directly and capture output
    output=$(notify::module_success "TestModule" "0.0.1" 2>&1 || true)
fi

# Wait for async operations
sleep 0.5

# Assert: Webhook was NOT called (no test webhook set)
mock_log_not_contains "$MOCK_LOG" "hooks.slack.com" "Webhook should not be called without MSP_SLACK_TEST_WEBHOOK"

# Assert: Warning message is logged (check for partial match)
if ! echo "$output" | grep -q "TEST MODE active but MSP_SLACK_TEST_WEBHOOK not set"; then
    echo "ASSERT FAILED: Warning should be logged when test webhook is missing" >&2
    echo "Output: $output" >&2
    exit 1
fi

echo "✓ Test passed: TEST MODE requires TEST webhook (soft-fail)"

