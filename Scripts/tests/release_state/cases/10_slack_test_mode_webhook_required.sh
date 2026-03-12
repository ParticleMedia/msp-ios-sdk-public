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

set -euo pipefail

# Test Case 10: Channel notification requires webhook

repo_root="$(pwd)"

# Source helpers
# shellcheck source=Scripts/tests/release_state/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

echo "Test: Channel notification requires webhook"

export MSP_SLACK_DM_OVERRIDE="U0910UJPD7B"

# Clear mock log
clear_mock_log

# Source notify.sh to test functions directly
# Set ROOT_DIR if not already set (required by notify.sh)
export ROOT_DIR="${ROOT_DIR:-$repo_root}"

# Source notify.sh (this may load slack.conf which re-sets vars)
# shellcheck source=Scripts/release/utils/notify.sh
if [[ -f "${repo_root}/Scripts/release/utils/notify.sh" ]]; then
    source "${repo_root}/Scripts/release/utils/notify.sh" 2>/dev/null || true
fi

# Unset SLACK_BOT_TOKEN and SLACK_WEBHOOK_URL AFTER sourcing notify.sh
# (slack.conf sets these during source, so we must unset after)
unset SLACK_BOT_TOKEN
unset SLACK_WEBHOOK_URL

# Test notification routing directly using notify::channel
# Call notify::channel directly (not through release_success_channel which suppresses stderr)
output=""
if command -v notify::channel &>/dev/null; then
    output=$(notify::channel "test message" 2>&1 || true)
fi

# Wait for async operations
sleep 0.5

# Assert: Webhook was NOT called (no webhook configured)
mock_log_not_contains "$MOCK_LOG" "hooks.slack.com" "Webhook should not be called without SLACK_WEBHOOK_URL"

echo "✓ Test passed: Channel notification requires webhook (soft-fail)"
