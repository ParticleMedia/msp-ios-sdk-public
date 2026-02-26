#!/usr/bin/env bash
# ============================================================================
# Shared GitHub Release Module (R007)
# ============================================================================
# Module: lib/shared/github_release.sh
# Purpose: Unified GitHub Release operations for CocoaPods and SPM releases
#
# Functions:
#   - github_release_create_or_verify: Create or verify a GitHub release exists
#   - github_release_upload_asset: Upload a single asset (idempotent)
#   - github_release_upload_assets: Batch upload multiple assets
#   - github_release_prepare: Full workflow (create, upload, CDN wait, verify)
#   - github_release_verify_asset: Verify asset checksum matches local
#   - github_release_probe_url: Probe URL availability with retries
#   - github_release_generate_notes: Generate default release notes
#   - github_release_ensure_exists: Ensure release exists (idempotent)
#
# Environment Variables:
#   - MSP_GITHUB_REPO: GitHub repository (default: ParticleMedia/msp-ios-sdk-public)
#   - DRY_RUN: Controls draft vs published (default: false)
#   - MSP_ALLOW_EXISTING_RELEASE: Allow existing release with different state
#   - MSP_FORCE_REUPLOAD: Force re-upload even if asset exists
#   - MSP_CDN_WAIT_TIME: CDN propagation wait time (default: 120)
#   - MSP_GITHUB_UPLOAD_MAX_RETRIES: Max upload retry attempts (default: 3)
#   - MSP_GITHUB_PROBE_MAX_ATTEMPTS: Max URL probe attempts (default: 12)
#   - MSP_GITHUB_PROBE_SLEEP_SECONDS: Delay between probes (default: 5)
#   - RELEASE_NOTES: CLI-provided release notes (optional)
#
# Dependencies:
#   - gh CLI (GitHub CLI)
#   - curl CLI
#   - Logging functions (log::info, log::error, log::success)
#   - checksum.sh (optional, for verification)
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_SHARED_GITHUB_RELEASE_SOURCED:-}" ]] && return 0
readonly _SHARED_GITHUB_RELEASE_SOURCED=1

# ============================================================================
# Configuration Defaults
# ============================================================================

GITHUB_RELEASE_DEFAULT_REPO="ParticleMedia/msp-ios-sdk-public"
GITHUB_RELEASE_DEFAULT_UPLOAD_MAX_RETRIES=3
GITHUB_RELEASE_DEFAULT_PROBE_MAX_ATTEMPTS=12
GITHUB_RELEASE_DEFAULT_PROBE_SLEEP_SECONDS=5
GITHUB_RELEASE_DEFAULT_CDN_WAIT_TIME=120

# ============================================================================
# Internal Helpers
# ============================================================================

_github_release_log() {
    local level="$1"
    local tag="${2:-GH}"
    local msg="$3"

    if command -v "log::${level}" &>/dev/null; then
        "log::${level}" "$tag" "$msg"
    else
        echo "[$level][$tag] $msg" >&2
    fi
}

_github_release_get_repo() {
    echo "${MSP_GITHUB_REPO:-$GITHUB_RELEASE_DEFAULT_REPO}"
}

