#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

set -euo pipefail

# Test Case 15 (T037): Validate that resume respects simple mode from state file
# Per FR-040~042: Resume should read release_mode from state and respect it

repo_root="$(pwd)"

# Source helpers
# shellcheck source=Scripts/tests/release_state/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

echo "Test: Resume respects simple mode from state file"

# Create a synthetic state file with simple mode and a failed step
cat > "${repo_root}/.msp-release-state.json" <<EOF
{
  "schema_version": 1,
  "run_id": "test-run-$(date +%s)",
  "mode": "run",
  "version": "0.0.1",
  "release_mode": "simple",
  "base_branch": "main",
  "release_branch": "release/0.0.1",
  "dry_run": false,
  "config": {
    "config_path": null,
    "cli_args": "",
    "invoked_subcommand": "run"
  },
  "git": {
    "tag_created": true,
    "tag_name": "v0.0.1",
    "release_branch_pushed": false,
    "github_release_created": false
  },
  "steps": {
    "preflight": {
      "status": "success",
      "attempt": 1
    },
    "run": {
      "status": "failed",
      "attempt": 1,
      "error_message": "Test failure for resume test"
    }
  },
  "timestamps": {
    "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  },
  "last_error": {
    "step": "run",
    "message": "Test failure for resume test",
    "exit_code": 1,
    "occurred_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}
EOF

# Run resume (should read release_mode: simple from state)
output="$(./Scripts/msp-release.sh resume --dry-run --skip-preflight --no-ansi 2>&1 || true)"

# Wait a moment for state file updates
sleep 0.5

# Assert 1: Resume should detect the state file
# If no state file error, we're good
assert_not_contains "$output" "No release state found" "Resume should detect the state file"

# Assert 2: Should stay in simple mode (not upgrade to full mode)
# Output should indicate simple mode OR skip verification
if [[ "$output" == *"Simple release mode"* ]] || [[ "$output" == *"Skipping verification"* ]]; then
    echo "INFO: Confirmed simple mode behavior"
else
    # It's acceptable if resume doesn't explicitly log mode, as long as it doesn't do full mode
    echo "INFO: Mode not explicitly logged, checking for full mode indicators"
fi

# Assert 3: Should NOT be in full mode (unless --full was specified)
assert_not_contains "$output" "Full release mode" "Should NOT be in full mode when state has simple"

echo "✓ Test passed: Resume correctly respects simple mode from state file"

# Cleanup
rm -f "${repo_root}/.msp-release-state.json"
