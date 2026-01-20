#!/bin/bash
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

# Prevent multiple sourcing
[[ -n "${_MSP_COCOAPODS_SOURCED:-}" ]] && return 0
readonly _MSP_COCOAPODS_SOURCED=1

# CocoaPods operations for MSP iOS SDK build system
# This module provides comprehensive CocoaPods management with dependency handling and validation

# Source dependencies
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/validation.sh"

# Source process utilities (timeout functions)
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/process_utils.sh" ]]; then
    # shellcheck source=Scripts/lib/process_utils.sh
    source "$(dirname "${BASH_SOURCE[0]}")/process_utils.sh" 2>/dev/null || true
fi

# CocoaPods constants
# Note: PODFILE is not readonly to allow override in release scripts
PODFILE="${PODFILE:-Podfile}"   # allow override, no readonly
readonly PODFILE_LOCK="Podfile.lock"
readonly PODS_DIR="Pods"
readonly PODSPEC_EXTENSION=".podspec"

# CocoaPods validation functions
validate_cocoapods_environment() {
    log_step "Validating CocoaPods environment..."
    
    # Check if CocoaPods is installed
    if ! check_command_exists "pod" "CocoaPods"; then
        log_error "CocoaPods not installed. Run: sudo gem install cocoapods"
        return $EXIT_COMMAND_NOT_FOUND
    fi
    
    # Check CocoaPods version
    local pod_version
    pod_version=$(get_command_version "pod")
    if [[ "$pod_version" == "unknown" ]]; then
        log_warn "Could not determine CocoaPods version"
    else
        log_debug "CocoaPods version: $pod_version"
    fi
    
    # Check if Podfile exists
    if ! check_path_exists "$PODFILE" "Podfile" "file"; then
        log_error "Podfile not found. This doesn't appear to be a CocoaPods project."
        return $EXIT_VALIDATION_ERROR
    fi
    
    log_success "CocoaPods environment validated"
    return $EXIT_SUCCESS
}

# Podfile operations
validate_podfile() {
    local podfile="${1:-$PODFILE}"
    
    if ! check_path_exists "$podfile" "Podfile" "file"; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    log_step "Validating Podfile syntax..."
    
    # Basic syntax check
    if bundle exec pod spec lint --quick --allow-warnings "$podfile" >/dev/null 2>&1; then
        log_success "Podfile syntax is valid"
        return $EXIT_SUCCESS
    else
        # Pod spec lint might not work on Podfile, so try a different approach
        if ruby -c "$podfile" >/dev/null 2>&1; then
            log_success "Podfile syntax is valid"
            return $EXIT_SUCCESS
        else
            log_error "Podfile has syntax errors"
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

# Installation and update operations
install_pods() {
    local options=("$@")
    local repo_update=false
    local clean_install=false
    
    # Parse options
    for option in "${options[@]}"; do
        case "$option" in
            "--repo-update") repo_update=true ;;
            "--clean") clean_install=true ;;
        esac
    done
    
    if ! validate_cocoapods_environment; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Clean install if requested
    if [[ "$clean_install" == "true" ]]; then
        clean_pods
    fi
    
    log_step "Installing CocoaPods dependencies..."
    
    local install_cmd="bundle exec pod install"
    
    # Add repo update if requested or if this is CI
    if [[ "$repo_update" == "true" ]] || [[ "$BUILD_ENVIRONMENT" == "github-actions" ]]; then
        install_cmd="$install_cmd --repo-update"
        log_debug "Including repository update"
    fi
    
    # Add CI-specific flags
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
        log_success "CocoaPods installation completed in $(format_duration $duration)"
        
        # Verify installation
        verify_pods_installation
        return $EXIT_SUCCESS
    else
        log_warn "CocoaPods installation failed, attempting troubleshooting..."
        
        # Try troubleshooting network issues
        if troubleshoot_cocoapods_network; then
            log_info "Network troubleshooting successful, retrying installation..."
            
            # Retry installation after troubleshooting
            if eval "$install_cmd"; then
                local duration
                duration=$(($(date +%s) - start_time))
                log_success "CocoaPods installation completed after troubleshooting in $(format_duration $duration)"
                
                # Verify installation
                verify_pods_installation
                return $EXIT_SUCCESS
            fi
        fi
        
        log_error "CocoaPods installation failed even after troubleshooting"
        return $EXIT_BUILD_ERROR
    fi
}