# ============================================================================
# Create or Verify GitHub Release (Idempotent)
# ============================================================================
# @description Creates a new GitHub release or verifies existing one matches expected state
# @param $1 tag - Release tag (e.g., "1.0.0")
# @param $2 log_tag - Optional log tag (default: GH)
# @return 0 if success, 1 if failure
# @env DRY_RUN - Controls draft vs published (default: false)
# @env MSP_GITHUB_REPO - GitHub repository
# @env MSP_ALLOW_EXISTING_RELEASE - Allow existing release with different state
# ============================================================================
github_release_create_or_verify() {
    local tag="$1"
    local log_tag="${2:-GH}"
    local dry_run="${DRY_RUN:-false}"
    local repo
    repo=$(_github_release_get_repo)

    _github_release_log "info" "$log_tag" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    _github_release_log "info" "$log_tag" "GitHub Release: $tag"
    _github_release_log "info" "$log_tag" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Verify gh CLI is available
    if ! command -v gh &>/dev/null; then
        _github_release_log "error" "$log_tag" "GitHub CLI (gh) is not installed"
        return 1
    fi

    # Determine expected state
    local expected_draft
    if [[ "$dry_run" == "true" ]]; then
        expected_draft="true"
        _github_release_log "info" "$log_tag" "Mode: DRY_RUN (draft release)"
    else
        expected_draft="false"
        _github_release_log "info" "$log_tag" "Mode: PRODUCTION (published release)"
    fi

    # Check if release already exists
    if gh release view "$tag" --repo "$repo" >/dev/null 2>&1; then
        _github_release_log "info" "$log_tag" "✓ Release $tag already exists"

        # Get current state
        local current_draft
        current_draft=$(gh release view "$tag" --repo "$repo" --json isDraft -q '.isDraft' 2>/dev/null || echo "false")

        # Verify state matches expectation
        if [[ "$current_draft" == "$expected_draft" ]]; then
            _github_release_log "success" "$log_tag" "✓ Release state is correct"
            return 0
        else
            _github_release_log "warn" "$log_tag" "Release state mismatch: current=$current_draft, expected=$expected_draft"

            # Handle mismatch
            if [[ "${MSP_ALLOW_EXISTING_RELEASE:-false}" == "true" ]]; then
                _github_release_log "warn" "$log_tag" "Continuing with existing release (MSP_ALLOW_EXISTING_RELEASE=true)"

                # Auto-fix: Publish draft release if production mode expects published
                if [[ "$current_draft" == "true" ]] && [[ "$expected_draft" == "false" ]]; then
                    _github_release_log "info" "$log_tag" "Auto-fixing: Publishing draft release"
                    if gh release edit "$tag" --repo "$repo" --draft=false 2>&1; then
                        _github_release_log "success" "$log_tag" "✅ Published draft release: $tag"
                        sleep 10
                    else
                        _github_release_log "warn" "$log_tag" "⚠️ Failed to publish draft release"
                    fi
                fi
                return 0
            else
                _github_release_log "error" "$log_tag" "Release state mismatch. Set MSP_ALLOW_EXISTING_RELEASE=true to override"
                return 1
            fi
        fi
    fi

    # Release doesn't exist, create it
    _github_release_log "info" "$log_tag" "Creating GitHub Release: $tag"

    # Use RELEASE_NOTES from CLI if provided, otherwise generate default notes
    local release_notes
    if [[ -n "${RELEASE_NOTES:-}" ]]; then
        _github_release_log "info" "$log_tag" "Using release notes from CLI"
        release_notes="$RELEASE_NOTES"
    else
        release_notes=$(github_release_generate_notes "$tag")
    fi

    local create_args=(
        "$tag"
        --repo "$repo"
        --title "Release $tag"
        --notes "$release_notes"
    )

    if [[ "$expected_draft" == "true" ]]; then
        create_args+=(--draft)
        _github_release_log "info" "$log_tag" "Creating DRAFT release (DRY_RUN mode)"
    else
        _github_release_log "info" "$log_tag" "Creating PUBLISHED release (production mode)"
    fi

    # Create release
    if gh release create "${create_args[@]}" 2>&1; then
        _github_release_log "success" "$log_tag" "✓ Created GitHub Release: $tag"
        return 0
    else
        _github_release_log "error" "$log_tag" "✗ Failed to create GitHub Release: $tag"
        return 1
    fi
}

