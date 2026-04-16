#!/usr/bin/env bash
set -euo pipefail

# @description Unit tests for state.sh schema v4: is_prerelease and cdn_metrics
# @test msp_state_get_is_prerelease, msp_state_set_cdn_metrics, msp_state_get_cdn_metrics, schema_version=4

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../mock_loader.sh"

# ============================================================================
# Test Setup
# ============================================================================

setup_test_env() {
    mock_init
    mkdir -p "${TEST_TMPDIR}/Scripts/release/utils"
    mkdir -p "${TEST_TMPDIR}/Scripts/lib"

    cat > "${TEST_TMPDIR}/Scripts/lib/worktree_guard.sh" <<'EOF'
#!/bin/bash
msp_enforce_main_repo_or_exit() { return 0; }
export -f msp_enforce_main_repo_or_exit
EOF

    mkdir -p "${TEST_TMPDIR}/.git"
    echo "ref: refs/heads/main" > "${TEST_TMPDIR}/.git/HEAD"
    cat > "${TEST_TMPDIR}/.git/config" <<'EOF'
[core]
    repositoryformatversion = 0
EOF

    sed '/^#!\/usr\/bin\/env bash/d; /^# --- MSP Worktree Safety Guard/,/^# --- End MSP Worktree Safety Guard/d' \
        "${REPO_ROOT}/Scripts/release/utils/state.sh" > "${TEST_TMPDIR}/Scripts/release/utils/state.sh"

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
    export RELEASE_VERSION="3.6.8"
    export BASE_BRANCH="main"
    export RELEASE_BRANCH="release/3.6.8"
    export DRY_RUN="true"
}

# ============================================================================
# (a) msp_state_init writes is_prerelease=true when MSP_PRERELEASE=1
# ============================================================================

test_init_writes_is_prerelease_true() {
    setup_test_env
    cd "${TEST_TMPDIR}"
    rm -f "${TEST_TMPDIR}/.msp-release-state.json"

    # shellcheck source=/dev/null
    source "${TEST_TMPDIR}/Scripts/release/utils/state.sh"

    export MSP_PRERELEASE=1
    msp_state_init "run"
    unset MSP_PRERELEASE

    local val
    val=$(jq -r '.is_prerelease' "${TEST_TMPDIR}/.msp-release-state.json" 2>/dev/null || echo "missing")
    assert_equals "true" "$val" "is_prerelease should be true when MSP_PRERELEASE=1"
    info "is_prerelease=true written when MSP_PRERELEASE=1"
}

# ============================================================================
# (a) msp_state_init writes is_prerelease=false when MSP_PRERELEASE unset
# ============================================================================

test_init_writes_is_prerelease_false() {
    setup_test_env
    cd "${TEST_TMPDIR}"
    rm -f "${TEST_TMPDIR}/.msp-release-state.json"

    # shellcheck source=/dev/null
    source "${TEST_TMPDIR}/Scripts/release/utils/state.sh"

    unset MSP_PRERELEASE 2>/dev/null || true
    msp_state_init "run"

    local val
    val=$(jq -r '.is_prerelease' "${TEST_TMPDIR}/.msp-release-state.json" 2>/dev/null || echo "missing")
    assert_equals "false" "$val" "is_prerelease should be false when MSP_PRERELEASE unset"
    info "is_prerelease=false written when MSP_PRERELEASE unset"
}

# ============================================================================
# (b) msp_state_get_is_prerelease round-trips correctly
# ============================================================================

