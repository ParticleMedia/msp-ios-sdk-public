#!/usr/bin/env bash
# ============================================================================
# MSP iOS SDK - Verification Dispatcher (Phase 4)
# ============================================================================
# Module: verify.sh
# Purpose: Dispatch verification tasks for Phase 4 of release flow
# Created for: T061 (Phase 4 structure rewrite)
#
# Verification Types (per release.yaml verify.types):
#   - local:        Local simulator build verification
#   - remote_pods:  CocoaPods trunk verification
#   - remote_spm:   SPM package resolution verification
#   - sample_app:   Demo app build verification
#   - device:       Physical device test (optional)
#
# Usage:
#   ./verify.sh <version> [--type=<type>] [--sandbox-dir=<path>]
#   ./verify.sh 1.0.0                    # Run all enabled verifications
#   ./verify.sh 1.0.0 --type=remote_pods # Run only CocoaPods verification
#   ./verify.sh 1.0.0 --type=local       # Run only local verification
#
# Environment Variables:
#   MSP_RELEASE_MODE: "full" runs verification (auto for production), "simple" skips it
#   DRY_RUN: If "true", simulation mode
#   VERBOSE/DEBUG: Keep sandbox for inspection
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_VERIFY_DISPATCHER_SOURCED:-}" ]] && return 0
readonly _VERIFY_DISPATCHER_SOURCED=1

# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

# shellcheck source=Scripts/lib/path-helpers.sh
source "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/path-helpers.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# Module Loading
# ============================================================================

# shellcheck source=Scripts/lib/release-common.sh
source "$ROOT_DIR/Scripts/lib/release-common.sh"

# R042c: Source config loader extension for test settings
if [[ -f "$ROOT_DIR/Scripts/lib/config_loader_ext.sh" ]]; then
    # shellcheck source=Scripts/lib/config_loader_ext.sh
    source "$ROOT_DIR/Scripts/lib/config_loader_ext.sh" 2>/dev/null || true
    load_test_config 2>/dev/null || true
fi
# Default simulator destination from config or fallback
VERIFY_SIMULATOR_DESTINATION="${TEST_UNIT_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 15}"

# Load release state utilities
source "$SCRIPT_DIR/../utils/state.sh"

# Load logger with Phase 4 support
if [[ -f "$SCRIPT_DIR/../utils/logger.sh" ]]; then
    source "$SCRIPT_DIR/../utils/logger.sh"
fi

# Load sandbox module (T060)
if [[ -f "$SCRIPT_DIR/sandbox.sh" ]]; then
    source "$SCRIPT_DIR/sandbox.sh"
    log::debug "VERIFY" "Loaded sandbox.sh module"
fi

# ============================================================================
# Constants (Exported for use by sub-scripts)
# ============================================================================

# Verification step numbers (per FR-062: Phase 4 has 6 steps)
# shellcheck disable=SC2034
export VERIFY_STEP_INIT=1
# shellcheck disable=SC2034
export VERIFY_STEP_LOCAL=2
# shellcheck disable=SC2034
export VERIFY_STEP_REMOTE_PODS=3
# shellcheck disable=SC2034
export VERIFY_STEP_REMOTE_SPM=4
# shellcheck disable=SC2034
export VERIFY_STEP_SAMPLE_APP=5
# shellcheck disable=SC2034
export VERIFY_STEP_CLEANUP=6

# ============================================================================
# Early Exit Checks
# ============================================================================

# Check if running in simple mode (skip verification)
# Verification only runs in full mode (--full flag or production profile)
_check_simple_mode() {
    if [[ "${MSP_RELEASE_MODE:-simple}" != "full" ]]; then
        log::info "VERIFY" "Simple mode: skipping verification (use --full for verification)"
        return 0
    fi
    return 1
}

# ============================================================================
# Verification Type Handlers
# ============================================================================

