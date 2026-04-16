#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch K, shared) ---
# shellcheck source=/dev/null
if command -v git >/dev/null 2>&1; then
  MSP_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$MSP_REPO_ROOT" ] && [ -f "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh" ]; then
    # shellcheck source=/dev/null
    . "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh"
    msp_enforce_main_repo_or_exit
  fi
fi
# --- End MSP Worktree Safety Guard (Patch K, shared) ---

[[ -n "${_MSP_COCOAPODS_SOURCED:-}" ]] && return 0
readonly _MSP_COCOAPODS_SOURCED=1

# CocoaPods operations for MSP iOS SDK build system
# This module provides comprehensive CocoaPods management with dependency handling and validation

# Source dependencies (common.sh provides logger.sh for unified logging)
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/validation.sh"

if [[ -f "$(dirname "${BASH_SOURCE[0]}")/process_utils.sh" ]]; then
    # shellcheck source=Scripts/lib/process_utils.sh
    source "$(dirname "${BASH_SOURCE[0]}")/process_utils.sh" 2>/dev/null || true
fi

# R040d: Source config loader extension for CocoaPods settings
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/config_loader_ext.sh" ]]; then
    # shellcheck source=Scripts/lib/config_loader_ext.sh
    source "$(dirname "${BASH_SOURCE[0]}")/config_loader_ext.sh" 2>/dev/null || true
    load_cocoapods_config 2>/dev/null || true
fi

# Note: PODFILE is not readonly to allow override in release scripts
PODFILE="${PODFILE:-Podfile}"   # allow override, no readonly
readonly PODFILE_LOCK="Podfile.lock"
readonly PODS_DIR="Pods"
readonly PODSPEC_EXTENSION=".podspec"

validate_cocoapods_environment() {
    log::step "PODS" "Validating CocoaPods environment..."

    if ! check_command_exists "pod" "CocoaPods"; then
        log::error "PODS" "CocoaPods not installed. Run: sudo gem install cocoapods"
        return $EXIT_COMMAND_NOT_FOUND
    fi

    local pod_version
    pod_version=$(get_command_version "pod")
    if [[ "$pod_version" == "unknown" ]]; then
        log::warn "PODS" "Could not determine CocoaPods version"
    else
        log::debug "PODS" "CocoaPods version: $pod_version"
    fi

    if ! check_path_exists "$PODFILE" "Podfile" "file"; then
        log::error "PODS" "Podfile not found. This doesn't appear to be a CocoaPods project."
        return $EXIT_VALIDATION_ERROR
    fi

    log::success "PODS" "CocoaPods environment validated"
    return $EXIT_SUCCESS
}

validate_podfile() {
    local podfile="${1:-$PODFILE}"

    if ! check_path_exists "$podfile" "Podfile" "file"; then
        return $EXIT_VALIDATION_ERROR
    fi

    log::step "PODS" "Validating Podfile syntax..."

    if bundle exec pod spec lint --quick --allow-warnings "$podfile" >/dev/null 2>&1; then
        log::success "PODS" "Podfile syntax is valid"
        return $EXIT_SUCCESS
    else
        # Pod spec lint might not work on Podfile, so try a different approach
        if ruby -c "$podfile" >/dev/null 2>&1; then
            log::success "PODS" "Podfile syntax is valid"
            return $EXIT_SUCCESS
        else
            log::error "PODS" "Podfile has syntax errors"
            return $EXIT_VALIDATION_ERROR
        fi
    fi
}

get_podfile_platforms() {
    local podfile="${1:-$PODFILE}"
    
    if [[ ! -f "$podfile" ]]; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    grep -o "platform :ios, '[0-9.]*'" "$podfile" | head -n1 | grep -o "[0-9.]*"
}

