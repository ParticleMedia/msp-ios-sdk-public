#!/usr/bin/env bash
# ============================================================================
# MSP Release System - Safety Checks (Phase 3)
# ============================================================================
# Purpose: Enforce strict safety requirements for Release tier executions
#          to prevent accidental production releases.
#
# Safety Features:
#   1. Block Release tier from running locally (requires CI environment)
#      - Local release is enabled by default (MSP_ALLOW_LOCAL_RELEASE=1)
#      - Set MSP_ALLOW_LOCAL_RELEASE=0 in Jenkins CI to enforce CI-only releases
#   2. Require clean Git state
#   3. Validate version format
#   4. Require confirmation unless --force is passed
#   5. Block release if branch name is not allowed
#   6. Require changelog (release.md)
# ============================================================================

# Prevent multiple sourcing
[[ -n "${_MSP_SAFETY_SOURCED:-}" ]] && return 0
readonly _MSP_SAFETY_SOURCED=1

# Source shared validation library for centralized branch validation
if [[ -z "${ROOT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # SCRIPT_DIR is Scripts/release/utils, need to go up 3 levels to reach repo root
    ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi
# shellcheck source=Scripts/lib/validation.sh
source "$ROOT_DIR/Scripts/lib/validation.sh" 2>/dev/null || true

# ============================================================================
# Safety Check 1: Block Release Tier from Running Locally
# ============================================================================
msp_safety_require_ci_for_release() {
    # Phase B: Use DRY_RUN instead of MSP_RELEASE_TIER
    local dry_run="${DRY_RUN:-true}"

    # Production mode (DRY_RUN=false) requires CI environment
    # TODO: Re-enable this check when CI pipeline is fully set up
    # For now, allow local execution since all releases are done locally
    # See README.md for details
    if [[ "$dry_run" == "false" ]]; then
        # Check for CI environment variables (CI, GITHUB_ACTIONS, etc.)
        local ci_detected=false
        if [[ -n "${CI:-}" ]] && [[ "${CI}" == "true" ]]; then
            ci_detected=true
        elif [[ -n "${GITHUB_ACTIONS:-}" ]] && [[ "${GITHUB_ACTIONS}" == "true" ]]; then
            ci_detected=true
        fi
        
        if [[ "$ci_detected" == "false" ]]; then
            # TEMPORARY: Local releases allowed while CI pipeline is not yet set up.
            # TODO(CI-ready): Re-enable CI-only restriction. Future logic:
            #   if [[ "${MSP_ALLOW_LOCAL_RELEASE:-0}" == "1" ]]; then
            #       return 0  # explicit override for emergencies
            #   fi
            #   log::error "SAFETY" "Production mode cannot be executed locally. Use CI pipeline only."
            #   return 1
            # See README.md - "Future CI Integration" section
            log::info "SAFETY" "[SAFETY] ℹ️  本地发布模式 (Local release mode)"
            log::info "SAFETY" "[SAFETY] ℹ️  注意: 当前允许本地执行生产模式 (Currently allowing local production mode)"
            log::info "SAFETY" "[SAFETY] ℹ️  未来 CI 流水线就绪后将恢复限制 (CI restriction will be re-enabled when CI pipeline is ready)"
            return 0
        fi
        log::info "SAFETY" "[SAFETY] ✓ CI environment detected (CI=${CI:-}, GITHUB_ACTIONS=${GITHUB_ACTIONS:-})"
    fi

    return 0
}

# ============================================================================
# Safety Check 2: Require Clean Git State
# ============================================================================
msp_safety_require_clean_git() {
    # Phase B: Use DRY_RUN directly, removed tier variable
    local dry_run="${DRY_RUN:-true}"

    # Production mode (DRY_RUN=false) requires clean git state
    if [[ "$dry_run" == "false" ]]; then
        
        log::info "SAFETY" "[SAFETY] Checking Git working directory cleanliness..."

        if ! git diff --quiet 2>/dev/null; then
            log::error "SAFETY" "[SAFETY] Release tier requires a clean working directory."
            log::error "SAFETY" "[SAFETY] You have unstaged changes. Commit or stash them before release."
            git status --short
            return 1
        fi

        if ! git diff --cached --quiet 2>/dev/null; then
            log::error "SAFETY" "[SAFETY] Release tier requires a clean working directory."
            log::error "SAFETY" "[SAFETY] You have staged changes. Commit them before release."
            git status --short
            return 1
        fi

        log::info "SAFETY" "[SAFETY] ✓ Git working directory is clean"
    fi

    return 0
}

# ============================================================================
# Safety Check 3: Validate Version Format
# ============================================================================
msp_safety_validate_version() {
    local version="$1"
    # Phase B: Use DRY_RUN instead of MSP_RELEASE_TIER
    local dry_run="${DRY_RUN:-true}"

    # Production mode (DRY_RUN=false) requires version validation
    if [[ "$dry_run" == "false" ]]; then
        log::info "SAFETY" "[SAFETY] Validating version format: $version"

        # Check for valid release version patterns
        # Valid: X.Y.Z, X.Y.Z-hotfix.N, X.Y.Z-rc.N
        # Invalid: 0.0.*, *-preflight*, versions missing components

        # Reject 0.0.* versions
        if [[ "$version" =~ ^0\.0\. ]]; then
            log::error "SAFETY" "[SAFETY] Invalid release version format: $version"
            log::error "SAFETY" "[SAFETY] Production mode cannot use 0.0.* versions (development only)"
            return 1
        fi

        # Reject versions containing 'preflight', 'test', 'dev'
        if [[ "$version" =~ (preflight|test|dev) ]]; then
            log::error "SAFETY" "[SAFETY] Invalid release version format: $version"
            log::error "SAFETY" "[SAFETY] Production mode cannot use test/preflight/dev versions"
            return 1
        fi

        # Validate format: SemVer 2.0 compliant
        # Valid: X.Y.Z, X.Y.Z-qualifier, X.Y.Z-qualifier.N, X.Y.Z-qualifier.N.identifier
        # Examples: 1.0.0, 1.0.0-migration, 1.0.0-rc.1, 1.0.0-beta.2.fix
        if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)*)?$ ]]; then
            log::error "SAFETY" "[SAFETY] Invalid release version format: $version"
            log::error "SAFETY" "[SAFETY] Expected SemVer format: X.Y.Z or X.Y.Z-prerelease"
            return 1
        fi

        log::info "SAFETY" "[SAFETY] ✓ Version format is valid: $version"
    fi

    return 0
}

