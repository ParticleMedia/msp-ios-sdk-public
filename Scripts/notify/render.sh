#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Notification Template Rendering Engine
# ============================================================================
# Purpose: Render notification templates with placeholder replacement
#
# Usage:   Source this file and call render functions
# ============================================================================

set -euo pipefail

# Source time utilities if available
if [[ -n "${ROOT_DIR:-}" ]] && [[ -f "${ROOT_DIR}/Scripts/lib/time-utils.sh" ]]; then
    source "${ROOT_DIR}/Scripts/lib/time-utils.sh" 2>/dev/null || true
elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/../../lib/time-utils.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../../lib/time-utils.sh" 2>/dev/null || true
fi

# ============================================================================
# Template Variables (loaded from notify_mapping.yaml)
# ============================================================================

SLACK_DM_TEMPLATE=""
SLACK_CHANNEL_TEMPLATE=""
SLACK_BLOCK_TEMPLATE=""
SLACK_BLOCKKIT_TEMPLATE=""
EMAIL_SUBJECT_TEMPLATE=""
EMAIL_HTML_TEMPLATE=""

# ============================================================================
# Initialize Templates from YAML
# ============================================================================

notify::render::init_templates() {
    local mapping_file="${ROOT_DIR:-.}/Scripts/config/notify_mapping.yaml"
    
    if [[ ! -f "$mapping_file" ]]; then
        return 0  # Soft-fail: template file not found
    fi
    
    # Parse YAML and extract templates directly using Python
    if ! command -v python3 >/dev/null 2>&1; then
        return 0  # Soft-fail: python3 not available
    fi
    
    # Use Python to extract templates and write to temp files
    local temp_dir
    temp_dir="$(mktemp -d)" || return 0
    
    python3 - "$mapping_file" "$temp_dir" <<'PYEOF' 2>/dev/null || true
import yaml
import sys
import os

try:
    mapping_file = sys.argv[1]
    temp_dir = sys.argv[2]
    
    with open(mapping_file, 'r') as f:
        data = yaml.safe_load(f)
    
    slack = data.get('slack', {})
    email = data.get('email', {})
    
    templates = {
        'SLACK_DM_TEMPLATE': slack.get('dm_template', ''),
        'SLACK_CHANNEL_TEMPLATE': slack.get('channel_template', ''),
        'SLACK_BLOCK_TEMPLATE': slack.get('block_template', ''),
        'EMAIL_SUBJECT_TEMPLATE': email.get('subject_template', ''),
        'EMAIL_HTML_TEMPLATE': email.get('html_template', '')
    }
    
    for var_name, template in templates.items():
        if template:
            file_path = os.path.join(temp_dir, var_name)
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(template)
except Exception:
    pass
PYEOF
    
    # Read templates from temp files
    [[ -f "$temp_dir/SLACK_DM_TEMPLATE" ]] && SLACK_DM_TEMPLATE="$(cat "$temp_dir/SLACK_DM_TEMPLATE")" || SLACK_DM_TEMPLATE=""
    [[ -f "$temp_dir/SLACK_CHANNEL_TEMPLATE" ]] && SLACK_CHANNEL_TEMPLATE="$(cat "$temp_dir/SLACK_CHANNEL_TEMPLATE")" || SLACK_CHANNEL_TEMPLATE=""
    [[ -f "$temp_dir/SLACK_BLOCK_TEMPLATE" ]] && SLACK_BLOCK_TEMPLATE="$(cat "$temp_dir/SLACK_BLOCK_TEMPLATE")" || SLACK_BLOCK_TEMPLATE=""
    [[ -f "$temp_dir/EMAIL_SUBJECT_TEMPLATE" ]] && EMAIL_SUBJECT_TEMPLATE="$(cat "$temp_dir/EMAIL_SUBJECT_TEMPLATE")" || EMAIL_SUBJECT_TEMPLATE=""
    [[ -f "$temp_dir/EMAIL_HTML_TEMPLATE" ]] && EMAIL_HTML_TEMPLATE="$(cat "$temp_dir/EMAIL_HTML_TEMPLATE")" || EMAIL_HTML_TEMPLATE=""
    
    # Cleanup
    rm -rf "$temp_dir" 2>/dev/null || true
    
    return 0
}

# ============================================================================
# Helper: Extract JSON Field
# ============================================================================

_notify_render::extract_json() {
    local json="$1"
    local field="$2"
    
    if command -v jq >/dev/null 2>&1; then
        echo "$json" | jq -r "$field // empty" 2>/dev/null || echo ""
    elif command -v python3 >/dev/null 2>&1; then
        echo "$json" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('$field', ''))" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# ============================================================================
# Helper: Format Timestamp for Slack
# ============================================================================

_notify_render::format_slack_timestamp() {
    local iso8601="$1"
    
    if [[ -z "$iso8601" ]]; then
        echo ""
        return 0
    fi
    
    # Try to use shared time utility if available
    if command -v format_timestamp_slack >/dev/null 2>&1; then
        format_timestamp_slack "$iso8601"
        return 0
    fi
    
    # Fallback to local implementation if time-utils.sh is not available
    # Try to convert ISO8601 to unix timestamp
    local unix_ts
    unix_ts="$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$iso8601" "+%s" 2>/dev/null || \
               date -jf "%Y-%m-%dT%H:%M:%S" "${iso8601%Z}" "+%s" 2>/dev/null || \
               date -d "$iso8601" "+%s" 2>/dev/null || \
               echo "")"
    
    if [[ -n "$unix_ts" ]] && [[ "$unix_ts" =~ ^[0-9]+$ ]]; then
        # Use Slack's date formatting: <!date^unix_ts^{format}|fallback>
        echo "<!date^${unix_ts}^{date_num} {time}|${iso8601}>"
    else
        # Fallback to original ISO string if parsing fails
        echo "$iso8601"
    fi
}

# ============================================================================
# Generate Modules Text
# ============================================================================

_notify_render::generate_modules_text() {
    local json="$1"
    
    local modules_json
    modules_json="$(echo "$json" | jq -r '.modules // {}' 2>/dev/null || echo "{}")"
    
    if [[ "$modules_json" == "{}" ]] || [[ -z "$modules_json" ]]; then
        echo "(none)"
        return 0
    fi
    
    local output=""
    local first=1
    
    # Use process substitution to avoid subshell variable scoping issues
    while IFS= read -r line; do
        if [[ $first -eq 1 ]]; then
            output="$line"
            first=0
        else
            output="$output"$'\n'"$line"
        fi
    done < <(echo "$modules_json" | jq -r 'to_entries[] | "  • \(.key) \(.value)"' 2>/dev/null)
    
    if [[ -z "$output" ]]; then
        echo "(none)"
        return 0
    fi
    
    echo "$output"
}

_notify_render::generate_modules_short() {
    local json="$1"
    
    local modules_json
    modules_json="$(echo "$json" | jq -r '.modules // {}' 2>/dev/null || echo "{}")"
    
    if [[ "$modules_json" == "{}" ]] || [[ -z "$modules_json" ]]; then
        echo "(none)"
        return 0
    fi
    
    local modules_list
    modules_list="$(echo "$modules_json" | jq -r 'keys | join(", ")' 2>/dev/null || echo "")"
    echo "$modules_list"
}

_notify_render::generate_modules_html() {
    local json="$1"
    
    local modules_json
    modules_json="$(echo "$json" | jq -r '.modules // {}' 2>/dev/null || echo "{}")"
    
    if [[ "$modules_json" == "{}" ]] || [[ -z "$modules_json" ]]; then
        printf '%s\n' "<p>(none)</p>"
        return 0
    fi
    
    # Use process substitution to avoid subshell issue with while loop
    local output=""
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            if [[ -z "$output" ]]; then
                output="$line"
            else
                output="$output"$'\n'"$line"
            fi
        fi
    done < <(echo "$modules_json" | jq -r 'to_entries[] | "<div class=\"module\">\(.key) <span class=\"version\">\(.value)</span></div>"' 2>/dev/null)
    
    if [[ -z "$output" ]]; then
        printf '%s\n' "<p>(none)</p>"
    else
        printf '%s\n' "$output"
    fi
}

# ============================================================================
# Generate Verification Text
# ============================================================================

