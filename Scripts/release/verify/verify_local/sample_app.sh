#!/usr/bin/env bash
# ============================================================================
# MSP iOS SDK - Sample App Build Verification
# ============================================================================
# Module: verify_local/sample_app.sh
# Purpose: Verify the demo/sample app builds correctly with the release
# Created for: T066
#
# Description:
#   Builds the project's sample/demo application to verify that the released
#   SDK integrates correctly in a real-world scenario.
#
# Usage:
#   source verify_local/sample_app.sh
#   verify_sample_app "1.0.0" "/tmp/sandbox"
#
# Environment Variables:
#   SAMPLE_APP_PATH: Path to sample app directory (default: ROOT_DIR/Example)
#   SAMPLE_APP_WORKSPACE: Workspace name (default: Example.xcworkspace)
#   SAMPLE_APP_SCHEME: Build scheme (default: Example)
#   VERIFY_TIMEOUT_SAMPLE: Timeout in seconds (default: 600)
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_VERIFY_SAMPLE_APP_SOURCED:-}" ]] && return 0
readonly _VERIFY_SAMPLE_APP_SOURCED=1

# ============================================================================
# Configuration
# ============================================================================

# Default timeout for sample app verification (10 minutes)
readonly VERIFY_SAMPLE_APP_TIMEOUT="${VERIFY_TIMEOUT_SAMPLE:-600}"

# Default sample app locations
readonly DEFAULT_SAMPLE_APP_PATHS=(
    "Example"
    "Demo"
    "SampleApp"
    "Examples/MSPDemo"
)

# ============================================================================
# Helper Functions
# ============================================================================

