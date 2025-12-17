#!/usr/bin/env bash
# ============================================================================
# MSP Release System - Safety Checks (Phase 3)
# ============================================================================
# Purpose: Enforce strict safety requirements for Release tier executions
#          to prevent accidental production releases.
#
# Safety Features:
#   1. Block Release tier from running locally (requires CI environment)
#      - Local release can be enabled via MSP_ALLOW_LOCAL_RELEASE=1
#   2. Require clean Git state
#   3. Validate version format
#   4. Require confirmation unless --force is passed
#   5. Block release if branch name is not allowed
#   6. Require changelog (release.md)
# ============================================================================

# Prevent multiple sourcing
[[ -n "${_MSP_SAFETY_SOURCED:-}" ]] && return 0
readonly _MSP_SAFETY_SOURCED=1

# ============================================================================
# Safety Check 1: Block Release Tier from Running Locally
# ============================================================================
msp_safety_require_ci_for_release() {
    local tier="${MSP_RELEASE_TIER:-preflight}"

    if [[ "$tier" == "release" || "$tier" == "production" ]]; then
        if [[ -z "${CI:-}" ]]; then
            # Local release mode: Allow local execution when explicitly enabled
            if [[ "${MSP_ALLOW_LOCAL_RELEASE:-0}" == "1" ]]; then
                log_info "[SAFETY] ℹ️  本地发布模式已启用 (Local release mode enabled)"
                log_info "[SAFETY] ℹ️  建议在正式生产环境使用 CI 流水线 (Recommend using CI pipeline for production)"
                return 0
            fi
            log_error "[SAFETY] Release tier cannot be executed locally. Use CI pipeline only."
            log_error "[SAFETY] To run a test release, use: MSP_RELEASE_TIER=preflight"
            return 1
        fi
        log_info "[SAFETY] ✓ CI environment detected (CI=${CI})"
    fi

    return 0
}

# ============================================================================
# Safety Check 2: Require Clean Git State
# ============================================================================
msp_safety_require_clean_git() {
    local tier="${MSP_RELEASE_TIER:-preflight}"

    if [[ "$tier" == "release" || "$tier" == "production" ]]; then
        log_info "[SAFETY] Checking Git working directory cleanliness..."

        if ! git diff --quiet 2>/dev/null; then
            log_error "[SAFETY] Release tier requires a clean working directory."
            log_error "[SAFETY] You have unstaged changes. Commit or stash them before release."
            git status --short
            return 1
        fi

        if ! git diff --cached --quiet 2>/dev/null; then
            log_error "[SAFETY] Release tier requires a clean working directory."
            log_error "[SAFETY] You have staged changes. Commit them before release."
            git status --short
            return 1
        fi

        log_info "[SAFETY] ✓ Git working directory is clean"
    fi

    return 0
}

# ============================================================================
# Safety Check 3: Validate Version Format
# ============================================================================
msp_safety_validate_version() {
    local version="$1"
    local tier="${MSP_RELEASE_TIER:-preflight}"

    if [[ "$tier" == "release" || "$tier" == "production" ]]; then
        log_info "[SAFETY] Validating version format: $version"

        # Check for valid release version patterns
        # Valid: X.Y.Z, X.Y.Z-hotfix.N, X.Y.Z-rc.N
        # Invalid: 0.0.*, *-preflight*, versions missing components

        # Reject 0.0.* versions
        if [[ "$version" =~ ^0\.0\. ]]; then
            log_error "[SAFETY] Invalid release version format: $version"
            log_error "[SAFETY] Release tier cannot use 0.0.* versions (development only)"
            return 1
        fi

        # Reject versions containing 'preflight', 'test', 'dev'
        if [[ "$version" =~ (preflight|test|dev) ]]; then
            log_error "[SAFETY] Invalid release version format: $version"
            log_error "[SAFETY] Release tier cannot use test/preflight/dev versions"
            return 1
        fi

        # Validate format: X.Y.Z or X.Y.Z-qualifier.N
        if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-z]+\.[0-9]+)?$ ]]; then
            log_error "[SAFETY] Invalid release version format: $version"
            log_error "[SAFETY] Expected format: X.Y.Z, X.Y.Z-hotfix.N, or X.Y.Z-rc.N"
            return 1
        fi

        log_info "[SAFETY] ✓ Version format is valid: $version"
    fi

    return 0
}

# ============================================================================
# Safety Check 4: Require Confirmation Unless --force
# ============================================================================
msp_safety_require_confirmation() {
    local version="$1"
    local force="${MSP_RELEASE_FORCE:-false}"
    local tier="${MSP_RELEASE_TIER:-preflight}"

    if [[ "$tier" == "release" || "$tier" == "production" ]]; then
        # Local release mode: Allow local execution when explicitly enabled
        if [[ "${MSP_ALLOW_LOCAL_RELEASE:-0}" == "1" ]]; then
            log_info "[SAFETY] ℹ️  本地发布模式已启用 (Local release mode enabled)"
            log_info "[SAFETY] ℹ️  建议在正式生产环境使用 CI 流水线 (Recommend using CI pipeline for production)"
            return 0
        fi
        
        if [[ "$force" != "true" ]]; then
            local current_branch
            current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"

            echo ""
            echo "═══════════════════════════════════════════════════════════"
            echo "⚠️  RELEASE CONFIRMATION REQUIRED"
            echo "═══════════════════════════════════════════════════════════"
            echo ""
            echo "You are about to perform a REAL RELEASE."
            echo ""
            echo "  Version: $version"
            echo "  Branch:  $current_branch"
            echo "  Tier:    $tier"
            echo ""
            echo "This will:"
            echo "  • Publish CocoaPods to trunk"
            echo "  • Create and push Git tags"
            echo "  • Push to remote repository"
            echo ""
            echo "═══════════════════════════════════════════════════════════"
            echo ""
            read -r -p "Continue with REAL RELEASE? (type 'yes' to confirm): " response
            echo ""

            if [[ "$response" != "yes" ]]; then
                log_error "[SAFETY] Release aborted by user"
                return 1
            fi

            log_info "[SAFETY] ✓ User confirmed release"
        else
            log_info "[SAFETY] ✓ Confirmation skipped (--force flag present)"
        fi
    fi

    return 0
}

