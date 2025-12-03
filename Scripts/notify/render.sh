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
    
    echo "$modules_json" | jq -r 'to_entries[] | "  • \(.key) \(.value)"' 2>/dev/null | while IFS= read -r line; do
        if [[ $first -eq 1 ]]; then
            output="$line"
            first=0
        else
            output="$output"$'\n'"$line"
        fi
    done
    
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
    version="$(echo "$json" | jq -r '.version // ""' 2>/dev/null || echo "")"
    author="$(echo "$json" | jq -r '.author // ""' 2>/dev/null || echo "")"
    duration="$(echo "$json" | jq -r '.duration // ""' 2>/dev/null || echo "")"
    timestamp="$(echo "$json" | jq -r '.timestamp // ""' 2>/dev/null || echo "")"
    
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
    version="$(echo "$json" | jq -r '.version // ""' 2>/dev/null || echo "")"
    author="$(echo "$json" | jq -r '.author // ""' 2>/dev/null || echo "")"
    duration="$(echo "$json" | jq -r '.duration // ""' 2>/dev/null || echo "")"
    timestamp="$(echo "$json" | jq -r '.timestamp // ""' 2>/dev/null || echo "")"
    
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
    local version author duration timestamp
    version="$(echo "$json" | jq -r '.version // empty' 2>/dev/null || echo "")"
    author="$(echo "$json" | jq -r '.author // empty' 2>/dev/null || echo "")"
    duration="$(echo "$json" | jq -r '.duration // empty' 2>/dev/null || echo "")"
    timestamp="$(echo "$json" | jq -r '.timestamp // empty' 2>/dev/null || echo "")"
    
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
    
    # First replace placeholders to get rendered template
    html="${html//\{\{VERSION\}\}/$version}"
    html="${html//\{\{AUTHOR\}\}/$author}"
    html="${html//\{\{DURATION\}\}/$duration}"
    html="${html//\{\{TIMESTAMP\}\}/$timestamp}"
    html="${html//\{\{STATUS\}\}/$status}"
    html="${html//\{\{STATUS_CLASS\}\}/$header_status_class}"
    
    # Now replace the header title and meta lines with our computed values
    # Use sed for more robust pattern matching that handles leading whitespace
    # Escape special characters in replacement strings for sed
    local final_title_escaped final_meta_escaped
    final_title_escaped="$(printf '%s\n' "$final_title" | sed 's/[[\.*^$()+?{|]/\\&/g')"
    final_meta_escaped="$(printf '%s\n' "$final_meta" | sed 's/[[\.*^$()+?{|]/\\&/g')"
    
    html="$(echo "$html" | sed "s|<h1>MSP Release Summary — [^<]*</h1>|<h1>$final_title_escaped</h1>|g")"
    html="$(echo "$html" | sed "s|<p>Author: [^<]*</p>|<p>$final_meta_escaped</p>|g")"
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
    version="$(echo "$json" | jq -r '.version // ""' 2>/dev/null || echo "")"
    author="$(echo "$json" | jq -r '.author // ""' 2>/dev/null || echo "")"
    duration="$(echo "$json" | jq -r '.duration // ""' 2>/dev/null || echo "")"
    timestamp="$(echo "$json" | jq -r '.timestamp // ""' 2>/dev/null || echo "")"
    
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
    
    if [[ -z "$SLACK_BLOCK_TEMPLATE" ]]; then
        return 0  # Soft-fail: template not loaded
    fi
    
    # Extract values from JSON
    local version author duration timestamp
    version="$(echo "$json" | jq -r '.version // ""' 2>/dev/null || echo "")"
    author="$(echo "$json" | jq -r '.author // ""' 2>/dev/null || echo "")"
    duration="$(echo "$json" | jq -r '.duration // ""' 2>/dev/null || echo "")"
    timestamp="$(echo "$json" | jq -r '.timestamp // ""' 2>/dev/null || echo "")"
    
    # Generate Block Kit blocks for modules, verification, and failure
    local modules_block verification_block failure_context_block
    
    # Generate MODULES_BLOCK
    modules_block="$(_notify_render::generate_modules_block "$json" 2>/dev/null || echo "")"
    
    # Generate VERIFICATION_BLOCK
    verification_block="$(_notify_render::generate_verification_block "$json" 2>/dev/null || echo "")"
    
    # Generate FAILURE_CONTEXT_BLOCK
    failure_context_block="$(_notify_render::generate_failure_context_block "$json" 2>/dev/null || echo "")"
    
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

# Replace block placeholders
modules_block_str = '''$modules_block'''
verification_block_str = '''$verification_block'''
failure_block_str = '''$failure_context_block'''

# Replace MODULES_BLOCK
if modules_block_str and modules_block_str.strip():
    template_str = template_str.replace('{{MODULES_BLOCK}}', modules_block_str)
else:
    # Remove MODULES_BLOCK placeholder and preceding divider if empty
    template_str = template_str.replace(',\n        {{MODULES_BLOCK}},', '')
    template_str = template_str.replace('        {{MODULES_BLOCK}},', '')