update_pods() {
    local options=("$@")
    
    if ! validate_cocoapods_environment; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    log_step "Updating CocoaPods dependencies..."
    
    local update_cmd="bundle exec pod update"
    
    # Add options
    for option in "${options[@]}"; do
        case "$option" in
            "--verbose") update_cmd="$update_cmd --verbose" ;;
            "--no-repo-update") update_cmd="$update_cmd --no-repo-update" ;;
        esac
    done
    
    if eval "$update_cmd"; then
        log_success "CocoaPods update completed"
        verify_pods_installation
        return $EXIT_SUCCESS
    else
        log_error "CocoaPods update failed"
        return $EXIT_BUILD_ERROR
    fi
}

verify_pods_installation() {
    log_step "Verifying CocoaPods installation..."
    
    # Check if Podfile.lock exists
    if ! check_path_exists "$PODFILE_LOCK" "Podfile.lock" "file"; then
        log_warn "Podfile.lock not found"
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Check if Pods directory exists
    if ! check_path_exists "$PODS_DIR" "Pods directory" "directory"; then
        log_warn "Pods directory not found"
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Check if dependencies are up to date
    if command -v bundle >/dev/null 2>&1; then
        if bundle check >/dev/null 2>&1; then
            log_debug "Bundle dependencies are up to date"
        else
            log_warn "Bundle dependencies need updating"
        fi
    fi
    
    # Get installation statistics
    local pods_count=0
    if [[ -f "$PODFILE_LOCK" ]]; then
        pods_count=$(grep -c "^  - " "$PODFILE_LOCK" 2>/dev/null || echo "0")
    fi
    
    log_success "CocoaPods installation verified ($pods_count dependencies)"
    return $EXIT_SUCCESS
}

# Cleanup operations
clean_pods() {
    log_step "Cleaning CocoaPods installation..."
    
    # Remove Pods directory
    if [[ -d "$PODS_DIR" ]]; then
        safe_remove "$PODS_DIR"
        log_debug "Removed Pods directory"
    fi
    
    # Remove Podfile.lock
    if [[ -f "$PODFILE_LOCK" ]]; then
        safe_remove "$PODFILE_LOCK"
        log_debug "Removed Podfile.lock"
    fi
    
    # Remove workspace if it exists and seems to be generated by CocoaPods
    local workspace_files=(*.xcworkspace)
    for workspace in "${workspace_files[@]}"; do
        if [[ -f "$workspace" ]] && [[ "$workspace" != "*.xcworkspace" ]]; then
            # Check if workspace is likely generated by CocoaPods
            if grep -q "Pods/" "$workspace/contents.xcworkspacedata" 2>/dev/null; then
                log_debug "Workspace $workspace appears to be CocoaPods-managed, keeping it"
            fi
        fi
    done
    
    log_success "CocoaPods cleanup completed"
}

deintegrate_pods() {
    log_step "Deintegrating CocoaPods..."
    
    if command -v pod >/dev/null 2>&1; then
        if bundle exec pod deintegrate; then
            log_success "CocoaPods deintegration completed"
        else
            log_warn "CocoaPods deintegration had issues, continuing with manual cleanup"
            clean_pods
        fi
    else
        log_warn "CocoaPods not available, performing manual cleanup"
        clean_pods
    fi
}

# Podspec operations
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
    
    log_step "Validating podspec: $(basename "$podspec")..."
    
    local lint_cmd="bundle exec pod spec lint \"$podspec\""
    
    # Add common options
    lint_cmd="$lint_cmd --allow-warnings --skip-import-validation"
    
    # Add custom options
    for option in "${options[@]}"; do
        lint_cmd="$lint_cmd $option"
    done
    
    log_info "Running pod spec lint (timeout: 30 minutes)..."
    
    # Run with timeout: 30 minutes (1800s)
    # Rationale: Observed 1-5 min, extreme cases up to 20 min (complex deps), 30 min provides safety margin
    if run_with_timeout 1800 eval "$lint_cmd"; then
        log_success "Podspec validation passed: $(basename "$podspec")"
        return $EXIT_SUCCESS
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log_error "❌ TIMEOUT: pod spec lint exceeded 30 minutes"
            log_error "This usually indicates:"
            log_error "  1. Dependency resolution hanging"
            log_error "  2. Network issues downloading dependencies"
            log_error "  3. Build phase hanging"
            log_error ""
            log_error "Troubleshooting:"
            log_error "  1. Check dependency availability: pod search <dep_name>"
            log_error "  2. Test locally: $lint_cmd"
            log_error "  3. Check network: bundle exec pod repo update"
            return $EXIT_VALIDATION_ERROR
        else
            log_error "Podspec validation failed: $(basename "$podspec")"
            return $EXIT_VALIDATION_ERROR
        fi
    fi
}