# Dispatch to appropriate verification script based on type
# @param $1 type - Verification type (local, remote_pods, remote_spm, sample_app, device)
# @param $2 version - Release version
# @param $3 sandbox_path - Path to sandbox directory
# @return 0 on success, 1 on failure
_dispatch_verification() {
    local type="$1"
    local version="$2"
    local sandbox_path="$3"

    case "$type" in
        local)
            _run_local_verification "$version" "$sandbox_path"
            ;;
        remote_pods)
            _run_remote_pods_verification "$version" "$sandbox_path"
            ;;
        remote_spm)
            _run_remote_spm_verification "$version" "$sandbox_path"
            ;;
        sample_app)
            _run_sample_app_verification "$version" "$sandbox_path"
            ;;
        device)
            _run_device_verification "$version" "$sandbox_path"
            ;;
        *)
            log::error "VERIFY" "Unknown verification type: $type"
            return 1
            ;;
    esac
}

# Run local simulator build verification
# @param $1 version - Release version
# @param $2 sandbox_path - Path to sandbox directory
_run_local_verification() {
    local version="$1"
    local sandbox_path="$2"

    log_step_info "Local verification: build with simulator"

    local script_path="$SCRIPT_DIR/verify_local/pods.sh"
    if [[ -f "$script_path" ]]; then
        source "$script_path"
        verify_local_pods "$version" "$sandbox_path"
    else
        log::warn "VERIFY" "Local verification script not found: $script_path"
        log::info "VERIFY" "Skipping local verification (script not implemented)"
        return 0
    fi
}

