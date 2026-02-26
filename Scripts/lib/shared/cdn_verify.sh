#!/usr/bin/env bash
# ============================================================================
# Shared CDN Verification Module
# ============================================================================
# Module: shared/cdn_verify.sh
# Purpose: GitHub Release CDN propagation waiting and verification
#          Used by both CocoaPods and SPM release workflows
#
# Functions:
#   - cdn_wait_for_propagation: Wait for CDN to propagate release assets
#   - cdn_verify_url: Verify single URL on CDN
#   - cdn_verify_urls: Batch verify multiple URLs on CDN
#   - cdn_build_github_release_url: Build GitHub Release download URL
#
# Config-Driven Environment Variables:
#   - MSP_CDN_WAIT_TIME: CDN propagation wait time in seconds (default: 120)
#   - MSP_CDN_MAX_ATTEMPTS: Max retry attempts for verification (default: 5)
#   - MSP_CDN_RETRY_DELAY: Delay between retries in seconds (default: 10)
#   - MSP_GITHUB_REPO: GitHub repository (default: ParticleMedia/msp-ios-sdk-public)
#
# Dependencies:
#   - curl CLI
#   - Logging functions (log::info, log::error, log::success)
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_SHARED_CDN_VERIFY_SOURCED:-}" ]] && return 0
readonly _SHARED_CDN_VERIFY_SOURCED=1

# ============================================================================
# Configuration (Config-Driven)
# ============================================================================
# Default values can be overridden by environment variables

CDN_DEFAULT_WAIT_TIME=120
CDN_DEFAULT_MAX_ATTEMPTS=5
CDN_DEFAULT_RETRY_DELAY=10
CDN_DEFAULT_GITHUB_REPO="ParticleMedia/msp-ios-sdk-public"

# ============================================================================
# Build GitHub Release Download URL
# ============================================================================
# Constructs a GitHub Release download URL
#
# Args:
#   $1: tag - Release tag (e.g., "v1.0.0")
#   $2: filename - Asset filename (e.g., "MSPCore.xcframework.zip")
#   $3: repo (optional) - GitHub repo (default: MSP_GITHUB_REPO or default)
#
# Returns:
#   Prints the constructed URL
# ============================================================================
cdn_build_github_release_url() {
    local tag="$1"
    local filename="$2"
    local repo="${3:-${MSP_GITHUB_REPO:-$CDN_DEFAULT_GITHUB_REPO}}"

    echo "https://github.com/${repo}/releases/download/${tag}/${filename}"
}

# ============================================================================
# Wait for CDN Propagation
# ============================================================================
# Waits for GitHub CDN to propagate release assets globally
# Shows progress bar during wait
#
# Args:
#   $1: context - Context name for logging (e.g., "SPM", "PODS")
#
# Environment:
#   MSP_CDN_WAIT_TIME - Wait time in seconds (default: 120)
# ============================================================================
cdn_wait_for_propagation() {
    local context="${1:-CDN}"
    local wait_time="${MSP_CDN_WAIT_TIME:-$CDN_DEFAULT_WAIT_TIME}"

    if command -v log::info &>/dev/null; then
        log::info "$context" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log::info "$context" "Waiting for GitHub CDN Propagation"
        log::info "$context" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log::info "$context" "Wait time: ${wait_time}s (configurable via MSP_CDN_WAIT_TIME)"
        log::info "$context" "Why: GitHub Release CDN takes 60-120s to propagate globally"
    fi

    local start_time=$(date +%s)
    while true; do
        local elapsed=$(($(date +%s) - start_time))
        if [[ $elapsed -ge $wait_time ]]; then
            break
        fi

        local remaining=$((wait_time - elapsed))
        local progress=$((elapsed * 100 / wait_time))

        # Progress bar: [███████░░░] 70% (84s/120s, remaining: 36s)
        local bar_length=30
        local filled=$((progress * bar_length / 100))
        local empty=$((bar_length - filled))

        printf "\r["
        printf "%${filled}s" | tr ' ' '█'
        printf "%${empty}s" | tr ' ' '░'
        printf "] %3d%% (%ds/%ds, remaining: %ds)  " \
            "$progress" "$elapsed" "$wait_time" "$remaining" >&2

        sleep 1
    done

    echo "" >&2
    if command -v log::success &>/dev/null; then
        log::success "$context" "✓ CDN propagation wait complete (${wait_time}s)"
    fi
}

