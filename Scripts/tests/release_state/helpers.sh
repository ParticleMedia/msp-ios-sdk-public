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

# Test helpers for release state test suite
# Provides assertion utilities and state inspection functions

# Log file for mock invocations (set by run_all.sh)
MOCK_LOG="${MOCK_LOG:-./mock_invocations.log}"

# ============================================================================
# Assertion Functions
# ============================================================================

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    
    if [[ "$expected" != "$actual" ]]; then
        echo "ASSERT FAILED: ${message} (expected='${expected}', actual='${actual}')" >&2
        exit 1
    fi
}

assert_file_exists() {
    local path="$1"
    local message="$2"
    
    if [[ ! -f "$path" ]]; then
        echo "ASSERT FAILED: ${message} (file not found: ${path})" >&2
        exit 1
    fi
}

assert_file_not_exists() {
    local path="$1"
    local message="$2"
    
    if [[ -f "$path" ]]; then
        echo "ASSERT FAILED: ${message} (file should not exist: ${path})" >&2
        exit 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"
    
    if [[ "$haystack" != *"$needle"* ]]; then
        echo "ASSERT FAILED: ${message} (expected to find '${needle}' in output)" >&2
        exit 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        echo "ASSERT FAILED: ${message} (expected NOT to find '${needle}' in output)" >&2
        exit 1
    fi
}

# ============================================================================
# State Inspection Functions
# ============================================================================

read_state_field() {
    local repo_root="$1"
    local jq_expr="$2"
    
    local state_file="${repo_root}/.msp-release-state.json"
    if [[ ! -f "$state_file" ]]; then
        echo "ASSERT FAILED: state file not found at ${state_file}" >&2
        exit 1
    fi
    
    jq -r "$jq_expr" "$state_file" 2>/dev/null || echo "<error>"
}

assert_state_step_status() {
    local repo_root="$1"
    local step="$2"
    local expected="$3"
    
    local status
    status="$(read_state_field "$repo_root" ".steps[\"${step}\"].status // \"<missing>\"")"
    assert_equals "$expected" "$status" "Step ${step} status mismatch"
}

assert_state_field() {
    local repo_root="$1"
    local jq_expr="$2"
    local expected="$3"
    local message="$4"
    
    local actual
    actual="$(read_state_field "$repo_root" "$jq_expr")"
    assert_equals "$expected" "$actual" "${message}"
}

# ============================================================================
# Mock Log Inspection
# ============================================================================

mock_log_contains() {
    local log_file="${1:-${MOCK_LOG}}"
    local pattern="$2"
    local message="$3"
    
    # If only 2 args provided, treat first as pattern and second as message
    if [[ $# -eq 2 ]]; then
        pattern="$1"
        message="$2"
        log_file="${MOCK_LOG}"
    fi
    
    if [[ ! -f "$log_file" ]]; then
        echo "ASSERT FAILED: ${message} (mock log not found: ${log_file})" >&2
        exit 1
    fi
    
    if ! grep -q "$pattern" "$log_file" 2>/dev/null; then
        echo "ASSERT FAILED: ${message} (expected pattern '${pattern}' not found in mock log)" >&2
        exit 1
    fi
}

mock_log_not_contains() {
    local log_file="${1:-${MOCK_LOG}}"
    local pattern="$2"
    local message="$3"
    
    # If only 2 args provided, treat first as pattern and second as message
    if [[ $# -eq 2 ]]; then
        pattern="$1"
        message="$2"
        log_file="${MOCK_LOG}"
    fi
    
    if [[ ! -f "$log_file" ]]; then
        return 0  # Log doesn't exist, so pattern doesn't exist
    fi
    
    if grep -q "$pattern" "$log_file" 2>/dev/null; then
        echo "ASSERT FAILED: ${message} (expected pattern '${pattern}' should NOT be in mock log)" >&2
        exit 1
    fi
}

clear_mock_log() {
    > "$MOCK_LOG" 2>/dev/null || true
}

# ============================================================================
# Utility Functions
# ============================================================================

create_synthetic_state() {
    local repo_root="$1"
    local version="${2:-0.0.1}"
    local tag_name="${3:-v${version}}"
    local release_branch="${4:-release/${version}}"
    
    cat > "${repo_root}/.msp-release-state.json" <<EOF
{
  "schema_version": 1,
  "run_id": "test-run-$(date +%s)",
  "mode": "run",
  "version": "${version}",
  "base_branch": "main",
  "release_branch": "${release_branch}",
  "dry_run": false,
  "config": {
    "config_path": null,
    "cli_args": "",
    "invoked_subcommand": "run"
  },
  "git": {
    "tag_created": true,
    "tag_name": "${tag_name}",
    "release_branch_pushed": true,
    "github_release_created": true
  },
  "steps": {
    "run": {
      "status": "success",
      "attempt": 1,
      "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
      "completed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }
  },
  "timestamps": {
    "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  },
  "last_error": {
    "step": null,
    "message": null,
    "exit_code": null,
    "occurred_at": null
  }
}
EOF
}

