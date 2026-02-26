#!/usr/bin/env bash
# ============================================================================
# MSP Release CLI - Commands Module
# ============================================================================
# Purpose: Provides utility command implementations for the release CLI
# Usage:   source Scripts/release/cli/commands.sh
#
# Exported Commands:
#   - msp_cmd_fix_public_tag    - Fix public remote tag mismatch
#   - msp_cmd_verify            - Run verification
#   - msp_cmd_verify_matrix     - Run verification matrix
#   - msp_cmd_rollback          - Show/execute rollback plan
#
# Dependencies:
#   - Scripts/lib/common.sh (log::* functions)
#   - Scripts/release/utils/git.sh (git utilities)
#   - Scripts/release/utils/github.sh (github utilities)
# ============================================================================

# Prevent multiple sourcing
[[ -n "${_MSP_CLI_COMMANDS_SOURCED:-}" ]] && return 0
readonly _MSP_CLI_COMMANDS_SOURCED=1

# Get script directory and ROOT_DIR
_COMMANDS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_COMMANDS_ROOT_DIR="$(cd "$_COMMANDS_SCRIPT_DIR/../../.." && pwd)"

# Source dependencies if not already loaded
if ! command -v log::info &>/dev/null; then
    if [[ -f "$_COMMANDS_ROOT_DIR/Scripts/lib/common.sh" ]]; then
        # shellcheck source=Scripts/lib/common.sh
        source "$_COMMANDS_ROOT_DIR/Scripts/lib/common.sh" 2>/dev/null || true
    fi
fi

# ============================================================================
# Fix Public Tag Command
# ============================================================================
# @description Fix public remote tag mismatch by force-pushing the correct tag
# @param $1 version - The tag version to fix
# @return 0 on success, 1 on error
msp_cmd_fix_public_tag() {
    local version="$1"
    local root_dir="${ROOT_DIR:-$_COMMANDS_ROOT_DIR}"

    if [[ -z "$version" ]]; then
        log::error "CMD" "Usage: msp-release.sh fix-public-tag <version>"
        return 1
    fi

    log::info "CMD" "════════════════════════════════════════════════════════════"
    log::info "CMD" "  Fixing public remote tag: $version"
    log::info "CMD" "════════════════════════════════════════════════════════════"

    # Check if local tag exists
    if ! git rev-parse "refs/tags/$version" >/dev/null 2>&1; then
        log::error "CMD" "Local tag $version not found"
        return 1
    fi

    local local_sha
    local_sha=$(git rev-parse "refs/tags/$version")

    log::info "CMD" "本地 tag SHA: $local_sha"

    # Check public remote tag
    local public_sha
    public_sha=$(git ls-remote --tags public "refs/tags/$version" 2>/dev/null | awk '{print $1}')

    if [[ -n "$public_sha" ]]; then
        log::info "CMD" "远程 tag SHA: $public_sha"

        if [[ "$local_sha" == "$public_sha" ]]; then
            log::success "CMD" "✅ Tag already correct on public remote"
            return 0
        fi

        log::warn "CMD" "Tag SHA 不匹配，将强制更新..."
    else
        log::warn "CMD" "Public remote 上没有找到 tag，将创建..."
    fi

    # Delete old tag
    log::info "CMD" "删除 public remote 上的旧 tag..."
    git push public ":refs/tags/$version" 2>/dev/null || true

    # Push new tag
    log::info "CMD" "推送正确的 tag 到 public remote..."
    local push_output
    push_output=$(git push public "refs/tags/$version" 2>&1)
    local push_exit_code=$?

    if [[ $push_exit_code -eq 0 ]]; then
        log::success "CMD" "✅ Tag 推送成功"

        # Verify
        sleep 2
        local new_public_sha
        new_public_sha=$(git ls-remote --tags public "refs/tags/$version" 2>/dev/null | awk '{print $1}')

        if [[ "$new_public_sha" == "$local_sha" ]]; then
            log::success "CMD" "✅ 验证成功: public remote tag 已更新"
            log::info "CMD" "Tag $version 现在指向正确的 commit: $local_sha"
        else
            log::error "CMD" "❌ 验证失败: tag SHA 仍不匹配"
            log::error "CMD" "期望: $local_sha"
            log::error "CMD" "实际: $new_public_sha"
            return 1
        fi
    else
        log::error "CMD" "❌ Tag 推送失败"
        log::error "CMD" ""
        log::error "CMD" "推送输出:"
        echo "$push_output"
        log::error "CMD" ""

        if echo "$push_output" | grep -qi "push protection"; then
            log::error "CMD" "GitHub Push Protection 阻止了推送"
            log::error "CMD" "请访问 GitHub Web 界面手动允许推送"
            log::error "CMD" "检查推送输出中的 URL 链接"
        fi

        return 1
    fi
}

