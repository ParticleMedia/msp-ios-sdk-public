#!/usr/bin/env bash
# ============================================================================
# Release Verification Module
# ============================================================================
# Module: orchestrator/lib/verification.sh
# Purpose: Verification functions for release orchestration
#
# Functions:
#   - run_remote_verification: Run remote SPM/Pods verification
#   - run_device_verification: Run device verification
#   - run_xcframework_verification: Run XCFramework deep verification
#
# Config-Driven:
#   - MSP_VERIFY_REMOTE: Enable remote verification (default: true)
#   - MSP_VERIFY_DEVICE: Enable device verification (default: true)
#   - MSP_VERIFY_XCF: Enable XCFramework verification (default: true)
#
# Dependencies:
#   - step_lifecycle.sh (step_skip, mark_step_* functions)
#   - state.sh (msp_state_* functions)
#   - jq CLI (for JSON state updates)
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_ORCH_VERIFICATION_SOURCED:-}" ]] && return 0
readonly _ORCH_VERIFICATION_SOURCED=1

# ============================================================================
# Run Remote Verification
# ============================================================================
# Runs remote verification (SPM/Pods availability checks)
# Config-driven: verify.remote flag
# ============================================================================
orch_run_remote_verification() {
    export CURRENT_STEP="run_remote_verification"

    # Config-driven gating
    if command -v is_enabled &>/dev/null && ! is_enabled "verify.remote"; then
        step_skip "run_remote_verification (config: verify.remote=false)"
        return 0
    fi

    # Environment variable check
    if [[ "${MSP_VERIFY_REMOTE:-true}" != "true" ]]; then
        if command -v log::info &>/dev/null; then
            log::info "VERIFY" "Remote verification disabled (MSP_VERIFY_REMOTE=false)"
        fi
        return 0
    fi

    if command -v log_section &>/dev/null; then
        log_section "Remote Verification"
    fi

    local root_dir="${ROOT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
    local verify_script="$root_dir/Scripts/release/verify_remote/run_all.sh"

    if [[ ! -f "$verify_script" ]]; then
        if command -v log::warn &>/dev/null; then
            log::warn "VERIFY" "Remote verification script not found, skipping"
        fi
        return 0
    fi

    # Run remote verification (soft-fail: never breaks release)
    if source "$verify_script" && run_all_remote_verification 2>/dev/null; then
        if command -v log::info &>/dev/null; then
            log::info "VERIFY" "Remote verification completed"
        fi
    else
        if command -v log::warn &>/dev/null; then
            log::warn "VERIFY" "Remote verification encountered errors (non-blocking)"
        fi
    fi

    # Write results to state file
    _write_remote_verify_state "$root_dir"

    return 0
}

# ============================================================================
# Run Device Verification
# ============================================================================
# Runs device verification (build and deploy to device)
# Config-driven: verify.device flag
# ============================================================================
orch_run_device_verification() {
    export CURRENT_STEP="run_device_verification"

    # Environment variable check
    if [[ "${MSP_VERIFY_DEVICE:-true}" != "true" ]]; then
        if command -v log::info &>/dev/null; then
            log::info "VERIFY" "Device verification disabled (MSP_VERIFY_DEVICE=false)"
        fi
        return 0
    fi

    if command -v log_section &>/dev/null; then
        log_section "Device Verification"
    fi

    local root_dir="${ROOT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
    local verify_script="$root_dir/Scripts/release/verify_local_device/run_device.sh"

    if [[ ! -f "$verify_script" ]]; then
        if command -v log::warn &>/dev/null; then
            log::warn "VERIFY" "Device verification script not found, skipping"
        fi
        return 0
    fi

    # Run device verification (soft-fail: never breaks release)
    # Note: Using subshell to avoid function name collision
    if ( source "$verify_script" && run_device_verification ) 2>/dev/null; then
        if command -v log::info &>/dev/null; then
            log::info "VERIFY" "Device verification completed"
        fi
    else
        if command -v log::warn &>/dev/null; then
            log::warn "VERIFY" "Device verification encountered errors (non-blocking)"
        fi
    fi

    # Write results to state file
    _write_device_verify_state "$root_dir"

    return 0
}

# ============================================================================
# Run XCFramework Verification
# ============================================================================
# Runs XCFramework deep verification
# Config-driven: verify.xcframework flag
# ============================================================================
orch_run_xcframework_verification() {
    export CURRENT_STEP="run_xcframework_verification"

    # Environment variable check
    if [[ "${MSP_VERIFY_XCF:-true}" != "true" ]]; then
        if command -v log::info &>/dev/null; then
            log::info "VERIFY" "XCFramework verification disabled (MSP_VERIFY_XCF=false)"
        fi
        return 0
    fi

    # Check if xcodebuild exists
    if ! command -v xcodebuild >/dev/null 2>&1; then
        if command -v log::info &>/dev/null; then
            log::info "VERIFY" "xcodebuild not found, skipping XCFramework verification"
        fi
        return 0
    fi

    if command -v log_section &>/dev/null; then
        log_section "XCFramework Deep Verification"
    fi

    local root_dir="${ROOT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
    local verify_script="$root_dir/Scripts/release/verify_xcframework/run_xcf.sh"

    if [[ ! -f "$verify_script" ]]; then
        if command -v log::warn &>/dev/null; then
            log::warn "VERIFY" "XCFramework verification script not found, skipping"
        fi
        return 0
    fi

    # Run XCFramework verification (soft-fail: never breaks release)
    # Note: Using subshell to avoid function name collision
    if ( source "$verify_script" && run_xcframework_verification ) 2>/dev/null; then
        if command -v log::info &>/dev/null; then
            log::info "VERIFY" "XCFramework verification completed"
        fi
    else
        if command -v log::warn &>/dev/null; then
            log::warn "VERIFY" "XCFramework verification encountered errors (non-blocking)"
        fi
    fi

    # Write results to state file
    _write_xcf_verify_state "$root_dir"

    return 0
}

