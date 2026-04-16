#!/usr/bin/env bash
set -euo pipefail

# @description Unit tests for safety.sh msp_safety_require_changelog auto-gen behavior
# @test 6 cases per contracts/release_md_autogen.md

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../mock_loader.sh"

SAFETY_SH="${REPO_ROOT}/Scripts/release/utils/safety.sh"

# ============================================================================
# Setup
# ============================================================================

setup_safety_env() {
    mock_init
    mkdir -p "${TEST_TMPDIR}/Scripts/release/utils"
    mkdir -p "${TEST_TMPDIR}/Scripts/lib"
    mkdir -p "${TEST_TMPDIR}/.git"
    echo "ref: refs/heads/main" > "${TEST_TMPDIR}/.git/HEAD"
    cat > "${TEST_TMPDIR}/.git/config" <<'EOF'
[core]
    repositoryformatversion = 0
EOF
    # Set git user.name for autogen placeholder
    git -C "${TEST_TMPDIR}" config user.name "Test User" 2>/dev/null || true

    # Stub validation.sh dependency
    cat > "${TEST_TMPDIR}/Scripts/lib/validation.sh" <<'EOF'
#!/bin/bash
validate_release_branch() { return 0; }
export -f validate_release_branch
EOF

    # Stub logger functions in current shell (safety.sh calls these directly)
    log::debug()   { true; }
    log::info()    { true; }
    log::warn()    { echo "[SAFETY] ${2:-}" >&2; }
    log::error()   { echo "[SAFETY] ${2:-}" >&2; }
    log::success() { true; }
    log::step()    { true; }
    export -f log::debug log::info log::warn log::error log::success log::step

    export _SHARED_LOGGER_SOURCED=1

    export ROOT_DIR="${TEST_TMPDIR}"
    export MSP_STATE_DISABLE="1"
    export RELEASE_VERSION="3.6.8"
    unset MSP_PRERELEASE 2>/dev/null || true
    unset MSP_RESUME_MODE 2>/dev/null || true
    unset DRY_RUN 2>/dev/null || true
    unset CI 2>/dev/null || true
    unset GITHUB_ACTIONS 2>/dev/null || true
}

source_safety() {
    unset _MSP_SAFETY_SOURCED 2>/dev/null || true
    # shellcheck source=/dev/null
    source "${SAFETY_SH}"
}

# ============================================================================
# Case 1: file absent, CI=true → exit 1, no file generated
# ============================================================================

test_absent_ci_fails() {
    setup_safety_env
    cd "${TEST_TMPDIR}"
    rm -f "${TEST_TMPDIR}/release.md"

    source_safety

    export CI=true
    export DRY_RUN=false

    local exit_code=0
    msp_safety_require_changelog || exit_code=$?
    assert_not_equals "0" "$exit_code" "CI + absent release.md should fail"
    assert_file_not_exists "${TEST_TMPDIR}/release.md" "No release.md should be generated in CI"
    unset CI DRY_RUN
    info "Case 1: absent+CI → fail verified"
}

# ============================================================================
# Case 2: file absent, CI=false → exit 0, file generated with valid content
# ============================================================================

test_absent_non_ci_autogenerates() {
    setup_safety_env
    cd "${TEST_TMPDIR}"
    rm -f "${TEST_TMPDIR}/release.md"

    source_safety

    unset CI 2>/dev/null || true
    export DRY_RUN=false

    local exit_code=0
    local warn_output
    warn_output=$(msp_safety_require_changelog 2>&1) || exit_code=$?

    assert_equals "0" "$exit_code" "non-CI + absent release.md should succeed (autogen)"
    assert_file_exists "${TEST_TMPDIR}/release.md" "release.md should be auto-generated"

    # File must contain ## Changes
    if ! grep -q "## Changes" "${TEST_TMPDIR}/release.md"; then
        fail_test "Generated release.md missing ## Changes section"
    fi

    # WARN log should be emitted
    assert_contains "$warn_output" "release.md" "WARN log should mention release.md"
    unset DRY_RUN
    info "Case 2: absent+non-CI → autogen+continue verified"
}

