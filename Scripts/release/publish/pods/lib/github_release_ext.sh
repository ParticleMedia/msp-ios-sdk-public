#!/usr/bin/env bash
# ============================================================================
# GitHub Release Extended Module
# ============================================================================
# Module: github_release_ext.sh
# Purpose: Extended GitHub release operations (preparation, verification, pod-specific)
# Extracted from: publish.sh
#
# Functions:
#   - prepare_github_release: Orchestrate GitHub release preparation workflow
#   - verify_and_fix_github_release_zip: Verify and auto-fix zip mismatches
#   - create_github_release_for_pod: Create release and upload zip for specific pod
#   - probe_zip_url: Check if zip URL is accessible
#
# Dependencies:
#   - github_release.sh (create_or_verify_github_release, upload_zip_to_github, upload_all_zips_to_github)
#   - cdn_verify.sh (wait_for_cdn_propagation, verify_cdn_availability, verify_all_cdn_availability)
#   - zip_management.sh (create_zip_from_xcframework)
#   - distribution_utils.sh (is_binary_distribution)
#   - Logging functions (log::info, log::error, log::success, log::warn, log::step)
#   - ROOT_DIR environment variable
#
# Environment Variables:
#   - ROOT_DIR: Project root directory
#   - DRY_RUN: If "true", perform dry-run operations
#   - MSP_SKIP_CDN_VERIFICATION: If "true", skip CDN verification failures
#   - MSP_FORCE_REUPLOAD: If "true", force re-upload existing assets
#   - MSP_CDN_WAIT_TIME: CDN propagation wait time in seconds
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_GITHUB_RELEASE_EXT_SOURCED:-}" ]] && return 0
readonly _GITHUB_RELEASE_EXT_SOURCED=1

# R010: Determine root directory for sourcing shared modules
_GH_EXT_ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"

# R031d: Source checksum module for unified checksum computation
if [[ -f "$_GH_EXT_ROOT_DIR/Scripts/lib/checksum.sh" ]]; then
    # shellcheck source=Scripts/lib/checksum.sh
    source "$_GH_EXT_ROOT_DIR/Scripts/lib/checksum.sh" 2>/dev/null || true
fi

# R010: Source shared GitHub release module for common operations
# The shared module provides: prepare_github_release, probe_zip_url (via backward compat aliases)
if [[ -f "$_GH_EXT_ROOT_DIR/Scripts/lib/shared/github_release.sh" ]]; then
    # shellcheck source=Scripts/lib/shared/github_release.sh
    source "$_GH_EXT_ROOT_DIR/Scripts/lib/shared/github_release.sh" 2>/dev/null || true
fi

