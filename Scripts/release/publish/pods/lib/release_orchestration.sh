#!/usr/bin/env bash
# ============================================================================
# Release Orchestration Module
# ============================================================================
# Module: release_orchestration.sh
# Purpose: Pod release orchestration and workflow management
# Extracted from: publish.sh
#
# Functions:
#   - release_msp_ioscore: Release MSPiOSCore (foundation - required by all modules)
#   - release_msp_shared_libraries: Release MSPSharedLibraries (foundation dependency)
#   - release_msp_googleadstypes: Release MSPGoogleAdsTypes (required by Google/Amazon adapters)
#   - release_single_adapter: Release a single adapter (helper for parallel processing)
#   - release_adapters: Release all adapters (parallel processing)
#   - release_msp_core: Release MSPCore (main framework)
#
# Dependencies:
#   - Logging functions (log::info, log::error, log::success, log::step, log_section, log_title)
#   - ROOT_DIR, VERSION, DRY_RUN, PODS_MODULES environment variables
#   - pod_publish.sh module (publish_pod_to_cocoapods)
#   - novacore_build.sh module (ensure_novacore_xcframework)
#   - Pod availability functions (check_pod_availability, smart_wait_for_pod_availability)
#   - Podspec functions (update_podspec_for_release, update_adapter_podspec_dependencies)
#   - GitHub release functions (create_github_release_for_pod)
#   - Binary distribution functions (is_binary_distribution, ensure_zip_file_exists_for_pod)
#   - Version functions (update_config_plist_version)
#   - State functions (msp_state_mark_step_failed)
#   - Metrics functions (metrics::start, metrics::end, metrics::record)
#   - Process management (register_child_pid, register_temp_resource)
#
# Environment Variables:
#   - ROOT_DIR: Project root directory
#   - VERSION: Release version string
#   - DRY_RUN: "true" to skip actual publishing
#   - PODS_MODULES: Space-separated list of pods to release
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_RELEASE_ORCHESTRATION_SOURCED:-}" ]] && return 0
readonly _RELEASE_ORCHESTRATION_SOURCED=1

# ============================================================================
# CDN module: source early so all check_pod_availability calls use CDN checks
# ============================================================================
_orch_cdn_module="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)/Scripts/lib/shared/cocoapods_cdn.sh"
if [[ -f "$_orch_cdn_module" ]] && ! command -v cocoapods_cdn_check_pod_available >/dev/null 2>&1; then
    # shellcheck source=/dev/null
    source "$_orch_cdn_module"
fi
# Initialize CDN metrics accumulator for this release session
if command -v cocoapods_cdn_metrics_init >/dev/null 2>&1; then
    cocoapods_cdn_metrics_init
fi
unset _orch_cdn_module

# ============================================================================
# Release MSPiOSCore (Step 0)
# ============================================================================
# MSPiOSCore is the foundation module required by all other modules.
# It must be released first and be available before other pods can be released.
#
# Returns:
#   0 if MSPiOSCore released successfully (or already published)
#   1 if release failed
# ============================================================================
release_msp_ioscore() {
    log_section "Step 0: Releasing MSPiOSCore (foundation - required by all modules)"

    # Start timing
    if command -v metrics::start &>/dev/null; then
        metrics::start "pod_MSPiOSCore"
    fi

    # Check if MSPiOSCore is already published (idempotency)
    if [[ "$DRY_RUN" != "true" ]]; then
        if check_pod_availability "MSPiOSCore" "$VERSION"; then
            log::info "PODS" "MSPiOSCore $VERSION is already published to CocoaPods, skipping release"
            log::success "PODS" "MSPiOSCore $VERSION already available"
            # Even when skipping the publish, the local specs repo must be updated.
            # MSPSharedLibraries and MSPGoogleAdsTypes pod trunk push validate against
            # the LOCAL specs repo — if it doesn't contain MSPiOSCore yet, lint fails.
            log::step "PODS" "Updating local CocoaPods specs repo (required even when MSPiOSCore publish is skipped)..."
            local skip_repo_update_attempts=0
            local skip_repo_update_max=3
            while [[ $skip_repo_update_attempts -lt $skip_repo_update_max ]]; do
                ((skip_repo_update_attempts++)) || true
                if update_specs_repo; then
                    log::success "PODS" "Local specs repo updated (attempt $skip_repo_update_attempts)"
                    break
                fi
                if [[ $skip_repo_update_attempts -lt $skip_repo_update_max ]]; then
                    log::warn "PODS" "Specs repo update failed (attempt $skip_repo_update_attempts/$skip_repo_update_max), retrying in 30s..."
                    sleep 30
                else
                    log::error "PODS" "Specs repo update failed after $skip_repo_update_max attempts — MSPSharedLibraries/MSPGoogleAdsTypes will likely fail to resolve MSPiOSCore"
                    return 1
                fi
            done
            if command -v metrics::end &>/dev/null; then
                metrics::end "pod_MSPiOSCore"
            fi
            return 0
        fi
    fi

    # Ensure zip file exists for binary distribution pods (Resume-safe)
    if is_binary_distribution "MSPiOSCore"; then
        log::info "PODS" "Verifying zip file exists for binary distribution pod..."

        if ! ensure_zip_file_exists_for_pod "MSPiOSCore" "$VERSION"; then
            log::error "PODS" "Failed to ensure zip file exists for MSPiOSCore"

            if [[ "${DRY_RUN:-true}" == "false" ]]; then
                log::error "PODS" "[FAIL-FAST] Cannot proceed without zip file. Aborting."
                exit 1
            fi

            return 1
        fi

        log::success "PODS" "Zip file verified/recreated for MSPiOSCore"
    fi

    # Update podspec (now guaranteed to succeed if binary distribution)
    if ! update_podspec_for_release "MSPiOSCore" "$VERSION"; then
        # FAIL-FAST: Immediately abort if podspec generation fails (release tier only)
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log::error "PODS" "[FAIL-FAST] Podspec generation failed for MSPiOSCore. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Podspec generation failed for MSPiOSCore" "1"
            exit 1
        fi
        return 1
    fi

    # FAIL-FAST: Verify generated podspec exists (release tier only)
    local podspec_path="$ROOT_DIR/Build/ReleasePodspecs/MSPiOSCore.podspec"
    if [[ "${DRY_RUN:-true}" == "false" ]] && [[ ! -f "$podspec_path" ]]; then
        log::error "PODS" "[FAIL-FAST] Generated podspec not found: $podspec_path. Aborting release."
        msp_state_mark_step_failed "pods_publish" "Generated podspec not found: $podspec_path" "1"
        exit 1
    fi

    # Create GitHub release (with resume support)
    local github_release_status="unknown"
    if command -v msp_state_get_pod_github_release_created &>/dev/null; then
        github_release_status=$(msp_state_get_pod_github_release_created "MSPiOSCore")
    fi

    if [[ "$github_release_status" == "true" ]]; then
        log::info "PODS" "GitHub release for MSPiOSCore already created (state: true), skipping"
    else
        log::info "PODS" "Creating/retrying GitHub release for MSPiOSCore (state: $github_release_status)"
        create_github_release_for_pod "MSPiOSCore" "$VERSION"
    fi

    # Publish to CocoaPods
    # Phase R1.11: Fail-fast if publication fails (prevent wait loop)
    if ! publish_pod_to_cocoapods "MSPiOSCore" "$VERSION"; then
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log::error "PODS" "[FAIL-FAST] Failed to publish MSPiOSCore to CocoaPods. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Failed to publish MSPiOSCore" "1"
            exit 1
        fi
        return 1
    fi

    # Wait for availability (skip in dry-run mode)
    if [[ "$DRY_RUN" != "true" ]]; then
        smart_wait_for_pod_availability "MSPiOSCore" "$VERSION" "foundation module required by all other modules"

        # Update local specs repo after MSPiOSCore is confirmed available on CDN.
        # Required: MSPSharedLibraries and MSPGoogleAdsTypes pod trunk push validate
        # against the LOCAL specs repo, so it must contain MSPiOSCore before they run.
        log::step "PODS" "Updating local CocoaPods specs repo (required for MSPSharedLibraries/MSPGoogleAdsTypes pod trunk push lint)..."
        local ios_core_repo_update_attempts=0
        local ios_core_repo_update_max=3
        while [[ $ios_core_repo_update_attempts -lt $ios_core_repo_update_max ]]; do
            ((ios_core_repo_update_attempts++)) || true
            if update_specs_repo; then
                log::success "PODS" "Local specs repo updated (attempt $ios_core_repo_update_attempts)"
                break
            fi
            if [[ $ios_core_repo_update_attempts -lt $ios_core_repo_update_max ]]; then
                log::warn "PODS" "Specs repo update failed (attempt $ios_core_repo_update_attempts/$ios_core_repo_update_max), retrying in 30s..."
                sleep 30
            else
                log::error "PODS" "Specs repo update failed after $ios_core_repo_update_max attempts — MSPSharedLibraries/MSPGoogleAdsTypes pod trunk push will likely fail to resolve MSPiOSCore"
                return 1
            fi
        done
    fi

    # End timing
    if command -v metrics::end &>/dev/null; then
        metrics::end "pod_MSPiOSCore"
        metrics::record "cocoapods_success_count" 1 "count"
    fi

    log::success "PODS" "MSPiOSCore released successfully"
    return 0
}

