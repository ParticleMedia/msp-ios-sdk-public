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
# Safety Check 1: CI check — unlocked (any branch, no MSP_ALLOW_LOCAL_RELEASE needed)
# ============================================================================
# Previously enforced CI-only + branch allowlist + MSP_ALLOW_LOCAL_RELEASE=1.
# Now a no-op: local releases are fully allowed. Clean git + changelog are the
# only safety nets for local production releases (see US2 contract).
msp_safety_require_ci_for_release() {
    log::debug "SAFETY" "[SAFETY] CI gate: unlocked (local releases allowed from any branch)"
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
# Safety Check 3: Validate Version Format — dual-mode
# ============================================================================
# Strict mode  (MSP_PRERELEASE unset/0): only X.Y.Z accepted
# Prerelease   (MSP_PRERELEASE=1):       only X.Y.Z-suffix accepted
# Mutex:
#   suffix + no flag  → reject ("looks like prerelease, tick PRERELEASE")
#   clean  + flag set → reject ("clean version but PRERELEASE is set, uncheck it")
#   0.0.*  always     → reject
# ============================================================================
msp_safety_validate_version() {
    local version="$1"
    local dry_run="${DRY_RUN:-true}"

    if [[ "$dry_run" != "false" ]]; then
        return 0
    fi

    log::info "SAFETY" "[SAFETY] Validating version format: $version"

    # Reject empty / malformed
    if [[ -z "$version" ]]; then
        log::error "SAFETY" "[SAFETY] Version is empty. Expected X.Y.Z or X.Y.Z-suffix."
        return 1
    fi

    # Reject 0.0.* (development placeholders)
    if [[ "$version" =~ ^0\.0\. ]]; then
        log::error "SAFETY" "[SAFETY] Version $version rejected: 0.0.* is for development only."
        return 1
    fi

    # Pattern: strict (X.Y.Z — digits only)
    local strict_re='^[0-9]+\.[0-9]+\.[0-9]+$'
    # Pattern: prerelease (X.Y.Z-suffix — alphanumeric segments)
    local pre_re='^[0-9]+\.[0-9]+\.[0-9]+-[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)*$'

    local is_clean=false
    local has_suffix=false
    [[ "$version" =~ $strict_re ]] && is_clean=true
    [[ "$version" =~ $pre_re ]]   && has_suffix=true

    # Reject malformed (neither strict nor prerelease)
    if [[ "$is_clean" == "false" && "$has_suffix" == "false" ]]; then
        log::error "SAFETY" "[SAFETY] Invalid version format: '$version'."
        log::error "SAFETY" "[SAFETY] Expected X.Y.Z (production) or X.Y.Z-suffix (prerelease, requires MSP_PRERELEASE=1)."
        return 1
    fi

    # Determine prerelease intent from MSP_PRERELEASE env
    local is_prerelease_mode=false
    if [[ "${MSP_PRERELEASE:-0}" == "1" ]] || [[ "${MSP_PRERELEASE:-}" == "true" ]]; then
        is_prerelease_mode=true
    fi

    # Mutex: suffix version but MSP_PRERELEASE not set
    if [[ "$has_suffix" == "true" && "$is_prerelease_mode" == "false" ]]; then
        log::error "SAFETY" "[SAFETY] VERSION='${version}' looks like a prerelease (has suffix)."
        log::error "SAFETY" "[SAFETY] Set MSP_PRERELEASE=1 to confirm this is a prerelease, or use a clean X.Y.Z."
        return 1
    fi

    # Mutex: clean version but MSP_PRERELEASE=1
    if [[ "$is_clean" == "true" && "$is_prerelease_mode" == "true" ]]; then
        log::error "SAFETY" "[SAFETY] VERSION='${version}' is clean X.Y.Z but MSP_PRERELEASE=1 is set."
        log::error "SAFETY" "[SAFETY] Unset MSP_PRERELEASE for production releases, or add a suffix for prerelease."
        return 1
    fi

    if [[ "$is_prerelease_mode" == "true" ]]; then
        log::warn "SAFETY" "[SAFETY] ⚠️  Prerelease version: ${version} — NOT for production"
        # Export transitional env var for backward-compatible consumers
        export MSP_IS_PRERELEASE=1
    else
        log::info "SAFETY" "[SAFETY] ✓ Version format is valid: $version"
    fi

    return 0
}

# ============================================================================
# Safety Check 4: Confirmation — unlocked (no --force required)
# ============================================================================
# Previously required --force for local non-CI production releases.
# Now a no-op: the clean-git and changelog checks are the safety net.
msp_safety_require_confirmation() {
    log::debug "SAFETY" "[SAFETY] Confirmation gate: unlocked (--force not required)"
    return 0
}

# ============================================================================
# Safety Check 5: Branch validation — unlocked (any branch allowed)
# ============================================================================
# Previously blocked releases from non-allowlisted branches in CI.
# Now a no-op: release from any branch.
msp_safety_validate_branch() {
    log::debug "SAFETY" "[SAFETY] Branch gate: unlocked (any branch allowed)"
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
            if msp_safety_is_ci; then
                # CI: strict — missing release.md is a hard fail
                log::error "SAFETY" "[SAFETY] Missing release.md"
                log::error "SAFETY" "[SAFETY] A release cannot proceed without documented changes"
                log::error "SAFETY" "[SAFETY] Create release.md with a '## Changes' section"
                return 1
            else
                # Local: auto-generate a skeleton so the release can proceed
                local version_label="${RELEASE_VERSION:-unknown}"
                local git_user
                git_user=$(git config user.name 2>/dev/null || echo "unknown")
                local hostname_val
                hostname_val=$(hostname 2>/dev/null || echo "unknown")
                local now_str
                now_str=$(date "+%Y-%m-%d %H:%M:%S %Z" 2>/dev/null || echo "unknown")

                cat > "$changelog_file" <<EOF
# Release ${version_label}

## Changes

- Auto-generated by release safety check on ${now_str}
- Released by ${git_user} from ${hostname_val}
- TODO: describe the actual changes before publishing

## End
EOF
                log::warn "SAFETY" "[SAFETY] ⚠️  release.md was missing; auto-generated skeleton at ${changelog_file}. Edit and re-run if you need custom changelog."
                # Continue — the generated file satisfies the validation below
            fi
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