# ============================================================================
# Prepare GitHub Release (Unified Flow)
# ============================================================================
# R010: This function now delegates to the shared module's github_release_prepare
# while maintaining the additional CDN verification step using cdn_verify.sh
#
# Args:
#   $1: tag - Release tag
#   $@: zip_paths - Array of zip file paths
# Returns:
#   0 if success, 1 if failure
# ============================================================================
prepare_github_release() {
    local tag="$1"
    shift
    local zip_paths=("$@")

    log::info "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "PODS" "Preparing GitHub Release (Phase B Unified Flow)"
    log::info "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "PODS" "Tag: $tag"
    log::info "PODS" "Zips: ${#zip_paths[@]}"
    log::info "PODS" "DRY_RUN: ${DRY_RUN:-false}"

    # R010: Delegate to shared module if available
    if command -v github_release_create_or_verify &>/dev/null && \
       command -v github_release_upload_assets &>/dev/null; then

        # Step 1: Create/verify release (via shared module)
        log::info "PODS" ""
        log::info "PODS" "Step 1: Create/verify GitHub Release"
        if ! github_release_create_or_verify "$tag" "PODS"; then
            log::error "PODS" "Failed to create/verify GitHub Release"
            return 1
        fi

        # Step 2: Upload zips (via shared module)
        log::info "PODS" ""
        log::info "PODS" "Step 2: Upload zips to GitHub Release"
        if ! github_release_upload_assets "$tag" "PODS" "${zip_paths[@]}"; then
            log::error "PODS" "Failed to upload zips"
            return 1
        fi
    else
        # Fallback: Use legacy functions
        log::info "PODS" ""
        log::info "PODS" "Step 1: Create/verify GitHub Release"
        if ! create_or_verify_github_release "$tag"; then
            log::error "PODS" "Failed to create/verify GitHub Release"
            return 1
        fi

        log::info "PODS" ""
        log::info "PODS" "Step 2: Upload zips to GitHub Release"
        if ! upload_all_zips_to_github "$tag" "${zip_paths[@]}"; then
            log::error "PODS" "Failed to upload zips"
            return 1
        fi
    fi

    # Step 3: Wait for CDN propagation (uses cdn_verify.sh)
    log::info "PODS" ""
    log::info "PODS" "Step 3: Wait for CDN propagation"
    if command -v wait_for_cdn_propagation &>/dev/null; then
        wait_for_cdn_propagation "$tag"
    else
        local cdn_wait="${MSP_CDN_WAIT_TIME:-120}"
        log::info "PODS" "Waiting ${cdn_wait}s for CDN propagation..."
        sleep "$cdn_wait"
    fi

    # Step 4: Verify CDN availability (uses cdn_verify.sh)
    log::info "PODS" ""
    log::info "PODS" "Step 4: Verify CDN availability"
    local filenames=()
    for zip_path in "${zip_paths[@]}"; do
        if [[ -f "$zip_path" ]]; then
            filenames+=("$(basename "$zip_path")")
        fi
    done

    if command -v verify_all_cdn_availability &>/dev/null; then
        if ! verify_all_cdn_availability "$tag" "${filenames[@]}"; then
            log::error "PODS" "CDN verification failed"
            if [[ "${MSP_SKIP_CDN_VERIFICATION:-false}" == "true" ]]; then
                log::warn "PODS" "Continuing despite CDN verification failure (MSP_SKIP_CDN_VERIFICATION=true)"
            else
                log::error "PODS" "Set MSP_SKIP_CDN_VERIFICATION=true to continue anyway (NOT recommended)"
                return 1
            fi
        fi
    fi

    log::success "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::success "PODS" "GitHub Release Ready ✓"
    log::success "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    return 0
}

