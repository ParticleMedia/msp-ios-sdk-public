#!/usr/bin/env bash
# ============================================================================
# Pod Trunk Module
# ============================================================================
# Module: pod_trunk.sh
# Purpose: CocoaPods Trunk verification and availability checking
# Extracted from: publish.sh (T101)
#
# Functions:
#   - check_pod_published_on_trunk: Check if pod version exists on Trunk
#   - verify_all_pods_on_trunk: Batch verify pods on Trunk
#   - wait_for_pod_availability: Wait for pod to be available after publish
#
# Dependencies:
#   - pod CLI (CocoaPods)
#   - Logging functions (log_info, log_error, log_success, log_warning, log_step)
#   - check_pod_availability from cocoapods.sh (for CDN availability)
#
# Environment Variables:
#   - None specific to this module
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_POD_TRUNK_SOURCED:-}" ]] && return 0
readonly _POD_TRUNK_SOURCED=1

# ============================================================================
# Module Initialization
# ============================================================================

_pod_trunk_init() {
    # Verify pod CLI is available
    if ! command -v pod &>/dev/null; then
        echo "[ERROR] CocoaPods CLI (pod) is not installed" >&2
        return 1
    fi

    # Verify logging functions are available
    if ! command -v log_info &>/dev/null; then
        echo "[ERROR] Logging functions not available. Source logger.sh first." >&2
        return 1
    fi

    return 0
}

# ============================================================================
# Public API
# ============================================================================

# Check if a specific pod version exists on CocoaPods Trunk
# @description Verifies if a pod version has been published to CocoaPods Trunk
# @param $1 pod - Pod name (e.g., "MSPCore")
# @param $2 version - Version string (e.g., "1.0.0")
# @return 0 if exists, 1 if not found
check_pod_published_on_trunk() {
    local pod="$1"
    local version="$2"

    log::info "PODS" "Checking if $pod $version is published on CocoaPods Trunk..."

    # Method 1: pod trunk info (fastest and most reliable)
    if pod trunk info "$pod" 2>/dev/null | grep -q -- "- $version"; then
        log::success "PODS" "$pod $version found on Trunk (via trunk info)"
        return 0
    fi

    # Method 2: pod search (fallback)
    if pod search "$pod" --simple 2>/dev/null | grep -q -- "-> $version"; then
        log::success "PODS" "$pod $version found on Trunk (via search)"
        return 0
    fi

    # Method 3: Check pod spec repo (last resort)
    if pod spec cat "$pod" 2>/dev/null | grep -q -- "version.*$version"; then
        log::success "PODS" "$pod $version found in spec repo"
        return 0
    fi

    log::warn "PODS" "$pod $version not found on Trunk"
    return 1
}

# Verify all pods in list are published
# @description Batch verify multiple pods are published to Trunk
# @param $1 version - Version string to check
# @param $@ pods - Array of pod names
# @return 0 if all found, 1 if any missing
verify_all_pods_on_trunk() {
    local version="$1"
    shift
    local pods=("$@")

    log::info "PODS" "Verifying ${#pods[@]} pods on CocoaPods Trunk..."

    local all_found=true
    for pod in "${pods[@]}"; do
        if ! check_pod_published_on_trunk "$pod" "$version"; then
            all_found=false
        fi
    done

    if [[ "$all_found" == "true" ]]; then
        log::success "PODS" "All pods verified on Trunk"
        return 0
    else
        log::error "PODS" "Some pods not found on Trunk"
        return 1
    fi
}

# Wait for pod to be available on CDN
# @description Waits with exponential backoff for pod to become available
# @param $1 pod - Pod name
# @param $2 version - Version string
# @return 0 if available, 1 if timeout
# @note Uses check_pod_availability from cocoapods.sh
wait_for_pod_availability() {
    local pod="$1"
    local version="$2"
    local max_attempts=12  # Increased from 8 to 12 for longer waiting period
    local base_delay=20    # Increased from 15 to 20 seconds for better CDN propagation coverage

    log::step "PODS" "Waiting for $pod version $version to be available"

    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if check_pod_availability "$pod" "$version"; then
            log::success "PODS" "$pod version $version is now available"
            return 0
        else
            if [[ $attempt -lt $max_attempts ]]; then
                local delay=$((base_delay * (1 << (attempt - 1))))
                log::info "PODS" "Waiting ${delay}s for $pod to be published (attempt $attempt/$max_attempts)..."
                sleep $delay
            else
                log::warn "PODS" "Timeout waiting for $pod version $version to be published (CDN sync may be delayed)"
                return 1
            fi
        fi
        ((attempt++)) || true
    done

    return 1
}

# ============================================================================
# Export Functions
# ============================================================================

export -f check_pod_published_on_trunk
export -f verify_all_pods_on_trunk
export -f wait_for_pod_availability