# ============================================================================
# Verify Command
# ============================================================================
# @description Run verification for a release
# @param $1 version - The version to verify
# @return 0 on success, 1 on error
msp_cmd_verify() {
    local version="$1"
    local root_dir="${ROOT_DIR:-$_COMMANDS_ROOT_DIR}"

    if [[ "${MSP_RELEASE_MODE:-simple}" != "full" ]]; then
        log::info "CMD" "Skipping verify (simple mode — use --full for verification)"
        return 0
    fi

    if [[ -z "$version" ]]; then
        log::error "CMD" "Missing version for verify"
        log::info "CMD" "Usage: msp-release.sh verify <VERSION> [OPTIONS]"
        return 1
    fi

    # Load verify script
    local VERIFY_SCRIPT="$root_dir/Scripts/release/verify/verify.sh"
    if [[ ! -f "$VERIFY_SCRIPT" ]]; then
        log::error "CMD" "Verify script not found at $VERIFY_SCRIPT"
        return 1
    fi

    # shellcheck source=Scripts/release/verify/verify.sh
    source "$VERIFY_SCRIPT"

    if command -v log_title &>/dev/null; then
        log_title "Verifying Remote Release (Pods + SPM placeholder)"
    else
        log::info "CMD" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log::info "CMD" "Verifying Remote Release"
        log::info "CMD" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi

    if ! verify_main "$version"; then
        log::error "CMD" "Remote verification failed"
        return 1
    fi

    return 0
}

# ============================================================================
# Verify Matrix Command
# ============================================================================
# @description Run verification matrix
# @return 0 on success, 1 on error
msp_cmd_verify_matrix() {
    local root_dir="${ROOT_DIR:-$_COMMANDS_ROOT_DIR}"

    if [[ "${MSP_RELEASE_MODE:-simple}" != "full" ]]; then
        log::info "CMD" "Skipping verify-matrix (simple mode — use --full for verification)"
        return 0
    fi

    if command -v log_title &>/dev/null; then
        log_title "MSP Release Verification Matrix"
    else
        log::info "CMD" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log::info "CMD" "MSP Release Verification Matrix"
        log::info "CMD" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi

    # Get matrix script path
    local MATRIX_SCRIPT="$root_dir/Scripts/release/verify-matrix/matrix.sh"
    if [[ ! -f "$MATRIX_SCRIPT" ]]; then
        log::error "CMD" "Verification matrix script not found at $MATRIX_SCRIPT"
        return 1
    fi

    # Pass through environment variables
    export DRY_RUN="${DRY_RUN:-false}"
    export VERBOSE="${VERBOSE:-false}"
    export NO_ANSI="${NO_ANSI:-false}"

    # Run matrix script
    if bash "$MATRIX_SCRIPT"; then
        log::success "CMD" "Verification matrix completed successfully"
        return 0
    else
        log::error "CMD" "Verification matrix failed"
        return 1
    fi
}