test_get_is_prerelease_returns_true() {
    setup_test_env
    cd "${TEST_TMPDIR}"

    cat > "${TEST_TMPDIR}/.msp-release-state.json" <<'EOF'
{
  "schema_version": 4,
  "is_prerelease": true,
  "cdn_metrics": {"total_checks":0,"success_count":0,"retry_count":0,"failure_count":0,
    "p50_latency_ms":0,"p95_latency_ms":0,"first_check_at":null,"last_check_at":null},
  "timestamps": {"started_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
}
EOF

    # shellcheck source=/dev/null
    source "${TEST_TMPDIR}/Scripts/release/utils/state.sh"

    local result
    result=$(msp_state_get_is_prerelease)
    assert_equals "true" "$result" "get_is_prerelease should return true"
    info "get_is_prerelease returns true correctly"
}

test_get_is_prerelease_returns_false() {
    setup_test_env
    cd "${TEST_TMPDIR}"

    cat > "${TEST_TMPDIR}/.msp-release-state.json" <<'EOF'
{
  "schema_version": 4,
  "is_prerelease": false,
  "timestamps": {"started_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
}
EOF

    # shellcheck source=/dev/null
    source "${TEST_TMPDIR}/Scripts/release/utils/state.sh"

    local result
    result=$(msp_state_get_is_prerelease)
    assert_equals "false" "$result" "get_is_prerelease should return false"
    info "get_is_prerelease returns false correctly"
}

# ============================================================================
# (c) msp_state_set_cdn_metrics / get_cdn_metrics round-trips all 8 sub-fields
# ============================================================================

test_cdn_metrics_roundtrip() {
    setup_test_env
    cd "${TEST_TMPDIR}"

    cat > "${TEST_TMPDIR}/.msp-release-state.json" <<'EOF'
{
  "schema_version": 4,
  "is_prerelease": false,
  "cdn_metrics": {"total_checks":0,"success_count":0,"retry_count":0,"failure_count":0,
    "p50_latency_ms":0,"p95_latency_ms":0,"first_check_at":null,"last_check_at":null},
  "timestamps": {"started_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
}
EOF

    # shellcheck source=/dev/null
    source "${TEST_TMPDIR}/Scripts/release/utils/state.sh"

    local metrics='{"total_checks":42,"success_count":40,"retry_count":5,"failure_count":0,"p50_latency_ms":420,"p95_latency_ms":980,"first_check_at":"2026-04-16T10:30:00Z","last_check_at":"2026-04-16T10:45:12Z"}'
    msp_state_set_cdn_metrics "$metrics"

    local out
    out=$(msp_state_get_cdn_metrics)

    local total success retry fail p50 p95 first last
    total=$(echo "$out" | jq -r '.total_checks')
    success=$(echo "$out" | jq -r '.success_count')
    retry=$(echo "$out" | jq -r '.retry_count')
    fail=$(echo "$out" | jq -r '.failure_count')
    p50=$(echo "$out" | jq -r '.p50_latency_ms')
    p95=$(echo "$out" | jq -r '.p95_latency_ms')
    first=$(echo "$out" | jq -r '.first_check_at')
    last=$(echo "$out" | jq -r '.last_check_at')

    assert_equals "42"  "$total"   "total_checks round-trips"
    assert_equals "40"  "$success" "success_count round-trips"
    assert_equals "5"   "$retry"   "retry_count round-trips"
    assert_equals "0"   "$fail"    "failure_count round-trips"
    assert_equals "420" "$p50"     "p50_latency_ms round-trips"
    assert_equals "980" "$p95"     "p95_latency_ms round-trips"
    assert_equals "2026-04-16T10:30:00Z" "$first" "first_check_at round-trips"
    assert_equals "2026-04-16T10:45:12Z" "$last"  "last_check_at round-trips"
    info "cdn_metrics round-trip: all 8 sub-fields verified"
}

# ============================================================================
# (d) schema_version is 4 in newly-created files
# ============================================================================

test_schema_version_is_4() {
    setup_test_env
    cd "${TEST_TMPDIR}"
    rm -f "${TEST_TMPDIR}/.msp-release-state.json"

    # shellcheck source=/dev/null
    source "${TEST_TMPDIR}/Scripts/release/utils/state.sh"

    unset MSP_PRERELEASE 2>/dev/null || true
    msp_state_init "run"

    local ver
    ver=$(jq -r '.schema_version' "${TEST_TMPDIR}/.msp-release-state.json" 2>/dev/null || echo "missing")
    assert_equals "4" "$ver" "schema_version should be 4 in new files"
    info "schema_version=4 verified"
}

# ============================================================================
# (e) Old v3 state files tolerated: is_prerelease defaults to false,
#     cdn_metrics absence OK
# ============================================================================

test_v3_state_file_tolerated() {
    setup_test_env
    cd "${TEST_TMPDIR}"

    # Write a v3 state file (no is_prerelease, no cdn_metrics)
    cat > "${TEST_TMPDIR}/.msp-release-state.json" <<'EOF'
{
  "schema_version": 3,
  "version": "3.5.0",
  "mode": "run",
  "timestamps": {"started_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
}
EOF

    # shellcheck source=/dev/null
    source "${TEST_TMPDIR}/Scripts/release/utils/state.sh"

    local is_pre
    is_pre=$(msp_state_get_is_prerelease)
    assert_equals "false" "$is_pre" "v3 file: is_prerelease should default to false"

    local metrics
    metrics=$(msp_state_get_cdn_metrics)
    # Should return {} or a JSON object — not an error
    assert_not_equals "" "$metrics" "v3 file: cdn_metrics should return something non-empty"
    info "v3 state file tolerated; defaults verified"
}

# ============================================================================
# Run All Tests
# ============================================================================

info "Running state_is_prerelease tests (schema v4)..."

test_init_writes_is_prerelease_true
test_init_writes_is_prerelease_false
test_get_is_prerelease_returns_true
test_get_is_prerelease_returns_false
test_cdn_metrics_roundtrip
test_schema_version_is_4
test_v3_state_file_tolerated

info "All state_is_prerelease tests passed!"
