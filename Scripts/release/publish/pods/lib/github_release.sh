#!/usr/bin/env bash
# ============================================================================
# GitHub Release Module
# ============================================================================
# Module: github_release.sh
# Purpose: GitHub Release creation, verification, and asset upload
# Extracted from: publish.sh (T100)
#
# Functions:
#   - create_or_verify_github_release: Create or verify GitHub release exists
#   - generate_release_notes: Generate default release notes
#   - upload_zip_to_github: Upload single zip to release
#   - upload_all_zips_to_github: Batch upload zips to release
#
# Dependencies:
#   - gh CLI (GitHub CLI)
#   - Logging functions (log_info, log_error, log_success, log_warning, log_debug)
#
# Environment Variables:
#   - DRY_RUN: Controls draft vs published (default: false)
#   - MSP_GITHUB_REPO: GitHub repository (default: ParticleMedia/msp-ios-sdk-public)
#   - MSP_ALLOW_EXISTING_RELEASE: Allow existing release with different state (default: false)
#   - MSP_FORCE_REUPLOAD: Force re-upload even if asset exists (default: false)
#   - MSP_CDN_WAIT_TIME: CDN propagation wait time (default: 120)
#   - RELEASE_NOTES: CLI-provided release notes (optional)
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_GITHUB_RELEASE_SOURCED:-}" ]] && return 0
readonly _GITHUB_RELEASE_SOURCED=1

# ============================================================================
# R009: Source Shared GitHub Release Module
# ============================================================================
# This module now delegates to the unified shared module for all GitHub
# Release operations. The functions below are wrappers that maintain
# backward compatibility while using the shared implementation.
# ============================================================================

_PODS_GH_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
if [[ -f "$_PODS_GH_ROOT_DIR/Scripts/lib/shared/github_release.sh" ]]; then
    # shellcheck source=Scripts/lib/shared/github_release.sh
    source "$_PODS_GH_ROOT_DIR/Scripts/lib/shared/github_release.sh" 2>/dev/null || true
fi

# ============================================================================
# Module Initialization
# ============================================================================

