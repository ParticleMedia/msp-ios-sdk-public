#!/usr/bin/env bash
# ============================================================================
# Pod Publishing Module
# ============================================================================
# Module: pod_publish.sh
# Purpose: Resume-aware pod publishing to CocoaPods Trunk
# Extracted from: publish.sh
#
# Functions:
#   - publish_pod_with_resume: Three-tier verification publishing
#   - publish_pod_to_cocoapods: Standard CocoaPods publishing
#   - acquire_github_release_lock: Concurrent control for GitHub releases
#   - release_github_release_lock: Release GitHub release lock
#   - backup_github_release_assets: Backup assets before release recreation
#   - restore_github_release_assets: Restore backed up assets
#   - auto_fix_checksum_issue: Auto-fix checksum verification errors
#
# Dependencies:
#   - Logging functions (log::info, log::error, log::success, log::step, log::warn)
#   - is_binary_distribution, get_module_dir (from distribution_utils.sh)
#   - check_pod_published_on_trunk, check_pod_availability (from pod_trunk.sh)
#   - create_or_verify_github_release, upload_zip_to_github (from github_release.sh)
#   - probe_zip_url (from github_release_ext.sh)
#   - ROOT_DIR, DRY_RUN, VERSION environment variables
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_POD_PUBLISH_SOURCED:-}" ]] && return 0
readonly _POD_PUBLISH_SOURCED=1

# R031d: Source checksum module for unified checksum computation
if [[ -n "${ROOT_DIR:-}" ]] && [[ -f "$ROOT_DIR/Scripts/lib/checksum.sh" ]]; then
    # shellcheck source=Scripts/lib/checksum.sh
    source "$ROOT_DIR/Scripts/lib/checksum.sh" 2>/dev/null || true
fi

# ============================================================================
# GitHub Release Lock Mechanism
# ============================================================================
# Prevents multiple pods from simultaneously modifying the same GitHub Release
# Uses cross-platform lock.sh (T070) with mkdir fallback for macOS
# ============================================================================
acquire_github_release_lock() {
    local version_tag="$1"
    local timeout="${2:-60}"

    # Use lock.sh API if available (cross-platform support)
    if command -v lock_acquire &>/dev/null; then
        local lock_name="github-release-${version_tag}"
        if lock_acquire "$lock_name" "$timeout"; then
            export GITHUB_RELEASE_LOCK_NAME="$lock_name"
            log::info "PODS" "LOCK" "Acquired lock for GitHub Release: $version_tag"
            return 0
        else
            log::error "PODS" "LOCK" "Failed to acquire lock for $version_tag after ${timeout}s"
            if command -v lock_get_holder &>/dev/null; then
                local holder_info
                holder_info=$(lock_get_holder "$lock_name" 2>/dev/null || echo "unknown")
                log::error "PODS" "LOCK" "Lock holder: $holder_info"
            fi
            return 1
        fi
    fi

    # Fallback: original flock-based implementation (legacy)
    local lock_file="/tmp/msp-release-github-${version_tag}.lock"
    local wait_interval=2
    local elapsed=0

    exec 200>"$lock_file"

    if ! command -v flock >/dev/null 2>&1; then
        log::debug "PODS" "LOCK" "flock not available (macOS), skipping file locking"
        return 0
    fi

    while true; do
        if flock -x -n 200; then
            echo "$$:$(date -u +%Y-%m-%dT%H:%M:%SZ):$(hostname)" >&200
            export GITHUB_RELEASE_LOCK_FD=200
            log::info "PODS" "LOCK" "Acquired lock for GitHub Release: $version_tag"
            return 0
        fi

        if [[ $elapsed -ge $timeout ]]; then
            local lock_holder
            lock_holder=$(cat "$lock_file" 2>/dev/null || echo "unknown")
            log::error "PODS" "LOCK" "Failed to acquire lock for $version_tag after ${timeout}s (holder: $lock_holder)"
            return 1
        fi

        log::debug "PODS" "LOCK" "Lock busy, waiting... (${elapsed}/${timeout}s)"
        sleep $wait_interval
        elapsed=$((elapsed + wait_interval))
    done
}