# ============================================================================
# Release MSPSharedLibraries (Step 1)
# ============================================================================
# MSPSharedLibraries is a foundation dependency required by adapters.
# It should be released after MSPiOSCore.
#
# Returns:
#   0 if MSPSharedLibraries released successfully (or already published)
#   1 if release failed
# ============================================================================
release_msp_shared_libraries() {
    log_section "Step 1: Releasing MSPSharedLibraries (foundation dependency)"

    # ========================================================================
    # Idempotency Check: Skip if already published (Resume-safe)
    # ========================================================================
    # Rationale:
    # - Resume may be called after MSPSharedLibraries was already published
    # - Re-running create_github_release_for_pod() can overwrite correct checksum
    # - check_pod_availability() verifies if pod is available on CocoaPods CDN
    # - If available, skip all steps (no zip upload, no podspec regeneration)
    # ========================================================================
    if [[ "$DRY_RUN" != "true" ]]; then
        if check_pod_availability "MSPSharedLibraries" "$VERSION"; then
            log::info "PODS" "MSPSharedLibraries $VERSION is already published to CocoaPods"

            # Enhanced Check: Verify GitHub Release zip matches local zip
            if is_binary_distribution "MSPSharedLibraries"; then
                if ! verify_and_fix_github_release_zip "MSPSharedLibraries" "$VERSION"; then
                    log::error "PODS" "Failed to verify/fix GitHub Release zip for MSPSharedLibraries"

                    # In release mode, this is a critical failure
                    if [[ "${DRY_RUN:-true}" == "false" ]]; then
                        log::error "PODS" "[FAIL-FAST] Cannot continue with incorrect GitHub Release zip"
                        log::error "PODS" "Adapters depending on MSPSharedLibraries will fail validation"

                        # End timing if metrics enabled
                        if command -v metrics::end &>/dev/null; then
                            metrics::end "pod_MSPSharedLibraries"
                        fi

                        return 1
                    fi
                fi
            fi

            log::success "PODS" "MSPSharedLibraries $VERSION already available and verified"

            # End timing if metrics enabled
            if command -v metrics::end &>/dev/null; then
                metrics::end "pod_MSPSharedLibraries"
            fi

            return 0
        fi
    fi

    # Ensure zip file exists for binary distribution pods (Resume-safe)
    if is_binary_distribution "MSPSharedLibraries"; then
        log::info "PODS" "Verifying zip file exists for binary distribution pod..."

        if ! ensure_zip_file_exists_for_pod "MSPSharedLibraries" "$VERSION"; then
            log::error "PODS" "Failed to ensure zip file exists for MSPSharedLibraries"

            if [[ "${DRY_RUN:-true}" == "false" ]]; then
                log::error "PODS" "[FAIL-FAST] Cannot proceed without zip file. Aborting."
                exit 1
            fi

            return 1
        fi

        log::success "PODS" "Zip file verified/recreated for MSPSharedLibraries"
    fi

    # Update podspec (now guaranteed to succeed if binary distribution)
    if ! update_podspec_for_release "MSPSharedLibraries" "$VERSION"; then
        # FAIL-FAST: Immediately abort if podspec generation fails (release tier only)
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log::error "PODS" "[FAIL-FAST] Podspec generation failed for MSPSharedLibraries. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Podspec generation failed for MSPSharedLibraries" "1"
            exit 1
        fi
        return 1
    fi

    # FAIL-FAST: Verify generated podspec exists (release tier only)
    local podspec_path="$ROOT_DIR/Build/ReleasePodspecs/MSPSharedLibraries.podspec"
    if [[ "${DRY_RUN:-true}" == "false" ]] && [[ ! -f "$podspec_path" ]]; then
        log::error "PODS" "[FAIL-FAST] Generated podspec not found: $podspec_path. Aborting release."
        msp_state_mark_step_failed "pods_publish" "Generated podspec not found: $podspec_path" "1"
        exit 1
    fi

    # Create GitHub release (with resume support)
    local github_release_status="unknown"
    if command -v msp_state_get_pod_github_release_created &>/dev/null; then
        github_release_status=$(msp_state_get_pod_github_release_created "MSPSharedLibraries")
    fi

    if [[ "$github_release_status" == "true" ]]; then
        log::info "PODS" "GitHub release for MSPSharedLibraries already created (state: true), skipping"
    else
        log::info "PODS" "Creating/retrying GitHub release for MSPSharedLibraries (state: $github_release_status)"
        create_github_release_for_pod "MSPSharedLibraries" "$VERSION"
    fi

    # Publish to CocoaPods
    # Phase R1.11: Fail-fast if publication fails (prevent wait loop)
    if ! publish_pod_to_cocoapods "MSPSharedLibraries" "$VERSION"; then
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log::error "PODS" "[FAIL-FAST] Failed to publish MSPSharedLibraries to CocoaPods. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Failed to publish MSPSharedLibraries" "1"
            exit 1
        fi
        return 1
    fi

    # NOTE: Pod availability check moved to parallel release wrapper
    # This allows MSPSharedLibraries and MSPGoogleAdsTypes to be published in parallel
    # Availability will be checked before adapter releases (in release_adapters function)

    # End timing
    if command -v metrics::end &>/dev/null; then
        metrics::end "pod_MSPSharedLibraries"
        metrics::record "cocoapods_success_count" 1 "count"
    fi

    log::success "PODS" "MSPSharedLibraries released successfully"
}