install_pods() {
    local repo_update=false
    local clean_install=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            "--repo-update") repo_update=true ;;
            "--clean") clean_install=true ;;
        esac
        shift
    done

    if ! validate_cocoapods_environment; then
        return $EXIT_VALIDATION_ERROR
    fi

    if [[ "$clean_install" == "true" ]]; then
        clean_pods
    fi

    log::step "PODS" "Installing CocoaPods dependencies..."

    local install_cmd
    if [[ -f "Gemfile" ]] && command -v bundle >/dev/null 2>&1; then
        install_cmd="bundle exec pod install"
    else
        install_cmd="pod install"
    fi

    # CI environments need repo-update to ensure latest podspec indices
    if [[ "$repo_update" == "true" ]] || [[ "$BUILD_ENVIRONMENT" == "github-actions" ]]; then
        install_cmd="$install_cmd --repo-update"
        log::debug "PODS" "Including repository update"
    fi

    # Verbose output helps debug CI failures in build logs
    case "$BUILD_ENVIRONMENT" in
        "github-actions"|"ci")
            install_cmd="$install_cmd --verbose"
            ;;
    esac

    local start_time
    start_time=$(date +%s)

    if eval "$install_cmd"; then
        local duration
        duration=$(($(date +%s) - start_time))
        log::success "PODS" "CocoaPods installation completed in $(format_duration $duration)"

        verify_pods_installation
        return $EXIT_SUCCESS
    else
        log::warn "PODS" "CocoaPods installation failed, attempting troubleshooting..."

        if troubleshoot_cocoapods_network; then
            log::info "PODS" "Network troubleshooting successful, retrying installation..."

            if eval "$install_cmd"; then
                local duration
                duration=$(($(date +%s) - start_time))
                log::success "PODS" "CocoaPods installation completed after troubleshooting in $(format_duration $duration)"

                verify_pods_installation
                return $EXIT_SUCCESS
            fi
        fi

        log::error "PODS" "CocoaPods installation failed even after troubleshooting"
        return $EXIT_BUILD_ERROR
    fi
}

update_pods() {
    local options=("$@")

    if ! validate_cocoapods_environment; then
        return $EXIT_VALIDATION_ERROR
    fi

    log::step "PODS" "Updating CocoaPods dependencies..."

    local update_cmd="bundle exec pod update"

    for option in "${options[@]}"; do
        case "$option" in
            "--verbose") update_cmd="$update_cmd --verbose" ;;
            "--no-repo-update") update_cmd="$update_cmd --no-repo-update" ;;
        esac
    done

    if eval "$update_cmd"; then
        log::success "PODS" "CocoaPods update completed"
        verify_pods_installation
        return $EXIT_SUCCESS
    else
        log::error "PODS" "CocoaPods update failed"
        return $EXIT_BUILD_ERROR
    fi
}

verify_pods_installation() {
    log::step "PODS" "Verifying CocoaPods installation..."

    if ! check_path_exists "$PODFILE_LOCK" "Podfile.lock" "file"; then
        log::warn "PODS" "Podfile.lock not found"
        return $EXIT_VALIDATION_ERROR
    fi

    if ! check_path_exists "$PODS_DIR" "Pods directory" "directory"; then
        log::warn "PODS" "Pods directory not found"
        return $EXIT_VALIDATION_ERROR
    fi
    if command -v bundle >/dev/null 2>&1; then
        if bundle check >/dev/null 2>&1; then
            log::debug "PODS" "Bundle dependencies are up to date"
        else
            log::warn "PODS" "Bundle dependencies need updating"
        fi
    fi

    local pods_count=0
    if [[ -f "$PODFILE_LOCK" ]]; then
        pods_count=$(grep -c "^  - " "$PODFILE_LOCK" 2>/dev/null || echo "0")
    fi

    log::success "PODS" "CocoaPods installation verified ($pods_count dependencies)"
    return $EXIT_SUCCESS
}

clean_pods() {
    log::step "PODS" "Cleaning CocoaPods installation..."

    if [[ -d "$PODS_DIR" ]]; then
        safe_remove "$PODS_DIR"
        log::debug "PODS" "Removed Pods directory"
    fi

    if [[ -f "$PODFILE_LOCK" ]]; then
        safe_remove "$PODFILE_LOCK"
        log::debug "PODS" "Removed Podfile.lock"
    fi

    # Only remove workspaces that CocoaPods generated (contain Pods/ reference)
    local workspace_files=(*.xcworkspace)
    for workspace in "${workspace_files[@]}"; do
        if [[ -f "$workspace" ]] && [[ "$workspace" != "*.xcworkspace" ]]; then
            # Check if workspace is likely generated by CocoaPods
            if grep -q "Pods/" "$workspace/contents.xcworkspacedata" 2>/dev/null; then
                log::debug "PODS" "Workspace $workspace appears to be CocoaPods-managed, keeping it"
            fi
        fi
    done

    log::success "PODS" "CocoaPods cleanup completed"
}

deintegrate_pods() {
    log::step "PODS" "Deintegrating CocoaPods..."

    if command -v pod >/dev/null 2>&1; then
        if bundle exec pod deintegrate; then
            log::success "PODS" "CocoaPods deintegration completed"
        else
            log::warn "PODS" "CocoaPods deintegration had issues, continuing with manual cleanup"
            clean_pods
        fi
    else
        log::warn "PODS" "CocoaPods not available, performing manual cleanup"
        clean_pods
    fi
}

find_podspecs() {
    local directory="${1:-.}"
    find "$directory" -name "*$PODSPEC_EXTENSION" -type f
}

