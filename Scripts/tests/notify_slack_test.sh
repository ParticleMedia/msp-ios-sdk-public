#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Slack Notification E2E Test
# ============================================================================
# Purpose: End-to-end test for Slack notification system (text + BlockKit)
#
# Usage:   bash Scripts/tests/notify_slack_test.sh
#
# Requirements:
#   - MSP_SLACK_DM_OVERRIDE set (test user ID)
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

export MSP_SLACK_DISABLED="${MSP_SLACK_DISABLED:-0}"

# Disable email for this test
export MSP_EMAIL_DISABLED=1

# Enable BlockKit mode to test both text and BlockKit
export MSP_SLACK_BLOCK_MODE="${MSP_SLACK_BLOCK_MODE:-1}"

# ============================================================================
# Construct Mock NOTIFY_DATA_JSON
# ============================================================================

NOTIFY_DATA_JSON='{
  "release": {
    "version": "1.9.0-test-e2e",
    "environment": "test"
  },
  "version": "1.9.0-test-e2e",
  "author": {
    "email": "test.user@newsbreak.com",
    "name": "Test User"
  },
  "timing": {
    "duration": "180",
    "duration_human": "3m 0s",
    "started_at": "2025-12-03T12:00:00Z",
    "finished_at": "2025-12-03T12:03:00Z"
  },
  "timestamp": "2025-12-03T12:03:00Z",
  "status": "success",
  "success": true,
  "modules": {
    "MSPCore": "1.9.0-test-e2e",
    "MSPUI": "1.9.0-test-e2e",
    "MSPAnalytics": "1.9.0-test-e2e"
  },
  "remote_verify": {
    "spm": {
      "executed": true,
      "success": true,
      "version": "1.9.0-test-e2e"
    },
    "pods": {
      "executed": true,
      "success": true,
      "version": "1.9.0-test-e2e"
    }
  },
  "local_verify": {
    "executed": true,
    "mode": "pods",
    "success": true,
    "build_time": "45s"
  },
  "device_verify": {
    "executed": true,
    "mode": "pods",
    "success": true,
    "archive": "pass",
    "ipa": "pass",
    "build_time": "120s"
  },
  "xcframework_verify": {
    "executed": true,
    "modules": {
      "MSPCore": {
        "success": true,
        "warnings": 0,
        "architectures": ["arm64", "arm64-simulator", "x86_64"]
      },
      "MSPUI": {
        "success": true,
        "warnings": 1,
        "architectures": ["arm64", "arm64-simulator", "x86_64"]
      }
    }
  },
  "failure": {
    "occurred": false,
    "stage": null,
    "module": null,
    "script": null,
    "reason": null,
    "log_path": null
  }
}'

export NOTIFY_DATA_JSON

# ============================================================================
# Run Test
# ============================================================================

echo "[TEST] Slack E2E test: START"
echo "[TEST] BlockKit mode: MSP_SLACK_BLOCK_MODE=${MSP_SLACK_BLOCK_MODE}"
echo "[TEST] Email disabled: MSP_EMAIL_DISABLED=${MSP_EMAIL_DISABLED}"
echo ""
echo "[TEST] Sending Slack messages..."
echo ""

# Call notification system (soft-fail)
notify::send_release_summary "$NOTIFY_DATA_JSON" || {
    echo "[WARN] Slack test failed (soft-fail)" >&2
}

echo ""
echo "[TEST] Slack E2E test: DONE (check your Slack)"
echo "[TEST] Expected:"
echo "  - Slack DM sent to test user (if SLACK_BOT_TOKEN set)"
echo "  - Slack Channel message sent"
echo "  - BlockKit message sent (if MSP_SLACK_BLOCK_MODE=1)"
echo "  - Email NOT sent (MSP_EMAIL_DISABLED=1)"

exit 0