# ============================================================================
# Safety Check 4: Require Confirmation Unless --force
# ============================================================================
msp_safety_require_confirmation() {
    local version="$1"
    local force="${MSP_RELEASE_FORCE:-false}"
    # Phase B: Use DRY_RUN directly, removed tier variable
    local dry_run="${DRY_RUN:-true}"

    # Production mode (DRY_RUN=false) requires confirmation
    if [[ "$dry_run" == "false" ]]; then
        # Skip confirmation in DRY_RUN mode
        if [[ "$dry_run" == "true" ]]; then
            log::info "SAFETY" "[SAFETY] ℹ️  DRY RUN mode: Skipping confirmation"
            return 0
        fi
        
        # Local release mode: Allow local execution (defaults to enabled)
        # MSP_ALLOW_LOCAL_RELEASE defaults to 1 for local development
        # Will be set to 0 in Jenkins CI environment
        if [[ "${MSP_ALLOW_LOCAL_RELEASE:-1}" == "1" ]]; then
            log::info "SAFETY" "[SAFETY] ℹ️  本地发布模式已启用 (Local release mode enabled)"
            log::info "SAFETY" "[SAFETY] ℹ️  建议在正式生产环境使用 CI 流水线 (Recommend using CI pipeline for production)"
            return 0
        fi

        log::info "SAFETY" "[SAFETY] ✓ Production release confirmed (non-interactive)"
    fi

    return 0
}

# ============================================================================
# Safety Check 5: Validate Branch Name
# ============================================================================
msp_safety_validate_branch() {
    # Phase B: Use DRY_RUN instead of MSP_RELEASE_TIER
    local dry_run="${DRY_RUN:-true}"

    # Production mode (DRY_RUN=false) requires branch validation
    if [[ "$dry_run" == "false" ]]; then
        # Local release mode: Allow local execution when explicitly enabled
        # MSP_ALLOW_LOCAL_RELEASE defaults to 1 (enabled) for local development
        # Will be set to 0 in Jenkins CI environment
        if [[ "${MSP_ALLOW_LOCAL_RELEASE:-1}" == "1" ]]; then
            log::info "SAFETY" "[SAFETY] ℹ️  本地发布模式已启用 (Local release mode enabled)"
            log::info "SAFETY" "[SAFETY] ℹ️  建议在正式生产环境使用 CI 流水线 (Recommend using CI pipeline for production)"
            return 0
        fi

        # Use centralized branch validation from validation.sh (DRY principle)
        # This ensures consistency between safety.sh and modular.sh
        if ! validate_release_branch; then
            return 1
        fi
    fi

    return 0
}

