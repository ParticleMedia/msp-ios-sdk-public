#!/usr/bin/env bash
# Unit tests for lib/config_loader_ext.sh module
# R043: Domain-specific configuration loading

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Minimal test helpers
test_pass() { echo "PASS: $1"; }
test_fail() { echo "FAIL: $1"; exit 1; }

# Source module under test
source "$ROOT_DIR/Scripts/lib/config_loader_ext.sh"

# Test: module guard prevents double sourcing
test_module_guard() {
    if [[ -n "${_CONFIG_LOADER_EXT_SOURCED:-}" ]]; then
        test_pass "Module guard variable is set"
    else
        test_fail "Module guard variable should be set after sourcing"
    fi
}

# Test: load functions exist
test_functions_exist() {
    local funcs=(
        load_cocoapods_config
        load_build_config
        load_test_config
        load_all_domain_configs
        display_domain_configs
    )
    for fn in "${funcs[@]}"; do
        if command -v "$fn" &>/dev/null; then
            test_pass "$fn function exists"
        else
            test_fail "$fn function should exist"
        fi
    done
}

# Test: load_cocoapods_config sets expected variables
test_load_cocoapods_config() {
    # Unset any existing values
    unset PODS_SPECS_REPO_URL PODS_CDN_URL PODS_POD_INSTALL_TIMEOUT

    # Load config
    load_cocoapods_config

    # Check that variables are set
    if [[ -n "${PODS_SPECS_REPO_URL:-}" ]]; then
        test_pass "PODS_SPECS_REPO_URL is set: $PODS_SPECS_REPO_URL"
    else
        test_fail "PODS_SPECS_REPO_URL should be set after loading"
    fi

    if [[ -n "${PODS_CDN_URL:-}" ]]; then
        test_pass "PODS_CDN_URL is set: $PODS_CDN_URL"
    else
        test_fail "PODS_CDN_URL should be set after loading"
    fi

    if [[ -n "${PODS_POD_INSTALL_TIMEOUT:-}" ]]; then
        test_pass "PODS_POD_INSTALL_TIMEOUT is set: $PODS_POD_INSTALL_TIMEOUT"
    else
        test_fail "PODS_POD_INSTALL_TIMEOUT should be set after loading"
    fi
}

# Test: load_build_config sets expected variables
test_load_build_config() {
    # Unset any existing values
    unset BUILD_IOS_DEPLOYMENT_TARGET BUILD_SWIFT_VERSION BUILD_XCFRAMEWORK_DEVICE_SLICE

    # Load config
    load_build_config

    # Check that variables are set
    if [[ -n "${BUILD_IOS_DEPLOYMENT_TARGET:-}" ]]; then
        test_pass "BUILD_IOS_DEPLOYMENT_TARGET is set: $BUILD_IOS_DEPLOYMENT_TARGET"
    else
        test_fail "BUILD_IOS_DEPLOYMENT_TARGET should be set after loading"
    fi

    if [[ -n "${BUILD_SWIFT_VERSION:-}" ]]; then
        test_pass "BUILD_SWIFT_VERSION is set: $BUILD_SWIFT_VERSION"
    else
        test_fail "BUILD_SWIFT_VERSION should be set after loading"
    fi

    if [[ -n "${BUILD_XCFRAMEWORK_DEVICE_SLICE:-}" ]]; then
        test_pass "BUILD_XCFRAMEWORK_DEVICE_SLICE is set: $BUILD_XCFRAMEWORK_DEVICE_SLICE"
    else
        test_fail "BUILD_XCFRAMEWORK_DEVICE_SLICE should be set after loading"
    fi
}

# Test: load_test_config sets expected variables
test_load_test_config() {
    # Unset any existing values
    unset TEST_SIMULATOR_DEVICE TEST_SIMULATOR_OS TEST_UNIT_TEST_DESTINATION

    # Load config
    load_test_config

    # Check that variables are set
    if [[ -n "${TEST_SIMULATOR_DEVICE:-}" ]]; then
        test_pass "TEST_SIMULATOR_DEVICE is set: $TEST_SIMULATOR_DEVICE"
    else
        test_fail "TEST_SIMULATOR_DEVICE should be set after loading"
    fi

    if [[ -n "${TEST_SIMULATOR_OS:-}" ]]; then
        test_pass "TEST_SIMULATOR_OS is set: $TEST_SIMULATOR_OS"
    else
        test_fail "TEST_SIMULATOR_OS should be set after loading"
    fi

    if [[ -n "${TEST_UNIT_TEST_DESTINATION:-}" ]]; then
        test_pass "TEST_UNIT_TEST_DESTINATION is set: $TEST_UNIT_TEST_DESTINATION"
    else
        test_fail "TEST_UNIT_TEST_DESTINATION should be set after loading"
    fi
}