# ============================================================================
# Ensure GitHub Release Exists (Idempotent Creation)
# ============================================================================
# @description Ensures a GitHub release exists, creating if necessary
# @param $1 tag - Release tag
# @param $2 log_tag - Optional log tag
# @return 0 if success
# ============================================================================
github_release_ensure_exists() {
    local tag="$1"
    local log_tag="${2:-GH}"
    local repo
    repo=$(_github_release_get_repo)

    if gh release view "$tag" --repo "$repo" >/dev/null 2>&1; then
        _github_release_log "info" "$log_tag" "✓ Release $tag already exists"
        return 0
    fi

    github_release_create_or_verify "$tag" "$log_tag"
}

# ============================================================================
# Upload Single Asset to GitHub Release (Idempotent)
# ============================================================================
# @description Uploads a single asset to GitHub release with idempotency checks
# @param $1 tag - Release tag
# @param $2 asset_path - Path to the asset file
# @param $3 log_tag - Optional log tag
# @return 0 if success, 1 if failure
# ============================================================================
github_release_upload_asset() {
    local tag="$1"
    local asset_path="$2"
    local log_tag="${3:-GH}"
    local repo
    repo=$(_github_release_get_repo)
    local max_retries="${MSP_GITHUB_UPLOAD_MAX_RETRIES:-$GITHUB_RELEASE_DEFAULT_UPLOAD_MAX_RETRIES}"

    local asset_name
    asset_name=$(basename "$asset_path")

    _github_release_log "info" "$log_tag" "Uploading: $asset_name"

    # Verify asset file exists
    if [[ ! -f "$asset_path" ]]; then
        _github_release_log "error" "$log_tag" "Asset file not found: $asset_path"
        return 1
    fi

    # Idempotency: Check if already uploaded
    local local_size
    local_size=$(stat -f%z "$asset_path" 2>/dev/null || stat -c%s "$asset_path" 2>/dev/null || echo "0")

    local remote_asset_info
    remote_asset_info=$(gh release view "$tag" --repo "$repo" --json assets -q ".assets[] | select(.name == \"$asset_name\")" 2>/dev/null || echo "")

    if [[ -n "$remote_asset_info" ]]; then
        local remote_size
        remote_size=$(echo "$remote_asset_info" | grep -o '"size":[0-9]*' | cut -d: -f2 || echo "0")

        if [[ "$local_size" == "$remote_size" ]] && [[ "$local_size" != "0" ]]; then
            if [[ "${MSP_FORCE_REUPLOAD:-false}" != "true" ]]; then
                _github_release_log "info" "$log_tag" "✓ $asset_name already uploaded ($local_size bytes)"
                return 0
            fi
            _github_release_log "info" "$log_tag" "Re-uploading (MSP_FORCE_REUPLOAD=true)..."
        else
            _github_release_log "info" "$log_tag" "Size mismatch: local=$local_size, remote=$remote_size. Re-uploading..."
        fi
    fi

    # Upload with retry logic
    local retry_count=0
    while [[ $retry_count -lt $max_retries ]]; do
        if gh release upload "$tag" "$asset_path" --repo "$repo" --clobber 2>&1; then
            _github_release_log "success" "$log_tag" "✓ Uploaded $asset_name"
            return 0
        else
            ((retry_count++)) || true
            if [[ $retry_count -lt $max_retries ]]; then
                _github_release_log "warn" "$log_tag" "Upload failed, retrying in 5 seconds... (attempt $retry_count/$max_retries)"
                sleep 5
            fi
        fi
    done

    _github_release_log "error" "$log_tag" "✗ Failed to upload $asset_name after $max_retries attempts"
    return 1
}

