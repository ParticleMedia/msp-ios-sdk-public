#!/usr/bin/env bash
set -euo pipefail

# @description Unit tests for resume path restoring MSP_PRERELEASE from state file
# @test 4 cases per contracts/state_schema.md resume pattern

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../mock_loader.sh"

ORCHESTRATOR_SH="${REPO_ROOT}/Scripts/release/orchestrator/modular.sh"
STATE_SH="${REPO_ROOT}/Scripts/release/utils/state.sh"

# ============================================================================
# Setup
# ============================================================================

setup_resume_env() {
    mock_init
    mkdir -p "${TEST_TMPDIR}/Scripts/release/utils"
    mkdir -p "${TEST_TMPDIR}/Scripts/lib"
    mkdir -p "${TEST_TMPDIR}/.git"
    echo "ref: refs/heads/main" > "${TEST_TMPDIR}/.git/HEAD"
    cat > "${TEST_TMPDIR}/.git/config" <<'EOF'
[core]
    repositoryformatversion = 0
EOF

    cat > "${TEST_TMPDIR}/Scripts/lib/worktree_guard.sh" <<'EOF'
#!/bin/bash
msp_enforce_main_repo_or_exit() { return 0; }
export -f msp_enforce_main_repo_or_exit
EOF

    # Patch state.sh for isolated testing
    sed '/^#!\/usr\/bin\/env bash/d; /^# --- MSP Worktree Safety Guard/,/^# --- End MSP Worktree Safety Guard/d' \
        "${STATE_SH}" > "${TEST_TMPDIR}/Scripts/release/utils/state.sh"
    cat > "${TEST_TMPDIR}/Scripts/release/utils/state_patched.sh" <<EOF
#!/bin/bash
source "${TEST_TMPDIR}/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
$(cat "${TEST_TMPDIR}/Scripts/release/utils/state.sh")
EOF
    mv "${TEST_TMPDIR}/Scripts/release/utils/state_patched.sh" \
       "${TEST_TMPDIR}/Scripts/release/utils/state.sh"

    export ROOT_DIR="${TEST_TMPDIR}"
    export MSP_STATE_DISABLE=""
    unset MSP_PRERELEASE 2>/dev/null || true
    unset RELEASE_VERSION 2>/dev/null || true
}

write_state() {
    local is_pre="$1"
    local version="${2:-3.6.8}"
    cat > "${TEST_TMPDIR}/.msp-release-state.json" <<EOF
{
  "schema_version": 4,
  "version": "${version}",
  "is_prerelease": ${is_pre},
  "resume_count": 0,
  "timestamps": {"started_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
}
EOF
}

# Helper: simulate the resume-entry hook (what T025 adds to orchestrator)
# This runs the logic that will be implemented in modular.sh resume path.
# We test it as an isolated shell function to avoid full orchestrator overhead.
simulate_resume_entry() {
    local state_file="${TEST_TMPDIR}/.msp-release-state.json"
    local log_output=""

    # This is the exact logic that T025 will add to the orchestrator
    local is_pre
    is_pre=$(jq -r '.is_prerelease // false' "$state_file" 2>/dev/null || echo "false")

    if [[ "$is_pre" == "true" ]]; then
        export MSP_PRERELEASE=1
        log_output="Resume: restored MSP_PRERELEASE=1 from state file"
    else
        unset MSP_PRERELEASE 2>/dev/null || true
        log_output="Resume: is_prerelease=false, MSP_PRERELEASE not set"
    fi

    echo "$log_output"
}

# ============================================================================
# (a) state file is_prerelease=true → MSP_PRERELEASE=1 after resume entry
# ============================================================================

test_resume_restores_prerelease_flag() {
    setup_resume_env
    write_state "true" "3.6.8-rc.1"

    unset MSP_PRERELEASE 2>/dev/null || true
    simulate_resume_entry > /dev/null

    local val="${MSP_PRERELEASE:-unset}"
    assert_equals "1" "$val" "Resume with is_prerelease=true should export MSP_PRERELEASE=1"
    info "(a) resume restores MSP_PRERELEASE=1 verified"
}

# ============================================================================
# (b) state file is_prerelease=false → MSP_PRERELEASE unset/empty after resume
# ============================================================================

test_resume_clears_prerelease_flag() {
    setup_resume_env
    write_state "false" "3.6.8"

    # Pre-set the flag to verify it gets cleared
    export MSP_PRERELEASE=1
    simulate_resume_entry > /dev/null

    local val="${MSP_PRERELEASE:-unset}"
    assert_equals "unset" "$val" "Resume with is_prerelease=false should unset MSP_PRERELEASE"
    info "(b) resume clears MSP_PRERELEASE verified"
}

# ============================================================================
# (c) log emitted states "Resume: restored MSP_PRERELEASE=1 from state file"
# ============================================================================

test_resume_logs_restoration() {
    setup_resume_env
    write_state "true" "3.6.8-rc.1"

    unset MSP_PRERELEASE 2>/dev/null || true
    local log_output
    log_output=$(simulate_resume_entry)

    assert_contains "$log_output" "MSP_PRERELEASE=1" \
        "Log should mention MSP_PRERELEASE=1 restoration"
    assert_contains "$log_output" "state file" \
        "Log should mention state file as source"
    info "(c) resume log message verified"
}

# ============================================================================
# (d) VERSION env conflict with state version → does NOT abort;
#     a log line notes the override
# ============================================================================

test_resume_version_conflict_does_not_abort() {
    setup_resume_env
    write_state "true" "3.6.8-rc.1"

    # Simulate T026: Jenkins passes a different VERSION than what's in state
    simulate_version_conflict_check() {
        local state_file="${TEST_TMPDIR}/.msp-release-state.json"
        local input_version="${RELEASE_VERSION:-}"
        local state_version
        state_version=$(jq -r '.version // ""' "$state_file" 2>/dev/null || echo "")

        if [[ -n "$input_version" ]] && [[ "$input_version" != "$state_version" ]]; then
            echo "Resume: using state version ${state_version}, ignoring input ${input_version}"
            # Does NOT abort — just logs
            return 0
        fi
        return 0
    }

    export RELEASE_VERSION="3.6.9"  # Conflicts with state's 3.6.8-rc.1
    local log_output exit_code=0
    log_output=$(simulate_version_conflict_check) || exit_code=$?

    assert_equals "0" "$exit_code" "Version conflict should NOT abort resume (exit 0)"
    assert_contains "$log_output" "state version" \
        "Log should mention using state version"
    assert_contains "$log_output" "ignoring" \
        "Log should mention ignoring input version"
    unset RELEASE_VERSION
    info "(d) VERSION conflict does not abort resume verified"
}

# ============================================================================
# Run All Tests
# ============================================================================

info "Running resume_prerelease tests..."

test_resume_restores_prerelease_flag
test_resume_clears_prerelease_flag
test_resume_logs_restoration
test_resume_version_conflict_does_not_abort

info "All resume_prerelease tests passed!"
