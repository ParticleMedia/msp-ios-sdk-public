#!/usr/bin/env bash
# ============================================================================
# Unit Tests for Scripts/testflight/lib/config.sh
# ============================================================================
# Tests YAML config loading, build number computation, and build number commit.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Source test helpers
source "$HELPERS_DIR/helpers.sh"

# Stub logging functions (avoid sourcing full common.sh which triggers side effects)
log::info()    { :; }
log::error()   { :; }
log::warn()    { :; }
log::success() { :; }
log::debug()   { :; }

# Stub utility functions used by config.sh
ensure_directory() { mkdir -p "$1"; }
safe_remove() { rm -rf "$1"; }

# Exit codes (from common.sh)
EXIT_SUCCESS=0
EXIT_CONFIG_ERROR=6

# Path to module under test
TF_CONFIG_MODULE="$PROJECT_ROOT/Scripts/testflight/lib/config.sh"

# ============================================================================
# Test Setup
# ============================================================================

PASSED=0
FAILED=0

pass() {
    local msg="$1"
    echo -e "${_GREEN:-}✓${_NC:-} $msg"
    PASSED=$((PASSED + 1))
}

fail() {
    local msg="$1"
    echo -e "${_RED:-}✗${_NC:-} $msg"
    FAILED=$((FAILED + 1))
}

# Create a temporary project root with a config file
setup_test_root() {
    local tmpdir
    tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir/Scripts/testflight"
    cat > "$tmpdir/Scripts/testflight/config.yaml" <<'EOF'
schema_version: 1
build_number: 7

app:
  scheme: MSPDemoApp
  workspace: msp-ios-sdk.xcworkspace
  bundle_id: MSPDemoApp.MSPDemoApp
  configuration: Release

signing:
  team_id: 4PEHUZX8QH

testflight:
  skip_waiting: true
  changelog_template: "Build {build_number} - Internal testing"

output:
  archive_path: build/testflight/MSPDemoApp.xcarchive
  export_path: build/testflight/export
  log_path: build/testflight/logs
EOF
    echo "$tmpdir"
}

# Source the module with a given ROOT_DIR, resetting the guard first
source_config_module() {
    unset _TF_CONFIG_SOURCED 2>/dev/null || true
    ROOT_DIR="$1"
    source "$TF_CONFIG_MODULE"
}

# ============================================================================
# Test Cases
# ============================================================================

test_module_guard() {
    local tmpdir
    tmpdir=$(setup_test_root)
    source_config_module "$tmpdir"

    if [[ -n "${_TF_CONFIG_SOURCED:-}" ]]; then
        pass "Module guard variable _TF_CONFIG_SOURCED is set"
    else
        fail "Module guard variable _TF_CONFIG_SOURCED not set"
    fi

    rm -rf "$tmpdir"
}

test_load_config_parses_all_fields() {
    local tmpdir
    tmpdir=$(setup_test_root)
    source_config_module "$tmpdir"

    tf_load_config

    local all_ok=true

    [[ "$TF_SCHEMA_VERSION" == "1" ]]                                   || { fail "schema_version should be '1', got: ${TF_SCHEMA_VERSION:-<empty>}"; all_ok=false; }
    [[ "$TF_BUILD_NUMBER" == "7" ]]                                     || { fail "build_number should be '7', got: ${TF_BUILD_NUMBER:-<empty>}"; all_ok=false; }
    [[ "$TF_SCHEME" == "MSPDemoApp" ]]                                  || { fail "scheme should be 'MSPDemoApp', got: ${TF_SCHEME:-<empty>}"; all_ok=false; }
    [[ "$TF_WORKSPACE" == "msp-ios-sdk.xcworkspace" ]]                  || { fail "workspace wrong, got: ${TF_WORKSPACE:-<empty>}"; all_ok=false; }
    [[ "$TF_BUNDLE_ID" == "MSPDemoApp.MSPDemoApp" ]]                    || { fail "bundle_id wrong, got: ${TF_BUNDLE_ID:-<empty>}"; all_ok=false; }
    [[ "$TF_CONFIGURATION" == "Release" ]]                              || { fail "configuration wrong, got: ${TF_CONFIGURATION:-<empty>}"; all_ok=false; }
    [[ "$TF_TEAM_ID" == "4PEHUZX8QH" ]]                                || { fail "team_id wrong, got: ${TF_TEAM_ID:-<empty>}"; all_ok=false; }
    [[ "$TF_SKIP_WAITING" == "true" ]]                                  || { fail "skip_waiting wrong, got: ${TF_SKIP_WAITING:-<empty>}"; all_ok=false; }
    [[ "$TF_ARCHIVE_PATH" == "build/testflight/MSPDemoApp.xcarchive" ]] || { fail "archive_path wrong, got: ${TF_ARCHIVE_PATH:-<empty>}"; all_ok=false; }
    [[ "$TF_EXPORT_PATH" == "build/testflight/export" ]]                || { fail "export_path wrong, got: ${TF_EXPORT_PATH:-<empty>}"; all_ok=false; }
    [[ "$TF_LOG_PATH" == "build/testflight/logs" ]]                     || { fail "log_path wrong, got: ${TF_LOG_PATH:-<empty>}"; all_ok=false; }

    if [[ "$all_ok" == "true" ]]; then
        pass "All config fields parsed correctly"
    fi

    rm -rf "$tmpdir"
}

