#!/usr/bin/env bash
# ============================================================================
# Release Utilities Module
# ============================================================================
# Module: release_utils.sh
# Purpose: Release-related utility functions (auth checks, commits, workspace, binaries)
# Extracted from: publish.sh
#
# Functions:
#   - unified_github_cli_auth_check: Verify GitHub CLI authentication
#   - commit_release_changes: Commit release artifacts to git
#   - ensure_release_workspace: Ensure CocoaPods workspace exists
#   - rebuild_release_binaries: Rebuild all binary XCFrameworks
#
# Dependencies:
#   - Logging functions (log::info, log::error, log::success, log::step, log::warn)
#   - ROOT_DIR environment variable
#   - VERSION environment variable (for commit messages)
#
# Environment Variables:
#   - ROOT_DIR: Project root directory
#   - DRY_RUN: If "true", skip actual operations
#   - VERSION: Release version for commit messages
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_RELEASE_UTILS_SOURCED:-}" ]] && return 0
readonly _RELEASE_UTILS_SOURCED=1

# ============================================================================
# GitHub CLI Authentication Check
# ============================================================================
# Unified authentication check called ONCE before parallel adapter release.
# Verifies gh auth status is valid before spawning subprocesses, ensuring
# all parallel processes can access GitHub Release APIs.
#
# Returns:
#   0 if authenticated
#   1 if authentication failed
# ============================================================================
unified_github_cli_auth_check() {
    log::step "PODS" "Verifying GitHub CLI authentication (pre-flight check)"

    # Check if gh is installed
    if ! command -v gh &>/dev/null; then
        log::error "PODS" "GitHub CLI (gh) not found"
        log::error "PODS" "Please install GitHub CLI: brew install gh"
        log::error "PODS" "Or visit: https://cli.github.com"
        return 1
    fi

    # Perform authentication check with detailed output
    local auth_check_output
    auth_check_output=$(mktemp)

    log::info "PODS" "Checking GitHub CLI authentication..."

    if timeout 30 gh auth status &>"$auth_check_output"; then
        log::success "PODS" "GitHub CLI authenticated"

        # Show account info if available
        if grep -q "Logged in to github.com" "$auth_check_output"; then
            local account
            account=$(grep "Logged in" "$auth_check_output" 2>/dev/null | head -1 | sed -n 's/.*account \([^ ]*\).*/\1/p')
            if [[ -n "$account" ]]; then
                log::info "PODS" "  Account: $account"
            fi

            # Show token scopes
            if grep -q "Token scopes:" "$auth_check_output"; then
                local scopes
                scopes=$(grep "Token scopes:" "$auth_check_output" 2>/dev/null | sed "s/.*Token scopes: //")
                log::info "PODS" "  Scopes: $scopes"
            fi
        fi

        rm -f "$auth_check_output"
        return 0
    else
        local exit_code=$?
        log::error "PODS" "GitHub CLI authentication failed (exit code: $exit_code)"
        log::error "PODS" ""
        log::error "PODS" "Common solutions:"
        log::error "PODS" "  1. Re-authenticate: gh auth login"
        log::error "PODS" "  2. Refresh token: gh auth refresh -h github.com"
        log::error "PODS" "  3. Check token status: gh auth status"
        log::error "PODS" "  4. Verify scopes include: 'repo', 'workflow'"

        rm -f "$auth_check_output"

        # Optional: Attempt automatic refresh (1 retry)
        log::warn "PODS" "Attempting to refresh token..."
        if gh auth refresh -h github.com &>/dev/null; then
            log::info "PODS" "Token refreshed, rechecking..."
            if timeout 30 gh auth status &>/dev/null; then
                log::success "PODS" "Authentication successful after refresh"
                return 0
            fi
        fi

        return 1
    fi
}