# Find sample app directory
# @return Path to sample app via stdout, empty if not found
_find_sample_app_dir() {
    local root_dir="${ROOT_DIR:-.}"

    # Check explicit path first
    if [[ -n "${SAMPLE_APP_PATH:-}" ]] && [[ -d "$SAMPLE_APP_PATH" ]]; then
        echo "$SAMPLE_APP_PATH"
        return 0
    fi

    # Check common paths
    for path in "${DEFAULT_SAMPLE_APP_PATHS[@]}"; do
        local full_path="$root_dir/$path"
        if [[ -d "$full_path" ]]; then
            # Verify it has a workspace or project
            if ls "$full_path"/*.xcworkspace 1>/dev/null 2>&1 || \
               ls "$full_path"/*.xcodeproj 1>/dev/null 2>&1; then
                echo "$full_path"
                return 0
            fi
        fi
    done

    return 1
}

# Find workspace or project in directory
# @param $1 dir - Directory to search
# @return Workspace/project name via stdout
_find_xcode_target() {
    local dir="$1"

    # Prefer workspace
    local workspace
    workspace=$(ls "$dir"/*.xcworkspace 2>/dev/null | head -1)
    if [[ -n "$workspace" ]]; then
        echo "$(basename "$workspace")"
        echo "workspace"
        return 0
    fi

    # Fall back to project
    local project
    project=$(ls "$dir"/*.xcodeproj 2>/dev/null | head -1)
    if [[ -n "$project" ]]; then
        echo "$(basename "$project")"
        echo "project"
        return 0
    fi

    return 1
}

# ============================================================================
# Main Verification Function
# ============================================================================

# Verify sample app build
# @param $1 version - Release version
# @param $2 sandbox_path - Path to sandbox directory (used for build output)
# @return 0 on success, 1 on failure
verify_sample_app() {
    local version="$1"
    local sandbox_path="${2:-}"

    if [[ -z "$version" ]]; then
        log::error "VERIFY_SAMPLE" "Version is required"
        return 1
    fi

    # Check resume mode
    if [[ "${MSP_RESUME_MODE:-0}" == "1" ]]; then
        local status
        status="$(msp_state_get_step_status "sample_app_verify" 2>/dev/null || echo "unknown")"
        if [[ "$status" == "success" || "$status" == "skipped" ]]; then
            log::info "VERIFY_SAMPLE" "Resuming: skipping sample_app_verify (status: ${status})"
            return 0
        fi
    fi

    msp_state_mark_step_running "sample_app_verify"

    log_step_info "Sample App Build Verification"

    # DRY_RUN check
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log::info "VERIFY_SAMPLE" "DRY RUN: Skipping sample app verification"
        msp_state_mark_step_skipped "sample_app_verify" "Skipped due to DRY_RUN"
        return 0
    fi

    # Find sample app
    local sample_app_dir
    sample_app_dir=$(_find_sample_app_dir) || {
        log::warn "VERIFY_SAMPLE" "Sample app directory not found"
        log::info "VERIFY_SAMPLE" "Checked paths: ${DEFAULT_SAMPLE_APP_PATHS[*]}"
        log::info "VERIFY_SAMPLE" "Set SAMPLE_APP_PATH to specify custom location"
        msp_state_mark_step_skipped "sample_app_verify" "Sample app not found"
        return 0
    }

    log::info "VERIFY_SAMPLE" "Sample app directory: $sample_app_dir"

    # Find workspace or project
    local xcode_info
    xcode_info=$(_find_xcode_target "$sample_app_dir") || {
        log::warn "VERIFY_SAMPLE" "No workspace or project found in: $sample_app_dir"
        msp_state_mark_step_skipped "sample_app_verify" "No Xcode target found"
        return 0
    }

    local xcode_target xcode_type
    xcode_target=$(echo "$xcode_info" | head -1)
    xcode_type=$(echo "$xcode_info" | tail -1)

    # Determine scheme
    local scheme="${SAMPLE_APP_SCHEME:-}"
    if [[ -z "$scheme" ]]; then
        # Default to target name without extension
        scheme="${xcode_target%.*}"
    fi

    log::info "VERIFY_SAMPLE" "Building: $xcode_target ($xcode_type)"
    log::info "VERIFY_SAMPLE" "Scheme: $scheme"
    log::info "VERIFY_SAMPLE" "Version: $version"

    # Change to sample app directory
    cd "$sample_app_dir" || {
        log::error "VERIFY_SAMPLE" "Failed to enter sample app directory"
        msp_state_mark_step_failed "sample_app_verify" "Failed to enter directory" "1"
        return 1
    }

    if [[ -f "Podfile" ]]; then
        log_step_info "Running pod install for sample app"

        local pod_exit_code=0
        if [[ "${VERBOSE:-false}" == "true" ]]; then
            if ! pod install 2>&1; then
                pod_exit_code=$?
            fi
        else
            if ! pod install --silent 2>&1; then
                pod_exit_code=$?
            fi
        fi

        if [[ $pod_exit_code -ne 0 ]]; then
            log::error "VERIFY_SAMPLE" "pod install failed for sample app"
            msp_state_mark_step_failed "sample_app_verify" "pod install failed" "$pod_exit_code"
            return 1
        fi

        log::success "VERIFY_SAMPLE" "Pods installed for sample app"
    fi

    log_step_info "Building sample app"

    local build_output
    local build_exit_code=0

    local xcodebuild_cmd=(xcodebuild)

    if [[ "$xcode_type" == "workspace" ]]; then
        xcodebuild_cmd+=(-workspace "$xcode_target")
    else
        xcodebuild_cmd+=(-project "$xcode_target")
    fi

    xcodebuild_cmd+=(
        -scheme "$scheme"
        -sdk iphonesimulator
        -destination 'platform=iOS Simulator,name=iPhone 15'
        -configuration Debug
        build
    )

    # Use derived data in sandbox if available
    if [[ -n "$sandbox_path" ]] && [[ -d "$sandbox_path" ]]; then
        xcodebuild_cmd+=(-derivedDataPath "$sandbox_path/DerivedData")
    fi

    if [[ "${VERBOSE:-false}" == "true" ]]; then
        log::info "VERIFY_SAMPLE" "Running: ${xcodebuild_cmd[*]}"
        if ! "${xcodebuild_cmd[@]}" 2>&1; then
            build_exit_code=$?
        fi
    else
        build_output=$("${xcodebuild_cmd[@]}" 2>&1) || build_exit_code=$?
    fi

    if [[ $build_exit_code -ne 0 ]]; then
        log::error "VERIFY_SAMPLE" "Sample app build failed (exit: $build_exit_code)"
        if [[ "${VERBOSE:-false}" != "true" && -n "${build_output:-}" ]]; then
            log::info "VERIFY_SAMPLE" "Build output (last 40 lines):"
            echo "$build_output" | tail -40 | sed 's/^/  /'
        fi
        msp_state_mark_step_failed "sample_app_verify" "Build failed" "$build_exit_code"
        return 1
    fi

    log::success "VERIFY_SAMPLE" "Sample app built successfully"

    # Summary
    ui_divider
    log::success "VERIFY_SAMPLE" "Sample App Verification Complete"
    ui_kv "Directory" "$sample_app_dir"
    ui_kv "Target" "$xcode_target"
    ui_kv "Scheme" "$scheme"
    ui_kv "Build" "SUCCESS"
    ui_divider

    msp_state_mark_step_success "sample_app_verify"
    return 0
}

# Export function
export -f verify_sample_app
