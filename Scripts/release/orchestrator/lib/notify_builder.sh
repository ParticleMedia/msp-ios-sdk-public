#!/usr/bin/env bash
# ============================================================================
# Notification Builder Module
# ============================================================================
# Module: orchestrator/lib/notify_builder.sh
# Purpose: Build notification data structures for Slack/email notifications
#
# Functions:
#   - orch_build_module_list: Build formatted module list string
#   - orch_build_remote_status: Build remote verification status string
#   - orch_build_local_status: Build local verification status string
#   - orch_build_device_status: Build device verification status string
#   - orch_build_xcf_status: Build XCFramework verification status string
#   - orch_build_verify_status: Combine all verification statuses
#   - orch_build_notify_json: Build complete notification JSON
#
# Dependencies:
#   - jq CLI (for JSON parsing)
#   - Logging functions (log::info, log::error, log::success)
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_ORCH_NOTIFY_BUILDER_SOURCED:-}" ]] && return 0
readonly _ORCH_NOTIFY_BUILDER_SOURCED=1

# ============================================================================
# Build Module List
# ============================================================================
# Builds a formatted list of modules for notification display.
#
# Args:
#   $@: Module names to include in the list
#
# Returns:
#   Prints formatted module list string
# ============================================================================
orch_build_module_list() {
    local module_list=""

    # Handle empty array with set -u
    local modules=()
    [[ $# -gt 0 ]] && modules=("$@")

    if [[ ${#modules[@]} -eq 0 ]]; then
        echo "    - (none)"
        return 0
    fi

    for module in ${modules[@]+"${modules[@]}"}; do
        if [[ -z "$module_list" ]]; then
            module_list="    - $module"
        else
            module_list="$module_list"$'\n'"    - $module"
        fi
    done

    echo "$module_list"
}

# ============================================================================
# Build Remote Verification Status
# ============================================================================
# Builds remote verification status string from environment variables.
#
# Environment:
#   REMOTE_SPM_EXECUTED - "1" if SPM verification was executed
#   REMOTE_SPM_SUCCESS - "1" if SPM verification succeeded
#   REMOTE_PODS_EXECUTED - "1" if Pods verification was executed
#   REMOTE_PODS_SUCCESS - "1" if Pods verification succeeded
#   MSP_VERIFY_SPM_URL - SPM verification URL (for SKIPPED status)
#   MSP_VERIFY_SPM_VERSION - SPM verification version
#   MSP_VERIFY_PODS_URL - Pods verification URL (for SKIPPED status)
#   MSP_VERIFY_PODS_VERSION - Pods verification version
#
# Returns:
#   Prints formatted remote status string
# ============================================================================
orch_build_remote_status() {
    local remote_status=""

    # SPM status
    if [[ "${REMOTE_SPM_EXECUTED:-0}" == "1" ]]; then
        if [[ "${REMOTE_SPM_SUCCESS:-0}" == "1" ]]; then
            remote_status="    - SPM: PASS"
        else
            remote_status="    - SPM: FAIL"
        fi
    elif [[ -n "${MSP_VERIFY_SPM_URL:-}" ]] && [[ -n "${MSP_VERIFY_SPM_VERSION:-}" ]]; then
        remote_status="    - SPM: SKIPPED"
    fi

    # Pods status
    if [[ "${REMOTE_PODS_EXECUTED:-0}" == "1" ]]; then
        local pods_line
        if [[ "${REMOTE_PODS_SUCCESS:-0}" == "1" ]]; then
            pods_line="    - Pods: PASS"
        else
            pods_line="    - Pods: FAIL"
        fi

        if [[ -z "$remote_status" ]]; then
            remote_status="$pods_line"
        else
            remote_status="$remote_status"$'\n'"$pods_line"
        fi
    elif [[ -n "${MSP_VERIFY_PODS_URL:-}" ]] && [[ -n "${MSP_VERIFY_PODS_VERSION:-}" ]]; then
        local pods_line="    - Pods: SKIPPED"
        if [[ -z "$remote_status" ]]; then
            remote_status="$pods_line"
        else
            remote_status="$remote_status"$'\n'"$pods_line"
        fi
    fi

    echo "$remote_status"
}

# ============================================================================
# Build Local Verification Status
# ============================================================================
# Builds local verification status string from state file.
#
# Args:
#   $1: state_file - Path to .msp-release-state.json
#   $2: mode - Local verification mode (optional, default: "unknown")
#
# Returns:
#   Prints formatted local status string
# ============================================================================
orch_build_local_status() {
    local state_file="${1:-}"
    local mode="${2:-unknown}"
    local local_status=""

    if [[ -f "$state_file" ]] && command -v jq >/dev/null 2>&1; then
        local local_step_status
        local_step_status="$(jq -r '.steps.run_local_verification.status // "unknown"' "$state_file" 2>/dev/null || echo "unknown")"

        if [[ "$local_step_status" == "success" ]]; then
            local_status="    - Local ($mode): PASS"
        elif [[ "$local_step_status" == "error" ]] || [[ "$local_step_status" == "failed" ]]; then
            local_status="    - Local ($mode): FAIL"
        fi
    fi

    echo "$local_status"
}

# ============================================================================
# Build Device Verification Status
# ============================================================================
# Builds device verification status string from state file.
#
# Args:
#   $1: state_file - Path to .msp-release-state.json
#   $2: mode - Device verification mode (optional, default: "unknown")
#
# Returns:
#   Prints formatted device status string
# ============================================================================
orch_build_device_status() {
    local state_file="${1:-}"
    local mode="${2:-unknown}"
    local device_status=""

    if [[ -f "$state_file" ]] && command -v jq >/dev/null 2>&1; then
        local device_step_status
        device_step_status="$(jq -r '.steps.run_device_verification.status // "unknown"' "$state_file" 2>/dev/null || echo "unknown")"

        if [[ "$device_step_status" == "success" ]]; then
            device_status="    - Device ($mode): PASS"
        elif [[ "$device_step_status" == "error" ]] || [[ "$device_step_status" == "failed" ]]; then
            device_status="    - Device ($mode): FAIL"
        fi
    fi

    echo "$device_status"
}

# ============================================================================
# Build XCFramework Verification Status
# ============================================================================
# Builds XCFramework verification status string from state file.
#
# Args:
#   $1: state_file - Path to .msp-release-state.json
#
# Returns:
#   Prints formatted XCFramework status string
# ============================================================================
orch_build_xcf_status() {
    local state_file="${1:-}"
    local xcf_status=""

    if [[ -f "$state_file" ]] && command -v jq >/dev/null 2>&1; then
        local xcf_step_status
        xcf_step_status="$(jq -r '.steps.run_xcframework_verification.status // "unknown"' "$state_file" 2>/dev/null || echo "unknown")"

        if [[ "$xcf_step_status" != "unknown" ]] && [[ "$xcf_step_status" != "skipped" ]]; then
            local modules
            modules="$(jq -r '.steps.run_xcframework_verification.modules // {} | keys[]' "$state_file" 2>/dev/null || echo "")"

            if [[ -n "$modules" ]]; then
                while IFS= read -r module; do
                    [[ -z "$module" ]] && continue

                    local success warnings module_status
                    success="$(jq -r ".steps.run_xcframework_verification.modules[\"$module\"].success" "$state_file" 2>/dev/null || echo "0")"
                    warnings="$(jq -r ".steps.run_xcframework_verification.modules[\"$module\"].warnings" "$state_file" 2>/dev/null || echo "0")"

                    if [[ "$success" == "1" ]]; then
                        if [[ "$warnings" == "0" ]]; then
                            module_status="    - XCFramework $module: PASS"
                        else
                            module_status="    - XCFramework $module: WARN ($warnings warnings)"
                        fi
                    else
                        module_status="    - XCFramework $module: FAIL"
                    fi

                    if [[ -z "$xcf_status" ]]; then
                        xcf_status="$module_status"
                    else
                        xcf_status="$xcf_status"$'\n'"$module_status"
                    fi
                done <<< "$modules"
            fi
        fi
    fi

    echo "$xcf_status"
}

# ============================================================================
# Build Combined Verification Status
# ============================================================================
# Combines all verification statuses into a single string.
#
# Args:
#   $1: remote_status - Remote verification status string
#   $2: local_status - Local verification status string
#   $3: device_status - Device verification status string
#   $4: xcf_status - XCFramework verification status string
#
# Returns:
#   Prints combined verification status string
# ============================================================================
orch_build_verify_status() {
    local remote_status="${1:-}"
    local local_status="${2:-}"
    local device_status="${3:-}"
    local xcf_status="${4:-}"

    local verify_status="$remote_status"

    if [[ -n "$local_status" ]]; then
        if [[ -z "$verify_status" ]]; then
            verify_status="$local_status"
        else
            verify_status="$verify_status"$'\n'"$local_status"
        fi
    fi

    if [[ -n "$device_status" ]]; then
        if [[ -z "$verify_status" ]]; then
            verify_status="$device_status"
        else
            verify_status="$verify_status"$'\n'"$device_status"
        fi
    fi

    if [[ -n "$xcf_status" ]]; then
        if [[ -z "$verify_status" ]]; then
            verify_status="$xcf_status"
        else
            verify_status="$verify_status"$'\n'"$xcf_status"
        fi
    fi

    echo "$verify_status"
}

# ============================================================================
# Build Modules JSON
# ============================================================================
# Builds JSON object for modules and their versions.
#
# Args:
#   $1: version - Release version
#   $@: Module names (after version)
#
# Returns:
#   Prints JSON object string
# ============================================================================
orch_build_modules_json() {
    local version="$1"
    shift

    local modules_json="{"
    local first_module=1

    # Handle empty array with set -u
    local modules=()
    [[ $# -gt 0 ]] && modules=("$@")

    for module in ${modules[@]+"${modules[@]}"}; do
        if [[ $first_module -eq 1 ]]; then
            first_module=0
        else
            modules_json="$modules_json,"
        fi
        modules_json="$modules_json\"$module\":\"$version\""
    done

    modules_json="$modules_json}"
    echo "$modules_json"
}

# ============================================================================
# Build Remote Verification JSON
# ============================================================================
# Builds JSON object for remote verification results.
#
# Environment:
#   REMOTE_SPM_EXECUTED, REMOTE_SPM_SUCCESS
#   REMOTE_PODS_EXECUTED, REMOTE_PODS_SUCCESS
#   MSP_VERIFY_SPM_URL, MSP_VERIFY_SPM_VERSION
#   MSP_VERIFY_PODS_URL, MSP_VERIFY_PODS_VERSION
#
# Returns:
#   Prints JSON object string
# ============================================================================
orch_build_remote_verify_json() {
    local remote_verify_json="{"
    local first_remote=1

    if [[ "${REMOTE_SPM_EXECUTED:-0}" == "1" ]]; then
        first_remote=0
        local spm_success
        spm_success=$([[ "${REMOTE_SPM_SUCCESS:-0}" == "1" ]] && echo "true" || echo "false")
        remote_verify_json="$remote_verify_json\"spm\":{\"executed\":true,\"success\":$spm_success,\"url\":\"${MSP_VERIFY_SPM_URL:-}\",\"version\":\"${MSP_VERIFY_SPM_VERSION:-}\"}"
    fi

    if [[ "${REMOTE_PODS_EXECUTED:-0}" == "1" ]]; then
        if [[ $first_remote -eq 0 ]]; then
            remote_verify_json="$remote_verify_json,"
        fi
        local pods_success
        pods_success=$([[ "${REMOTE_PODS_SUCCESS:-0}" == "1" ]] && echo "true" || echo "false")
        remote_verify_json="$remote_verify_json\"pods\":{\"executed\":true,\"success\":$pods_success,\"url\":\"${MSP_VERIFY_PODS_URL:-}\",\"version\":\"${MSP_VERIFY_PODS_VERSION:-}\"}"
    fi

    remote_verify_json="$remote_verify_json}"
    echo "$remote_verify_json"
}

# ============================================================================
# Build Local Verification JSON
# ============================================================================
# Builds JSON object for local verification results.
#
# Args:
#   $1: state_file - Path to .msp-release-state.json
#   $2: mode - Local verification mode (optional)
#
# Returns:
#   Prints JSON object string
# ============================================================================
orch_build_local_verify_json() {
    local state_file="${1:-}"
    local mode="${2:-unknown}"

    local local_step_status_json="unknown"
    if [[ -f "$state_file" ]] && command -v jq >/dev/null 2>&1; then
        local_step_status_json="$(jq -r '.steps.run_local_verification.status // "unknown"' "$state_file" 2>/dev/null || echo "unknown")"
    fi

    local local_executed="false"
    local local_success="false"
    if [[ "$local_step_status_json" == "success" ]]; then
        local_executed="true"
        local_success="true"
    elif [[ "$local_step_status_json" == "error" ]] || [[ "$local_step_status_json" == "failed" ]]; then
        local_executed="true"
        local_success="false"
    fi

    echo "{\"executed\":$local_executed,\"success\":$local_success,\"mode\":\"$mode\"}"
}

# ============================================================================
# Build Device Verification JSON
# ============================================================================
# Builds JSON object for device verification results.
#
# Args:
#   $1: state_file - Path to .msp-release-state.json
#   $2: mode - Device verification mode (optional)
#
# Environment:
#   DEVICE_VERIFY_ARCHIVE_PATH - Archive path (for archive status)
#   DEVICE_VERIFY_IPA_PATH - IPA path (for IPA status)
#
# Returns:
#   Prints JSON object string
# ============================================================================
orch_build_device_verify_json() {
    local state_file="${1:-}"
    local mode="${2:-unknown}"

    local device_step_status_json="unknown"
    if [[ -f "$state_file" ]] && command -v jq >/dev/null 2>&1; then
        device_step_status_json="$(jq -r '.steps.run_device_verification.status // "unknown"' "$state_file" 2>/dev/null || echo "unknown")"
    fi

    local device_executed="false"
    local device_success="false"
    if [[ "$device_step_status_json" == "success" ]]; then
        device_executed="true"
        device_success="true"
    elif [[ "$device_step_status_json" == "error" ]] || [[ "$device_step_status_json" == "failed" ]]; then
        device_executed="true"
        device_success="false"
    fi

    local archive_status ipa_status
    archive_status=$([[ -n "${DEVICE_VERIFY_ARCHIVE_PATH:-}" ]] && echo "pass" || echo "fail")
    ipa_status=$([[ -n "${DEVICE_VERIFY_IPA_PATH:-}" ]] && echo "pass" || echo "fail")

    echo "{\"executed\":$device_executed,\"success\":$device_success,\"mode\":\"$mode\",\"archive\":\"$archive_status\",\"ipa\":\"$ipa_status\"}"
}

# ============================================================================
# Build XCFramework Verification JSON
# ============================================================================
# Builds JSON object for XCFramework verification results.
#
# Args:
#   $1: state_file - Path to .msp-release-state.json
#
# Returns:
#   Prints JSON object string
# ============================================================================
orch_build_xcf_verify_json() {
    local state_file="${1:-}"

    local xcf_step_status_json="unknown"
    if [[ -f "$state_file" ]] && command -v jq >/dev/null 2>&1; then
        xcf_step_status_json="$(jq -r '.steps.run_xcframework_verification.status // "unknown"' "$state_file" 2>/dev/null || echo "unknown")"
    fi

    local xcf_executed="false"
    if [[ "$xcf_step_status_json" != "unknown" ]] && [[ "$xcf_step_status_json" != "skipped" ]]; then
        xcf_executed="true"
    fi

    local xcf_modules_json="{}"
    if [[ -f "$state_file" ]] && command -v jq >/dev/null 2>&1; then
        xcf_modules_json="$(jq -c '.steps.run_xcframework_verification.modules // {}' "$state_file" 2>/dev/null || echo "{}")"
    fi

    echo "{\"executed\":$xcf_executed,\"modules\":$xcf_modules_json}"
}

# ============================================================================
# Build Complete Notification JSON
# ============================================================================
# Builds complete notification JSON for Slack/email.
#
# Args:
#   $1: version - Release version
#   $2: author - Author email
#   $3: duration - Release duration string
#   $4: modules_json - Modules JSON object
#   $5: remote_verify_json - Remote verification JSON
#   $6: local_verify_json - Local verification JSON
#   $7: device_verify_json - Device verification JSON
#   $8: xcf_verify_json - XCFramework verification JSON
#
# Returns:
#   Prints complete notification JSON
# ============================================================================
orch_build_notify_json() {
    local version="$1"
    local author="$2"
    local duration="$3"
    local modules_json="$4"
    local remote_verify_json="$5"
    local local_verify_json="$6"
    local device_verify_json="$7"
    local xcf_verify_json="$8"
    local release_notes="${9:-}"

    local failure_json="{\"occurred\":false}"
    local timestamp release_notes_escaped
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    release_notes_escaped="$(echo "$release_notes" | jq -Rs '.')"

    cat <<EOF
{
  "version": "$version",
  "author": "$author",
  "duration": "$duration",
  "timestamp": "$timestamp",
  "release_notes": $release_notes_escaped,
  "modules": $modules_json,
  "remote_verify": $remote_verify_json,
  "local_verify": $local_verify_json,
  "device_verify": $device_verify_json,
  "xcframework_verify": $xcf_verify_json,
  "failure": $failure_json
}
EOF
}

# ============================================================================
# Export Functions
# ============================================================================

export -f orch_build_module_list 2>/dev/null || true
export -f orch_build_remote_status 2>/dev/null || true
export -f orch_build_local_status 2>/dev/null || true
export -f orch_build_device_status 2>/dev/null || true
export -f orch_build_xcf_status 2>/dev/null || true
export -f orch_build_verify_status 2>/dev/null || true
export -f orch_build_modules_json 2>/dev/null || true
export -f orch_build_remote_verify_json 2>/dev/null || true
export -f orch_build_local_verify_json 2>/dev/null || true
export -f orch_build_device_verify_json 2>/dev/null || true
export -f orch_build_xcf_verify_json 2>/dev/null || true
export -f orch_build_notify_json 2>/dev/null || true
