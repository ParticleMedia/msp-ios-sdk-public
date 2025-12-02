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
EMAIL_SUBJECT_TEMPLATE=""
EMAIL_HTML_TEMPLATE=""

# ============================================================================
# Initialize Templates from YAML
# ============================================================================

notify::render::init_templates() {
    local mapping_file="${ROOT_DIR:-.}/Scripts/config/notify_mapping.yaml"
    
    if [[ ! -f "$mapping_file" ]]; then
        echo "Warning: notify_mapping.yaml not found" >&2
        return 1
    fi
    
    # Parse YAML using Python (if available)
    if command -v python3 >/dev/null 2>&1; then
        local yaml_data
        yaml_data="$(python3 <<'PYEOF'
import yaml
import json
import sys

try:
    with open(sys.argv[1], 'r') as f:
        data = yaml.safe_load(f)
    print(json.dumps(data))
except Exception as e:
    print(json.dumps({}), file=sys.stderr)
    sys.exit(1)
PYEOF
"$mapping_file" 2>/dev/null || echo "{}")"
        
        if [[ -n "$yaml_data" ]] && [[ "$yaml_data" != "{}" ]]; then
            # Extract Slack templates
            SLACK_DM_TEMPLATE="$(echo "$yaml_data" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('slack', {}).get('dm_template', ''))" 2>/dev/null || echo "")"
            SLACK_CHANNEL_TEMPLATE="$(echo "$yaml_data" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('slack', {}).get('channel_template', ''))" 2>/dev/null || echo "")"
            
            # Extract Email templates
            EMAIL_SUBJECT_TEMPLATE="$(echo "$yaml_data" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('email', {}).get('subject_template', ''))" 2>/dev/null || echo "")"
            EMAIL_HTML_TEMPLATE="$(echo "$yaml_data" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('email', {}).get('html_template', ''))" 2>/dev/null || echo "")"
        fi
    fi
    
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
    
    echo "$modules_json" | jq -r 'to_entries[] | "\(.key) (\(.value))"' 2>/dev/null | while IFS= read -r line; do
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
        echo "<p>(none)</p>"
        return 0
    fi
    
    local output=""
    echo "$modules_json" | jq -r 'to_entries[] | "<div class=\"module\">\(.key) <span class=\"version\">\(.value)</span></div>"' 2>/dev/null | while IFS= read -r line; do
        if [[ -z "$output" ]]; then
            output="$line"
        else
            output="$output"$'\n'"$line"
        fi
    done
    
    echo "$output"
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
            output="    - SPM: PASS"
        else
            output="    - SPM: FAIL"
        fi
    fi
    
    if [[ "$remote_pods_executed" == "true" ]]; then
        if [[ "$remote_pods_success" == "true" ]]; then
            if [[ -z "$output" ]]; then
                output="    - Pods: PASS"
            else
                output="$output"$'\n'"    - Pods: PASS"
            fi
        else
            if [[ -z "$output" ]]; then
                output="    - Pods: FAIL"
            else
                output="$output"$'\n'"    - Pods: FAIL"
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
                output="    - Local ($local_mode): PASS"
            else
                output="$output"$'\n'"    - Local ($local_mode): PASS"
            fi
        else
            if [[ -z "$output" ]]; then
                output="    - Local ($local_mode): FAIL"
            else
                output="$output"$'\n'"    - Local ($local_mode): FAIL"
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
                output="    - Device ($device_mode): PASS"
            else
                output="$output"$'\n'"    - Device ($device_mode): PASS"
            fi
        else
            if [[ -z "$output" ]]; then
                output="    - Device ($device_mode): FAIL"
            else
                output="$output"$'\n'"    - Device ($device_mode): FAIL"
            fi
        fi
    fi
    
    # XCFramework Verification
    local xcf_modules_json
    xcf_modules_json="$(echo "$json" | jq -r '.xcframework_verify.modules // {}' 2>/dev/null || echo "{}")"
    
    if [[ "$xcf_modules_json" != "{}" ]] && [[ -n "$xcf_modules_json" ]]; then
        echo "$xcf_modules_json" | jq -r 'to_entries[] | "    - XCFramework \(.key): \(if .value.success then "PASS" else "FAIL" end)\(if .value.warnings > 0 then " (\(.value.warnings) warnings)" else "" end)"' 2>/dev/null | while IFS= read -r line; do
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
        echo "$xcf_modules_json" | jq -r 'to_entries[] | "<div class=\"verification-item\"><span class=\"\(if .value.success then "success" else "failure" end)\">\(if .value.success then "✓" else "✗" end)</span> XCFramework \(.key): \(if .value.success then "PASS" else "FAIL" end)\(if .value.warnings > 0 then " <span class=\"warning\">(\(.value.warnings) warnings)</span>" else "" end)</div>"' 2>/dev/null | while IFS= read -r line; do
            if [[ -z "$output" ]]; then
                output="$line"
            else
                output="$output"$'\n'"$line"
            fi
        done
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
    
    local output="❌ Failure Detected:"
    [[ -n "$stage" ]] && output="$output"$'\n'"  Stage: $stage"
    [[ -n "$module" ]] && output="$output"$'\n'"  Module: $module"
    [[ -n "$script" ]] && output="$output"$'\n'"  Script: $script"
    [[ -n "$reason" ]] && output="$output"$'\n'"  Reason: $reason"
    [[ -n "$log_path" ]] && output="$output"$'\n'"  Log: $log_path"
    
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
        return 1
    fi
    
    local version author duration timestamp
    version="$(echo "$json" | jq -r '.version // ""' 2>/dev/null || echo "")"
    author="$(echo "$json" | jq -r '.author // ""' 2>/dev/null || echo "")"
    duration="$(echo "$json" | jq -r '.duration // ""' 2>/dev/null || echo "")"
    timestamp="$(echo "$json" | jq -r '.timestamp // ""' 2>/dev/null || echo "")"
    
    local modules verification failure_context
    modules="$(_notify_render::generate_modules_text "$json")"
    verification="$(_notify_render::generate_verification_text "$json")"
    failure_context="$(_notify_render::generate_failure_context "$json")"
    
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
        return 1
    fi
    
    local version author duration timestamp
    version="$(echo "$json" | jq -r '.version // ""' 2>/dev/null || echo "")"
    author="$(echo "$json" | jq -r '.author // ""' 2>/dev/null || echo "")"
    duration="$(echo "$json" | jq -r '.duration // ""' 2>/dev/null || echo "")"
    timestamp="$(echo "$json" | jq -r '.timestamp // ""' 2>/dev/null || echo "")"
    
    local modules_short verification_short failure_context_short
    modules_short="$(_notify_render::generate_modules_short "$json")"
    verification_short="$(_notify_render::generate_verification_short "$json")"
    failure_context_short="$(_notify_render::generate_failure_context_short "$json")"
    
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
        return 1
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
        return 1
    fi
    
    local version author duration timestamp
    version="$(echo "$json" | jq -r '.version // ""' 2>/dev/null || echo "")"
    author="$(echo "$json" | jq -r '.author // ""' 2>/dev/null || echo "")"
    duration="$(echo "$json" | jq -r '.duration // ""' 2>/dev/null || echo "")"
    timestamp="$(echo "$json" | jq -r '.timestamp // ""' 2>/dev/null || echo "")"
    
    local modules_html verification_html failure_context_html
    modules_html="$(_notify_render::generate_modules_html "$json")"
    verification_html="$(_notify_render::generate_verification_html "$json")"
    failure_context_html="$(_notify_render::generate_failure_context_html "$json")"
    
    local result="$EMAIL_HTML_TEMPLATE"
    result="${result//\{\{VERSION\}\}/$version}"
    result="${result//\{\{AUTHOR\}\}/$author}"
    result="${result//\{\{DURATION\}\}/$duration}"
    result="${result//\{\{TIMESTAMP\}\}/$timestamp}"
    result="${result//\{\{MODULES_HTML\}\}/$modules_html}"
    result="${result//\{\{VERIFICATION_HTML\}\}/$verification_html}"
    result="${result//\{\{FAILURE_CONTEXT_HTML\}\}/$failure_context_html}"
    
    # Determine status
    local failure_occurred
    failure_occurred="$(echo "$json" | jq -r '.failure.occurred // false' 2>/dev/null || echo "false")"
    local status="Success"
    [[ "$failure_occurred" == "true" ]] && status="Failure"
    result="${result//\{\{STATUS\}\}/$status}"
    
    echo "$result"
}