release_github_release_lock() {
    # Use lock.sh API if available
    if [[ -n "${GITHUB_RELEASE_LOCK_NAME:-}" ]] && command -v lock_release &>/dev/null; then
        lock_release "$GITHUB_RELEASE_LOCK_NAME"
        unset GITHUB_RELEASE_LOCK_NAME
        log::info "PODS" "LOCK" "Released GitHub Release lock"
        return 0
    fi

    # Fallback: original flock-based release (legacy)
    if ! command -v flock >/dev/null 2>&1; then
        return 0
    fi

    if [[ -n "${GITHUB_RELEASE_LOCK_FD:-}" ]]; then
        eval "exec ${GITHUB_RELEASE_LOCK_FD}>&-"
        unset GITHUB_RELEASE_LOCK_FD
        log::info "PODS" "LOCK" "Released GitHub Release lock"
    fi
}

# ============================================================================
# GitHub Release Asset Backup/Restore
# ============================================================================
# Preserves binary assets (XCFramework zips) when recreating Release
# ============================================================================
backup_github_release_assets() {
    local version_tag="$1"
    local release_repo="$2"
    local backup_dir="/tmp/msp-release-assets-backup-${version_tag}-$$"

    log::info "PODS" "BACKUP" "Backing up GitHub Release assets for $version_tag..."

    mkdir -p "$backup_dir"

    local assets
    assets=$(gh release view "$version_tag" --repo "$release_repo" --json assets --jq '.assets[].name' 2>/dev/null || echo "")

    if [[ -z "$assets" ]]; then
        log::debug "PODS" "BACKUP" "No assets to backup"
        echo "$backup_dir"
        return 0
    fi

    local asset_count=0
    while IFS= read -r asset_name; do
        [[ -z "$asset_name" ]] && continue

        log::debug "PODS" "BACKUP" "Downloading asset: $asset_name"
        if gh release download "$version_tag" \
            --repo "$release_repo" \
            --pattern "$asset_name" \
            --dir "$backup_dir" \
            --clobber 2>/dev/null; then
            asset_count=$((asset_count + 1))
            log::debug "PODS" "BACKUP" "Backed up: $asset_name"
        else
            log::warn "PODS" "BACKUP" "Failed to backup: $asset_name"
        fi
    done <<< "$assets"

    log::info "PODS" "BACKUP" "Backed up $asset_count asset(s) to: $backup_dir"
    echo "$backup_dir"
}

