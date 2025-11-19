#!/usr/bin/env bash
# Wrapper package configuration for MSP iOS SDK build system
# Centralized definitions for all wrapper packages
# Compatible with bash 3.2+ (uses case statements instead of associative arrays)

# Wrapper package names
declare -a WRAPPER_NAMES=(
    "ShimmerWrapper"
    "FBAudienceNetworkWrapper"
    "IronSourceSDKWrapper"
    "OpenWrapSDKWrapper"
    "MintegralAdSDKWrapper"
    "MobileFuseSDKWrapper"
    "InMobiSDKWrapper"
)

# Get SDK name for a wrapper
# Usage: sdk_name=$(get_sdk_name "ShimmerWrapper")
get_sdk_name() {
    local wrapper="${1:-}"
    case "$wrapper" in
        "ShimmerWrapper") echo "Shimmer" ;;
        "FBAudienceNetworkWrapper") echo "FBAudienceNetwork" ;;
        "IronSourceSDKWrapper") echo "IronSourceSDK" ;;
        "OpenWrapSDKWrapper") echo "OpenWrapSDK" ;;
        "MintegralAdSDKWrapper") echo "MintegralAdSDK" ;;
        "MobileFuseSDKWrapper") echo "MobileFuseSDK" ;;
        "InMobiSDKWrapper") echo "InMobiSDK" ;;
        *) echo "" ;;
    esac
}

# Get builder script name for a wrapper
# Usage: script_name=$(get_builder_script "ShimmerWrapper")
get_builder_script() {
    local wrapper="${1:-}"
    case "$wrapper" in
        "ShimmerWrapper") echo "build-shimmer.sh" ;;
        "FBAudienceNetworkWrapper") echo "build-fbaudiencenetwork.sh" ;;
        "IronSourceSDKWrapper") echo "build-ironsourcesdk.sh" ;;
        "OpenWrapSDKWrapper") echo "build-openwrap.sh" ;;
        "MintegralAdSDKWrapper") echo "build-mintegralad.sh" ;;
        "MobileFuseSDKWrapper") echo "build-mobilefuse.sh" ;;
        "InMobiSDKWrapper") echo "build-inmobi.sh" ;;
        *) echo "" ;;
    esac
}

# Check if a wrapper name is valid
# Usage: if is_valid_wrapper "ShimmerWrapper"; then ...
is_valid_wrapper() {
    local wrapper="${1:-}"
    local name
    for name in "${WRAPPER_NAMES[@]}"; do
        if [[ "$name" == "$wrapper" ]]; then
            return 0
        fi
    done
    return 1
}

# Export functions and arrays
export -f get_sdk_name get_builder_script is_valid_wrapper
export WRAPPER_NAMES
