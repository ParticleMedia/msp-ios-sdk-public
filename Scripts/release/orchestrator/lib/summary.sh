#!/usr/bin/env bash
# ============================================================================
# Release Summary Module
# ============================================================================
# Module: orchestrator/lib/summary.sh
# Purpose: Release summary display and formatting functions
#
# Functions:
#   - orch_show_release_summary: Display comprehensive release summary
#   - orch_print_step_summary: Print individual step status
#   - orch_calculate_duration: Calculate duration between timestamps
#   - orch_get_step_status_from_state: Read step status from state.json
#
# Dependencies:
#   - jq CLI (for JSON parsing)
#   - Logging functions (log::info, log::error, log::success)
#   - print_section, print_subsection (from logger.sh)
#   - Scripts/lib/shared/time_utils.sh (R012a - unified time functions)
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_ORCH_SUMMARY_SOURCED:-}" ]] && return 0
readonly _ORCH_SUMMARY_SOURCED=1

# R012a: Source time_utils.sh for unified duration calculation
_SUMMARY_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
if [[ -f "$_SUMMARY_ROOT_DIR/Scripts/lib/shared/time_utils.sh" ]]; then
    # shellcheck source=Scripts/lib/shared/time_utils.sh
    source "$_SUMMARY_ROOT_DIR/Scripts/lib/shared/time_utils.sh" 2>/dev/null || true
fi

# ============================================================================
# Calculate Duration
# ============================================================================
# Calculates duration between two timestamps.
#
# Args:
#   $1: start_time - Start time in "YYYY-MM-DD HH:MM:SS" format
#   $2: end_time - End time in "YYYY-MM-DD HH:MM:SS" format
#
# Returns:
#   Prints duration string (e.g., "5m 30s") or empty if calculation fails
# ============================================================================
orch_calculate_duration() {
    local start_time="$1"
    local end_time="$2"

    if [[ -z "$start_time" ]] || [[ -z "$end_time" ]]; then
        echo ""
        return 0
    fi

    # Try macOS date format first, then Linux
    local start_epoch end_epoch
    start_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$start_time" "+%s" 2>/dev/null || \
                  date -d "$start_time" "+%s" 2>/dev/null || echo "")
    end_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$end_time" "+%s" 2>/dev/null || \
                date -d "$end_time" "+%s" 2>/dev/null || echo "")

    if [[ -n "$start_epoch" ]] && [[ -n "$end_epoch" ]]; then
        local duration_seconds=$((end_epoch - start_epoch))
        local minutes=$((duration_seconds / 60))
        local seconds=$((duration_seconds % 60))
        echo "${minutes}m ${seconds}s"
    else
        echo ""
    fi
}

# ============================================================================
# Get Step Status from State File
# ============================================================================
# Reads step status from the release state JSON file.
#
# Args:
#   $1: state_file - Path to state.json file
#   $2: step_name - Name of the step
#
# Returns:
#   Prints status string (success, error, failed, skipped, running, unknown)
# ============================================================================
orch_get_step_status_from_state() {
    local state_file="$1"
    local step_name="$2"

    if ! command -v jq >/dev/null 2>&1; then
        echo "unknown"
        return 0
    fi

    if [[ ! -f "$state_file" ]]; then
        echo "unknown"
        return 0
    fi

    local status
    status="$(jq -r ".steps.${step_name}.status // \"unknown\"" "$state_file" 2>/dev/null || echo "unknown")"
    echo "$status"
}

