#!/usr/bin/env bash
# ============================================================================
# Unit Tests for SDK Version SSOT Functions in Scripts/release/utils/version.sh
# ============================================================================
# Tests the new SSOT (Single Source of Truth) model for SDK versioning:
#   - get_sdk_version_config_path
#   - read_sdk_version_from_config / set_sdk_version_in_config
#   - resolve_effective_sdk_version
#   - update_novacore_config_plist_version (structural test)
#   - update_config_plist_version (structural test)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Source test helpers
source "$HELPERS_DIR/helpers.sh"

# Source required modules
source "$ROOT_DIR/Scripts/lib/common.sh" 2>/dev/null || true
source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true

# Source module under test
source "$ROOT_DIR/Scripts/release/utils/version.sh"

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

VERSION_SH="$ROOT_DIR/Scripts/release/utils/version.sh"

# ============================================================================
# Test: SSOT functions exist
# ============================================================================

test_ssot_functions_exist() {
    local funcs=(get_sdk_version_config_path read_sdk_version_from_config set_sdk_version_in_config resolve_effective_sdk_version)
    for fn in "${funcs[@]}"; do
        if command -v "$fn" &>/dev/null; then
            pass "$fn function exists"
        else
            fail "$fn function should exist"
        fi
    done
}

# ============================================================================
# Test: get_sdk_version_config_path returns correct path
# ============================================================================

test_get_sdk_version_config_path() {
    local path
    path=$(get_sdk_version_config_path)

    if [[ "$path" == *"Scripts/config/sdk_version.conf"* ]]; then
        pass "get_sdk_version_config_path returns path ending in Scripts/config/sdk_version.conf"
    else
        fail "get_sdk_version_config_path should return sdk_version.conf path, got: $path"
    fi
}

# ============================================================================
# Test: read_sdk_version_from_config reads from sdk_version.conf
# ============================================================================

test_read_sdk_version_from_config() {
    # Use real sdk_version.conf
    local version
    version=$(read_sdk_version_from_config 2>/dev/null) || true

    if [[ -n "$version" ]]; then
        pass "read_sdk_version_from_config reads version: $version"
    else
        fail "read_sdk_version_from_config should read a version from sdk_version.conf"
    fi
}

# ============================================================================
# Test: set_sdk_version_in_config writes and read_sdk_version_from_config reads back
# ============================================================================

test_set_and_read_sdk_version() {
    # Use temp dir to avoid modifying real config
    local saved_root="$ROOT_DIR"
    ROOT_DIR="$(mktemp -d)"
    mkdir -p "$ROOT_DIR/Scripts/config"

    set_sdk_version_in_config "9.8.7-test" 2>/dev/null

    local read_back
    read_back=$(read_sdk_version_from_config 2>/dev/null) || true

    if [[ "$read_back" == "9.8.7-test" ]]; then
        pass "set_sdk_version_in_config + read_sdk_version_from_config round-trip works"
    else
        fail "Round-trip should return 9.8.7-test, got: $read_back"
    fi

    # Cleanup
    rm -rf "$ROOT_DIR"
    ROOT_DIR="$saved_root"
}

# ============================================================================
# Test: read_sdk_version_from_config returns 1 when file missing
# ============================================================================

test_read_missing_config_fails() {
    local saved_root="$ROOT_DIR"
    ROOT_DIR="$(mktemp -d)"

    if read_sdk_version_from_config 2>/dev/null; then
        fail "read_sdk_version_from_config should return 1 when config file is missing"
    else
        pass "read_sdk_version_from_config returns 1 when config file is missing"
    fi

    rm -rf "$ROOT_DIR"
    ROOT_DIR="$saved_root"
}

# ============================================================================
# Test: resolve_effective_sdk_version prefers explicit version
# ============================================================================

test_resolve_prefers_explicit_version() {
    local version
    version=$(resolve_effective_sdk_version "1.2.3-explicit" 2>/dev/null)

    if [[ "$version" == "1.2.3-explicit" ]]; then
        pass "resolve_effective_sdk_version returns explicit version when provided"
    else
        fail "resolve_effective_sdk_version should return 1.2.3-explicit, got: $version"
    fi
}

# ============================================================================
# Test: resolve_effective_sdk_version falls back to config
# ============================================================================