# ============================================================================
# Upload Multiple Assets to GitHub Release (Batch)
# ============================================================================
# @description Uploads multiple assets to GitHub release
# @param $1 tag - Release tag
# @param $2 log_tag - Log tag
# @param $@ asset_paths - Array of asset file paths
# @return 0 if all succeed, 1 if any fail
# ============================================================================
github_release_upload_assets() {
    local tag="$1"
    local log_tag="$2"
    shift 2
    local asset_paths=("$@")

    _github_release_log "info" "$log_tag" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    _github_release_log "info" "$log_tag" "Uploading Assets to GitHub Release"
    _github_release_log "info" "$log_tag" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    _github_release_log "info" "$log_tag" "Release: $tag"
    _github_release_log "info" "$log_tag" "Assets: ${#asset_paths[@]}"

    local failed=0
    local uploaded=0
    local skipped=0

    for asset_path in "${asset_paths[@]}"; do
        if [[ ! -f "$asset_path" ]]; then
            _github_release_log "warn" "$log_tag" "Asset not found, skipping: $asset_path"
            ((skipped++)) || true
            continue
        fi

        if github_release_upload_asset "$tag" "$asset_path" "$log_tag"; then
            ((uploaded++)) || true
        else
            ((failed++)) || true
        fi
    done

    _github_release_log "info" "$log_tag" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    _github_release_log "info" "$log_tag" "Upload Summary: Total=${#asset_paths[@]}, Uploaded=$uploaded, Skipped=$skipped, Failed=$failed"

    if [[ $failed -gt 0 ]]; then
        _github_release_log "error" "$log_tag" "Upload failed: $failed asset(s)"
        return 1
    else
        _github_release_log "success" "$log_tag" "All assets uploaded ✓"
        return 0
    fi
}

# ============================================================================
# Probe URL Availability with Retries
# ============================================================================
# @description Probes URL availability with configurable retries
# @param $1 url - URL to probe
# @param $2 log_tag - Optional log tag
# @param $3 max_attempts - Optional max attempts
# @param $4 sleep_seconds - Optional delay between attempts
# @return 0 if URL accessible, 1 otherwise
# ============================================================================
github_release_probe_url() {
    local url="$1"
    local log_tag="${2:-GH}"
    local max_attempts="${3:-${MSP_GITHUB_PROBE_MAX_ATTEMPTS:-$GITHUB_RELEASE_DEFAULT_PROBE_MAX_ATTEMPTS}}"
    local sleep_seconds="${4:-${MSP_GITHUB_PROBE_SLEEP_SECONDS:-$GITHUB_RELEASE_DEFAULT_PROBE_SLEEP_SECONDS}}"

    _github_release_log "step" "$log_tag" "Probing URL availability: $url"

    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if curl -sSfL --head "$url" >/dev/null 2>&1; then
            _github_release_log "success" "$log_tag" "✓ URL is accessible"
            return 0
        else
            if [[ $attempt -lt $max_attempts ]]; then
                _github_release_log "info" "$log_tag" "URL not yet accessible (attempt $attempt/$max_attempts), waiting ${sleep_seconds}s..."
                sleep "$sleep_seconds"
            else
                _github_release_log "error" "$log_tag" "❌ URL not accessible after $max_attempts attempts: $url"
                return 1
            fi
        fi
        ((attempt++)) || true
    done

    return 1
}

# ============================================================================
# Verify Asset Checksum
# ============================================================================
# @description Verifies that remote asset matches local file checksum
# @param $1 tag - Release tag
# @param $2 local_path - Path to local file
# @param $3 log_tag - Optional log tag
# @return 0 if match, 1 if mismatch or error
# ============================================================================
github_release_verify_asset() {
    local tag="$1"
    local local_path="$2"
    local log_tag="${3:-GH}"
    local repo
    repo=$(_github_release_get_repo)

    local asset_name
    asset_name=$(basename "$local_path")
    local url="https://github.com/${repo}/releases/download/${tag}/${asset_name}"

    _github_release_log "info" "$log_tag" "Verifying asset: $asset_name"

    if [[ ! -f "$local_path" ]]; then
        _github_release_log "warn" "$log_tag" "Local file not found: $local_path"
        return 0
    fi

    # Calculate local checksum
    local local_checksum
    if command -v checksum_compute_sha256 &>/dev/null; then
        local_checksum=$(checksum_compute_sha256 "$local_path")
    else
        local_checksum=$(shasum -a 256 "$local_path" 2>/dev/null | awk '{print $1}')
    fi

    if [[ -z "$local_checksum" ]]; then
        _github_release_log "error" "$log_tag" "Failed to calculate local checksum"
        return 1
    fi

    # Download and verify
    local temp_file
    temp_file=$(mktemp)

    if timeout 60 curl -L -f -s -o "$temp_file" "$url" 2>/dev/null; then
        local remote_checksum
        if command -v checksum_compute_sha256 &>/dev/null; then
            remote_checksum=$(checksum_compute_sha256 "$temp_file")
        else
            remote_checksum=$(shasum -a 256 "$temp_file" 2>/dev/null | awk '{print $1}')
        fi

        rm -f "$temp_file"

        if [[ "$local_checksum" == "$remote_checksum" ]]; then
            _github_release_log "success" "$log_tag" "✓ Checksum verified: $asset_name"
            return 0
        else
            _github_release_log "warn" "$log_tag" "Checksum mismatch: local=$local_checksum, remote=$remote_checksum"
            return 1
        fi
    else
        rm -f "$temp_file"
        _github_release_log "warn" "$log_tag" "Failed to download for verification: $url"
        return 1
    fi
}