# ============================================================================
# Print Step Summary
# ============================================================================
# Prints individual step status in summary format.
#
# Args:
#   $1: step_number - Step number for display
#   $2: step_name - Step identifier (for state lookup)
#   $3: step_label - Human-readable step name
#
# Environment:
#   ROOT_DIR - Project root directory
#   STEP_RESULTS - Associative array with step results (optional)
# ============================================================================
orch_print_step_summary() {
    local step_number="$1"
    local step_name="$2"
    local step_label="$3"
    local root_dir="${ROOT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
    local state_file="$root_dir/.msp-release-state.json"

    # Get status from state file
    local status
    status=$(orch_get_step_status_from_state "$state_file" "$step_name")

    # Format output based on status
    local status_icon status_text
    case "$status" in
        success)
            status_icon="✓"
            status_text="SUCCESS"
            if command -v log::success &>/dev/null; then
                log::success "SUMMARY" "  [$step_number] $step_label: $status_icon $status_text"
            else
                echo "  [$step_number] $step_label: $status_icon $status_text"
            fi
            ;;
        error|failed)
            status_icon="✗"
            status_text="FAILED"
            if command -v log::error &>/dev/null; then
                log::error "SUMMARY" "  [$step_number] $step_label: $status_icon $status_text"
            else
                echo "  [$step_number] $step_label: $status_icon $status_text"
            fi
            ;;
        skipped)
            status_icon="⊘"
            status_text="SKIPPED"
            if command -v log::info &>/dev/null; then
                log::info "SUMMARY" "  [$step_number] $step_label: $status_icon $status_text"
            else
                echo "  [$step_number] $step_label: $status_icon $status_text"
            fi
            ;;
        running)
            status_icon="⟳"
            status_text="RUNNING"
            if command -v log::info &>/dev/null; then
                log::info "SUMMARY" "  [$step_number] $step_label: $status_icon $status_text"
            else
                echo "  [$step_number] $step_label: $status_icon $status_text"
            fi
            ;;
        *)
            status_icon="?"
            status_text="UNKNOWN"
            if command -v log::info &>/dev/null; then
                log::info "SUMMARY" "  [$step_number] $step_label: $status_icon $status_text"
            else
                echo "  [$step_number] $step_label: $status_icon $status_text"
            fi
            ;;
    esac
}

