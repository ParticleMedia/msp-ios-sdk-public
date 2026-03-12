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

# Test Case 16 (T038): Validate that resume --full overrides simple mode from state
# Per FR-040~042: --full flag on resume should take priority over state file's release_mode

repo_root="$(pwd)"

# Source helpers
# shellcheck source=Scripts/tests/release_state/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

echo "Test: Resume --full overrides simple mode from state file"

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

# Run resume with --full flag (should override state's simple mode)
output="$(./Scripts/msp-release.sh resume --full --dry-run --skip-preflight --no-ansi 2>&1 || true)"

# Wait a moment for state file updates
sleep 0.5

# Assert 1: Resume should detect the state file
assert_not_contains "$output" "No release state found" "Resume should detect the state file"

# Assert 2: Should indicate full mode was enabled
# Check for either explicit full mode message OR absence of "Skipping verification"
if [[ "$output" == *"Full release mode"* ]]; then
    echo "INFO: Confirmed full mode via explicit message"
elif [[ "$output" != *"Skipping verification"* ]]; then
    echo "INFO: Confirmed full mode (no skip verification message)"
else
    echo "ASSERT FAILED: --full flag should override simple mode from state" >&2
    exit 1
fi

# Assert 3: Should NOT mention "Simple release mode"
assert_not_contains "$output" "Simple release mode" "Should NOT be in simple mode when --full is specified"

echo "✓ Test passed: Resume --full correctly overrides simple mode from state"

# Cleanup
rm -f "${repo_root}/.msp-release-state.json"