# ============================================================================
# Case 3: file present with valid ## Changes → exit 0, file unchanged
# ============================================================================

test_present_valid_unchanged() {
    setup_safety_env
    cd "${TEST_TMPDIR}"

    cat > "${TEST_TMPDIR}/release.md" <<'EOF'
# Release 3.6.8

## Changes

- Fixed the important bug

## End
EOF

    local original_mtime
    original_mtime=$(stat -f "%m" "${TEST_TMPDIR}/release.md" 2>/dev/null \
        || stat -c "%Y" "${TEST_TMPDIR}/release.md" 2>/dev/null)

    source_safety

    unset CI 2>/dev/null || true
    export DRY_RUN=false

    msp_safety_require_changelog
    local exit_code=$?
    assert_equals "0" "$exit_code" "Valid release.md should pass"

    local current_mtime
    current_mtime=$(stat -f "%m" "${TEST_TMPDIR}/release.md" 2>/dev/null \
        || stat -c "%Y" "${TEST_TMPDIR}/release.md" 2>/dev/null)
    assert_equals "$original_mtime" "$current_mtime" "Existing release.md should not be modified"
    unset DRY_RUN
    info "Case 3: present+valid → unchanged+pass verified"
}

# ============================================================================
# Case 4: file present but empty ## Changes → exit 1
# ============================================================================

test_present_empty_changes_fails() {
    setup_safety_env
    cd "${TEST_TMPDIR}"

    cat > "${TEST_TMPDIR}/release.md" <<'EOF'
# Release 3.6.8

## Changes

## End
EOF

    source_safety

    unset CI 2>/dev/null || true
    export DRY_RUN=false

    local exit_code=0
    msp_safety_require_changelog || exit_code=$?
    assert_not_equals "0" "$exit_code" "Empty ## Changes should fail"
    unset DRY_RUN
    info "Case 4: present+empty → fail verified"
}

# ============================================================================
# Case 5: file absent, DRY_RUN=true → exit 0, no file generated
# ============================================================================

test_absent_dry_run_skips() {
    setup_safety_env
    cd "${TEST_TMPDIR}"
    rm -f "${TEST_TMPDIR}/release.md"

    source_safety

    unset CI 2>/dev/null || true
    export DRY_RUN=true

    msp_safety_require_changelog
    local exit_code=$?
    assert_equals "0" "$exit_code" "DRY_RUN should skip changelog check"
    assert_file_not_exists "${TEST_TMPDIR}/release.md" "No release.md generated in DRY_RUN"
    unset DRY_RUN
    info "Case 5: absent+DRY_RUN → skip verified"
}

# ============================================================================
# Case 6: file absent, MSP_RESUME_MODE=1 → exit 0, no file generated
# ============================================================================

test_absent_resume_mode_skips() {
    setup_safety_env
    cd "${TEST_TMPDIR}"
    rm -f "${TEST_TMPDIR}/release.md"

    source_safety

    unset CI 2>/dev/null || true
    export DRY_RUN=false
    export MSP_RESUME_MODE=1

    msp_safety_require_changelog
    local exit_code=$?
    assert_equals "0" "$exit_code" "RESUME_MODE should skip changelog check"
    assert_file_not_exists "${TEST_TMPDIR}/release.md" "No release.md generated in RESUME_MODE"
    unset DRY_RUN MSP_RESUME_MODE
    info "Case 6: absent+MSP_RESUME_MODE → skip verified"
}

# ============================================================================
# Run All Tests
# ============================================================================

info "Running safety_release_md_autogen tests..."

test_absent_ci_fails
test_absent_non_ci_autogenerates
test_present_valid_unchanged
test_present_empty_changes_fails
test_absent_dry_run_skips
test_absent_resume_mode_skips

info "All safety_release_md_autogen tests passed!"
