#!/usr/bin/env bash
# ============================================================================
# MSP iOS SDK - Remote CocoaPods Verification
# ============================================================================
# Module: verify_remote/pods.sh
# Purpose: Verify remote CocoaPods trunk availability and build
# Created for: T064
#
# Description:
#   Verifies that the published version is available on CocoaPods trunk
#   by creating a fresh test app and running pod install with the version.
#
# Usage:
#   source verify_remote/pods.sh
#   verify_remote_pods "1.0.0" "/tmp/sandbox"
#
# Environment Variables:
#   PODS_REMOTE_URL: Remote podspec repository URL
#   PODS_REMOTE_PRIMARY_PRODUCT: Primary pod name (default: MSPCore)
#   VERIFY_TIMEOUT_REMOTE: Timeout in seconds (default: 600)
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_VERIFY_REMOTE_PODS_SOURCED:-}" ]] && return 0
readonly _VERIFY_REMOTE_PODS_SOURCED=1

# ============================================================================
# Configuration
# ============================================================================

# Default timeout for remote verification (10 minutes)
readonly VERIFY_REMOTE_PODS_TIMEOUT="${VERIFY_TIMEOUT_REMOTE:-600}"

# ============================================================================
# Main Verification Function
# ============================================================================

# Verify remote CocoaPods availability
# @description This is a modular wrapper that delegates to verify_pods_remote
#              in the main verify.sh. Provides a clean entry point for
#              standalone remote pods verification.
# @param $1 version - Release version
# @param $2 sandbox_path - Path to sandbox directory (optional, will use sandbox_create if not active)
# @return 0 on success, 1 on failure
verify_remote_pods() {
    local version="$1"
    local sandbox_path="${2:-}"

    if [[ -z "$version" ]]; then
        log::error "VERIFY_REMOTE_PODS" "Version is required"
        return 1
    fi

    # If verify_pods_remote is available (from verify.sh), delegate to it
    if type -t verify_pods_remote &>/dev/null; then
        log::debug "VERIFY_REMOTE_PODS" "Delegating to verify_pods_remote"
        verify_pods_remote "$version"
        return $?
    fi

    # Otherwise, implement standalone verification
    log::info "VERIFY_REMOTE_PODS" "Running standalone remote pods verification"

    # Check resume mode
    if [[ "${MSP_RESUME_MODE:-0}" == "1" ]]; then
        local status
        status="$(msp_state_get_step_status "pods_remote_verify" 2>/dev/null || echo "unknown")"
        if [[ "$status" == "success" || "$status" == "skipped" ]]; then
            log::info "VERIFY_REMOTE_PODS" "Resuming: skipping (status: ${status})"
            return 0
        fi
    fi

    msp_state_mark_step_running "pods_remote_verify"

    log_step_info "Remote CocoaPods Verification"

    # DRY_RUN check
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log::info "VERIFY_REMOTE_PODS" "DRY RUN: Skipping remote pods verification"
        log::info "VERIFY_REMOTE_PODS" "Would verify: pod 'MSPCore', '~> $version'"
        msp_state_mark_step_skipped "pods_remote_verify" "Skipped due to DRY_RUN"
        return 0
    fi

    # Configuration
    local pods_remote_url="${PODS_REMOTE_URL:-}"
    local pods_primary_product="${PODS_REMOTE_PRIMARY_PRODUCT:-MSPCore}"

    if [[ -z "$pods_remote_url" ]]; then
        log::warn "VERIFY_REMOTE_PODS" "PODS_REMOTE_URL not set. Skipping verification."
        msp_state_mark_step_skipped "pods_remote_verify" "PODS_REMOTE_URL not set"
        return 0
    fi

    # Ensure sandbox
    if [[ -z "$sandbox_path" ]]; then
        if sandbox_is_active; then
            sandbox_path=$(sandbox_get_path)
        else
            sandbox_path=$(sandbox_create "remote-pods-verify")
        fi
    fi

    local testapp_dir="$sandbox_path/RemotePodsTest"
    mkdir -p "$testapp_dir"

    cd "$testapp_dir" || {
        log::error "VERIFY_REMOTE_PODS" "Failed to enter test directory"
        msp_state_mark_step_failed "pods_remote_verify" "Failed to enter test directory" "1"
        return 1
    }

    log::info "VERIFY_REMOTE_PODS" "Remote URL: $pods_remote_url"
    log::info "VERIFY_REMOTE_PODS" "Primary product: $pods_primary_product"
    log::info "VERIFY_REMOTE_PODS" "Version: $version"

    log_step_info "Generating remote test app"

    cat > "$testapp_dir/main.swift" << EOF
import SwiftUI
import ${pods_primary_product}

@main
struct RemoteTestApp: App {
    var body: some Scene {
        WindowGroup {
            Text("MSP Remote Verification - $version")
        }
    }
}
EOF

    cat > "$testapp_dir/Podfile" << EOF
source '$pods_remote_url'
source 'https://cdn.cocoapods.org/'

platform :ios, '15.0'
use_frameworks!

target 'RemoteTestApp' do
  pod '${pods_primary_product}', '~> $version'
end
EOF

    log_step_info "Updating CocoaPods repository"
    pod repo update 2>&1 | grep -v "Updating spec repo" || true

    log_step_info "Installing remote pods"
    local install_exit_code=0
    if ! pod install --silent 2>&1; then
        install_exit_code=$?
        log::error "VERIFY_REMOTE_PODS" "pod install failed (exit: $install_exit_code)"
        msp_state_mark_step_failed "pods_remote_verify" "pod install failed" "$install_exit_code"
        return 1
    fi

    log::success "VERIFY_REMOTE_PODS" "Remote pods installed successfully"

    log_step_info "Building remote test app"
    local build_exit_code=0
    if ! xcodebuild -workspace RemoteTestApp.xcworkspace \
                    -scheme RemoteTestApp \
                    -sdk iphonesimulator \
                    -destination 'platform=iOS Simulator,name=iPhone 15' \
                    build >/dev/null 2>&1; then
        build_exit_code=$?
        log::error "VERIFY_REMOTE_PODS" "Build failed (exit: $build_exit_code)"
        msp_state_mark_step_failed "pods_remote_verify" "Build failed" "$build_exit_code"
        return 1
    fi

    log::success "VERIFY_REMOTE_PODS" "Remote build succeeded"

    # Summary
    ui_divider
    log::success "VERIFY_REMOTE_PODS" "Remote CocoaPods Verification Complete"
    ui_kv "Remote URL" "$pods_remote_url"
    ui_kv "Product" "$pods_primary_product"
    ui_kv "Version" "$version"
    ui_kv "Available" "YES"
    ui_kv "Build" "SUCCESS"
    ui_divider

    msp_state_mark_step_success "pods_remote_verify"
    return 0
}

# Export function
export -f verify_remote_pods