# ============================================================================
# Print Module Results
# ============================================================================
# Prints results for a specific module type (CocoaPods, SPM, GitHub).
#
# Args:
#   $1: module_type - Type label (e.g., "CocoaPods", "SPM")
#   $2: success_array_name - Name of success array variable
#   $3: failed_array_name - Name of failed array variable
# ============================================================================
orch_print_module_results() {
    local module_type="$1"
    local success_array_name="$2"
    local failed_array_name="$3"

    # Use nameref to access arrays by name
    local -n success_arr="$success_array_name" 2>/dev/null || true
    local -n failed_arr="$failed_array_name" 2>/dev/null || true

    if command -v print_subsection &>/dev/null; then
        print_subsection "$module_type Module Results"
    else
        echo ""
        echo "=== $module_type Module Results ==="
    fi

    # Check if arrays exist and have elements
    if [[ -n "${success_arr+x}" ]] && [[ ${#success_arr[@]} -gt 0 ]]; then
        if command -v log::success &>/dev/null; then
            log::success "SUMMARY" "✅ Successfully Released:"
        else
            echo "✅ Successfully Released:"
        fi
        for item in "${success_arr[@]}"; do
            if command -v log::info &>/dev/null; then
                log::info "SUMMARY" "  - $item"
            else
                echo "  - $item"
            fi
        done
        echo ""
    fi

    if [[ -n "${failed_arr+x}" ]] && [[ ${#failed_arr[@]} -gt 0 ]]; then
        if command -v log::error &>/dev/null; then
            log::error "SUMMARY" "❌ Failed to Release:"
        else
            echo "❌ Failed to Release:"
        fi
        for item in "${failed_arr[@]}"; do
            if command -v log::info &>/dev/null; then
                log::info "SUMMARY" "  - $item"
            else
                echo "  - $item"
            fi
        done
        echo ""
    fi
}

# ============================================================================
# Print Verification Summary
# ============================================================================
# Prints verification results section.
#
# Args:
#   $1: verify_type - Verification type (remote, local, device, xcframework)
#   $2: state_file - Path to state file
# ============================================================================
orch_print_verification_summary() {
    local verify_type="$1"
    local state_file="$2"
    local step_name="run_${verify_type}_verification"

    if command -v print_subsection &>/dev/null; then
        print_subsection "${verify_type^} Verification"
    else
        echo ""
        echo "=== ${verify_type^} Verification ==="
    fi

    local status
    status=$(orch_get_step_status_from_state "$state_file" "$step_name")

    case "$status" in
        success)
            if command -v log::success &>/dev/null; then
                log::success "SUMMARY" "Executed: yes"
                log::success "SUMMARY" "Result: PASS"
            else
                echo "Executed: yes"
                echo "Result: PASS"
            fi
            ;;
        error|failed)
            if command -v log::info &>/dev/null; then
                log::info "SUMMARY" "Executed: yes"
            fi
            if command -v log::error &>/dev/null; then
                log::error "SUMMARY" "Result: FAIL"
            else
                echo "Executed: yes"
                echo "Result: FAIL"
            fi
            ;;
        skipped)
            if command -v log::info &>/dev/null; then
                log::info "SUMMARY" "Executed: no"
                log::info "SUMMARY" "Result: SKIPPED"
            else
                echo "Executed: no"
                echo "Result: SKIPPED"
            fi
            ;;
        *)
            if command -v log::info &>/dev/null; then
                log::info "SUMMARY" "Executed: no"
                log::info "SUMMARY" "Result: N/A"
            else
                echo "Executed: no"
                echo "Result: N/A"
            fi
            ;;
    esac
    echo ""
}

# ============================================================================
# Show Release Summary
# ============================================================================
# Displays comprehensive release summary with all steps, modules, and results.
#
# Environment Variables (required):
#   VERSION - Release version
#   RELEASE_BRANCH - Release branch name
#   BASE_BRANCH - Base branch name
#   RELEASE_START_TIME - Start timestamp
#   RELEASE_END_TIME - End timestamp
#   OVERALL_SUCCESS - "true" or "false"
#   ROOT_DIR - Project root directory
#
# Environment Variables (optional):
#   COCOAPODS_SUCCESS - Array of successful pods
#   COCOAPODS_FAILED - Array of failed pods
#   SPM_SUCCESS - Array of successful packages
#   SPM_FAILED - Array of failed packages
#   GITHUB_RELEASES_SUCCESS - Array of successful releases
#   GITHUB_RELEASES_FAILED - Array of failed releases
# ============================================================================
orch_show_release_summary() {
    local version="${VERSION:-unknown}"
    local release_branch="${RELEASE_BRANCH:-unknown}"
    local base_branch="${BASE_BRANCH:-main}"
    local start_time="${RELEASE_START_TIME:-}"
    local end_time="${RELEASE_END_TIME:-}"
    local overall_success="${OVERALL_SUCCESS:-false}"
    local root_dir="${ROOT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
    local state_file="$root_dir/.msp-release-state.json"

    if command -v print_section &>/dev/null; then
        print_section "Release Process Summary"
    else
        echo ""
        echo "════════════════════════════════════════════════════════════════"
        echo "  Release Process Summary"
        echo "════════════════════════════════════════════════════════════════"
    fi

    # Calculate duration
    local duration=""
    duration=$(orch_calculate_duration "$start_time" "$end_time")

    # Overall status
    if [[ "$overall_success" == "true" ]]; then
        if command -v log::success &>/dev/null; then
            log::success "SUMMARY" "🎉 Release $version completed successfully!"
        else
            echo "🎉 Release $version completed successfully!"
        fi
    else
        if command -v log::error &>/dev/null; then
            log::error "SUMMARY" "❌ Release $version completed with errors"
        else
            echo "❌ Release $version completed with errors"
        fi
    fi

    echo ""
    if command -v log::info &>/dev/null; then
        log::info "SUMMARY" "Release Details:"
        log::info "SUMMARY" "  Version: $version"
        log::info "SUMMARY" "  Release Branch: $release_branch"
        log::info "SUMMARY" "  Base Branch: $base_branch"
        log::info "SUMMARY" "  Start Time: ${start_time:-N/A}"
        log::info "SUMMARY" "  End Time: ${end_time:-N/A}"
        if [[ -n "$duration" ]]; then
            log::info "SUMMARY" "  Duration: $duration"
        fi
    else
        echo "Release Details:"
        echo "  Version: $version"
        echo "  Release Branch: $release_branch"
        echo "  Base Branch: $base_branch"
        echo "  Start Time: ${start_time:-N/A}"
        echo "  End Time: ${end_time:-N/A}"
        if [[ -n "$duration" ]]; then
            echo "  Duration: $duration"
        fi
    fi
    echo ""

    # Step-by-Step Execution Summary
    if command -v print_subsection &>/dev/null; then
        print_subsection "Step Execution Summary"
    else
        echo "=== Step Execution Summary ==="
    fi

    orch_print_step_summary "0" "pre_release_setup" "Pre-release Setup"
    orch_print_step_summary "1" "create_release_branch" "Create Release Branch"
    orch_print_step_summary "2" "release_cocoapods" "Release CocoaPods"
    orch_print_step_summary "3" "release_spm" "Release SPM"
    orch_print_step_summary "4" "push_release_branch" "Push Release Branch"
    orch_print_step_summary "5" "run_remote_verification" "Remote Verification"
    orch_print_step_summary "6" "run_local_verification" "Local Verification"
    orch_print_step_summary "7" "run_device_verification" "Device Verification"
    orch_print_step_summary "8" "run_xcframework_verification" "XCFramework Verification"
    echo ""

    # Verification summaries
    orch_print_verification_summary "remote" "$state_file"
    orch_print_verification_summary "local" "$state_file"
    orch_print_verification_summary "device" "$state_file"
    orch_print_verification_summary "xcframework" "$state_file"

    # Next Steps
    if command -v print_subsection &>/dev/null; then
        print_subsection "Next Steps"
    else
        echo "=== Next Steps ==="
    fi

    if [[ "$overall_success" == "true" ]]; then
        if command -v log::info &>/dev/null; then
            log::info "SUMMARY" "1. Verify the release on GitHub: https://github.com/ParticleMedia/msp-ios-sdk-public/releases/tag/$version"
            log::info "SUMMARY" "2. Test CocoaPods installation: pod 'MSPCore', '~> $version'"
            log::info "SUMMARY" "3. Test SPM installation: .package(url: \"https://github.com/ParticleMedia/msp-ios-sdk-public.git\", from: \"$version\")"
            log::info "SUMMARY" "4. Create pull request to merge release branch if needed"
        else
            echo "1. Verify the release on GitHub: https://github.com/ParticleMedia/msp-ios-sdk-public/releases/tag/$version"
            echo "2. Test CocoaPods installation: pod 'MSPCore', '~> $version'"
            echo "3. Test SPM installation: .package(url: \"https://github.com/ParticleMedia/msp-ios-sdk-public.git\", from: \"$version\")"
            echo "4. Create pull request to merge release branch if needed"
        fi
    else
        if command -v log::info &>/dev/null; then
            log::info "SUMMARY" "1. Review the failed components above"
            log::info "SUMMARY" "2. Fix any issues and retry the release"
            log::info "SUMMARY" "3. Check logs for detailed error information"
        else
            echo "1. Review the failed components above"
            echo "2. Fix any issues and retry the release"
            echo "3. Check logs for detailed error information"
        fi
    fi
    echo ""
}

# ============================================================================
# Export Functions
# ============================================================================

export -f orch_calculate_duration 2>/dev/null || true
export -f orch_get_step_status_from_state 2>/dev/null || true
export -f orch_print_step_summary 2>/dev/null || true
export -f orch_print_module_results 2>/dev/null || true
export -f orch_print_verification_summary 2>/dev/null || true
export -f orch_show_release_summary 2>/dev/null || true
