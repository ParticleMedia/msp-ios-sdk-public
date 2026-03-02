#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

set -euo pipefail

# Test Case 09: DM notification soft-fails without bot token

repo_root="$(pwd)"

# Source helpers
# shellcheck source=Scripts/tests/release_state/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

echo "Test: DM notification soft-fails without bot token"

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

# Unset SLACK_BOT_TOKEN AFTER sourcing notify.sh
# (slack.conf sets it during source, so we must unset after)
unset SLACK_BOT_TOKEN

# Test: Without bot token, DM should fail gracefully (non-blocking)
output=""
rc=0
if command -v notify::dm &>/dev/null; then
    output=$(notify::dm "" "test message" 2>&1) || rc=$?
fi

# Wait for async operations
sleep 0.5

# Assert: DM send was attempted but failed due to missing bot token
if ! echo "$output" | grep -q "SLACK_BOT_TOKEN not set"; then
    echo "ASSERT FAILED: Should warn about missing SLACK_BOT_TOKEN" >&2
    echo "Output: $output" >&2
    exit 1
fi

# Assert: function returned non-zero (failure, but non-blocking to caller)
if [[ "$rc" -eq 0 ]]; then
    echo "ASSERT FAILED: notify::dm should return non-zero when bot token is missing" >&2
    exit 1
fi

echo "✓ Test passed: DM notification soft-fails without bot token"