# ============================================================================
# Commit Release Changes
# ============================================================================
# Commit all changes to release branch (podspecs, generated files)
# ============================================================================
commit_release_changes() {
    log::step "PODS" "Committing remaining release artifacts (podspecs, generated files)"

    if [[ "$DRY_RUN" == "true" ]]; then
        log::info "PODS" "DRY RUN: Would commit remaining changes"
        return 0
    fi

    # Add generated release podspecs
    if [[ -d "Build/ReleasePodspecs" ]]; then
        git add Build/ReleasePodspecs/*.podspec 2>/dev/null || true
    fi

    # Add Package.swift if SPM is enabled
    if [[ -f "Package.swift" ]]; then
        git add Package.swift 2>/dev/null || true
    fi

    # Check if there are changes to commit
    if git diff --cached --quiet; then
        log::info "PODS" "No additional artifacts to commit"
        log::info "PODS" "   (Version number updates were committed separately per-pod)"
        return 0
    fi

    # Commit remaining artifacts
    git commit -m "chore(release): add generated artifacts for version ${VERSION}

- Generated release podspecs for binary distribution
- Updated Package.swift for SPM (if enabled)
- Part of release ${VERSION} finalization

Note: Version number updates were committed separately after each pod publish."

    log::success "PODS" "Committed remaining release artifacts"
}

# ============================================================================
# Ensure Release Workspace
# ============================================================================
# Ensure CocoaPods workspace exists before release flow (needed for NovaCore rebuild)
# ============================================================================
ensure_release_workspace() {
    local workspace="$ROOT_DIR/msp-ios-sdk.xcworkspace"

    if [[ -L "$workspace" || -d "$workspace" ]]; then
        log::info "PODS" "Workspace already exists: $workspace"
        return 0
    fi

    local switch_script="$ROOT_DIR/Scripts/switch-target.sh"
    if [[ ! -x "$switch_script" ]]; then
        log::error "PODS" "switch-target.sh not found or not executable: $switch_script"
        return 1
    fi

    log::step "PODS" "Workspace missing; preparing via pods-release"
    if "$switch_script" pods-release; then
        log::success "PODS" "Workspace prepared via pods-release"
        return 0
    fi

    log::error "PODS" "Failed to prepare workspace via pods-release"
    return 1
}

# ============================================================================
# Rebuild Release Binaries
# ============================================================================
# Force rebuild of all binary XCFrameworks before publishing.
# This guarantees the published binaries match the current source, even on resume.
# ============================================================================
rebuild_release_binaries() {
    if [[ "${DRY_RUN:-true}" == "true" ]]; then
        log::info "PODS" "DRY RUN: Skipping binary rebuild (no binaries will be published)"
        return 0
    fi

    log_section "Rebuilding binary XCFrameworks (forced for release)"

    local build_core_script="$ROOT_DIR/Scripts/xcframeworks/build-core.sh"
    if [[ ! -x "$build_core_script" ]]; then
        log::error "PODS" "build-core.sh not found or not executable: $build_core_script"
        return 1
    fi
    log::step "PODS" "Building core XCFrameworks"
    if ! bash "$build_core_script"; then
        log::error "PODS" "Core XCFramework build failed"
        return 1
    fi

    local build_adapters_script="$ROOT_DIR/Scripts/xcframeworks/build-adapters.sh"
    if [[ ! -x "$build_adapters_script" ]]; then
        log::error "PODS" "build-adapters.sh not found or not executable: $build_adapters_script"
        return 1
    fi
    log::step "PODS" "Building adapter XCFrameworks"
    if ! bash "$build_adapters_script"; then
        log::error "PODS" "Adapter XCFramework build script failed"
        return 1
    fi

    # Verify required binary XCFrameworks exist after rebuild
    local required=(
        "MSPiOSCore"
        "MSPSharedLibraries"
        "MSPGoogleAdsTypes"
        "MSPPrebidAdapter"
        "MSPGoogleAdapter"
        "MSPFacebookAdapter"
        "MSPAmazonAdapter"
        "MSPMolocoAdapter"
        "MSPLiftoffAdapter"
        "MSPNovaAdapter"
        "MSPCore"
    )
    local missing=0
    for pod in "${required[@]}"; do
        local path="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks/${pod}.xcframework"
        if [[ ! -d "$path" ]]; then
            log::error "PODS" "Missing rebuilt XCFramework: $path"
            missing=1
        fi
    done

    # Ensure ReleaseArtifacts/Binary/MSPNovaAdapter.xcframework is refreshed for podspec generation
    local nova_build="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks/MSPNovaAdapter.xcframework"
    local nova_binary="$ROOT_DIR/Build/ReleaseArtifacts/Binary/MSPNovaAdapter.xcframework"
    if [[ -d "$nova_build" ]]; then
        rm -rf "$nova_binary"
        if cp -R "$nova_build" "$nova_binary"; then
            log::success "PODS" "Updated ReleaseArtifacts/Binary/MSPNovaAdapter.xcframework"
        else
            log::error "PODS" "Failed to copy MSPNovaAdapter.xcframework to ReleaseArtifacts/Binary"
            missing=1
        fi
    else
        log::error "PODS" "MSPNovaAdapter.xcframework not found at: $nova_build"
        missing=1
    fi

    if [[ "$missing" -ne 0 ]]; then
        log::error "PODS" "Binary rebuild verification failed"
        return 1
    fi

    log::success "PODS" "All binary XCFrameworks rebuilt successfully"
    return 0
}

# ============================================================================
# Export Functions
# ============================================================================

export -f unified_github_cli_auth_check 2>/dev/null || true
export -f commit_release_changes 2>/dev/null || true
export -f ensure_release_workspace 2>/dev/null || true
export -f rebuild_release_binaries 2>/dev/null || true
