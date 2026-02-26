#!/usr/bin/env bash
# ============================================================================
# SPM CDN Verification Module
# ============================================================================
# Module: release/publish/spm/lib/cdn_verification.sh
# Purpose: CDN availability verification and checksum validation for SPM
#
# Functions:
#   - spm_verify_cdn_availability: Verify CDN availability for all zips
#   - spm_verify_checksum_from_cdn: Verify checksums by downloading from CDN
#   - spm_quick_cdn_check: Quick CDN accessibility check
#
# Config-Driven Environment Variables:
#   - MSP_SPM_GITHUB_REPO: GitHub repository (default: ParticleMedia/msp-ios-sdk-public)
#   - MSP_SPM_CDN_MAX_ATTEMPTS: Max retry attempts (default: 5)
#   - MSP_SPM_CDN_RETRY_DELAY: Delay between retries (default: 10)
#   - MSP_SKIP_SPM_CDN_VERIFICATION: Skip CDN verification (default: false)
#   - MSP_SKIP_SPM_CHECKSUM_VERIFICATION: Skip checksum verification (default: false)
#
# Dependencies:
#   - curl CLI
#   - shasum or sha256sum CLI
#   - Logging functions (log::info, log::error, log::success)
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_SPM_CDN_VERIFICATION_SOURCED:-}" ]] && return 0
readonly _SPM_CDN_VERIFICATION_SOURCED=1

# R031e: Source checksum module for unified checksum computation
_CDN_VERIFY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CDN_VERIFY_ROOT_DIR="$(cd "$_CDN_VERIFY_SCRIPT_DIR/../../../../.." && pwd)"
if [[ -f "$_CDN_VERIFY_ROOT_DIR/Scripts/lib/checksum.sh" ]]; then
    # shellcheck source=Scripts/lib/checksum.sh
    source "$_CDN_VERIFY_ROOT_DIR/Scripts/lib/checksum.sh" 2>/dev/null || true
fi

# ============================================================================
# Configuration (Config-Driven)
# ============================================================================

SPM_CDN_DEFAULT_GITHUB_REPO="ParticleMedia/msp-ios-sdk-public"
SPM_CDN_DEFAULT_MAX_ATTEMPTS=5
SPM_CDN_DEFAULT_RETRY_DELAY=10

