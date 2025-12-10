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

# Test Case 08: Slack success notification in TEST MODE

repo_root="$(pwd)"

# Source helpers
# shellcheck source=Scripts/tests/release_state/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

echo "Test: Slack success notification in TEST MODE"

# Set TEST MODE environment variables (NO SLACK_BOT_TOKEN)
export MSP_SLACK_DM_OVERRIDE="U0910UJPD7B"
export MSP_SLACK_ALERT_ENV="test"
export MSP_SLACK_TEST_WEBHOOK="https://hooks.slack.com/services/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"

# Explicitly unset SLACK_BOT_TOKEN (user will provide manually if needed)
unset SLACK_BOT_TOKEN

# Source notify.sh to test functions directly
# shellcheck source=Scripts/release/utils/notify.sh
source "${repo_root}/Scripts/release/utils/notify.sh" 2>/dev/null || true

# Clear mock log
clear_mock_log

# Test notification routing directly using global success functions
# Module-level notifications are disabled, so we test global success functions
if command -v notify::release_success_channel &>/dev/null; then
    # Call global success channel function to test routing
    notify::release_success_channel "0.0.1" 2>/dev/null || true
fi

# Wait for async operations
sleep 0.5

# Note: Without SLACK_BOT_TOKEN, notify::_send_dm() returns early (line 251)
# DM API calls require SLACK_BOT_TOKEN, which is provided manually by user
# This test verifies that webhook routing works correctly in TEST MODE

# Assert: Test webhook was called (doesn't require SLACK_BOT_TOKEN)
mock_log_contains "$MOCK_LOG" "hooks.slack.com/services/T04Q2K244/B0A0TT1A2A0" "Test webhook should be called in TEST MODE"

# Note: DM calls (conversations.open, chat.postMessage) require SLACK_BOT_TOKEN
# They won't appear in log if token is not set - this is expected behavior
# The test verifies routing, not token validation

echo "✓ Test passed: Slack success notification in TEST MODE"