_notify_render::generate_verification_text() {
    local json="$1"
    
    local output=""
    
    # Remote Verification
    local remote_spm_executed remote_spm_success remote_pods_executed remote_pods_success
    remote_spm_executed="$(echo "$json" | jq -r '.remote_verify.spm.executed // false' 2>/dev/null || echo "false")"
    remote_spm_success="$(echo "$json" | jq -r '.remote_verify.spm.success // false' 2>/dev/null || echo "false")"
    remote_pods_executed="$(echo "$json" | jq -r '.remote_verify.pods.executed // false' 2>/dev/null || echo "false")"
    remote_pods_success="$(echo "$json" | jq -r '.remote_verify.pods.success // false' 2>/dev/null || echo "false")"
    
    if [[ "$remote_spm_executed" == "true" ]]; then
        if [[ "$remote_spm_success" == "true" ]]; then
            output="  ✔ SPM: PASS"
        else
            output="  ❌ SPM: FAIL"
        fi
    fi
    
    if [[ "$remote_pods_executed" == "true" ]]; then
        if [[ "$remote_pods_success" == "true" ]]; then
            if [[ -z "$output" ]]; then
                output="  ✔ Pods: PASS"
            else
                output="$output"$'\n'"  ✔ Pods: PASS"
            fi
        else
            if [[ -z "$output" ]]; then
                output="  ❌ Pods: FAIL"
            else
                output="$output"$'\n'"  ❌ Pods: FAIL"
            fi
        fi
    fi
    
    # Local Verification
    local local_executed local_success local_mode
    local_executed="$(echo "$json" | jq -r '.local_verify.executed // false' 2>/dev/null || echo "false")"
    local_success="$(echo "$json" | jq -r '.local_verify.success // false' 2>/dev/null || echo "false")"
    local_mode="$(echo "$json" | jq -r '.local_verify.mode // ""' 2>/dev/null || echo "")"
    
    if [[ "$local_executed" == "true" ]]; then
        if [[ "$local_success" == "true" ]]; then
            if [[ -z "$output" ]]; then
                output="  ✔ Local ($local_mode): PASS"
            else
                output="$output"$'\n'"  ✔ Local ($local_mode): PASS"
            fi
        else
            if [[ -z "$output" ]]; then
                output="  ❌ Local ($local_mode): FAIL"
            else
                output="$output"$'\n'"  ❌ Local ($local_mode): FAIL"
            fi
        fi
    fi
    
    # Device Verification
    local device_executed device_success device_mode
    device_executed="$(echo "$json" | jq -r '.device_verify.executed // false' 2>/dev/null || echo "false")"
    device_success="$(echo "$json" | jq -r '.device_verify.success // false' 2>/dev/null || echo "false")"
    device_mode="$(echo "$json" | jq -r '.device_verify.mode // ""' 2>/dev/null || echo "")"
    
    if [[ "$device_executed" == "true" ]]; then
        if [[ "$device_success" == "true" ]]; then
            if [[ -z "$output" ]]; then
                output="  ✔ Device ($device_mode): PASS"
            else
                output="$output"$'\n'"  ✔ Device ($device_mode): PASS"
            fi
        else
            if [[ -z "$output" ]]; then
                output="  ❌ Device ($device_mode): FAIL"
            else
                output="$output"$'\n'"  ❌ Device ($device_mode): FAIL"
            fi
        fi
    fi
    
    # XCFramework Verification
    local xcf_modules_json
    xcf_modules_json="$(echo "$json" | jq -r '.xcframework_verify.modules // {}' 2>/dev/null || echo "{}")"
    
    if [[ "$xcf_modules_json" != "{}" ]] && [[ -n "$xcf_modules_json" ]]; then
        echo "$xcf_modules_json" | jq -r 'to_entries[] | "  \(if .value.success then "✔" else "❌" end) XCF \(.key): \(if .value.success then "PASS" else "FAIL" end)\(if .value.warnings > 0 then " ⚠️ \(.value.warnings)" else "" end)"' 2>/dev/null | while IFS= read -r line; do
            if [[ -z "$output" ]]; then
                output="$line"
            else
                output="$output"$'\n'"$line"
            fi
        done
    fi
    
    if [[ -z "$output" ]]; then
        echo "(none)"
    else
        echo "$output"
    fi
}

