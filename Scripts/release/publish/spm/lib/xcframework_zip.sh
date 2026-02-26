#!/usr/bin/env bash
# ============================================================================
# SPM XCFramework Zip Module
# ============================================================================
# Module: release/publish/spm/lib/xcframework_zip.sh
# Purpose: Deterministic zip creation, checksum computation, and GitHub upload
#
# Functions:
#   - spm_create_deterministic_zip: Create reproducible zip from XCFramework
#   - spm_compute_zip_checksum: Compute SHA256 checksum for zip
#   - spm_upload_to_github_release: Upload zip to GitHub Release
#   - spm_probe_zip_url: Probe URL availability with retries
#
# Config-Driven Environment Variables:
#   - MSP_SPM_GITHUB_REPO: GitHub repository (default: ParticleMedia/msp-ios-sdk-public)
#   - MSP_SPM_UPLOAD_MAX_RETRIES: Max upload retry attempts (default: 3)
#   - MSP_SPM_PROBE_MAX_ATTEMPTS: Max URL probe attempts (default: 12)
#   - MSP_SPM_PROBE_SLEEP_SECONDS: Delay between probes (default: 5)
#
# Dependencies:
#   - curl CLI
#   - gh CLI (GitHub CLI)
#   - swift CLI (optional, for compute-checksum)
#   - zip CLI
#   - Logging functions (log::info, log::error, log::success)
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_SPM_XCFRAMEWORK_ZIP_SOURCED:-}" ]] && return 0
readonly _SPM_XCFRAMEWORK_ZIP_SOURCED=1

# R031a: Source checksum module for unified SHA256 computation
_SPM_XCF_ZIP_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
if [[ -f "$_SPM_XCF_ZIP_ROOT_DIR/Scripts/lib/checksum.sh" ]]; then
    # shellcheck source=Scripts/lib/checksum.sh
    source "$_SPM_XCF_ZIP_ROOT_DIR/Scripts/lib/checksum.sh" 2>/dev/null || true
fi

# R008: Source shared GitHub release module for unified release operations
if [[ -f "$_SPM_XCF_ZIP_ROOT_DIR/Scripts/lib/shared/github_release.sh" ]]; then
    # shellcheck source=Scripts/lib/shared/github_release.sh
    source "$_SPM_XCF_ZIP_ROOT_DIR/Scripts/lib/shared/github_release.sh" 2>/dev/null || true
fi

# ============================================================================
# Configuration (Config-Driven)
# ============================================================================

SPM_ZIP_DEFAULT_GITHUB_REPO="ParticleMedia/msp-ios-sdk-public"
SPM_ZIP_DEFAULT_UPLOAD_MAX_RETRIES=3
SPM_ZIP_DEFAULT_PROBE_MAX_ATTEMPTS=12
SPM_ZIP_DEFAULT_PROBE_SLEEP_SECONDS=5

# ============================================================================
# Create Deterministic Zip
# ============================================================================
# Creates a deterministic (reproducible) zip file from an XCFramework.
# Uses fixed timestamps to ensure consistent checksums across builds.
#
# Args:
#   $1: xcframework_path - Path to the .xcframework directory
#   $2: zip_output_path - Output path for the zip file
#   $3: framework_name - Name for logging
#
# Returns:
#   0 on success, 1 on failure
# ============================================================================
spm_create_deterministic_zip() {
    local xcframework_path="$1"
    local zip_output_path="$2"
    local framework_name="$3"

    if [[ ! -d "$xcframework_path" ]]; then
        if command -v log::error &>/dev/null; then
            log::error "SPM" "XCFramework not found: $xcframework_path"
        fi
        return 1
    fi

    if command -v log::step &>/dev/null; then
        log::step "SPM" "Creating deterministic zip for $framework_name"
    fi

    # Create temporary directory for zip creation
    local temp_zip_dir
    temp_zip_dir="$(mktemp -d -t msp_spm_zip_XXXXXX)"
    if [[ ! -d "$temp_zip_dir" ]]; then
        if command -v log::error &>/dev/null; then
            log::error "SPM" "Failed to create temporary directory for zip"
        fi
        return 1
    fi

    # Copy XCFramework to temp directory
    cp -R "$xcframework_path" "$temp_zip_dir/$(basename "$xcframework_path")"

    # Set deterministic timestamp to ensure consistent checksums across builds
    # Use a fixed date (2025-01-01 00:00:00 UTC) for all files
    if command -v log::info &>/dev/null; then
        log::info "SPM" "Setting deterministic timestamps for reproducible zip"
    fi
    find "$temp_zip_dir" -exec touch -t 202501010000.00 {} \;

    # Create deterministic zip file
    # -r: recursive
    # -X: exclude extra file attributes (ensures cross-platform reproducibility)
    # -q: quiet mode
    if command -v log::info &>/dev/null; then
        log::info "SPM" "Creating deterministic zip file"
    fi
    (cd "$temp_zip_dir" && TZ=UTC zip -r -X -q "$zip_output_path" .)
    local zip_exit_code=$?

    # Cleanup
    rm -rf "$temp_zip_dir"

    if [[ $zip_exit_code -ne 0 ]] || [[ ! -f "$zip_output_path" ]]; then
        if command -v log::error &>/dev/null; then
            log::error "SPM" "Failed to create zip file: $zip_output_path"
        fi
        return 1
    fi

    if command -v log::success &>/dev/null; then
        log::success "SPM" "Created deterministic zip: $zip_output_path"
    fi
    return 0
}