# ============================================================================
# Internal: Write State Updates
# ============================================================================

_write_remote_verify_state() {
    local root_dir="$1"
    local state_file="$root_dir/.msp-release-state.json"

    if ! command -v msp_state_is_enabled &>/dev/null || ! msp_state_is_enabled; then
        return 0
    fi

    if [[ ! -f "$state_file" ]] || ! command -v jq >/dev/null 2>&1; then
        return 0
    fi

    local spm_executed="${REMOTE_SPM_EXECUTED:-0}"
    local spm_success="${REMOTE_SPM_SUCCESS:-0}"
    local pods_executed="${REMOTE_PODS_EXECUTED:-0}"
    local pods_success="${REMOTE_PODS_SUCCESS:-0}"

    jq ".remote_verify = {
        spm: {executed: ($spm_executed == 1), success: ($spm_success == 1)},
        pods: {executed: ($pods_executed == 1), success: ($pods_success == 1)}
    } | .timestamps.updated_at = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"" \
        "$state_file" > "${state_file}.tmp" 2>/dev/null && \
        mv "${state_file}.tmp" "$state_file" 2>/dev/null || true
}

_write_device_verify_state() {
    local root_dir="$1"
    local state_file="$root_dir/.msp-release-state.json"

    if ! command -v msp_state_is_enabled &>/dev/null || ! msp_state_is_enabled; then
        return 0
    fi

    if [[ ! -f "$state_file" ]] || ! command -v jq >/dev/null 2>&1; then
        return 0
    fi

    local device_status
    device_status="$(jq -r '.steps.run_device_verification.status // "unknown"' "$state_file" 2>/dev/null || echo "unknown")"

    local executed=false
    local success=false
    if [[ "$device_status" == "success" ]]; then
        executed=true
        success=true
    elif [[ "$device_status" == "error" ]] || [[ "$device_status" == "failed" ]]; then
        executed=true
        success=false
    fi

    local mode="${DEVICE_VERIFY_MODE:-unknown}"
    local archive_path="${DEVICE_VERIFY_ARCHIVE_PATH:-}"
    local ipa_path="${DEVICE_VERIFY_IPA_PATH:-}"

    jq ".device_verify = {
        executed: $executed,
        success: $success,
        mode: \"$mode\",
        archive_path: \"$archive_path\",
        ipa_path: \"$ipa_path\"
    } | .timestamps.updated_at = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"" \
        "$state_file" > "${state_file}.tmp" 2>/dev/null && \
        mv "${state_file}.tmp" "$state_file" 2>/dev/null || true
}

_write_xcf_verify_state() {
    local root_dir="$1"
    local state_file="$root_dir/.msp-release-state.json"

    if ! command -v msp_state_is_enabled &>/dev/null || ! msp_state_is_enabled; then
        return 0
    fi

    if [[ ! -f "$state_file" ]] || ! command -v jq >/dev/null 2>&1; then
        return 0
    fi

    local modules_json="${XCF_VERIFY_MODULES_JSON:-{}}"

    local total_modules=0
    local passed_modules=0
    local failed_modules=0

    if [[ -n "$modules_json" ]] && [[ "$modules_json" != "{}" ]]; then
        total_modules=$(echo "$modules_json" | jq 'length' 2>/dev/null || echo "0")
        passed_modules=$(echo "$modules_json" | jq '[.[] | select(.success == 1)] | length' 2>/dev/null || echo "0")
        total_modules=$(echo "${total_modules}" | tr -d '[:space:]')
        passed_modules=$(echo "${passed_modules}" | tr -d '[:space:]')
        total_modules="${total_modules:-0}"
        passed_modules="${passed_modules:-0}"
        failed_modules=$(( ${total_modules:-0} - ${passed_modules:-0} ))
    fi

    jq ".steps.run_xcframework_verification.modules = $modules_json |
        .steps.run_xcframework_verification.summary = {
          total: $total_modules,
          passed: $passed_modules,
          failed: $failed_modules
        } |
        .timestamps.updated_at = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"" \
        "$state_file" > "${state_file}.tmp" 2>/dev/null && \
        mv "${state_file}.tmp" "$state_file" 2>/dev/null || true
}

# ============================================================================
# Export Functions
# ============================================================================

export -f orch_run_remote_verification 2>/dev/null || true
export -f orch_run_device_verification 2>/dev/null || true
export -f orch_run_xcframework_verification 2>/dev/null || true