test_load_config_missing_file() {
    local tmpdir
    tmpdir=$(mktemp -d)
    source_config_module "$tmpdir"

    local exit_code=0
    tf_load_config || exit_code=$?

    if [[ $exit_code -eq $EXIT_CONFIG_ERROR ]]; then
        pass "Returns EXIT_CONFIG_ERROR when config file missing"
    else
        fail "Should return EXIT_CONFIG_ERROR ($EXIT_CONFIG_ERROR), got: $exit_code"
    fi

    rm -rf "$tmpdir"
}

test_load_config_missing_required_fields() {
    local tmpdir
    tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir/Scripts/testflight"

    # Config with missing required fields
    cat > "$tmpdir/Scripts/testflight/config.yaml" <<'EOF'
schema_version: 1
build_number: 1
EOF

    source_config_module "$tmpdir"

    local exit_code=0
    tf_load_config || exit_code=$?

    if [[ $exit_code -eq $EXIT_CONFIG_ERROR ]]; then
        pass "Returns EXIT_CONFIG_ERROR when required fields missing"
    else
        fail "Should return EXIT_CONFIG_ERROR ($EXIT_CONFIG_ERROR), got: $exit_code"
    fi

    rm -rf "$tmpdir"
}

test_compute_next_build_number_auto_increment() {
    local tmpdir
    tmpdir=$(setup_test_root)
    source_config_module "$tmpdir"

    tf_load_config
    tf_compute_next_build_number ""

    if [[ "$TF_NEXT_BUILD_NUMBER" == "8" ]]; then
        pass "Auto-incremented build number: $TF_NEXT_BUILD_NUMBER (was 7)"
    else
        fail "Next build number should be '8', got: ${TF_NEXT_BUILD_NUMBER:-<empty>}"
    fi

    rm -rf "$tmpdir"
}

test_compute_next_build_number_override() {
    local tmpdir
    tmpdir=$(setup_test_root)
    source_config_module "$tmpdir"

    tf_load_config
    tf_compute_next_build_number "42"

    if [[ "$TF_NEXT_BUILD_NUMBER" == "42" ]]; then
        pass "Override build number: $TF_NEXT_BUILD_NUMBER"
    else
        fail "Override build number should be '42', got: ${TF_NEXT_BUILD_NUMBER:-<empty>}"
    fi

    rm -rf "$tmpdir"
}

test_commit_build_number_updates_yaml() {
    local tmpdir
    tmpdir=$(setup_test_root)

    # Initialize a git repo so git commands work
    git -C "$tmpdir" init -q
    git -C "$tmpdir" add -A
    git -C "$tmpdir" -c user.email="test@test.com" -c user.name="Test" commit -q -m "init"

    source_config_module "$tmpdir"

    tf_load_config
    tf_compute_next_build_number ""
    tf_commit_build_number

    # Verify config.yaml was updated
    local new_value
    new_value=$(grep "^build_number:" "$tmpdir/Scripts/testflight/config.yaml" | awk '{print $2}')

    if [[ "$new_value" == "8" ]]; then
        pass "config.yaml updated with new build number: $new_value"
    else
        fail "config.yaml build_number should be '8', got: ${new_value:-<empty>}"
    fi

    # Verify git commit was made
    local last_msg
    last_msg=$(git -C "$tmpdir" log -1 --format="%s")

    if [[ "$last_msg" == *"bump build number to 8"* ]]; then
        pass "Git commit message correct: $last_msg"
    else
        fail "Git commit message should contain 'bump build number to 8', got: $last_msg"
    fi

    rm -rf "$tmpdir"
}

test_commit_build_number_preserves_yaml_structure() {
    local tmpdir
    tmpdir=$(setup_test_root)

    git -C "$tmpdir" init -q
    git -C "$tmpdir" add -A
    git -C "$tmpdir" -c user.email="test@test.com" -c user.name="Test" commit -q -m "init"

    source_config_module "$tmpdir"

    tf_load_config
    tf_compute_next_build_number ""
    tf_commit_build_number

    # Verify other fields were not corrupted
    local scheme
    scheme=$(grep "scheme:" "$tmpdir/Scripts/testflight/config.yaml" | head -1 | awk '{print $2}')
    if [[ "$scheme" == "MSPDemoApp" ]]; then
        pass "YAML structure preserved after build number update"
    else
        fail "YAML structure corrupted — scheme should be 'MSPDemoApp', got: ${scheme:-<empty>}"
    fi

    rm -rf "$tmpdir"
}

# ============================================================================
# Run Tests
# ============================================================================

echo "Running testflight/lib/config.sh unit tests..."
echo "============================================"

test_module_guard
test_load_config_parses_all_fields
test_load_config_missing_file
test_load_config_missing_required_fields
test_compute_next_build_number_auto_increment
test_compute_next_build_number_override
test_commit_build_number_updates_yaml
test_commit_build_number_preserves_yaml_structure

echo "============================================"
echo "TestFlight config tests: $PASSED passed, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
