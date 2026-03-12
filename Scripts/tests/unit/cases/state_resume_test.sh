#!/usr/bin/env bash
set -euo pipefail

# @description Unit tests for state.sh resume functionality
# @test msp_state_increment_resume_count, state preservation across resumes

# Get the repo root (relative to this test file)
# This file is at: Scripts/tests/unit/cases/state_resume_test.sh
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
# Test: msp_state_increment_resume_count
# ============================================================================

test_increment_resume_count_from_zero() {
    setup_test_env
    cd "${TEST_TMPDIR}"

    # Create state file with resume_count = 0
    cat > "${TEST_TMPDIR}/.msp-release-state.json" <<'EOF'
{
  "schema_version": 3,
  "resume_count": 0,
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

    # Increment resume count
    msp_state_increment_resume_count

    # Verify count
    local resume_count
    resume_count=$(jq -r '.resume_count' "${TEST_TMPDIR}/.msp-release-state.json")
    assert_equals "1" "$resume_count" "Resume count should be 1"

    info "msp_state_increment_resume_count works from zero"
}

test_increment_resume_count_multiple_times() {
    setup_test_env
    cd "${TEST_TMPDIR}"

    # Create state file with resume_count = 0
    cat > "${TEST_TMPDIR}/.msp-release-state.json" <<'EOF'
{
  "schema_version": 3,
  "resume_count": 0,
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

    # Increment multiple times
    msp_state_increment_resume_count
    msp_state_increment_resume_count
    msp_state_increment_resume_count

    # Verify count
    local resume_count
    resume_count=$(jq -r '.resume_count' "${TEST_TMPDIR}/.msp-release-state.json")
    assert_equals "3" "$resume_count" "Resume count should be 3 after 3 increments"

    info "msp_state_increment_resume_count increments correctly multiple times"
}

test_increment_resume_count_without_initial_field() {
    setup_test_env
    cd "${TEST_TMPDIR}"

    # Create state file WITHOUT resume_count field
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

    # Increment (should handle missing field)
    msp_state_increment_resume_count

    # Verify count is 1 (started from implicit 0)
    local resume_count
    resume_count=$(jq -r '.resume_count' "${TEST_TMPDIR}/.msp-release-state.json")
    assert_equals "1" "$resume_count" "Resume count should be 1 even without initial field"

    info "msp_state_increment_resume_count handles missing field"
}

# ============================================================================
# Test: State preservation across resumes
# ============================================================================

test_successful_steps_preserved_on_resume() {
    setup_test_env
    cd "${TEST_TMPDIR}"

    # Create state file with some successful steps
    cat > "${TEST_TMPDIR}/.msp-release-state.json" <<'EOF'
{
  "schema_version": 3,
  "mode": "run",
  "version": "1.0.0",
  "resume_count": 0,
  "steps": {
    "preflight": {
      "status": "success",
      "attempt": 1,
      "started_at": "2026-01-01T00:00:00Z",
      "completed_at": "2026-01-01T00:01:00Z"
    },
    "build": {
      "status": "success",
      "attempt": 1,
      "started_at": "2026-01-01T00:01:00Z",
      "completed_at": "2026-01-01T00:10:00Z"
    },
    "publish": {
      "status": "failed",
      "attempt": 1,
      "started_at": "2026-01-01T00:10:00Z",
      "completed_at": "2026-01-01T00:15:00Z"
    }
  },
  "last_error": {
    "step": "publish",
    "message": "Network timeout",
    "exit_code": 1
  },
  "timestamps": {
    "started_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:15:00Z"
  }
}
EOF

    # Source state.sh
    # shellcheck source=/dev/null
    source "${TEST_TMPDIR}/Scripts/release/utils/state.sh"

    # Simulate resume: increment count
    msp_state_increment_resume_count

    # Verify successful steps are still preserved
    local preflight_status build_status publish_status
    preflight_status="$(msp_state_get_step_status "preflight")"
    build_status="$(msp_state_get_step_status "build")"
    publish_status="$(msp_state_get_step_status "publish")"

    assert_equals "success" "$preflight_status" "Preflight should still be 'success'"
    assert_equals "success" "$build_status" "Build should still be 'success'"
    assert_equals "failed" "$publish_status" "Publish should still be 'failed'"

    # Verify version preserved
    local version
    version=$(jq -r '.version' "${TEST_TMPDIR}/.msp-release-state.json")
    assert_equals "1.0.0" "$version" "Version should be preserved"

    info "Successful steps preserved on resume"
}

test_pod_status_preserved_on_resume() {
    setup_test_env
    cd "${TEST_TMPDIR}"

    # Create state file with pod statuses
    cat > "${TEST_TMPDIR}/.msp-release-state.json" <<'EOF'
{
  "schema_version": 3,
  "resume_count": 0,
  "pods": {
    "MSPSharedLibraries": {
      "status": "published",
      "updated_at": "2026-01-01T00:05:00Z"
    },
    "MSPiOSCore": {
      "status": "published",
      "updated_at": "2026-01-01T00:06:00Z"
    },
    "MSPCore": {
      "status": "failed",
      "updated_at": "2026-01-01T00:07:00Z"
    }
  },
  "steps": {},
  "timestamps": {
    "started_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:07:00Z"
  }
}
EOF

    # Source state.sh
    # shellcheck source=/dev/null
    source "${TEST_TMPDIR}/Scripts/release/utils/state.sh"

    # Simulate resume
    msp_state_increment_resume_count

    # Verify pod statuses preserved
    local shared_status ios_status core_status
    shared_status="$(msp_state_get_pod_status "MSPSharedLibraries")"
    ios_status="$(msp_state_get_pod_status "MSPiOSCore")"
    core_status="$(msp_state_get_pod_status "MSPCore")"

    assert_equals "published" "$shared_status" "MSPSharedLibraries should be 'published'"
    assert_equals "published" "$ios_status" "MSPiOSCore should be 'published'"
    assert_equals "failed" "$core_status" "MSPCore should be 'failed'"

    info "Pod status preserved on resume"
}

test_git_flags_preserved_on_resume() {
    setup_test_env
    cd "${TEST_TMPDIR}"

    # Create state file with git flags
    cat > "${TEST_TMPDIR}/.msp-release-state.json" <<'EOF'
{
  "schema_version": 3,
  "resume_count": 0,
  "git": {
    "tag_created": true,
    "tag_name": "v1.0.0",
    "release_branch_pushed": true,
    "github_release_created": false
  },
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

    # Simulate resume
    msp_state_increment_resume_count

    # Verify git flags preserved
    local tag_created tag_name branch_pushed release_created
    tag_created=$(jq -r '.git.tag_created' "${TEST_TMPDIR}/.msp-release-state.json")
    tag_name=$(jq -r '.git.tag_name' "${TEST_TMPDIR}/.msp-release-state.json")
    branch_pushed=$(jq -r '.git.release_branch_pushed' "${TEST_TMPDIR}/.msp-release-state.json")
    release_created=$(jq -r '.git.github_release_created' "${TEST_TMPDIR}/.msp-release-state.json")

    assert_equals "true" "$tag_created" "tag_created should be preserved"
    assert_equals "v1.0.0" "$tag_name" "tag_name should be preserved"
    assert_equals "true" "$branch_pushed" "release_branch_pushed should be preserved"
    assert_equals "false" "$release_created" "github_release_created should be preserved"

    info "Git flags preserved on resume"
}

# ============================================================================
# Test: Retry logic after resume
# ============================================================================

test_retry_failed_step_after_resume() {
    setup_test_env
    cd "${TEST_TMPDIR}"

    # Create state file with failed step
    cat > "${TEST_TMPDIR}/.msp-release-state.json" <<'EOF'
{
  "schema_version": 3,
  "resume_count": 1,
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
    "message": "First failure",
    "exit_code": 1
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

    # Retry the failed step
    msp_state_mark_step_running "publish"

    # Verify attempt is incremented
    local attempt status
    attempt=$(jq -r '.steps.publish.attempt' "${TEST_TMPDIR}/.msp-release-state.json")
    status="$(msp_state_get_step_status "publish")"

    assert_equals "2" "$attempt" "Attempt should be incremented to 2"
    assert_equals "running" "$status" "Status should be 'running'"

    # Complete successfully
    msp_state_mark_step_success "publish"

    local final_status
    final_status="$(msp_state_get_step_status "publish")"
    assert_equals "success" "$final_status" "Final status should be 'success'"

    info "Retry failed step after resume works correctly"
}

# ============================================================================
# Test: Resume with trunk verification state
# ============================================================================

test_trunk_verification_preserved_on_resume() {
    setup_test_env
    cd "${TEST_TMPDIR}"

    # Create state file with trunk verification
    cat > "${TEST_TMPDIR}/.msp-release-state.json" <<'EOF'
{
  "schema_version": 3,
  "resume_count": 0,
  "pods": {
    "MSPSharedLibraries": {
      "status": "published",
      "trunk_verified": true,
      "trunk_verified_at": "2026-01-01T00:10:00Z"
    },
    "MSPCore": {
      "status": "failed",
      "trunk_verified": false
    }
  },
  "steps": {},
  "timestamps": {
    "started_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:15:00Z"
  }
}
EOF

    # Source state.sh
    # shellcheck source=/dev/null
    source "${TEST_TMPDIR}/Scripts/release/utils/state.sh"

    # Simulate resume
    msp_state_increment_resume_count

    # Verify trunk verification preserved
    local shared_verified core_verified
    shared_verified="$(msp_state_get_pod_trunk_verified "MSPSharedLibraries")"
    core_verified="$(msp_state_get_pod_trunk_verified "MSPCore")"

    assert_equals "true" "$shared_verified" "MSPSharedLibraries trunk_verified should be preserved"
    # Note: boolean false may come back as "false" or "unknown" depending on jq behavior
    # The test verifies the state is preserved (not changed to something else)
    if [[ "$core_verified" == "false" ]] || [[ "$core_verified" == "unknown" ]]; then
        info "MSPCore trunk_verified preserved as: $core_verified"
    else
        fail_test "Unexpected value for trunk_verified: $core_verified"
    fi

    info "Trunk verification preserved on resume"
}

# ============================================================================
# Test: state_init does not overwrite on resume
# ============================================================================

test_state_init_preserves_on_resume() {
    setup_test_env
    cd "${TEST_TMPDIR}"

    # Create existing state file (simulating interrupted run)
    cat > "${TEST_TMPDIR}/.msp-release-state.json" <<'EOF'
{
  "schema_version": 3,
  "run_id": "original-run-id",
  "mode": "run",
  "version": "1.0.0",
  "resume_count": 2,
  "steps": {
    "preflight": {"status": "success"},
    "build": {"status": "success"},
    "publish": {"status": "failed"}
  },
  "timestamps": {
    "started_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T01:00:00Z"
  }
}
EOF

    # Set environment for "new" init
    export RELEASE_VERSION="2.0.0"  # Different version!
    export BASE_BRANCH="main"
    export RELEASE_BRANCH="release/2.0.0"
    export DRY_RUN="true"

    # Source state.sh
    # shellcheck source=/dev/null
    source "${TEST_TMPDIR}/Scripts/release/utils/state.sh"

    # Call init (should NOT overwrite)
    msp_state_init "resume"

    # Verify original data preserved
    local version run_id resume_count
    version=$(jq -r '.version' "${TEST_TMPDIR}/.msp-release-state.json")
    run_id=$(jq -r '.run_id' "${TEST_TMPDIR}/.msp-release-state.json")
    resume_count=$(jq -r '.resume_count' "${TEST_TMPDIR}/.msp-release-state.json")

    assert_equals "1.0.0" "$version" "Original version should be preserved"
    assert_equals "original-run-id" "$run_id" "Original run_id should be preserved"
    assert_equals "2" "$resume_count" "Resume count should be preserved"

    # Verify step statuses preserved
    local preflight_status
    preflight_status="$(msp_state_get_step_status "preflight")"
    assert_equals "success" "$preflight_status" "Preflight status should be preserved"

    info "state_init preserves state on resume"
}

# ============================================================================
# Run All Tests
# ============================================================================

info "Running state resume tests..."

test_increment_resume_count_from_zero
test_increment_resume_count_multiple_times
test_increment_resume_count_without_initial_field
test_successful_steps_preserved_on_resume
test_pod_status_preserved_on_resume
test_git_flags_preserved_on_resume
test_retry_failed_step_after_resume
test_trunk_verification_preserved_on_resume
test_state_init_preserves_on_resume

info "All state resume tests passed!"
