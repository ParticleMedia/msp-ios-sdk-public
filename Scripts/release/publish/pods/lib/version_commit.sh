#!/usr/bin/env bash
# ============================================================================
# Version Commit Module
# ============================================================================
# Module: version_commit.sh
# Purpose: Git commit operations for adapter SDK version and MSPCore version updates
# Extracted from: publish.sh
#
# Functions:
#   - ensure_adapter_version_committed: Ensure adapter version is committed
#   - commit_adapter_version_updates: Batch commit adapter version updates
#   - ensure_mspcore_version_committed: Ensure MSPCore Config.plist version is committed
#
# Dependencies:
#   - version_management.sh (get_module_dir, adapter_sdk_version_should_skip, etc.)
#   - Logging functions (log::info, log::error, log::success, log::warn, log::debug)
#   - ROOT_DIR environment variable
#   - DRY_RUN environment variable (optional)
#
# Environment Variables:
#   - ROOT_DIR: Project root directory
#   - DRY_RUN: If "true", skip actual commit operations
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_VERSION_COMMIT_SOURCED:-}" ]] && return 0
readonly _VERSION_COMMIT_SOURCED=1

# ============================================================================
# Helper: Ensure Adapter Version is Committed
# ============================================================================
# Checks if adapter version file matches target version and commits if needed.
# This handles the case where pod was published but version commit was interrupted.
#
# Args:
#   $1: adapter name (e.g., MSPPrebidAdapter)
#   $2: target version (e.g., 1.0.0-rc.24)
#
# Returns:
#   0: Version committed successfully or no action needed
#   1: Fatal error (e.g., directory not found)
# ============================================================================
ensure_adapter_version_committed() {
    local adapter="$1"
    local version="$2"

    # Skip if in dry-run mode
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    # Skip adapters based on config
    if adapter_sdk_version_should_skip "$adapter"; then
        log::info "PODS" "[$adapter] Skipping version commit check (config skip list)"
        return 0
    fi

    log::info "PODS" "[$adapter] Checking version file state..."

    # Map pod name to directory name
    local module_dir
    module_dir=$(get_module_dir "$adapter")
    local adapter_path="Sources/Adapters/${module_dir}/${module_dir}"
    local adapter_abs_path="$ROOT_DIR/$adapter_path"

    # Validate directory exists
    if [[ ! -d "$adapter_abs_path" ]]; then
        log::error "PODS" "[$adapter] Directory not found: $adapter_abs_path"
        return 1
    fi

    if ! load_adapter_sdk_version_config; then
        log::error "PODS" "[$adapter] Failed to load adapter SDK version config"
        return 1
    fi

    local rc=0
    check_adapter_sdk_version "$adapter" "$version" || rc=$?
    case "$rc" in
        0)
            log::info "PODS" "[$adapter] ${ADAPTER_SDK_VERSION_FUNCTION}() already matches $version"
            ;;
        1)
            log::info "PODS" "[$adapter] ${ADAPTER_SDK_VERSION_FUNCTION}() mismatch detected, updating to $version..."
            if ! update_adapter_sdk_version "$adapter" "$version"; then
                log::error "PODS" "[$adapter] Failed to update SDK version"
                return 1
            fi
            # Verify the file was actually modified
            if git diff --quiet -- "$adapter_abs_path"; then
                log::error "PODS" "[$adapter] update_adapter_sdk_version returned success but file was not modified!"
                log::error "PODS" "[$adapter] Expected path: $adapter_abs_path"
                log::error "PODS" "[$adapter] This indicates a bug in the version update tool"
                return 1
            fi
            log::debug "PODS" "[$adapter] File modification verified"
            ;;
        2)
            log::warn "PODS" "[$adapter] No ${ADAPTER_SDK_VERSION_FUNCTION}() found; skipping version commit check"
            if [[ "${ADAPTER_SDK_VERSION_STRICT}" == "true" ]]; then
                return 1
            fi
            return 0
            ;;
        3)
            log::warn "PODS" "[$adapter] No string literal in ${ADAPTER_SDK_VERSION_FUNCTION}(); skipping version commit check"
            if [[ "${ADAPTER_SDK_VERSION_STRICT}" == "true" ]]; then
                return 1
            fi
            return 0
            ;;
        *)
            log::error "PODS" "[$adapter] SDK version check failed (exit $rc)"
            return 1
            ;;
    esac

    # Check if there are uncommitted changes (don't suppress errors)
    local diff_exit_code=0
    git diff --quiet -- "$adapter_abs_path" || diff_exit_code=$?

    if [[ $diff_exit_code -eq 1 ]]; then
        # Exit code 1 means there are differences (uncommitted changes)
        log::info "PODS" "[$adapter] Uncommitted version changes detected, committing now..."

        # Change to ROOT_DIR for git operations
        pushd "$ROOT_DIR" > /dev/null || {
            log::error "PODS" "[$adapter] Failed to change to ROOT_DIR: $ROOT_DIR"
            return 1
        }

        # Find and stage Swift files
        local swift_files_staged=0
        while IFS= read -r -d '' swift_file; do
            if git add "$swift_file"; then
                ((swift_files_staged++)) || true
                log::debug "PODS" "[$adapter] Staged: $swift_file"
            else
                log::warn "PODS" "[$adapter] Failed to stage: $swift_file"
            fi
        done < <(find "$adapter_path" -name "*.swift" -type f -print0)

        if [[ $swift_files_staged -gt 0 ]]; then
            # Commit with detailed message
            if git commit -m "chore(release): update ${adapter} SDK version to ${version}