# ============================================================================
# Prepare GitHub Release (Full Workflow)
# ============================================================================
# @description Full workflow: create release, upload assets, wait for CDN, verify
# @param $1 tag - Release tag
# @param $2 log_tag - Log tag
# @param $@ asset_paths - Array of asset file paths
# @return 0 if success, 1 if failure
# ============================================================================
github_release_prepare() {
    local tag="$1"
    local log_tag="$2"
    shift 2
    local asset_paths=("$@")

    _github_release_log "info" "$log_tag" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    _github_release_log "info" "$log_tag" "Preparing GitHub Release (Full Workflow)"
    _github_release_log "info" "$log_tag" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    _github_release_log "info" "$log_tag" "Tag: $tag"
    _github_release_log "info" "$log_tag" "Assets: ${#asset_paths[@]}"

    # Step 1: Create/verify release
    _github_release_log "info" "$log_tag" ""
    _github_release_log "info" "$log_tag" "Step 1: Create/verify GitHub Release"
    if ! github_release_create_or_verify "$tag" "$log_tag"; then
        _github_release_log "error" "$log_tag" "Failed to create/verify GitHub Release"
        return 1
    fi

    # Step 2: Upload assets
    _github_release_log "info" "$log_tag" ""
    _github_release_log "info" "$log_tag" "Step 2: Upload assets"
    if ! github_release_upload_assets "$tag" "$log_tag" "${asset_paths[@]}"; then
        _github_release_log "error" "$log_tag" "Failed to upload assets"
        return 1
    fi

    # Step 3: Wait for CDN propagation
    local cdn_wait_time="${MSP_CDN_WAIT_TIME:-$GITHUB_RELEASE_DEFAULT_CDN_WAIT_TIME}"
    _github_release_log "info" "$log_tag" ""
    _github_release_log "info" "$log_tag" "Step 3: Waiting ${cdn_wait_time}s for CDN propagation"
    sleep "$cdn_wait_time"

    # Step 4: Verify assets
    _github_release_log "info" "$log_tag" ""
    _github_release_log "info" "$log_tag" "Step 4: Verify asset availability"
    local repo
    repo=$(_github_release_get_repo)
    local verify_failed=0

    for asset_path in "${asset_paths[@]}"; do
        if [[ -f "$asset_path" ]]; then
            local asset_name
            asset_name=$(basename "$asset_path")
            local url="https://github.com/${repo}/releases/download/${tag}/${asset_name}"

            if ! github_release_probe_url "$url" "$log_tag" 3 5; then
                ((verify_failed++)) || true
            fi
        fi
    done

    if [[ $verify_failed -gt 0 ]]; then
        if [[ "${MSP_SKIP_CDN_VERIFICATION:-false}" == "true" ]]; then
            _github_release_log "warn" "$log_tag" "CDN verification failed for $verify_failed asset(s), continuing (MSP_SKIP_CDN_VERIFICATION=true)"
        else
            _github_release_log "error" "$log_tag" "CDN verification failed for $verify_failed asset(s)"
            return 1
        fi
    fi

    _github_release_log "success" "$log_tag" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    _github_release_log "success" "$log_tag" "GitHub Release Ready ✓"
    _github_release_log "success" "$log_tag" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    return 0
}

