#!/usr/bin/env bash
set -euo pipefail

# @description Unit tests for state.sh status transitions
# @test running→success, running→failed, pending→skipped, multiple transitions

# Get the repo root (relative to this test file)
# This file is at: Scripts/tests/unit/cases/state_transition_test.sh
# So repo root is 4 directories up
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

# Source helpers
source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../mock_loader.sh"

# ============================================================================
# Test Setup
# ============================================================================

setup_test_env() {
    # Initialize mock system
    mock_init

    # Create directory structure
    mkdir -p "${TEST_TMPDIR}/Scripts/release/utils"
    mkdir -p "${TEST_TMPDIR}/Scripts/lib"

    # Copy worktree_guard.sh or create a no-op version for testing
    cat > "${TEST_TMPDIR}/Scripts/lib/worktree_guard.sh" <<'EOF'
#!/bin/bash
# No-op worktree guard for testing
msp_enforce_main_repo_or_exit() { return 0; }
export -f msp_enforce_main_repo_or_exit
EOF

    # Create minimal .git for git rev-parse
    mkdir -p "${TEST_TMPDIR}/.git"
    echo "ref: refs/heads/main" > "${TEST_TMPDIR}/.git/HEAD"
    cat > "${TEST_TMPDIR}/.git/config" <<'EOF'
[core]
    repositoryformatversion = 0
EOF

    # Copy the actual state.sh for testing, but remove the worktree guard lines
    # since they rely on git rev-parse which won't work in test isolation
    sed '/^#!\/usr\/bin\/env bash/d; /^# --- MSP Worktree Safety Guard/,/^# --- End MSP Worktree Safety Guard/d' "${REPO_ROOT}/Scripts/release/utils/state.sh" > "${TEST_TMPDIR}/Scripts/release/utils/state.sh"

    # Add shebang and source the no-op worktree guard
    cat > "${TEST_TMPDIR}/Scripts/release/utils/state_patched.sh" <<EOF
#!/bin/bash
# Patched state.sh for unit testing
source "${TEST_TMPDIR}/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
$(cat "${TEST_TMPDIR}/Scripts/release/utils/state.sh")
EOF
    mv "${TEST_TMPDIR}/Scripts/release/utils/state_patched.sh" "${TEST_TMPDIR}/Scripts/release/utils/state.sh"

    # Set environment
    export ROOT_DIR="${TEST_TMPDIR}"
    export MSP_STATE_DISABLE=""
}

# ============================================================================
# Test: Transition running → success
# ============================================================================

test_transition_running_to_success() {
    setup_test_env
    cd "${TEST_TMPDIR}"

    # Create state file with running step
    cat > "${TEST_TMPDIR}/.msp-release-state.json" <<'EOF'
{
  "schema_version": 3,
  "steps": {
    "preflight": {
      "status": "running",
      "attempt": 1,
      "started_at": "2026-01-01T00:00:00Z",
      "completed_at": null
    }
  },
  "timestamps": {
    "started_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:00:00Z"
  }
}
EOF

    # Source state.sh
    # shellcheck source=/dev/null
    source "${TEST_TMPDIR}/Scripts/release/utils/state.sh"

    # Get initial status
    local initial_status
    initial_status="$(msp_state_get_step_status "preflight")"
    assert_equals "running" "$initial_status" "Initial status should be 'running'"

    # Transition to success
    msp_state_mark_step_success "preflight"

    # Verify transition
    local final_status
    final_status="$(msp_state_get_step_status "preflight")"
    assert_equals "success" "$final_status" "Final status should be 'success'"

    # Verify completed_at is set
    local completed_at
    completed_at=$(jq -r '.steps.preflight.completed_at' "${TEST_TMPDIR}/.msp-release-state.json")
    assert_not_equals "null" "$completed_at" "completed_at should be set after success"

    # Verify attempt is preserved
    local attempt
    attempt=$(jq -r '.steps.preflight.attempt' "${TEST_TMPDIR}/.msp-release-state.json")
    assert_equals "1" "$attempt" "Attempt count should be preserved"

    info "Transition running → success works correctly"
}

# ============================================================================
# Test: Transition running → failed
# ============================================================================

test_transition_running_to_failed() {
    setup_test_env
    cd "${TEST_TMPDIR}"

    # Create state file with running step
    cat > "${TEST_TMPDIR}/.msp-release-state.json" <<'EOF'
{
  "schema_version": 3,
  "steps": {
    "build": {
      "status": "running",
      "attempt": 1,
      "started_at": "2026-01-01T00:00:00Z",
      "completed_at": null
    }
  },
  "last_error": {
    "step": null,
    "message": null,
    "exit_code": null,
    "occurred_at": null
  },
  "timestamps": {
    "started_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:00:00Z"
  }
}
EOF

    # Source state.sh
    # shellcheck source=/dev/null
    source "${TEST_TMPDIR}/Scripts/release/utils/state.sh"

    # Get initial status
    local initial_status
    initial_status="$(msp_state_get_step_status "build")"
    assert_equals "running" "$initial_status" "Initial status should be 'running'"

    # Transition to failed
    msp_state_mark_step_failed "build" "Compilation error" 1

    # Verify transition
    local final_status
    final_status="$(msp_state_get_step_status "build")"
    assert_equals "failed" "$final_status" "Final status should be 'failed'"

    # Verify last_error is set
    local error_step error_message
    error_step=$(jq -r '.last_error.step' "${TEST_TMPDIR}/.msp-release-state.json")
    error_message=$(jq -r '.last_error.message' "${TEST_TMPDIR}/.msp-release-state.json")
    assert_equals "build" "$error_step" "last_error.step should be 'build'"
    assert_contains "$error_message" "Compilation error" "Error message should be preserved"

    info "Transition running → failed works correctly"
}