# ============================================================================
# Release MSPGoogleAdsTypes (Step 1.5)
# ============================================================================
# MSPGoogleAdsTypes is required by MSPGoogleAdapter and MSPAmazonAdapter.
# It can be released in parallel with MSPSharedLibraries.
#
# Returns:
#   0 if MSPGoogleAdsTypes released successfully (or already published)
#   1 if release failed
# ============================================================================
release_msp_googleadstypes() {
    log_section "Step 1.5: Releasing MSPGoogleAdsTypes (required by MSPGoogleAdapter and MSPAmazonAdapter)"

    # Start timing
    if command -v metrics::start &>/dev/null; then
        metrics::start "pod_MSPGoogleAdsTypes"
    fi

    # Check if MSPGoogleAdsTypes is already published (idempotency)
    if [[ "$DRY_RUN" != "true" ]]; then
        if check_pod_availability "MSPGoogleAdsTypes" "$VERSION"; then
            log::info "PODS" "MSPGoogleAdsTypes $VERSION is already published to CocoaPods, skipping release"
            log::success "PODS" "MSPGoogleAdsTypes $VERSION already available"
            if command -v metrics::end &>/dev/null; then
                metrics::end "pod_MSPGoogleAdsTypes"
            fi
            return 0
        fi
    fi

    # Ensure zip file exists for binary distribution pods (Resume-safe)
    if is_binary_distribution "MSPGoogleAdsTypes"; then
        log::info "PODS" "Verifying zip file exists for binary distribution pod..."

        if ! ensure_zip_file_exists_for_pod "MSPGoogleAdsTypes" "$VERSION"; then
            log::error "PODS" "Failed to ensure zip file exists for MSPGoogleAdsTypes"

            if [[ "${DRY_RUN:-true}" == "false" ]]; then
                log::error "PODS" "[FAIL-FAST] Cannot proceed without zip file. Aborting."
                exit 1
            fi

            return 1
        fi

        log::success "PODS" "Zip file verified/recreated for MSPGoogleAdsTypes"
    fi

    # Update podspec (now guaranteed to succeed if binary distribution)
    if ! update_podspec_for_release "MSPGoogleAdsTypes" "$VERSION"; then
        # FAIL-FAST: Immediately abort if podspec generation fails (release tier only)
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log::error "PODS" "[FAIL-FAST] Podspec generation failed for MSPGoogleAdsTypes. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Podspec generation failed for MSPGoogleAdsTypes" "1"
            exit 1
        fi
        return 1
    fi

    # FAIL-FAST: Verify generated podspec exists (release tier only)
    local podspec_path="$ROOT_DIR/Build/ReleasePodspecs/MSPGoogleAdsTypes.podspec"
    if [[ "${DRY_RUN:-true}" == "false" ]] && [[ ! -f "$podspec_path" ]]; then
        log::error "PODS" "[FAIL-FAST] Generated podspec not found: $podspec_path. Aborting release."
        msp_state_mark_step_failed "pods_publish" "Generated podspec not found: $podspec_path" "1"
        exit 1
    fi

    # Create GitHub release (with resume support)
    local github_release_status="unknown"
    if command -v msp_state_get_pod_github_release_created &>/dev/null; then
        github_release_status=$(msp_state_get_pod_github_release_created "MSPGoogleAdsTypes")
    fi

    if [[ "$github_release_status" == "true" ]]; then
        log::info "PODS" "GitHub release for MSPGoogleAdsTypes already created (state: true), skipping"
    else
        log::info "PODS" "Creating/retrying GitHub release for MSPGoogleAdsTypes (state: $github_release_status)"
        create_github_release_for_pod "MSPGoogleAdsTypes" "$VERSION"
    fi

    # Publish to CocoaPods
    # Phase R1.11: Fail-fast if publication fails (prevent wait loop)
    if ! publish_pod_to_cocoapods "MSPGoogleAdsTypes" "$VERSION"; then
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log::error "PODS" "[FAIL-FAST] Failed to publish MSPGoogleAdsTypes to CocoaPods. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Failed to publish MSPGoogleAdsTypes" "1"
            exit 1
        fi
        return 1
    fi

    # NOTE: Pod availability check moved to parallel release wrapper
    # MSPGoogleAdsTypes is only needed by MSPGoogleAdapter and MSPAmazonAdapter, which will check individually

    # End timing
    if command -v metrics::end &>/dev/null; then
        metrics::end "pod_MSPGoogleAdsTypes"
        metrics::record "cocoapods_success_count" 1 "count"
    fi

    log::success "PODS" "MSPGoogleAdsTypes released successfully"
}