# ============================================================================
# Verify and Fix GitHub Release Zip (Enhanced Idempotency)
# ============================================================================
# Purpose: Verify that GitHub Release zip matches local zip
# - Called during idempotency check for already-published pods
# - Detects if GitHub Release has wrong/old zip file
# - Automatically re-uploads correct zip if mismatch detected
# - Ensures downstream pods (Adapters) can validate successfully
# ============================================================================
verify_and_fix_github_release_zip() {
    local pod="$1"
    local version="$2"

    log::info "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "PODS" "Enhanced Idempotency Check: Verifying GitHub Release zip"
    log::info "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "PODS" "Pod: $pod $version"
    log::info "PODS" "Checking if GitHub Release zip matches local zip..."

    local local_zip="$ROOT_DIR/Build/Zips/${pod}-${version}.zip"
    local zip_url="https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/${pod}-${version}.zip"

    # Check if local zip exists
    if [[ ! -f "$local_zip" ]]; then
        log::warn "PODS" "Local zip not found: $local_zip"
        log::warn "PODS" "Cannot verify GitHub Release zip (no local reference)"
        log::info "PODS" "Assuming GitHub Release is correct (pod already published)"
        return 0
    fi

    # Calculate local zip checksum
    # R031d: Use checksum.sh module if available, fallback to direct shasum
    local local_checksum
    if command -v checksum_compute_sha256 &>/dev/null; then
        local_checksum=$(checksum_compute_sha256 "$local_zip")
    else
        local_checksum=$(shasum -a 256 "$local_zip" 2>/dev/null | awk '{print $1}')
    fi
    if [[ -z "$local_checksum" ]]; then
        log::error "PODS" "Failed to calculate local zip checksum"
        return 1
    fi

    log::info "PODS" "Local zip checksum: $local_checksum"

    # Download GitHub Release zip and calculate checksum
    log::info "PODS" "Downloading zip from GitHub Release to verify..."
    local temp_verify="/tmp/msp-verify-github-release-$$"
    mkdir -p "$temp_verify"

    local github_checksum=""
    local download_success=false

    # Try to download with timeout (30 seconds max)
    if timeout 30 curl -L -f -s -o "$temp_verify/verify.zip" "$zip_url" 2>/dev/null; then
        local file_size
        file_size=$(stat -f%z "$temp_verify/verify.zip" 2>/dev/null || stat -c%s "$temp_verify/verify.zip" 2>/dev/null || echo "0")

        if [[ $file_size -gt 0 ]]; then
            # R031d: Use checksum.sh module if available, fallback to direct shasum
            if command -v checksum_compute_sha256 &>/dev/null; then
                github_checksum=$(checksum_compute_sha256 "$temp_verify/verify.zip")
            else
                github_checksum=$(shasum -a 256 "$temp_verify/verify.zip" 2>/dev/null | awk '{print $1}')
            fi
            if [[ -n "$github_checksum" && ${#github_checksum} -eq 64 ]]; then
                download_success=true
                log::info "PODS" "GitHub Release checksum: $github_checksum"
            else
                log::warn "PODS" "Downloaded file but checksum calculation failed"
            fi
        else
            log::warn "PODS" "Downloaded file is empty (0 bytes)"
        fi
    else
        log::warn "PODS" "Failed to download GitHub Release zip (timeout or 404)"
    fi

    rm -rf "$temp_verify"

    # Compare checksums
    if [[ "$download_success" == "true" ]]; then
        if [[ "$local_checksum" == "$github_checksum" ]]; then
            log::success "PODS" "GitHub Release zip matches local zip"
            log::success "PODS" "Checksum verified: $local_checksum"
            log::info "PODS" "No action needed - GitHub Release is correct"
            return 0
        else
            log::warn "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log::warn "PODS" "CRITICAL: GitHub Release zip MISMATCH detected!"
            log::warn "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log::warn "PODS" "Local zip checksum:      $local_checksum  <- CORRECT"
            log::warn "PODS" "GitHub Release checksum: $github_checksum  <- WRONG"
            log::info "PODS" ""
            log::info "PODS" "Applying automatic fix..."

            # Use unified upload function with force re-upload
            local old_force_reupload="${MSP_FORCE_REUPLOAD:-false}"
            export MSP_FORCE_REUPLOAD=true

            if upload_zip_to_github "$version" "$local_zip"; then
                export MSP_FORCE_REUPLOAD="$old_force_reupload"
                log::success "PODS" "Upload completed successfully"

                # Wait for CDN propagation
                local file_size_bytes
                file_size_bytes=$(stat -f%z "$local_zip" 2>/dev/null || stat -c%s "$local_zip" 2>/dev/null || echo "0")
                local file_size_mb=$((file_size_bytes / 1024 / 1024))
                local wait_time=60

                if [[ $file_size_mb -ge 15 ]]; then
                    wait_time=120
                elif [[ $file_size_mb -ge 5 ]]; then
                    wait_time=90
                fi

                log::info "PODS" "Waiting ${wait_time} seconds for CDN propagation..."
                sleep $wait_time

                log::success "PODS" "Automatic fix completed"
                return 0
            else
                export MSP_FORCE_REUPLOAD="$old_force_reupload"
                log::error "PODS" "Automatic fix failed"
                return 1
            fi
        fi
    else
        log::warn "PODS" "Cannot verify GitHub Release zip"
        log::warn "PODS" "Continuing with Resume (pod already published)..."
        return 0
    fi
}

# ============================================================================
# Probe Zip URL Availability
# ============================================================================
# R010: This function now delegates to the shared module's github_release_probe_url
#
# Args:
#   $1: pod - Pod name
#   $2: version - Release version
# Returns:
#   0 if URL is accessible, 1 if not
# ============================================================================
probe_zip_url() {
    local pod="$1"
    local version="$2"
    local repo="${MSP_GITHUB_REPO:-ParticleMedia/msp-ios-sdk-public}"
    local zip_url="https://github.com/${repo}/releases/download/${version}/${pod}-${version}.zip"

    # R010: Delegate to shared module if available
    if command -v github_release_probe_url &>/dev/null; then
        github_release_probe_url "$zip_url" "PODS"
        return $?
    fi

    # Fallback: Original implementation
    local max_attempts=12
    local sleep_seconds=5

    log::step "PODS" "Probing zip URL availability: $zip_url"

    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if curl -sSfL --head "$zip_url" >/dev/null 2>&1; then
            log::success "PODS" "Zip URL is accessible: $zip_url"
            return 0
        else
            if [[ $attempt -lt $max_attempts ]]; then
                log::info "PODS" "Zip URL not yet accessible (attempt $attempt/$max_attempts), waiting ${sleep_seconds}s..."
                sleep "$sleep_seconds"
            else
                log::error "PODS" "[FAIL-FAST] Zip URL not accessible after $max_attempts attempts: $zip_url"
                log::error "PODS" "Binary zip must be available before pod trunk push (HTTP distribution)"
                return 1
            fi
        fi
        ((attempt++)) || true
    done

    return 1
}

# ============================================================================
# Create GitHub Release for Pod
# ============================================================================
# Create GitHub release and upload zip for a specific pod
#
# Args:
#   $1: pod - Pod name
#   $2: version - Release version
# Returns:
#   0 if success, 1 if failure
# ============================================================================
create_github_release_for_pod() {
    local pod="$1"
    local version="$2"

    log::step "PODS" "Creating GitHub release for $pod"

    # Start timing
    if command -v metrics::start &>/dev/null; then
        metrics::start "publish_${pod}_github_release"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log::info "PODS" "DRY RUN: Would create GitHub release for $pod version $version"
        if command -v metrics::end &>/dev/null; then
            metrics::end "publish_${pod}_github_release"
        fi
        return 0
    fi

    # Only binary distribution pods need GitHub release
    if ! is_binary_distribution "$pod"; then
        log::info "PODS" "Non-binary distribution pod $pod, skipping GitHub release creation"
        if command -v metrics::end &>/dev/null; then
            metrics::end "publish_${pod}_github_release"
        fi
        return 0
    fi

    local zip_name="${pod}-${version}.zip"
    local local_zip_path="$ROOT_DIR/Build/Zips/$zip_name"

    # Ensure zip exists
    if [[ -f "$local_zip_path" ]]; then
        local zip_size
        zip_size=$(stat -f%z "$local_zip_path" 2>/dev/null || stat -c%s "$local_zip_path" 2>/dev/null || echo "0")
        if [[ $zip_size -gt 0 ]]; then
            log::info "PODS" "Using existing zip file: $local_zip_path (size: $zip_size bytes)"
        else
            log::warn "PODS" "Local zip exists but is empty, recreating..."
            if ! create_zip_from_xcframework "$pod" "$version"; then
                log::error "PODS" "Failed to create zip file from XCFramework"
                return 1
            fi
        fi
    else
        if ! create_zip_from_xcframework "$pod" "$version"; then
            log::error "PODS" "Failed to create zip file from XCFramework"
            return 1
        fi
        log::info "PODS" "Created zip file: $local_zip_path"
    fi

    if [[ ! -f "$local_zip_path" ]]; then
        log::error "PODS" "Zip file not found after creation: $local_zip_path"
        return 1
    fi

    # Create/verify GitHub Release
    if ! create_or_verify_github_release "$version"; then
        log::error "PODS" "Failed to create/verify GitHub Release"
        return 1
    fi

    # Upload zip
    if ! upload_zip_to_github "$version" "$local_zip_path"; then
        log::error "PODS" "Failed to upload zip to GitHub Release"
        return 1
    fi

    # Wait for CDN and verify
    local file_size_mb
    file_size_mb=$(du -m "$local_zip_path" 2>/dev/null | awk '{print $1}' || echo "5")
    local cdn_wait_time=60
    if [[ $file_size_mb -lt 5 ]]; then
        cdn_wait_time=60
    elif [[ $file_size_mb -lt 20 ]]; then
        cdn_wait_time=90
    else
        cdn_wait_time=120
    fi

    export MSP_CDN_WAIT_TIME=$cdn_wait_time
    wait_for_cdn_propagation "$version"

    if ! verify_cdn_availability "$version" "$zip_name"; then
        log::error "PODS" "Failed to verify GitHub Release upload"
        return 1
    fi

    # Update state: Mark GitHub Release as created
    if command -v msp_state_set_pod_github_release_created &>/dev/null; then
        local release_url="https://github.com/${GITHUB_REPO:-ParticleMedia/msp-ios-sdk-public}/releases/tag/${version}"
        msp_state_set_pod_github_release_created "$pod" "true"
        msp_state_set_pod_github_release_url "$pod" "$release_url"
        log::debug "PODS" "Updated state: $pod github_release_created=true"
    fi

    log::success "PODS" "GitHub release created and zip uploaded for $pod"

    if command -v metrics::end &>/dev/null; then
        metrics::end "publish_${pod}_github_release"
    fi

    return 0
}

# ============================================================================
# Export Functions
# ============================================================================

export -f prepare_github_release 2>/dev/null || true
export -f verify_and_fix_github_release_zip 2>/dev/null || true
export -f probe_zip_url 2>/dev/null || true
export -f create_github_release_for_pod 2>/dev/null || true
