#!/usr/bin/env bash
# ============================================================================
# MSP iOS SDK - Remote SPM Verification
# ============================================================================
# Module: verify_remote/spm.sh
# Purpose: Verify remote SPM package availability and resolution
# Created for: T065
#
# Description:
#   Verifies that the published version is available via SPM by creating
#   a fresh test package and resolving/building the dependency.
#
# Usage:
#   source verify_remote/spm.sh
#   verify_remote_spm "1.0.0" "/tmp/sandbox"
#
# Environment Variables:
#   SPM_REMOTE_URL: Remote git repository URL for SPM
#   SPM_REMOTE_PACKAGE_NAME: Package name (default: msp-ios-sdk)
#   SPM_REMOTE_PRODUCT_NAME: Product name (default: MSPAds)
#   VERIFY_SPM_STRICT: If "true", fail on SPM errors (default: true)
#   VERIFY_TIMEOUT_REMOTE: Timeout in seconds (default: 300)
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_VERIFY_REMOTE_SPM_SOURCED:-}" ]] && return 0
readonly _VERIFY_REMOTE_SPM_SOURCED=1

# ============================================================================
# Configuration
# ============================================================================

# Default timeout for remote SPM verification (5 minutes)
readonly VERIFY_REMOTE_SPM_TIMEOUT="${VERIFY_TIMEOUT_REMOTE:-300}"

# ============================================================================
# Main Verification Function
# ============================================================================

# Verify remote SPM package availability
# @description This is a modular wrapper that delegates to verify_spm_remote
#              in the main verify.sh. Provides a clean entry point for
#              standalone remote SPM verification.
# @param $1 version - Release version
# @param $2 sandbox_path - Path to sandbox directory (optional)
# @return 0 on success, 1 on failure
verify_remote_spm() {
    local version="$1"
    local sandbox_path="${2:-}"

    if [[ -z "$version" ]]; then
        log::error "VERIFY_REMOTE_SPM" "Version is required"
        return 1
    fi

    # If verify_spm_remote is available (from verify.sh), delegate to it
    if type -t verify_spm_remote &>/dev/null; then
        log::debug "VERIFY_REMOTE_SPM" "Delegating to verify_spm_remote"
        verify_spm_remote "$version"
        return $?
    fi

    # Otherwise, implement standalone verification
    log::info "VERIFY_REMOTE_SPM" "Running standalone remote SPM verification"

    # Check resume mode
    if [[ "${MSP_RESUME_MODE:-0}" == "1" ]]; then
        local status
        status="$(msp_state_get_step_status "spm_remote_verify" 2>/dev/null || echo "unknown")"
        if [[ "$status" == "success" || "$status" == "skipped" ]]; then
            log::info "VERIFY_REMOTE_SPM" "Resuming: skipping (status: ${status})"
            return 0
        fi
    fi

    msp_state_mark_step_running "spm_remote_verify"

    log_step_info "Remote SPM Verification"

    # DRY_RUN check
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log::info "VERIFY_REMOTE_SPM" "DRY RUN: Skipping remote SPM verification"
        msp_state_mark_step_skipped "spm_remote_verify" "Skipped due to DRY_RUN"
        return 0
    fi

    # Configuration
    local spm_remote_url="${SPM_REMOTE_URL:-}"
    local spm_package_name="${SPM_REMOTE_PACKAGE_NAME:-msp-ios-sdk}"
    local spm_product_name="${SPM_REMOTE_PRODUCT_NAME:-MSPAds}"
    local strict_mode="${VERIFY_SPM_STRICT:-true}"

    if [[ -z "$spm_remote_url" ]]; then
        log::warn "VERIFY_REMOTE_SPM" "SPM_REMOTE_URL not set. Skipping verification."
        msp_state_mark_step_skipped "spm_remote_verify" "SPM_REMOTE_URL not set"
        return 0
    fi

    # Ensure sandbox
    if [[ -z "$sandbox_path" ]]; then
        if sandbox_is_active; then
            sandbox_path=$(sandbox_get_path)
        else
            sandbox_path=$(sandbox_create "remote-spm-verify")
        fi
    fi

    local testpkg_dir="$sandbox_path/RemoteSPMTest"
    mkdir -p "$testpkg_dir"

    cd "$testpkg_dir" || {
        log::error "VERIFY_REMOTE_SPM" "Failed to enter test directory"
        msp_state_mark_step_failed "spm_remote_verify" "Failed to enter test directory" "1"
        return 1
    }

    log::info "VERIFY_REMOTE_SPM" "Remote URL: $spm_remote_url"
    log::info "VERIFY_REMOTE_SPM" "Package: $spm_package_name"
    log::info "VERIFY_REMOTE_SPM" "Product: $spm_product_name"
    log::info "VERIFY_REMOTE_SPM" "Version: $version"
    log::info "VERIFY_REMOTE_SPM" "Strict mode: $strict_mode"

    log_step_info "Initializing remote SPM test package"

    if ! swift package init --type executable --name RemoteSPMTest 2>&1; then
        log::error "VERIFY_REMOTE_SPM" "Failed to initialize Swift package"
        msp_state_mark_step_failed "spm_remote_verify" "Failed to init package" "1"
        return 1
    fi

    log_step_info "Generating Package.swift with remote dependency"

    cat > "$testpkg_dir/Package.swift" << EOF
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RemoteSPMTest",
    dependencies: [
        .package(url: "$spm_remote_url", .exact("$version"))
    ],
    targets: [
        .executableTarget(
            name: "RemoteSPMTest",
            dependencies: [
                .product(name: "$spm_product_name", package: "$spm_package_name")
            ]
        )
    ]
)
EOF

    local main_swift
    main_swift=$(find "$testpkg_dir/Sources" -name "*.swift" | head -1)
    if [[ -n "$main_swift" ]]; then
        cat > "$main_swift" << EOF