# ============================================================================
# Verify Single URL on CDN
# ============================================================================
# Verifies a single URL is accessible on CDN with retries
#
# Args:
#   $1: url - URL to verify
#   $2: context (optional) - Context name for logging (default: "CDN")
#
# Environment:
#   MSP_CDN_MAX_ATTEMPTS - Max retry attempts (default: 5)
#   MSP_CDN_RETRY_DELAY - Delay between retries (default: 10)
#
# Returns:
#   0 if accessible, 1 if not
# ============================================================================
cdn_verify_url() {
    local url="$1"
    local context="${2:-CDN}"
    local max_attempts="${MSP_CDN_MAX_ATTEMPTS:-$CDN_DEFAULT_MAX_ATTEMPTS}"
    local retry_delay="${MSP_CDN_RETRY_DELAY:-$CDN_DEFAULT_RETRY_DELAY}"
    local filename
    filename=$(basename "$url")

    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        # Use HTTP HEAD request to check URL accessibility
        # -L: Follow redirects (GitHub uses 302)
        # --max-time: Prevent hanging requests
        if curl -sSL --head --max-time 15 "$url" >/dev/null 2>&1; then
            if command -v log::success &>/dev/null; then
                log::success "$context" "✓ $filename is accessible on CDN"
            fi
            return 0
        else
            if [[ $attempt -lt $max_attempts ]]; then
                if command -v log::debug &>/dev/null; then
                    log::debug "$context" "CDN not ready for $filename, retrying in ${retry_delay}s... (attempt $attempt/$max_attempts)"
                fi
                sleep "$retry_delay"
            fi
        fi
        ((attempt++)) || true
    done

    if command -v log::error &>/dev/null; then
        log::error "$context" "✗ $filename not accessible on CDN after $max_attempts attempts"
        log::error "$context" "  URL: $url"
    fi
    return 1
}

# ============================================================================
# Verify Multiple URLs on CDN
# ============================================================================
# Batch verifies multiple URLs on CDN
#
# Args:
#   $1: context - Context name for logging
#   $@: urls - URLs to verify (remaining arguments)
#
# Returns:
#   0 if all accessible, 1 if any failed
# ============================================================================
cdn_verify_urls() {
    local context="$1"
    shift
    local urls=("$@")

    if [[ ${#urls[@]} -eq 0 ]]; then
        if command -v log::info &>/dev/null; then
            log::info "$context" "No URLs to verify"
        fi
        return 0
    fi

    if command -v log::info &>/dev/null; then
        log::info "$context" "Verifying ${#urls[@]} URL(s) on CDN..."
    fi

    local verified=0
    local failed=0

    for url in "${urls[@]}"; do
        if cdn_verify_url "$url" "$context"; then
            ((verified++)) || true
        else
            ((failed++)) || true
        fi
    done

    # Summary
    if command -v log::info &>/dev/null; then
        log::info "$context" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log::info "$context" "CDN Verification Summary:"
        log::info "$context" "  Total:    ${#urls[@]}"
        log::info "$context" "  Verified: $verified"
        log::info "$context" "  Failed:   $failed"
        log::info "$context" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi

    if [[ $failed -gt 0 ]]; then
        if command -v log::error &>/dev/null; then
            log::error "$context" "CDN verification failed: $failed file(s) not accessible"
            log::error "$context" ""
            log::error "$context" "Possible reasons:"
            log::error "$context" "  1. CDN propagation needs more time (increase MSP_CDN_WAIT_TIME)"
            log::error "$context" "  2. GitHub Release upload failed"
            log::error "$context" "  3. Network issues"
        fi
        return 1
    fi

    if command -v log::success &>/dev/null; then
        log::success "$context" "✓ All URLs verified on CDN"
    fi
    return 0
}

# ============================================================================
# Backward Compatibility Aliases (for pods/lib/cdn_verify.sh migration)
# ============================================================================
# These functions provide backward compatibility with the old function names
# used in pods/lib/cdn_verify.sh. They wrap the new cdn_* functions.

# @deprecated Use cdn_wait_for_propagation instead
wait_for_cdn_propagation() {
    local tag="$1"
    cdn_wait_for_propagation "PODS"
}

# @deprecated Use cdn_verify_url instead
# @param $1 tag - Release tag
# @param $2 filename - Filename to verify
verify_cdn_availability() {
    local tag="$1"
    local filename="$2"
    local url
    url=$(cdn_build_github_release_url "$tag" "$filename")
    cdn_verify_url "$url" "PODS"
}

# @deprecated Use cdn_verify_urls instead
# @param $1 tag - Release tag
# @param $@ filenames - Filenames to verify
verify_all_cdn_availability() {
    local tag="$1"
    shift
    local filenames=("$@")
    local urls=()

    for filename in "${filenames[@]}"; do
        urls+=("$(cdn_build_github_release_url "$tag" "$filename")")
    done

    cdn_verify_urls "PODS" "${urls[@]}"
}

# ============================================================================
# Export Functions
# ============================================================================

export -f cdn_build_github_release_url 2>/dev/null || true
export -f cdn_wait_for_propagation 2>/dev/null || true
export -f cdn_verify_url 2>/dev/null || true
export -f cdn_verify_urls 2>/dev/null || true

# Backward compatibility exports
export -f wait_for_cdn_propagation 2>/dev/null || true
export -f verify_cdn_availability 2>/dev/null || true
export -f verify_all_cdn_availability 2>/dev/null || true
