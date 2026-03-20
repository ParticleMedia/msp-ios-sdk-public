#!/usr/bin/env bash
# ============================================================================
# Config Loader Extension - Domain-Specific Configuration Loading
# ============================================================================
# R043: Provides functions to load cocoapods-config.yaml, build-config.yaml,
#       and test-config.yaml with environment variable override support.
#
# Usage:
#   source Scripts/lib/config_loader_ext.sh
#   load_cocoapods_config
#   load_build_config
#   load_test_config
#
# Override precedence:
#   1. Environment variables (highest priority)
#   2. Config file values
#   3. Hardcoded defaults (lowest priority)
#
# ============================================================================

# Module Guard
[[ -n "${_CONFIG_LOADER_EXT_SOURCED:-}" ]] && return 0
readonly _CONFIG_LOADER_EXT_SOURCED=1

# NOTE: Do NOT use `set -euo pipefail` here.
# This file is sourced (not executed) by other scripts, so setting shell
# options here would override the caller's error-handling mode — breaking
# post-action scripts that intentionally use `set +e`.

# ============================================================================
# Configuration Paths
# ============================================================================

# Find project root
_find_config_root() {
    if [[ -n "${ROOT_DIR:-}" ]]; then
        echo "$ROOT_DIR"
    elif git rev-parse --show-toplevel &>/dev/null; then
        git rev-parse --show-toplevel
    else
        echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    fi
}

CONFIG_EXT_ROOT="$(_find_config_root)"

# Config file paths
COCOAPODS_CONFIG_FILE="${MSP_COCOAPODS_CONFIG:-$CONFIG_EXT_ROOT/Scripts/config/cocoapods-config.yaml}"
BUILD_CONFIG_FILE="${MSP_BUILD_CONFIG:-$CONFIG_EXT_ROOT/Scripts/config/build-config.yaml}"
TEST_CONFIG_FILE="${MSP_TEST_CONFIG:-$CONFIG_EXT_ROOT/Scripts/config/test-config.yaml}"

# ============================================================================
# Simple YAML Parser (Shared)
# ============================================================================