# ============================================================================
# Pods Remote Verification
# ============================================================================
verify_pods_remote() {
    local version="$1"

    if [[ -z "$version" ]]; then
        log::error "VERIFY" "Version is required for Pods remote verification"
        return 1
    fi

    # Check if we should skip this step in resume mode
    if [[ "${MSP_RESUME_MODE:-0}" == "1" ]]; then
        local status
        status="$(msp_state_get_step_status "pods_remote_verify" 2>/dev/null || echo "unknown")"
        if [[ "$status" == "success" || "$status" == "skipped" ]]; then
            log::info "VERIFY" "Resuming: skipping pods_remote_verify (status already ${status})"
            return 0
        fi
    fi

    msp_state_mark_step_running "pods_remote_verify"

    log_step_info "CocoaPods Remote Verification"

    # DRY_RUN shortcut
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log::info "VERIFY" "DRY RUN: Skipping Pods remote verification"
        log::info "VERIFY" "Would verify: pod 'MSPCore', '~> $version'"
        msp_state_mark_step_skipped "pods_remote_verify" "Pods remote verify skipped due to DRY_RUN"
        return 0
    fi

    # Use sandbox for isolation (T060)
    local sandbox_path
    if sandbox_is_active; then
        sandbox_path=$(sandbox_get_path)
    else
        sandbox_path=$(sandbox_create "pods-verify")
    fi

    local testapp_dir
    testapp_dir=$(sandbox_mkdir "TestApp")

    log_step_info "Creating isolated test environment"
    log::info "VERIFY" "Sandbox directory: $sandbox_path"

    cd "$testapp_dir" || {
        log::error "VERIFY" "Failed to enter test directory"
        msp_state_mark_step_failed "pods_remote_verify" "Failed to enter test directory" "1"
        return 1
    }

    # Configuration: Read from environment with defaults
    local pods_remote_url="${PODS_REMOTE_URL:-}"
    local pods_primary_product="${PODS_REMOTE_PRIMARY_PRODUCT:-MSPCore}"

    # Check if PODS_REMOTE_URL is set
    if [[ -z "$pods_remote_url" ]]; then
        log::warn "VERIFY" "PODS_REMOTE_URL is not set. Skipping Pods remote verification."
        log::info "VERIFY" "To enable Pods verification, set PODS_REMOTE_URL environment variable."
        msp_state_mark_step_skipped "pods_remote_verify" "Pods remote verify skipped due to PODS_REMOTE_URL not set"
        return 0
    fi

    log::info "VERIFY" "Using remote URL: $pods_remote_url"
    log::info "VERIFY" "Primary product: $pods_primary_product"
    log::info "VERIFY" "Version: $version"

    log_step_info "Generating minimal TestApp"

    # Create main.swift (SwiftUI minimal app) with dynamic import
    cat > "$testapp_dir/main.swift" << EOF
import SwiftUI
import ${pods_primary_product}

@main
struct TestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            Text("MSP Verification Test")
                .font(.title)
            Text("If you see this, the app built successfully.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
EOF

    log_step_info "Generating Podfile"

    cat > "$testapp_dir/Podfile" << EOF
source '$pods_remote_url'
source 'https://cdn.cocoapods.org/'

platform :ios, '15.0'
use_frameworks!

target 'TestApp' do
  pod '${pods_primary_product}', '~> $version'
end
EOF

    log::info "VERIFY" "Podfile created with version constraint: ~> $version"
    log::info "VERIFY" "Podfile uses remote source: $pods_remote_url"

    log_step_info "Updating CocoaPods repository"
    if ! pod repo update 2>&1 | grep -v "Updating spec repo" | grep -v "^$" || true; then
        log::warn "VERIFY" "pod repo update had warnings (continuing)"
    fi

    log_step_info "Checking if version $version is available remotely"
    if ! pod search MSPCore --simple 2>/dev/null | grep -q "$version"; then
        log::warn "VERIFY" "Version $version may not be available in pod search (this is normal for very recent releases)"
        log::info "VERIFY" "Attempting pod install anyway..."
    fi

    log_step_info "Installing pods from remote trunk"
    local install_exit_code=0
    if ! pod install --silent 2>&1; then
        install_exit_code=$?
        log::error "VERIFY" "pod install failed"
        log::info "VERIFY" "This may indicate:"
        log::info "VERIFY" "  - Version $version is not yet available in CocoaPods trunk"
        log::info "VERIFY" "  - Network connectivity issues"
        log::info "VERIFY" "  - Podspec validation errors"
        msp_state_mark_step_failed "pods_remote_verify" "pod install failed" "$install_exit_code"
        return 1
    fi

    log::success "VERIFY" "Pods installed successfully"

    if [[ ! -f "$testapp_dir/TestApp.xcworkspace/contents.xcworkspacedata" ]]; then
        log::error "VERIFY" "Workspace file not found after pod install"
        msp_state_mark_step_failed "pods_remote_verify" "Workspace file not found after pod install" "1"
        return 1
    fi

    log::info "VERIFY" "Workspace created: TestApp.xcworkspace"

    log_step_info "Building TestApp with xcodebuild"

    local build_output
    local build_exit_code

    if [[ "${VERBOSE:-false}" == "true" ]]; then
        log::info "VERIFY" "Running: xcodebuild -workspace TestApp.xcworkspace -scheme TestApp -sdk iphonesimulator -destination "$VERIFY_SIMULATOR_DESTINATION""
        if xcodebuild -workspace TestApp.xcworkspace \
                      -scheme TestApp \
                      -sdk iphonesimulator \
                      -destination "$VERIFY_SIMULATOR_DESTINATION" \
                      build 2>&1; then
            build_exit_code=0
        else
            build_exit_code=$?
        fi
    else
        build_output=$(xcodebuild -workspace TestApp.xcworkspace \
                                  -scheme TestApp \
                                  -sdk iphonesimulator \
                                  -destination "$VERIFY_SIMULATOR_DESTINATION" \
                                  build 2>&1)
        build_exit_code=$?
    fi

    if [[ $build_exit_code -ne 0 ]]; then
        log::error "VERIFY" "xcodebuild failed with exit code $build_exit_code"
        if [[ "${VERBOSE:-false}" != "true" && -n "$build_output" ]]; then
            log::info "VERIFY" "Build output (last 20 lines):"
            echo "$build_output" | tail -20 | sed 's/^/  /'
        fi
        msp_state_mark_step_failed "pods_remote_verify" "xcodebuild failed" "$build_exit_code"
        return 1
    fi

    log::success "VERIFY" "Build succeeded"

    log_step_info "Validating installed frameworks"

    local derived_data
    derived_data=$(xcodebuild -workspace TestApp.xcworkspace -showBuildSettings 2>/dev/null | grep -m1 "BUILD_DIR" | sed 's/.*= *//' | sed 's/Build\/Products/DerivedData/' || echo "")

    if [[ -n "$derived_data" ]]; then
        local framework_path="$derived_data/Build/Products/Debug-iphonesimulator"
        if [[ -d "$framework_path" ]]; then
            local msp_frameworks
            msp_frameworks=$(find "$framework_path" -name "*.framework" -type d 2>/dev/null | grep -i "msp\|nova" | wc -l | tr -d ' ')
            if [[ "$msp_frameworks" -gt 0 ]]; then
                log::info "VERIFY" "Found $msp_frameworks MSP-related framework(s) in build products"
            else
                log::warn "VERIFY" "No MSP frameworks found in build products (may be normal for static linking)"
            fi
        fi
    fi

    ui_divider
    log::success "VERIFY" "Pods Remote Verification Summary"
    ui_kv "Remote pods available" "YES"
    ui_kv "Build succeeded" "YES"
    ui_kv "Installed version" "$version"
    ui_kv "Sandbox directory" "$sandbox_path"
    ui_divider

    msp_state_mark_step_success "pods_remote_verify"
    return 0
}

# Run remote CocoaPods verification (wrapper for dispatch)
_run_remote_pods_verification() {
    local version="$1"
    local sandbox_path="$2"

    verify_pods_remote "$version"
}

# ============================================================================
# SPM Remote Verification
# ============================================================================
verify_spm_remote() {
    local version="$1"

    if [[ -z "$version" ]]; then
        log::error "VERIFY" "Version is required for SPM remote verification"
        return 1
    fi

    # Check if we should skip this step in resume mode
    if [[ "${MSP_RESUME_MODE:-0}" == "1" ]]; then
        local status
        status="$(msp_state_get_step_status "spm_remote_verify" 2>/dev/null || echo "unknown")"
        if [[ "$status" == "success" || "$status" == "skipped" ]]; then
            log::info "VERIFY" "Resuming: skipping spm_remote_verify (status already ${status})"
            return 0
        fi
    fi

    msp_state_mark_step_running "spm_remote_verify"

    log_step_info "SPM Remote Verification"

    # DRY_RUN shortcut
    local dry_run_value="${DRY_RUN:-false}"
    if [[ "$dry_run_value" == "true" ]] || [[ "$dry_run_value" == "1" ]] || [[ "$dry_run_value" == "yes" ]]; then
        log::info "VERIFY" "[DRY RUN] Skipping SPM remote verification"
        msp_state_mark_step_skipped "spm_remote_verify" "SPM remote verify skipped due to DRY_RUN"
        return 0
    fi

    # Configuration: Read from environment with defaults
    local spm_remote_url="${SPM_REMOTE_URL:-}"
    local spm_package_name="${SPM_REMOTE_PACKAGE_NAME:-msp-ios-sdk}"
    local spm_product_name="${SPM_REMOTE_PRODUCT_NAME:-MSPAds}"

    # Fallback to default if empty
    if [[ -z "$spm_product_name" ]]; then
        spm_product_name="MSPAds"
    fi

    # Check if SPM_REMOTE_URL is set
    if [[ -z "$spm_remote_url" ]]; then
        log::warn "VERIFY" "SPM_REMOTE_URL is not set. Skipping SPM remote verification."
        log::info "VERIFY" "To enable SPM verification, set SPM_REMOTE_URL environment variable."
        msp_state_mark_step_skipped "spm_remote_verify" "SPM remote verify skipped due to SPM_REMOTE_URL not set"
        return 0
    fi

    log::info "VERIFY" "Using remote URL: $spm_remote_url"
    log::info "VERIFY" "Package name: $spm_package_name"
    log::info "VERIFY" "Product name: $spm_product_name"
    log::info "VERIFY" "Version: $version"

    # Use sandbox for isolation (T060)
    local sandbox_path
    if sandbox_is_active; then
        sandbox_path=$(sandbox_get_path)
    else
        sandbox_path=$(sandbox_create "spm-verify")
    fi

    local test_dir
    test_dir=$(sandbox_mkdir "TestSPMApp")

    log_step_info "Creating temporary SPM test package"
    log::info "VERIFY" "Sandbox directory: $sandbox_path"

    cd "$test_dir" || {
        log::error "VERIFY" "Failed to change to test directory"
        msp_state_mark_step_failed "spm_remote_verify" "Failed to change to test directory" "1"
        return 1
    }

    log_step_info "Initializing SwiftPM test package"

    if ! swift package init --type executable --name TestSPMApp 2>&1; then
        log::error "VERIFY" "Failed to initialize Swift package"
        msp_state_mark_step_failed "spm_remote_verify" "Failed to initialize Swift package" "1"
        return 1
    fi

    log::success "VERIFY" "Swift package initialized"

    # Patch Package.swift to add remote dependency
    log_step_info "Adding remote SPM dependency to Package.swift"

    local package_swift="$test_dir/Package.swift"
    if [[ ! -f "$package_swift" ]]; then
        log::error "VERIFY" "Package.swift not found after initialization"
        msp_state_mark_step_failed "spm_remote_verify" "Package.swift not found after initialization" "1"
        return 1
    fi

    cat > "$package_swift" << EOF
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TestSPMApp",
    dependencies: [
        .package(url: "$spm_remote_url", .exact("$version"))
    ],
    targets: [
        .executableTarget(
            name: "TestSPMApp",
            dependencies: [
                .product(name: "${spm_product_name}", package: "$spm_package_name")
            ]
        )
    ]
)
EOF

    log::info "VERIFY" "Package.swift updated with remote dependency"

    log_step_info "Updating main.swift to use remote product"

    local main_swift="$test_dir/Sources/TestSPMApp/main.swift"
    if [[ -f "$main_swift" ]]; then
        cat > "$main_swift" << EOF
import Foundation
import ${spm_product_name}
// Import the remote product to verify it's available
// Note: This is a minimal test - actual usage would require proper imports

print("MSP SPM Verification Test")
print("If you see this, the package resolved and built successfully.")
EOF
        log::info "VERIFY" "main.swift updated with import: $spm_product_name"
    fi

    log_step_info "Resolving Swift package dependencies"

    local resolve_output
    local resolve_exit_code

    if [[ "${VERBOSE:-false}" == "true" ]]; then
        if swift package resolve 2>&1; then
            resolve_exit_code=0
        else
            resolve_exit_code=$?
        fi
    else
        resolve_output=$(swift package resolve 2>&1)
        resolve_exit_code=$?
    fi

    if [[ $resolve_exit_code -ne 0 ]]; then
        log::error "VERIFY" "swift package resolve failed (exit code: $resolve_exit_code)"
        if [[ "${VERBOSE:-false}" != "true" && -n "$resolve_output" ]]; then
            log::info "VERIFY" "Resolve output (last 20 lines):"
            echo "$resolve_output" | tail -20 | sed 's/^/  /'
        fi
        log::info "VERIFY" "This may indicate:"
        log::info "VERIFY" "  - Version $version is not yet available in the remote repository"
        log::info "VERIFY" "  - Network connectivity issues"
        log::info "VERIFY" "  - Invalid remote URL: $spm_remote_url"

        # Check strict mode
        if [[ "${VERIFY_SPM_STRICT:-true}" == "true" ]]; then
            log::error "VERIFY" "SPM remote verification FAILED (strict mode). Blocking release."
            msp_state_mark_step_failed "spm_remote_verify" "swift package resolve failed (strict mode)" "$resolve_exit_code"
            return 1
        else
            log::warn "VERIFY" "SPM remote verification failed (soft mode). Continuing."
            msp_state_mark_step_skipped "spm_remote_verify" "swift package resolve failed (soft mode)"
            return 0
        fi
    fi

    log::success "VERIFY" "Swift package resolved successfully"

    log_step_info "Building Swift package"

    local build_output
    local build_exit_code

    if [[ "${VERBOSE:-false}" == "true" ]]; then
        if swift build 2>&1; then
            build_exit_code=0
        else
            build_exit_code=$?
        fi
    else
        build_output=$(swift build 2>&1)
        build_exit_code=$?
    fi

    if [[ $build_exit_code -ne 0 ]]; then
        log::error "VERIFY" "swift build failed (exit code: $build_exit_code)"
        if [[ "${VERBOSE:-false}" != "true" && -n "$build_output" ]]; then
            log::info "VERIFY" "Build output (last 20 lines):"
            echo "$build_output" | tail -20 | sed 's/^/  /'
        fi
        log::info "VERIFY" "This may indicate:"
        log::info "VERIFY" "  - Build errors in the remote package"
        log::info "VERIFY" "  - Incompatible Swift version"
        log::info "VERIFY" "  - Missing dependencies"

        # Check strict mode
        if [[ "${VERIFY_SPM_STRICT:-true}" == "true" ]]; then
            log::error "VERIFY" "SPM remote verification FAILED (strict mode). Blocking release."
            msp_state_mark_step_failed "spm_remote_verify" "swift build failed (strict mode)" "$build_exit_code"
            return 1
        else
            log::warn "VERIFY" "SPM remote verification failed (soft mode). Continuing."
            msp_state_mark_step_skipped "spm_remote_verify" "swift build failed (soft mode)"
            return 0
        fi
    fi

    log::success "VERIFY" "Swift package built successfully"

    ui_divider
    log::success "VERIFY" "SPM Remote Verification Summary"
    ui_kv "Remote URL" "$spm_remote_url"
    ui_kv "Version" "$version"
    ui_kv "Package" "$spm_package_name"
    ui_kv "Product" "$spm_product_name"
    ui_kv "Resolved" "YES"
    ui_kv "Built" "YES"
    ui_kv "Sandbox directory" "$sandbox_path"
    ui_divider

    msp_state_mark_step_success "spm_remote_verify"
    return 0
}