import Foundation
import $spm_product_name

print("MSP Remote SPM Verification")
print("Version: $version")
print("If you see this, the remote package resolved successfully.")
EOF
    fi

    log_step_info "Resolving remote SPM dependencies"

    local resolve_output
    local resolve_exit_code=0

    if [[ "${VERBOSE:-false}" == "true" ]]; then
        if ! swift package resolve 2>&1; then
            resolve_exit_code=$?
        fi
    else
        resolve_output=$(swift package resolve 2>&1) || resolve_exit_code=$?
    fi

    if [[ $resolve_exit_code -ne 0 ]]; then
        log::error "VERIFY_REMOTE_SPM" "swift package resolve failed (exit: $resolve_exit_code)"
        if [[ "${VERBOSE:-false}" != "true" && -n "${resolve_output:-}" ]]; then
            log::info "VERIFY_REMOTE_SPM" "Output (last 20 lines):"
            echo "$resolve_output" | tail -20 | sed 's/^/  /'
        fi

        if [[ "$strict_mode" == "true" ]]; then
            log::error "VERIFY_REMOTE_SPM" "Strict mode: failing verification"
            msp_state_mark_step_failed "spm_remote_verify" "swift package resolve failed (strict)" "$resolve_exit_code"
            return 1
        else
            log::warn "VERIFY_REMOTE_SPM" "Soft mode: continuing despite resolve failure"
            msp_state_mark_step_skipped "spm_remote_verify" "resolve failed (soft mode)"
            return 0
        fi
    fi

    log::success "VERIFY_REMOTE_SPM" "Dependencies resolved"

    log_step_info "Building remote SPM package"

    local build_output
    local build_exit_code=0

    if [[ "${VERBOSE:-false}" == "true" ]]; then
        if ! swift build 2>&1; then
            build_exit_code=$?
        fi
    else
        build_output=$(swift build 2>&1) || build_exit_code=$?
    fi

    if [[ $build_exit_code -ne 0 ]]; then
        log::error "VERIFY_REMOTE_SPM" "swift build failed (exit: $build_exit_code)"
        if [[ "${VERBOSE:-false}" != "true" && -n "${build_output:-}" ]]; then
            log::info "VERIFY_REMOTE_SPM" "Build output (last 30 lines):"
            echo "$build_output" | tail -30 | sed 's/^/  /'
        fi

        if [[ "$strict_mode" == "true" ]]; then
            log::error "VERIFY_REMOTE_SPM" "Strict mode: failing verification"
            msp_state_mark_step_failed "spm_remote_verify" "swift build failed (strict)" "$build_exit_code"
            return 1
        else
            log::warn "VERIFY_REMOTE_SPM" "Soft mode: continuing despite build failure"
            msp_state_mark_step_skipped "spm_remote_verify" "build failed (soft mode)"
            return 0
        fi
    fi

    log::success "VERIFY_REMOTE_SPM" "Remote SPM build succeeded"

    # Summary
    ui_divider
    log::success "VERIFY_REMOTE_SPM" "Remote SPM Verification Complete"
    ui_kv "Remote URL" "$spm_remote_url"
    ui_kv "Package" "$spm_package_name"
    ui_kv "Product" "$spm_product_name"
    ui_kv "Version" "$version"
    ui_kv "Resolved" "YES"
    ui_kv "Build" "SUCCESS"
    ui_divider

    msp_state_mark_step_success "spm_remote_verify"
    return 0
}

# Export function
export -f verify_remote_spm
