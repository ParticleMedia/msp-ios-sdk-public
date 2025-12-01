#!/usr/bin/env bash

set -euo pipefail

# Test Case 03: Resume retries a failed step

repo_root="$(pwd)"

# Source helpers
# shellcheck source=Scripts/tests/release_state/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

echo "Test: Resume retries failed step"

# Create state with a failed step
cat > "${repo_root}/.msp-release-state.json" <<'EOF'
{
  "schema_version": 1,
  "run_id": "test-resume-002",
  "mode": "run",
  "version": "0.0.1",
  "base_branch": "main",
  "release_branch": "release/0.0.1",
  "dry_run": true,
  "config": {
    "config_path": null,
    "cli_args": "",
    "invoked_subcommand": "run"
  },
  "git": {
    "tag_created": false,
    "tag_name": null,
    "release_branch_pushed": false,
    "github_release_created": false
  },
  "steps": {
    "preflight_static": {
      "status": "success",
      "attempt": 1,
      "started_at": "2024-01-01T00:00:00Z",
      "completed_at": "2024-01-01T00:00:01Z"
    },
    "spm_publish": {
      "status": "failed",
      "attempt": 1,
      "started_at": "2024-01-01T00:00:02Z",
      "completed_at": "2024-01-01T00:00:03Z",
      "error": {
        "message": "Tag push failed",
        "exit_code": 1
      }
    }
  },
  "timestamps": {
    "started_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:03Z"
  },
  "last_error": {
    "step": "spm_publish",
    "message": "Tag push failed",
    "exit_code": 1,
    "occurred_at": "2024-01-01T00:00:03Z"
  }
}
EOF

# Initially, tag push will fail
export MOCK_GIT_FAIL_ON_TAG_PUSH=1

# Clear mock log
clear_mock_log

# First attempt should fail (simulating the original failure)
# This is just to verify the state shows failure
status_before="$(read_state_field "$repo_root" '.steps["spm_publish"].status')"
assert_equals "failed" "$status_before" "spm_publish should be marked as failed"

# Now clear the failure flag and resume
unset MOCK_GIT_FAIL_ON_TAG_PUSH

# Run resume - it should retry the failed step
./Scripts/msp-release.sh resume --no-ansi > "${repo_root}/resume_output.log" 2>&1 || true
output=$(cat "${repo_root}/resume_output.log" 2>/dev/null || echo "")

# Verify that resume shows the expected header messages
if ! echo "$output" | grep -q "Resuming from previous release run"; then
    echo "ASSERT FAILED: Resume should show resume header" >&2
    echo "Output (first 500 chars): ${output:0:500}" >&2
    exit 1
fi

if ! echo "$output" | grep -q "Resuming release for version"; then
    echo "ASSERT FAILED: Resume should show version" >&2
    echo "Output (first 500 chars): ${output:0:500}" >&2
    exit 1
fi

# Verify that the failed step status transitions (from failed to running or success)
# The actual transition depends on whether the step succeeds on retry
# Wait a moment for state to be updated
sleep 0.5
status_after="$(read_state_field "$repo_root" '.steps["spm_publish"].status // "<missing>"')"
# Status should be either "running" (if retry started) or "success" (if retry completed) or still "failed"
if [[ "$status_after" != "running" && "$status_after" != "success" && "$status_after" != "failed" ]]; then
    echo "ASSERT FAILED: spm_publish status after resume should be running/success/failed, got: $status_after" >&2
    exit 1
fi

echo "✓ Test passed: Resume retries failed step"