# ============================================================================
# Rollback Command
# ============================================================================
# @description Show rollback plan and optionally execute it
# @param $1 force - Set to "1" to execute rollback
# @return 0 on success, 1 on error
msp_cmd_rollback() {
    local force="${1:-0}"
    local root_dir="${ROOT_DIR:-$_COMMANDS_ROOT_DIR}"

    if command -v log_title &>/dev/null; then
        log_title "MSP Release - Rollback Plan"
    else
        log::info "CMD" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log::info "CMD" "MSP Release - Rollback Plan"
        log::info "CMD" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi

    # Determine repo root and state file
    local state_file="${root_dir}/.msp-release-state.json"

    if [[ ! -f "$state_file" ]]; then
        log::error "CMD" "No .msp-release-state.json found. Nothing to roll back."
        log::info "CMD" "State file not found: $state_file"
        log::info "CMD" "Please run 'msp-release.sh run <VERSION>' first to start a release."
        return 1
    fi

    # Use jq (if available) to read the state
    if ! command -v jq >/dev/null 2>&1; then
        log::error "CMD" "jq is required to inspect rollback state."
        log::info "CMD" "Please install jq to use the rollback command."
        return 1
    fi

    # Extract relevant fields
    local version release_branch tag_created tag_name branch_pushed gh_release_created

    version="$(jq -r '.version // "unknown"' "$state_file" 2>/dev/null || echo "unknown")"
    release_branch="$(jq -r '.release_branch // "unknown"' "$state_file" 2>/dev/null || echo "unknown")"
    tag_created="$(jq -r '.git.tag_created // false' "$state_file" 2>/dev/null || echo "false")"
    tag_name="$(jq -r '.git.tag_name // empty' "$state_file" 2>/dev/null || echo "")"
    branch_pushed="$(jq -r '.git.release_branch_pushed // false' "$state_file" 2>/dev/null || echo "false")"
    gh_release_created="$(jq -r '.git.github_release_created // false' "$state_file" 2>/dev/null || echo "false")"

    # Print a clear rollback plan
    if command -v log_section &>/dev/null; then
        log_section "MSP Rollback Plan"
    fi
    if command -v ui_kv &>/dev/null; then
        ui_kv "Version" "${version}"
        ui_kv "Release branch" "${release_branch}"
        ui_kv "Git tag" "${tag_name:-<none>}"
    else
        log::info "CMD" "Version: ${version}"
        log::info "CMD" "Release branch: ${release_branch}"
        log::info "CMD" "Git tag: ${tag_name:-<none>}"
    fi
    echo ""

    if command -v log_section &>/dev/null; then
        log_section "Planned Actions"
    else
        log::info "CMD" "--- Planned Actions ---"
    fi

    if [[ "$tag_created" == "true" ]]; then
        if [[ -n "$tag_name" && "$tag_name" != "null" && "$tag_name" != "" ]]; then
            log::info "CMD" "- Would delete local git tag: ${tag_name}"
            log::info "CMD" "- Would delete remote git tag: ${tag_name}"
        else
            log::info "CMD" "- Git tag was created but tag name is not recorded"
            log::info "CMD" "- Would attempt to identify and delete tags for version: ${version}"
        fi
    else
        log::info "CMD" "- No git tag recorded as created"
    fi

    echo ""

    if [[ "$branch_pushed" == "true" ]]; then
        if [[ "$release_branch" != "unknown" && "$release_branch" != "null" && -n "$release_branch" ]]; then
            log::info "CMD" "- Would delete remote release branch: ${release_branch}"
        else
            log::info "CMD" "- Release branch was pushed but branch name is not recorded"
        fi
    else
        log::info "CMD" "- No release branch recorded as pushed"
    fi

    echo ""

    if [[ "$gh_release_created" == "true" ]]; then
        if [[ -n "$tag_name" && "$tag_name" != "null" && "$tag_name" != "" ]]; then
            log::info "CMD" "- Would delete GitHub Release associated with tag: ${tag_name}"
        elif [[ "$version" != "unknown" ]]; then
            log::info "CMD" "- Would delete GitHub Release associated with version: ${version}"
        else
            log::info "CMD" "- GitHub Release was created but tag/version is not recorded"
        fi
    else
        log::info "CMD" "- No GitHub Release recorded as created"
    fi

    echo ""
    if command -v log_section &>/dev/null; then
        log_section "CocoaPods Considerations"
    else
        log::info "CMD" "--- CocoaPods Considerations ---"
    fi
    log::info "CMD" "- CocoaPods trunk does not support automatic unpublish"
    log::info "CMD" "- Manual remediation may be required (e.g., publish a new version)"
    echo ""

    # If --force is not set, just print the plan and exit
    if [[ "$force" != "1" ]]; then
        log::info "CMD" "No changes have been made. Re-run with --force to execute destructive rollback operations"
        return 0
    fi

    # --force is set: execute destructive rollback
    log::warn "CMD" "Executing destructive rollback operations as described above"
    log::warn "CMD" "This includes deleting git tags/branches and GitHub Releases"

    # Execute rollback actions
    if _msp_execute_rollback_actions \
        "$version" \
        "$release_branch" \
        "$tag_created" \
        "$tag_name" \
        "$branch_pushed" \
        "$gh_release_created"; then

        # On success, reset git flags in the state
        if command -v msp_state_reset_git_flags &>/dev/null; then
            msp_state_reset_git_flags
        fi

        if command -v log_section &>/dev/null; then
            log_section "Rollback completed successfully"
        else
            log::success "CMD" "Rollback completed successfully"
        fi
        return 0
    else
        if command -v log_section &>/dev/null; then
            log_section "Rollback completed with errors"
        else
            log::error "CMD" "Rollback completed with errors"
        fi
        return 1
    fi
}

