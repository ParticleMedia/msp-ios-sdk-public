#!/bin/bash
# ============================================================================
# Notification Template Rendering Engine
# ============================================================================
# Purpose: Render notification templates with placeholder replacement
#
# Usage:   Source this file and call render functions
# ============================================================================

set -euo pipefail

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
    
    # Try to convert ISO8601 to unix timestamp
    local unix_ts
    unix_ts="$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$iso8601" "+%s" 2>/dev/null || \
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
    
    if [[ -z "$EMAIL_HTML_TEMPLATE" ]]; then
        echo "Warning: Email HTML template not loaded" >&2
        return 0  # Soft-fail
    fi
    
    # ============================================================================
    # Email Header Extraction with Defensive Fallbacks
    # ============================================================================
    # This section provides safe default header content for older/not-yet-updated
    # orchestrator JSON payloads. It first tries dedicated email header fields,
    # then falls back to general release fields, ensuring the header is never empty.
    # ============================================================================
    
    # Try dedicated email header fields first
    local header_title header_meta header_status_class
    header_title="$(echo "$json" | jq -r '.email.header.title // empty' 2>/dev/null || echo "")"
    header_meta="$(echo "$json" | jq -r '.email.header.meta // empty' 2>/dev/null || echo "")"
    header_status_class="$(echo "$json" | jq -r '.email.header.status_class // empty' 2>/dev/null || echo "")"
    
    # Build fallback title if header_title is empty
    if [[ -z "$header_title" ]]; then
        local release_version release_environment release_channel
        release_version="$(echo "$json" | jq -r '.release.version // .version // empty' 2>/dev/null || echo "")"
        release_environment="$(echo "$json" | jq -r '.release.environment // .release.channel // empty' 2>/dev/null || echo "")"
        
        header_title="MSP Release Summary"
        [[ -n "$release_version" ]] && header_title="$header_title — $release_version"
        [[ -n "$release_environment" ]] && header_title="$header_title ($release_environment)"
    fi
    
    # Build fallback meta line if header_meta is empty
    if [[ -z "$header_meta" ]]; then
        local author_email author_name author_fallback
        local duration_human duration_fallback
        local finished_at timestamp_fallback
        
        # Author: prefer .author.email, fallback to .author.name, then .author (if string)
        author_email="$(echo "$json" | jq -r '.author.email // empty' 2>/dev/null || echo "")"
        author_name="$(echo "$json" | jq -r '.author.name // empty' 2>/dev/null || echo "")"
        # Check if .author is a string (not an object)
        author_type="$(echo "$json" | jq -r 'if .author | type == "string" then .author else empty end' 2>/dev/null || echo "")"
        
        local author_part=""
        if [[ -n "$author_email" ]]; then
            author_part="$author_email"
        elif [[ -n "$author_name" ]]; then
            author_part="$author_name"
        elif [[ -n "$author_type" ]]; then
            author_part="$author_type"
        fi
        
        # Duration: prefer .timing.duration_human, fallback to .timing.duration, then .duration
        duration_human="$(echo "$json" | jq -r '.timing.duration_human // empty' 2>/dev/null || echo "")"
        duration_fallback="$(echo "$json" | jq -r '.timing.duration // .duration // empty' 2>/dev/null || echo "")"
        
        local duration_part=""
        if [[ -n "$duration_human" ]]; then
            duration_part="$duration_human"
        elif [[ -n "$duration_fallback" ]]; then
            duration_part="$duration_fallback"
        fi
        
        # Timestamp: prefer .timing.finished_at, fallback to .finished_at, then .timestamp
        finished_at="$(echo "$json" | jq -r '.timing.finished_at // .finished_at // empty' 2>/dev/null || echo "")"
        timestamp_fallback="$(echo "$json" | jq -r '.timestamp // empty' 2>/dev/null || echo "")"
        
        local timestamp_part=""
        if [[ -n "$finished_at" ]]; then
            timestamp_part="$finished_at"
        elif [[ -n "$timestamp_fallback" ]]; then
            timestamp_part="$timestamp_fallback"
        fi
        
        # Build meta line by joining non-empty parts with " | "
        local meta_parts=()
        [[ -n "$author_part" ]] && meta_parts+=("Author: $author_part")
        [[ -n "$duration_part" ]] && meta_parts+=("Duration: $duration_part")
        [[ -n "$timestamp_part" ]] && meta_parts+=("Time: $timestamp_part")
        
        if [[ ${#meta_parts[@]} -gt 0 ]]; then
            header_meta="$(IFS=' | '; echo "${meta_parts[*]}")"
        else
            header_meta="MSP Release Pipeline"
        fi
    fi
    
    # Derive status_class if header_status_class is empty
    if [[ -z "$header_status_class" ]]; then
        local generic_status
        generic_status="$(echo "$json" | jq -r '.status // empty' 2>/dev/null || echo "")"
        
        case "$generic_status" in
            success|Success|SUCCESS)
                header_status_class="success"
                ;;
            failure|Failure|FAILURE|failed|Failed|FAILED)
                header_status_class="failed"
                ;;
            *)
                # Fallback to existing logic
                local failure_occurred overall_success
                failure_occurred="$(echo "$json" | jq -r '.failure.occurred // false' 2>/dev/null || echo "false")"
                overall_success="$(echo "$json" | jq -r '.success // true' 2>/dev/null || echo "true")"
                
                if [[ "$failure_occurred" == "true" ]] || [[ "$overall_success" == "false" ]]; then
                    header_status_class="failed"
                else
                    header_status_class="success"
                fi
                ;;
        esac
    fi
    
    # Optional debug output (only when MSP_DEBUG_NOTIFY_EMAIL_HEADER=1)
    if [[ "${MSP_DEBUG_NOTIFY_EMAIL_HEADER:-}" == "1" ]]; then
        echo "[notify][debug] email header_title: $header_title" >&2
        echo "[notify][debug] email header_meta: $header_meta" >&2
        echo "[notify][debug] email status_class: $header_status_class" >&2
    fi
    
    # For backward compatibility, also extract individual fields for template replacement
    # (These are used by the existing template placeholders)
    # Use the same fallback logic as header extraction
    local version author duration timestamp
    
    # Version: prefer .release.version, fallback to .version
    version="$(echo "$json" | jq -r '.release.version // .version // empty' 2>/dev/null || echo "")"
    
    # Author: prefer .author.email, fallback to .author.name, then .author (if string)
    author="$(echo "$json" | jq -r '.author.email // .author.name // (if .author | type == "string" then .author else empty end) // empty' 2>/dev/null || echo "")"
    
    # Duration: prefer .timing.duration_human, fallback to .timing.duration, then .duration
    duration="$(echo "$json" | jq -r '.timing.duration_human // .timing.duration // .duration // empty' 2>/dev/null || echo "")"
    
    # Timestamp: prefer .timing.finished_at, fallback to .finished_at, then .timestamp
    timestamp="$(echo "$json" | jq -r '.timing.finished_at // .finished_at // .timestamp // empty' 2>/dev/null || echo "")"
    
    # Set defaults if empty (for backward compatibility with existing template)
    version="${version:-unknown}"
    author="${author:-unknown}"
    duration="${duration:-unknown}"
    timestamp="${timestamp:-unknown}"
    
    # Generate HTML sections
    local modules_html verification_html failure_context_html
    modules_html="$(_notify_render::generate_modules_html "$json" 2>/dev/null || echo "<p>(none)</p>")"
    verification_html="$(_notify_render::generate_verification_html "$json" 2>/dev/null || echo "<p>(none)</p>")"
    failure_context_html="$(_notify_render::generate_failure_context_html "$json" 2>/dev/null || echo "")"
    
    # Determine status for template (used by {{STATUS}} placeholder)
    local failure_occurred overall_success
    failure_occurred="$(echo "$json" | jq -r '.failure.occurred // false' 2>/dev/null || echo "false")"
    overall_success="$(echo "$json" | jq -r '.success // true' 2>/dev/null || echo "true")"
    
    local status
    if [[ "$failure_occurred" == "true" ]] || [[ "$overall_success" == "false" ]]; then
        status="Failed"
    else
        status="Success"
    fi
    
    # Build final title and meta strings for template replacement
    local final_title final_meta
    if [[ -n "$header_title" ]]; then
        final_title="$header_title"
    else
        # Build from version (backward compatibility)
        if [[ "$version" != "unknown" ]]; then
            final_title="MSP Release Summary — $version"
        else
            final_title="MSP Release Summary"
        fi
    fi
    
    if [[ -n "$header_meta" ]]; then
        final_meta="$header_meta"
    else
        # Build from individual fields (backward compatibility)
        local meta_parts=()
        [[ "$author" != "unknown" ]] && meta_parts+=("Author: $author")
        [[ "$duration" != "unknown" ]] && meta_parts+=("Duration: $duration")
        [[ "$timestamp" != "unknown" ]] && meta_parts+=("Time: $timestamp")
        
        if [[ ${#meta_parts[@]} -gt 0 ]]; then
            final_meta="$(IFS=' | '; echo "${meta_parts[*]}")"
        else
            final_meta="MSP Release Pipeline"
        fi
    fi
    
    # Apply all replacements sequentially (compatible with all bash versions)
    local html="$EMAIL_HTML_TEMPLATE"
    
    # Replace header title and meta lines BEFORE placeholder replacement
    # This avoids issues with JSON objects being inserted into placeholders
    # Use sed with # as delimiter and properly escape replacement strings
    # Escape special sed characters in replacement strings
    local final_title_safe final_meta_safe
    final_title_safe="$(printf '%s\n' "$final_title" | sed 's/[[\.*^$()+?{|]/\\&/g' | sed 's/#/\\#/g')"
    final_meta_safe="$(printf '%s\n' "$final_meta" | sed 's/[[\.*^$()+?{|]/\\&/g' | sed 's/#/\\#/g')"
    
    # Replace title line (match exact pattern with leading spaces, handle inline styles)
    # Pattern must match both with and without inline styles
    html="$(echo "$html" | sed "s#    <h1[^>]*>MSP Release Summary — {{VERSION}}</h1>#    <h1 style=\"color: white !important; margin: 0; padding: 0;\">$final_title_safe</h1>#")"
    
    # Replace meta line (match exact pattern with leading spaces, handle inline styles)
    html="$(echo "$html" | sed "s#    <p[^>]*>Author: {{AUTHOR}} | Duration: {{DURATION}} | Time: {{TIMESTAMP}}</p>#    <p style=\"color: white !important; margin: 10px 0 0 0;\">$final_meta_safe</p>#")"
    
    # Now replace remaining placeholders (for other sections that might use them)
    html="${html//\{\{VERSION\}\}/$version}"
    html="${html//\{\{AUTHOR\}\}/$author}"
    html="${html//\{\{DURATION\}\}/$duration}"
    html="${html//\{\{TIMESTAMP\}\}/$timestamp}"
    html="${html//\{\{STATUS\}\}/$status}"
    html="${html//\{\{STATUS_CLASS\}\}/$header_status_class}"
    html="${html//\{\{MODULES_HTML\}\}/$modules_html}"
    html="${html//\{\{VERIFICATION_HTML\}\}/$verification_html}"
    
    # Handle failure context - remove placeholder if empty
    if [[ -z "$failure_context_html" ]] || [[ "$failure_context_html" == "" ]]; then
        html="${html//\{\{FAILURE_CONTEXT_HTML\}\}/}"
    else
        html="${html//\{\{FAILURE_CONTEXT_HTML\}\}/$failure_context_html}"
    fi
    
    # Write to preview file (soft-fail if directory creation fails)
    mkdir -p Tests/notify_output 2>/dev/null || true
    printf '%s\n' "$html" > Tests/notify_output/email_preview.html 2>/dev/null || true
    
    printf '%s\n' "$html"
}

# ============================================================================
# Render Slack Block Kit
# ============================================================================

notify::render::render_slack_blockkit() {
    local json="$1"
    
    if [[ -z "$SLACK_BLOCKKIT_TEMPLATE" ]]; then
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
template_str = '''$SLACK_BLOCKKIT_TEMPLATE'''

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
    
    # Generate Block Kit blocks for modules, verification, and release notes
    local modules_block verification_block release_notes_block
    
    # Generate MODULES_BLOCK
    modules_block="$(_notify_render::generate_modules_block "$json" 2>/dev/null || echo "")"
    
    # Generate VERIFICATION_BLOCK
    verification_block="$(_notify_render::generate_verification_block "$json" 2>/dev/null || echo "")"
    
    # Generate RELEASE_NOTES_BLOCK
    release_notes_block="$(_notify_render::generate_release_notes_block "$json" 2>/dev/null || echo "")"
    
    # Use Python to build BlockKit JSON
    if ! command -v python3 >/dev/null 2>&1; then
        return 0  # Soft-fail: python3 not available
    fi
    
    # Write blocks to temp files to avoid shell escaping issues
    local temp_dir
    temp_dir="$(mktemp -d)" || return 0
    
    [[ -n "$modules_block" ]] && echo "$modules_block" > "$temp_dir/modules.json" || true
    [[ -n "$verification_block" ]] && echo "$verification_block" > "$temp_dir/verification.json" || true
    [[ -n "$release_notes_block" ]] && echo "$release_notes_block" > "$temp_dir/release_notes.json" || true
    
    local result
    result="$(python3 <<PYEOF
import json
import sys
import os

temp_dir = '''$temp_dir'''

# Build blocks array
blocks = []

# Header/Title (section)
version_str = '''$version'''
if version_str:
    blocks.append({
        "type": "section",
        "text": {
            "type": "mrkdwn",
            "text": "🎉 *MSP Release " + version_str + "*"
        }
    })

# Meta info (context)
meta_elements = []
author_str = '''$author'''
duration_str = '''$duration'''
slack_time_str = '''$slack_time'''

if author_str:
    meta_elements.append({"type": "mrkdwn", "text": "👤 " + author_str})
if duration_str:
    meta_elements.append({"type": "mrkdwn", "text": "⏱ " + duration_str})
if slack_time_str:
    meta_elements.append({"type": "mrkdwn", "text": "🕐 " + slack_time_str})

if meta_elements:
    blocks.append({
        "type": "context",
        "elements": meta_elements
    })

# Divider
blocks.append({"type": "divider"})

# Modules section
modules_file = os.path.join(temp_dir, "modules.json")
if os.path.exists(modules_file):
    try:
        with open(modules_file, 'r', encoding='utf-8') as f:
            modules_block_obj = json.load(f)
            if modules_block_obj:
                blocks.append(modules_block_obj)
                blocks.append({"type": "divider"})
    except Exception:
        pass

# Verification section
verification_file = os.path.join(temp_dir, "verification.json")
if os.path.exists(verification_file):
    try:
        with open(verification_file, 'r', encoding='utf-8') as f:
            verification_block_obj = json.load(f)
            if verification_block_obj:
                blocks.append(verification_block_obj)
                blocks.append({"type": "divider"})
    except Exception:
        pass

# Release notes section
release_notes_file = os.path.join(temp_dir, "release_notes.json")
if os.path.exists(release_notes_file):
    try:
        with open(release_notes_file, 'r', encoding='utf-8') as f:
            release_notes_block_obj = json.load(f)
            if release_notes_block_obj:
                blocks.append(release_notes_block_obj)
    except Exception:
        pass

# Build final payload
payload = {"blocks": blocks}

# Output minified JSON
print(json.dumps(payload, separators=(',', ':')))
PYEOF
2>/dev/null || echo "")"
    
    # Cleanup temp directory
    rm -rf "$temp_dir" 2>/dev/null || true
    
    if [[ -z "$result" ]]; then
        return 0  # Soft-fail: failed to render
    fi
    
    echo "$result"
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
        ((i++))
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