validate_podspec() {
    local podspec="$1"
    local options=("${@:2}")

    if ! check_path_exists "$podspec" "Podspec" "file"; then
        return $EXIT_VALIDATION_ERROR
    fi

    log::step "PODS" "Validating podspec: $(basename "$podspec")..."

    local lint_cmd="bundle exec pod spec lint \"$podspec\""

    lint_cmd="$lint_cmd --allow-warnings --skip-import-validation"

    for option in "${options[@]}"; do
        lint_cmd="$lint_cmd $option"
    done

    # R040d: Use configurable timeout from cocoapods-config.yaml
    local lint_timeout="${PODS_SPEC_LINT_TIMEOUT:-1800}"
    log::info "PODS" "Running pod spec lint (timeout: $((lint_timeout/60)) minutes)..."

    # Rationale: Observed 1-5 min, extreme cases up to 20 min (complex deps), 30 min provides safety margin
    if run_with_timeout "$lint_timeout" eval "$lint_cmd"; then
        log::success "PODS" "Podspec validation passed: $(basename "$podspec")"
        return $EXIT_SUCCESS
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log::error "PODS" "❌ TIMEOUT: pod spec lint exceeded 30 minutes"
            log::error "PODS" "This usually indicates:"
            log::error "PODS" "  1. Dependency resolution hanging"
            log::error "PODS" "  2. Network issues downloading dependencies"
            log::error "PODS" "  3. Build phase hanging"
            log::error "PODS" ""
            log::error "PODS" "Troubleshooting:"
            log::error "PODS" "  1. Check dependency availability: pod search <dep_name>"
            log::error "PODS" "  2. Test locally: $lint_cmd"
            log::error "PODS" "  3. Check network: bundle exec pod repo update"
            return $EXIT_VALIDATION_ERROR
        else
            log::error "PODS" "Podspec validation failed: $(basename "$podspec")"
            return $EXIT_VALIDATION_ERROR
        fi
    fi
}