- Update ${ADAPTER_SDK_VERSION_FUNCTION}() return value to ${version}
- Committed during resume/idempotency check
- Part of release ${version} preparation"; then
                log::success "PODS" "[$adapter] ✓ Committed version update ($swift_files_staged files)"
            else
                log::error "PODS" "[$adapter] ✗ Failed to commit version update"
                log::error "PODS" "[$adapter] Manual fix: cd $ROOT_DIR && git add ${adapter_path} && git commit"
                popd > /dev/null || true
                return 1
            fi
        else
            log::error "PODS" "[$adapter] No Swift files found or staged in ${adapter_path}"
            log::error "PODS" "[$adapter] Expected to find Swift files but found none"
            log::error "PODS" "[$adapter] adapter_path=$adapter_path"
            log::error "PODS" "[$adapter] Listing directory contents:"
            ls -la "$adapter_path" 2>&1 | while read -r line; do log::error "PODS" "[$adapter]   $line"; done
            popd > /dev/null || true
            return 1
        fi

        popd > /dev/null || true
    elif [[ $diff_exit_code -eq 0 ]]; then
        # Exit code 0 means no differences (already committed or no changes)
        log::info "PODS" "[$adapter] Version already committed, no action needed"
    else
        # Other exit codes indicate an error
        log::error "PODS" "[$adapter] git diff failed with exit code $diff_exit_code"
        log::error "PODS" "[$adapter] adapter_abs_path=$adapter_abs_path"
        return 1
    fi

    return 0
}