# ============================================================================
# Compute Zip Checksum
# ============================================================================
# Computes SHA256 checksum for a zip file using swift package compute-checksum
# or falling back to shasum.
#
# Args:
#   $1: zip_path - Path to the zip file
#
# Returns:
#   Prints the 64-character SHA256 checksum on success
#   Returns 1 on failure
# ============================================================================
spm_compute_zip_checksum() {
    local zip_path="$1"

    if [[ ! -f "$zip_path" ]]; then
        if command -v log::error &>/dev/null; then
            log::error "SPM" "Zip file not found: $zip_path"
        fi
        return 1
    fi

    if command -v log::step &>/dev/null; then
        log::step "SPM" "Computing checksum for $(basename "$zip_path")"
    fi

    # R031a: Use checksum.sh module if available
    if command -v checksum_compute_sha256 &>/dev/null; then
        local checksum
        checksum=$(checksum_compute_sha256 "$zip_path")
        if [[ -n "$checksum" ]] && [[ ${#checksum} -eq 64 ]]; then
            if command -v log::success &>/dev/null; then
                log::success "SPM" "Computed checksum via checksum.sh: $checksum"
            fi
            echo "$checksum"
            return 0
        fi
    fi

    # Fallback: Use swift package compute-checksum (preferred method)
    if command -v swift >/dev/null 2>&1; then
        local checksum
        checksum=$(swift package compute-checksum "$zip_path" 2>/dev/null)
        if [[ -n "$checksum" ]] && [[ ${#checksum} -eq 64 ]]; then
            if command -v log::success &>/dev/null; then
                log::success "SPM" "Computed checksum: $checksum"
            fi
            echo "$checksum"
            return 0
        else
            if command -v log::warn &>/dev/null; then
                log::warn "SPM" "swift package compute-checksum failed or returned invalid checksum, falling back to shasum"
            fi
        fi
    fi

    # Fallback to shasum
    if command -v shasum >/dev/null 2>&1; then
        local checksum
        checksum=$(shasum -a 256 "$zip_path" 2>/dev/null | cut -d' ' -f1)
        if [[ -n "$checksum" ]] && [[ ${#checksum} -eq 64 ]]; then
            if command -v log::success &>/dev/null; then
                log::success "SPM" "Computed checksum (shasum): $checksum"
            fi
            echo "$checksum"
            return 0
        else
            if command -v log::error &>/dev/null; then
                log::error "SPM" "shasum failed to compute checksum"
            fi
            return 1
        fi
    fi

    if command -v log::error &>/dev/null; then
        log::error "SPM" "Neither checksum.sh, swift package compute-checksum, nor shasum is available"
    fi
    return 1
}

# ============================================================================
# Upload to GitHub Release
# ============================================================================
# Uploads zip file to GitHub Release with idempotency checks.
# R008: Now delegates to shared github_release.sh module
#
# Args:
#   $1: zip_path - Path to the zip file
#   $2: framework_name - Name for logging
#   $3: version - Release version tag
#
# Environment:
#   DRY_RUN - If "true", skip actual upload
#   MSP_SPM_GITHUB_REPO - Target repository (maps to MSP_GITHUB_REPO)
#   MSP_SPM_UPLOAD_MAX_RETRIES - Max retry attempts
#
# Returns:
#   0 on success, 1 on failure
# ============================================================================
spm_upload_to_github_release() {
    local zip_path="$1"
    local framework_name="$2"
    local version="$3"

    if [[ ! -f "$zip_path" ]]; then
        if command -v log::error &>/dev/null; then
            log::error "SPM" "Zip file not found: $zip_path"
        fi
        return 1
    fi

    local zip_name
    zip_name=$(basename "$zip_path")

    if command -v log::step &>/dev/null; then
        log::step "SPM" "Uploading $framework_name to GitHub Release"
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]] || [[ "${DRY_RUN:-0}" == "1" ]]; then
        local zip_url
        zip_url=$(spm_build_github_release_url "$version" "$zip_name")
        if command -v log::info &>/dev/null; then
            log::info "SPM" "DRY RUN: Would upload $zip_path to GitHub Release $version"
            log::info "SPM" "DRY RUN: Generated URL: $zip_url"
        fi
        return 0
    fi

    # R008: Delegate to shared module if available
    if command -v github_release_upload_asset &>/dev/null; then
        # Map SPM-specific env vars to shared module vars
        local saved_repo="${MSP_GITHUB_REPO:-}"
        local saved_retries="${MSP_GITHUB_UPLOAD_MAX_RETRIES:-}"
        export MSP_GITHUB_REPO="${MSP_SPM_GITHUB_REPO:-$SPM_ZIP_DEFAULT_GITHUB_REPO}"
        export MSP_GITHUB_UPLOAD_MAX_RETRIES="${MSP_SPM_UPLOAD_MAX_RETRIES:-$SPM_ZIP_DEFAULT_UPLOAD_MAX_RETRIES}"

        local result=0
        if ! github_release_upload_asset "$version" "$zip_path" "SPM"; then
            result=1
        fi

        # Restore original env vars
        if [[ -n "$saved_repo" ]]; then
            export MSP_GITHUB_REPO="$saved_repo"
        else
            unset MSP_GITHUB_REPO
        fi
        if [[ -n "$saved_retries" ]]; then
            export MSP_GITHUB_UPLOAD_MAX_RETRIES="$saved_retries"
        else
            unset MSP_GITHUB_UPLOAD_MAX_RETRIES
        fi

        # Probe URL after upload
        if [[ $result -eq 0 ]] && [[ "${DRY_RUN:-false}" != "true" ]]; then
            if command -v log::info &>/dev/null; then
                log::info "SPM" ""
                log::info "SPM" "Verifying upload: probing zip URL availability..."
            fi
            if ! spm_probe_zip_url "$framework_name" "$version" "$zip_name"; then
                if command -v log::error &>/dev/null; then
                    log::error "SPM" "Zip URL not accessible after upload"
                fi
                return 1
            fi
        fi

        return $result
    fi

    # Fallback: Original implementation if shared module not available
    if command -v log::warn &>/dev/null; then
        log::warn "SPM" "Shared github_release module not available, using legacy implementation"
    fi

    local github_repo="${MSP_SPM_GITHUB_REPO:-$SPM_ZIP_DEFAULT_GITHUB_REPO}"
    local max_retries="${MSP_SPM_UPLOAD_MAX_RETRIES:-$SPM_ZIP_DEFAULT_UPLOAD_MAX_RETRIES}"

    # Check if GitHub CLI is available
    if ! command -v gh >/dev/null 2>&1; then
        if command -v log::error &>/dev/null; then
            log::error "SPM" "GitHub CLI (gh) is not available"
        fi
        return 1
    fi

    # Legacy upload with retry logic
    local retry_count=0
    while [[ $retry_count -lt $max_retries ]]; do
        if gh release upload "$version" "$zip_path" --repo "$github_repo" --clobber 2>&1; then
            if command -v log::success &>/dev/null; then
                log::success "SPM" "Uploaded $framework_name to GitHub Release $version"
            fi
            return 0
        else
            ((retry_count++)) || true
            if [[ $retry_count -lt $max_retries ]]; then
                if command -v log::warn &>/dev/null; then
                    log::warn "SPM" "Upload failed, retrying in 5 seconds..."
                fi
                sleep 5
            fi
        fi
    done

    if command -v log::error &>/dev/null; then
        log::error "SPM" "Failed to upload $framework_name to GitHub Release"
    fi
    return 1
}

# ============================================================================
# Probe Zip URL Availability
# ============================================================================
# Probes zip URL availability with retries.
# R008: Now delegates to shared github_release.sh module
#
# Args:
#   $1: framework_name - Name for logging
#   $2: version - Release version tag
#   $3: zip_name - Zip filename
#   $4: max_attempts (optional) - Max attempts (default: MSP_SPM_PROBE_MAX_ATTEMPTS)
#   $5: sleep_seconds (optional) - Delay between attempts (default: MSP_SPM_PROBE_SLEEP_SECONDS)
#
# Returns:
#   0 if URL accessible, 1 otherwise
# ============================================================================
spm_probe_zip_url() {
    local framework_name="$1"
    local version="$2"
    local zip_name="$3"
    local max_attempts="${4:-${MSP_SPM_PROBE_MAX_ATTEMPTS:-$SPM_ZIP_DEFAULT_PROBE_MAX_ATTEMPTS}}"
    local sleep_seconds="${5:-${MSP_SPM_PROBE_SLEEP_SECONDS:-$SPM_ZIP_DEFAULT_PROBE_SLEEP_SECONDS}}"
    local github_repo="${MSP_SPM_GITHUB_REPO:-$SPM_ZIP_DEFAULT_GITHUB_REPO}"

    local zip_url="https://github.com/${github_repo}/releases/download/${version}/${zip_name}"

    # R008: Delegate to shared module if available
    if command -v github_release_probe_url &>/dev/null; then
        if ! github_release_probe_url "$zip_url" "SPM" "$max_attempts" "$sleep_seconds"; then
            if command -v log::error &>/dev/null; then
                log::error "SPM" "   Framework: $framework_name"
                log::error "SPM" ""
                log::error "SPM" "Binary zip must be available before pushing tags (SPM distribution requirement)"
            fi
            return 1
        fi
        return 0
    fi

    # Fallback: Original implementation
    if command -v log::step &>/dev/null; then
        log::step "SPM" "Probing zip URL availability: $zip_url"
    fi

    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if curl -sSfL --head "$zip_url" >/dev/null 2>&1; then
            if command -v log::success &>/dev/null; then
                log::success "SPM" "✓ Zip URL is accessible: $zip_url"
            fi
            return 0
        else
            if [[ $attempt -lt $max_attempts ]]; then
                if command -v log::info &>/dev/null; then
                    log::info "SPM" "  Zip URL not yet accessible (attempt $attempt/$max_attempts), waiting ${sleep_seconds}s..."
                fi
                sleep "$sleep_seconds"
            else
                if command -v log::error &>/dev/null; then
                    log::error "SPM" "❌ Zip URL not accessible after $max_attempts attempts"
                    log::error "SPM" "   Framework: $framework_name"
                    log::error "SPM" "   URL: $zip_url"
                fi
                return 1
            fi
        fi
        ((attempt++)) || true
    done

    return 1
}

# ============================================================================
# Build GitHub Release URL
# ============================================================================
# Constructs a GitHub Release download URL.
#
# Args:
#   $1: version - Release version tag
#   $2: zip_name - Zip filename
#
# Returns:
#   Prints the constructed URL
# ============================================================================
spm_build_github_release_url() {
    local version="$1"
    local zip_name="$2"
    local github_repo="${MSP_SPM_GITHUB_REPO:-$SPM_ZIP_DEFAULT_GITHUB_REPO}"

    echo "https://github.com/${github_repo}/releases/download/${version}/${zip_name}"
}

# ============================================================================
# Export Functions
# ============================================================================

export -f spm_create_deterministic_zip 2>/dev/null || true
export -f spm_compute_zip_checksum 2>/dev/null || true
export -f spm_upload_to_github_release 2>/dev/null || true
export -f spm_probe_zip_url 2>/dev/null || true
export -f spm_build_github_release_url 2>/dev/null || true