# ============================================================================
# Release Single Adapter (Helper for Parallel Processing)
# ============================================================================
# Releases a single adapter pod. Used by release_adapters() for parallel execution.
#
# Args:
#   $1: adapter name (e.g., MSPPrebidAdapter)
#   $2: version (e.g., 1.0.0-rc.24)
#   $3: result_file - path to write result (SUCCESS/ERROR)
#
# Returns:
#   0 if adapter released successfully (or already published)
#   1 if release failed
# ============================================================================
release_single_adapter() {
    local adapter="$1"
    local version="$2"
    local result_file="$3"

    # Ensure ROOT_DIR is set in subprocess (parallel execution)
    if [[ -z "${ROOT_DIR:-}" ]]; then
        if command -v git >/dev/null 2>&1; then
            ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
        fi
        if [[ -z "${ROOT_DIR:-}" ]]; then
            ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
        fi
        export ROOT_DIR
    fi

    log_section "Releasing $adapter"

    # ========================================================================
    # Idempotency Check: Skip if already published (Resume-safe)
    # ========================================================================
    if [[ "$DRY_RUN" != "true" ]]; then
        if check_pod_availability "$adapter" "$version"; then
            log::info "PODS" "$adapter $version is already published to CocoaPods"

            # Enhanced Check: Verify GitHub Release zip matches local zip
            if is_binary_distribution "$adapter"; then
                if ! verify_and_fix_github_release_zip "$adapter" "$version"; then
                    log::error "PODS" "Failed to verify/fix GitHub Release zip for $adapter"
                    echo "ERROR: GitHub Release zip verification failed for $adapter" > "$result_file"

                    # In release mode, this is a failure
                    if [[ "${DRY_RUN:-true}" == "false" ]]; then
                        return 1
                    fi
                fi
            fi

            log::success "PODS" "$adapter $version already available and verified"
            echo "SUCCESS: $adapter already published" > "$result_file"
            return 0
        fi
    fi

    # Ensure zip file exists for binary distribution pods (Resume-safe)
    if is_binary_distribution "$adapter"; then
        log::info "PODS" "Verifying zip file exists for binary distribution pod..."

        if ! ensure_zip_file_exists_for_pod "$adapter" "$version"; then
            log::error "PODS" "Failed to ensure zip file exists for $adapter"
            echo "ERROR: Failed to ensure zip file exists for $adapter" > "$result_file"
            return 1
        fi

        log::success "PODS" "Zip file verified/recreated for $adapter"
    fi

    # Update podspec (now guaranteed to succeed if binary distribution)
    if ! update_podspec_for_release "$adapter" "$version"; then
        echo "ERROR: Failed to update podspec for $adapter" > "$result_file"
        # FAIL-FAST: Immediately abort if podspec generation fails (release tier only)
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log::error "PODS" "[FAIL-FAST] Podspec generation failed for $adapter. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Podspec generation failed for $adapter" "1"
        fi
        return 1
    fi

    # ========================================================================
    # DEBUG & CRITICAL FIX: Ensure ROOT_DIR before podspec verification
    # ========================================================================
    log::info "PODS" "[DEBUG] Before podspec verification for $adapter"
    log::info "PODS" "[DEBUG] ROOT_DIR current value: '${ROOT_DIR:-<EMPTY>}'"

    # CRITICAL: Re-ensure ROOT_DIR is set (defensive programming)
    if [[ -z "${ROOT_DIR:-}" ]]; then
        log::error "PODS" "[CRITICAL] ROOT_DIR is EMPTY before podspec verification!"
        log::error "PODS" "[CRITICAL] This should not happen - attempting emergency resolution..."

        # Try git method
        if command -v git >/dev/null 2>&1; then
            ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
            if [[ -n "$ROOT_DIR" ]]; then
                log::info "PODS" "[CRITICAL] ROOT_DIR resolved via git: $ROOT_DIR"
                export ROOT_DIR
            fi
        fi

        # Fallback
        if [[ -z "${ROOT_DIR:-}" ]]; then
            ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
            log::info "PODS" "[CRITICAL] ROOT_DIR resolved via fallback: $ROOT_DIR"
            export ROOT_DIR
        fi
    else
        log::info "PODS" "[DEBUG] ROOT_DIR is set: $ROOT_DIR"
    fi
    # ========================================================================

    # FAIL-FAST: Verify generated podspec exists (release tier only)
    local podspec_path="$ROOT_DIR/Build/ReleasePodspecs/${adapter}.podspec"

    log::info "PODS" "[DEBUG] Constructed podspec_path: $podspec_path"
    log::info "PODS" "[DEBUG] Checking if file exists: [[ -f \"$podspec_path\" ]]"

    if [[ "${DRY_RUN:-true}" == "false" ]] && [[ ! -f "$podspec_path" ]]; then
        log::error "PODS" "[DEBUG] File check FAILED"
        log::error "PODS" "[DEBUG] ROOT_DIR: '${ROOT_DIR}'"
        log::error "PODS" "[DEBUG] adapter: '$adapter'"
        log::error "PODS" "[DEBUG] podspec_path: '$podspec_path'"
        log::error "PODS" "[DEBUG] Listing Build/ReleasePodspecs/:"
        if [[ -d "$ROOT_DIR/Build/ReleasePodspecs/" ]]; then
            ls -la "$ROOT_DIR/Build/ReleasePodspecs/" 2>/dev/null || log::error "PODS" "[DEBUG] Failed to list"
        else
            log::error "PODS" "[DEBUG] Directory does not exist: $ROOT_DIR/Build/ReleasePodspecs/"
        fi

        echo "ERROR: Generated podspec not found: $podspec_path" > "$result_file"
        log::error "PODS" "[FAIL-FAST] Generated podspec not found: $podspec_path. Aborting release."
        msp_state_mark_step_failed "pods_publish" "Generated podspec not found: $podspec_path" "1"
        return 1
    fi

    log::info "PODS" "[DEBUG] Podspec file exists: $podspec_path"

    # Update dependencies
    log::info "PODS" "[DEBUG] About to call update_adapter_podspec_dependencies for $adapter"
    log::info "PODS" "[DEBUG] ROOT_DIR before call: '${ROOT_DIR:-<EMPTY>}'"

    if ! update_adapter_podspec_dependencies "$adapter" "$version"; then
        echo "ERROR: Failed to update dependencies for $adapter" > "$result_file"
        log::error "PODS" "[DEBUG] update_adapter_podspec_dependencies failed for $adapter"
        return 1
    fi

    log::info "PODS" "[DEBUG] update_adapter_podspec_dependencies succeeded for $adapter"

    # Create GitHub release for adapter (all adapters are binary distribution)
    local github_release_status="unknown"
    if command -v msp_state_get_pod_github_release_created &>/dev/null; then
        github_release_status=$(msp_state_get_pod_github_release_created "$adapter")
    fi

    if [[ "$github_release_status" == "true" ]]; then
        log::info "PODS" "GitHub release for $adapter already created (state: true), skipping"
    else
        log::info "PODS" "Creating/retrying GitHub release for $adapter (state: $github_release_status)"
        create_github_release_for_pod "$adapter" "$version"
    fi

    # Publish to CocoaPods
    if ! publish_pod_to_cocoapods "$adapter" "$version"; then
        echo "ERROR: Failed to publish $adapter to CocoaPods" > "$result_file"
        return 1
    fi

    # Note: Availability checking is done after ALL adapters are released
    echo "SUCCESS: $adapter released successfully" > "$result_file"
    return 0
}