# ============================================================================
# Test: Transition pending → skipped
# ============================================================================

test_transition_pending_to_skipped() {
    setup_test_env
    cd "${TEST_TMPDIR}"

    # Create state file with no verify step (implicit pending)
    cat > "${TEST_TMPDIR}/.msp-release-state.json" <<'EOF'
{
  "schema_version": 3,
  "steps": {},
  "timestamps": {
    "started_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:00:00Z"
  }
}
EOF

    # Source state.sh
    # shellcheck source=/dev/null
    source "${TEST_TMPDIR}/Scripts/release/utils/state.sh"

    # Get initial status (should be unknown/pending since step doesn't exist)
    local initial_status
    initial_status="$(msp_state_get_step_status "verify")"
    assert_equals "unknown" "$initial_status" "Initial status should be 'unknown' (step doesn't exist)"

    # Transition to skipped
    msp_state_mark_step_skipped "verify" "Simple mode - verification skipped"

    # Verify transition
    local final_status
    final_status="$(msp_state_get_step_status "verify")"
    assert_equals "skipped" "$final_status" "Final status should be 'skipped'"

    # Verify notes contain skip reason
    local notes
    notes=$(jq -r '.steps.verify.notes' "${TEST_TMPDIR}/.msp-release-state.json")
    assert_contains "$notes" "Simple mode" "Notes should contain skip reason"

    # Verify attempt is 0 for skipped step
    local attempt
    attempt=$(jq -r '.steps.verify.attempt' "${TEST_TMPDIR}/.msp-release-state.json")
    assert_equals "0" "$attempt" "Attempt should be 0 for skipped step"

    info "Transition pending → skipped works correctly"
}

# ============================================================================
# Test: Retry transition (failed → running → success)
# ============================================================================

test_retry_transition_failed_running_success() {
    setup_test_env
    cd "${TEST_TMPDIR}"

    # Create state file with failed step
    cat > "${TEST_TMPDIR}/.msp-release-state.json" <<'EOF'
{
  "schema_version": 3,
  "steps": {
    "publish": {
      "status": "failed",
      "attempt": 1,
      "started_at": "2026-01-01T00:00:00Z",
      "completed_at": "2026-01-01T00:05:00Z"
    }
  },
  "last_error": {
    "step": "publish",
    "message": "Network timeout",
    "exit_code": 1,
    "occurred_at": "2026-01-01T00:05:00Z"
  },
  "timestamps": {
    "started_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:05:00Z"
  }
}
EOF

    # Source state.sh
    # shellcheck source=/dev/null
    source "${TEST_TMPDIR}/Scripts/release/utils/state.sh"

    # Verify initial state
    local initial_status initial_attempt
    initial_status="$(msp_state_get_step_status "publish")"
    initial_attempt=$(jq -r '.steps.publish.attempt' "${TEST_TMPDIR}/.msp-release-state.json")
    assert_equals "failed" "$initial_status" "Initial status should be 'failed'"
    assert_equals "1" "$initial_attempt" "Initial attempt should be 1"

    # Retry: transition to running (attempt 2)
    msp_state_mark_step_running "publish"

    local running_status running_attempt
    running_status="$(msp_state_get_step_status "publish")"
    running_attempt=$(jq -r '.steps.publish.attempt' "${TEST_TMPDIR}/.msp-release-state.json")
    assert_equals "running" "$running_status" "Status should be 'running' after retry"
    assert_equals "2" "$running_attempt" "Attempt should be incremented to 2"

    # Complete successfully
    msp_state_mark_step_success "publish"

    local final_status final_attempt
    final_status="$(msp_state_get_step_status "publish")"
    final_attempt=$(jq -r '.steps.publish.attempt' "${TEST_TMPDIR}/.msp-release-state.json")
    assert_equals "success" "$final_status" "Final status should be 'success'"
    assert_equals "2" "$final_attempt" "Attempt should remain 2"

    info "Retry transition (failed → running → success) works correctly"
}

# ============================================================================
# Test: Multiple steps with different transitions
# ============================================================================

