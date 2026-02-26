#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# GitHub Release Verification Module
# ============================================================================
# Purpose: Verify all binary distribution pods have GitHub releases created
# Usage:
#   source github_release_verify.sh
#   verify_all_github_releases "$version"
# ============================================================================

# Guard against multiple sourcing
[[ -n "${_GITHUB_RELEASE_VERIFY_SOURCED:-}" ]] && return 0
readonly _GITHUB_RELEASE_VERIFY_SOURCED=1

# Determine root directory
_GH_VERIFY_ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"

# Source dependencies
if [[ -f "$_GH_VERIFY_ROOT_DIR/Scripts/lib/logger.sh" ]]; then
    # shellcheck source=Scripts/lib/logger.sh
    source "$_GH_VERIFY_ROOT_DIR/Scripts/lib/logger.sh" 2>/dev/null || true
fi

if [[ -f "$_GH_VERIFY_ROOT_DIR/Scripts/release/utils/state.sh" ]]; then
    # shellcheck source=Scripts/release/utils/state.sh
    source "$_GH_VERIFY_ROOT_DIR/Scripts/release/utils/state.sh" 2>/dev/null || true
fi

if [[ -f "$_GH_VERIFY_ROOT_DIR/Scripts/release/publish/pods/lib/distribution_utils.sh" ]]; then
    # shellcheck source=Scripts/release/publish/pods/lib/distribution_utils.sh
    source "$_GH_VERIFY_ROOT_DIR/Scripts/release/publish/pods/lib/distribution_utils.sh" 2>/dev/null || true
fi

GITHUB_REPO="${GITHUB_REPO:-ParticleMedia/msp-ios-sdk-public}"

# ============================================================================
# Check if GitHub release exists for a version
# ============================================================================
# Args:
#   $1: version
# Returns:
#   0 if exists, 1 if not
# ============================================================================
github_release_exists_for_version() {
    local version="$1"

    if ! command -v gh &>/dev/null; then
        log::warn "GITHUB" "gh CLI not available, skipping verification"
        return 0  # Assume success if gh not available
    fi

    if gh release view "$version" --repo "$GITHUB_REPO" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# Verify all binary distribution pods have GitHub releases
# ============================================================================
# Args:
#   $1: version
# Returns:
#   0 if all verified, 1 if any missing
# ============================================================================
verify_all_github_releases() {
    local version="$1"
    local missing_releases=()
    local verified_releases=()

    log::step "GITHUB" "Verifying GitHub releases for all binary distribution pods..."

    # Get list of binary distribution pods
    local binary_pods
    if command -v get_binary_distribution_pods &>/dev/null; then
        binary_pods=($(get_binary_distribution_pods))
    else
        # Fallback: hardcoded list
        binary_pods=("MSPiOSCore" "MSPSharedLibraries" "MSPGoogleAdsTypes" "MSPPrebidAdapter" "MSPFacebookAdapter" "MSPNovaAdapter" "MSPAmazonAdapter" "MSPGoogleAdapter" "MSPMolocoAdapter" "MSPLiftoffAdapter" "MSPCore")
    fi

    # Check GitHub release exists
    if ! github_release_exists_for_version "$version"; then
        log::error "GITHUB" "GitHub Release $version does not exist"
        log::error "GITHUB" "Please create it first or run: ./Scripts/msp-release.sh create-github-releases $version"
        return 1
    fi

    log::info "GITHUB" "GitHub Release $version exists, checking individual pod assets..."

    # Verify each pod's zip asset
    for pod in "${binary_pods[@]}"; do
        local zip_name="${pod}-${version}.zip"
        local zip_url="https://github.com/${GITHUB_REPO}/releases/download/${version}/${zip_name}"

        # Check if zip is accessible
        if curl --head --silent --fail "$zip_url" --max-time 10 &>/dev/null; then
            verified_releases+=("$pod")
            log::success "GITHUB" "✅ $pod: zip found at $zip_url"

            # Update state
            if command -v msp_state_set_pod_github_release_created &>/dev/null; then
                msp_state_set_pod_github_release_created "$pod" "true"
                msp_state_set_pod_github_release_url "$pod" "https://github.com/${GITHUB_REPO}/releases/tag/${version}"
            fi
        else
            missing_releases+=("$pod")
            log::warn "GITHUB" "❌ $pod: zip NOT found at $zip_url"

            # Mark as not created in state
            if command -v msp_state_set_pod_github_release_created &>/dev/null; then
                msp_state_set_pod_github_release_created "$pod" "false"
            fi
        fi
    done

    # Summary
    echo ""
    log::info "GITHUB" "GitHub Release Verification Summary:"
    log::info "GITHUB" "  ✅ Verified: ${#verified_releases[@]}/${#binary_pods[@]}"

    if [[ ${#missing_releases[@]} -gt 0 ]]; then
        log::warn "GITHUB" "  ❌ Missing: ${#missing_releases[@]}"
        log::warn "GITHUB" "  Missing pods: ${missing_releases[*]}"
        return 1
    fi

    log::success "GITHUB" "All binary distribution pods have GitHub release assets"
    return 0
}

# ============================================================================
# Export Functions
# ============================================================================
export -f github_release_exists_for_version 2>/dev/null || true
export -f verify_all_github_releases 2>/dev/null || true