# ============================================================================
# Helper: Commit Adapter Version Updates (Post-All)
# ============================================================================
# Runs after all adapters are released successfully to avoid git index contention.
#
# Args:
#   $1: target version (e.g., 1.0.0-rc.24)
#   $@: adapter names
#
# Returns:
#   0: All commits handled (or no action needed)
#   1: One or more adapters failed commit/update
# ============================================================================
commit_adapter_version_updates() {
    local version="$1"
    shift
    local adapters=("$@")
    if [[ -n "$version" && ${#adapters[@]} -ge 0 ]]; then
        :
    fi

    log::info "PODS" "Adapter SDK version auto-commit is deprecated; skipping."
    return 0

    if [[ "$DRY_RUN" == "true" ]]; then
        log::info "PODS" "DRY RUN: Would commit adapter SDK version updates"
        return 0
    fi

    if [[ ${#adapters[@]} -eq 0 ]]; then
        log::info "PODS" "No adapters to update"
        return 0
    fi

    log_section "Post-Release: Committing adapter SDK version updates"

    local failed=0
    local committed_any=false
    for adapter in "${adapters[@]}"; do
        if ! ensure_adapter_version_committed "$adapter" "$version"; then
            log::warn "PODS" "[$adapter] Version commit/update failed"
            failed=1
        else
            # Check if a commit was actually made (not just "already committed")
            # by checking if HEAD changed
            committed_any=true
        fi
    done

    # Push version update commits to origin if any were made
    if [[ "$committed_any" == "true" ]] && [[ $failed -eq 0 ]]; then
        log::info "PODS" "Pushing adapter SDK version commits to origin..."

        # Get current branch
        local current_branch
        current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || {
            log::warn "PODS" "Failed to get current branch, skipping push"
            log::warn "PODS" "You may need to push manually: git push origin HEAD"
            return $failed
        }

        # Push to origin
        if git push origin "$current_branch" 2>&1; then
            log::success "PODS" "✓ Pushed adapter SDK version commits to origin/$current_branch"
        else
            log::warn "PODS" "Failed to push adapter SDK version commits"
            log::warn "PODS" "You may need to push manually: git push origin $current_branch"
            # Don't fail the release for push failure - pods are already published
        fi
    fi

    return $failed
}

# ============================================================================
# Helper: Ensure MSPCore Version is Committed
# ============================================================================
# Checks if MSPCore Config.plist version matches target version and commits if needed.
# This handles the case where pod was published but version commit was interrupted.
#
# Args:
#   $1: target version (e.g., 1.0.0-rc.24)
#
# Returns:
#   0: Version committed successfully or no action needed
#   1: Fatal error (e.g., Config.plist not found)
# ============================================================================
ensure_mspcore_version_committed() {
    local version="$1"

    # Skip if in dry-run mode
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    log::info "PODS" "[MSPCore] Checking Config.plist version state..."

    # Locate Config.plist
    local config_plist_rel_path="Sources/Core/MSPCore/MSPCore/Resources/Config.plist"
    local config_plist_abs_path="$ROOT_DIR/$config_plist_rel_path"

    # Validate file exists
    if [[ ! -f "$config_plist_abs_path" ]]; then
        log::error "PODS" "[MSPCore] Config.plist not found at: $config_plist_abs_path"
        return 1
    fi

    # Read current version from Config.plist
    local current_version=""
    current_version=$(grep -A1 "SDKVersion" "$config_plist_abs_path" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')

    log::info "PODS" "[MSPCore] Current version: $current_version, Target version: $version"

    # Case 1: Version mismatch - update and commit
    if [[ "$current_version" != "$version" ]]; then
        log::info "PODS" "[MSPCore] Version mismatch detected, updating to $version..."

        if ! update_config_plist_version "$version"; then
            log::error "PODS" "[MSPCore] Failed to update Config.plist version"
            return 1
        fi

        log::info "PODS" "[MSPCore] Config.plist updated, committing changes..."
    else
        log::info "PODS" "[MSPCore] Version already correct ($version)"
    fi

    # Case 2: Check if there are uncommitted changes
    if ! git diff --quiet -- "$config_plist_abs_path" 2>/dev/null; then
        log::info "PODS" "[MSPCore] Uncommitted Config.plist changes detected, committing now..."

        # Change to ROOT_DIR for git operations
        pushd "$ROOT_DIR" > /dev/null || {
            log::error "PODS" "[MSPCore] Failed to change to ROOT_DIR: $ROOT_DIR"
            return 0  # Non-fatal: pod is already published
        }

        # Stage Config.plist
        if git add "$config_plist_rel_path"; then
            # Commit with detailed message
            if git commit -m "chore(release): update MSPCore version to ${version}

- Update Config.plist SDKVersion to ${version}
- Committed during resume/idempotency check
- Part of release ${version} preparation"; then
                log::success "PODS" "[MSPCore] ✓ Committed version update"
            else
                log::error "PODS" "[MSPCore] ✗ Failed to commit version update"
                log::warn "PODS" "[MSPCore] You may need to commit manually: cd $ROOT_DIR && git add $config_plist_rel_path && git commit"
            fi
        else
            log::error "PODS" "[MSPCore] Failed to stage $config_plist_rel_path"
        fi

        popd > /dev/null || true
    else
        log::info "PODS" "[MSPCore] Version already committed, no action needed"
    fi

    return 0
}

# ============================================================================
# Export Functions
# ============================================================================

export -f ensure_adapter_version_committed 2>/dev/null || true
export -f commit_adapter_version_updates 2>/dev/null || true
export -f ensure_mspcore_version_committed 2>/dev/null || true