_github_release_init() {
    # Verify gh CLI is available
    if ! command -v gh &>/dev/null; then
        echo "[ERROR] GitHub CLI (gh) is not installed" >&2
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

# Create or verify GitHub release
# @description Creates a new GitHub release or verifies existing one matches expected state
# R009: Now delegates to shared module when available
# @param $1 tag - Release tag (e.g., "1.0.0")
# @return 0 if success, 1 if failure
# @env DRY_RUN - Controls draft vs published (default: false)
# @env MSP_GITHUB_REPO - GitHub repository (default: ParticleMedia/msp-ios-sdk-public)
# @env MSP_ALLOW_EXISTING_RELEASE - Allow existing release with different state (default: false)
create_or_verify_github_release() {
    local tag="$1"

    # R009: Delegate to shared module if available
    if command -v github_release_create_or_verify &>/dev/null; then
        github_release_create_or_verify "$tag" "PODS"
        return $?
    fi

    # Fallback: Original implementation
    local dry_run="${DRY_RUN:-false}"
    local repo="${MSP_GITHUB_REPO:-ParticleMedia/msp-ios-sdk-public}"

    log::info "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "PODS" "GitHub Release: $tag"
    log::info "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Determine expected state
    local expected_draft
    if [[ "$dry_run" == "true" ]]; then
        expected_draft="true"
        log::info "PODS" "Mode: DRY_RUN (draft release)"
    else
        expected_draft="false"
        log::info "PODS" "Mode: PRODUCTION (published release)"
    fi

    # Check if release already exists
    if gh release view "$tag" --repo "$repo" >/dev/null 2>&1; then
        log::info "PODS" "✓ Release $tag already exists"

        # Get current state
        local current_draft
        current_draft=$(gh release view "$tag" --repo "$repo" --json isDraft -q '.isDraft' 2>/dev/null || echo "false")

        log::debug "PODS" "Current state: draft=$current_draft"
        log::debug "PODS" "Expected state: draft=$expected_draft"

        # Verify state matches expectation
        if [[ "$current_draft" == "$expected_draft" ]]; then
            log::success "PODS" "✓ Release state is correct"
            return 0
        else
            log::warn "PODS" "Release state mismatch:"
            log::warn "PODS" "  Current:  draft=$current_draft"
            log::warn "PODS" "  Expected: draft=$expected_draft"

            # Handle mismatch
            if [[ "${MSP_ALLOW_EXISTING_RELEASE:-false}" == "true" ]]; then
                log::warn "PODS" "Continuing with existing release (MSP_ALLOW_EXISTING_RELEASE=true)"

                # Auto-fix: Publish draft release if production mode expects published
                if [[ "$current_draft" == "true" ]] && [[ "$expected_draft" == "false" ]]; then
                    log::info "PODS" "Auto-fixing: Publishing draft release to enable CDN access"
                    log::info "PODS" "Reason: Draft releases are private, CDN URLs will return 404"
                    log::info "PODS" "Action: gh release edit $tag --repo $repo --draft=false"

                    if gh release edit "$tag" --repo "$repo" --draft=false 2>&1 | tee /tmp/gh-release-publish-$tag.log; then
                        log::success "PODS" "✅ Published draft release: $tag"
                        log::info "PODS" "Waiting 10 seconds for GitHub to propagate release state..."
                        sleep 10

                        # Verify release is now published
                        local new_draft
                        new_draft=$(gh release view "$tag" --repo "$repo" --json isDraft -q '.isDraft' 2>/dev/null || echo "false")
                        if [[ "$new_draft" == "false" ]]; then
                            log::success "PODS" "✅ Release state verified: published"
                        else
                            log::warn "PODS" "⚠️ Release state still draft after publish attempt"
                            log::warn "PODS" "⚠️ CDN verification may still fail"
                        fi
                    else
                        log::error "PODS" "❌ Failed to publish draft release"
                        log::error "PODS" "Check log: /tmp/gh-release-publish-$tag.log"
                        log::warn "PODS" "Continuing anyway (MSP_ALLOW_EXISTING_RELEASE=true)"
                    fi
                elif [[ "$current_draft" == "false" ]] && [[ "$expected_draft" == "true" ]]; then
                    # Edge case: Published release but dry-run mode expects draft
                    log::warn "PODS" "⚠️ Release is published but DRY_RUN mode expects draft"
                    log::warn "PODS" "⚠️ Continuing with published release (safe, non-destructive)"
                fi

                return 0
            else
                log::error "PODS" "Release state mismatch"
                log::error "PODS" "Options:"
                log::error "PODS" "  1. Set MSP_ALLOW_EXISTING_RELEASE=true to use existing release"
                log::error "PODS" "  2. Delete release: gh release delete $tag --repo $repo --yes"
                log::error "PODS" "  3. Change DRY_RUN to match existing state"
                return 1
            fi
        fi
    fi

    # Release doesn't exist, create it
    log::info "PODS" "Creating GitHub Release: $tag"

    # Use RELEASE_NOTES from CLI if provided, otherwise generate default notes
    local release_notes
    if [[ -n "${RELEASE_NOTES:-}" ]]; then
        log::info "PODS" "Using release notes from CLI (--release-notes)"
        release_notes="$RELEASE_NOTES"
    else
        release_notes=$(generate_release_notes "$tag")
    fi

    local create_args=(
        "$tag"
        --repo "$repo"
        --title "Release $tag"
        --notes "$release_notes"
    )

    if [[ "$expected_draft" == "true" ]]; then
        create_args+=(--draft)
        log::info "PODS" "Creating DRAFT release (DRY_RUN mode)"
    else
        log::info "PODS" "Creating PUBLISHED release (production mode)"
    fi

    # Create release
    if gh release create "${create_args[@]}" 2>&1 | tee /tmp/gh-release-create-$tag.log; then
        log::success "PODS" "✓ Created GitHub Release: $tag"
        return 0
    else
        log::error "PODS" "✗ Failed to create GitHub Release: $tag"
        log::error "PODS" "See log: /tmp/gh-release-create-$tag.log"
        return 1
    fi
}

# Generate release notes
# @description Generates default release notes for a version
# R009: Now delegates to shared module when available
# @param $1 tag - Release tag
# @return Prints release notes to stdout
generate_release_notes() {
    local tag="$1"

    # R009: Delegate to shared module if available
    if command -v github_release_generate_notes &>/dev/null; then
        github_release_generate_notes "$tag"
        return $?
    fi

    # Fallback: Original implementation
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
- MSPMolocoAdapter (if applicable)
- MSPLiftoffAdapter (if applicable)
- MSPApplovinMaxAdapter (if applicable)

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

## Changes

See commit history for detailed changes in this release.

---

🚀 Generated with [Claude Code](https://claude.com/claude-code)
EOF
}

# Upload zip to GitHub Release (idempotent)
# @description Uploads a single zip file to GitHub release
# R009: Now delegates to shared module when available
# @param $1 tag - Release tag
# @param $2 zip_path - Path to zip file
# @return 0 if success, 1 if failure
# @env MSP_GITHUB_REPO - GitHub repository
# @env MSP_FORCE_REUPLOAD - Force re-upload even if asset exists
upload_zip_to_github() {
    local tag="$1"
    local zip_path="$2"

    # R009: Delegate to shared module if available
    if command -v github_release_upload_asset &>/dev/null; then
        github_release_upload_asset "$tag" "$zip_path" "PODS"
        return $?
    fi

    # Fallback: Original implementation
    local repo="${MSP_GITHUB_REPO:-ParticleMedia/msp-ios-sdk-public}"

    local zip_name
    zip_name=$(basename "$zip_path")

    log::info "PODS" "Uploading: $zip_name"

    # Verify zip file exists
    if [[ ! -f "$zip_path" ]]; then
        log::error "PODS" "Zip file not found: $zip_path"
        return 1
    fi

    # Check if already uploaded (idempotency)
    if gh release view "$tag" --repo "$repo" --json assets -q ".assets[] | select(.name == \"$zip_name\")" 2>/dev/null | grep -q "$zip_name"; then
        log::info "PODS" "✓ $zip_name already uploaded"

        # Optional: Verify file size matches
        local remote_size
        remote_size=$(gh release view "$tag" --repo "$repo" --json assets -q ".assets[] | select(.name == \"$zip_name\") | .size" 2>/dev/null || echo "0")
        local local_size
        local_size=$(stat -f%z "$zip_path" 2>/dev/null || stat -c%s "$zip_path" 2>/dev/null || echo "0")

        if [[ "$remote_size" == "$local_size" ]] && [[ "$remote_size" != "0" ]]; then
            log::debug "PODS" "File size matches: $local_size bytes"
        else
            log::warn "PODS" "File size mismatch: remote=$remote_size, local=$local_size"
            if [[ "${MSP_FORCE_REUPLOAD:-false}" == "true" ]]; then
                log::info "PODS" "Re-uploading (MSP_FORCE_REUPLOAD=true)..."
            else
                log::warn "PODS" "Skipping re-upload (set MSP_FORCE_REUPLOAD=true to force)"
                return 0
            fi
        fi

        if [[ "${MSP_FORCE_REUPLOAD:-false}" != "true" ]]; then
            return 0
        fi
    fi

    # Upload
    log::debug "PODS" "Uploading $zip_path to release $tag"
    if gh release upload "$tag" "$zip_path" --repo "$repo" --clobber 2>&1 | tee /tmp/gh-upload-$zip_name.log; then
        log::success "PODS" "✓ Uploaded $zip_name"
        return 0
    else
        log::error "PODS" "✗ Failed to upload $zip_name"
        log::error "PODS" "See log: /tmp/gh-upload-$zip_name.log"
        return 1
    fi
}

# Upload all zips to GitHub Release (batch operation)
# @description Uploads multiple zip files to GitHub release
# R009: Now delegates to shared module when available
# @param $1 tag - Release tag
# @param $@ zip_paths - Array of zip file paths
# @return 0 if all succeed, 1 if any fail
upload_all_zips_to_github() {
    local tag="$1"
    shift
    local zip_paths=("$@")

    # R009: Delegate to shared module if available
    if command -v github_release_upload_assets &>/dev/null; then
        github_release_upload_assets "$tag" "PODS" "${zip_paths[@]}"
        return $?
    fi

    # Fallback: Original implementation
    log::info "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "PODS" "Uploading Zips to GitHub Release"
    log::info "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "PODS" "Release: $tag"
    log::info "PODS" "Zips: ${#zip_paths[@]}"

    local failed=0
    local uploaded=0
    local skipped=0

    for zip_path in "${zip_paths[@]}"; do
        if [[ ! -f "$zip_path" ]]; then
            log::warn "PODS" "Zip not found, skipping: $zip_path"
            ((skipped++)) || true
            continue
        fi

        if upload_zip_to_github "$tag" "$zip_path"; then
            ((uploaded++)) || true
        else
            ((failed++)) || true
        fi
    done

    log::info "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "PODS" "Upload Summary:"
    log::info "PODS" "  Total:    ${#zip_paths[@]}"
    log::info "PODS" "  Uploaded: $uploaded"
    log::info "PODS" "  Skipped:  $skipped"
    log::info "PODS" "  Failed:   $failed"

    if [[ $failed -gt 0 ]]; then
        log::error "PODS" "Upload failed: $failed zip(s) failed to upload"
        log::error "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    else
        log::success "PODS" "All zips uploaded ✓"
        log::success "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 0
    fi
}

# ============================================================================
# Export Functions
# ============================================================================

export -f create_or_verify_github_release
export -f generate_release_notes
export -f upload_zip_to_github
export -f upload_all_zips_to_github
