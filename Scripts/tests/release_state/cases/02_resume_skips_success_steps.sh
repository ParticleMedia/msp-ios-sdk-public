#!/usr/bin/env bash

set -euo pipefail

# Test Case 02: Resume skips steps that have already succeeded

repo_root="$(pwd)"

# Source helpers
# shellcheck source=Scripts/tests/release_state/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

echo "Test: Resume skips success steps"

# First, create a state file with successful preflight steps
cat > "${repo_root}/.msp-release-state.json" <<'EOF'
{
  "schema_version": 1,
  "run_id": "test-resume-001",
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
    "preflight_build": {
      "status": "success",
      "attempt": 1,
      "started_at": "2024-01-01T00:00:01Z",
      "completed_at": "2024-01-01T00:00:02Z"
    }
  },
  "timestamps": {
    "started_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:02Z"
  },
  "last_error": {
    "step": null,
    "message": null,
    "exit_code": null,
    "occurred_at": null
  }
}
EOF

# Clear mock log
clear_mock_log

# Run resume
output=$(./Scripts/msp-release.sh resume --dry-run --no-ansi 2>&1 || true)

# Assert that resume mentions skipping preflight_static (check for partial match)
assert_contains "$output" "skipping preflight_static" "Resume should skip preflight_static"

# Assert that resume mentions skipping preflight_build (check for partial match)
assert_contains "$output" "skipping preflight_build" "Resume should skip preflight_build"

echo "✓ Test passed: Resume correctly skips success steps"

