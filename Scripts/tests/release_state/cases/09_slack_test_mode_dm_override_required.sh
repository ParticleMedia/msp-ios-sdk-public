#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch K, shared) ---
# shellcheck source=/dev/null
if command -v git >/dev/null 2>&1; then
  MSP_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$MSP_REPO_ROOT" ] && [ -f "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh" ]; then
    # shellcheck source=/dev/null
    . "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh"
    msp_enforce_main_repo_or_exit
  fi
fi
# --- End MSP Worktree Safety Guard (Patch K, shared) ---

set -euo pipefail

# Test Case 09: TEST MODE requires DM override

repo_root="$(pwd)"

# Source helpers
# shellcheck source=Scripts/tests/release_state/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

echo "Test: TEST MODE requires DM override"

# Set TEST MODE environment variables (NO DM override, NO SLACK_BOT_TOKEN)
export MSP_SLACK_ALERT_ENV="test"
export MSP_SLACK_TEST_WEBHOOK="https://hooks.slack.com/services/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"

# Explicitly unset DM override and SLACK_BOT_TOKEN
unset MSP_SLACK_DM_OVERRIDE
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

# Test notification routing directly using global success DM function
# Module-level notifications are disabled, so we test global success functions
# Capture stderr to check for warnings
output=""
if command -v notify::release_success_dm &>/dev/null; then
    # Call global success DM function and capture output
    output=$(notify::release_success_dm "0.0.1" 2>&1 || true)
fi

# Wait for async operations
sleep 0.5

# Assert: DM API was NOT called (no override set)
mock_log_not_contains "$MOCK_LOG" "conversations.open" "DM should not be attempted without MSP_SLACK_DM_OVERRIDE"

# Assert: Warning message is logged (check for partial match)
if ! echo "$output" | grep -q "TEST MODE active but MSP_SLACK_DM_OVERRIDE not set"; then
    echo "ASSERT FAILED: Warning should be logged when DM override is missing" >&2
    echo "Output: $output" >&2
    exit 1
fi

echo "✓ Test passed: TEST MODE requires DM override (soft-fail)"