# ============================================================================
# Safety Check 5: Validate Branch Name
# ============================================================================
msp_safety_validate_branch() {
    local tier="${MSP_RELEASE_TIER:-preflight}"

    if [[ "$tier" == "release" || "$tier" == "production" ]]; then
        # Local release mode: Allow local execution when explicitly enabled
        if [[ "${MSP_ALLOW_LOCAL_RELEASE:-0}" == "1" ]]; then
            log_info "[SAFETY] ℹ️  本地发布模式已启用 (Local release mode enabled)"
            log_info "[SAFETY] ℹ️  建议在正式生产环境使用 CI 流水线 (Recommend using CI pipeline for production)"
            return 0
        fi
        
        local current_branch
        current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"

        if [[ -z "$current_branch" ]]; then
            log_error "[SAFETY] Cannot determine current Git branch"
            return 1
        fi

        log_info "[SAFETY] Validating branch: $current_branch"

        # Allowed branches: release/*, main, master
        if [[ "$current_branch" =~ ^release/ ]] || \
           [[ "$current_branch" == "main" ]] || \
           [[ "$current_branch" == "master" ]]; then
            log_info "[SAFETY] ✓ Branch '$current_branch' is allowed for release"
        else
            log_error "[SAFETY] Release tier cannot run on branch '$current_branch'"
            log_error "[SAFETY] Allowed branches: release/*, main, master"
            return 1
        fi
    fi

    return 0
}

# ============================================================================
# Safety Check 6: Require Changelog
# ============================================================================
msp_safety_require_changelog() {
    local tier="${MSP_RELEASE_TIER:-preflight}"
    local repo_root="${ROOT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"

    if [[ "$tier" == "release" || "$tier" == "production" ]]; then
        local changelog_file="$repo_root/release.md"

        log_info "[SAFETY] Checking for changelog: release.md"

        if [[ ! -f "$changelog_file" ]]; then
            log_error "[SAFETY] Missing release.md"
            log_error "[SAFETY] A release cannot proceed without documented changes"
            log_error "[SAFETY] Create release.md with a '## Changes' section"
            return 1
        fi

        # Check if file has content under "## Changes"
        if ! grep -q "## Changes" "$changelog_file" 2>/dev/null; then
            log_error "[SAFETY] release.md exists but does not contain '## Changes' section"
            log_error "[SAFETY] Document your changes before proceeding with release"
            return 1
        fi

        # Check if there's actual content after "## Changes"
        local changes_content
        changes_content=$(sed -n '/## Changes/,/^##/p' "$changelog_file" | tail -n +2 | sed '$d' | grep -v '^[[:space:]]*$' | head -1)

        if [[ -z "$changes_content" ]]; then
            log_error "[SAFETY] release.md '## Changes' section is empty"
            log_error "[SAFETY] Document your changes before proceeding with release"
            return 1
        fi

        log_info "[SAFETY] ✓ Changelog present and contains changes"
    fi

    return 0
}

# ============================================================================
# Master Safety Check Function
# ============================================================================
msp_release_safety_check() {
    local version="$1"
    local tier="${MSP_RELEASE_TIER:-preflight}"

    log_info "[SAFETY] Running safety checks for tier: $tier"

    # Skip all safety checks for preflight tier
    if [[ "$tier" != "release" && "$tier" != "production" ]]; then
        log_info "[SAFETY] Preflight tier - skipping production safety checks"
        return 0
    fi

    log_info "[SAFETY] ══════════════════════════════════════════════════════"
    log_info "[SAFETY] RELEASE TIER SAFETY CHECKS"
    log_info "[SAFETY] ══════════════════════════════════════════════════════"

    # Run all safety checks in sequence
    if ! msp_safety_require_ci_for_release; then
        return 1
    fi

    if ! msp_safety_require_clean_git; then
        return 1
    fi

    if ! msp_safety_validate_version "$version"; then
        return 1
    fi

    if ! msp_safety_validate_branch; then
        return 1
    fi

    if ! msp_safety_require_changelog; then
        return 1
    fi

    if ! msp_safety_require_confirmation "$version"; then
        return 1
    fi

    log_info "[SAFETY] ══════════════════════════════════════════════════════"
    log_success "[SAFETY] ✅ All safety checks passed"
    log_info "[SAFETY] ══════════════════════════════════════════════════════"

    return 0
}

# Export functions
export -f msp_safety_require_ci_for_release \
         msp_safety_require_clean_git \
         msp_safety_validate_version \
         msp_safety_require_confirmation \
         msp_safety_validate_branch \
         msp_safety_require_changelog \
         msp_release_safety_check 2>/dev/null || true
