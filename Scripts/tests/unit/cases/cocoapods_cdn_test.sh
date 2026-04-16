#!/usr/bin/env bash
set -euo pipefail

# @description Unit tests for cocoapods_cdn.sh — CDN shard computation, URL build,
#              availability check (exit codes), metrics recording, module guard.
# @test cocoapods_cdn_compute_shard, cocoapods_cdn_build_url, cocoapods_cdn_check_pod_available,
#       cocoapods_cdn_metrics_init/record/flush, module guard

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../mock_loader.sh"

CDN_MODULE="${REPO_ROOT}/Scripts/lib/shared/cocoapods_cdn.sh"
STATE_SH="${REPO_ROOT}/Scripts/release/utils/state.sh"

# ============================================================================
# Setup
# ============================================================================

setup_cdn_env() {
    mock_init
    mkdir -p "${TEST_TMPDIR}/Scripts/lib"
    mkdir -p "${TEST_TMPDIR}/Scripts/release/utils"
    mkdir -p "${TEST_TMPDIR}/.git"
    echo "ref: refs/heads/main" > "${TEST_TMPDIR}/.git/HEAD"

    # No-op worktree guard
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
    export RELEASE_VERSION="3.6.8"
    export DRY_RUN="true"

    # Reset module guard so we can re-source
    unset _SHARED_COCOAPODS_CDN_SOURCED 2>/dev/null || true
}

source_cdn_module() {
    unset _SHARED_COCOAPODS_CDN_SOURCED 2>/dev/null || true
    # shellcheck source=/dev/null
    source "${CDN_MODULE}"
}

# ============================================================================
# test_module_guard: _SHARED_COCOAPODS_CDN_SOURCED
# ============================================================================

test_module_guard() {
    setup_cdn_env
    source_cdn_module

    local guard_val
    guard_val="${_SHARED_COCOAPODS_CDN_SOURCED:-unset}"
    assert_equals "1" "$guard_val" "Module guard _SHARED_COCOAPODS_CDN_SOURCED should be 1 after sourcing"

    # Source again — should no-op (not cause errors)
    source_cdn_module
    info "Module guard _SHARED_COCOAPODS_CDN_SOURCED verified"
}

# ============================================================================
# test_shard_computation: MSPCore→9/c/4, AFNetworking→a/7/5, MSPSharedLibraries→7/3/3
# ============================================================================

test_shard_computation() {
    setup_cdn_env
    source_cdn_module

    local s1 s2 s3
    s1=$(cocoapods_cdn_compute_shard "MSPCore")
    s2=$(cocoapods_cdn_compute_shard "AFNetworking")
    s3=$(cocoapods_cdn_compute_shard "MSPSharedLibraries")

    assert_equals "9/c/4" "$s1" "MSPCore shard should be 9/c/4"
    assert_equals "a/7/5" "$s2" "AFNetworking shard should be a/7/5"
    assert_equals "7/3/3" "$s3" "MSPSharedLibraries shard should be 7/3/3"
    info "Shard computation verified for MSPCore, AFNetworking, MSPSharedLibraries"
}

# ============================================================================
# test_url_construction
# ============================================================================

test_url_construction() {
    setup_cdn_env
    source_cdn_module

    local url
    url=$(cocoapods_cdn_build_url "MSPCore" "3.6.8")
    assert_equals \
        "https://cdn.cocoapods.org/Specs/9/c/4/MSPCore/3.6.8/MSPCore.podspec.json" \
        "$url" \
        "URL for MSPCore 3.6.8 should match expected pattern"
    info "URL construction verified"
}

# ============================================================================
# test_available_200: stub curl returns 200 → exit 0
# ============================================================================

test_available_200() {
    setup_cdn_env
    source_cdn_module

    # CDN_CURL_CMD override: always return 200
    CDN_CURL_CMD="echo 200"
    export CDN_CURL_CMD

    cocoapods_cdn_check_pod_available "MSPCore" "3.6.8"
    local exit_code=$?
    assert_equals "0" "$exit_code" "HTTP 200 → exit 0 (available)"
    unset CDN_CURL_CMD
    info "HTTP 200 → exit 0 verified"
}