restore_github_release_assets() {
    local version_tag="$1"
    local release_repo="$2"
    local backup_dir="$3"

    if [[ ! -d "$backup_dir" ]] || [[ -z "$(ls -A "$backup_dir" 2>/dev/null)" ]]; then
        log::debug "PODS" "RESTORE" "No assets to restore from: $backup_dir"
        return 0
    fi

    log::info "PODS" "RESTORE" "Restoring assets to GitHub Release: $version_tag..."

    local restored_count=0
    for asset_file in "$backup_dir"/*; do
        [[ ! -f "$asset_file" ]] && continue

        local asset_name
        asset_name=$(basename "$asset_file")

        log::debug "PODS" "RESTORE" "Uploading asset: $asset_name"
        if gh release upload "$version_tag" \
            --repo "$release_repo" \
            "$asset_file" \
            --clobber 2>/dev/null; then
            restored_count=$((restored_count + 1))
            log::debug "PODS" "RESTORE" "Restored: $asset_name"
        else
            log::warn "PODS" "RESTORE" "Failed to restore: $asset_name"
        fi
    done

    log::info "PODS" "RESTORE" "Restored $restored_count asset(s)"
    rm -rf "$backup_dir"
    log::debug "PODS" "RESTORE" "Cleaned up backup directory"
}

# ============================================================================
# Checksum Issue Auto-Fix Helper
# ============================================================================
# Detects and fixes checksum verification errors for source-based adapters
# ============================================================================
auto_fix_checksum_issue() {
    local pod_name="$1"
    local version_tag="$2"
    local error_output="$3"

    if ! echo "$error_output" | grep -q "Verification checksum was incorrect"; then
        return 1
    fi

    log::warn "PODS" "PUBLISH" "Detected checksum verification error for $pod_name"
    log::info "PODS" "PUBLISH" "This usually happens when GitHub Release source code zip doesn't match git tag"

    local podspec_file="${ROOT_DIR}/Build/ReleasePodspecs/${pod_name}.podspec"
    if [[ ! -f "$podspec_file" ]]; then
        log::error "PODS" "PUBLISH" "Podspec not found: $podspec_file"
        return 1
    fi

    if ! grep -q "git:" "$podspec_file"; then
        log::warn "PODS" "PUBLISH" "Not a source-based distribution, cannot auto-fix"
        return 1
    fi

    log::info "PODS" "PUBLISH" "Confirmed: $pod_name is source-based (git+tag)"
    log::info "PODS" "PUBLISH" "Attempting automatic fix..."

    local release_repo="ParticleMedia/msp-ios-sdk-public"
    export MSP_GITHUB_REPO="$release_repo"

    if ! create_or_verify_github_release "$version_tag"; then
        log::error "PODS" "PUBLISH" "Failed to create/verify GitHub Release $version_tag"
        return 1
    fi

    log::info "PODS" "PUBLISH" "GitHub Release $version_tag created/verified"
    sleep 5

    log::info "PODS" "PUBLISH" "Checksum issue fixed automatically"
    return 0
}

# ============================================================================
# Permanent Trunk Error Detection
# ============================================================================
# Uses inverse matching — anything NOT matching here is considered transient
# and eligible for retry (server 500, timeouts, CDN failures, etc.).
# ============================================================================
is_permanent_trunk_error() {
    local log="$1"
    # Network errors are transient even if they cause "did not pass validation"
    if grep -qi -e "Recv failure" -e "Connection reset by peer" -e "curl: (56)" "$log"; then
        return 1
    fi
    # CDN shard index lag is always transient — dependency spec not yet propagated to
    # the CDN node pod trunk push hit internally. The CDN retry loop handles this first;
    # this pre-check ensures auto-retry also runs if CDN retry somehow doesn't trigger.
    if grep -qi "could not find compatible versions" "$log"; then
        return 1
    fi
    grep -qi \
        -e "already exists" \
        -e "duplicate entry" \
        -e "Source code.*not accessible" \
        -e "bad/illegal format" \
        -e "did not pass validation" \
        -e "ERROR.*spec" \
        "$log"
}

# ============================================================================
# Publish Pod with Resume Support
# ============================================================================
# Three-tier verification: Local state -> Trunk check -> Publish
#
# Args:
#   $1: pod_name
#   $2: version
#   $3: podspec_path
# Returns:
#   0 if published or already exists, 1 if failed
# ============================================================================
publish_pod_with_resume() {
    local pod="$1"
    local version="$2"
    local podspec="$3"

    log::info "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "PODS" "Publishing: $pod $version"
    log::info "PODS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Tier 1: Check local state (fast path)
    local local_status
    if command -v msp_state_get_pod_status &>/dev/null; then
        local_status=$(msp_state_get_pod_status "$pod")
        log::info "PODS" "Local state: $local_status"
    else
        local_status="unknown"
    fi

    if [[ "$local_status" == "published" ]]; then
        log::info "PODS" "Local state indicates pod was published"

        # Tier 2: Verify with Trunk (authoritative)
        if check_pod_published_on_trunk "$pod" "$version"; then
            log::success "PODS" "Skipping $pod $version (already published on Trunk)"
            return 0
        else
            log::warn "PODS" "Local state says published, but not found on Trunk"
            log::info "PODS" "Will retry publishing..."

            if command -v msp_state_mark_pod_status &>/dev/null; then
                msp_state_mark_pod_status "$pod" "inconsistent"
            fi
        fi
    fi

    # Auto-Build Missing XCFrameworks for Binary Distribution Adapters
    if is_binary_distribution "$pod"; then
        case "$pod" in
            MSPPrebidAdapter|MSPGoogleAdapter|MSPFacebookAdapter|MSPAmazonAdapter|MSPMolocoAdapter|MSPLiftoffAdapter)
                local module_dir
                module_dir=$(get_module_dir "$pod")
                local xcframework_path="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks/${pod}.xcframework"

                if [[ ! -d "$xcframework_path" ]]; then
                    log::warn "PODS" "XCFramework missing for $pod, auto-building..."
                    local build_script="$ROOT_DIR/Scripts/xcframeworks/build_module.sh"

                    if [[ ! -x "$build_script" ]]; then
                        log::error "PODS" "Build script not found: $build_script"
                        return 1
                    fi

                    if "$build_script" "$module_dir" 2>&1 | tee "/tmp/auto-build-${pod}.log"; then
                        if [[ -d "$xcframework_path" ]]; then
                            log::success "PODS" "Auto-built XCFramework: $pod"
                        else
                            log::error "PODS" "Build reported success but XCFramework not found"
                            return 1
                        fi
                    else
                        log::error "PODS" "Failed to auto-build XCFramework for $pod"
                        return 1
                    fi
                fi
                ;;
        esac
    fi

    # Ensure binary distribution pods have valid checksum
    if is_binary_distribution "$pod"; then
        local podspec_file="$ROOT_DIR/Build/ReleasePodspecs/${pod}.podspec"

        if [[ -f "$podspec_file" ]]; then
            local existing_checksum
            existing_checksum=$(grep ":sha256" "$podspec_file" 2>/dev/null | sed 's/.*"\(.*\)".*/\1/' || echo "")
            local local_zip="$ROOT_DIR/Build/Zips/${pod}-${version}.zip"

            if [[ -f "$local_zip" ]]; then
                # R031d: Use checksum.sh module if available, fallback to shasum
                local actual_checksum
                if command -v checksum_compute_sha256 &>/dev/null; then
                    actual_checksum=$(checksum_compute_sha256 "$local_zip")
                else
                    actual_checksum=$(shasum -a 256 "$local_zip" 2>/dev/null | awk '{print $1}')
                fi

                if [[ -n "$actual_checksum" ]] && [[ "$existing_checksum" != "$actual_checksum" ]]; then
                    log::warn "PODS" "Checksum mismatch for $pod, updating..."
                    if [[ "$OSTYPE" == "darwin"* ]]; then
                        sed -i '' "s/:sha256 => \".*\"/:sha256 => \"$actual_checksum\"/" "$podspec_file"
                    else
                        sed -i "s/:sha256 => \".*\"/:sha256 => \"$actual_checksum\"/" "$podspec_file"
                    fi
                    log::success "PODS" "Updated $pod podspec checksum"
                fi
            fi
        fi
    fi

    # Tier 3: Attempt to publish
    log::info "PODS" "Publishing $pod $version to CocoaPods Trunk..."

    local log_file
    log_file=$(mktemp)

    local skip_tests_flag=""
    if [[ "${MSP_SKIP_TRUNK_TESTS:-0}" == "1" ]]; then
        skip_tests_flag="--skip-tests"
    fi

    # Verify podspec checksum matches GitHub Release
    log::step "PODS" "Verifying podspec checksum matches GitHub Release"

    local podspec_checksum
    podspec_checksum=$(grep -E '^\s*:sha256\s*=>\s*"[^"]*"' "$podspec" 2>/dev/null | sed -E 's/.*"([^"]+)".*/\1/' || echo "")

    if [[ -z "$podspec_checksum" || ${#podspec_checksum} -ne 64 ]]; then
        log::error "PODS" "Failed to extract valid checksum from podspec"
        return 1
    fi

    local podspec_http_url
    podspec_http_url=$(grep -E '^\s*:http\s*=>\s*"[^"]*"' "$podspec" 2>/dev/null | sed -E 's/.*"([^"]+)".*/\1/' || echo "")

    if [[ -n "$podspec_http_url" ]]; then
        local temp_verify_zip="/tmp/verify-publish-${pod}-${version}-$$.zip"
        sleep 5

        if curl -L -f -s -o "$temp_verify_zip" "$podspec_http_url" 2>/dev/null; then
            # R031d: Use checksum.sh module if available, fallback to shasum
            local github_checksum
            if command -v checksum_compute_sha256 &>/dev/null; then
                github_checksum=$(checksum_compute_sha256 "$temp_verify_zip")
            else
                github_checksum=$(shasum -a 256 "$temp_verify_zip" 2>/dev/null | awk '{print $1}')
            fi
            rm -f "$temp_verify_zip"

            if [[ "$podspec_checksum" != "$github_checksum" ]]; then
                log::error "PODS" "Checksum mismatch! Podspec: $podspec_checksum, GitHub: $github_checksum"
                return 1
            fi
            log::success "PODS" "Checksum verification PASSED"
        else
            log::error "PODS" "Failed to download zip from GitHub Release"
            return 1
        fi
    fi

    # Execute pod trunk push — with CDN shard index retry.
    # Background: pod trunk push runs pod spec lint internally. The lint step resolves
    # dependencies from CDN, potentially hitting a DIFFERENT edge node than the one
    # used by wait_for_pod_in_spec_index. If that node's shard index hasn't propagated
    # yet, the lint fails with "could not find compatible versions" even though the pod
    # IS published. Detect this transient failure and retry after refreshing the local
    # spec repo (forcing a new CDN node hit that may have the updated shard index).
    local exit_code_file
    exit_code_file=$(mktemp "/tmp/pod_trunk_exit_code_XXXXXX")

    local publish_exit_code="1"
    local publish_output=""
    local cdn_retry=0
    local cdn_retry_max=5

    while [[ $cdn_retry -le $cdn_retry_max ]]; do
        : > "$log_file"  # truncate log before each attempt
        {
            pod trunk push "$podspec" --allow-warnings $skip_tests_flag 2>&1 | tee "$log_file"
            echo "${PIPESTATUS[0]}" > "$exit_code_file"
        } || true

        publish_exit_code=$(cat "$exit_code_file" 2>/dev/null || echo "1")
        publish_output=$(cat "$log_file" 2>/dev/null || echo "")

        if [[ "$publish_exit_code" == "0" ]]; then
            break
        fi

        # Retry only for CDN shard index propagation failures (transient, different edge nodes)
        if echo "$publish_output" | grep -q "could not find compatible versions"; then
            cdn_retry=$((cdn_retry + 1))
            if [[ $cdn_retry -le $cdn_retry_max ]]; then
                log::warn "PODS" "CDN shard index lag detected (attempt $cdn_retry/$cdn_retry_max) — refreshing spec repo and retrying in 60s..."
                rm -f /tmp/msp-cocoapods-specs-repo-last-update 2>/dev/null || true
                pod repo update trunk 2>/dev/null || log::warn "PODS" "pod repo update failed, retrying push anyway..."
                sleep 60
                continue
            fi
        fi
        break
    done

    rm -f "$exit_code_file"

    if [[ "$publish_exit_code" == "0" ]]; then
        log::success "PODS" "$pod $version published to CocoaPods Trunk"
        if command -v msp_state_mark_pod_status &>/dev/null; then
            msp_state_mark_pod_status "$pod" "published"
            # Do NOT mark trunk_verified yet - need to verify availability first
        fi

        # CRITICAL: Verify pod is actually available on CocoaPods CDN before marking verified
        # Rationale (Constitution Article I.4): State must reflect actual reality, not assumed success
        log::info "PODS" "Verifying $pod $version is available on CocoaPods CDN..."
        if command -v smart_wait_for_pod_availability &>/dev/null; then
            if smart_wait_for_pod_availability "$pod" "$version" "post-publish verification"; then
                log::success "PODS" "✅ Verified: $pod $version is available on CocoaPods CDN"
                if command -v msp_state_set_pod_trunk_verified &>/dev/null; then
                    msp_state_set_pod_trunk_verified "$pod" "true"
                fi
            else
                log::warn "PODS" "⚠️  $pod $version published but not yet available on CDN"
                log::warn "PODS" "This may indicate CDN propagation delay or publication failure"
                # Mark as published but not verified - resume can retry verification
            fi
        else
            log::warn "PODS" "⚠️  smart_wait_for_pod_availability not available, skipping CDN verification"
        fi

        rm -f "$log_file"
        return 0
    fi

    # Try auto-fix for checksum issues
    if auto_fix_checksum_issue "$pod" "$version" "$publish_output"; then
        log::info "PODS" "Retrying publication after checksum fix..."
        local retry_exit_code_file
        retry_exit_code_file=$(mktemp "/tmp/pod_trunk_retry_XXXXXX")

        {
            pod trunk push "$podspec" --allow-warnings $skip_tests_flag 2>&1 | tee "$log_file"
            echo "${PIPESTATUS[0]}" > "$retry_exit_code_file"
        } || true

        publish_exit_code=$(cat "$retry_exit_code_file" 2>/dev/null || echo "1")
        rm -f "$retry_exit_code_file"

        if [[ "$publish_exit_code" == "0" ]]; then
            log::success "PODS" "Publication succeeded after auto-fix"
            if command -v msp_state_mark_pod_status &>/dev/null; then
                msp_state_mark_pod_status "$pod" "published"
                # Do NOT mark trunk_verified yet - need to verify availability first
            fi

            # CRITICAL: Verify pod is actually available on CocoaPods CDN
            log::info "PODS" "Verifying $pod $version is available on CocoaPods CDN..."
            if command -v smart_wait_for_pod_availability &>/dev/null; then
                if smart_wait_for_pod_availability "$pod" "$version" "post-publish verification after auto-fix"; then
                    log::success "PODS" "✅ Verified: $pod $version is available on CocoaPods CDN"
                    if command -v msp_state_set_pod_trunk_verified &>/dev/null; then
                        msp_state_set_pod_trunk_verified "$pod" "true"
                    fi
                else
                    log::warn "PODS" "⚠️  $pod $version published but not yet available on CDN"
                fi
            fi

            rm -f "$log_file"
            return 0
        fi
    fi

    # Check if already exists.
    # "Unable to accept duplicate entry" / "already exists" from Trunk is authoritative:
    # it proves the version is on Trunk. No further verification is needed — the Trunk
    # API itself confirmed the entry. Attempting pod trunk info immediately after publish
    # is unreliable because CocoaPods CDN index propagation can take minutes.
    if grep -q "already exists\|Unable to accept duplicate entry" "$log_file"; then
        log::warn "PODS" "$pod $version already exists on Trunk (Trunk confirmed — treating as success)"
        if command -v msp_state_mark_pod_status &>/dev/null; then
            msp_state_mark_pod_status "$pod" "published"
            if command -v msp_state_set_pod_trunk_verified &>/dev/null; then
                msp_state_set_pod_trunk_verified "$pod" "true"
            fi
        fi
        rm -f "$log_file"
        return 0
    fi

    # Auto-retry on transient CocoaPods errors (HTTP 500, timeouts, CDN issues)
    # Uses inverse matching: retry everything EXCEPT known permanent errors.
    if ! is_permanent_trunk_error "$log_file"; then
        local max_server_retries=3
        local retry_delays=(30 60 120)
        local server_retry=0

        while [[ $server_retry -lt $max_server_retries ]]; do
            local delay=${retry_delays[$server_retry]}
            log::warn "PODS" "Transient server error detected (attempt $((server_retry + 1))/$max_server_retries)"
            log::info "PODS" "Waiting ${delay}s before retry..."
            sleep "$delay"

            local retry_exit_code_file
            retry_exit_code_file=$(mktemp "/tmp/pod_trunk_exit_code_server_retry_XXXXXX")

            {
                pod trunk push "$podspec" --allow-warnings $skip_tests_flag 2>&1 | tee "$log_file"
                echo "${PIPESTATUS[0]}" > "$retry_exit_code_file"
            } || true

            publish_exit_code=$(cat "$retry_exit_code_file" 2>/dev/null || echo "1")
            rm -f "$retry_exit_code_file"

            if [[ "$publish_exit_code" == "0" ]]; then
                log::success "PODS" "$pod $version published successfully (after server retry $((server_retry + 1)))"
                if command -v msp_state_mark_pod_status &>/dev/null; then
                    msp_state_mark_pod_status "$pod" "published"
                    msp_state_set_pod_trunk_verified "$pod" "true"
                fi
                rm -f "$log_file"
                return 0
            fi

            # If error became permanent, stop retrying
            if is_permanent_trunk_error "$log_file"; then
                log::warn "PODS" "Error is now a permanent error, stopping retries"
                break
            fi

            ((server_retry++)) || true
        done
    fi

    # Real failure
    log::error "PODS" "Failed to publish $pod $version"
    if command -v msp_state_mark_pod_status &>/dev/null; then
        msp_state_mark_pod_status "$pod" "failed"
    fi
    tail -20 "$log_file" | sed 's/^/  /'
    rm -f "$log_file"
    return 1
}

# ============================================================================
# Publish Pod to CocoaPods
# ============================================================================
# Standard CocoaPods publishing with validation
#
# Args:
#   $1: pod_name
#   $2: version
# Returns:
#   0 if published, 1 if failed
# ============================================================================
publish_pod_to_cocoapods() {
    local pod="$1"
    local version="$2"

    local podspec="$ROOT_DIR/Build/ReleasePodspecs/${pod}.podspec"

    log::step "PODS" "Publishing $pod to CocoaPods using generated podspec"

    if command -v metrics::start &>/dev/null; then
        metrics::start "publish_${pod}_trunk_push"
    fi

    if [[ ! -f "$podspec" ]]; then
        log::error "PODS" "Generated podspec not found: $podspec"
        return 1
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log::info "PODS" "DRY RUN: Would publish $pod version $version to CocoaPods using $podspec"
        return 0
    fi

    # Probe zip URL for binary distribution pods
    local core_modules=("MSPSharedLibraries" "MSPGoogleAdsTypes" "MSPCore" "MSPiOSCore")
    local is_binary=false

    for core in "${core_modules[@]}"; do
        if [[ "$pod" == "$core" ]]; then
            is_binary=true
            break
        fi
    done

    if [[ "$is_binary" == "true" ]]; then
        log::info "PODS" "$pod: Verifying binary zip availability"
        if ! probe_zip_url "$pod" "$version"; then
            log::error "PODS" "Binary zip not available, cannot publish"
            return 1
        fi
    fi

    # Publish based on mode
    if [[ "${MSP_RESUME_MODE:-0}" == "1" ]]; then
        if ! publish_pod_with_resume "$pod" "$version" "$podspec"; then
            log::error "PODS" "Failed to publish $pod to CocoaPods"
            return 1
        fi
    else
        if command -v msp_state_mark_pod_status &>/dev/null; then
            msp_state_mark_pod_status "$pod" "pending"
        fi

        if ! publish_podspec_with_retry "$podspec"; then
            log::error "PODS" "Failed to publish $pod to CocoaPods"
            if command -v msp_state_mark_pod_status &>/dev/null; then
                msp_state_mark_pod_status "$pod" "failed"
            fi
            if command -v metrics::end &>/dev/null; then
                metrics::end "publish_${pod}_trunk_push"
            fi
            return 1
        fi

        if command -v msp_state_mark_pod_status &>/dev/null; then
            msp_state_mark_pod_status "$pod" "published"
            msp_state_set_pod_trunk_verified "$pod" "true"
        fi

        if command -v metrics::end &>/dev/null; then
            metrics::end "publish_${pod}_trunk_push"
        fi
    fi

    log::success "PODS" "Published $pod to CocoaPods"
}

# ============================================================================
# Export Functions
# ============================================================================

export -f acquire_github_release_lock 2>/dev/null || true
export -f release_github_release_lock 2>/dev/null || true
export -f backup_github_release_assets 2>/dev/null || true
export -f restore_github_release_assets 2>/dev/null || true
export -f auto_fix_checksum_issue 2>/dev/null || true
export -f is_permanent_trunk_error 2>/dev/null || true
export -f publish_pod_with_resume 2>/dev/null || true
export -f publish_pod_to_cocoapods 2>/dev/null || true