# ============================================================================
# Generate Default Release Notes
# ============================================================================
# @description Generates default release notes for a version
# @param $1 tag - Release tag
# @return Prints release notes to stdout
# ============================================================================
github_release_generate_notes() {
    local tag="$1"

    cat <<EOF
# MSP iOS SDK Release $tag

## Components

This release includes the following components:
- MSPCore
- MSPSharedLibraries
- MSPPrebidAdapter
- MSPGoogleAdapter
- MSPFacebookAdapter
- MSPNovaAdapter
- MSPAmazonAdapter
- MSPMolocoAdapter
- MSPLiftoffAdapter

## Installation

Add to your \`Podfile\`:
\`\`\`ruby
pod 'MSPCore', '$tag'
# ... other pods as needed
\`\`\`

Then run:
\`\`\`bash
pod install
\`\`\`

## Documentation

See [README.md](https://github.com/ParticleMedia/msp-ios-sdk-public) for complete documentation.

---

Generated with [Claude Code](https://claude.com/claude-code)
EOF
}

# ============================================================================
# Build GitHub Release URL
# ============================================================================
# @description Constructs a GitHub Release download URL
# @param $1 tag - Release tag
# @param $2 asset_name - Asset filename
# @return Prints the constructed URL
# ============================================================================
github_release_build_url() {
    local tag="$1"
    local asset_name="$2"
    local repo
    repo=$(_github_release_get_repo)

    echo "https://github.com/${repo}/releases/download/${tag}/${asset_name}"
}

# ============================================================================
# Backward Compatibility Aliases
# ============================================================================
# These aliases maintain compatibility with existing code that uses the old function names

# From pods/lib/github_release.sh
create_or_verify_github_release() {
    github_release_create_or_verify "$@"
}

generate_release_notes() {
    github_release_generate_notes "$@"
}

upload_zip_to_github() {
    local tag="$1"
    local zip_path="$2"
    github_release_upload_asset "$tag" "$zip_path" "PODS"
}

upload_all_zips_to_github() {
    local tag="$1"
    shift
    github_release_upload_assets "$tag" "PODS" "$@"
}

# From pods/lib/github_release_ext.sh
prepare_github_release() {
    local tag="$1"
    shift
    github_release_prepare "$tag" "PODS" "$@"
}

probe_zip_url() {
    local pod="$1"
    local version="$2"
    local repo
    repo=$(_github_release_get_repo)
    local url="https://github.com/${repo}/releases/download/${version}/${pod}-${version}.zip"
    github_release_probe_url "$url" "PODS"
}

# ============================================================================
# Export Functions
# ============================================================================

export -f github_release_create_or_verify 2>/dev/null || true
export -f github_release_ensure_exists 2>/dev/null || true
export -f github_release_upload_asset 2>/dev/null || true
export -f github_release_upload_assets 2>/dev/null || true
export -f github_release_probe_url 2>/dev/null || true
export -f github_release_verify_asset 2>/dev/null || true
export -f github_release_prepare 2>/dev/null || true
export -f github_release_generate_notes 2>/dev/null || true
export -f github_release_build_url 2>/dev/null || true

# Backward compatibility exports
export -f create_or_verify_github_release 2>/dev/null || true
export -f generate_release_notes 2>/dev/null || true
export -f upload_zip_to_github 2>/dev/null || true
export -f upload_all_zips_to_github 2>/dev/null || true
export -f prepare_github_release 2>/dev/null || true
export -f probe_zip_url 2>/dev/null || true