# ============================================================================
# test_not_yet_404: stub returns 404 → exit 2
# ============================================================================

test_not_yet_404() {
    setup_cdn_env
    source_cdn_module

    CDN_CURL_CMD="echo 404"
    export CDN_CURL_CMD

    local exit_code=0
    cocoapods_cdn_check_pod_available "MSPCore" "3.6.8" || exit_code=$?
    assert_equals "2" "$exit_code" "HTTP 404 → exit 2 (not yet available)"
    unset CDN_CURL_CMD
    info "HTTP 404 → exit 2 verified"
}

# ============================================================================
# test_unreachable_5xx: stub returns 503 all 3 retries → exit 3
# ============================================================================

test_unreachable_5xx() {
    setup_cdn_env
    source_cdn_module

    CDN_CURL_CMD="echo 503"
    export CDN_CURL_CMD

    local exit_code=0
    cocoapods_cdn_check_pod_available "MSPCore" "3.6.8" || exit_code=$?
    assert_equals "3" "$exit_code" "HTTP 503 all retries → exit 3 (unreachable)"
    unset CDN_CURL_CMD
    info "HTTP 503 all retries → exit 3 verified"
}

# ============================================================================
# test_timeout: stub curl exits 28 → exit 3
# ============================================================================

test_timeout() {
    setup_cdn_env
    source_cdn_module

    # Simulate curl timeout (exit 28, no output to stdout)
    local stub_script="${TEST_TMPDIR}/fake_curl_timeout.sh"
    cat > "$stub_script" <<'EOF'
#!/bin/bash
exit 28
EOF
    chmod +x "$stub_script"

    CDN_CURL_CMD="$stub_script"
    export CDN_CURL_CMD

    local exit_code=0
    cocoapods_cdn_check_pod_available "MSPCore" "3.6.8" || exit_code=$?
    assert_equals "3" "$exit_code" "curl exit 28 (timeout) → exit 3 (unreachable)"
    unset CDN_CURL_CMD
    info "curl timeout (exit 28) → exit 3 verified"
}

# ============================================================================
# test_metrics_record + test_metrics_flush: verify state file write via jq
# ============================================================================

test_metrics_record_and_flush() {
    setup_cdn_env
    cd "${TEST_TMPDIR}"

    # Initialize state file
    # shellcheck source=/dev/null
    source "${TEST_TMPDIR}/Scripts/release/utils/state.sh"
    unset MSP_PRERELEASE 2>/dev/null || true
    msp_state_init "run"

    source_cdn_module

    # Record some check results (200 = success, 503 = fail with retry)
    cocoapods_cdn_metrics_init
    cocoapods_cdn_metrics_record 200 412
    cocoapods_cdn_metrics_record 200 380
    cocoapods_cdn_metrics_record 503 10023

    # Flush to state file
    cocoapods_cdn_metrics_flush_to_state

    # Read back and verify
    local total success fail retry
    total=$(jq -r '.cdn_metrics.total_checks' "${TEST_TMPDIR}/.msp-release-state.json")
    success=$(jq -r '.cdn_metrics.success_count' "${TEST_TMPDIR}/.msp-release-state.json")
    fail=$(jq -r '.cdn_metrics.failure_count' "${TEST_TMPDIR}/.msp-release-state.json")

    assert_equals "3" "$total" "total_checks should be 3 after 3 records"
    assert_equals "2" "$success" "success_count should be 2 (two 200s)"
    assert_equals "1" "$fail" "failure_count should be 1 (one 503)"
    info "cdn_metrics record+flush verified"
}

# ============================================================================
# Run All Tests
# ============================================================================

info "Running cocoapods_cdn tests..."

test_module_guard
test_shard_computation
test_url_construction
test_available_200
test_not_yet_404
test_unreachable_5xx
test_timeout
test_metrics_record_and_flush

info "All cocoapods_cdn tests passed!"
