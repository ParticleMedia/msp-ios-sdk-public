#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch M, shared) ---
# shellcheck source=/dev/null
_msp_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$_msp_root" ] && [ -f "$_msp_root/Scripts/lib/worktree_guard.sh" ]; then
  . "$_msp_root/Scripts/lib/worktree_guard.sh"
  msp_enforce_main_repo_or_exit
fi
unset _msp_root
# --- End MSP Worktree Safety Guard (Patch M, shared) ---
# ============================================================================
# Prepare DemoApp for Local Verification
# ============================================================================
# Purpose: Set up minimal DemoApp in sandbox using shared verification fixtures
#
# Uses:    verify_remote/cocoapods/fixtures/    (shared source fixtures)
#          verify_remote/cocoapods/project.yml.verify-template (shared config)
#
# Usage:   ./prepare_demoapp.sh <sandbox_path>
# ============================================================================

set -euo pipefail

source "$(dirname "$0")/../verify_remote/common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

prepare_demoapp() {
    local sandbox="$1"

    if [[ -z "$sandbox" ]]; then
        vr_log::error "LOCAL" "[LOCAL] Sandbox path required"
        return 1
    fi

    # Shared fixtures and templates live alongside the remote verification scripts
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local shared_dir="$script_dir/../verify_remote/cocoapods"
    local fixtures_dir="$shared_dir/fixtures"
    local verify_template="$shared_dir/project.yml.verify-template"

    if [[ ! -d "$fixtures_dir/MSPDemoApp" ]]; then
        vr_log::error "LOCAL" "Shared fixtures not found: $fixtures_dir/MSPDemoApp"
        return 1
    fi

    if [[ ! -f "$verify_template" ]]; then
        vr_log::error "LOCAL" "Shared verify template not found: $verify_template"
        return 1
    fi

    local demoapp_dst="$sandbox/DemoApp"

    # 1. Create sandbox layout
    mkdir -p "$demoapp_dst"

    # 2. Copy shared verification fixtures (minimal source that imports MSPCore)
    cp -R "$fixtures_dir/MSPDemoApp" "$demoapp_dst/"
    vr_log::info "LOCAL" "[LOCAL] Copied verification fixtures"

    # 3. Copy minimal project.yml from shared template (config-driven)
    cp "$verify_template" "$demoapp_dst/project.yml"
    vr_log::info "LOCAL" "[LOCAL] Copied project.yml from verify-template"

    # 4. Generate .xcodeproj via XcodeGen (required by CocoaPods)
    if command -v xcodegen >/dev/null 2>&1; then
        pushd "$demoapp_dst" >/dev/null
        local xcodegen_output
        if xcodegen_output=$(xcodegen generate 2>&1); then
            vr_log::info "LOCAL" "[LOCAL] Generated .xcodeproj via XcodeGen"
        else
            vr_log::warn "LOCAL" "[LOCAL] XcodeGen failed: $xcodegen_output"
        fi
        popd >/dev/null
    else
        vr_log::warn "LOCAL" "[LOCAL] xcodegen not found, skipping .xcodeproj generation"
    fi

    vr_log::info "LOCAL" "[LOCAL] Prepared DemoApp in sandbox: $demoapp_dst"

    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    prepare_demoapp "$@"
fi

