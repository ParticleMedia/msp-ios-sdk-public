#!/usr/bin/env bash
# ============================================================================
# Version Commit Module
# ============================================================================
# Module: version_commit.sh
# Purpose: Update Config.plist versions and commit immediately
#
# Functions:
#   - update_and_commit_plist_version: Update a Config.plist + git commit (DRY)
#   - ensure_version_files_committed: Safety net for any uncommitted version files
#
# Dependencies:
#   - version.sh (update_config_plist_version, update_novacore_config_plist_version)
#   - Logging functions (log::info, log::error, log::success, log::warn)
#   - ROOT_DIR environment variable
#   - DRY_RUN environment variable (optional)
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_VERSION_COMMIT_SOURCED:-}" ]] && return 0
readonly _VERSION_COMMIT_SOURCED=1

# ============================================================================
# DRY Helper: Update Config.plist version and commit immediately
# ============================================================================
# Updates a Config.plist SDKVersion and commits the change right away.
# Called from Step 0.9 (NovaCore) and release_msp_core (MSPCore).
#
# Args:
#   $1: target — "mspcore" or "novacore"
#   $2: version (e.g., 3.1.7)
#
# Returns:
#   0: Updated and committed (or dry-run/already up-to-date)
#   1: Update failed
# ============================================================================
update_and_commit_plist_version() {
    local target="$1"
    local version="$2"
    local rel_path label

    case "$target" in
        mspcore)
            rel_path="Sources/Core/MSPCore/MSPCore/Resources/Config.plist"
            label="MSPCore"
            if ! update_config_plist_version "$version"; then
                log::error "PODS" "[$label] Failed to update Config.plist version"
                return 1
            fi
            ;;
        novacore)
            rel_path="Sources/Core/NovaCore/NovaCore/NBResourceBundle.bundle/Config.plist"
            label="NovaCore"
            if ! update_novacore_config_plist_version "$version"; then
                log::error "PODS" "[$label] Failed to update Config.plist version"
                return 1
            fi
            ;;
        *)
            log::error "PODS" "Unknown target: $target (expected mspcore or novacore)"
            return 1
            ;;
    esac

    log::success "PODS" "[$label] Config.plist SDKVersion updated to $version"

    # Commit immediately (skip in dry-run mode)
    if [[ "${DRY_RUN:-false}" != "true" ]]; then
        pushd "$ROOT_DIR" > /dev/null || true
        git add "$rel_path" 2>/dev/null || true
        git commit -m "chore(release): update $label Config.plist SDKVersion to ${version}" 2>/dev/null || {
            log::warn "PODS" "[$label] Config.plist already committed or nothing to commit"
        }
        popd > /dev/null || true
    fi

    return 0
}

# ============================================================================
# Safety Net: Ensure all version files are committed
# ============================================================================
# Catches any version files that slipped through uncommitted.
# In normal flow each file is committed at its modification site,
# so this function usually finds nothing to do.
#
# Checks and commits:
#   - MSPCore Config.plist (update if version mismatches)
#   - NovaCore Config.plist (update if version mismatches)
#   - sdk_version.conf (SSOT)
#
# Args:
#   $1: target version (e.g., 1.0.0-rc.24)
#
# Returns:
#   0: All committed or no action needed
#   1: Fatal error
# ============================================================================
ensure_version_files_committed() {
    local version="$1"

    # Skip if in dry-run mode
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        return 0
    fi

    log::info "PODS" "Checking version files commit state..."

    # --- MSPCore Config.plist ---
    local mspcore_rel="Sources/Core/MSPCore/MSPCore/Resources/Config.plist"
    local mspcore_abs="$ROOT_DIR/$mspcore_rel"

    if [[ -f "$mspcore_abs" ]]; then
        local mspcore_ver=""
        mspcore_ver=$(grep -A1 "SDKVersion" "$mspcore_abs" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
        if [[ "$mspcore_ver" != "$version" ]]; then
            log::info "PODS" "[MSPCore] Version mismatch ($mspcore_ver != $version), updating..."
            update_config_plist_version "$version" || true
        fi
    fi

    # --- NovaCore Config.plist ---
    local novacore_rel="Sources/Core/NovaCore/NovaCore/NBResourceBundle.bundle/Config.plist"
    local novacore_abs="$ROOT_DIR/$novacore_rel"

    if [[ -f "$novacore_abs" ]]; then
        local novacore_ver=""
        novacore_ver=$(grep -A1 "SDKVersion" "$novacore_abs" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
        if [[ "$novacore_ver" != "$version" ]]; then
            log::info "PODS" "[NovaCore] Version mismatch ($novacore_ver != $version), updating..."
            update_novacore_config_plist_version "$version" || true
        fi
    fi

    # --- Check for any uncommitted changes ---
    local ssot_rel="Scripts/config/sdk_version.conf"

    local has_changes=false
    git diff --quiet -- "$mspcore_abs" 2>/dev/null || has_changes=true
    git diff --quiet -- "$novacore_abs" 2>/dev/null || has_changes=true
    git diff --quiet -- "$ROOT_DIR/$ssot_rel" 2>/dev/null || has_changes=true

    if [[ "$has_changes" == "true" ]]; then
        log::info "PODS" "Uncommitted version file changes detected, committing now..."

        pushd "$ROOT_DIR" > /dev/null || {
            log::error "PODS" "Failed to change to ROOT_DIR: $ROOT_DIR"
            return 0  # Non-fatal
        }

        git add "$mspcore_rel" 2>/dev/null || true
        git add "$novacore_rel" 2>/dev/null || true
        git add "$ssot_rel" 2>/dev/null || true

        if git commit -m "chore(release): update version files to ${version}

- MSPCore Config.plist SDKVersion → ${version}
- NovaCore Config.plist SDKVersion → ${version}
- sdk_version.conf (SSOT)
- Safety net commit during release ${version}"; then
            log::success "PODS" "Committed version files"
        else
            log::error "PODS" "Failed to commit version files"
            log::warn "PODS" "Manual fix: cd $ROOT_DIR && git add $mspcore_rel $novacore_rel $ssot_rel && git commit"
        fi

        popd > /dev/null || true
    else
        log::info "PODS" "All version files already committed"
    fi

    # Also update DemoApp MARKETING_VERSION to match SDK version
    if command -v update_demo_app_version &>/dev/null; then
        update_demo_app_version "$version"

        local template_rel="Examples/MSPDemoApp/project.yml.template"
        local update_sh_rel="Scripts/workspace/update.sh"

        pushd "$ROOT_DIR" > /dev/null || true
        git add "$template_rel" "$update_sh_rel" 2>/dev/null || true
        git commit -m "chore(release): update DemoApp MARKETING_VERSION to ${version}" 2>/dev/null || {
            log::warn "PODS" "DemoApp version commit failed or nothing to commit"
        }
        popd > /dev/null || true
    fi

    return 0
}

# Backward compatibility alias
ensure_mspcore_version_committed() {
    ensure_version_files_committed "$@"
}

# ============================================================================
# Export Functions
# ============================================================================

export -f update_and_commit_plist_version 2>/dev/null || true
export -f ensure_version_files_committed 2>/dev/null || true
export -f ensure_mspcore_version_committed 2>/dev/null || true