_notify_render::generate_verification_short() {
    local json="$1"
    
    local items=()
    
    # Remote SPM
    local remote_spm_executed remote_spm_success
    remote_spm_executed="$(echo "$json" | jq -r '.remote_verify.spm.executed // false' 2>/dev/null || echo "false")"
    remote_spm_success="$(echo "$json" | jq -r '.remote_verify.spm.success // false' 2>/dev/null || echo "false")"
    if [[ "$remote_spm_executed" == "true" ]]; then
        if [[ "$remote_spm_success" == "true" ]]; then
            items+=("SPM:PASS")
        else
            items+=("SPM:FAIL")
        fi
    fi
    
    # Remote Pods
    local remote_pods_executed remote_pods_success
    remote_pods_executed="$(echo "$json" | jq -r '.remote_verify.pods.executed // false' 2>/dev/null || echo "false")"
    remote_pods_success="$(echo "$json" | jq -r '.remote_verify.pods.success // false' 2>/dev/null || echo "false")"
    if [[ "$remote_pods_executed" == "true" ]]; then
        if [[ "$remote_pods_success" == "true" ]]; then
            items+=("Pods:PASS")
        else
            items+=("Pods:FAIL")
        fi
    fi
    
    # Local
    local local_executed local_success
    local_executed="$(echo "$json" | jq -r '.local_verify.executed // false' 2>/dev/null || echo "false")"
    local_success="$(echo "$json" | jq -r '.local_verify.success // false' 2>/dev/null || echo "false")"
    if [[ "$local_executed" == "true" ]]; then
        if [[ "$local_success" == "true" ]]; then
            items+=("Local:PASS")
        else
            items+=("Local:FAIL")
        fi
    fi
    
    # Device
    local device_executed device_success
    device_executed="$(echo "$json" | jq -r '.device_verify.executed // false' 2>/dev/null || echo "false")"
    device_success="$(echo "$json" | jq -r '.device_verify.success // false' 2>/dev/null || echo "false")"
    if [[ "$device_executed" == "true" ]]; then
        if [[ "$device_success" == "true" ]]; then
            items+=("Device:PASS")
        else
            items+=("Device:FAIL")
        fi
    fi
    
    if [[ ${#items[@]} -eq 0 ]]; then
        echo "(none)"
    else
        IFS=','; echo "${items[*]}"
    fi
}

_notify_render::generate_verification_html() {
    local json="$1"
    
    local output=""
    
    # Remote Verification
    local remote_spm_executed remote_spm_success remote_pods_executed remote_pods_success
    remote_spm_executed="$(echo "$json" | jq -r '.remote_verify.spm.executed // false' 2>/dev/null || echo "false")"
    remote_spm_success="$(echo "$json" | jq -r '.remote_verify.spm.success // false' 2>/dev/null || echo "false")"
    remote_pods_executed="$(echo "$json" | jq -r '.remote_verify.pods.executed // false' 2>/dev/null || echo "false")"
    remote_pods_success="$(echo "$json" | jq -r '.remote_verify.pods.success // false' 2>/dev/null || echo "false")"
    
    if [[ "$remote_spm_executed" == "true" ]]; then
        if [[ "$remote_spm_success" == "true" ]]; then
            output="<div class=\"verification-item\"><span class=\"success\">✓</span> SPM: PASS</div>"
        else
            output="<div class=\"verification-item\"><span class=\"failure\">✗</span> SPM: FAIL</div>"
        fi
    fi
    
    if [[ "$remote_pods_executed" == "true" ]]; then
        if [[ "$remote_pods_success" == "true" ]]; then
            if [[ -z "$output" ]]; then
                output="<div class=\"verification-item\"><span class=\"success\">✓</span> Pods: PASS</div>"
            else
                output="$output"$'\n'"<div class=\"verification-item\"><span class=\"success\">✓</span> Pods: PASS</div>"
            fi
        else
            if [[ -z "$output" ]]; then
                output="<div class=\"verification-item\"><span class=\"failure\">✗</span> Pods: FAIL</div>"
            else
                output="$output"$'\n'"<div class=\"verification-item\"><span class=\"failure\">✗</span> Pods: FAIL</div>"
            fi
        fi
    fi
    
    # Local Verification
    local local_executed local_success local_mode
    local_executed="$(echo "$json" | jq -r '.local_verify.executed // false' 2>/dev/null || echo "false")"
    local_success="$(echo "$json" | jq -r '.local_verify.success // false' 2>/dev/null || echo "false")"
    local_mode="$(echo "$json" | jq -r '.local_verify.mode // ""' 2>/dev/null || echo "")"
    
    if [[ "$local_executed" == "true" ]]; then
        if [[ "$local_success" == "true" ]]; then
            if [[ -z "$output" ]]; then
                output="<div class=\"verification-item\"><span class=\"success\">✓</span> Local ($local_mode): PASS</div>"
            else
                output="$output"$'\n'"<div class=\"verification-item\"><span class=\"success\">✓</span> Local ($local_mode): PASS</div>"
            fi
        else
            if [[ -z "$output" ]]; then
                output="<div class=\"verification-item\"><span class=\"failure\">✗</span> Local ($local_mode): FAIL</div>"
            else
                output="$output"$'\n'"<div class=\"verification-item\"><span class=\"failure\">✗</span> Local ($local_mode): FAIL</div>"
            fi
        fi
    fi
    
    # Device Verification
    local device_executed device_success device_mode
    device_executed="$(echo "$json" | jq -r '.device_verify.executed // false' 2>/dev/null || echo "false")"
    device_success="$(echo "$json" | jq -r '.device_verify.success // false' 2>/dev/null || echo "false")"
    device_mode="$(echo "$json" | jq -r '.device_verify.mode // ""' 2>/dev/null || echo "")"
    
    if [[ "$device_executed" == "true" ]]; then
        if [[ "$device_success" == "true" ]]; then
            if [[ -z "$output" ]]; then
                output="<div class=\"verification-item\"><span class=\"success\">✓</span> Device ($device_mode): PASS</div>"
            else
                output="$output"$'\n'"<div class=\"verification-item\"><span class=\"success\">✓</span> Device ($device_mode): PASS</div>"
            fi
        else
            if [[ -z "$output" ]]; then
                output="<div class=\"verification-item\"><span class=\"failure\">✗</span> Device ($device_mode): FAIL</div>"
            else
                output="$output"$'\n'"<div class=\"verification-item\"><span class=\"failure\">✗</span> Device ($device_mode): FAIL</div>"
            fi
        fi
    fi
    
    # XCFramework Verification
    local xcf_modules_json
    xcf_modules_json="$(echo "$json" | jq -r '.xcframework_verify.modules // {}' 2>/dev/null || echo "{}")"
    
    if [[ "$xcf_modules_json" != "{}" ]] && [[ -n "$xcf_modules_json" ]]; then
        # Use process substitution to avoid subshell issue with while loop
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                if [[ -z "$output" ]]; then
                    output="$line"
                else
                    output="$output"$'\n'"$line"
                fi
            fi
        done < <(echo "$xcf_modules_json" | jq -r 'to_entries[] | "<div class=\"verification-item\"><span class=\"\(if .value.success then "success" else "failure" end)\">\(if .value.success then "✓" else "✗" end)</span> XCFramework \(.key): \(if .value.success then "PASS" else "FAIL" end)\(if .value.warnings > 0 then " <span class=\"warning\">(\(.value.warnings) warnings)</span>" else "" end)</div>"' 2>/dev/null)
    fi
    
    if [[ -z "$output" ]]; then
        echo "<p>(none)</p>"
    else
        echo "$output"
    fi
}

# ============================================================================
# Generate Failure Context
# ============================================================================

_notify_render::generate_failure_context() {
    local json="$1"
    
    local occurred
    occurred="$(echo "$json" | jq -r '.failure.occurred // false' 2>/dev/null || echo "false")"
    
    if [[ "$occurred" != "true" ]]; then
        echo ""
        return 0
    fi
    
    local stage module script reason log_path
    stage="$(echo "$json" | jq -r '.failure.stage // ""' 2>/dev/null || echo "")"
    module="$(echo "$json" | jq -r '.failure.module // ""' 2>/dev/null || echo "")"
    script="$(echo "$json" | jq -r '.failure.script // ""' 2>/dev/null || echo "")"
    reason="$(echo "$json" | jq -r '.failure.reason // ""' 2>/dev/null || echo "")"
    log_path="$(echo "$json" | jq -r '.failure.log_path // ""' 2>/dev/null || echo "")"
    
    local output="❌ Failure: $stage"
    [[ -n "$module" ]] && output="$output/$module"
    output="$output"$'\n'"  → $reason"
    [[ -n "$log_path" ]] && output="$output"$'\n'"  📄 $log_path"
    
    echo "$output"
}

_notify_render::generate_failure_context_short() {
    local json="$1"
    
    local occurred
    occurred="$(echo "$json" | jq -r '.failure.occurred // false' 2>/dev/null || echo "false")"
    
    if [[ "$occurred" != "true" ]]; then
        echo ""
        return 0
    fi
    
    local stage module reason
    stage="$(echo "$json" | jq -r '.failure.stage // ""' 2>/dev/null || echo "")"
    module="$(echo "$json" | jq -r '.failure.module // ""' 2>/dev/null || echo "")"
    reason="$(echo "$json" | jq -r '.failure.reason // ""' 2>/dev/null || echo "")"
    
    local output="❌ $stage"
    [[ -n "$module" ]] && output="$output/$module"
    [[ -n "$reason" ]] && output="$output: $reason"
    
    echo "$output"
}

_notify_render::generate_failure_context_html() {
    local json="$1"
    
    local occurred
    occurred="$(echo "$json" | jq -r '.failure.occurred // false' 2>/dev/null || echo "false")"
    
    if [[ "$occurred" != "true" ]]; then
        echo ""
        return 0
    fi
    
    local stage module script reason log_path
    stage="$(echo "$json" | jq -r '.failure.stage // ""' 2>/dev/null || echo "")"
    module="$(echo "$json" | jq -r '.failure.module // ""' 2>/dev/null || echo "")"
    script="$(echo "$json" | jq -r '.failure.script // ""' 2>/dev/null || echo "")"
    reason="$(echo "$json" | jq -r '.failure.reason // ""' 2>/dev/null || echo "")"
    log_path="$(echo "$json" | jq -r '.failure.log_path // ""' 2>/dev/null || echo "")"
    
    local output="<div class=\"section failure\">"
    output="$output<h2>❌ Failure Detected</h2>"
    [[ -n "$stage" ]] && output="$output<p><strong>Stage:</strong> $stage</p>"
    [[ -n "$module" ]] && output="$output<p><strong>Module:</strong> $module</p>"
    [[ -n "$script" ]] && output="$output<p><strong>Script:</strong> $script</p>"
    [[ -n "$reason" ]] && output="$output<p><strong>Reason:</strong> $reason</p>"
    [[ -n "$log_path" ]] && output="$output<p><strong>Log:</strong> <code>$log_path</code></p>"
    output="$output</div>"
    
    echo "$output"
}

# ============================================================================
# Render Functions
# ============================================================================

notify::render::render_dm() {
    local json="$1"
    
    if [[ -z "$SLACK_DM_TEMPLATE" ]]; then
        echo "Warning: Slack DM template not loaded" >&2
        return 0  # Soft-fail
    fi
    
    local version author duration timestamp
    version="$(echo "$json" | jq -r '.version // .release.version // ""' 2>/dev/null || echo "")"
    # Extract author: prefer .author.email, fallback to .author.name, then .author (if string)
    author="$(echo "$json" | jq -r '.author.email // .author.name // (if .author | type == "string" then .author else empty end) // ""' 2>/dev/null || echo "")"
    # Extract duration: prefer .timing.duration_human, fallback to .timing.duration, then .duration
    duration="$(echo "$json" | jq -r '.timing.duration_human // .timing.duration // .duration // ""' 2>/dev/null || echo "")"
    # Extract timestamp: prefer .timing.finished_at, fallback to .finished_at, then .timestamp
    timestamp="$(echo "$json" | jq -r '.timing.finished_at // .finished_at // .timestamp // ""' 2>/dev/null || echo "")"
    
    local modules verification failure_context
    modules="$(_notify_render::generate_modules_text "$json" 2>/dev/null || echo "(none)")"
    verification="$(_notify_render::generate_verification_text "$json" 2>/dev/null || echo "(none)")"
    failure_context="$(_notify_render::generate_failure_context "$json" 2>/dev/null || echo "")"
    
    local result="$SLACK_DM_TEMPLATE"
    result="${result//\{\{VERSION\}\}/$version}"
    result="${result//\{\{AUTHOR\}\}/$author}"
    result="${result//\{\{DURATION\}\}/$duration}"
    result="${result//\{\{TIMESTAMP\}\}/$timestamp}"
    result="${result//\{\{MODULES\}\}/$modules}"
    result="${result//\{\{VERIFICATION\}\}/$verification}"
    result="${result//\{\{FAILURE_CONTEXT\}\}/$failure_context}"
    
    # Determine status
    local failure_occurred
    failure_occurred="$(echo "$json" | jq -r '.failure.occurred // false' 2>/dev/null || echo "false")"
    local status="Success"
    [[ "$failure_occurred" == "true" ]] && status="Failure"
    result="${result//\{\{STATUS\}\}/$status}"
    
    echo "$result"
}

notify::render::render_channel() {
    local json="$1"
    
    if [[ -z "$SLACK_CHANNEL_TEMPLATE" ]]; then
        echo "Warning: Slack Channel template not loaded" >&2
        return 0  # Soft-fail
    fi
    
    local version author duration timestamp
    version="$(echo "$json" | jq -r '.version // .release.version // ""' 2>/dev/null || echo "")"
    # Extract author: prefer .author.email, fallback to .author.name, then .author (if string)
    author="$(echo "$json" | jq -r '.author.email // .author.name // (if .author | type == "string" then .author else empty end) // ""' 2>/dev/null || echo "")"
    # Extract duration: prefer .timing.duration_human, fallback to .timing.duration, then .duration
    duration="$(echo "$json" | jq -r '.timing.duration_human // .timing.duration // .duration // ""' 2>/dev/null || echo "")"
    # Extract timestamp: prefer .timing.finished_at, fallback to .finished_at, then .timestamp
    timestamp="$(echo "$json" | jq -r '.timing.finished_at // .finished_at // .timestamp // ""' 2>/dev/null || echo "")"
    
    local modules_short verification_short failure_context_short
    modules_short="$(_notify_render::generate_modules_short "$json" 2>/dev/null || echo "(none)")"
    verification_short="$(_notify_render::generate_verification_short "$json" 2>/dev/null || echo "(none)")"
    failure_context_short="$(_notify_render::generate_failure_context_short "$json" 2>/dev/null || echo "")"
    
    local result="$SLACK_CHANNEL_TEMPLATE"
    result="${result//\{\{VERSION\}\}/$version}"
    result="${result//\{\{AUTHOR\}\}/$author}"
    result="${result//\{\{DURATION\}\}/$duration}"
    result="${result//\{\{TIMESTAMP\}\}/$timestamp}"
    result="${result//\{\{MODULES_SHORT\}\}/$modules_short}"
    result="${result//\{\{VERIFICATION_SHORT\}\}/$verification_short}"
    result="${result//\{\{FAILURE_CONTEXT_SHORT\}\}/$failure_context_short}"
    
    # Determine status
    local failure_occurred
    failure_occurred="$(echo "$json" | jq -r '.failure.occurred // false' 2>/dev/null || echo "false")"
    local status="Success"
    [[ "$failure_occurred" == "true" ]] && status="Failure"
    result="${result//\{\{STATUS\}\}/$status}"
    
    echo "$result"
}

notify::render::render_email_subject() {
    local json="$1"
    
    if [[ -z "$EMAIL_SUBJECT_TEMPLATE" ]]; then
        echo "Warning: Email subject template not loaded" >&2
        return 0  # Soft-fail
    fi
    
    local version
    version="$(echo "$json" | jq -r '.version // ""' 2>/dev/null || echo "")"
    
    local failure_occurred
    failure_occurred="$(echo "$json" | jq -r '.failure.occurred // false' 2>/dev/null || echo "false")"
    local status="Success"
    [[ "$failure_occurred" == "true" ]] && status="Failure"
    
    local result="$EMAIL_SUBJECT_TEMPLATE"
    result="${result//\{\{VERSION\}\}/$version}"
    result="${result//\{\{STATUS\}\}/$status}"
    
    echo "$result"
}

notify::render::render_email_html() {
    local json="$1"
    
    # Phase 4 Step 2 TASK 6: Detect release tier for email
    local release_tier
    release_tier="$(echo "$json" | jq -r '.release_tier // .release.release_tier // "preflight"' 2>/dev/null || echo "preflight")"
    local release_mode
    release_mode="$(echo "$json" | jq -r '.release_mode // .release.release_mode // "cli"' 2>/dev/null || echo "cli")"
    
    # Route to tier-specific email renderer
    if [[ "$release_tier" == "production" ]]; then
        _notify_render::render_production_email "$json" "$release_mode"
    else
        _notify_render::render_preflight_email "$json"
    fi
}

# ============================================================================
# Phase 4 Step 2: Production Email HTML Renderer
# ============================================================================

_notify_render::render_production_email() {
    local json="$1"
    local release_mode="$2"
    
    # Extract data
    local version author duration branch started_at ended_at
    version="$(echo "$json" | jq -r '.version // .release.version // ""' 2>/dev/null || echo "")"
    author="$(echo "$json" | jq -r '.author.email // .author.name // ""' 2>/dev/null || echo "")"
    duration="$(echo "$json" | jq -r '.duration // .timing.duration_human // ""' 2>/dev/null || echo "")"
    branch="$(echo "$json" | jq -r '.release_branch // ""' 2>/dev/null || echo "")"
    started_at="$(echo "$json" | jq -r '.timestamps.timestamp_start // ""' 2>/dev/null || echo "")"
    ended_at="$(echo "$json" | jq -r '.timestamps.timestamp_end // ""' 2>/dev/null || echo "")"
    
    # Extract pods lint results
    local pods_lint_errors pods_lint_warnings
    pods_lint_errors="$(echo "$json" | jq -r '.steps.pods.lint_errors // 0' 2>/dev/null || echo "0")"
    pods_lint_warnings="$(echo "$json" | jq -r '.steps.pods.lint_warnings // 0' 2>/dev/null || echo "0")"
    
    # Extract SPM manifest results
    local spm_manifest_status spm_errors spm_warnings
    spm_manifest_status="$(echo "$json" | jq -r '.steps.spm_manifest.status // "unknown"' 2>/dev/null || echo "unknown")"
    spm_errors="$(echo "$json" | jq -r '.steps.spm_manifest.errors // []' 2>/dev/null || echo "[]")"
    spm_warnings="$(echo "$json" | jq -r '.steps.spm_manifest.warnings // []' 2>/dev/null || echo "[]")"
    
    # Extract artifacts
    local xcframework_paths ipa_path spec_paths
    xcframework_paths="$(echo "$json" | jq -r '.artifacts.xcframework_paths // []' 2>/dev/null || echo "[]")"
    ipa_path="$(echo "$json" | jq -r '.artifacts.ipa_path // ""' 2>/dev/null || echo "")"
    spec_paths="$(echo "$json" | jq -r '.artifacts.spec_paths // []' 2>/dev/null || echo "[]")"
    
    # Extract release notes
    local release_notes
    release_notes="$(echo "$json" | jq -r '.release_notes // .release.notes // ""' 2>/dev/null || echo "")"
    
    # Extract modules
    local modules_json
    modules_json="$(echo "$json" | jq -r '.modules // {}' 2>/dev/null || echo "{}")"
    
    # Extract verification results
    local steps_json
    steps_json="$(echo "$json" | jq -r '.steps // {}' 2>/dev/null || echo "{}")"
    
    # Generate HTML
    python3 <<PYEOF
import json
import html

version = '''$version'''
author = '''$author'''
duration = '''$duration'''
branch = '''$branch'''
started_at = '''$started_at'''
ended_at = '''$ended_at'''
release_mode = '''$release_mode'''
pods_lint_errors = int('''$pods_lint_errors''')
pods_lint_warnings = int('''$pods_lint_warnings''')
spm_manifest_status = '''$spm_manifest_status'''

try:
    spm_errors = json.loads('''$spm_errors''')
    spm_warnings = json.loads('''$spm_manifest_warnings''')
    xcf_paths = json.loads('''$xcframework_paths''')
    spec_paths_list = json.loads('''$spec_paths''')
    modules = json.loads('''$modules_json''')
    steps = json.loads('''$steps_json''')
except:
    spm_errors = []
    spm_warnings = []
    xcf_paths = []
    spec_paths_list = []
    modules = {}
    steps = {}

ipa_path = '''$ipa_path'''
release_notes = '''$release_notes'''

html_content = """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { background: #2eb886; color: white; padding: 30px; border-radius: 8px 8px 0 0; }
        .header h1 { margin: 0; font-size: 24px; }
        .header p { margin: 10px 0 0 0; opacity: 0.9; }
        .content { padding: 30px; }
        .section { margin-bottom: 30px; }
        .section h2 { color: #333; border-bottom: 2px solid #2eb886; padding-bottom: 10px; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        table td, table th { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        table th { background: #f8f8f8; font-weight: 600; }
        .success { color: #2eb886; }
        .error { color: #e01e5a; }
        .warning { color: #f39c12; }
        .pre-block { background: #f8f8f8; padding: 15px; border-radius: 4px; font-family: monospace; white-space: pre-wrap; overflow-x: auto; }
        .error-item { color: #e01e5a; font-weight: 600; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🟢 MSP iOS SDK Production Release</h1>
            <p>Version: {version} | Branch: {branch} | Duration: {duration}</p>
        </div>
        <div class="content">
            <div class="section">
                <h2>Release Information</h2>
                <table>
                    <tr><th>Version</th><td><strong>{version}</strong></td></tr>
                    <tr><th>Author</th><td>{author}</td></tr>
                    <tr><th>Branch</th><td>{branch}</td></tr>
                    <tr><th>Started</th><td>{started_at}</td></tr>
                    <tr><th>Ended</th><td>{ended_at}</td></tr>
                    <tr><th>Duration</th><td>{duration}</td></tr>
                </table>
            </div>
            
            <div class="section">
                <h2>Summary</h2>
                <table>
                    <tr>
                        <th>CocoaPods Release</th>
                        <td class="{pods_status_class}">{pods_status_text}</td>
                    </tr>
                    <tr>
                        <th>Pods Lint</th>
                        <td>Errors: {pods_lint_errors}, Warnings: {pods_lint_warnings}</td>
                    </tr>
                    <tr>
                        <th>SPM Release</th>
                        <td class="{spm_status_class}">{spm_status_text}</td>
                    </tr>
                    <tr>
                        <th>SPM Manifest</th>
                        <td>Status: {spm_manifest_status} | Errors: {spm_error_count}, Warnings: {spm_warning_count}</td>
                    </tr>
                </table>
            </div>
""".format(
    version=html.escape(version or "N/A"),
    author=html.escape(author or "N/A"),
    branch=html.escape(branch or "N/A"),
    started_at=html.escape(started_at or "N/A"),
    ended_at=html.escape(ended_at or "N/A"),
    duration=html.escape(duration or "N/A"),
    pods_status_class="success" if pods_lint_errors == 0 else "error",
    pods_status_text="✅ Success" if pods_lint_errors == 0 else f"❌ Failed ({pods_lint_errors} errors)",
    pods_lint_errors=pods_lint_errors,
    pods_lint_warnings=pods_lint_warnings,
    spm_status_class="success" if spm_manifest_status == "success" else "error",
    spm_status_text="✅ Success" if spm_manifest_status == "success" else "❌ Failed",
    spm_manifest_status=spm_manifest_status,
    spm_error_count=len(spm_errors),
    spm_warning_count=len(spm_warnings)
)

# Verification Section (CLI only)
if release_mode == "cli":
    html_content += """
            <div class="section">
                <h2>Verification</h2>
                <table>
"""
    if steps.get("local_verify", {}).get("status") == "success":
        html_content += "<tr><th>Local Verify</th><td class='success'>✅ PASS</td></tr>"
    elif steps.get("local_verify", {}).get("status") == "failed":
        html_content += "<tr><th>Local Verify</th><td class='error'>❌ FAIL</td></tr>"
    
    if steps.get("device_verify", {}).get("status") == "success":
        html_content += "<tr><th>Device Verify</th><td class='success'>✅ PASS</td></tr>"
    elif steps.get("device_verify", {}).get("status") == "failed":
        html_content += "<tr><th>Device Verify</th><td class='error'>❌ FAIL</td></tr>"
    
    if steps.get("xcframework_verify", {}).get("status") == "success":
        html_content += "<tr><th>XCFramework Verify</th><td class='success'>✅ PASS</td></tr>"
    elif steps.get("xcframework_verify", {}).get("status") == "failed":
        html_content += "<tr><th>XCFramework Verify</th><td class='error'>❌ FAIL</td></tr>"
    
    html_content += """
                </table>
            </div>
"""

# Release Notes
if release_notes:
    html_content += f"""
            <div class="section">
                <h2>Release Notes</h2>
                <div class="pre-block">{html.escape(release_notes)}</div>
            </div>
"""

# Artifacts
if xcf_paths or ipa_path or spec_paths_list:
    html_content += """
            <div class="section">
                <h2>Artifacts</h2>
                <table>
"""
    if xcf_paths:
        html_content += f"<tr><th>XCFrameworks</th><td>{len(xcf_paths)} files</td></tr>"
    if ipa_path:
        html_content += f"<tr><th>IPA</th><td>{html.escape(ipa_path)}</td></tr>"
    if spec_paths_list:
        html_content += f"<tr><th>Specs</th><td>{len(spec_paths_list)} files</td></tr>"
    html_content += """
                </table>
            </div>
"""

# Error Section
error_items = []
if pods_lint_errors > 0:
    error_items.append("❌ pods lint failed")
if spm_manifest_status == "error":
    error_items.append("❌ spm manifest mismatch")
if spm_errors:
    error_items.append("❌ spm tag missing")
if steps.get("local_verify", {}).get("status") == "failed":
    error_items.append("❌ local verify fail")
if steps.get("device_verify", {}).get("status") == "failed":
    error_items.append("❌ device verify fail")
if steps.get("xcframework_verify", {}).get("status") == "failed":
    error_items.append("❌ xcframework verify fail")

if error_items:
    html_content += """
            <div class="section">
                <h2>Errors</h2>
                <ul>
"""
    for item in error_items:
        html_content += f"<li class='error-item'>{html.escape(item)}</li>"
    html_content += """
                </ul>
            </div>
"""

html_content += """
        </div>
    </div>
</body>
</html>
"""

print(html_content)
PYEOF
}

# ============================================================================
# Phase 4 Step 2: Preflight Email HTML Renderer
# ============================================================================

_notify_render::render_preflight_email() {
    local json="$1"
    
    # Extract data
    local version author duration branch
    version="$(echo "$json" | jq -r '.version // .release.version // ""' 2>/dev/null || echo "")"
    author="$(echo "$json" | jq -r '.author.email // .author.name // ""' 2>/dev/null || echo "")"
    duration="$(echo "$json" | jq -r '.duration // .timing.duration_human // ""' 2>/dev/null || echo "")"
    branch="$(echo "$json" | jq -r '.release_branch // ""' 2>/dev/null || echo "")"
    
    local pods_lint_warnings spm_warnings
    pods_lint_warnings="$(echo "$json" | jq -r '.steps.pods.lint_warnings // 0' 2>/dev/null || echo "0")"
    spm_warnings="$(echo "$json" | jq -r '.steps.spm_manifest.warnings // []' 2>/dev/null || echo "[]")"
    
    local release_notes modules_json
    release_notes="$(echo "$json" | jq -r '.release_notes // .release.notes // ""' 2>/dev/null || echo "")"
    modules_json="$(echo "$json" | jq -r '.modules // {}' 2>/dev/null || echo "{}")"
    
    python3 <<PYEOF
import json
import html

version = '''$version'''
author = '''$author'''
duration = '''$duration'''
branch = '''$branch'''
pods_lint_warnings = int('''$pods_lint_warnings''')

try:
    spm_warnings = json.loads('''$spm_warnings''')
    modules = json.loads('''$modules_json''')
except:
    spm_warnings = []
    modules = {}

release_notes = '''$release_notes'''

html_content = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {{ font-family: -apple-system, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }}
        .container {{ max-width: 700px; margin: 0 auto; background: white; border-radius: 8px; padding: 20px; }}
        .header {{ background: #f39c12; color: white; padding: 20px; border-radius: 8px; margin: -20px -20px 20px -20px; }}
        .section {{ margin: 20px 0; }}
        .pre-block {{ background: #f8f8f8; padding: 15px; border-radius: 4px; font-family: monospace; white-space: pre-wrap; }}
        .warning {{ color: #f39c12; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🟡 Preflight Release """ + html.escape(version or "N/A") + """</h1>
            <p>Author: """ + html.escape(author or "N/A") + """ | Duration: """ + html.escape(duration or "N/A") + """ | Branch: """ + html.escape(branch or "N/A") + """</p>
        </div>
        
        <div class="section">
            <h2>Version & Branch</h2>
            <p><strong>Version:</strong> """ + html.escape(version or "N/A") + """</p>
            <p><strong>Branch:</strong> """ + html.escape(branch or "N/A") + """</p>
        </div>
"""

# Warnings
warnings_list = []
if pods_lint_warnings > 0:
    warnings_list.append(f"Pods Lint: {pods_lint_warnings} warnings")
if spm_warnings:
    warnings_list.append(f"SPM Manifest: {len(spm_warnings)} warnings")

if warnings_list:
    html_content += """
        <div class="section">
            <h2>⚠️ Warnings</h2>
            <ul>
"""
    for w in warnings_list:
        html_content += f"<li class='warning'>{html.escape(w)}</li>"
    html_content += """
            </ul>
        </div>
"""

# Modules
if modules:
    html_content += """
        <div class="section">
            <h2>📦 Modules</h2>
            <ul>
"""
    for k, v in modules.items():
        html_content += f"<li>{html.escape(k)} {html.escape(str(v))}</li>"
    html_content += """
            </ul>
        </div>
"""

# Release Notes
if release_notes:
    html_content += """
        <div class="section">
            <h2>📝 Release Notes</h2>
            <div class="pre-block">""" + html.escape(release_notes) + """</div>
        </div>
"""

html_content += """
    </div>
</body>
</html>
"""

print(html_content)
PYEOF
}

# ============================================================================
# Render Slack Block Kit
# ============================================================================

notify::render::render_slack_blockkit() {
    local json="$1"
    
    if [[ -z "$SLACK_BLOCK_TEMPLATE" ]]; then
        return 0  # Soft-fail: template not loaded
    fi
    
    # Extract values from JSON
    local version author duration timestamp
    version="$(echo "$json" | jq -r '.version // .release.version // ""' 2>/dev/null || echo "")"
    # Extract author: prefer .author.email, fallback to .author.name, then .author (if string)
    author="$(echo "$json" | jq -r '.author.email // .author.name // (if .author | type == "string" then .author else empty end) // ""' 2>/dev/null || echo "")"
    # Extract duration: prefer .timing.duration_human, fallback to .timing.duration, then .duration
    duration="$(echo "$json" | jq -r '.timing.duration_human // .timing.duration // .duration // ""' 2>/dev/null || echo "")"
    # Extract timestamp: prefer .timing.finished_at, fallback to .finished_at, then .timestamp
    timestamp="$(echo "$json" | jq -r '.timing.finished_at // .finished_at // .timestamp // ""' 2>/dev/null || echo "")"
    
    # Generate content sections
    local modules verification failure_context
    modules="$(_notify_render::generate_modules_text "$json" 2>/dev/null || echo "(none)")"
    verification="$(_notify_render::generate_verification_text "$json" 2>/dev/null || echo "(none)")"
    failure_context="$(_notify_render::generate_failure_context "$json" 2>/dev/null || echo "")"
    
    # Use Python to properly build and escape JSON
    if ! command -v python3 >/dev/null 2>&1; then
        return 0  # Soft-fail: python3 not available
    fi
    
    local result
    result="$(python3 <<PYEOF
import json
import sys

    # Read template
    template_str = '''$SLACK_BLOCK_TEMPLATE'''

# Replace simple placeholders first
template_str = template_str.replace('{{VERSION}}', '$version')
template_str = template_str.replace('{{AUTHOR}}', '$author')
template_str = template_str.replace('{{DURATION}}', '$duration')
template_str = template_str.replace('{{TIMESTAMP}}', '$timestamp')

# Parse template JSON
try:
    template = json.loads(template_str)
except Exception:
    sys.exit(1)

# Escape modules and verification for JSON
modules_text = '''$modules'''
verification_text = '''$verification'''
failure_text = '''$failure_context'''

# Replace placeholders in blocks
for block in template.get('blocks', []):
    if block.get('type') == 'section':
        text_obj = block.get('text', {})
        if 'text' in text_obj:
            text_content = text_obj['text']
            
            # Replace MODULES placeholder
            if '{{MODULES}}' in text_content:
                text_content = text_content.replace('{{MODULES}}', modules_text)
            
            # Replace VERIFICATION placeholder
            if '{{VERIFICATION}}' in text_content:
                text_content = text_content.replace('{{VERIFICATION}}', verification_text)
            
            # Replace FAILURE_CONTEXT placeholder
            if '{{FAILURE_CONTEXT}}' in text_content:
                if failure_text and failure_text.strip():
                    text_content = text_content.replace('{{FAILURE_CONTEXT}}', failure_text)
                else:
                    # Mark block for removal
                    block['_remove'] = True
                    continue
            
            text_obj['text'] = text_content

# Remove marked blocks and their preceding dividers
new_blocks = []
i = 0
while i < len(template['blocks']):
    block = template['blocks'][i]
    if block.get('_remove'):
        # Remove this block and preceding divider if exists
        if i > 0 and template['blocks'][i-1].get('type') == 'divider':
            new_blocks.pop()  # Remove the divider
        i += 1
        continue
    new_blocks.append(block)
    i += 1

template['blocks'] = new_blocks

# Output minified JSON
print(json.dumps(template, separators=(',', ':')))
PYEOF
2>/dev/null || echo "")"
    
    if [[ -z "$result" ]]; then
        return 0  # Soft-fail: failed to render
    fi
    
    echo "$result"
}


# ============================================================================
# Render Slack Block (Structured Block Kit)
# ============================================================================

notify::render::render_slack_block() {
    local json="$1"
    
    # Phase 4 Step 2 TASK 6: Detect release tier
    local release_tier
    release_tier="$(echo "$json" | jq -r '.release_tier // .release.release_tier // "preflight"' 2>/dev/null || echo "preflight")"
    local release_mode
    release_mode="$(echo "$json" | jq -r '.release_mode // .release.release_mode // "cli"' 2>/dev/null || echo "cli")"
    
    # Extract values from JSON
    local version author duration timestamp_raw
    version="$(echo "$json" | jq -r '.release.version // .version // ""' 2>/dev/null || echo "")"
    # Extract author: prefer .author.email, fallback to .author.name, then .author (if string)
    author="$(echo "$json" | jq -r '.author.email // .author.name // (if .author | type == "string" then .author else empty end) // ""' 2>/dev/null || echo "")"
    # Extract duration: prefer .timing.duration_human, fallback to .timing.duration, then .duration
    duration="$(echo "$json" | jq -r '.timing.duration_human // .timing.duration // .duration // ""' 2>/dev/null || echo "")"
    # Extract timestamp: prefer .timing.finished_at, fallback to .finished_at, then .timestamp
    timestamp_raw="$(echo "$json" | jq -r '.timing.finished_at // .finished_at // .timestamp // ""' 2>/dev/null || echo "")"
    
    # Format timestamp for Slack
    local slack_time
    slack_time="$(_notify_render::format_slack_timestamp "$timestamp_raw")"
    
    # Phase 4 Step 2: Route to tier-specific renderer
    if [[ "$release_tier" == "production" ]]; then
        _notify_render::render_production_blockkit "$json" "$version" "$author" "$duration" "$slack_time" "$release_mode"
    else
        _notify_render::render_preflight_blockkit "$json" "$version" "$author" "$duration" "$slack_time"
    fi
}

# ============================================================================
# Phase 4 Step 2: Production BlockKit Renderer
# ============================================================================

_notify_render::render_production_blockkit() {
    local json="$1"
    local version="$2"
    local author="$3"
    local duration="$4"
    local slack_time="$5"
    local release_mode="$6"
    
    if ! command -v python3 >/dev/null 2>&1; then
        return 0
    fi
    
    # Extract additional production-specific data
    local branch started_at ended_at
    branch="$(echo "$json" | jq -r '.release_branch // .git.release_branch // ""' 2>/dev/null || echo "")"
    started_at="$(echo "$json" | jq -r '.timestamps.timestamp_start // .timestamps.started_at // ""' 2>/dev/null || echo "")"
    ended_at="$(echo "$json" | jq -r '.timestamps.timestamp_end // .timestamps.updated_at // ""' 2>/dev/null || echo "")"
    
    # Extract pods lint results
    local pods_lint_errors pods_lint_warnings
    pods_lint_errors="$(echo "$json" | jq -r '.steps.pods.lint_errors // 0' 2>/dev/null || echo "0")"
    pods_lint_warnings="$(echo "$json" | jq -r '.steps.pods.lint_warnings // 0' 2>/dev/null || echo "0")"
    
    # Extract SPM manifest results
    local spm_manifest_status spm_manifest_errors spm_manifest_warnings
    spm_manifest_status="$(echo "$json" | jq -r '.steps.spm_manifest.status // "unknown"' 2>/dev/null || echo "unknown")"
    spm_manifest_errors="$(echo "$json" | jq -r '.steps.spm_manifest.errors // []' 2>/dev/null || echo "[]")"
    spm_manifest_warnings="$(echo "$json" | jq -r '.steps.spm_manifest.warnings // []' 2>/dev/null || echo "[]")"
    
    # Extract artifacts
    local xcframework_paths ipa_path spec_paths
    xcframework_paths="$(echo "$json" | jq -r '.artifacts.xcframework_paths // []' 2>/dev/null || echo "[]")"
    ipa_path="$(echo "$json" | jq -r '.artifacts.ipa_path // ""' 2>/dev/null || echo "")"
    spec_paths="$(echo "$json" | jq -r '.artifacts.spec_paths // []' 2>/dev/null || echo "[]")"
    
    # Extract release notes
    local release_notes
    release_notes="$(echo "$json" | jq -r '.release_notes // .release.notes // ""' 2>/dev/null || echo "")"
    
    # Extract errors
    local errors_json
    errors_json="$(echo "$json" | jq -r '.steps // {}' 2>/dev/null || echo "{}")"
    
    local result
    result="$(python3 <<PYEOF
import json
import sys

version = '''$version'''
author = '''$author'''
duration = '''$duration'''
slack_time = '''$slack_time'''
branch = '''$branch'''
started_at = '''$started_at'''
ended_at = '''$ended_at'''
release_mode = '''$release_mode'''
pods_lint_errors = int('''$pods_lint_errors''')
pods_lint_warnings = int('''$pods_lint_warnings''')
spm_manifest_status = '''$spm_manifest_status'''

# Parse JSON arrays
try:
    spm_errors = json.loads('''$spm_manifest_errors''')
    spm_warnings = json.loads('''$spm_manifest_warnings''')
    xcf_paths = json.loads('''$xcframework_paths''')
    spec_paths_list = json.loads('''$spec_paths''')
except:
    spm_errors = []
    spm_warnings = []
    xcf_paths = []
    spec_paths_list = []

ipa_path = '''$ipa_path'''
release_notes = '''$release_notes'''
steps_json = '''$errors_json'''

blocks = []

# Header with green border (Production)
blocks.append({
    "type": "header",
    "text": {
        "type": "plain_text",
        "text": "🟢 MSP iOS SDK Production Release"
    }
})

# Version (highlighted)
if version:
    blocks.append({
        "type": "section",
        "text": {
            "type": "mrkdwn",
            "text": f"*Version:* `{version}`"
        }
    })

# Meta info
meta_elements = []
if author:
    meta_elements.append({"type": "mrkdwn", "text": f"👤 {author}"})
if duration:
    meta_elements.append({"type": "mrkdwn", "text": f"⏱ {duration}"})
if branch:
    meta_elements.append({"type": "mrkdwn", "text": f"🌿 {branch}"})
if started_at:
    meta_elements.append({"type": "mrkdwn", "text": f"🕐 Started: {started_at}"})
if ended_at:
    meta_elements.append({"type": "mrkdwn", "text": f"✅ Ended: {ended_at}"})

if meta_elements:
    blocks.append({
        "type": "context",
        "elements": meta_elements
    })

blocks.append({"type": "divider"})

# Summary Section
blocks.append({
    "type": "section",
    "text": {
        "type": "mrkdwn",
        "text": "*📊 Summary*"
    }
})

# Pods Release Status
pods_status_text = "✅ CocoaPods Release: Success"
if pods_lint_errors > 0:
    pods_status_text = f"❌ CocoaPods Release: Failed ({pods_lint_errors} errors)"
elif pods_lint_warnings > 0:
    pods_status_text = f"⚠️ CocoaPods Release: Success ({pods_lint_warnings} warnings)"

blocks.append({
    "type": "section",
    "text": {
        "type": "mrkdwn",
        "text": pods_status_text
    }
})

# Pods Lint Results
if pods_lint_errors > 0 or pods_lint_warnings > 0:
    lint_details = f"Lint Errors: {pods_lint_errors}, Warnings: {pods_lint_warnings}"
    blocks.append({
        "type": "context",
        "elements": [{"type": "mrkdwn", "text": lint_details}]
    })

# SPM Release Status
spm_status_text = "✅ SPM Release: Success"
if spm_manifest_status == "error":
    spm_status_text = "❌ SPM Release: Failed"
elif spm_manifest_status == "warning":
    spm_status_text = "⚠️ SPM Release: Success (warnings)"

blocks.append({
    "type": "section",
    "text": {
        "type": "mrkdwn",
        "text": spm_status_text
    }
})

# SPM Manifest Results
if spm_errors or spm_warnings:
    manifest_details = []
    if spm_errors:
        manifest_details.append(f"Errors: {len(spm_errors)}")
    if spm_warnings:
        manifest_details.append(f"Warnings: {len(spm_warnings)}")
    if manifest_details:
        blocks.append({
            "type": "context",
            "elements": [{"type": "mrkdwn", "text": " | ".join(manifest_details)}]
        })

blocks.append({"type": "divider"})

# Verification Section (CLI only)
if release_mode == "cli":
    blocks.append({
        "type": "section",
        "text": {
            "type": "mrkdwn",
            "text": "*🔍 Verification*"
        }
    })
    
    # Parse verification results from steps
    try:
        steps = json.loads(steps_json)
        verifications = []
        
        if steps.get("local_verify", {}).get("status") == "success":
            verifications.append("✅ Local Verify: PASS")
        elif steps.get("local_verify", {}).get("status") == "failed":
            verifications.append("❌ Local Verify: FAIL")
        
        if steps.get("device_verify", {}).get("status") == "success":
            verifications.append("✅ Device Verify: PASS")
        elif steps.get("device_verify", {}).get("status") == "failed":
            verifications.append("❌ Device Verify: FAIL")
        
        if steps.get("xcframework_verify", {}).get("status") == "success":
            verifications.append("✅ XCFramework Verify: PASS")
        elif steps.get("xcframework_verify", {}).get("status") == "failed":
            verifications.append("❌ XCFramework Verify: FAIL")
        
        if verifications:
            blocks.append({
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": "\\n".join(verifications)
                }
            })
    except:
        pass
    
    blocks.append({"type": "divider"})

# Release Notes
if release_notes:
    blocks.append({
        "type": "section",
        "text": {
            "type": "mrkdwn",
            "text": "*📝 Release Notes*"
        }
    })
    
    # Truncate if too long (Slack limit ~3000 chars per block)
    notes_text = release_notes[:2000] + ("..." if len(release_notes) > 2000 else "")
    blocks.append({
        "type": "section",
        "text": {
            "type": "mrkdwn",
            "text": f"```{notes_text}```"
        }
    })
    
    blocks.append({"type": "divider"})

# Artifacts
artifacts_text = []
if xcf_paths:
    artifacts_text.append(f"*XCFrameworks:* {len(xcf_paths)} files")
if ipa_path:
    artifacts_text.append(f"*IPA:* {ipa_path}")
if spec_paths_list:
    artifacts_text.append(f"*Specs:* {len(spec_paths_list)} files")

if artifacts_text:
    blocks.append({
        "type": "section",
        "text": {
            "type": "mrkdwn",
            "text": "*📦 Artifacts*\\n" + "\\n".join(artifacts_text)
        }
    })
    blocks.append({"type": "divider"})

# Error Section
error_items = []
if pods_lint_errors > 0:
    error_items.append("❌ pods lint failed")
if spm_manifest_status == "error":
    error_items.append("❌ spm manifest mismatch")
if spm_errors:
    error_items.append("❌ spm tag missing")

# Check steps for failures
try:
    steps = json.loads(steps_json)
    if steps.get("local_verify", {}).get("status") == "failed":
        error_items.append("❌ local verify fail")
    if steps.get("device_verify", {}).get("status") == "failed":
        error_items.append("❌ device verify fail")
    if steps.get("xcframework_verify", {}).get("status") == "failed":
        error_items.append("❌ xcframework verify fail")
except:
    pass

if error_items:
    blocks.append({
        "type": "section",
        "text": {
            "type": "mrkdwn",
            "text": "*❌ Errors*\\n" + "\\n".join(error_items)
        }
    })

payload = {"blocks": blocks}
print(json.dumps(payload, separators=(',', ':')))
PYEOF
2>/dev/null || echo "")"
    
    if [[ -n "$result" ]]; then
        echo "$result"
    fi
}

# ============================================================================
# Phase 4 Step 2: Preflight BlockKit Renderer
# ============================================================================

_notify_render::render_preflight_blockkit() {
    local json="$1"
    local version="$2"
    local author="$3"
    local duration="$4"
    local slack_time="$5"
    
    if ! command -v python3 >/dev/null 2>&1; then
        return 0
    fi
    
    # Extract preflight-specific data
    local branch
    branch="$(echo "$json" | jq -r '.release_branch // .git.release_branch // ""' 2>/dev/null || echo "")"
    
    # Extract warnings and soft failures
    local pods_lint_warnings spm_manifest_warnings
    pods_lint_warnings="$(echo "$json" | jq -r '.steps.pods.lint_warnings // 0' 2>/dev/null || echo "0")"
    spm_manifest_warnings="$(echo "$json" | jq -r '.steps.spm_manifest.warnings // []' 2>/dev/null || echo "[]")"
    
    # Extract release notes
    local release_notes
    release_notes="$(echo "$json" | jq -r '.release_notes // .release.notes // ""' 2>/dev/null || echo "")"
    
    # Extract modules
    local modules_json
    modules_json="$(echo "$json" | jq -r '.modules // {}' 2>/dev/null || echo "{}")"
    
    local result
    result="$(python3 <<PYEOF
import json
import sys

version = '''$version'''
author = '''$author'''
duration = '''$duration'''
slack_time = '''$slack_time'''
branch = '''$branch'''
pods_lint_warnings = int('''$pods_lint_warnings''')

try:
    spm_warnings = json.loads('''$spm_manifest_warnings''')
    modules = json.loads('''$modules_json''')
except:
    spm_warnings = []
    modules = {}

release_notes = '''$release_notes'''

blocks = []

# Header (Preflight - lighter style)
blocks.append({
    "type": "section",
    "text": {
        "type": "mrkdwn",
        "text": f"🟡 *Preflight Release {version}*"
    }
})

# Meta info
meta_elements = []
if author:
    meta_elements.append({"type": "mrkdwn", "text": f"👤 {author}"})
if duration:
    meta_elements.append({"type": "mrkdwn", "text": f"⏱ {duration}"})
if branch:
    meta_elements.append({"type": "mrkdwn", "text": f"🌿 {branch}"})
if slack_time:
    meta_elements.append({"type": "mrkdwn", "text": f"🕐 {slack_time}"})

if meta_elements:
    blocks.append({
        "type": "context",
        "elements": meta_elements
    })

blocks.append({"type": "divider"})

# Version & Branch
if version:
    blocks.append({
        "type": "section",
        "fields": [
            {"type": "mrkdwn", "text": f"*Version:*\\n`{version}`"},
            {"type": "mrkdwn", "text": f"*Branch:*\\n{branch or 'N/A'}"}
        ]
    })

# Warnings
warnings_text = []
if pods_lint_warnings > 0:
    warnings_text.append(f"Pods Lint: {pods_lint_warnings} warnings")
if spm_warnings:
    warnings_text.append(f"SPM Manifest: {len(spm_warnings)} warnings")

if warnings_text:
    blocks.append({
        "type": "section",
        "text": {
            "type": "mrkdwn",
            "text": "*⚠️ Warnings*\\n" + "\\n".join([f"• {w}" for w in warnings_text])
        }
    })

blocks.append({"type": "divider"})

# Modules (full list)
if modules:
    module_items = [f"• {k} {v}" for k, v in modules.items()]
    blocks.append({
        "type": "section",
        "text": {
            "type": "mrkdwn",
            "text": "*📦 Modules*\\n" + "\\n".join(module_items)
        }
    })
    blocks.append({"type": "divider"})

# Release Notes (full)
if release_notes:
    blocks.append({
        "type": "section",
        "text": {
            "type": "mrkdwn",
            "text": "*📝 Release Notes*"
        }
    })
    
    notes_text = release_notes[:1500] + ("..." if len(release_notes) > 1500 else "")
    blocks.append({
        "type": "section",
        "text": {
            "type": "mrkdwn",
            "text": f"```{notes_text}```"
        }
    })

payload = {"blocks": blocks}
print(json.dumps(payload, separators=(',', ':')))
PYEOF
2>/dev/null || echo "")"
    
    if [[ -n "$result" ]]; then
        echo "$result"
    fi
}

# ============================================================================
# Generate Modules Block (Block Kit format)
# ============================================================================

_notify_render::generate_modules_block() {
    local json="$1"
    
    local modules_json
    modules_json="$(echo "$json" | jq -r '.modules // {}' 2>/dev/null || echo "{}")"
    
    if [[ "$modules_json" == "{}" ]] || [[ -z "$modules_json" ]]; then
        return 0  # Return empty, will be removed
    fi
    
    # Generate Block Kit section block for modules
    echo "$modules_json" | python3 -c "
import sys, json

modules = json.load(sys.stdin)
if not modules:
    sys.exit(0)

# Build module list text (show all modules, no truncation)
module_items = []
for module_name, version in modules.items():
    module_items.append(f'• {module_name} {version}')

module_lines = ['📦 *Modules*']
module_lines.extend(module_items)

module_text = '\n'.join(module_lines)

# Create Block Kit section block
block = {
    'type': 'section',
    'text': {
        'type': 'mrkdwn',
        'text': module_text
    }
}

print(json.dumps(block, separators=(',', ':')))
" 2>/dev/null || echo ""
}

# ============================================================================
# Generate Verification Block (Block Kit format)
# ============================================================================

_notify_render::generate_verification_block() {
    local json="$1"
    
    # Collect all verification statuses
    local verification_items=()
    
    # Remote SPM
    local remote_spm_executed remote_spm_success
    remote_spm_executed="$(echo "$json" | jq -r '.remote_verify.spm.executed // false' 2>/dev/null || echo "false")"
    remote_spm_success="$(echo "$json" | jq -r '.remote_verify.spm.success // false' 2>/dev/null || echo "false")"
    if [[ "$remote_spm_executed" == "true" ]]; then
        if [[ "$remote_spm_success" == "true" ]]; then
            verification_items+=("• SPM: PASS")
        else
            verification_items+=("• SPM: FAIL")
        fi
    fi
    
    # Remote Pods
    local remote_pods_executed remote_pods_success
    remote_pods_executed="$(echo "$json" | jq -r '.remote_verify.pods.executed // false' 2>/dev/null || echo "false")"
    remote_pods_success="$(echo "$json" | jq -r '.remote_verify.pods.success // false' 2>/dev/null || echo "false")"
    if [[ "$remote_pods_executed" == "true" ]]; then
        if [[ "$remote_pods_success" == "true" ]]; then
            verification_items+=("• Pods: PASS")
        else
            verification_items+=("• Pods: FAIL")
        fi
    fi
    
    # Local Verification
    local local_executed local_success local_mode
    local_executed="$(echo "$json" | jq -r '.local_verify.executed // false' 2>/dev/null || echo "false")"
    local_success="$(echo "$json" | jq -r '.local_verify.success // false' 2>/dev/null || echo "false")"
    local_mode="$(echo "$json" | jq -r '.local_verify.mode // ""' 2>/dev/null || echo "")"
    if [[ "$local_executed" == "true" ]]; then
        if [[ "$local_success" == "true" ]]; then
            verification_items+=("• Local: PASS")
        else
            verification_items+=("• Local: FAIL")
        fi
    fi
    
    # Device Verification
    local device_executed device_success device_mode
    device_executed="$(echo "$json" | jq -r '.device_verify.executed // false' 2>/dev/null || echo "false")"
    device_success="$(echo "$json" | jq -r '.device_verify.success // false' 2>/dev/null || echo "false")"
    device_mode="$(echo "$json" | jq -r '.device_verify.mode // ""' 2>/dev/null || echo "")"
    if [[ "$device_executed" == "true" ]]; then
        if [[ "$device_success" == "true" ]]; then
            verification_items+=("• Device: PASS")
        else
            verification_items+=("• Device: FAIL")
        fi
    fi
    
    # XCFramework Verification
    local xcf_modules_json
    xcf_modules_json="$(echo "$json" | jq -r '.xcframework_verify.modules // {}' 2>/dev/null || echo "{}")"
    if [[ "$xcf_modules_json" != "{}" ]] && [[ -n "$xcf_modules_json" ]]; then
        # Use process substitution to avoid subshell variable scoping issues
        while IFS= read -r line; do
            verification_items+=("$line")
        done < <(echo "$xcf_modules_json" | python3 -c "
import sys, json
modules = json.load(sys.stdin)
for module_name, data in modules.items():
    status = 'PASS' if data.get('success', False) else 'FAIL'
    warnings = data.get('warnings', 0)
    warn_text = f' ⚠️{warnings}' if warnings > 0 else ''
    print(f'• XC {module_name}: {status}{warn_text}')
" 2>/dev/null)
    fi
    
    if [[ ${#verification_items[@]} -eq 0 ]]; then
        return 0  # Return empty, will be removed
    fi
    
    # Generate Block Kit section block for verification (show all items, no truncation)
    local verification_text="🧪 *Verification*"
    local i=0
    while [[ $i -lt ${#verification_items[@]} ]]; do
        verification_text="$verification_text"$'\n'"${verification_items[$i]}"
        ((i++)) || true
    done
    
    python3 -c "
import sys, json
block = {
    'type': 'section',
    'text': {
        'type': 'mrkdwn',
        'text': '''$verification_text'''
    }
}
print(json.dumps(block, separators=(',', ':')))
" 2>/dev/null || echo ""
}

# ============================================================================
# Generate Failure Context Block (Block Kit format)
# ============================================================================

_notify_render::generate_failure_context_block() {
    local json="$1"
    
    local occurred
    occurred="$(echo "$json" | jq -r '.failure.occurred // false' 2>/dev/null || echo "false")"
    
    if [[ "$occurred" != "true" ]]; then
        return 0  # Return empty, will be removed
    fi
    
    local stage module script reason log_path
    stage="$(echo "$json" | jq -r '.failure.stage // ""' 2>/dev/null || echo "")"
    module="$(echo "$json" | jq -r '.failure.module // ""' 2>/dev/null || echo "")"
    script="$(echo "$json" | jq -r '.failure.script // ""' 2>/dev/null || echo "")"
    reason="$(echo "$json" | jq -r '.failure.reason // ""' 2>/dev/null || echo "")"
    log_path="$(echo "$json" | jq -r '.failure.log_path // ""' 2>/dev/null || echo "")"
    
    local failure_text="❌ Failure: $stage"
    [[ -n "$module" ]] && failure_text="$failure_text/$module"
    failure_text="$failure_text"$'\n'"  → $reason"
    [[ -n "$log_path" ]] && failure_text="$failure_text"$'\n'"  📄 $log_path"
    
    # Generate Block Kit section block for failure
    python3 -c "
import sys, json
block = {
    'type': 'section',
    'text': {
        'type': 'mrkdwn',
        'text': '''$failure_text'''
    }
}
print(json.dumps(block, separators=(',', ':')))
" 2>/dev/null || echo ""
}

# ============================================================================
# Generate Release Notes Block (Block Kit format)
# ============================================================================

_notify_render::generate_release_notes_block() {
    local json="$1"
    
    # Extract release notes
    local release_notes
    release_notes="$(echo "$json" | jq -r '.release_notes // .release.notes // ""' 2>/dev/null || echo "")"
    
    if [[ -z "$release_notes" ]]; then
        return 0  # Return empty if no release notes
    fi
    
    # Show full release notes (no truncation)
    # Generate Block Kit section block for release notes
    python3 -c "
import sys, json
release_notes_str = '''$release_notes'''
block = {
    'type': 'section',
    'text': {
        'type': 'mrkdwn',
        'text': '📄 *Release Notes*\\n' + release_notes_str
    }
}
print(json.dumps(block, separators=(',', ':')))
" 2>/dev/null || echo ""
}