# Private helper to execute rollback actions
_msp_execute_rollback_actions() {
    local version="$1"
    local release_branch="$2"
    local tag_created="$3"
    local tag_name="$4"
    local branch_pushed="$5"
    local gh_release_created="$6"

    local any_error=0

    if command -v log_section &>/dev/null; then
        log_section "Executing Destructive Rollback Actions"
    else
        log::info "CMD" "--- Executing Destructive Rollback Actions ---"
    fi

    # 1) Delete git tag (local + remote) if recorded as created
    if [[ "$tag_created" == "true" ]]; then
        if [[ -z "$tag_name" || "$tag_name" == "null" || "$tag_name" == "" ]]; then
            log::warn "CMD" "State indicates tag_created=true but tag_name is empty. Skipping tag deletion"
        else
            log::info "CMD" "Deleting git tag (local + remote): ${tag_name}"
            if command -v msp_git_delete_tag &>/dev/null; then
                if ! msp_git_delete_tag "$tag_name"; then
                    log::error "CMD" "Failed to delete git tag ${tag_name}"
                    any_error=1
                fi
            else
                log::error "CMD" "msp_git_delete_tag function not available"
                any_error=1
            fi
        fi
    else
        log::info "CMD" "No git tag recorded as created. Skipping git tag deletion"
    fi

    echo ""

    # 2) Delete remote release branch if recorded as pushed
    if [[ "$branch_pushed" == "true" ]]; then
        if [[ -z "$release_branch" || "$release_branch" == "unknown" || "$release_branch" == "null" ]]; then
            log::warn "CMD" "State indicates release_branch_pushed=true but release_branch is unknown. Skipping remote branch deletion"
        else
            log::info "CMD" "Deleting remote release branch: ${release_branch}"
            if command -v msp_git_delete_remote_branch &>/dev/null; then
                if ! msp_git_delete_remote_branch "$release_branch"; then
                    log::error "CMD" "Failed to delete remote release branch ${release_branch}"
                    any_error=1
                fi
            else
                log::error "CMD" "msp_git_delete_remote_branch function not available"
                any_error=1
            fi
        fi
    else
        log::info "CMD" "No release branch recorded as pushed. Skipping remote branch deletion"
    fi

    echo ""

    # 3) Delete GitHub Release if recorded as created
    if [[ "$gh_release_created" == "true" ]]; then
        local release_target=""
        if [[ -n "$tag_name" && "$tag_name" != "null" && "$tag_name" != "" ]]; then
            release_target="$tag_name"
        elif [[ "$version" != "unknown" && "$version" != "null" && -n "$version" ]]; then
            release_target="$version"
        fi

        if [[ -z "$release_target" ]]; then
            log::warn "CMD" "State indicates github_release_created=true but tag_name/version is empty. Skipping GitHub Release deletion"
        else
            log::info "CMD" "Deleting GitHub Release: ${release_target}"
            if command -v github_delete_release &>/dev/null; then
                if ! github_delete_release "$release_target"; then
                    log::error "CMD" "Failed to delete GitHub Release ${release_target}"
                    any_error=1
                fi
            else
                log::error "CMD" "github_delete_release function not available"
                any_error=1
            fi
        fi
    else
        log::info "CMD" "No GitHub Release recorded as created. Skipping GitHub Release deletion"
    fi

    echo ""

    # 4) CocoaPods considerations (no automatic unpublish)
    if command -v log_section &>/dev/null; then
        log_section "CocoaPods Considerations"
    else
        log::info "CMD" "--- CocoaPods Considerations ---"
    fi
    log::info "CMD" "- CocoaPods trunk does not support automatic unpublish"
    log::info "CMD" "- If a broken version has been published, the recommended remediation is:"
    log::info "CMD" "    1) Bump a new version (e.g., patch/minor)"
    log::info "CMD" "    2) Release the new version with the fixes"
    log::info "CMD" "    3) Communicate deprecation of the problematic version if necessary"
    echo ""

    if [[ $any_error -ne 0 ]]; then
        log::warn "CMD" "Rollback actions completed with errors. See messages above"
        return 1
    fi

    log::success "CMD" "All destructive rollback actions completed successfully"
    return 0
}

# Export functions
export -f msp_cmd_fix_public_tag 2>/dev/null || true
export -f msp_cmd_verify 2>/dev/null || true
export -f msp_cmd_verify_matrix 2>/dev/null || true
export -f msp_cmd_rollback 2>/dev/null || true
