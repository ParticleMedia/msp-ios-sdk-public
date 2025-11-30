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
output=$(./Scripts/msp-release.sh resume --dry-run --no-ansi 2>&1 || true)

# Verify that preflight_static is skipped (already succeeded) - check for partial match
assert_contains "$output" "skipping preflight_static" "Resume should skip preflight_static"

# The failed step should be retried (we can't easily verify success without full integration,
# but we can verify it's not skipped)
assert_not_contains "$output" "skipping spm_publish" "Resume should NOT skip failed spm_publish"

echo "✓ Test passed: Resume retries failed step"