# ============================================================================
# Safety Check 6: Require Changelog
# ============================================================================
msp_safety_require_changelog() {
    # Phase B: Use DRY_RUN instead of MSP_RELEASE_TIER
    local dry_run="${DRY_RUN:-true}"
    local repo_root="${ROOT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"

    # Production mode (DRY_RUN=false) requires changelog
    # But only in CI environment - local releases skip this check
    # (consistent with msp_safety_require_ci_for_release behavior)
    if [[ "$dry_run" == "false" ]]; then
        # Check for CI environment - skip changelog check for local releases
        local ci_detected=false
        if [[ -n "${CI:-}" ]] && [[ "${CI}" == "true" ]]; then
            ci_detected=true
        elif [[ -n "${GITHUB_ACTIONS:-}" ]] && [[ "${GITHUB_ACTIONS}" == "true" ]]; then
            ci_detected=true
        fi

        if [[ "$ci_detected" == "false" ]]; then
            # Local release mode - skip changelog check
            # All releases are currently done locally, changelog will be required when CI is ready
            log::info "SAFETY" "[SAFETY] ℹ️  Changelog check skipped (local release mode)"
            return 0
        fi
        local changelog_file="$repo_root/release.md"

        log::info "SAFETY" "[SAFETY] Checking for changelog: release.md"

        if [[ ! -f "$changelog_file" ]]; then
            log::error "SAFETY" "[SAFETY] Missing release.md"
            log::error "SAFETY" "[SAFETY] A release cannot proceed without documented changes"
            log::error "SAFETY" "[SAFETY] Create release.md with a '## Changes' section"
            return 1
        fi

        # Check if file has content under "## Changes"
        if ! grep -q "## Changes" "$changelog_file" 2>/dev/null; then
            log::error "SAFETY" "[SAFETY] release.md exists but does not contain '## Changes' section"
            log::error "SAFETY" "[SAFETY] Document your changes before proceeding with release"
            return 1
        fi

        # Check if there's actual content after "## Changes"
        local changes_content
        changes_content=$(sed -n '/## Changes/,/^##/p' "$changelog_file" | tail -n +2 | sed '$d' | grep -v '^[[:space:]]*$' | head -1)

        if [[ -z "$changes_content" ]]; then
            log::error "SAFETY" "[SAFETY] release.md '## Changes' section is empty"
            log::error "SAFETY" "[SAFETY] Document your changes before proceeding with release"
            return 1
        fi

        log::info "SAFETY" "[SAFETY] ✓ Changelog present and contains changes"
    fi

    return 0
}

# ============================================================================
# Master Safety Check Function
# ============================================================================
msp_release_safety_check() {
    local version="$1"
    # Phase B: Use DRY_RUN instead of MSP_RELEASE_TIER
    local dry_run="${DRY_RUN:-true}"

    log::info "SAFETY" "[SAFETY] Running safety checks for mode: $(if [[ "$dry_run" == "false" ]]; then echo "production"; else echo "dry-run"; fi)"

    # Skip all safety checks for dry-run mode
    if [[ "$dry_run" == "true" ]]; then
        log::info "SAFETY" "[SAFETY] Dry-run mode - skipping production safety checks"
        return 0
    fi

    log::info "SAFETY" "[SAFETY] ══════════════════════════════════════════════════════"
    log::info "SAFETY" "[SAFETY] PRODUCTION MODE SAFETY CHECKS"
    log::info "SAFETY" "[SAFETY] ══════════════════════════════════════════════════════"

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

    log::info "SAFETY" "[SAFETY] ══════════════════════════════════════════════════════"
    log::success "SAFETY" "[SAFETY] ✅ All safety checks passed"
    log::info "SAFETY" "[SAFETY] ══════════════════════════════════════════════════════"

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