# Replace VERIFICATION_BLOCK
if verification_block_str and verification_block_str.strip():
    template_str = template_str.replace('{{VERIFICATION_BLOCK}}', verification_block_str)
else:
    # Remove VERIFICATION_BLOCK placeholder and preceding divider if empty
    template_str = template_str.replace(',\n        {{VERIFICATION_BLOCK}},', '')
    template_str = template_str.replace('        {{VERIFICATION_BLOCK}},', '')

# Replace FAILURE_CONTEXT_BLOCK
if failure_block_str and failure_block_str.strip():
    template_str = template_str.replace('{{FAILURE_CONTEXT_BLOCK}}', failure_block_str)
else:
    # Remove FAILURE_CONTEXT_BLOCK placeholder and preceding divider if empty
    template_str = template_str.replace(',\n        {{FAILURE_CONTEXT_BLOCK}},', '')
    template_str = template_str.replace('        {{FAILURE_CONTEXT_BLOCK}},', '')

# Parse template JSON
try:
    template = json.loads(template_str)
except Exception as e:
    sys.exit(1)

# Clean up empty blocks and extra dividers
if 'blocks' in template:
    new_blocks = []
    i = 0
    while i < len(template['blocks']):
        block = template['blocks'][i]
        # Skip empty or None blocks
        if block is None:
            i += 1
            continue
        # Remove duplicate dividers
        if block.get('type') == 'divider' and i > 0 and template['blocks'][i-1].get('type') == 'divider':
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

# Build module list text
module_lines = ['*📦 Modules Released*']
for module_name, version in modules.items():
    module_lines.append(f'  • {module_name} ({version})')

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
            verification_items+=("✔ SPM: PASS")
        else
            verification_items+=("❌ SPM: FAIL")
        fi
    fi
    
    # Remote Pods
    local remote_pods_executed remote_pods_success
    remote_pods_executed="$(echo "$json" | jq -r '.remote_verify.pods.executed // false' 2>/dev/null || echo "false")"
    remote_pods_success="$(echo "$json" | jq -r '.remote_verify.pods.success // false' 2>/dev/null || echo "false")"
    if [[ "$remote_pods_executed" == "true" ]]; then
        if [[ "$remote_pods_success" == "true" ]]; then
            verification_items+=("✔ Pods: PASS")
        else
            verification_items+=("❌ Pods: FAIL")
        fi
    fi
    
    # Local Verification
    local local_executed local_success local_mode
    local_executed="$(echo "$json" | jq -r '.local_verify.executed // false' 2>/dev/null || echo "false")"
    local_success="$(echo "$json" | jq -r '.local_verify.success // false' 2>/dev/null || echo "false")"
    local_mode="$(echo "$json" | jq -r '.local_verify.mode // ""' 2>/dev/null || echo "")"
    if [[ "$local_executed" == "true" ]]; then
        if [[ "$local_success" == "true" ]]; then
            verification_items+=("✔ Local ($local_mode): PASS")
        else
            verification_items+=("❌ Local ($local_mode): FAIL")
        fi
    fi
    
    # Device Verification
    local device_executed device_success device_mode
    device_executed="$(echo "$json" | jq -r '.device_verify.executed // false' 2>/dev/null || echo "false")"
    device_success="$(echo "$json" | jq -r '.device_verify.success // false' 2>/dev/null || echo "false")"
    device_mode="$(echo "$json" | jq -r '.device_verify.mode // ""' 2>/dev/null || echo "")"
    if [[ "$device_executed" == "true" ]]; then
        if [[ "$device_success" == "true" ]]; then
            verification_items+=("✔ Device ($device_mode): PASS")
        else
            verification_items+=("❌ Device ($device_mode): FAIL")
        fi
    fi
    
    # XCFramework Verification
    local xcf_modules_json
    xcf_modules_json="$(echo "$json" | jq -r '.xcframework_verify.modules // {}' 2>/dev/null || echo "{}")"
    if [[ "$xcf_modules_json" != "{}" ]] && [[ -n "$xcf_modules_json" ]]; then
        echo "$xcf_modules_json" | python3 -c "
import sys, json
modules = json.load(sys.stdin)
for module_name, data in modules.items():
    status = '✔' if data.get('success', False) else '❌'
    warnings = data.get('warnings', 0)
    warn_text = f' ⚠️{warnings}' if warnings > 0 else ''
    print(f'{status} XCF {module_name}: {\"PASS\" if data.get(\"success\", False) else \"FAIL\"}{warn_text}')
" 2>/dev/null | while IFS= read -r line; do
            verification_items+=("$line")
        done
    fi
    
    if [[ ${#verification_items[@]} -eq 0 ]]; then
        return 0  # Return empty, will be removed
    fi
    
    # Generate Block Kit section block for verification
    local verification_text="*🧪 Verification Summary*"
    for item in "${verification_items[@]}"; do
        verification_text="$verification_text"$'\n'"  $item"
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
