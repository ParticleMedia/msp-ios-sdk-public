#!/usr/bin/env bash
# ============================================================================
# MSP Release System - Safety Checks (Phase 3)
# ============================================================================
# Purpose: Enforce strict safety requirements for Release tier executions
#          to prevent accidental production releases.
#
# Safety Features:
#   1. Prefer CI for production releases
#   2. Allow local production only as an explicit emergency override
#   3. Require clean Git state
#   4. Validate version format
#   5. Require --force for local emergency overrides
#   6. Block release if branch name is not allowed
#   7. Require changelog (release.md)
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

# Helper: detect CI execution
msp_safety_is_ci() {
    [[ "${CI:-}" == "true" ]] || [[ "${GITHUB_ACTIONS:-}" == "true" ]]
}

# Helper: current branch name
msp_safety_current_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null || echo ""
}

# Helper: local emergency release branch allowlist
msp_safety_is_local_override_branch_allowed() {
    local branch="$1"
    [[ "$branch" == "develop" ]] || \
    [[ "$branch" == "main" ]] || \
    [[ "$branch" == "master" ]] || \
    [[ "$branch" =~ ^hotfix/ ]]
}

# ============================================================================
# Safety Check 1: CI default, local production requires explicit override
# ============================================================================
msp_safety_require_ci_for_release() {
    local dry_run="${DRY_RUN:-true}"
    local current_branch

    if [[ "$dry_run" != "false" ]]; then
        return 0
    fi

    if msp_safety_is_ci; then
        log::info "SAFETY" "[SAFETY] ✓ CI environment detected (CI=${CI:-}, GITHUB_ACTIONS=${GITHUB_ACTIONS:-})"
        return 0
    fi

    if [[ "${MSP_ALLOW_LOCAL_RELEASE:-0}" != "1" ]]; then
        log::error "SAFETY" "[SAFETY] Production releases default to CI."
        log::error "SAFETY" "[SAFETY] For emergency local releases, set MSP_ALLOW_LOCAL_RELEASE=1 and pass --force."
        return 1
    fi

    current_branch="$(msp_safety_current_branch)"
    if [[ -z "$current_branch" ]]; then
        log::error "SAFETY" "[SAFETY] Cannot determine current Git branch for local production override"
        return 1
    fi

    if ! msp_safety_is_local_override_branch_allowed "$current_branch"; then
        log::error "SAFETY" "[SAFETY] Local production override is not allowed on branch '$current_branch'"
        log::error "SAFETY" "[SAFETY] Allowed local production branches: develop, main, master, hotfix/*"
        return 1
    fi

    log::warn "SAFETY" "[SAFETY] Emergency local production override enabled"
    log::warn "SAFETY" "[SAFETY] Branch '$current_branch' is allowed for local production override"
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
    local dry_run="${DRY_RUN:-true}"

    if [[ "$dry_run" != "false" ]]; then
        return 0
    fi

    if ! msp_safety_is_ci; then
        if [[ "$force" != "true" ]]; then
            log::error "SAFETY" "[SAFETY] Local production override requires --force"
            log::error "SAFETY" "[SAFETY] Example: MSP_ALLOW_LOCAL_RELEASE=1 ./Scripts/msp-release.sh --profile=production run <version> --force"
            return 1
        fi
        log::info "SAFETY" "[SAFETY] ✓ Local production override confirmed with --force"
        return 0
    fi

    log::info "SAFETY" "[SAFETY] ✓ Production release confirmed (non-interactive CI)"
    return 0
}

# ============================================================================
# Safety Check 5: Validate Branch Name
# ============================================================================
msp_safety_validate_branch() {
    local dry_run="${DRY_RUN:-true}"

    if [[ "$dry_run" != "false" ]]; then
        return 0
    fi

    if ! msp_safety_is_ci; then
        return 0
    fi

    # Use centralized branch validation from validation.sh (DRY principle)
    # This ensures consistency between safety.sh and modular.sh
    if ! validate_release_branch; then
        return 1
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

    # Resume mode: release.md was already verified in the original run.
    # git clean removes it from the workspace, so skip the check here.
    if [[ "${MSP_RESUME_MODE:-}" == "1" ]]; then
        log::info "SAFETY" "[SAFETY] Skipping changelog check in resume mode (already verified in original run)"
        return 0
    fi

    if [[ "$dry_run" == "false" ]]; then
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
         msp_safety_is_ci \
         msp_safety_current_branch \
         msp_safety_is_local_override_branch_allowed \
         msp_safety_require_clean_git \
         msp_safety_validate_version \
         msp_safety_require_confirmation \
         msp_safety_validate_branch \
         msp_safety_require_changelog \
         msp_release_safety_check 2>/dev/null || true
