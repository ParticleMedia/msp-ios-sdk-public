#!/usr/bin/env bash
# ============================================================================
# MSP iOS SDK - Local SPM Verification
# ============================================================================
# Module: verify_local/spm.sh
# Purpose: Verify local Swift Package Manager build
# Created for: T063
#
# Description:
#   Performs local verification by building a test package against the local
#   Package.swift before publishing. This catches SPM configuration errors early.
#
# Usage:
#   source verify_local/spm.sh
#   verify_local_spm "1.0.0" "/tmp/sandbox"
#
# Environment Variables:
#   SPM_LOCAL_PATH: Path to local Package.swift (default: ROOT_DIR)
#   SPM_PRODUCT_NAME: Product to test (default: MSPAds)
#   VERIFY_TIMEOUT_LOCAL: Timeout in seconds (default: 300)
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_VERIFY_LOCAL_SPM_SOURCED:-}" ]] && return 0
readonly _VERIFY_LOCAL_SPM_SOURCED=1

# ============================================================================
# Configuration
# ============================================================================

# Default timeout for local verification (5 minutes)
readonly VERIFY_SPM_LOCAL_TIMEOUT="${VERIFY_TIMEOUT_LOCAL:-300}"

# ============================================================================
# Main Verification Function
# ============================================================================

# Verify local SPM build
# @param $1 version - Release version
# @param $2 sandbox_path - Path to sandbox directory
# @return 0 on success, 1 on failure
verify_local_spm() {
    local version="$1"
    local sandbox_path="$2"

    if [[ -z "$version" ]]; then
        log::error "VERIFY_LOCAL_SPM" "Version is required"
        return 1
    fi

    if [[ -z "$sandbox_path" ]] || [[ ! -d "$sandbox_path" ]]; then
        log::error "VERIFY_LOCAL_SPM" "Valid sandbox path required: $sandbox_path"
        return 1
    fi

    # Check resume mode
    if [[ "${MSP_RESUME_MODE:-0}" == "1" ]]; then
        local status
        status="$(msp_state_get_step_status "spm_local_verify" 2>/dev/null || echo "unknown")"
        if [[ "$status" == "success" || "$status" == "skipped" ]]; then
            log::info "VERIFY_LOCAL_SPM" "Resuming: skipping spm_local_verify (status: ${status})"
            return 0
        fi
    fi

    msp_state_mark_step_running "spm_local_verify"

    log_step_info "Local SPM Verification"

    # DRY_RUN check
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log::info "VERIFY_LOCAL_SPM" "DRY RUN: Skipping local SPM verification"
        msp_state_mark_step_skipped "spm_local_verify" "Skipped due to DRY_RUN"
        return 0
    fi

    # Configuration
    local spm_local_path="${SPM_LOCAL_PATH:-$ROOT_DIR}"
    local spm_product_name="${SPM_PRODUCT_NAME:-MSPAds}"

    # Check if Package.swift exists
    if [[ ! -f "$spm_local_path/Package.swift" ]]; then
        log::warn "VERIFY_LOCAL_SPM" "Package.swift not found at: $spm_local_path"
        log::info "VERIFY_LOCAL_SPM" "Skipping local SPM verification"
        msp_state_mark_step_skipped "spm_local_verify" "Package.swift not found"
        return 0
    fi

    log::info "VERIFY_LOCAL_SPM" "Local Package.swift path: $spm_local_path"
    log::info "VERIFY_LOCAL_SPM" "Product name: $spm_product_name"
    log::info "VERIFY_LOCAL_SPM" "Version: $version"

    # Create test package directory in sandbox
    local testpkg_dir="$sandbox_path/LocalSPMTest"
    mkdir -p "$testpkg_dir"

    cd "$testpkg_dir" || {
        log::error "VERIFY_LOCAL_SPM" "Failed to enter test package directory"
        msp_state_mark_step_failed "spm_local_verify" "Failed to enter test directory" "1"
        return 1
    }

    log_step_info "Initializing local SPM test package"

    if ! swift package init --type executable --name LocalSPMTest 2>&1; then
        log::error "VERIFY_LOCAL_SPM" "Failed to initialize Swift package"
        msp_state_mark_step_failed "spm_local_verify" "Failed to init package" "1"
        return 1
    fi

    log_step_info "Generating Package.swift with local path"

    cat > "$testpkg_dir/Package.swift" << EOF
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocalSPMTest",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    dependencies: [
        .package(path: "$spm_local_path")
    ],
    targets: [
        .executableTarget(
            name: "LocalSPMTest",
            dependencies: [
                .product(name: "$spm_product_name", package: "msp-ios-sdk")
            ]
        )
    ]
)
EOF

    log::info "VERIFY_LOCAL_SPM" "Package.swift created with local path"

    log_step_info "Updating main.swift"

    local main_swift="$testpkg_dir/Sources/LocalSPMTest/main.swift"
    if [[ -f "$main_swift" ]] || [[ -f "$testpkg_dir/Sources/main.swift" ]]; then
        # Handle both Swift 5.9 and earlier layouts
        main_swift=$(find "$testpkg_dir/Sources" -name "main.swift" -o -name "LocalSPMTest.swift" | head -1)
        if [[ -n "$main_swift" ]]; then
            cat > "$main_swift" << EOF
import Foundation
import $spm_product_name

print("MSP Local SPM Verification")
print("Version: $version")
print("Product: $spm_product_name")
print("If you see this, the local package resolved successfully.")
EOF
            log::info "VERIFY_LOCAL_SPM" "main.swift updated with import"
        fi
    fi

    log_step_info "Resolving local SPM dependencies"

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
        log::error "VERIFY_LOCAL_SPM" "swift package resolve failed (exit code: $resolve_exit_code)"
        if [[ "${VERBOSE:-false}" != "true" && -n "${resolve_output:-}" ]]; then
            log::info "VERIFY_LOCAL_SPM" "Output (last 20 lines):"
            echo "$resolve_output" | tail -20 | sed 's/^/  /'
        fi
        msp_state_mark_step_failed "spm_local_verify" "swift package resolve failed" "$resolve_exit_code"
        return 1
    fi

    log::success "VERIFY_LOCAL_SPM" "Dependencies resolved"

    log_step_info "Building local SPM package"

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
        log::error "VERIFY_LOCAL_SPM" "swift build failed (exit code: $build_exit_code)"
        if [[ "${VERBOSE:-false}" != "true" && -n "${build_output:-}" ]]; then
            log::info "VERIFY_LOCAL_SPM" "Build output (last 30 lines):"
            echo "$build_output" | tail -30 | sed 's/^/  /'
        fi
        msp_state_mark_step_failed "spm_local_verify" "swift build failed" "$build_exit_code"
        return 1
    fi

    log::success "VERIFY_LOCAL_SPM" "Local SPM build succeeded"

    # Summary
    ui_divider
    log::success "VERIFY_LOCAL_SPM" "Local SPM Verification Summary"
    ui_kv "Local path" "$spm_local_path"
    ui_kv "Product" "$spm_product_name"
    ui_kv "Version" "$version"
    ui_kv "Resolve" "SUCCESS"
    ui_kv "Build" "SUCCESS"
    ui_divider

    msp_state_mark_step_success "spm_local_verify"
    return 0
}

# Export function
export -f verify_local_spm