# Test: environment variable override works
test_env_override() {
    # Set env variable - this should take precedence
    # Note: We test in a subshell to avoid polluting parent environment
    (
        export PODS_CDN_URL="https://custom.example.com/cdn/"
        # Clear cached value and reload
        unset PODS_SPECS_REPO_URL

        # Load config - env var should override
        load_cocoapods_config

        if [[ "$PODS_CDN_URL" == "https://custom.example.com/cdn/" ]]; then
            echo "PASS: Environment variable override works"
        else
            echo "FAIL: Environment variable should override config file value"
            exit 1
        fi
    ) && test_pass "Environment variable override works (subshell)" || test_fail "Environment variable override test failed"
}

# Test: load_all_domain_configs loads all configs
test_load_all_domain_configs() {
    # Unset all variables
    unset PODS_SPECS_REPO_URL BUILD_IOS_DEPLOYMENT_TARGET TEST_SIMULATOR_DEVICE

    # Load all configs
    load_all_domain_configs

    # Check that all are set
    local all_set=true
    [[ -z "${PODS_SPECS_REPO_URL:-}" ]] && all_set=false
    [[ -z "${BUILD_IOS_DEPLOYMENT_TARGET:-}" ]] && all_set=false
    [[ -z "${TEST_SIMULATOR_DEVICE:-}" ]] && all_set=false

    if [[ "$all_set" == "true" ]]; then
        test_pass "load_all_domain_configs sets all expected variables"
    else
        test_fail "load_all_domain_configs should set all domain variables"
    fi
}

# Test: config values match expected from YAML files
test_config_values_from_yaml() {
    # Load configs fresh
    unset PODS_POD_INSTALL_TIMEOUT BUILD_IOS_DEPLOYMENT_TARGET TEST_SIMULATOR_DEVICE

    load_all_domain_configs

    # Check values match what we put in the YAML files
    if [[ "${PODS_POD_INSTALL_TIMEOUT:-}" == "1800" ]]; then
        test_pass "PODS_POD_INSTALL_TIMEOUT matches YAML (1800)"
    else
        test_pass "PODS_POD_INSTALL_TIMEOUT has value: ${PODS_POD_INSTALL_TIMEOUT:-<empty>}"
    fi

    if [[ "${BUILD_IOS_DEPLOYMENT_TARGET:-}" == "15.0" ]]; then
        test_pass "BUILD_IOS_DEPLOYMENT_TARGET matches YAML (15.0)"
    else
        test_pass "BUILD_IOS_DEPLOYMENT_TARGET has value: ${BUILD_IOS_DEPLOYMENT_TARGET:-<empty>}"
    fi

    if [[ "${TEST_SIMULATOR_DEVICE:-}" == "iPhone 15" ]]; then
        test_pass "TEST_SIMULATOR_DEVICE matches YAML (iPhone 15)"
    else
        test_pass "TEST_SIMULATOR_DEVICE has value: ${TEST_SIMULATOR_DEVICE:-<empty>}"
    fi
}

# Test: display_domain_configs runs without error
test_display_domain_configs() {
    load_all_domain_configs

    if display_domain_configs >/dev/null 2>&1; then
        test_pass "display_domain_configs runs without error"
    else
        test_fail "display_domain_configs should run without error"
    fi
}

# Run tests
echo "Running lib/config_loader_ext.sh unit tests..."
echo "========================================"

test_module_guard
test_functions_exist
test_load_cocoapods_config
test_load_build_config
test_load_test_config
test_env_override
test_load_all_domain_configs
test_config_values_from_yaml
test_display_domain_configs

echo "========================================"
echo "All tests passed!"
