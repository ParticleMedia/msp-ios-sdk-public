#!/usr/bin/env bash
# ============================================================================
# MSP Release CLI - Resume Module
# ============================================================================
# Purpose: Provides resume functionality for interrupted releases
# Usage:   source Scripts/release/cli/resume.sh
#          msp_resume_release "$version"
#
# Dependencies:
#   - Scripts/lib/common.sh (log::* functions)
#   - Scripts/release/utils/state.sh (state management functions)
#   - Scripts/lib/release-common.sh (POD_RELEASE_ORDER)
# ============================================================================

# Prevent multiple sourcing
[[ -n "${_MSP_CLI_RESUME_SOURCED:-}" ]] && return 0
readonly _MSP_CLI_RESUME_SOURCED=1

# Get script directory and ROOT_DIR
_RESUME_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_RESUME_ROOT_DIR="$(cd "$_RESUME_SCRIPT_DIR/../../.." && pwd)"

# Source dependencies if not already loaded
if ! command -v log::info &>/dev/null; then
    if [[ -f "$_RESUME_ROOT_DIR/Scripts/lib/common.sh" ]]; then
        # shellcheck source=Scripts/lib/common.sh
        source "$_RESUME_ROOT_DIR/Scripts/lib/common.sh" 2>/dev/null || true
    fi
fi

# R031d: Source checksum module for unified checksum computation
if [[ -f "$_RESUME_ROOT_DIR/Scripts/lib/checksum.sh" ]]; then
    # shellcheck source=Scripts/lib/checksum.sh
    source "$_RESUME_ROOT_DIR/Scripts/lib/checksum.sh" 2>/dev/null || true
fi

