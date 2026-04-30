#!/usr/bin/env bash
# ============================================================================
# Create GitHub Releases Command
# ============================================================================
# Purpose: Manually create/verify GitHub releases for all binary distribution pods
# Usage:   msp-release.sh create-github-releases <version>
#
# Dependencies:
#   - Scripts/lib/logger.sh (log::* functions)
#   - Scripts/release/utils/state.sh (state management)
#   - Scripts/release/publish/pods/lib/distribution_utils.sh (binary pod detection)
#   - Scripts/release/publish/pods/lib/github_release_ext.sh (release creation)
# ============================================================================

# Prevent multiple sourcing
[[ -n "${_MSP_CREATE_GITHUB_RELEASES_SOURCED:-}" ]] && return 0
readonly _MSP_CREATE_GITHUB_RELEASES_SOURCED=1

# Get script directory and ROOT_DIR
_CREATE_GH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CREATE_GH_ROOT_DIR="$(cd "$_CREATE_GH_SCRIPT_DIR/../../.." && pwd)"

# Source dependencies if not already loaded
if ! command -v log::info &>/dev/null; then
    if [[ -f "$_CREATE_GH_ROOT_DIR/Scripts/lib/logger.sh" ]]; then
        # shellcheck source=Scripts/lib/logger.sh
        source "$_CREATE_GH_ROOT_DIR/Scripts/lib/logger.sh" 2>/dev/null || true
    fi
fi

if ! command -v msp_state_get_pod_github_release_created &>/dev/null; then
    if [[ -f "$_CREATE_GH_ROOT_DIR/Scripts/release/utils/state.sh" ]]; then
        # shellcheck source=Scripts/release/utils/state.sh
        source "$_CREATE_GH_ROOT_DIR/Scripts/release/utils/state.sh" 2>/dev/null || true
    fi
fi

if ! command -v get_binary_distribution_pods &>/dev/null; then
    if [[ -f "$_CREATE_GH_ROOT_DIR/Scripts/release/publish/pods/lib/distribution_utils.sh" ]]; then
        # shellcheck source=Scripts/release/publish/pods/lib/distribution_utils.sh
        source "$_CREATE_GH_ROOT_DIR/Scripts/release/publish/pods/lib/distribution_utils.sh" 2>/dev/null || true
    fi
fi

if ! command -v create_github_release_for_pod &>/dev/null; then
    if [[ -f "$_CREATE_GH_ROOT_DIR/Scripts/release/publish/pods/lib/github_release_ext.sh" ]]; then
        # shellcheck source=Scripts/release/publish/pods/lib/github_release_ext.sh
        source "$_CREATE_GH_ROOT_DIR/Scripts/release/publish/pods/lib/github_release_ext.sh" 2>/dev/null || true
    fi
fi

# ============================================================================
# Create GitHub Releases Command
# ============================================================================
# @description Create/verify GitHub releases for all binary distribution pods
# @param $1 version - The version to create releases for
# @return 0 on success, 1 on error
# ============================================================================
create_github_releases_command() {
    local version="$1"

    if [[ -z "$version" ]]; then
        log::error "CMD" "Version is required"
        echo ""
        echo "Usage: ./Scripts/msp-release.sh create-github-releases <version>"
        echo ""
        echo "Example:"
        echo "  ./Scripts/msp-release.sh create-github-releases 1.0.4-rc.10"
        echo ""
        return 1
    fi

    log::step "CMD" "Creating GitHub releases for version $version"
    echo ""

    # Get binary distribution pods
    local binary_pods
    if command -v get_binary_distribution_pods &>/dev/null; then
        binary_pods=($(get_binary_distribution_pods))
    else
        # Fallback: hardcoded list
        binary_pods=("MSPiOSCore" "MSPSharedLibraries" "MSPGoogleAdsTypes" "MSPPrebidAdapter" "MSPFacebookAdapter" "MSPNovaAdapter" "MSPAmazonAdapter" "MSPGoogleAdapter" "MSPMolocoAdapter" "MSPLiftoffAdapter" "MSPApplovinMaxAdapter" "MSPCore")
    fi

    log::info "CMD" "Total binary distribution pods: ${#binary_pods[@]}"
    echo ""

    local created_count=0
    local skipped_count=0
    local failed_count=0
    local failed_pods=()

    for pod in "${binary_pods[@]}"; do
        log::info "CMD" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log::info "CMD" "Processing: $pod"
        log::info "CMD" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        # Check state
        local github_release_status="unknown"
        if command -v msp_state_get_pod_github_release_created &>/dev/null; then
            github_release_status=$(msp_state_get_pod_github_release_created "$pod")
        fi

        if [[ "$github_release_status" == "true" ]]; then
            log::info "CMD" "✅ $pod: Already created (state: true), skipping"
            ((skipped_count++)) || true
            echo ""
            continue
        fi

        # Create GitHub release for pod
        log::info "CMD" "Creating GitHub release for $pod..."
        if create_github_release_for_pod "$pod" "$version"; then
            log::success "CMD" "✅ $pod: GitHub release created"
            ((created_count++)) || true
        else
            log::error "CMD" "❌ $pod: Failed to create GitHub release"
            ((failed_count++)) || true
            failed_pods+=("$pod")
        fi

        echo ""
    done

    # Summary
    log::info "CMD" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "CMD" "GitHub Releases Creation Summary"
    log::info "CMD" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "CMD" "  ✅ Created: $created_count"
    log::info "CMD" "  ⏭️  Skipped: $skipped_count (already existed)"

    if [[ $failed_count -gt 0 ]]; then
        log::error "CMD" "  ❌ Failed: $failed_count"
        log::error "CMD" ""
        log::error "CMD" "Failed pods: ${failed_pods[*]}"
        log::error "CMD" ""
        log::error "CMD" "Please check the logs above for error details"
        return 1
    fi

    echo ""
    log::success "CMD" "All GitHub releases processed successfully"
    return 0
}

# Export function
export -f create_github_releases_command 2>/dev/null || true