# ============================================================================
# Release Adapters (Step 2)
# ============================================================================
# Releases all adapter pods in parallel after verifying dependencies.
# Includes pre-flight checks, NovaCore build, and parallel release orchestration.
#
# Uses global VERSION variable (set in publish.sh main()).
#
# Returns:
#   0 if all adapters released successfully
#   1 if any adapter failed
# ============================================================================
release_adapters() {
    # Use global VERSION variable (set at Line 168) instead of local parameter
    # This allows subshells to access $VERSION for parallel dependency checks

    if command -v log_title &>/dev/null; then
        log_title "Releasing Adapters: $VERSION"
    else
        log_section "Releasing Adapters: $VERSION"
    fi

    # ========================================================================
    # Step -1: Extract adapters list early (needed for version updates)
    # ========================================================================
    local core_modules=("MSPSharedLibraries" "MSPGoogleAdsTypes" "MSPCore" "MSPiOSCore")
    local adapters=()

    # Split PODS_MODULES space-separated string and filter out core modules
    # Intentional word-splitting: PODS_MODULES is a space-delimited name list
    # shellcheck disable=SC2086
    for module in $PODS_MODULES; do
        local is_core=false
        for core in "${core_modules[@]}"; do
            if [[ "$module" == "$core" ]]; then
                is_core=true
                break
            fi
        done
        if [[ "$is_core" == "false" ]]; then
            adapters+=("$module")
        fi
    done

    if [[ ${#adapters[@]} -eq 0 ]]; then
        log::warn "PODS" "No adapters found in PODS_MODULES. Using default adapter list for backward compatibility."
        adapters=("MSPFacebookAdapter" "MSPGoogleAdapter" "MSPNovaAdapter" "MSPAmazonAdapter" "MSPPrebidAdapter")
    fi

    log::info "PODS" "Adapters to release: ${adapters[*]}"

    # ========================================================================
    # Step 0.9: Sync SDK version SSOT and NovaCore Config.plist
    # ========================================================================
    # IMPORTANT: Version updates MUST happen BEFORE XCFramework builds so
    # that the compiled binaries contain the correct release version numbers.
    # Adapter SDK versions are read at runtime from each third-party SDK
    # (e.g. DTBAds.version(), Prebid.shared.version) — no patching needed.
    if [[ "$DRY_RUN" != "true" ]]; then
        log_section "Step 0.9: Syncing NovaCore Config.plist from SSOT"
        # SSOT (sdk_version.conf) is already committed by modular.sh — just read it
        local sync_version="$VERSION"
        if read_sdk_version_from_config >/dev/null 2>&1; then
            sync_version="$(read_sdk_version_from_config)"
        fi

        # Update NovaCore SDKVersion in Config.plist and commit immediately
        if ! update_and_commit_plist_version "novacore" "$sync_version"; then
            log::warn "PODS" "[NovaCore] Failed to update Config.plist SDKVersion (non-fatal)"
        fi
    fi

    # ========================================================================
    # Step 0: Ensure NovaCore.xcframework is available for MSPNovaAdapter
    # ========================================================================
    log_section "Step 0: Ensuring NovaCore.xcframework is available"

    if ! ensure_novacore_xcframework; then
        log::error "PODS" "Failed to ensure NovaCore.xcframework availability"
        log::error "PODS" "Cannot proceed with MSPNovaAdapter release"
        log::error "PODS" "Please fix the issue and try again"
        return 1
    fi

    log::success "PODS" "NovaCore.xcframework is ready for MSPNovaAdapter"

    # Rebuild MSPNovaAdapter XCFramework now that NovaCore is available
    # (MSPNovaAdapter was excluded from the earlier adapter rebuild because it depends on NovaCore)
    if [[ "$DRY_RUN" != "true" ]]; then
        if is_binary_distribution "MSPNovaAdapter"; then
            log::step "PODS" "Rebuilding MSPNovaAdapter XCFramework (depends on NovaCore)..."
            local nova_module_dir
            nova_module_dir=$(get_module_dir "MSPNovaAdapter")
            local build_script="$ROOT_DIR/Scripts/xcframeworks/build_module.sh"
            if [[ -x "$build_script" ]]; then
                "$build_script" "$nova_module_dir" || log::warn "PODS" "MSPNovaAdapter XCFramework rebuild failed (non-fatal)"
            fi
        fi
    fi

    # Pre-flight check: GitHub CLI authentication (required for binary distribution adapters)
    if [[ "${DRY_RUN:-true}" == "false" ]]; then
        log::step "PODS" "Pre-flight check: GitHub CLI authentication"
        if ! unified_github_cli_auth_check; then
            log::error "PODS" "GitHub CLI authentication failed - cannot proceed with adapter releases"
            log::error "PODS" "Binary distribution adapters require GitHub CLI to upload zip files"
            log::error "PODS" "Please fix GitHub CLI authentication before retrying"
            return 1
        fi
    else
        log::info "PODS" "Dry-run mode: Skipping GitHub CLI authentication check"
    fi

    log_section "Step 2: Releasing Adapters that depend on MSPSharedLibraries (in parallel)"

    # Ensure MSPSharedLibraries and MSPGoogleAdsTypes are available before adapter releases
    log::step "PODS" "Verifying MSPSharedLibraries and MSPGoogleAdsTypes availability before adapter releases..."

    # Attempt specs repo update — non-fatal: CDN direct check is the authoritative
    # availability signal (cocoapods_cdn_check_pod_available). pod repo update is
    # best-effort only; failure is expected in CI environments without local spec repos.
    log::step "PODS" "Attempting CocoaPods specs repo update (non-fatal, CDN check is authoritative)..."
    if ! update_specs_repo 2>/dev/null; then
        log::warn "PODS" "Specs repo update failed — continuing with CDN direct check"
    fi

    # Create temporary files for parallel checks
    local shared_libs_check_file=$(mktemp "/tmp/msp_availability_check_shared_libs_XXXXXX")
    local google_ads_types_check_file=$(mktemp "/tmp/msp_availability_check_google_ads_types_XXXXXX")

    # Start MSPSharedLibraries check in background
    (
        if smart_wait_for_pod_availability "MSPSharedLibraries" "$VERSION" "before parallel adapter releases"; then
            echo "SUCCESS:MSPSharedLibraries" > "$shared_libs_check_file"
            exit 0
        else
            echo "FAILED:MSPSharedLibraries" > "$shared_libs_check_file"
            exit 1
        fi
    ) &
    local SHARED_LIBS_CHECK_PID=$!
    register_child_pid $SHARED_LIBS_CHECK_PID "MSPSharedLibraries availability check"
    register_temp_resource "$shared_libs_check_file"

    # Start MSPGoogleAdsTypes check in background
    (
        if smart_wait_for_pod_availability "MSPGoogleAdsTypes" "$VERSION" "before parallel adapter releases"; then
            echo "SUCCESS:MSPGoogleAdsTypes" > "$google_ads_types_check_file"
            exit 0
        else
            echo "FAILED:MSPGoogleAdsTypes" > "$google_ads_types_check_file"
            exit 1
        fi
    ) &
    local GOOGLE_ADS_TYPES_CHECK_PID=$!
    register_child_pid $GOOGLE_ADS_TYPES_CHECK_PID "MSPGoogleAdsTypes availability check"
    register_temp_resource "$google_ads_types_check_file"

    log::info "PODS" "Waiting for both availability checks to complete..."

    # Maximum wait time: 90 minutes (5400s)
    local timeout_seconds=5400
    local check_interval=5
    local elapsed=0

    # Track completion status
    local shared_libs_check_done=false
    local google_ads_types_check_done=false
    local shared_libs_check_exit_code=""
    local google_ads_types_check_exit_code=""

    # Parallel wait loop with timeout
    while [[ $elapsed -lt $timeout_seconds ]]; do
        # Check if MSPSharedLibraries check is still running
        if [[ "$shared_libs_check_done" == "false" ]]; then
            if ! kill -0 $SHARED_LIBS_CHECK_PID 2>/dev/null; then
                # Process has exited, get its exit code via wait
                wait $SHARED_LIBS_CHECK_PID 2>/dev/null
                shared_libs_check_exit_code=$?
                shared_libs_check_done=true
                log::info "PODS" "MSPSharedLibraries availability check completed (exit code: $shared_libs_check_exit_code)"
            fi
        fi

        # Check if MSPGoogleAdsTypes check is still running
        if [[ "$google_ads_types_check_done" == "false" ]]; then
            if ! kill -0 $GOOGLE_ADS_TYPES_CHECK_PID 2>/dev/null; then
                # Process has exited, get its exit code via wait
                wait $GOOGLE_ADS_TYPES_CHECK_PID 2>/dev/null
                google_ads_types_check_exit_code=$?
                google_ads_types_check_done=true
                log::info "PODS" "MSPGoogleAdsTypes availability check completed (exit code: $google_ads_types_check_exit_code)"
            fi
        fi

        # Check if both checks are done
        if [[ "$shared_libs_check_done" == "true" ]] && [[ "$google_ads_types_check_done" == "true" ]]; then
            log::success "PODS" "Both availability checks completed"
            break
        fi

        # Progress reporting every minute
        if [[ $((elapsed % 60)) -eq 0 ]] && [[ $elapsed -gt 0 ]]; then
            local remaining=$((timeout_seconds - elapsed))
            log::debug "PODS" "Availability checks: ${elapsed}s elapsed, ${remaining}s remaining"
            if [[ "$shared_libs_check_done" == "false" ]]; then
                log::debug "PODS" "   - MSPSharedLibraries: still checking"
            fi
            if [[ "$google_ads_types_check_done" == "false" ]]; then
                log::debug "PODS" "   - MSPGoogleAdsTypes: still checking"
            fi
        fi

        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done

    # Check for timeout
    if [[ "$shared_libs_check_done" == "false" ]] || [[ "$google_ads_types_check_done" == "false" ]]; then
        log::warn "PODS" "Dependency availability checks TIMED OUT after ${timeout_seconds}s (90 minutes)"
        log::warn "PODS" "This may indicate CDN sync delay. Common causes:"
        log::warn "PODS" "  1. CocoaPods CDN sync is slow (normal, can take up to 2 hours)"
        log::warn "PODS" "  2. Pod trunk push is still processing"
        log::warn "PODS" "  3. Network connectivity issues"

        if [[ "$shared_libs_check_done" == "false" ]]; then
            log::warn "PODS" "   - MSPSharedLibraries check: timed out (CDN may still be syncing)"
            kill -TERM $SHARED_LIBS_CHECK_PID 2>/dev/null || true
        fi
        if [[ "$google_ads_types_check_done" == "false" ]]; then
            log::warn "PODS" "   - MSPGoogleAdsTypes check: timed out (CDN may still be syncing)"
            kill -TERM $GOOGLE_ADS_TYPES_CHECK_PID 2>/dev/null || true
        fi

        # Cleanup temp files
        rm -f "$shared_libs_check_file" "$google_ads_types_check_file"
        log::debug "PODS" "[CLEANUP] Cleaned up dependency availability check temporary resources"

        return 1
    fi

    # =========================================================================
    # Process Results for MSPSharedLibraries Availability
    # =========================================================================
    local shared_libs_available=false

    # Check result file (primary indicator of success)
    if [[ -f "$shared_libs_check_file" ]] && grep -q "SUCCESS" "$shared_libs_check_file"; then
        shared_libs_available=true
        log::success "PODS" "MSPSharedLibraries $VERSION is available"
    else
        log::warn "PODS" "MSPSharedLibraries $VERSION is not yet available"

        # Detailed failure reason
        if [[ "$shared_libs_check_done" == "false" ]]; then
            log::warn "PODS" "Reason: Timeout (check did not complete in ${timeout_seconds}s) - CDN sync may be delayed"
        elif [[ -n "$shared_libs_check_exit_code" ]] && [[ "$shared_libs_check_exit_code" != "0" ]]; then
            log::error "PODS" "Reason: Check exit code $shared_libs_check_exit_code"
        else
            log::error "PODS" "Reason: Result file missing or does not contain SUCCESS"
        fi
    fi

    # =========================================================================
    # Process Results for MSPGoogleAdsTypes Availability
    # =========================================================================
    local google_ads_types_available=false

    # Check result file (primary indicator of success)
    if [[ -f "$google_ads_types_check_file" ]] && grep -q "SUCCESS" "$google_ads_types_check_file"; then
        google_ads_types_available=true
        log::success "PODS" "MSPGoogleAdsTypes $VERSION is available"
    else
        log::warn "PODS" "MSPGoogleAdsTypes $VERSION is not yet available"

        # Detailed failure reason
        if [[ "$google_ads_types_check_done" == "false" ]]; then
            log::warn "PODS" "Reason: Timeout (check did not complete in ${timeout_seconds}s) - CDN sync may be delayed"
        elif [[ -n "$google_ads_types_check_exit_code" ]] && [[ "$google_ads_types_check_exit_code" != "0" ]]; then
            log::error "PODS" "Reason: Check exit code $google_ads_types_check_exit_code"
        else
            log::error "PODS" "Reason: Result file missing or does not contain SUCCESS"
        fi
    fi

    # Cleanup temp files (comprehensive)
    rm -f "$shared_libs_check_file" "$google_ads_types_check_file"
    log::debug "PODS" "[CLEANUP] Cleaned up dependency availability check temporary resources"

    # Check if both are available
    if [[ "$shared_libs_available" != "true" ]] || [[ "$google_ads_types_available" != "true" ]]; then
        log::error "PODS" "One or more required dependencies are not available, cannot proceed with adapter releases"
        return 1
    fi

    log::success "PODS" "Both MSPSharedLibraries and MSPGoogleAdsTypes are available"

    # CRITICAL: Also ensure MSPiOSCore is available (adapters depend on it)
    log::step "PODS" "Verifying MSPiOSCore availability before adapter releases..."
    if ! smart_wait_for_pod_availability "MSPiOSCore" "$VERSION" "required by all adapters"; then
        log::error "PODS" "MSPiOSCore $VERSION not available, cannot proceed with adapter releases"
        log::error "PODS" "All adapters depend on MSPiOSCore. Please wait for CDN sync and retry."
        return 1
    fi

    log::success "PODS" "All required dependencies (MSPSharedLibraries, MSPGoogleAdsTypes, MSPiOSCore) are available, proceeding with parallel adapter releases"

    # adapters array already extracted at function start (Step -1)
    log::info "PODS" "Releasing adapters from PODS_MODULES: ${adapters[*]}"

    # ========================================================================
    # Step 0.5: Pre-flight checks for all adapters
    # ========================================================================
    log_section "Step 0.5: Pre-flight checks for adapters"

    # Pre-check each adapter's requirements before starting parallel releases
    for adapter in "${adapters[@]}"; do
        log::info "PODS" "Pre-checking $adapter requirements..."

        # MSPNovaAdapter: Verify Binary/NovaCore.xcframework exists and is valid
        if [[ "$adapter" == "MSPNovaAdapter" ]]; then
            local novacore_path="$ROOT_DIR/Build/ReleaseArtifacts/Binary/NovaCore.xcframework"

            # This should never happen if Step 0 succeeded, but double-check
            if [[ ! -d "$novacore_path" ]]; then
                log::error "PODS" "Pre-flight check failed: $adapter"
                log::error "PODS" "NovaCore.xcframework not found: $novacore_path"
                log::error "PODS" "This should have been built in Step 0"
                log::error "PODS" "Something went wrong - cannot proceed"
                return 1
            fi

            # Verify XCFramework is valid
            if [[ ! -f "$novacore_path/Info.plist" ]]; then
                log::error "PODS" "Pre-flight check failed: $adapter"
                log::error "PODS" "NovaCore.xcframework is invalid (missing Info.plist)"
                log::error "PODS" "Path: $novacore_path"
                return 1
            fi

            log::success "PODS" "MSPNovaAdapter pre-flight check passed (NovaCore.xcframework is valid)"
        else
            # Other adapters: Check Build/ReleaseArtifacts/XCFrameworks/<Adapter>.xcframework exists
            local xcframework_path="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks/${adapter}.xcframework"

            if [[ ! -d "$xcframework_path" ]]; then
                log::error "PODS" "Pre-flight check failed: $adapter"
                log::error "PODS" "XCFramework not found: $xcframework_path"
                log::error "PODS" "Expected location: Build/ReleaseArtifacts/XCFrameworks/${adapter}.xcframework"
                log::error "PODS" "Cannot proceed with adapter releases - missing required file"
                log::error "PODS" ""
                log::error "PODS" "Please build the XCFramework first:"
                log::error "PODS" "  ./Scripts/xcframeworks/build_module.sh $adapter"
                return 1
            fi

            # Verify XCFramework is valid
            if [[ ! -f "$xcframework_path/Info.plist" ]]; then
                log::error "PODS" "Pre-flight check failed: $adapter"
                log::error "PODS" "XCFramework is invalid (missing Info.plist)"
                log::error "PODS" "Path: $xcframework_path"
                log::error "PODS" "Please rebuild the XCFramework"
                return 1
            fi

            log::success "PODS" "$adapter pre-flight check passed (XCFramework exists)"
        fi
    done

    log::success "PODS" "All adapter pre-flight checks passed"

    # Update local specs repo before parallel adapter releases.
    # Required: adapter pod trunk push validates dependencies (MSPSharedLibraries, MSPGoogleAdsTypes,
    # MSPiOSCore) against the LOCAL specs repo. CDN check above confirmed those pods are available,
    # so pod repo update should succeed here.
    log::step "PODS" "Updating local CocoaPods specs repo (required for adapter pod trunk push lint)..."
    local adapter_repo_update_attempts=0
    local adapter_repo_update_max=3
    while [[ $adapter_repo_update_attempts -lt $adapter_repo_update_max ]]; do
        ((adapter_repo_update_attempts++)) || true
        if update_specs_repo; then
            log::success "PODS" "Local specs repo updated (attempt $adapter_repo_update_attempts)"
            break
        fi
        if [[ $adapter_repo_update_attempts -lt $adapter_repo_update_max ]]; then
            log::warn "PODS" "Specs repo update failed (attempt $adapter_repo_update_attempts/$adapter_repo_update_max), retrying in 30s..."
            sleep 30
        else
            log::error "PODS" "Specs repo update failed after $adapter_repo_update_max attempts — adapter pod trunk push will likely fail to resolve MSPSharedLibraries/MSPGoogleAdsTypes/MSPiOSCore"
            return 1
        fi
    done

    # ========================================================================
    # Step 1: Start parallel adapter releases
    # ========================================================================
    local pids=()
    local result_files=()
    local log_files=()
    local temp_dir="/tmp/msp_parallel_release_$$"

    # Create temporary directory for result files
    mkdir -p "$temp_dir"

    # Start all adapter releases in parallel
    for adapter in "${adapters[@]}"; do
        local result_file="$temp_dir/${adapter}_result.txt"
        local log_file="$temp_dir/${adapter}_log.txt"
        result_files+=("$result_file")
        log_files+=("$log_file")
        register_temp_resource "$result_file"
        register_temp_resource "$log_file"

        # Start adapter release in background with output redirection
        release_single_adapter "$adapter" "$VERSION" "$result_file" > "$log_file" 2>&1 &
        local pid=$!
        pids+=("$pid")
        register_child_pid $pid "$adapter release"

        log::info "PODS" "Started parallel release of $adapter (PID: $pid, log: $log_file)"
    done

    # Register temp directory
    register_temp_resource "$temp_dir"

    # Wait for all parallel processes to complete with FAIL-FAST
    log::info "PODS" "Waiting for all adapters to complete (fail-fast enabled)..."
    log::info "PODS" "If any adapter fails, all others will be stopped immediately"

    local success_count=0
    local failure_count=0
    local failed_adapters=()
    local check_interval=5  # Check every 5 seconds
    local all_completed=false

    while [[ "$all_completed" == "false" ]]; do
        all_completed=true
        local has_failure=false
        local failed_adapter=""

        # Check each process
        for i in "${!pids[@]}"; do
            local pid="${pids[$i]}"
            local adapter="${adapters[$i]}"
            local result_file="${result_files[$i]}"

            # Skip if already processed
            if [[ "${pids[$i]}" == "DONE" ]]; then
                continue
            fi

            # Check if process is still running
            if kill -0 "$pid" 2>/dev/null; then
                # Process still running
                all_completed=false

                # Check if result file indicates failure
                if [[ -f "$result_file" ]]; then
                    local result_content=$(cat "$result_file")
                    if [[ "$result_content" == *"ERROR"* ]] || [[ "$result_content" == *"FAILED"* ]]; then
                        log::error "PODS" "FAIL-FAST: $adapter failed while still running"
                        log::error "PODS" "Result: $result_content"

                        # Show last 30 lines of log file for debugging
                        local log_file="${log_files[$i]}"
                        if [[ -f "$log_file" ]]; then
                            log::error "PODS" ""
                            log::error "PODS" "Last 30 lines of $adapter log ($log_file):"
                            tail -30 "$log_file" >&2
                            log::error "PODS" ""
                            log::error "PODS" "Full log available at: $log_file"
                        fi

                        has_failure=true
                        failed_adapter="$adapter"
                        failed_adapters+=("$adapter")
                        ((failure_count++)) || true
                        pids[$i]="DONE"
                        break
                    fi
                fi
            else
                # Process has exited, capture exit code and check result
                wait "$pid" 2>/dev/null
                local exit_code=$?

                # Check result file (primary indicator of success)
                if [[ -f "$result_file" ]] && grep -q "SUCCESS" "$result_file"; then
                    log::success "PODS" "$adapter released successfully"
                    ((success_count++)) || true
                    pids[$i]="DONE"
                else
                    # Detailed failure analysis
                    log::error "PODS" "$adapter release failed"

                    # Show result file content
                    if [[ -f "$result_file" ]]; then
                        local result_content=$(cat "$result_file")
                        if [[ -n "$result_content" ]]; then
                            log::error "PODS" "Result: $result_content"
                        else
                            log::error "PODS" "Result file is empty: $result_file"
                        fi
                    else
                        log::error "PODS" "Result file not found: $result_file"
                    fi

                    # Show exit code if available
                    if [[ -n "$exit_code" ]] && [[ "$exit_code" != "0" ]]; then
                        log::error "PODS" "Exit code: $exit_code"
                    fi

                    # Show last 30 lines of log file for debugging
                    local log_file="${log_files[$i]}"
                    if [[ -f "$log_file" ]]; then
                        log::error "PODS" ""
                        log::error "PODS" "Last 30 lines of $adapter log ($log_file):"
                        tail -30 "$log_file" >&2
                        log::error "PODS" ""
                        log::error "PODS" "Full log available at: $log_file"
                    else
                        log::error "PODS" "Log file not found: $log_file"
                    fi

                    has_failure=true
                    failed_adapter="$adapter"
                    failed_adapters+=("$adapter")
                    ((failure_count++)) || true
                    pids[$i]="DONE"
                    break
                fi
            fi
        done

        # If any failure detected, kill all other processes
        if [[ "$has_failure" == "true" ]]; then
            log::error "PODS" "FAIL-FAST TRIGGERED"
            log::error "PODS" "Failed adapter: $failed_adapter"
            log::error "PODS" "Stopping all running adapters immediately..."

            # Kill all remaining processes
            for i in "${!pids[@]}"; do
                local pid="${pids[$i]}"
                local adapter="${adapters[$i]}"

                if [[ "$pid" != "DONE" ]] && kill -0 "$pid" 2>/dev/null; then
                    log::warn "PODS" "Stopping $adapter (PID: $pid)..."
                    kill -TERM "$pid" 2>/dev/null || true
                    sleep 1
                    # Force kill if still running
                    if kill -0 "$pid" 2>/dev/null; then
                        kill -KILL "$pid" 2>/dev/null || true
                    fi
                    pids[$i]="DONE"
                fi
            done

            break
        fi

        # Sleep before next check
        if [[ "$all_completed" == "false" ]]; then
            sleep $check_interval
        fi
    done

    # Clean up temporary files (comprehensive)
    rm -rf "$temp_dir"

    log::debug "PODS" "[CLEANUP] Cleaned up adapter release temporary resources"

    # Report final results
    if [[ $failure_count -gt 0 ]]; then
        log::error "PODS" "Adapter releases failed"
        log::error "PODS" "Failed adapters: ${failed_adapters[*]}"
        log::error "PODS" "Successful adapters: $success_count"
        log::error "PODS" "Failed adapters: $failure_count"
        return 1
    fi

    log::success "PODS" "All adapters released successfully ($success_count/$success_count)"

    # Step 2.5: Check availability of dependencies for MSPCore
    if [[ "$DRY_RUN" != "true" ]]; then
        log_section "Step 2.5: Checking availability of dependencies for MSPCore"

        # Update local specs repo before CDN availability check.
        # Required: pod trunk push for MSPCore validates dependencies against the LOCAL specs repo
        # (not CDN), so the local repo must contain all adapter versions before MSPCore is published.
        # CDN check below confirms pods are on CDN, so pod repo update should succeed here.
        log::step "PODS" "Updating local CocoaPods specs repo (required for MSPCore pod trunk push lint)..."
        local repo_update_attempts=0
        local repo_update_max=3
        while [[ $repo_update_attempts -lt $repo_update_max ]]; do
            ((repo_update_attempts++)) || true
            if update_specs_repo; then
                log::success "PODS" "Local specs repo updated (attempt $repo_update_attempts)"
                break
            fi
            if [[ $repo_update_attempts -lt $repo_update_max ]]; then
                log::warn "PODS" "Specs repo update failed (attempt $repo_update_attempts/$repo_update_max), retrying in 30s..."
                sleep 30
            else
                log::error "PODS" "Specs repo update failed after $repo_update_max attempts — MSPCore pod trunk push will likely fail to resolve adapter dependencies"
                return 1
            fi
        done

        # Define required dependencies (always check, fail-fast)
        local required_deps=("MSPSharedLibraries" "MSPPrebidAdapter" "MSPGoogleAdsTypes")

        # Check required dependencies sequentially (fail-fast)
        for dep in "${required_deps[@]}"; do
            # Check if dependency is in PODS_MODULES
            if ! echo "$PODS_MODULES" | grep -q "$dep"; then
                log::info "PODS" "$dep not in PODS_MODULES, skipping availability check"
                continue
            fi

            log::info "PODS" "Checking $dep availability (required for MSPCore)..."
            if ! smart_wait_for_pod_availability "$dep" "$VERSION" "required by MSPCore or adapters"; then
                log::error "PODS" "$dep not available, cannot proceed with MSPCore release"
                return 1
            fi
            log::success "PODS" "$dep is available"
        done

        log::success "PODS" "All required dependencies available for MSPCore release"
    fi

    return 0
}

# ============================================================================
# Release MSPCore (Step 3)
# ============================================================================
# MSPCore is the main framework that integrates all components.
# It should be released last after all adapters are available.
#
# Returns:
#   0 if MSPCore released successfully (or already published)
#   1 if release failed
# ============================================================================
release_msp_core() {
    log_section "Step 3: Releasing MSPCore (main framework)"

    # ========================================================================
    # Idempotency Check: Skip if already published (Resume-safe)
    # ========================================================================
    if [[ "$DRY_RUN" != "true" ]]; then
        if check_pod_availability "MSPCore" "$VERSION"; then
            log::info "PODS" "MSPCore $VERSION is already published to CocoaPods"

            # Enhanced Check: Verify GitHub Release zip matches local zip
            if is_binary_distribution "MSPCore"; then
                if ! verify_and_fix_github_release_zip "MSPCore" "$VERSION"; then
                    log::error "PODS" "Failed to verify/fix GitHub Release zip for MSPCore"
                    return 1
                fi
            fi

            # Ensure all version files are committed (handles interrupted commits)
            if ! ensure_version_files_committed "$VERSION"; then
                log::error "PODS" "Failed to ensure version files are committed"
                # Don't fail the release - pod is already published
                log::warn "PODS" "Continuing despite version commit issue (pod already published)"
            fi

            log::success "PODS" "MSPCore $VERSION already available and verified"
            return 0
        fi
    fi

    # Update MSPCore version in Config.plist and commit immediately,
    # BEFORE creating the zip so the binary contains the correct SDKVersion.
    update_and_commit_plist_version "mspcore" "$VERSION"

    # Rebuild MSPCore.xcframework with updated Config.plist so the binary
    # contains the correct SDKVersion (not the pre-release value)
    log::step "PODS" "Rebuilding MSPCore.xcframework with updated SDKVersion..."
    local build_core_script="$ROOT_DIR/Scripts/xcframeworks/build-core.sh"
    if [[ -x "$build_core_script" ]]; then
        if ! bash "$build_core_script"; then
            log::warn "PODS" "MSPCore XCFramework rebuild failed, using existing binary"
        fi
    else
        log::warn "PODS" "build-core.sh not found, using existing MSPCore binary"
    fi

    # Ensure zip file exists for binary distribution pods (Resume-safe)
    if is_binary_distribution "MSPCore"; then
        log::info "PODS" "Verifying zip file exists for binary distribution pod..."

        if ! ensure_zip_file_exists_for_pod "MSPCore" "$VERSION"; then
            log::error "PODS" "Failed to ensure zip file exists for MSPCore"

            if [[ "${DRY_RUN:-true}" == "false" ]]; then
                log::error "PODS" "[FAIL-FAST] Cannot proceed without zip file. Aborting."
                exit 1
            fi

            return 1
        fi

        log::success "PODS" "Zip file verified/recreated for MSPCore"
    fi

    # Update podspec (now guaranteed to succeed if binary distribution)
    if ! update_podspec_for_release "MSPCore" "$VERSION"; then
        # FAIL-FAST: Immediately abort if podspec generation fails (release tier only)
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            log::error "PODS" "[FAIL-FAST] Podspec generation failed for MSPCore. Aborting release."
            msp_state_mark_step_failed "pods_publish" "Podspec generation failed for MSPCore" "1"
            exit 1
        fi
        return 1
    fi

    # FAIL-FAST: Verify generated podspec exists (release tier only)
    local podspec_path="$ROOT_DIR/Build/ReleasePodspecs/MSPCore.podspec"
    if [[ "${DRY_RUN:-true}" == "false" ]] && [[ ! -f "$podspec_path" ]]; then
        log::error "PODS" "[FAIL-FAST] Generated podspec not found: $podspec_path. Aborting release."
        msp_state_mark_step_failed "pods_publish" "Generated podspec not found: $podspec_path" "1"
        exit 1
    fi

    # Update dependencies
    update_adapter_podspec_dependencies "MSPCore" "$VERSION"

    # Create GitHub release (with resume support)
    local github_release_status="unknown"
    if command -v msp_state_get_pod_github_release_created &>/dev/null; then
        github_release_status=$(msp_state_get_pod_github_release_created "MSPCore")
    fi

    if [[ "$github_release_status" == "true" ]]; then
        log::info "PODS" "GitHub release for MSPCore already created (state: true), skipping"
    else
        log::info "PODS" "Creating/retrying GitHub release for MSPCore (state: $github_release_status)"
        create_github_release_for_pod "MSPCore" "$VERSION"
    fi

    # Publish to CocoaPods
    if ! publish_pod_to_cocoapods "MSPCore" "$VERSION"; then
        log::error "PODS" "Failed to publish MSPCore to CocoaPods"
        return 1
    fi

    # Safety net: catch any version files that slipped through uncommitted
    # (each file should already be committed at its modification site)
    if ! ensure_version_files_committed "$VERSION"; then
        log::warn "PODS" "Version commit failed (non-fatal — pod already published)"
    fi

    # Wait for availability (skip in dry-run mode)
    if [[ "$DRY_RUN" != "true" ]]; then
        smart_wait_for_pod_availability "MSPCore" "$VERSION" "final integration module"
    fi

    log::success "PODS" "MSPCore released successfully"

    # Flush CDN metrics to state file (once per release session, at end of orchestration)
    if command -v cocoapods_cdn_metrics_flush_to_state >/dev/null 2>&1; then
        cocoapods_cdn_metrics_flush_to_state || true
    fi
}

# ============================================================================
# Export Functions
# ============================================================================

export -f release_msp_ioscore 2>/dev/null || true
export -f release_msp_shared_libraries 2>/dev/null || true
export -f release_msp_googleadstypes 2>/dev/null || true
export -f release_single_adapter 2>/dev/null || true
export -f release_adapters 2>/dev/null || true
export -f release_msp_core 2>/dev/null || true