# @description Parse simple YAML key-value pairs from a file.
#              Handles nested keys, arrays not fully supported.
# @param $1 yaml_file - Path to the YAML file
# @param $2 prefix - Variable name prefix (e.g., "PODS_")
# @return Variable assignments via stdout
_parse_simple_yaml() {
    local yaml_file="$1"
    local prefix="${2:-}"

    if [[ ! -f "$yaml_file" ]]; then
        return 1
    fi

    # Process YAML: remove comments, extract key-value pairs
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # Extract key and value
        if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_-]*)[[:space:]]*:[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Convert hyphens to underscores in key
            key="${key//-/_}"

            # Remove surrounding quotes from value
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"

            # Trim trailing whitespace and comments
            value="${value%%#*}"
            value="${value%"${value##*[![:space:]]}"}"

            echo "${prefix}${key}=\"${value}\""
        fi
    done < "$yaml_file"
}

# @description Get a single value from YAML file
# @param $1 yaml_file - Path to the YAML file
# @param $2 key - Key to extract (supports underscores, will also match hyphens)
# @param $3 default - Default value if key not found
# @return Value via stdout
_get_yaml_value() {
    local yaml_file="$1"
    local key="$2"
    local default="${3:-}"

    if [[ ! -f "$yaml_file" ]]; then
        echo "$default"
        return 0
    fi

    # Try to find the key (convert underscores to hyphens for matching)
    local key_pattern="${key//_/-}"
    local value

    value=$(grep -E "^${key_pattern}[[:space:]]*:" "$yaml_file" 2>/dev/null | head -1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/[[:space:]]*#.*//' | sed 's/^["'"'"']//' | sed 's/["'"'"']$//')

    if [[ -z "$value" ]]; then
        # Try with underscores too
        value=$(grep -E "^${key}[[:space:]]*:" "$yaml_file" 2>/dev/null | head -1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/[[:space:]]*#.*//' | sed 's/^["'"'"']//' | sed 's/["'"'"']$//')
    fi

    if [[ -n "$value" ]]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# ============================================================================
# CocoaPods Configuration (R043a)
# ============================================================================

# Default values for CocoaPods config
readonly PODS_DEFAULT_SPECS_REPO_URL="https://github.com/CocoaPods/Specs.git"
readonly PODS_DEFAULT_CDN_URL="https://cdn.cocoapods.org/"
readonly PODS_DEFAULT_POD_INSTALL_TIMEOUT=1800
readonly PODS_DEFAULT_REPO_UPDATE_TIMEOUT=900
readonly PODS_DEFAULT_SPEC_LINT_TIMEOUT=1800
readonly PODS_DEFAULT_QUICK_LINT_TIMEOUT=600
readonly PODS_DEFAULT_TRUNK_PUSH_TIMEOUT=1800
readonly PODS_DEFAULT_SEARCH_TIMEOUT=600
readonly PODS_DEFAULT_MAX_UPDATE_ATTEMPTS=3
readonly PODS_DEFAULT_RETRY_DELAY=10
readonly PODS_DEFAULT_LOCK_TIMEOUT=60
readonly PODS_DEFAULT_CACHE_TTL=300
readonly PODS_DEFAULT_FAILURE_CACHE_TTL=60
readonly PODS_DEFAULT_CONNECT_TIMEOUT=10

# @description Load CocoaPods configuration from cocoapods-config.yaml
#              Sets global variables: PODS_SPECS_REPO_URL, PODS_CDN_URL, etc.
# @return 0 on success, 1 if config file not found (uses defaults)
load_cocoapods_config() {
    # Specs Repository URLs
    PODS_SPECS_REPO_URL="${PODS_SPECS_REPO_URL:-$(_get_yaml_value "$COCOAPODS_CONFIG_FILE" "specs_repo_url" "$PODS_DEFAULT_SPECS_REPO_URL")}"
    PODS_CDN_URL="${PODS_CDN_URL:-$(_get_yaml_value "$COCOAPODS_CONFIG_FILE" "cdn_url" "$PODS_DEFAULT_CDN_URL")}"

    # Timeouts (seconds)
    PODS_POD_INSTALL_TIMEOUT="${PODS_POD_INSTALL_TIMEOUT:-$(_get_yaml_value "$COCOAPODS_CONFIG_FILE" "pod_install_timeout" "$PODS_DEFAULT_POD_INSTALL_TIMEOUT")}"
    PODS_REPO_UPDATE_TIMEOUT="${PODS_REPO_UPDATE_TIMEOUT:-$(_get_yaml_value "$COCOAPODS_CONFIG_FILE" "repo_update_timeout" "$PODS_DEFAULT_REPO_UPDATE_TIMEOUT")}"
    PODS_SPEC_LINT_TIMEOUT="${PODS_SPEC_LINT_TIMEOUT:-$(_get_yaml_value "$COCOAPODS_CONFIG_FILE" "spec_lint_timeout" "$PODS_DEFAULT_SPEC_LINT_TIMEOUT")}"
    PODS_QUICK_LINT_TIMEOUT="${PODS_QUICK_LINT_TIMEOUT:-$(_get_yaml_value "$COCOAPODS_CONFIG_FILE" "quick_lint_timeout" "$PODS_DEFAULT_QUICK_LINT_TIMEOUT")}"
    PODS_TRUNK_PUSH_TIMEOUT="${PODS_TRUNK_PUSH_TIMEOUT:-$(_get_yaml_value "$COCOAPODS_CONFIG_FILE" "trunk_push_timeout" "$PODS_DEFAULT_TRUNK_PUSH_TIMEOUT")}"
    PODS_SEARCH_TIMEOUT="${PODS_SEARCH_TIMEOUT:-$(_get_yaml_value "$COCOAPODS_CONFIG_FILE" "search_timeout" "$PODS_DEFAULT_SEARCH_TIMEOUT")}"

    # Retry Settings
    PODS_MAX_UPDATE_ATTEMPTS="${PODS_MAX_UPDATE_ATTEMPTS:-$(_get_yaml_value "$COCOAPODS_CONFIG_FILE" "max_update_attempts" "$PODS_DEFAULT_MAX_UPDATE_ATTEMPTS")}"
    PODS_RETRY_DELAY="${PODS_RETRY_DELAY:-$(_get_yaml_value "$COCOAPODS_CONFIG_FILE" "retry_delay" "$PODS_DEFAULT_RETRY_DELAY")}"
    PODS_LOCK_TIMEOUT="${PODS_LOCK_TIMEOUT:-$(_get_yaml_value "$COCOAPODS_CONFIG_FILE" "lock_timeout" "$PODS_DEFAULT_LOCK_TIMEOUT")}"

    # Cache Settings
    PODS_CACHE_TTL="${PODS_CACHE_TTL:-$(_get_yaml_value "$COCOAPODS_CONFIG_FILE" "cache_ttl" "$PODS_DEFAULT_CACHE_TTL")}"
    PODS_FAILURE_CACHE_TTL="${PODS_FAILURE_CACHE_TTL:-$(_get_yaml_value "$COCOAPODS_CONFIG_FILE" "failure_cache_ttl" "$PODS_DEFAULT_FAILURE_CACHE_TTL")}"

    # Network Settings
    PODS_CONNECT_TIMEOUT="${PODS_CONNECT_TIMEOUT:-$(_get_yaml_value "$COCOAPODS_CONFIG_FILE" "connect_timeout" "$PODS_DEFAULT_CONNECT_TIMEOUT")}"

    # Export all variables
    export PODS_SPECS_REPO_URL PODS_CDN_URL
    export PODS_POD_INSTALL_TIMEOUT PODS_REPO_UPDATE_TIMEOUT PODS_SPEC_LINT_TIMEOUT
    export PODS_QUICK_LINT_TIMEOUT PODS_TRUNK_PUSH_TIMEOUT PODS_SEARCH_TIMEOUT
    export PODS_MAX_UPDATE_ATTEMPTS PODS_RETRY_DELAY PODS_LOCK_TIMEOUT
    export PODS_CACHE_TTL PODS_FAILURE_CACHE_TTL PODS_CONNECT_TIMEOUT

    return 0
}

# ============================================================================
# Build Configuration (R043b)
# ============================================================================

# Default values for Build config
readonly BUILD_DEFAULT_IOS_DEPLOYMENT_TARGET="15.0"
readonly BUILD_DEFAULT_SWIFT_VERSION="5.0"
readonly BUILD_DEFAULT_SWIFT_TOOLS_VERSION="5.9"
readonly BUILD_DEFAULT_DEVICE_ARCH="arm64"
readonly BUILD_DEFAULT_SIMULATOR_ARCHS="arm64 x86_64"
readonly BUILD_DEFAULT_XCFRAMEWORK_DEVICE_SLICE="ios-arm64"
readonly BUILD_DEFAULT_XCFRAMEWORK_SIM_SLICE="ios-arm64_x86_64-simulator"
readonly BUILD_DEFAULT_XCFRAMEWORK_BUILD_TIMEOUT=1800
readonly BUILD_DEFAULT_ARCHIVE_TIMEOUT=900

# @description Load build configuration from build-config.yaml
#              Sets global variables: BUILD_IOS_DEPLOYMENT_TARGET, BUILD_SWIFT_VERSION, etc.
# @return 0 on success
load_build_config() {
    # iOS/Swift versions
    BUILD_IOS_DEPLOYMENT_TARGET="${BUILD_IOS_DEPLOYMENT_TARGET:-$(_get_yaml_value "$BUILD_CONFIG_FILE" "ios_deployment_target" "$BUILD_DEFAULT_IOS_DEPLOYMENT_TARGET")}"
    BUILD_SWIFT_VERSION="${BUILD_SWIFT_VERSION:-$(_get_yaml_value "$BUILD_CONFIG_FILE" "swift_version" "$BUILD_DEFAULT_SWIFT_VERSION")}"
    BUILD_SWIFT_TOOLS_VERSION="${BUILD_SWIFT_TOOLS_VERSION:-$(_get_yaml_value "$BUILD_CONFIG_FILE" "swift_tools_version" "$BUILD_DEFAULT_SWIFT_TOOLS_VERSION")}"

    # Architectures (arrays as space-separated strings for shell compatibility)
    BUILD_DEVICE_ARCHITECTURES="${BUILD_DEVICE_ARCHITECTURES:-$BUILD_DEFAULT_DEVICE_ARCH}"
    BUILD_SIMULATOR_ARCHITECTURES="${BUILD_SIMULATOR_ARCHITECTURES:-$BUILD_DEFAULT_SIMULATOR_ARCHS}"

    # XCFramework slice names
    BUILD_XCFRAMEWORK_DEVICE_SLICE="${BUILD_XCFRAMEWORK_DEVICE_SLICE:-$(_get_yaml_value "$BUILD_CONFIG_FILE" "xcframework_slices.device" "$BUILD_DEFAULT_XCFRAMEWORK_DEVICE_SLICE")}"
    BUILD_XCFRAMEWORK_SIM_SLICE="${BUILD_XCFRAMEWORK_SIM_SLICE:-$(_get_yaml_value "$BUILD_CONFIG_FILE" "xcframework_slices.simulator" "$BUILD_DEFAULT_XCFRAMEWORK_SIM_SLICE")}"

    # Fallback: try direct key lookup if nested key didn't work
    if [[ "$BUILD_XCFRAMEWORK_DEVICE_SLICE" == "$BUILD_DEFAULT_XCFRAMEWORK_DEVICE_SLICE" ]]; then
        local value
        value=$(_get_yaml_value "$BUILD_CONFIG_FILE" "device" "")
        [[ -n "$value" ]] && BUILD_XCFRAMEWORK_DEVICE_SLICE="$value"
    fi
    if [[ "$BUILD_XCFRAMEWORK_SIM_SLICE" == "$BUILD_DEFAULT_XCFRAMEWORK_SIM_SLICE" ]]; then
        local value
        value=$(_get_yaml_value "$BUILD_CONFIG_FILE" "simulator" "")
        [[ -n "$value" ]] && BUILD_XCFRAMEWORK_SIM_SLICE="$value"
    fi

    # Build Timeouts
    BUILD_XCFRAMEWORK_BUILD_TIMEOUT="${BUILD_XCFRAMEWORK_BUILD_TIMEOUT:-$(_get_yaml_value "$BUILD_CONFIG_FILE" "xcframework_build_timeout" "$BUILD_DEFAULT_XCFRAMEWORK_BUILD_TIMEOUT")}"
    BUILD_ARCHIVE_TIMEOUT="${BUILD_ARCHIVE_TIMEOUT:-$(_get_yaml_value "$BUILD_CONFIG_FILE" "archive_timeout" "$BUILD_DEFAULT_ARCHIVE_TIMEOUT")}"

    # Export all variables
    export BUILD_IOS_DEPLOYMENT_TARGET BUILD_SWIFT_VERSION BUILD_SWIFT_TOOLS_VERSION
    export BUILD_DEVICE_ARCHITECTURES BUILD_SIMULATOR_ARCHITECTURES
    export BUILD_XCFRAMEWORK_DEVICE_SLICE BUILD_XCFRAMEWORK_SIM_SLICE
    export BUILD_XCFRAMEWORK_BUILD_TIMEOUT BUILD_ARCHIVE_TIMEOUT

    return 0
}

# ============================================================================
# Test Configuration (R043c)
# ============================================================================

# Default values for Test config (used only when auto-detect is unavailable)
readonly TEST_DEFAULT_SIMULATOR_DEVICE="iPhone 15"
readonly TEST_DEFAULT_SIMULATOR_OS="18.0"
readonly TEST_DEFAULT_UNIT_TEST_DESTINATION="platform=iOS Simulator,name=iPhone 15"
readonly TEST_DEFAULT_INTEGRATION_TEST_DESTINATION="platform=iOS Simulator,name=iPhone 15,OS=18.0"
readonly TEST_DEFAULT_UNIT_TEST_TIMEOUT=300
readonly TEST_DEFAULT_INTEGRATION_TEST_TIMEOUT=600

# @description Auto-detect the best available iPhone simulator.
#              Parses `xcrun simctl list` to find the latest iOS version
#              and a suitable iPhone device within it.
# @return Prints "device_name|os_version" on success, returns 1 on failure
_auto_detect_simulator() {
    local current_os="" best_device="" best_os=""
    local pro_device="" pro_os=""
    # Regex stored in variable to avoid bash parsing issues with parentheses
    local iphone_re='^[[:space:]]+(iPhone[^(]+)\('

    while IFS= read -r line; do
        # Match OS section header: "-- iOS 26.1 --"
        if [[ "$line" =~ --\ iOS\ ([0-9]+\.[0-9]+) ]]; then
            current_os="${BASH_REMATCH[1]}"
            # New OS section resets Pro tracking (newer OS always preferred)
            pro_device=""
            pro_os=""
            continue
        fi
        # Match iPhone device line: "    iPhone 17 Pro (UUID) (Shutdown)"
        if [[ -n "$current_os" ]] && [[ "$line" =~ $iphone_re ]]; then
            local name="${BASH_REMATCH[1]}"
            # Trim trailing whitespace
            name="${name%"${name##*[![:space:]]}"}"
            best_device="$name"
            best_os="$current_os"
            # Track Pro (non-Max) as preferred device
            if [[ "$name" == *" Pro" ]]; then
                pro_device="$name"
                pro_os="$current_os"
            fi
        fi
    done < <(xcrun simctl list devices available 2>/dev/null)

    # Prefer Pro model if found in the latest OS
    if [[ -n "$pro_device" && "$pro_os" == "$best_os" ]]; then
        best_device="$pro_device"
    fi

    if [[ -n "$best_device" && -n "$best_os" ]]; then
        echo "${best_device}|${best_os}"
        return 0
    fi
    return 1
}

# @description Load test configuration from test-config.yaml
#              When simulator_device or simulator_os is "auto", auto-detects
#              the best available simulator on the current machine.
#              Sets global variables: TEST_SIMULATOR_DEVICE, TEST_SIMULATOR_OS, etc.
# @return 0 on success
load_test_config() {
    # Simulator settings
    TEST_SIMULATOR_DEVICE="${TEST_SIMULATOR_DEVICE:-$(_get_yaml_value "$TEST_CONFIG_FILE" "simulator_device" "$TEST_DEFAULT_SIMULATOR_DEVICE")}"
    TEST_SIMULATOR_OS="${TEST_SIMULATOR_OS:-$(_get_yaml_value "$TEST_CONFIG_FILE" "simulator_os" "$TEST_DEFAULT_SIMULATOR_OS")}"

    # Auto-detect when configured as "auto"
    if [[ "$TEST_SIMULATOR_DEVICE" == "auto" || "$TEST_SIMULATOR_OS" == "auto" ]]; then
        local detected
        if detected=$(_auto_detect_simulator); then
            local detected_device="${detected%%|*}"
            local detected_os="${detected##*|}"
            if [[ "$TEST_SIMULATOR_DEVICE" == "auto" ]]; then
                TEST_SIMULATOR_DEVICE="$detected_device"
            fi
            if [[ "$TEST_SIMULATOR_OS" == "auto" ]]; then
                TEST_SIMULATOR_OS="$detected_os"
            fi
        fi
    fi

    # Test destinations (constructed from simulator settings if not in config)
    TEST_UNIT_TEST_DESTINATION="${TEST_UNIT_TEST_DESTINATION:-$(_get_yaml_value "$TEST_CONFIG_FILE" "destinations.unit_test" "")}"
    if [[ -z "$TEST_UNIT_TEST_DESTINATION" || "$TEST_UNIT_TEST_DESTINATION" == *"auto"* ]]; then
        TEST_UNIT_TEST_DESTINATION="platform=iOS Simulator,name=$TEST_SIMULATOR_DEVICE"
    fi

    TEST_INTEGRATION_TEST_DESTINATION="${TEST_INTEGRATION_TEST_DESTINATION:-$(_get_yaml_value "$TEST_CONFIG_FILE" "destinations.integration_test" "")}"
    if [[ -z "$TEST_INTEGRATION_TEST_DESTINATION" || "$TEST_INTEGRATION_TEST_DESTINATION" == *"auto"* ]]; then
        TEST_INTEGRATION_TEST_DESTINATION="platform=iOS Simulator,name=$TEST_SIMULATOR_DEVICE,OS=$TEST_SIMULATOR_OS"
    fi

    # Test timeouts
    TEST_UNIT_TEST_TIMEOUT="${TEST_UNIT_TEST_TIMEOUT:-$(_get_yaml_value "$TEST_CONFIG_FILE" "unit_test_timeout" "$TEST_DEFAULT_UNIT_TEST_TIMEOUT")}"
    TEST_INTEGRATION_TEST_TIMEOUT="${TEST_INTEGRATION_TEST_TIMEOUT:-$(_get_yaml_value "$TEST_CONFIG_FILE" "integration_test_timeout" "$TEST_DEFAULT_INTEGRATION_TEST_TIMEOUT")}"

    # Export all variables
    export TEST_SIMULATOR_DEVICE TEST_SIMULATOR_OS
    export TEST_UNIT_TEST_DESTINATION TEST_INTEGRATION_TEST_DESTINATION
    export TEST_UNIT_TEST_TIMEOUT TEST_INTEGRATION_TEST_TIMEOUT

    return 0
}

# ============================================================================
# Convenience Functions (R043d)
# ============================================================================

# @description Load all domain-specific configurations at once
# @return 0 on success
load_all_domain_configs() {
    load_cocoapods_config
    load_build_config
    load_test_config
    return 0
}

# @description Display all loaded configuration values (for debugging)
display_domain_configs() {
    echo "=== CocoaPods Configuration ==="
    echo "  PODS_SPECS_REPO_URL: ${PODS_SPECS_REPO_URL:-<not loaded>}"
    echo "  PODS_CDN_URL: ${PODS_CDN_URL:-<not loaded>}"
    echo "  PODS_POD_INSTALL_TIMEOUT: ${PODS_POD_INSTALL_TIMEOUT:-<not loaded>}s"
    echo "  PODS_SPEC_LINT_TIMEOUT: ${PODS_SPEC_LINT_TIMEOUT:-<not loaded>}s"
    echo "  PODS_MAX_UPDATE_ATTEMPTS: ${PODS_MAX_UPDATE_ATTEMPTS:-<not loaded>}"
    echo ""
    echo "=== Build Configuration ==="
    echo "  BUILD_IOS_DEPLOYMENT_TARGET: ${BUILD_IOS_DEPLOYMENT_TARGET:-<not loaded>}"
    echo "  BUILD_SWIFT_VERSION: ${BUILD_SWIFT_VERSION:-<not loaded>}"
    echo "  BUILD_SWIFT_TOOLS_VERSION: ${BUILD_SWIFT_TOOLS_VERSION:-<not loaded>}"
    echo "  BUILD_DEVICE_ARCHITECTURES: ${BUILD_DEVICE_ARCHITECTURES:-<not loaded>}"
    echo "  BUILD_SIMULATOR_ARCHITECTURES: ${BUILD_SIMULATOR_ARCHITECTURES:-<not loaded>}"
    echo "  BUILD_XCFRAMEWORK_DEVICE_SLICE: ${BUILD_XCFRAMEWORK_DEVICE_SLICE:-<not loaded>}"
    echo "  BUILD_XCFRAMEWORK_SIM_SLICE: ${BUILD_XCFRAMEWORK_SIM_SLICE:-<not loaded>}"
    echo ""
    echo "=== Test Configuration ==="
    echo "  TEST_SIMULATOR_DEVICE: ${TEST_SIMULATOR_DEVICE:-<not loaded>}"
    echo "  TEST_SIMULATOR_OS: ${TEST_SIMULATOR_OS:-<not loaded>}"
    echo "  TEST_UNIT_TEST_DESTINATION: ${TEST_UNIT_TEST_DESTINATION:-<not loaded>}"
    echo "  TEST_UNIT_TEST_TIMEOUT: ${TEST_UNIT_TEST_TIMEOUT:-<not loaded>}s"
}
