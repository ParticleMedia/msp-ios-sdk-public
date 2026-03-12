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
# Prepare DemoApp for CocoaPods Verification
# ============================================================================
# Purpose: Copy DemoApp into sandbox directory for CocoaPods verification
#
# Usage:   ./prepare_demoapp.sh <sandbox_path>
# ============================================================================

set -euo pipefail

source "$(dirname "$0")/../common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

prepare_demoapp() {
    local sandbox="$1"

    if [[ -z "$sandbox" ]]; then
        vr_log::error "PODS" "Sandbox path required"
        return 1
    fi

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local fixtures_dir="$script_dir/fixtures"
    local verify_template="$script_dir/project.yml.verify-template"

    if [[ ! -d "$fixtures_dir/MSPDemoApp" ]]; then
        vr_log::error "PODS" "Verification fixtures not found: $fixtures_dir/MSPDemoApp"
        return 1
    fi

    if [[ ! -f "$verify_template" ]]; then
        vr_log::error "PODS" "Verification template not found: $verify_template"
        return 1
    fi

    # 1. Create sandbox layout: sandbox/DemoApp/MSPDemoApp/ (matches template sources path)
    mkdir -p "$sandbox/DemoApp"

    # 2. Copy minimal verification fixtures (not the full DemoApp which imports all adapters)
    cp -R "$fixtures_dir/MSPDemoApp" "$sandbox/DemoApp/"
    vr_log::info "PODS" "[PODS] Copied verification fixtures"

    # 3. Copy minimal project.yml from verify-template (config-driven)
    cp "$verify_template" "$sandbox/DemoApp/project.yml"
    vr_log::info "PODS" "[PODS] Copied project.yml from verify-template"

    # 4. Generate .xcodeproj from project.yml (required by CocoaPods)
    if command -v xcodegen >/dev/null 2>&1; then
        pushd "$sandbox/DemoApp" >/dev/null
        local xcodegen_output
        if xcodegen_output=$(xcodegen generate 2>&1); then
            vr_log::info "PODS" "[PODS] Generated .xcodeproj via XcodeGen"
        else
            vr_log::warn "PODS" "[PODS] XcodeGen failed: $xcodegen_output"
        fi
        popd >/dev/null
    else
        vr_log::warn "PODS" "[PODS] xcodegen not found, skipping .xcodeproj generation"
    fi

    vr_log::info "PODS" "[PODS] Prepared DemoApp in sandbox: $sandbox/DemoApp"

    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    prepare_demoapp "$@"
fi