# Run remote SPM verification (wrapper for dispatch)
_run_remote_spm_verification() {
    local version="$1"
    local sandbox_path="$2"

    verify_spm_remote "$version"
}

# Run sample app verification
_run_sample_app_verification() {
    local version="$1"
    local sandbox_path="$2"

    log_step_info "Sample app verification"

    local script_path="$SCRIPT_DIR/verify_local/sample_app.sh"
    if [[ -f "$script_path" ]]; then
        source "$script_path"
        verify_sample_app "$version" "$sandbox_path"
    else
        log::warn "VERIFY" "Sample app verification script not found: $script_path"
        log::info "VERIFY" "Skipping sample app verification (script not implemented)"
        return 0
    fi
}

# Run device verification (optional)
_run_device_verification() {
    local version="$1"
    local sandbox_path="$2"

    log_step_info "Device verification (optional)"

    local script_path="$SCRIPT_DIR/verify_local_device/device.sh"
    if [[ -f "$script_path" ]]; then
        source "$script_path"
        verify_device "$version" "$sandbox_path"
    else
        log::info "VERIFY" "Device verification script not found: $script_path"
        log::info "VERIFY" "Skipping device verification (optional)"
        return 0
    fi
}

# ============================================================================
# Main Verification Entrypoint (Phase 4 Structure)
# ============================================================================

