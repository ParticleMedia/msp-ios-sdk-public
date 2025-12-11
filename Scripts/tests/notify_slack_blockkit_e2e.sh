#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Slack BlockKit E2E Test
# ============================================================================
# Purpose: End-to-end test for Slack BlockKit notification system
#
# Usage:   bash Scripts/tests/notify_slack_blockkit_e2e.sh
#
# Requirements:
#   - MSP_SLACK_ALERT_ENV="test"
#   - MSP_SLACK_DM_OVERRIDE set (test user ID)
#   - MSP_SLACK_TEST_WEBHOOK set (test webhook URL)
#   - SLACK_BOT_TOKEN set (for DM sending)
# ============================================================================

set -euo pipefail

# ============================================================================
# Setup
# ============================================================================

# Detect ROOT_DIR
if [[ -z "${ROOT_DIR:-}" ]]; then
    if command -v git >/dev/null 2>&1; then
        ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
    fi
    if [[ -z "${ROOT_DIR:-}" ]]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
    fi
fi
export ROOT_DIR

# Source notification core
source "${ROOT_DIR}/Scripts/notify/notify_core.sh" 2>/dev/null || {
    echo "[ERROR] Failed to source notify_core.sh" >&2
    exit 1
}

# ============================================================================
# Test Configuration
# ============================================================================

# Ensure TEST MODE
export MSP_SLACK_ALERT_ENV="${MSP_SLACK_ALERT_ENV:-test}"
export MSP_SLACK_DISABLED="${MSP_SLACK_DISABLED:-0}"

# Disable email for this test
export MSP_EMAIL_DISABLED=1

# Enable BlockKit mode
export MSP_SLACK_BLOCK_MODE=1

echo "[TEST] notify_slack_blockkit_e2e.sh: START"
echo "[TEST] Environment: MSP_SLACK_ALERT_ENV=$MSP_SLACK_ALERT_ENV"
echo "[TEST] BlockKit mode: MSP_SLACK_BLOCK_MODE=$MSP_SLACK_BLOCK_MODE"
echo "[TEST] Email disabled: MSP_EMAIL_DISABLED=$MSP_EMAIL_DISABLED"

# ============================================================================
# Mock NOTIFY_DATA_JSON
# ============================================================================

NOTIFY_DATA_JSON='{
  "release": {
    "version": "1.9.0-test-e2e",
    "environment": "prod",
    "channel": "stable"
  },
  "author": {
    "email": "test.user@newsbreak.com",
    "name": "Test User"
  },
  "timing": {
    "duration_human": "3m 0s",
    "finished_at": "2025-12-03T12:03:00Z"
  },
  "status": "success",
  "overall_success": true,
  "modules": {
    "MSPCore": "1.9.0-test-e2e",
    "MSPUI": "1.9.0-test-e2e",
    "MSPAnalytics": "1.9.0-test-e2e"
  },
  "remote_verify": {
    "spm": { "executed": true, "success": true, "log": "SPM remote verification passed." },
    "pods": { "executed": true, "success": true, "log": "Pods remote verification passed." }
  },
  "local_verify": {
    "executed": true,
    "mode": "pods",
    "success": true,
    "log": "Local pods verification passed."
  },
  "device_verify": {
    "executed": true,
    "mode": "pods",
    "success": true,
    "archive": "pass",
    "ipa": "pass",
    "log": "Device pods verification passed."
  },
  "xcframework_verify": {
    "executed": true,
    "modules": {
      "MSPCore": { "success": true, "warnings": 0, "log": "MSPCore XCFramework passed." }
    }
  },
  "failure": {
    "occurred": false,
    "stage": null,
    "module": null,
    "script": null,
    "reason": null,
    "log_path": null
  },
  "release_notes": "This is a test release with new BlockKit design. Includes improved timestamp formatting and section-based layout."
}'
export NOTIFY_DATA_JSON

# ============================================================================
# Trigger Notification
# ============================================================================

echo "[TEST] Sending real Slack BlockKit message..."
notify::send_release_summary "$NOTIFY_DATA_JSON" || echo "[WARN] notify::send_release_summary failed (soft-fail)" >&2

echo "[TEST] Slack BlockKit E2E test: DONE (check your Slack)"
echo "[TEST] Expected:"
echo "  - Slack Channel message sent to test webhook (if MSP_SLACK_TEST_WEBHOOK set)"
echo "  - BlockKit message with new section-based design"
echo "  - Formatted timestamp (not raw ISO8601)"
echo "  - Email NOT sent (MSP_EMAIL_DISABLED=1)"

exit 0

