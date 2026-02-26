#!/usr/bin/env bash
# ============================================================================
# MSP iOS SDK - Local CocoaPods Verification
# ============================================================================
# Module: verify_local/pods.sh
# Purpose: Verify local CocoaPods build with iOS simulator
# Created for: T062
#
# Description:
#   Performs local verification by building a test app against the local
#   podspecs before publishing. This catches build errors early.
#
# Usage:
#   source verify_local/pods.sh
#   verify_local_pods "1.0.0" "/tmp/sandbox"
#
# Environment Variables:
#   PODS_LOCAL_PATH: Path to local podspecs (default: ROOT_DIR)
#   PODS_PRIMARY_PRODUCT: Primary pod to test (default: MSPCore)
#   VERIFY_SIMULATOR: iOS Simulator name (default: iPhone 15)
#   VERIFY_TIMEOUT_LOCAL: Timeout in seconds (default: 300)
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_VERIFY_LOCAL_PODS_SOURCED:-}" ]] && return 0
readonly _VERIFY_LOCAL_PODS_SOURCED=1

# ============================================================================
# Configuration
# ============================================================================

# Default timeout for local verification (5 minutes)
readonly VERIFY_LOCAL_TIMEOUT="${VERIFY_TIMEOUT_LOCAL:-300}"

# Default simulator
readonly VERIFY_LOCAL_SIMULATOR="${VERIFY_SIMULATOR:-iPhone 15}"

# ============================================================================
# Main Verification Function
# ============================================================================

# Verify local CocoaPods build
# @param $1 version - Release version
# @param $2 sandbox_path - Path to sandbox directory
# @return 0 on success, 1 on failure
verify_local_pods() {
    local version="$1"
    local sandbox_path="$2"

    if [[ -z "$version" ]]; then
        log::error "VERIFY_LOCAL" "Version is required"
        return 1
    fi

    if [[ -z "$sandbox_path" ]] || [[ ! -d "$sandbox_path" ]]; then
        log::error "VERIFY_LOCAL" "Valid sandbox path required: $sandbox_path"
        return 1
    fi

    # Check resume mode
    if [[ "${MSP_RESUME_MODE:-0}" == "1" ]]; then
        local status
        status="$(msp_state_get_step_status "pods_local_verify" 2>/dev/null || echo "unknown")"
        if [[ "$status" == "success" || "$status" == "skipped" ]]; then
            log::info "VERIFY_LOCAL" "Resuming: skipping pods_local_verify (status: ${status})"
            return 0
        fi
    fi

    msp_state_mark_step_running "pods_local_verify"

    log_step_info "Local CocoaPods Verification"

    # DRY_RUN check
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log::info "VERIFY_LOCAL" "DRY RUN: Skipping local pods verification"
        msp_state_mark_step_skipped "pods_local_verify" "Skipped due to DRY_RUN"
        return 0
    fi

    # Configuration
    local pods_local_path="${PODS_LOCAL_PATH:-$ROOT_DIR}"
    local pods_primary_product="${PODS_PRIMARY_PRODUCT:-MSPCore}"

    log::info "VERIFY_LOCAL" "Local podspecs path: $pods_local_path"
    log::info "VERIFY_LOCAL" "Primary product: $pods_primary_product"
    log::info "VERIFY_LOCAL" "Version: $version"
    log::info "VERIFY_LOCAL" "Simulator: $VERIFY_LOCAL_SIMULATOR"

    # Create test app directory in sandbox
    local testapp_dir="$sandbox_path/LocalTestApp"
    mkdir -p "$testapp_dir"

    cd "$testapp_dir" || {
        log::error "VERIFY_LOCAL" "Failed to enter test app directory"
        msp_state_mark_step_failed "pods_local_verify" "Failed to enter test directory" "1"
        return 1
    }

    log_step_info "Generating local test app"

    cat > "$testapp_dir/main.swift" << EOF
import SwiftUI
import ${pods_primary_product}

@main
struct LocalTestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            Text("MSP Local Verification")
                .font(.title)
            Text("Version: $version")
                .font(.caption)
        }
        .padding()
    }
}
EOF

    log_step_info "Generating Podfile with local path"

    cat > "$testapp_dir/Podfile" << EOF
# Local verification Podfile
# Points to local podspecs for pre-publish validation

platform :ios, '15.0'
use_frameworks!

target 'LocalTestApp' do
  # Use local path for all MSP pods
  pod '${pods_primary_product}', :path => '$pods_local_path'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
EOF

    log::info "VERIFY_LOCAL" "Podfile created with local path: $pods_local_path"

    log_step_info "Installing local pods"

    local install_output
    local install_exit_code=0

    if [[ "${VERBOSE:-false}" == "true" ]]; then
        if ! pod install --verbose 2>&1; then
            install_exit_code=$?
        fi
    else
        install_output=$(pod install 2>&1) || install_exit_code=$?
    fi

    if [[ $install_exit_code -ne 0 ]]; then
        log::error "VERIFY_LOCAL" "pod install failed (exit code: $install_exit_code)"
        if [[ "${VERBOSE:-false}" != "true" && -n "${install_output:-}" ]]; then
            log::info "VERIFY_LOCAL" "Output (last 20 lines):"
            echo "$install_output" | tail -20 | sed 's/^/  /'
        fi
        msp_state_mark_step_failed "pods_local_verify" "pod install failed" "$install_exit_code"
        return 1
    fi

    log::success "VERIFY_LOCAL" "Local pods installed successfully"

    if [[ ! -f "$testapp_dir/LocalTestApp.xcworkspace/contents.xcworkspacedata" ]]; then
        log::error "VERIFY_LOCAL" "Workspace not created after pod install"
        msp_state_mark_step_failed "pods_local_verify" "Workspace not created" "1"
        return 1
    fi

    log_step_info "Building local test app"

    local build_output
    local build_exit_code=0

    local xcodebuild_cmd=(
        xcodebuild
        -workspace LocalTestApp.xcworkspace
        -scheme LocalTestApp
        -sdk iphonesimulator
        -destination "platform=iOS Simulator,name=$VERIFY_LOCAL_SIMULATOR"
        -configuration Debug
        build
    )

    if [[ "${VERBOSE:-false}" == "true" ]]; then
        if ! "${xcodebuild_cmd[@]}" 2>&1; then
            build_exit_code=$?
        fi
    else
        build_output=$("${xcodebuild_cmd[@]}" 2>&1) || build_exit_code=$?
    fi

    if [[ $build_exit_code -ne 0 ]]; then
        log::error "VERIFY_LOCAL" "xcodebuild failed (exit code: $build_exit_code)"
        if [[ "${VERBOSE:-false}" != "true" && -n "${build_output:-}" ]]; then
            log::info "VERIFY_LOCAL" "Build output (last 30 lines):"
            echo "$build_output" | tail -30 | sed 's/^/  /'
        fi
        msp_state_mark_step_failed "pods_local_verify" "xcodebuild failed" "$build_exit_code"
        return 1
    fi

    log::success "VERIFY_LOCAL" "Local build succeeded"

    # Summary
    ui_divider
    log::success "VERIFY_LOCAL" "Local CocoaPods Verification Summary"
    ui_kv "Local path" "$pods_local_path"
    ui_kv "Primary product" "$pods_primary_product"
    ui_kv "Version" "$version"
    ui_kv "Build" "SUCCESS"
    ui_divider

    msp_state_mark_step_success "pods_local_verify"
    return 0
}

# Export function
export -f verify_local_pods