# Main verification dispatcher
# @description Orchestrates Phase 4 verification with proper logging structure
# @param $1 version - Release version to verify
# @param $@ remaining args - Optional flags (--type=<type>, --sandbox-dir=<path>)
# @return 0 on success, 1 on failure
verify_main() {
    local version=""
    local specific_type=""
    local custom_sandbox_dir=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type=*)
                specific_type="${1#--type=}"
                shift
                ;;
            --sandbox-dir=*)
                custom_sandbox_dir="${1#--sandbox-dir=}"
                shift
                ;;
            *)
                if [[ -z "$version" ]]; then
                    version="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$version" ]]; then
        log::error "VERIFY" "Version is required for verification"
        echo "Usage: verify_main <version> [--type=<type>] [--sandbox-dir=<path>]"
        return 1
    fi

    # Early exit: verification only runs in full mode
    if _check_simple_mode; then
        return 0
    fi

    # Start Phase 4 logging
    log_phase_start $PHASE_VERIFY

    local verify_status="success"
    local sandbox_path=""

    # Step 1: Initialize sandbox
    log_step_info "Initializing verification sandbox"

    if [[ -n "$custom_sandbox_dir" ]]; then
        export MSP_SANDBOX_DIR="$custom_sandbox_dir"
    fi

    sandbox_path=$(sandbox_create "verify-${version}")
    if [[ -z "$sandbox_path" ]]; then
        log_step_error "Failed to create verification sandbox"
        log_phase_end "failed"
        return 1
    fi

    log::info "VERIFY" "Sandbox created: $sandbox_path"
    log::info "VERIFY" "Version: $version"

    # Determine which verifications to run
    local verifications_to_run=()

    if [[ -n "$specific_type" ]]; then
        # Run only specific type
        verifications_to_run+=("$specific_type")
    else
        # Run all enabled verifications based on config
        # Default: remote_pods and remote_spm (local, sample_app, device are optional)
        if [[ "${VERIFY_LOCAL:-false}" == "true" ]]; then
            verifications_to_run+=("local")
        fi
        verifications_to_run+=("remote_pods")
        verifications_to_run+=("remote_spm")
        if [[ "${VERIFY_SAMPLE_APP:-false}" == "true" ]]; then
            verifications_to_run+=("sample_app")
        fi
        if [[ "${VERIFY_DEVICE:-false}" == "true" ]]; then
            verifications_to_run+=("device")
        fi
    fi

    log::info "VERIFY" "Verifications to run: ${verifications_to_run[*]}"

    # Run verifications
    local failed_verifications=()

    for verify_type in "${verifications_to_run[@]}"; do
        log::info "VERIFY" "Running verification: $verify_type"

        if ! _dispatch_verification "$verify_type" "$version" "$sandbox_path"; then
            log::error "VERIFY" "Verification failed: $verify_type"
            failed_verifications+=("$verify_type")
            verify_status="failed"

            # Check if we should continue on failure
            if [[ "${VERIFY_CONTINUE_ON_FAILURE:-false}" != "true" ]]; then
                log::error "VERIFY" "Stopping verification (set VERIFY_CONTINUE_ON_FAILURE=true to continue)"
                break
            fi
        else
            log::success "VERIFY" "Verification passed: $verify_type"
        fi
    done

    # Step 6: Cleanup sandbox
    log_step_info "Cleanup verification sandbox"

    if [[ "$verify_status" == "success" ]]; then
        sandbox_cleanup
        log::success "VERIFY" "Sandbox cleaned up successfully"
    else
        if [[ "${DEBUG:-false}" == "true" ]] || [[ "${VERBOSE:-false}" == "true" ]]; then
            log::warn "VERIFY" "Keeping sandbox for inspection (DEBUG/VERBOSE mode): $sandbox_path"
        else
            sandbox_cleanup
        fi
    fi

    # End Phase 4 logging
    log_phase_end "$verify_status"

    # Summary
    if [[ "$verify_status" == "success" ]]; then
        log::success "VERIFY" "All verifications passed!"
        return 0
    else
        log::error "VERIFY" "Verification failed: ${failed_verifications[*]}"
        return 1
    fi
}

# CLI entrypoint when script is executed directly
_verify_cli() {
    verify_main "$@"
}

# Export functions
export -f verify_pods_remote verify_spm_remote verify_main
export -f _dispatch_verification _run_local_verification _run_remote_pods_verification
export -f _run_remote_spm_verification _run_sample_app_verification _run_device_verification

# Run CLI if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _verify_cli "$@"
fi