# ============================================================================
# Verify CDN Availability
# ============================================================================
# Verifies CDN availability for all SPM zips.
#
# Args:
#   $1: version - Release version tag
#   $@: framework_checksums - Array of "framework_name|checksum|zip_name" strings
#
# Returns:
#   0 if all accessible, 1 if any failed
# ============================================================================
spm_verify_cdn_availability() {
    local version="$1"
    shift
    # Handle empty array with set -u by using ${@+"$@"} pattern
    local framework_checksums=()
    [[ $# -gt 0 ]] && framework_checksums=("$@")
    local github_repo="${MSP_SPM_GITHUB_REPO:-$SPM_CDN_DEFAULT_GITHUB_REPO}"
    local max_attempts="${MSP_SPM_CDN_MAX_ATTEMPTS:-$SPM_CDN_DEFAULT_MAX_ATTEMPTS}"
    local retry_delay="${MSP_SPM_CDN_RETRY_DELAY:-$SPM_CDN_DEFAULT_RETRY_DELAY}"

    if command -v log_section &>/dev/null; then
        log_section "Verifying CDN Availability for SPM Zips"
    fi
    if command -v log::info &>/dev/null; then
        log::info "SPM" "What: Checking if all uploaded zips are accessible via GitHub CDN"
        log::info "SPM" "Why: Ensures users won't get 404 errors when resolving Package.swift"
    fi
    echo ""

    local verified=0
    local failed=0
    local zip_urls=()

    # Guard: Return early if no checksums provided
    if [[ ${#framework_checksums[@]} -eq 0 ]]; then
        if command -v log::success &>/dev/null; then
            log::success "SPM" "No checksums to verify (empty input)"
        fi
        return 0
    fi

    # Collect all zip URLs
    for framework_info in "${framework_checksums[@]}"; do
        IFS='|' read -r framework_name checksum zip_name <<< "$framework_info"

        # Skip if zip_name is empty (source-based targets)
        if [[ -z "$zip_name" ]]; then
            if command -v log::debug &>/dev/null; then
                log::debug "SPM" "Skipping CDN verification for $framework_name (no zip file, likely source-based target)"
            fi
            continue
        fi

        local url="https://github.com/${github_repo}/releases/download/${version}/${zip_name}"
        zip_urls+=("$url|$framework_name")
    done

    if command -v log::info &>/dev/null; then
        log::info "SPM" "Verifying ${#zip_urls[@]} zip file(s)..."
    fi
    echo ""

    # Guard against empty array (set -u will fail on empty array iteration)
    if [[ ${#zip_urls[@]} -eq 0 ]]; then
        if command -v log::success &>/dev/null; then
            log::success "SPM" "No binary zip URLs to verify (all targets are source-based or skipped)"
        fi
        return 0
    fi

    # Verify each URL with HTTP HEAD request
    for url_info in "${zip_urls[@]}"; do
        IFS='|' read -r url framework_name <<< "$url_info"
        local filename=$(basename "$url")

        # Check if filename is actually the version (indicates empty zip_name)
        if [[ "$filename" == "$version" ]]; then
            if command -v log::error &>/dev/null; then
                log::error "SPM" "Invalid URL detected: zip_name appears to be empty"
                log::error "SPM" "  Framework: $framework_name"
                log::error "SPM" "  URL: $url"
                log::error "SPM" "  This framework is likely a source-based target that should not be verified"
                log::error "SPM" "  Tip: Check if this framework should be in the binary distribution list"
            fi
            ((failed++)) || true
            continue
        fi

        # R002a: Use shared cdn_verify_url instead of inline curl loop (DRY refactor)
        if command -v cdn_verify_url &>/dev/null; then
            # Use shared module with retry logic
            if cdn_verify_url "$url" "SPM"; then
                ((verified++)) || true
            else
                ((failed++)) || true
            fi
        else
            # Fallback if shared module not available
            if curl -sSL --head --max-time 15 "$url" >/dev/null 2>&1; then
                if command -v log::success &>/dev/null; then
                    log::success "SPM" "  ✓ $filename is available on CDN"
                fi
                ((verified++)) || true
            else
                if command -v log::error &>/dev/null; then
                    log::error "SPM" "  ✗ $filename not available on CDN"
                fi
                ((failed++)) || true
            fi
        fi
    done

    # Summary
    echo ""
    if command -v log::info &>/dev/null; then
        log::info "SPM" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log::info "SPM" "CDN Verification Summary:"
        log::info "SPM" "  Total zips:    ${#zip_urls[@]}"
        log::info "SPM" "  Verified:      $verified"
        log::info "SPM" "  Failed:        $failed"
        log::info "SPM" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi

    if [[ $failed -gt 0 ]]; then
        if command -v log::error &>/dev/null; then
            log::error "SPM" ""
            log::error "SPM" "CDN verification failed: $failed file(s) not available"
            log::error "SPM" ""
            log::error "SPM" "Possible reasons:"
            log::error "SPM" "  1. CDN propagation needs more time (try increasing MSP_SPM_CDN_WAIT_TIME)"
            log::error "SPM" "  2. GitHub Release upload failed silently"
            log::error "SPM" "  3. Network issues between your location and GitHub CDN"
            log::error "SPM" ""
            log::error "SPM" "Recommendations:"
            log::error "SPM" "  1. Check GitHub Release page: https://github.com/${github_repo}/releases/tag/$version"
            log::error "SPM" "  2. Verify all zip files exist in release assets"
            log::error "SPM" "  3. Wait a few more minutes and try again"
            log::error "SPM" "  4. Increase wait time: export MSP_SPM_CDN_WAIT_TIME=180"
            log::error "SPM" ""
            log::error "SPM" "To skip this check (NOT recommended):"
            log::error "SPM" "  export MSP_SKIP_SPM_CDN_VERIFICATION=true"
        fi
        return 1
    else
        if command -v log::success &>/dev/null; then
            log::success "SPM" "✓ All SPM zips are accessible on CDN"
        fi
        return 0
    fi
}

# ============================================================================
# Verify Checksums from CDN
# ============================================================================
# Verifies checksums by downloading from CDN and comparing.
#
# Args:
#   $1: version - Release version tag
#   $@: framework_checksums - Array of "framework_name|checksum|zip_name" strings
#
# Returns:
#   0 if all match, 1 if any mismatch
# ============================================================================
spm_verify_checksum_from_cdn() {
    local version="$1"
    shift
    # Handle empty array with set -u
    local framework_checksums=()
    [[ $# -gt 0 ]] && framework_checksums=("$@")
    local github_repo="${MSP_SPM_GITHUB_REPO:-$SPM_CDN_DEFAULT_GITHUB_REPO}"

    # Guard: Return early if no checksums provided
    if [[ ${#framework_checksums[@]} -eq 0 ]]; then
        if command -v log::success &>/dev/null; then
            log::success "SPM" "No checksums to verify (empty input)"
        fi
        return 0
    fi

    if command -v log_section &>/dev/null; then
        log_section "Verifying Checksums from GitHub Release CDN"
    fi
    if command -v log::info &>/dev/null; then
        log::info "SPM" "What: Download zips from CDN and verify checksums match Package.swift"
        log::info "SPM" "Why: Ensure uploaded files are not corrupted and Package.swift is correct"
    fi
    echo ""

    local verified=0
    local failed=0
    local mismatches=()

    # Create temp directory for downloads
    local temp_verify_dir
    temp_verify_dir="$(mktemp -d -t msp_spm_checksum_verify_XXXXXX)"

    # Cleanup on exit
    trap "rm -rf '$temp_verify_dir' 2>/dev/null || true" RETURN

    if command -v log::info &>/dev/null; then
        log::info "SPM" "Verifying ${#framework_checksums[@]} checksum(s)..."
    fi
    echo ""

    for framework_info in "${framework_checksums[@]}"; do
        IFS='|' read -r framework_name expected_checksum zip_name <<< "$framework_info"

        # Skip source-based targets (no zip file)
        if [[ -z "$zip_name" ]] || [[ ! "$zip_name" =~ \.zip$ ]]; then
            if command -v log::debug &>/dev/null; then
                log::debug "SPM" "Skipping checksum verification for $framework_name (source-based target, no zip file)"
            fi
            continue
        fi

        local url="https://github.com/${github_repo}/releases/download/${version}/${zip_name}"
        local temp_zip="$temp_verify_dir/$zip_name"

        if command -v log::step &>/dev/null; then
            log::step "SPM" "Verifying: $framework_name"
        fi
        if command -v log::info &>/dev/null; then
            log::info "SPM" "  Expected checksum: ${expected_checksum:0:16}..."
        fi

        # Download zip from CDN
        if command -v log::info &>/dev/null; then
            log::info "SPM" "  Downloading from CDN..."
        fi
        if ! curl -sSfL "$url" -o "$temp_zip" 2>/dev/null; then
            if command -v log::error &>/dev/null; then
                log::error "SPM" "  ✗ Failed to download $zip_name from CDN"
                log::error "SPM" "    URL: $url"
            fi
            ((failed++)) || true
            continue
        fi

        # Calculate checksum
        if command -v log::info &>/dev/null; then
            log::info "SPM" "  Calculating checksum..."
        fi
        local actual_checksum
        # R031e: Use checksum.sh module if available, fallback to direct tools
        if command -v checksum_compute_sha256 &>/dev/null; then
            actual_checksum=$(checksum_compute_sha256 "$temp_zip")
        elif command -v shasum >/dev/null 2>&1; then
            actual_checksum=$(shasum -a 256 "$temp_zip" | cut -d' ' -f1)
        elif command -v sha256sum >/dev/null 2>&1; then
            actual_checksum=$(sha256sum "$temp_zip" | cut -d' ' -f1)
        else
            if command -v log::error &>/dev/null; then
                log::error "SPM" "  ✗ No checksum tool available (checksum.sh, shasum, or sha256sum)"
            fi
            ((failed++)) || true
            continue
        fi

        # Compare checksums
        if [[ "$actual_checksum" == "$expected_checksum" ]]; then
            if command -v log::success &>/dev/null; then
                log::success "SPM" "  ✓ Checksum matches: ${actual_checksum:0:16}..."
            fi
            ((verified++)) || true
        else
            if command -v log::error &>/dev/null; then
                log::error "SPM" "  ✗ Checksum mismatch!"
                log::error "SPM" "    Expected: ${expected_checksum:0:16}..."
                log::error "SPM" "    Actual:   ${actual_checksum:0:16}..."
            fi
            mismatches+=("$framework_name")
            ((failed++)) || true
        fi
    done

    # Summary
    echo ""
    if command -v log::info &>/dev/null; then
        log::info "SPM" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log::info "SPM" "Checksum Verification Summary:"
        log::info "SPM" "  Verified: $verified"
        log::info "SPM" "  Failed:   $failed"
        log::info "SPM" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi

    if [[ $failed -gt 0 ]]; then
        if command -v log::error &>/dev/null; then
            log::error "SPM" ""
            log::error "SPM" "Checksum verification failed: $failed file(s)"
            if [[ ${#mismatches[@]} -gt 0 ]]; then
                log::error "SPM" "Mismatched frameworks:"
                for m in "${mismatches[@]}"; do
                    log::error "SPM" "  - $m"
                done
            fi
            log::error "SPM" ""
            log::error "SPM" "Possible reasons:"
            log::error "SPM" "  1. Zip was modified after checksum was computed"
            log::error "SPM" "  2. Package.swift has incorrect checksum"
            log::error "SPM" "  3. GitHub CDN served a cached/stale version"
            log::error "SPM" ""
            log::error "SPM" "To skip this check (NOT recommended):"
            log::error "SPM" "  export MSP_SKIP_SPM_CHECKSUM_VERIFICATION=true"
        fi
        return 1
    else
        if command -v log::success &>/dev/null; then
            log::success "SPM" "✓ All checksums verified from CDN"
        fi
        return 0
    fi
}

# ============================================================================
# Quick CDN Check
# ============================================================================
# Quick CDN accessibility check for all framework zips.
# Returns true if all are already accessible.
#
# Args:
#   $1: version - Release version tag
#   $@: framework_checksums - Array of "framework_name|checksum|zip_name" strings
#
# Returns:
#   0 if all accessible, 1 otherwise
# ============================================================================
spm_quick_cdn_check() {
    local version="$1"
    shift
    # Handle empty array with set -u
    local framework_checksums=()
    [[ $# -gt 0 ]] && framework_checksums=("$@")
    local github_repo="${MSP_SPM_GITHUB_REPO:-$SPM_CDN_DEFAULT_GITHUB_REPO}"

    # Guard: Return success if no checksums (nothing to check)
    if [[ ${#framework_checksums[@]} -eq 0 ]]; then
        return 0
    fi

    if command -v log::info &>/dev/null; then
        log::info "SPM" "Quick CDN accessibility check (skipping full wait if already ready)..."
    fi

    for framework_info in "${framework_checksums[@]}"; do
        IFS='|' read -r framework_name checksum zip_name <<< "$framework_info"

        # Skip source-based targets
        if [[ -z "$zip_name" ]] || [[ ! "$zip_name" =~ \.zip$ ]]; then
            continue
        fi

        local zip_url="https://github.com/${github_repo}/releases/download/${version}/${zip_name}"

        # R002b: Use shared cdn_verify_url instead of inline curl (DRY refactor)
        # Set quick timeout via env vars
        local orig_attempts="${MSP_CDN_MAX_ATTEMPTS:-}"
        export MSP_CDN_MAX_ATTEMPTS=1  # Quick check, no retries

        if command -v cdn_verify_url &>/dev/null; then
            if ! cdn_verify_url "$zip_url" "SPM" 2>/dev/null; then
                MSP_CDN_MAX_ATTEMPTS="$orig_attempts"
                return 1
            fi
        else
            # Fallback if shared module not available
            local http_code
            http_code=$(curl -sI -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$zip_url" 2>/dev/null || echo "000")
            if [[ "$http_code" == "000" ]] || ! echo "$http_code" | grep -q "^200\|^302"; then
                return 1
            fi
        fi

        MSP_CDN_MAX_ATTEMPTS="$orig_attempts"

        if command -v log::info &>/dev/null; then
            log::info "SPM" "  $framework_name: Already accessible ✓"
        fi
    done

    if command -v log::success &>/dev/null; then
        log::success "SPM" "✓ All CDN assets already accessible (skipping propagation wait)"
        log::info "SPM" "  CocoaPods release likely already completed CDN propagation"
    fi
    return 0
}

# ============================================================================
# Export Functions
# ============================================================================

export -f spm_verify_cdn_availability 2>/dev/null || true
export -f spm_verify_checksum_from_cdn 2>/dev/null || true
export -f spm_quick_cdn_check 2>/dev/null || true