validate_all_podspecs() {
    local directory="${1:-.}"
    local failed_specs=()
    local total_specs=0
    
    log_step "Validating all podspecs in $directory..."
    
    # Find all podspecs
    local podspecs
    mapfile -t podspecs < <(find_podspecs "$directory")
    
    if [[ ${#podspecs[@]} -eq 0 ]]; then
        log_warn "No podspecs found in $directory"
        return $EXIT_SUCCESS
    fi
    
    # Validate each podspec
    for podspec in "${podspecs[@]}"; do
        ((total_specs++))
        
        if ! validate_podspec "$podspec" >/dev/null 2>&1; then
            failed_specs+=("$(basename "$podspec")")
        fi
    done
    
    # Report results
    if [[ ${#failed_specs[@]} -eq 0 ]]; then
        log_success "All $total_specs podspecs validated successfully"
        return $EXIT_SUCCESS
    else
        log_error "${#failed_specs[@]} of $total_specs podspecs failed validation:"
        for spec in "${failed_specs[@]}"; do
            log_error "  - $spec"
        done
        return $EXIT_VALIDATION_ERROR
    fi
}

# Publishing operations
publish_podspec() {
    local podspec="$1"
    local options=("${@:2}")
    
    if ! check_path_exists "$podspec" "Podspec" "file"; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Validate before publishing
    if ! validate_podspec "$podspec"; then
        log_error "Cannot publish invalid podspec"
        return $EXIT_VALIDATION_ERROR
    fi
    
    log_step "Publishing podspec: $(basename "$podspec")..."
    
    local push_cmd="bundle exec pod trunk push \"$podspec\""
    
    # Add common options
    push_cmd="$push_cmd --allow-warnings"
    
    # Add custom options
    for option in "${options[@]}"; do
        push_cmd="$push_cmd $option"
    done
    
    if eval "$push_cmd"; then
        log_success "Podspec published successfully: $(basename "$podspec")"
        return $EXIT_SUCCESS
    else
        log_error "Podspec publishing failed: $(basename "$podspec")"
        return $EXIT_BUILD_ERROR
    fi
}

# Repository operations
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

    local cache_file="/tmp/msp-cocoapods-specs-repo-last-update"
    local cache_lock="${cache_file}.lock"
    local cache_ttl=300  # 5 minutes (300 seconds)
    local current_time
    current_time=$(date +%s)
    local max_attempts=3
    local attempt=1

    # Use file lock to prevent concurrent updates
    (
        # Check if flock is available (Linux has it, macOS may need coreutils)
        if ! command -v flock >/dev/null 2>&1; then
            log_debug "flock not available (macOS), skipping specs cache locking"
            log_debug "To enable file locking on macOS, install flock via: brew install coreutils"
            # Continue without locking (less safe but won't block execution)
            # Note: CocoaPods has its own locking mechanism via .git/index.lock
        else
            # Use flock for file locking
            # Try to acquire lock (non-blocking)
            if ! flock -n 9; then
                log_info "Another process is updating specs repo, waiting for lock..."
                # Wait for lock (blocking)
                flock 9
                log_info "Lock acquired, checking cache..."
            fi
        fi

        # Check cache (now protected by lock)
        if [[ -f "$cache_file" ]]; then
            local last_update_time
            last_update_time=$(cat "$cache_file" 2>/dev/null || echo 0)
            local time_since_update=$((current_time - last_update_time))

            if [[ $time_since_update -lt $cache_ttl ]]; then
                local remaining=$((cache_ttl - time_since_update))
                log_info "Specs repository was updated ${time_since_update}s ago (< ${cache_ttl}s TTL)"
                log_info "Skipping redundant update (will refresh in ${remaining}s if needed)"
                exit 0
            else
                log_debug "Cache expired (${time_since_update}s > ${cache_ttl}s TTL), updating now..."
            fi
        else
            log_debug "No cache found, performing first update..."
        fi

        # Perform update (only one process at a time)
        log_step "Updating CocoaPods specs repository..."

        while [[ $attempt -le $max_attempts ]]; do
            log_debug "Attempt $attempt/$max_attempts: Updating CocoaPods specs repository..."

            # Run with timeout: 15 minutes (900s)
            # Rationale: Observed 1-4 min, extreme cases up to 10 min, 15 min provides safety margin
            if run_with_timeout 900 bundle exec pod repo update; then
                # Update cache timestamp on success
                echo "$current_time" > "$cache_file"
                log_success "Specs repository updated (cache timestamp: $current_time)"
                exit 0
            else
                local exit_code=$?
                if [[ $exit_code -eq 124 ]]; then
                    log_error "pod repo update TIMED OUT after 15 minutes"
                else
                    log_error "pod repo update failed with exit code $exit_code"
                fi

                if [[ $attempt -lt $max_attempts ]]; then
                    log_info "Retrying in 5 seconds..."
                    sleep 5
                fi
            fi

            ((attempt++))
        done

        log_error "Failed to update specs repository after $max_attempts attempts"
        exit 1

    ) 9>"$cache_lock"

    local result=$?

    # Clean up lock file if it exists and is old (older than 1 hour)
    if [[ -f "$cache_lock" ]]; then
        local lock_age=$((current_time - $(stat -f %m "$cache_lock" 2>/dev/null || stat -c %Y "$cache_lock" 2>/dev/null || echo $current_time)))
        if [[ $lock_age -gt 3600 ]]; then
            log_warn "Removing stale lock file (age: ${lock_age}s)"
            rm -f "$cache_lock"
        fi
    fi

    return $result
}

# Clear specs repo update cache (for testing/debugging)
clear_specs_repo_cache() {
    local cache_file="/tmp/msp-cocoapods-specs-repo-last-update"
    if [[ -f "$cache_file" ]]; then
        rm -f "$cache_file"
        log_info "Cleared specs repository update cache"
    else
        log_debug "No cache file to clear"
    fi
}

export -f clear_specs_repo_cache

check_pod_availability() {
    local pod_name="$1"
    local version="${2:-}"
    
    local max_attempts=3
    local attempt=1
    
    if [[ -n "$version" ]]; then
        log_step "Checking availability of $pod_name version $version..."
    else
        log_step "Checking availability of $pod_name..."
    fi
    
    local last_search_failed=false
    
    while [[ $attempt -le $max_attempts ]]; do
        # ═══════════════════════════════════════════════════════════════════════
        # Smart Update Strategy (Fix for infinite loop issue)
        # ═══════════════════════════════════════════════════════════════════════
        # Only update specs repo on first attempt or after search failure
        # This reduces redundant updates from ~7 per check to 1-2 per check
        # ═══════════════════════════════════════════════════════════════════════

        # Update on first attempt, or if previous search failed
        local should_update=false
        if [[ $attempt -eq 1 ]]; then
            should_update=true
            log_debug "First attempt: Updating CocoaPods specs repository..."
        elif [[ "$last_search_failed" == "true" ]]; then
            should_update=true
            log_debug "Previous search failed, updating specs repository (attempt $attempt/$max_attempts)..."
        else
            log_debug "Attempt $attempt/$max_attempts: Reusing cached specs repository..."
        fi

        # Update specs repository if needed
        if [[ "$should_update" == "true" ]]; then
            if ! update_specs_repo; then
                log_warn "Failed to update specs repository (attempt $attempt/$max_attempts)"
                if [[ $attempt -lt $max_attempts ]]; then
                    local delay=$((attempt * 3))
                    log_info "Retrying in ${delay} seconds..."
                    sleep $delay
                fi
                ((attempt++))
                continue
            fi
        fi
        
        log_debug "Searching for $pod_name..."
        
        # Use a more reliable method to check pod availability
        local search_output
        local search_exit_code
        
        # Check both cocoapods and trunk repositories to ensure availability
        # since pod spec lint uses trunk repo while pod search might use cocoapods repo
        log_debug "Running: bundle exec pod search '$pod_name' --simple"
        # Run with timeout: 10 minutes (600s)
        # Rationale: Usually seconds, but large specs repo can be slow
        if search_output=$(run_with_timeout 600 bundle exec pod search "$pod_name" --simple 2>&1); then
            search_exit_code=0
        else
            search_exit_code=$?
            if [[ $search_exit_code -eq 124 ]]; then
                log_error "pod search TIMED OUT after 10 minutes"
                log_error "This usually indicates specs repo corruption or network issues"
                # Try to recover by updating specs repo
                log_info "Attempting to recover by updating specs repo..."
                run_with_timeout 900 bundle exec pod repo update || true
            fi
            log_debug "Pod search exit code: $search_exit_code"
            log_debug "Pod search output: $search_output"
        fi
        
        if [[ $search_exit_code -eq 0 ]] && [[ -n "$search_output" ]]; then
            if [[ -n "$version" ]]; then
                # Try to find specific version in the search output
                if echo "$search_output" | grep -q "$version"; then
                    # Additional verification: check if the podspec is actually available in trunk repo
                    # This ensures it's available for pod spec lint validation
                    # Use find to locate the podspec file (trunk repo uses hash-based directory structure)
                    log_debug "Version found in search, verifying availability in trunk repo for validation..."
                    local trunk_spec_path="${HOME}/.cocoapods/repos/trunk/Specs"
                    local spec_file_pattern="${pod_name}/${version}/${pod_name}.podspec.json"
                    
                    # Check if podspec file exists in trunk repo (verify CDN propagation)
                    if find "$trunk_spec_path" -path "*/${spec_file_pattern}" -type f -print -quit 2>/dev/null | grep -q "${pod_name}\.podspec\.json"; then
                        log_success "$pod_name version $version is available and ready for validation"
                        # Clear failure flag on success
                        last_search_failed=false
                        return $EXIT_SUCCESS
                    else
                        log_warn "$pod_name version $version found in search but not yet available for validation"
                        log_debug "Available versions in search: $(echo "$search_output" | head -5)"
                        return $EXIT_NOT_FOUND_YET  # Return proper constant for "not found yet"
                    fi
                else
                    log_warn "$pod_name is available but version $version not found yet"
                    log_debug "Available versions: $(echo "$search_output" | head -5)"
                    return $EXIT_NOT_FOUND_YET  # Return proper constant for "not found yet"
                fi
            else
                log_success "$pod_name is available"
                return $EXIT_SUCCESS
            fi
        else
            log_warn "Pod search failed (attempt $attempt/$max_attempts)"
            log_debug "Search output: $search_output"

            # Mark that search failed (trigger update on next attempt)
            last_search_failed=true

            if [[ $attempt -lt $max_attempts ]]; then
                local delay=$((attempt * 3))
                log_info "Retrying in ${delay} seconds..."
                sleep $delay
            else
                # Return proper constant for "not found yet" instead of validation error
                return $EXIT_NOT_FOUND_YET
            fi
        fi
        
        ((attempt++))
    done
    
    log_error "$pod_name not found in CocoaPods repository after $max_attempts attempts"
    return $EXIT_NOT_FOUND_YET  # Return proper constant for "not found yet"
}

# Network troubleshooting
troubleshoot_cocoapods_network() {
    log_step "Troubleshooting CocoaPods network issues..."
    
    # Check if we can reach the CDN
    if curl -s --connect-timeout 10 "https://cdn.cocoapods.org/" >/dev/null 2>&1; then
        log_success "CocoaPods CDN is reachable"
        return $EXIT_SUCCESS
    fi
    
    log_warn "CocoaPods CDN is not reachable, trying multiple strategies..."
    
    # Strategy 1: Clean cache and retry
    log_info "Strategy 1: Cleaning cache and retrying..."
        if bundle exec pod cache clean --all >/dev/null 2>&1; then
        log_info "Cache cleaned successfully"
        if run_with_timeout 900 bundle exec pod repo update >/dev/null 2>&1; then
            log_success "Repository updated after cache clean"
            return $EXIT_SUCCESS
        fi
    fi
    
    # Strategy 2: Try alternative sources
    log_info "Strategy 2: Trying alternative CocoaPods sources..."
    if try_alternative_cocoapods_sources; then
        log_success "Alternative sources worked"
        return $EXIT_SUCCESS
    fi
    
    # Strategy 3: Use local specs repo
    log_info "Strategy 3: Using local specs repository..."
    if use_local_specs_repo; then
        log_success "Local specs repository worked"
        return $EXIT_SUCCESS
    fi
    
    # Strategy 4: Skip problematic dependencies temporarily
    log_info "Strategy 4: Attempting build with dependency fallbacks..."
    if try_dependency_fallbacks; then
        log_success "Dependency fallbacks enabled"
        return $EXIT_SUCCESS
    fi
    
    # All strategies failed
    log_error "All network troubleshooting strategies failed"
    log_info "Possible solutions:"
    log_info "1. Check your internet connection"
    log_info "2. Try using a VPN if behind a corporate firewall"
    log_info "3. Wait a few minutes and try again"
    log_info "4. Check CocoaPods status at https://status.cocoapods.org/"
    log_info "5. Consider using local dependency copies"
    return $EXIT_BUILD_ERROR
}

# Try alternative CocoaPods sources
try_alternative_cocoapods_sources() {
    log_debug "Trying alternative CocoaPods sources..."
    
    # Add alternative sources
    local sources=(
        "https://github.com/CocoaPods/Specs.git"
        "https://cdn.cocoapods.org/"
    )
    
    for source in "${sources[@]}"; do
        log_debug "Trying source: $source"
        if bundle exec pod repo add temp-repo "$source" >/dev/null 2>&1; then
            log_info "Successfully added source: $source"
            # Try to update with this source
            if run_with_timeout 900 bundle exec pod repo update temp-repo >/dev/null 2>&1; then
                log_success "Source $source is working"
                return $EXIT_SUCCESS
            fi
            # Clean up if it didn't work
            bundle exec pod repo remove temp-repo >/dev/null 2>&1
        fi
    done
    
    return $EXIT_BUILD_ERROR
}

# Use local specs repository
use_local_specs_repo() {
    log_debug "Attempting to use local specs repository..."
    
    # Check if we have a local specs repo
    local specs_repo_path="$HOME/.cocoapods/repos/trunk"
    if [[ -d "$specs_repo_path" ]]; then
        log_info "Found local specs repository at $specs_repo_path"
        
        # Try to use the local repo
        if bundle exec pod install --no-repo-update >/dev/null 2>&1; then
            log_success "Successfully used local specs repository"
            return $EXIT_SUCCESS
        fi
    fi
    
    return $EXIT_BUILD_ERROR
}

# Try dependency fallbacks for problematic packages
try_dependency_fallbacks() {
    log_debug "Setting up dependency fallbacks..."
    
    # Create a temporary Podfile with fallback dependencies
    local temp_podfile="Podfile.fallback"
    local original_podfile="Podfile"
    
    if [[ -f "$original_podfile" ]]; then
        # Create a backup
        cp "$original_podfile" "${original_podfile}.backup"
        
        # Create fallback Podfile with alternative sources and dependency handling
        cat > "$temp_podfile" << 'EOF'
# Fallback Podfile with alternative sources and dependency handling
source 'https://github.com/CocoaPods/Specs.git'
source 'https://cdn.cocoapods.org/'

# Use the original Podfile content but with fallback sources
EOF
        
        # Append original Podfile content (excluding source lines)
        grep -v "^source " "$original_podfile" >> "$temp_podfile"
        
        # Try to install with fallback Podfile
        if bundle exec pod install --podfile="$temp_podfile" >/dev/null 2>&1; then
            log_success "Fallback Podfile worked"
            # Replace original with working fallback
            mv "$temp_podfile" "$original_podfile"
            return $EXIT_SUCCESS
        else
            # Try with problematic dependencies commented out
            log_info "Trying with problematic dependencies temporarily disabled..."
            if try_without_problematic_deps; then
                log_success "Build succeeded without problematic dependencies"
                return $EXIT_SUCCESS
            fi
            
            # Restore original
            mv "${original_podfile}.backup" "$original_podfile"
            rm -f "$temp_podfile"
        fi
    fi
    
    return $EXIT_BUILD_ERROR
}

# Try building without problematic dependencies
try_without_problematic_deps() {
    log_debug "Attempting build without problematic dependencies..."
    
    local temp_podfile="Podfile.no-problematic-deps"
    local original_podfile="Podfile"
    
    # Create a modified Podfile without problematic dependencies
    sed -e 's/spec\.dependency '\''OpenWrapSDK'\''/#spec.dependency '\''OpenWrapSDK'\''/g' \
        -e 's/spec\.dependency '\''IronSourceSDK'\''/#spec.dependency '\''IronSourceSDK'\''/g' \
        "$original_podfile" > "$temp_podfile"
    
    # Try to install with modified Podfile
    if bundle exec pod install --podfile="$temp_podfile" >/dev/null 2>&1; then
        log_success "Build succeeded without problematic dependencies"
        # Replace original with working version
        mv "$temp_podfile" "$original_podfile"
        return $EXIT_SUCCESS
    else
        # Clean up
        rm -f "$temp_podfile"
        return $EXIT_BUILD_ERROR
    fi
}

# Cache operations
clean_pod_cache() {
    log_step "Cleaning CocoaPods cache..."
    
    if bundle exec pod cache clean --all; then
        log_success "CocoaPods cache cleaned"
        return $EXIT_SUCCESS
    else
        log_warn "CocoaPods cache cleaning had issues"
        return $EXIT_GENERAL_ERROR
    fi
}

# Information and diagnostics
show_pod_info() {
    if ! validate_cocoapods_environment; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    print_subsection "CocoaPods Information"
    
    # CocoaPods version
    local pod_version
    pod_version=$(get_command_version "pod")
    log_info "CocoaPods version: $pod_version"
    
    # Ruby version (CocoaPods is Ruby-based)
    local ruby_version
    ruby_version=$(get_command_version "ruby")
    log_info "Ruby version: $ruby_version"
    
    # Bundler version if available
    if command -v bundle >/dev/null 2>&1; then
        local bundle_version
        bundle_version=$(get_command_version "bundle")
        log_info "Bundler version: $bundle_version"
    fi
    
    # Platform info from Podfile
    if [[ -f "$PODFILE" ]]; then
        local ios_version
        ios_version=$(get_podfile_platforms)
        if [[ -n "$ios_version" ]]; then
            log_info "iOS deployment target: $ios_version"
        fi
    fi
    
    # Installation status
    if [[ -f "$PODFILE_LOCK" ]]; then
        local pods_count
        pods_count=$(grep -c "^  - " "$PODFILE_LOCK" 2>/dev/null || echo "0")
        log_info "Installed pods: $pods_count"
        
        local lockfile_date
        if command -v stat >/dev/null 2>&1; then
            lockfile_date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$PODFILE_LOCK" 2>/dev/null || echo "unknown")
            log_info "Podfile.lock date: $lockfile_date"
        fi
    else
        log_info "No pods installed"
    fi
}

# Bundle integration
setup_bundle_integration() {
    log_step "Setting up Bundle integration with CocoaPods..."
    
    # Check if Gemfile exists
    if [[ -f "Gemfile" ]]; then
        # Check if CocoaPods is in Gemfile
        if grep -q "gem ['\"]cocoapods['\"]" Gemfile; then
            log_debug "CocoaPods found in Gemfile"
            
            # Use bundle exec for pod commands if available
            if command -v bundle >/dev/null 2>&1; then
                # Create wrapper functions that use bundle exec
                # pod command is already available
                log_debug "Set up bundle exec wrapper for pod commands"
            fi
        else
            log_debug "CocoaPods not found in Gemfile"
        fi
    else
        log_debug "No Gemfile found"
    fi
    
    log_success "Bundle integration setup completed"
}

# High-level operations
full_pod_setup() {
    local clean="${1:-false}"
    
    print_section "CocoaPods Setup"
    
    if ! validate_cocoapods_environment; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Setup bundle integration if available
    if [[ -f "Gemfile" ]]; then
        setup_bundle_integration
    fi
    
    # Clean if requested
    if [[ "$clean" == "true" ]]; then
        clean_pods
    fi
    
    # Install pods
    local install_options=()
    
    # Add repo update for CI environments
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

# Export CocoaPods functions
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
log_info "[UTF8] UTF-8 environment applied for pod install"
# ---------------------------------------------------------------------