test_multiple_steps_independent_transitions() {
    setup_test_env
    cd "${TEST_TMPDIR}"

    # Create state file with multiple steps
    cat > "${TEST_TMPDIR}/.msp-release-state.json" <<'EOF'
{
  "schema_version": 3,
  "steps": {},
  "last_error": {
    "step": null,
    "message": null,
    "exit_code": null,
    "occurred_at": null
  },
  "timestamps": {
    "started_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:00:00Z"
  }
}
EOF

    # Source state.sh
    # shellcheck source=/dev/null
    source "${TEST_TMPDIR}/Scripts/release/utils/state.sh"

    # Step 1: preflight → running → success
    msp_state_mark_step_running "preflight"
    msp_state_mark_step_success "preflight"

    # Step 2: build → running → failed
    msp_state_mark_step_running "build"
    msp_state_mark_step_failed "build" "Build error" 1

    # Step 3: verify → skipped (never started)
    msp_state_mark_step_skipped "verify" "Skipped due to build failure"

    # Verify all steps have correct status
    local preflight_status build_status verify_status
    preflight_status="$(msp_state_get_step_status "preflight")"
    build_status="$(msp_state_get_step_status "build")"
    verify_status="$(msp_state_get_step_status "verify")"

    assert_equals "success" "$preflight_status" "Preflight should be 'success'"
    assert_equals "failed" "$build_status" "Build should be 'failed'"
    assert_equals "skipped" "$verify_status" "Verify should be 'skipped'"

    # Verify last_error points to build (the failed step)
    local error_step
    error_step=$(jq -r '.last_error.step' "${TEST_TMPDIR}/.msp-release-state.json")
    assert_equals "build" "$error_step" "last_error.step should be 'build'"

    info "Multiple steps with independent transitions work correctly"
}

# ============================================================================
# Test: Pod status transitions
# ============================================================================

test_pod_status_transitions() {
    setup_test_env
    cd "${TEST_TMPDIR}"

    # Create minimal state file
    cat > "${TEST_TMPDIR}/.msp-release-state.json" <<'EOF'
{
  "schema_version": 3,
  "pods": {},
  "steps": {},
  "timestamps": {
    "started_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:00:00Z"
  }
}
EOF

    # Source state.sh
    # shellcheck source=/dev/null
    source "${TEST_TMPDIR}/Scripts/release/utils/state.sh"

    # Initial: no pods
    local initial_status
    initial_status="$(msp_state_get_pod_status "MSPCore")"
    assert_equals "unknown" "$initial_status" "Initial pod status should be 'unknown'"

    # Transition: pending
    msp_state_mark_pod_status "MSPCore" "pending"
    local pending_status
    pending_status="$(msp_state_get_pod_status "MSPCore")"
    assert_equals "pending" "$pending_status" "Pod status should be 'pending'"

    # Transition: failed
    msp_state_mark_pod_status "MSPCore" "failed"
    local failed_status
    failed_status="$(msp_state_get_pod_status "MSPCore")"
    assert_equals "failed" "$failed_status" "Pod status should be 'failed'"

    # Transition: published (retry succeeded)
    msp_state_mark_pod_status "MSPCore" "published"
    local published_status
    published_status="$(msp_state_get_pod_status "MSPCore")"
    assert_equals "published" "$published_status" "Pod status should be 'published'"

    info "Pod status transitions work correctly"
}

# ============================================================================
# Test: Timestamps are updated on each transition
# ============================================================================

test_timestamps_updated_on_transitions() {
    setup_test_env
    cd "${TEST_TMPDIR}"

    # Create state file with old timestamp
    cat > "${TEST_TMPDIR}/.msp-release-state.json" <<'EOF'
{
  "schema_version": 3,
  "steps": {},
  "timestamps": {
    "started_at": "2020-01-01T00:00:00Z",
    "updated_at": "2020-01-01T00:00:00Z"
  }
}
EOF

    # Source state.sh
    # shellcheck source=/dev/null
    source "${TEST_TMPDIR}/Scripts/release/utils/state.sh"

    # Get initial updated_at
    local initial_updated_at
    initial_updated_at=$(jq -r '.timestamps.updated_at' "${TEST_TMPDIR}/.msp-release-state.json")

    # Perform a transition
    msp_state_mark_step_running "test_step"

    # Get new updated_at
    local new_updated_at
    new_updated_at=$(jq -r '.timestamps.updated_at' "${TEST_TMPDIR}/.msp-release-state.json")

    # Verify timestamp was updated (should be newer than 2020)
    assert_not_equals "$initial_updated_at" "$new_updated_at" "updated_at should change after transition"
    assert_contains "$new_updated_at" "202" "New timestamp should be in 202x"

    info "Timestamps are updated on transitions correctly"
}

# ============================================================================
# Run All Tests
# ============================================================================

info "Running state transition tests..."

test_transition_running_to_success
test_transition_running_to_failed
test_transition_pending_to_skipped
test_retry_transition_failed_running_success
test_multiple_steps_independent_transitions
test_pod_status_transitions
test_timestamps_updated_on_transitions

info "All state transition tests passed!"