# ============================================================================
# GitHub Release Sync (for Resume Mode)
# ============================================================================
# @description Syncs local state (zips, podspecs) from GitHub Release.
#              This ensures local state matches the "source of truth" (GitHub).
# @param $1 version - The release version to sync
# @return 0 on success, 0 on skip (no GitHub release found)
msp_sync_from_github_release() {
    local version="$1"
    local root_dir="${ROOT_DIR:-$_RESUME_ROOT_DIR}"

    log::info "RESUME" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "RESUME" "🔄 Resume Mode: Syncing state from GitHub Release"
    log::info "RESUME" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "RESUME" ""
    log::info "RESUME" "Version: $version"
    log::info "RESUME" "Reason: Ensure local state matches GitHub Release (source of truth)"
    log::info "RESUME" ""

    # Step 1: Check if GitHub Release exists
    if ! gh release view "$version" --repo "ParticleMedia/msp-ios-sdk-public" &>/dev/null; then
        log::warn "RESUME" "GitHub Release $version not found, skipping sync"
        log::warn "RESUME" "This is expected if this is the first run (not a resume)"
        log::info "RESUME" ""
        return 0
    fi

    log::success "RESUME" "✅ GitHub Release $version exists"
    log::info "RESUME" ""

    # Step 2: Get list of published pods from GitHub Release
    log::info "RESUME" "Step 1: Fetching assets from GitHub Release..."
    local assets
    assets=$(gh release view "$version" --repo "ParticleMedia/msp-ios-sdk-public" --json assets --jq '.assets[].name' 2>/dev/null || echo "")

    if [[ -z "$assets" ]]; then
        log::warn "RESUME" "No assets found in GitHub Release, skipping sync"
        log::info "RESUME" ""
        return 0
    fi

    local asset_count
    asset_count=$(echo "$assets" | grep -c ".zip$" || echo "0")
    log::info "RESUME" "Found $asset_count zip file(s) in GitHub Release"
    log::info "RESUME" ""

    # Step 3: Download zips from GitHub Release
    log::info "RESUME" "Step 2: Downloading zips from GitHub Release..."
    log::info "RESUME" ""

    local download_count=0
    local skip_count=0
    local error_count=0

    # Ensure Build/Zips directory exists
    mkdir -p "$root_dir/Build/Zips"

    # Process each zip file
    while IFS= read -r asset_name; do
        if [[ ! "$asset_name" =~ \.zip$ ]]; then
            continue
        fi

        local local_zip="$root_dir/Build/Zips/$asset_name"
        local download_url="https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/${asset_name}"

        log::info "RESUME" "  📦 Processing: $asset_name"

        # Download with retry mechanism
        local temp_zip="/tmp/resume-sync-${asset_name}-$$.zip"
        local download_success=false
        local github_checksum=""
        local max_retries=3
        local retry_delay=5

        for ((retry=1; retry<=max_retries; retry++)); do
            if [[ $retry -gt 1 ]]; then
                log::info "RESUME" "     Retrying download (attempt $retry/$max_retries)..."
                sleep $retry_delay
            fi

            # Download with timeout (60 seconds)
            if timeout 60 curl -L -f -s -o "$temp_zip" "$download_url" 2>/dev/null; then
                local file_size
                file_size=$(stat -f%z "$temp_zip" 2>/dev/null || stat -c%s "$temp_zip" 2>/dev/null || echo "0")

                if [[ $file_size -gt 0 ]]; then
                    # R031d: Use checksum.sh module if available, fallback to shasum
                    if command -v checksum_compute_sha256 &>/dev/null; then
                        github_checksum=$(checksum_compute_sha256 "$temp_zip")
                    else
                        github_checksum=$(shasum -a 256 "$temp_zip" 2>/dev/null | awk '{print $1}')
                    fi

                    if [[ -n "$github_checksum" && ${#github_checksum} -eq 64 ]]; then
                        download_success=true
                        break
                    else
                        log::warn "RESUME" "     ⚠️  Downloaded file but checksum calculation failed, retrying..."
                        rm -f "$temp_zip"
                    fi
                else
                    log::warn "RESUME" "     ⚠️  Downloaded file is empty (0 bytes), retrying..."
                    rm -f "$temp_zip"
                fi
            else
                if [[ $retry -lt $max_retries ]]; then
                    log::warn "RESUME" "     ⚠️  Download failed (attempt $retry/$max_retries), will retry..."
                fi
            fi
        done

        if [[ "$download_success" == "true" ]]; then

            # Check if local zip exists and matches
            if [[ -f "$local_zip" ]]; then
                # R031d: Use checksum.sh module if available, fallback to shasum
                local local_checksum
                if command -v checksum_compute_sha256 &>/dev/null; then
                    local_checksum=$(checksum_compute_sha256 "$local_zip")
                else
                    local_checksum=$(shasum -a 256 "$local_zip" 2>/dev/null | awk '{print $1}')
                fi

                if [[ "$local_checksum" == "$github_checksum" ]]; then
                    log::info "RESUME" "     ✅ Local zip already matches GitHub Release"
                    log::info "RESUME" "        Checksum: $github_checksum"
                    rm -f "$temp_zip"
                    ((skip_count++)) || true
                    continue
                else
                    log::warn "RESUME" "     ⚠️  Local zip checksum differs from GitHub Release"
                    log::info "RESUME" "        Local:  $local_checksum"
                    log::info "RESUME" "        GitHub: $github_checksum"
                    log::info "RESUME" "        → Replacing with GitHub Release version"
                fi
            else
                log::info "RESUME" "     ℹ️  Local zip not found, downloading from GitHub Release"
            fi

            # Replace local zip with GitHub Release version
            mv "$temp_zip" "$local_zip"
            log::success "RESUME" "     ✅ Downloaded and replaced: $asset_name"
            log::info "RESUME" "        Checksum: $github_checksum"
            ((download_count++)) || true
        else
            log::error "RESUME" "     ❌ Failed to download from GitHub Release after $max_retries attempts"
            log::error "RESUME" "        URL: $download_url"
            log::error "RESUME" "        Possible causes:"
            log::error "RESUME" "          1. Network connectivity issues"
            log::error "RESUME" "          2. GitHub CDN temporarily unavailable"
            log::error "RESUME" "          3. File does not exist in GitHub Release"
            rm -f "$temp_zip"
            ((error_count++)) || true
        fi

        log::info "RESUME" ""
    done <<< "$assets"

    # Step 4: Summary
    log::info "RESUME" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "RESUME" "📊 Sync Summary"
    log::info "RESUME" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "RESUME" "Total zips:     $asset_count"
    log::info "RESUME" "Downloaded:     $download_count"
    log::info "RESUME" "Already synced: $skip_count"
    log::info "RESUME" "Errors:         $error_count"
    log::info "RESUME" ""

    if [[ $error_count -gt 0 ]]; then
        log::warn "RESUME" "⚠️  Some zips failed to sync, but continuing..."
        log::warn "RESUME" "This may cause checksum mismatches later"
    else
        log::success "RESUME" "✅ All zips synced from GitHub Release"
    fi

    # Step 5: Delete old podspecs (will be regenerated)
    log::info "RESUME" ""
    log::info "RESUME" "Step 3: Removing old podspecs (will be regenerated)..."

    local podspec_dir="$root_dir/Build/ReleasePodspecs"
    if [[ -d "$podspec_dir" ]]; then
        local podspec_count
        podspec_count=$(find "$podspec_dir" -maxdepth 1 -name "*.podspec" -type f 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$podspec_count" -gt 0 ]]; then
            log::info "RESUME" "Removing $podspec_count existing podspec(s)..."
            rm -f "$podspec_dir"/*.podspec
            log::success "RESUME" "✅ Removed $podspec_count podspec(s)"
        else
            log::info "RESUME" "No existing podspecs found"
        fi
    else
        log::info "RESUME" "Podspec directory does not exist yet"
    fi

    log::info "RESUME" ""
    log::success "RESUME" "✅ Sync complete: local state matches GitHub Release"
    log::info "RESUME" "   - Local zips updated from GitHub Release"
    log::info "RESUME" "   - Old podspecs removed (will be regenerated with correct checksums)"
    log::info "RESUME" ""
    log::info "RESUME" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "RESUME" ""
}

# ============================================================================
# Display Resume Summary
# ============================================================================
# @description Displays the status of all pods for resume
# @param $1 version - The release version
# @return Sets has_pending and has_failed variables
msp_display_resume_summary() {
    local version="$1"
    local root_dir="${ROOT_DIR:-$_RESUME_ROOT_DIR}"

    # Ensure POD_RELEASE_ORDER is available
    if [[ -z "${POD_RELEASE_ORDER:-}" ]]; then
        if [[ -f "$root_dir/Scripts/lib/release-common.sh" ]]; then
            # shellcheck source=Scripts/lib/release-common.sh
            source "$root_dir/Scripts/lib/release-common.sh" 2>/dev/null || true
        fi
    fi

    log::info "RESUME" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "RESUME" "📋 Resume Summary for $version"
    log::info "RESUME" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Display pod status
    _MSP_RESUME_HAS_PENDING=false
    _MSP_RESUME_HAS_FAILED=false

    for pod in "${POD_RELEASE_ORDER[@]}"; do
        local status="unknown"
        if command -v msp_state_get_pod_status &>/dev/null; then
            status=$(msp_state_get_pod_status "$pod")
        fi

        case "$status" in
            "published")
                log::success "RESUME" "  ✅ $pod - Published"
                ;;
            "failed")
                log::error "RESUME" "  ❌ $pod - Failed (will retry)"
                _MSP_RESUME_HAS_FAILED=true
                ;;
            "inconsistent")
                log::warn "RESUME" "  ⚠️  $pod - Inconsistent (will verify)"
                _MSP_RESUME_HAS_PENDING=true
                ;;
            "pending"|"unknown")
                log::info "RESUME" "  ⏳ $pod - Pending"
                _MSP_RESUME_HAS_PENDING=true
                ;;
            *)
                log::info "RESUME" "  ❓ $pod - $status"
                _MSP_RESUME_HAS_PENDING=true
                ;;
        esac
    done

    echo ""
    log::info "RESUME" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============================================================================
# Check if Resume is Complete
# ============================================================================
# @description Checks if all pods are already published
# @return 0 if complete (nothing to do), 1 if resume needed
msp_resume_is_complete() {
    if [[ "$_MSP_RESUME_HAS_PENDING" == "false" ]] && [[ "$_MSP_RESUME_HAS_FAILED" == "false" ]]; then
        return 0
    fi
    return 1
}

# ============================================================================
# Check State File Exists
# ============================================================================
# @description Checks if state file exists for resume
# @return 0 if exists, 1 if not (with error message)
msp_resume_check_state_file() {
    local root_dir="${ROOT_DIR:-$_RESUME_ROOT_DIR}"
    local state_file="$root_dir/.msp-release-state.json"

    if [[ ! -f "$state_file" ]]; then
        log::error "RELEASE" "❌ No previous release run found. Cannot resume."
        log::info "RELEASE" "State file not found: $state_file"
        log::info "RELEASE" "Please run 'msp-release.sh run <VERSION>' first to start a release."
        return 1
    fi
    return 0
}

# ============================================================================
# Get Version for Resume
# ============================================================================
# @description Gets version from args or state file
# @param $@ - Command line args (first arg may be version)
# @return Echoes version, exits 1 if not found
# shellcheck disable=SC2034 # _MSP_RESUME_VERSION used by caller
msp_resume_get_version() {
    local root_dir="${ROOT_DIR:-$_RESUME_ROOT_DIR}"
    local state_file="$root_dir/.msp-release-state.json"
    local version=""

    # Check if first arg is version
    if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
        version="$1"
    fi

    # Auto-detect from state file if not provided
    if [[ -z "$version" ]]; then
        if command -v jq >/dev/null 2>&1 && [[ -f "$state_file" ]]; then
            version=$(jq -r '.version // empty' "$state_file" 2>/dev/null || echo "")
            if [[ -n "$version" && "$version" != "unknown" ]]; then
                log::info "RELEASE" "📝 Auto-detected version from state file: $version" >&2
            fi
        fi
    fi

    # Verify version is set
    if [[ -z "$version" ]]; then
        log::error "RELEASE" "❌ No version specified and could not auto-detect"
        log::error "RELEASE" ""
        log::error "RELEASE" "Usage: msp-release.sh resume [VERSION]"
        log::error "RELEASE" ""
        log::error "RELEASE" "Examples:"
        log::error "RELEASE" "  msp-release.sh resume 0.3.0-rc.7"
        log::error "RELEASE" "  msp-release.sh resume              # Auto-detect from state file"
        return 1
    fi

    _MSP_RESUME_VERSION="$version"
    echo "$version"
}

# ============================================================================
# Load Resume Dependencies
# ============================================================================
# @description Loads required dependencies for resume
# @return 0 on success, 1 on failure
msp_resume_load_dependencies() {
    local root_dir="${ROOT_DIR:-$_RESUME_ROOT_DIR}"

    # Load release-common for POD_RELEASE_ORDER
    if [[ -f "$root_dir/Scripts/lib/release-common.sh" ]]; then
        # shellcheck source=Scripts/lib/release-common.sh
        source "$root_dir/Scripts/lib/release-common.sh"
    else
        log::error "RELEASE" "❌ Cannot load Scripts/lib/release-common.sh"
        return 1
    fi

    # Load state utilities
    if [[ -f "$root_dir/Scripts/release/utils/state.sh" ]]; then
        # shellcheck source=Scripts/release/utils/state.sh
        source "$root_dir/Scripts/release/utils/state.sh"
    fi

    return 0
}

# ============================================================================
# Setup Resume Environment
# ============================================================================
# @description Sets up environment variables for resume mode
# @param $1 version - The release version
# @globals Uses FULL_MODE
# @return Exports MSP_RESUME_MODE, RELEASE_VERSION, MSP_RELEASE_MODE, etc.
msp_resume_setup_environment() {
    local version="$1"
    local root_dir="${ROOT_DIR:-$_RESUME_ROOT_DIR}"
    local state_file="$root_dir/.msp-release-state.json"

    # Set resume mode flag and version
    export MSP_RESUME_MODE="1"
    export RELEASE_VERSION="$version"

    # Determine release mode: --full flag > state file > default (simple)
    if [[ "${FULL_MODE:-false}" == "true" ]]; then
        export MSP_RELEASE_MODE="full"
        log::info "RELEASE" "[MODE] Full release mode (--full flag): includes verification phase"
    else
        local saved_mode="simple"
        if command -v jq >/dev/null 2>&1 && [[ -f "$state_file" ]]; then
            saved_mode=$(jq -r '.release_mode // "simple"' "$state_file" 2>/dev/null || echo "simple")
        fi
        export MSP_RELEASE_MODE="$saved_mode"
        if [[ "$saved_mode" == "full" ]]; then
            log::info "RELEASE" "[MODE] Full release mode (restored from state): includes verification phase"
        else
            log::info "RELEASE" "[MODE] Simple release mode (default): skips verification phase"
        fi
    fi

    # Restore BASE_BRANCH from state file so the post-release PR
    # targets the correct branch (not the release branch itself)
    if command -v jq >/dev/null 2>&1 && [[ -f "$state_file" ]]; then
        local saved_base_branch
        saved_base_branch=$(jq -r '.base_branch // empty' "$state_file" 2>/dev/null || echo "")
        if [[ -n "$saved_base_branch" && "$saved_base_branch" != "unknown" ]]; then
            export BASE_BRANCH="$saved_base_branch"
            log::debug "RELEASE" "[RESUME] Restored BASE_BRANCH from state: $saved_base_branch"
        fi
    fi

    # Resume allows existing release and tag
    export MSP_ALLOW_EXISTING_RELEASE=true
    export MSP_ALLOW_EXISTING_TAG=true

    # T025: Restore MSP_PRERELEASE from state file (env scope is lost on resume)
    # This ensures safety.sh version validation and Slack notifications are
    # consistent with the original release intent.
    if command -v jq >/dev/null 2>&1 && [[ -f "$state_file" ]]; then
        local saved_is_prerelease
        saved_is_prerelease=$(jq -r '.is_prerelease // false' "$state_file" 2>/dev/null || echo "false")
        if [[ "$saved_is_prerelease" == "true" ]]; then
            export MSP_PRERELEASE=1
            log::info "RELEASE" "Resume: restored MSP_PRERELEASE=1 from state file"
        else
            unset MSP_PRERELEASE 2>/dev/null || true
            log::debug "RELEASE" "Resume: is_prerelease=false, MSP_PRERELEASE not set"
        fi
    fi

    # T026: If caller passed a VERSION that differs from state file version, log and continue
    # (do NOT abort — state file is authoritative for resume)
    if command -v jq >/dev/null 2>&1 && [[ -f "$state_file" ]]; then
        local state_version
        state_version=$(jq -r '.version // ""' "$state_file" 2>/dev/null || echo "")
        if [[ -n "$state_version" && -n "${RELEASE_VERSION:-}" && "$RELEASE_VERSION" != "$state_version" ]]; then
            log::warn "RELEASE" "Resume: using state version ${state_version}, ignoring input ${RELEASE_VERSION}"
            export RELEASE_VERSION="$state_version"
        fi
    fi

}

# Export functions
export -f msp_sync_from_github_release 2>/dev/null || true
export -f msp_display_resume_summary 2>/dev/null || true
export -f msp_resume_is_complete 2>/dev/null || true
export -f msp_resume_check_state_file 2>/dev/null || true
export -f msp_resume_get_version 2>/dev/null || true
export -f msp_resume_load_dependencies 2>/dev/null || true
export -f msp_resume_setup_environment 2>/dev/null || true