validate_all_podspecs() {
    local directory="${1:-.}"
    local failed_specs=()
    local total_specs=0

    log::step "PODS" "Validating all podspecs in $directory..."

    local podspecs
    mapfile -t podspecs < <(find_podspecs "$directory")

    if [[ ${#podspecs[@]} -eq 0 ]]; then
        log::warn "PODS" "No podspecs found in $directory"
        return $EXIT_SUCCESS
    fi

    for podspec in "${podspecs[@]}"; do
        ((total_specs++)) || true

        if ! validate_podspec "$podspec" >/dev/null 2>&1; then
            failed_specs+=("$(basename "$podspec")")
        fi
    done

    if [[ ${#failed_specs[@]} -eq 0 ]]; then
        log::success "PODS" "All $total_specs podspecs validated successfully"
        return $EXIT_SUCCESS
    else
        log::error "PODS" "${#failed_specs[@]} of $total_specs podspecs failed validation:"
        for spec in "${failed_specs[@]}"; do
            log::error "PODS" "  - $spec"
        done
        return $EXIT_VALIDATION_ERROR
    fi
}

publish_podspec() {
    local podspec="$1"
    local options=("${@:2}")

    if ! check_path_exists "$podspec" "Podspec" "file"; then
        return $EXIT_VALIDATION_ERROR
    fi

    if ! validate_podspec "$podspec"; then
        log::error "PODS" "Cannot publish invalid podspec"
        return $EXIT_VALIDATION_ERROR
    fi

    log::step "PODS" "Publishing podspec: $(basename "$podspec")..."

    local push_cmd="bundle exec pod trunk push \"$podspec\""

    push_cmd="$push_cmd --allow-warnings"

    for option in "${options[@]}"; do
        push_cmd="$push_cmd $option"
    done

    if eval "$push_cmd"; then
        log::success "PODS" "Podspec published successfully: $(basename "$podspec")"
        return $EXIT_SUCCESS
    else
        log::error "PODS" "Podspec publishing failed: $(basename "$podspec")"
        return $EXIT_BUILD_ERROR
    fi
}

# ============================================================================
# Stale Specs Repo Cleanup
# ============================================================================
# Problem: Temporary CocoaPods repos (e.g., tmp-msp_local_specs_*) can become
# stale when their source directory is deleted (e.g., after system reboot).
# This causes every `pod repo update` to fail.
#
# Solution: Proactively clean up orphaned repos at the start of any specs
# operation. A repo is considered orphaned if:
# 1. Its name starts with "tmp-" or "temp-"
# 2. It references a non-existent local path as its origin
# ============================================================================
cleanup_stale_specs_repos() {
    local repos_dir="$HOME/.cocoapods/repos"
    local cleaned_count=0

    if [[ ! -d "$repos_dir" ]]; then
        return 0
    fi

    log::debug "PODS" "Checking for stale CocoaPods specs repos..."

    # Find all directories in repos that might be stale
    for repo_dir in "$repos_dir"/tmp-* "$repos_dir"/temp-*; do
        if [[ -d "$repo_dir" ]]; then
            local repo_name
            repo_name=$(basename "$repo_dir")

            # Check if the repo's remote origin exists
            local remote_url
            remote_url=$(git -C "$repo_dir" config --get remote.origin.url 2>/dev/null || echo "")

            if [[ -n "$remote_url" ]]; then
                # If remote URL is a local path, check if it exists
                if [[ "$remote_url" == /* ]] || [[ "$remote_url" == file://* ]]; then
                    local local_path="${remote_url#file://}"
                    if [[ ! -d "$local_path" ]]; then
                        log::warn "PODS" "Removing stale specs repo '$repo_name' (origin '$local_path' no longer exists)"
                        rm -rf "$repo_dir"
                        ((cleaned_count++)) || true
                    fi
                fi
            else
                # No remote URL configured - likely corrupted
                log::warn "PODS" "Removing corrupted specs repo '$repo_name' (no remote origin)"
                rm -rf "$repo_dir"
                ((cleaned_count++)) || true
            fi
        fi
    done

    if [[ $cleaned_count -gt 0 ]]; then
        log::success "PODS" "Cleaned up $cleaned_count stale specs repo(s)"
    else
        log::debug "PODS" "No stale specs repos found"
    fi

    return 0
}

export -f cleanup_stale_specs_repos

update_specs_repo() {
    # ═══════════════════════════════════════════════════════════════════════════
    # Specs Repo Update Caching (Fix for infinite loop issue)
    # ═══════════════════════════════════════════════════════════════════════════
    # Problem: update_specs_repo was called repeatedly (every 10s) during pod
    # availability checks, each taking 50-60 seconds. This caused ~7 min delay
    # for just 7 update cycles, leading to test timeouts.
    #
    # Solution: Cache the update operation. If updated recently (within 5 min),
    # skip redundant updates. This is safe because:
    # 1. Pod trunk push takes 1-3 min to propagate to CDN
    # 2. Checking every 30-60s is sufficient
    # 3. Multiple checks within 5 min window will see the same CDN state
    # ═══════════════════════════════════════════════════════════════════════════

    # First, clean up any stale repos that might cause update failures
    cleanup_stale_specs_repos

    local cache_file="/tmp/msp-cocoapods-specs-repo-last-update"
    local cache_failure_file="/tmp/msp-cocoapods-specs-repo-last-failure"
    local cache_lock_file="${cache_file}.lock"
    local cache_lock_dir="${cache_file}.lockdir"
    # R040d: Use configurable values from cocoapods-config.yaml
    local cache_ttl="${PODS_CACHE_TTL:-300}"                   # 5 minutes for successful updates
    local failure_cache_ttl="${PODS_FAILURE_CACHE_TTL:-60}"    # 60 seconds for failed updates (prevents rapid retries)
    local current_time
    current_time=$(date +%s)
    local max_attempts="${PODS_MAX_UPDATE_ATTEMPTS:-3}"
    local attempt=1

    # Use file lock to prevent concurrent updates
    (
        local lock_acquired=false
        # Check if flock is available (Linux has it, macOS may need coreutils)
        if ! command -v flock >/dev/null 2>&1; then
            log::debug "PODS" "flock not available (macOS), using mkdir lock for specs update"
            # Best-effort lock using mkdir (portable)
            local lock_wait=0
            local lock_timeout="${PODS_LOCK_TIMEOUT:-60}"
            while ! mkdir "$cache_lock_dir" 2>/dev/null; do
                sleep 1
                lock_wait=$((lock_wait + 1))
                if [[ $lock_wait -ge $lock_timeout ]]; then
                    log::warn "PODS" "Timed out waiting for specs update lock; proceeding without lock"
                    break
                fi
            done
            if [[ -d "$cache_lock_dir" ]]; then
                lock_acquired=true
            fi
        else
            # Use flock for file locking
            # Try to acquire lock (non-blocking)
            if ! flock -n 9; then
                log::info "PODS" "Another process is updating specs repo, waiting for lock..."
                # Wait for lock (blocking)
                flock 9
                log::info "PODS" "Lock acquired, checking cache..."
            fi
        fi

        if [[ "$lock_acquired" == "true" ]]; then
            trap 'rmdir "'"$cache_lock_dir"'" 2>/dev/null || true' EXIT
        fi

        # Check success cache (now protected by lock)
        if [[ -f "$cache_file" ]]; then
            local last_update_time
            last_update_time=$(cat "$cache_file" 2>/dev/null || echo 0)
            local time_since_update=$((current_time - last_update_time))

            if [[ $time_since_update -lt $cache_ttl ]]; then
                local remaining=$((cache_ttl - time_since_update))
                log::info "PODS" "Specs repository was updated ${time_since_update}s ago (< ${cache_ttl}s TTL)"
                log::info "PODS" "Skipping redundant update (will refresh in ${remaining}s if needed)"
                exit 0
            else
                log::debug "PODS" "Cache expired (${time_since_update}s > ${cache_ttl}s TTL), updating now..."
            fi
        fi

        # Check failure cache (prevent rapid retries after failures)
        if [[ -f "$cache_failure_file" ]]; then
            local last_failure_time
            last_failure_time=$(cat "$cache_failure_file" 2>/dev/null || echo 0)
            local time_since_failure=$((current_time - last_failure_time))

            if [[ $time_since_failure -lt $failure_cache_ttl ]]; then
                local remaining=$((failure_cache_ttl - time_since_failure))
                log::warn "PODS" "Specs repo update failed ${time_since_failure}s ago, cooling down..."
                log::info "PODS" "Skipping retry (will retry in ${remaining}s)"
                exit 1
            fi
        fi

        # Perform update (only one process at a time)
        log::step "PODS" "Updating CocoaPods specs repository..."

        # R040d: Use configurable timeout and retry delay from cocoapods-config.yaml
        local repo_update_timeout="${PODS_REPO_UPDATE_TIMEOUT:-900}"
        local retry_delay="${PODS_RETRY_DELAY:-10}"

        # Ensure bundler gems are intact before any bundle exec call.
        # In CI, BUNDLE_PATH can become stale after workspace ops (SPM cleanup, git ops).
        if ! bundle check >/dev/null 2>&1; then
            log::warn "PODS" "Bundler gems missing — running bundle install before pod repo update..."
            bundle install --quiet 2>/dev/null || true
        fi

        while [[ $attempt -le $max_attempts ]]; do
            log::debug "PODS" "Attempt $attempt/$max_attempts: Updating CocoaPods specs repository..."

            # Rationale: Observed 1-4 min, extreme cases up to 10 min, 15 min provides safety margin
            if run_with_timeout "$repo_update_timeout" bundle exec pod repo update; then
                # Update success cache timestamp
                echo "$current_time" > "$cache_file"
                # Clear failure cache on success
                rm -f "$cache_failure_file"
                log::success "PODS" "Specs repository updated (cache timestamp: $current_time)"
                exit 0
            else
                local exit_code=$?
                if [[ $exit_code -eq 124 ]]; then
                    log::error "PODS" "pod repo update TIMED OUT after $((repo_update_timeout/60)) minutes"
                else
                    log::error "PODS" "pod repo update failed with exit code $exit_code"
                fi

                if [[ $attempt -lt $max_attempts ]]; then
                    log::info "PODS" "Retrying in ${retry_delay} seconds..."
                    sleep "$retry_delay"
                fi
            fi

            ((attempt++)) || true
        done

        # Cache the failure to prevent rapid retries
        echo "$current_time" > "$cache_failure_file"
        log::error "PODS" "Failed to update specs repository after $max_attempts attempts"
        log::info "PODS" "Failure cached for ${failure_cache_ttl}s to prevent rapid retries"
        exit 1

    ) 9>"$cache_lock_file"

    local result=$?

    # Clean up lock file if it exists and is old (older than 1 hour)
    if [[ -e "$cache_lock_file" ]]; then
        local lock_age=$((current_time - $(stat -f %m "$cache_lock_file" 2>/dev/null || stat -c %Y "$cache_lock_file" 2>/dev/null || echo $current_time)))
        if [[ $lock_age -gt 3600 ]]; then
            log::warn "PODS" "Removing stale lock file (age: ${lock_age}s)"
            rm -f "$cache_lock_file"
        fi
    fi
    if [[ -d "$cache_lock_dir" ]]; then
        local lock_dir_age=$((current_time - $(stat -f %m "$cache_lock_dir" 2>/dev/null || stat -c %Y "$cache_lock_dir" 2>/dev/null || echo $current_time)))
        if [[ $lock_dir_age -gt 3600 ]]; then
            log::warn "PODS" "Removing stale lock dir (age: ${lock_dir_age}s)"
            rmdir "$cache_lock_dir" 2>/dev/null || true
        fi
    fi

    return $result
}

# Clear specs repo update cache (for testing/debugging)
clear_specs_repo_cache() {
    local cache_file="/tmp/msp-cocoapods-specs-repo-last-update"
    local cache_failure_file="/tmp/msp-cocoapods-specs-repo-last-failure"
    local cleared=false

    if [[ -f "$cache_file" ]]; then
        rm -f "$cache_file"
        cleared=true
    fi
    if [[ -f "$cache_failure_file" ]]; then
        rm -f "$cache_failure_file"
        cleared=true
    fi

    if [[ "$cleared" == "true" ]]; then
        log::info "PODS" "Cleared specs repository update cache (success and failure)"
    else
        log::debug "PODS" "No cache file to clear"
    fi
}

export -f clear_specs_repo_cache

check_pod_availability() {
    local pod_name="$1"
    local version="${2:-}"

    if [[ -z "$version" ]]; then
        # No version specified — we can only check pod existence, not version availability.
        # CDN URL requires a specific version. Fall back to a simple CDN root check.
        log::step "PODS" "Checking availability of $pod_name (no version specified, CDN shard check)..."
        local shard
        shard=$(cocoapods_cdn_compute_shard "$pod_name" 2>/dev/null) || {
            log::warn "PODS" "Could not compute CDN shard for $pod_name"
            return $EXIT_VALIDATION_ERROR
        }
        log::info "PODS" "$pod_name CDN shard: $shard"
        return $EXIT_SUCCESS
    fi

    log::step "PODS" "Checking CDN availability of $pod_name version $version..."

    # Source the CDN module if not already loaded
    if ! command -v cocoapods_cdn_check_pod_available >/dev/null 2>&1; then
        local cdn_module
        cdn_module="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/shared/cocoapods_cdn.sh"
        if [[ -f "$cdn_module" ]]; then
            # shellcheck source=/dev/null
            source "$cdn_module"
        else
            log::error "PODS" "cocoapods_cdn.sh module not found at: $cdn_module"
            return $EXIT_VALIDATION_ERROR
        fi
    fi

    local cdn_exit=0
    cocoapods_cdn_check_pod_available "$pod_name" "$version" || cdn_exit=$?

    case $cdn_exit in
        0)
            log::success "PODS" "$pod_name $version is available on CocoaPods CDN"
            return $EXIT_SUCCESS
            ;;
        2)
            log::warn "PODS" "$pod_name $version not yet available on CocoaPods CDN (HTTP 404)"
            return $EXIT_NOT_FOUND_YET
            ;;
        3)
            log::error "PODS" "$pod_name $version: CocoaPods CDN unreachable after retries"
            return $EXIT_NOT_FOUND_YET
            ;;
        *)
            log::error "PODS" "$pod_name $version: CDN check returned unexpected exit code $cdn_exit"
            return $EXIT_VALIDATION_ERROR
            ;;
    esac
}

troubleshoot_cocoapods_network() {
    log::step "PODS" "Troubleshooting CocoaPods network issues..."

    # R040d: Use configurable values from cocoapods-config.yaml
    local connect_timeout="${PODS_CONNECT_TIMEOUT:-10}"
    local cdn_url="${PODS_CDN_URL:-https://cdn.cocoapods.org/}"
    local repo_update_timeout="${PODS_REPO_UPDATE_TIMEOUT:-900}"

    if curl -s --connect-timeout "$connect_timeout" "$cdn_url" >/dev/null 2>&1; then
        log::success "PODS" "CocoaPods CDN is reachable"
        return $EXIT_SUCCESS
    fi

    log::warn "PODS" "CocoaPods CDN is not reachable, trying multiple strategies..."

    # Strategy 1: Clean cache and retry
    log::info "PODS" "Strategy 1: Cleaning cache and retrying..."
        if bundle exec pod cache clean --all >/dev/null 2>&1; then
        log::info "PODS" "Cache cleaned successfully"
        if run_with_timeout "$repo_update_timeout" bundle exec pod repo update >/dev/null 2>&1; then
            log::success "PODS" "Repository updated after cache clean"
            return $EXIT_SUCCESS
        fi
    fi

    # Strategy 2: Try alternative sources
    log::info "PODS" "Strategy 2: Trying alternative CocoaPods sources..."
    if try_alternative_cocoapods_sources; then
        log::success "PODS" "Alternative sources worked"
        return $EXIT_SUCCESS
    fi

    # Strategy 3: Use local specs repo
    log::info "PODS" "Strategy 3: Using local specs repository..."
    if use_local_specs_repo; then
        log::success "PODS" "Local specs repository worked"
        return $EXIT_SUCCESS
    fi

    # Strategy 4: Skip problematic dependencies temporarily
    log::info "PODS" "Strategy 4: Attempting build with dependency fallbacks..."
    if try_dependency_fallbacks; then
        log::success "PODS" "Dependency fallbacks enabled"
        return $EXIT_SUCCESS
    fi

    # All strategies failed
    log::error "PODS" "All network troubleshooting strategies failed"
    log::info "PODS" "Possible solutions:"
    log::info "PODS" "1. Check your internet connection"
    log::info "PODS" "2. Try using a VPN if behind a corporate firewall"
    log::info "PODS" "3. Wait a few minutes and try again"
    log::info "PODS" "4. Check CocoaPods status at https://status.cocoapods.org/"
    log::info "PODS" "5. Consider using local dependency copies"
    return $EXIT_BUILD_ERROR
}

try_alternative_cocoapods_sources() {
    log::debug "PODS" "Trying alternative CocoaPods sources..."

    # R040d: Use configurable URLs from cocoapods-config.yaml
    local specs_repo_url="${PODS_SPECS_REPO_URL:-https://github.com/CocoaPods/Specs.git}"
    local cdn_url="${PODS_CDN_URL:-https://cdn.cocoapods.org/}"
    local repo_update_timeout="${PODS_REPO_UPDATE_TIMEOUT:-900}"

    local sources=(
        "$specs_repo_url"
        "$cdn_url"
    )

    # Use unique repo name to avoid conflicts
    local temp_repo_name="temp-msp-fallback-$$"

    # Ensure cleanup on exit (trap within function scope)
    local cleanup_needed=false

    for source in "${sources[@]}"; do
        log::debug "PODS" "Trying source: $source"
        if bundle exec pod repo add "$temp_repo_name" "$source" >/dev/null 2>&1; then
            cleanup_needed=true
            log::info "PODS" "Successfully added source: $source"
            # Try to update with this source
            if run_with_timeout "$repo_update_timeout" bundle exec pod repo update "$temp_repo_name" >/dev/null 2>&1; then
                log::success "PODS" "Source $source is working"
                # Clean up the temp repo - we don't need to keep it
                bundle exec pod repo remove "$temp_repo_name" >/dev/null 2>&1 || true
                return $EXIT_SUCCESS
            fi
            # Clean up if it didn't work
            bundle exec pod repo remove "$temp_repo_name" >/dev/null 2>&1 || true
            cleanup_needed=false
        fi
    done

    # Final cleanup just in case
    if [[ "$cleanup_needed" == "true" ]]; then
        bundle exec pod repo remove "$temp_repo_name" >/dev/null 2>&1 || true
    fi

    return $EXIT_BUILD_ERROR
}

use_local_specs_repo() {
    log::debug "PODS" "Attempting to use local specs repository..."

    local specs_repo_path="$HOME/.cocoapods/repos/trunk"
    if [[ -d "$specs_repo_path" ]]; then
        log::info "PODS" "Found local specs repository at $specs_repo_path"

        if bundle exec pod install --no-repo-update >/dev/null 2>&1; then
            log::success "PODS" "Successfully used local specs repository"
            return $EXIT_SUCCESS
        fi
    fi

    return $EXIT_BUILD_ERROR
}

try_dependency_fallbacks() {
    log::debug "PODS" "Setting up dependency fallbacks..."

    local temp_podfile="Podfile.fallback"
    local original_podfile="Podfile"

    # R040d: Use configurable URLs from cocoapods-config.yaml
    local specs_repo_url="${PODS_SPECS_REPO_URL:-https://github.com/CocoaPods/Specs.git}"
    local cdn_url="${PODS_CDN_URL:-https://cdn.cocoapods.org/}"

    if [[ -f "$original_podfile" ]]; then
        cp "$original_podfile" "${original_podfile}.backup"

        cat > "$temp_podfile" << EOF
# Fallback Podfile with alternative sources and dependency handling
source '$specs_repo_url'
source '$cdn_url'

# Use the original Podfile content but with fallback sources
EOF

        grep -v "^source " "$original_podfile" >> "$temp_podfile"

        if bundle exec pod install --podfile="$temp_podfile" >/dev/null 2>&1; then
            log::success "PODS" "Fallback Podfile worked"
            mv "$temp_podfile" "$original_podfile"
            rm -f "${original_podfile}.backup"
            return $EXIT_SUCCESS
        else
            # Try with problematic dependencies commented out
            log::info "PODS" "Trying with problematic dependencies temporarily disabled..."
            if try_without_problematic_deps; then
                log::success "PODS" "Build succeeded without problematic dependencies"
                return $EXIT_SUCCESS
            fi

            # Restore original
            mv "${original_podfile}.backup" "$original_podfile"
            rm -f "$temp_podfile"
        fi
    fi

    return $EXIT_BUILD_ERROR
}

try_without_problematic_deps() {
    log::debug "PODS" "Attempting build without problematic dependencies..."

    local temp_podfile="Podfile.no-problematic-deps"
    local original_podfile="Podfile"

    sed -e 's/spec\.dependency '\''OpenWrapSDK'\''/#spec.dependency '\''OpenWrapSDK'\''/g' \
        -e 's/spec\.dependency '\''IronSourceSDK'\''/#spec.dependency '\''IronSourceSDK'\''/g' \
        "$original_podfile" > "$temp_podfile"

    if bundle exec pod install --podfile="$temp_podfile" >/dev/null 2>&1; then
        log::success "PODS" "Build succeeded without problematic dependencies"
        mv "$temp_podfile" "$original_podfile"
        return $EXIT_SUCCESS
    else
        rm -f "$temp_podfile"
        return $EXIT_BUILD_ERROR
    fi
}

clean_pod_cache() {
    log::step "PODS" "Cleaning CocoaPods cache..."

    if bundle exec pod cache clean --all; then
        log::success "PODS" "CocoaPods cache cleaned"
        return $EXIT_SUCCESS
    else
        log::warn "PODS" "CocoaPods cache cleaning had issues"
        return $EXIT_GENERAL_ERROR
    fi
}

show_pod_info() {
    if ! validate_cocoapods_environment; then
        return $EXIT_VALIDATION_ERROR
    fi

    print_subsection "CocoaPods Information"

    local pod_version
    pod_version=$(get_command_version "pod")
    log::info "PODS" "CocoaPods version: $pod_version"

    # Ruby version (CocoaPods is Ruby-based)
    local ruby_version
    ruby_version=$(get_command_version "ruby")
    log::info "PODS" "Ruby version: $ruby_version"

    if command -v bundle >/dev/null 2>&1; then
        local bundle_version
        bundle_version=$(get_command_version "bundle")
        log::info "PODS" "Bundler version: $bundle_version"
    fi

    if [[ -f "$PODFILE" ]]; then
        local ios_version
        ios_version=$(get_podfile_platforms)
        if [[ -n "$ios_version" ]]; then
            log::info "PODS" "iOS deployment target: $ios_version"
        fi
    fi

    if [[ -f "$PODFILE_LOCK" ]]; then
        local pods_count
        pods_count=$(grep -c "^  - " "$PODFILE_LOCK" 2>/dev/null || echo "0")
        log::info "PODS" "Installed pods: $pods_count"

        local lockfile_date
        if command -v stat >/dev/null 2>&1; then
            lockfile_date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$PODFILE_LOCK" 2>/dev/null || echo "unknown")
            log::info "PODS" "Podfile.lock date: $lockfile_date"
        fi
    else
        log::info "PODS" "No pods installed"
    fi
}

setup_bundle_integration() {
    log::step "PODS" "Setting up Bundle integration with CocoaPods..."

    if [[ -f "Gemfile" ]]; then
        if grep -q "gem ['\"]cocoapods['\"]" Gemfile; then
            log::debug "PODS" "CocoaPods found in Gemfile"

            if command -v bundle >/dev/null 2>&1; then
                log::debug "PODS" "Set up bundle exec wrapper for pod commands"
            fi
        else
            log::debug "PODS" "CocoaPods not found in Gemfile"
        fi
    else
        log::debug "PODS" "No Gemfile found"
    fi

    log::success "PODS" "Bundle integration setup completed"
}

full_pod_setup() {
    local clean="${1:-false}"
    
    print_section "CocoaPods Setup"
    
    if ! validate_cocoapods_environment; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    if [[ -f "Gemfile" ]]; then
        setup_bundle_integration
    fi
    
    if [[ "$clean" == "true" ]]; then
        clean_pods
    fi
    
    local install_options=()

    if [[ "$BUILD_ENVIRONMENT" == "github-actions" ]]; then
        install_options+=("--repo-update")
    fi
    
    if install_pods "${install_options[@]}"; then
        show_pod_info
        return $EXIT_SUCCESS
    else
        return $EXIT_BUILD_ERROR
    fi
}

export -f validate_cocoapods_environment
export -f validate_podfile get_podfile_platforms
export -f install_pods update_pods verify_pods_installation
export -f clean_pods deintegrate_pods
export -f find_podspecs validate_podspec validate_all_podspecs
export -f publish_podspec
export -f update_specs_repo check_pod_availability
export -f troubleshoot_cocoapods_network
export -f try_alternative_cocoapods_sources
export -f use_local_specs_repo
export -f try_dependency_fallbacks
export -f try_without_problematic_deps
export -f clean_pod_cache
export -f show_pod_info setup_bundle_integration
export -f full_pod_setup

# ---------------------------------------------------------------------
# UTF-8 FIX PATCH
# CocoaPods requires UTF-8 or pod install will crash with:
#   "Unicode Normalization not appropriate for ASCII-8BIT"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export RUBYOPT="-EUTF-8:UTF-8"
# Use fallback echo if log::info not available (subprocess context)
if command -v log::info &>/dev/null; then
    log::info "PODS" "[UTF8] UTF-8 environment applied for pod install"
else
    echo "[INFO] [PODS] [UTF8] UTF-8 environment applied for pod install" >&2
fi
# ---------------------------------------------------------------------
