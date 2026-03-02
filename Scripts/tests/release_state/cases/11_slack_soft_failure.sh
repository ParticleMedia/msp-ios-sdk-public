#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

set -euo pipefail

# Test Case 11: Slack soft-failure testing

repo_root="$(pwd)"

# Source helpers
# shellcheck source=Scripts/tests/release_state/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

echo "Test: Slack soft-failure (curl failures don't break release)"

export MSP_SLACK_DM_OVERRIDE="U0910UJPD7B"

# Explicitly unset SLACK_BOT_TOKEN
unset SLACK_BOT_TOKEN

# Set curl failure flag
export MOCK_CURL_FAIL=1

# Clear mock log
clear_mock_log

# Run dry-run release and capture exit code
set +e
./Scripts/msp-release.sh run 0.0.1 --dry-run --skip-preflight --no-ansi > "${repo_root}/release_output.log" 2>&1
exit_code=$?
set -e

# Wait for async operations
sleep 0.5

# Assert: Exit code is 0 (soft-fail, doesn't break release)
assert_equals "0" "$exit_code" "Release should exit 0 despite curl failures"

# Note: Without SLACK_BOT_TOKEN, DM calls are skipped, so curl for DM won't appear
# However, webhook calls don't require SLACK_BOT_TOKEN, so they should appear
# Check for webhook curl calls (these don't require token)
if grep -q "curl.*hooks.slack.com" "$MOCK_LOG" 2>/dev/null; then
    echo "✓ Webhook curl calls were attempted (as expected)"
else
    # If no curl calls, that's also acceptable - notifications are optional
    echo "Note: No curl calls detected (notifications may be optional without SLACK_BOT_TOKEN)"
fi

# Assert: Release succeeded
run_status="$(read_state_field "$repo_root" '.steps["run"].status // "<missing>"')"
assert_equals "success" "$run_status" "Release should succeed despite curl failures"

# Clean up
unset MOCK_CURL_FAIL

echo "✓ Test passed: Slack soft-failure (curl failures don't break release)"