test_resolve_falls_back_to_config() {
    local version
    version=$(resolve_effective_sdk_version "" 2>/dev/null) || true

    if [[ -n "$version" ]]; then
        pass "resolve_effective_sdk_version falls back to config: $version"
    else
        fail "resolve_effective_sdk_version should fall back to sdk_version.conf"
    fi
}

# ============================================================================
# Test: resolve_effective_sdk_version fails when no version available
# ============================================================================

test_resolve_fails_when_no_version() {
    local saved_root="$ROOT_DIR"
    ROOT_DIR="$(mktemp -d)"

    if resolve_effective_sdk_version "" 2>/dev/null; then
        fail "resolve_effective_sdk_version should return 1 when no version available"
    else
        pass "resolve_effective_sdk_version returns 1 when no version available"
    fi

    rm -rf "$ROOT_DIR"
    ROOT_DIR="$saved_root"
}

# ============================================================================
# Test: update_novacore_config_plist_version function exists and targets correct path
# ============================================================================

test_update_novacore_function_exists() {
    if command -v update_novacore_config_plist_version &>/dev/null; then
        pass "update_novacore_config_plist_version function exists"
    else
        fail "update_novacore_config_plist_version function should exist"
    fi
}

test_update_novacore_targets_correct_path() {
    if grep -q 'NBResourceBundle.bundle/Config.plist' "$VERSION_SH"; then
        pass "update_novacore_config_plist_version targets NBResourceBundle.bundle/Config.plist"
    else
        fail "update_novacore_config_plist_version should target NBResourceBundle.bundle/Config.plist"
    fi
}

# ============================================================================
# Test: update_config_plist_version targets MSPCore path
# ============================================================================

test_update_mspcore_targets_correct_path() {
    if grep -q 'MSPCore/MSPCore/Resources/Config.plist' "$VERSION_SH"; then
        pass "update_config_plist_version targets MSPCore/Resources/Config.plist"
    else
        fail "update_config_plist_version should target MSPCore/Resources/Config.plist"
    fi
}

# ============================================================================
# Test: update_demo_app_version function exists
# ============================================================================

test_update_demo_app_version_exists() {
    if command -v update_demo_app_version &>/dev/null; then
        pass "update_demo_app_version function exists"
    else
        fail "update_demo_app_version function should exist"
    fi
}

# ============================================================================
# Test: sdk_version.conf file exists and has correct structure
# ============================================================================

test_sdk_version_conf_exists() {
    local conf="$ROOT_DIR/Scripts/config/sdk_version.conf"
    if [[ -f "$conf" ]]; then
        pass "sdk_version.conf exists"
    else
        fail "sdk_version.conf should exist at Scripts/config/sdk_version.conf"
    fi
}

test_sdk_version_conf_has_sdk_version_key() {
    local conf="$ROOT_DIR/Scripts/config/sdk_version.conf"
    if grep -q '^SDK_VERSION=' "$conf"; then
        pass "sdk_version.conf contains SDK_VERSION= key"
    else
        fail "sdk_version.conf should contain SDK_VERSION= key"
    fi
}

# ============================================================================
# Test: all SSOT functions are exported
# ============================================================================

test_ssot_functions_exported() {
    local export_line
    export_line=$(grep '^export -f' "$VERSION_SH")

    local funcs=(get_sdk_version_config_path read_sdk_version_from_config set_sdk_version_in_config resolve_effective_sdk_version update_novacore_config_plist_version update_demo_app_version)
    for fn in "${funcs[@]}"; do
        if echo "$export_line" | grep -q "$fn"; then
            pass "$fn is exported"
        else
            fail "$fn should be in the export -f line"
        fi
    done
}

# ============================================================================
# Run Tests
# ============================================================================

echo "Running SDK version SSOT tests..."
echo "============================================"

test_ssot_functions_exist
test_get_sdk_version_config_path
test_read_sdk_version_from_config
test_set_and_read_sdk_version
test_read_missing_config_fails
test_resolve_prefers_explicit_version
test_resolve_falls_back_to_config
test_resolve_fails_when_no_version
test_update_novacore_function_exists
test_update_novacore_targets_correct_path
test_update_mspcore_targets_correct_path
test_update_demo_app_version_exists
test_sdk_version_conf_exists
test_sdk_version_conf_has_sdk_version_key
test_ssot_functions_exported

echo "============================================"
echo "SDK version SSOT tests: $PASSED passed, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
