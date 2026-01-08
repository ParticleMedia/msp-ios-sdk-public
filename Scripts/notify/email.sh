#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Email Notification Module (HTTP API)
# ============================================================================
# Purpose: Send email notifications via internal HTTP API service
#
# Usage:   Source this file and call notify::email::send_success_email
# ============================================================================

# Only set strict mode when running as main script, not when sourced
# This prevents overriding the caller's error handling settings
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
fi

# ============================================================================
# Configuration Variables (loaded from YAML)
# ============================================================================

EMAIL_FROM=""
EMAIL_ENDPOINT_ENV=""
EMAIL_ENDPOINT=""
EMAIL_TEMPLATE_SUBJECT=""
EMAIL_TEMPLATE_SUCCESS=""
# Use regular arrays instead of associative arrays for compatibility
EMAIL_SUCCESS_LIST_TEST=()
EMAIL_SUCCESS_LIST_PROD=()

# ============================================================================
# Load Email Mapping Configuration
# ============================================================================

notify::email::load_mapping() {
    local mapping_file="${ROOT_DIR:-.}/Scripts/config/email_mapping.yaml"
    
    if [[ ! -f "$mapping_file" ]]; then
        echo "Warning: email_mapping.yaml not found" >&2
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
            # Extract api.from
            EMAIL_FROM="$(echo "$yaml_data" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('api', {}).get('from', 'msp-no-reply@newsbreak.com'))" 2>/dev/null || echo "msp-no-reply@newsbreak.com")"
            
            # Extract api.endpoint_env
            EMAIL_ENDPOINT_ENV="$(echo "$yaml_data" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('api', {}).get('endpoint_env', 'MSP_EMAIL_ENDPOINT'))" 2>/dev/null || echo "MSP_EMAIL_ENDPOINT")"
            
            # Extract templates.subject
            EMAIL_TEMPLATE_SUBJECT="$(echo "$yaml_data" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('templates', {}).get('subject', 'MSP Release Success — Version {{VERSION}}'))" 2>/dev/null || echo "MSP Release Success — Version {{VERSION}}")"
            
            # Extract templates.success
            EMAIL_TEMPLATE_SUCCESS="$(echo "$yaml_data" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('templates', {}).get('success', ''))" 2>/dev/null || echo "")"
            
            # Extract success_list.test
            local test_list
            test_list="$(echo "$yaml_data" | python3 -c "import sys, json; data=json.load(sys.stdin); emails=data.get('success_list', {}).get('test', []); print(' '.join(emails))" 2>/dev/null || echo "")"
            if [[ -n "$test_list" ]]; then
                local idx=0
                for email in $test_list; do
                    EMAIL_SUCCESS_LIST_TEST[$idx]="$email"
                    idx=$((idx + 1))
                done
            fi
            
            # Extract success_list.prod
            local prod_list
            prod_list="$(echo "$yaml_data" | python3 -c "import sys, json; data=json.load(sys.stdin); emails=data.get('success_list', {}).get('prod', []); print(' '.join(emails))" 2>/dev/null || echo "")"
            if [[ -n "$prod_list" ]]; then
                local idx=0
                for email in $prod_list; do
                    EMAIL_SUCCESS_LIST_PROD[$idx]="$email"
                    idx=$((idx + 1))
                done
            fi
        fi
    fi
    
    # Get endpoint from environment variable
    if [[ -n "$EMAIL_ENDPOINT_ENV" ]]; then
        EMAIL_ENDPOINT="${!EMAIL_ENDPOINT_ENV:-}"
    fi
    
    return 0
}

# ============================================================================
# Render Subject Template
# ============================================================================

notify::email::render_subject() {
    local version="$1"
    
    # Replace {{VERSION}} placeholder
    local subject="${EMAIL_TEMPLATE_SUBJECT//\{\{VERSION\}\}/$version}"
    
    echo "$subject"
}

# ============================================================================
# Render Success Email Template
# ============================================================================

notify::email::render_success_template() {
    local version="$1"
    local author="$2"
    local module_list="$3"
    local duration="$4"
    local verification_status="${5:-}"
    
    # Use config template if available
    if [[ -n "${EMAIL_TEMPLATE_SUCCESS:-}" ]]; then
        local template="${EMAIL_TEMPLATE_SUCCESS}"
        
        # Replace placeholders
        template="${template//\{\{VERSION\}\}/$version}"
        template="${template//\{\{AUTHOR\}\}/${author:-unknown}}"
        template="${template//\{\{MODULE_LIST\}\}/$module_list}"
        template="${template//\{\{DURATION\}\}/$duration}"
        
        # Replace {{VERIFICATION_STATUS}} if present
        if [[ -n "$verification_status" ]]; then
            template="${template//\{\{VERIFICATION_STATUS\}\}/$verification_status}"
        else
            template="${template//\{\{VERIFICATION_STATUS\}\}/}"
        fi
        
        # Convert newlines to HTML breaks and wrap in HTML
        local html_body
        html_body="<html><body><pre style=\"font-family: -apple-system, monospace; white-space: pre-wrap;\">"
        html_body="$html_body$(printf "%s" "$template" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')"
        html_body="$html_body</pre></body></html>"
        
        echo "$html_body"
        return 0
    fi
    
    # Fallback to hard-coded default template
    local email_body="MSP Release Success 🎉\nVersion: $version\nAuthor: ${author:-unknown}\nModules:\n$module_list\nDuration: $duration"
    if [[ -n "$verification_status" ]]; then
        email_body="$email_body\nVerification:\n$verification_status"
    fi
    
    local html_body
    html_body="<html><body><pre style=\"font-family: -apple-system, monospace; white-space: pre-wrap;\">"
    html_body="$html_body$(printf "%s" "$email_body" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')"
    html_body="$html_body</pre></body></html>"
    
    echo "$html_body"
    return 0
}

# ============================================================================
# Send Success Email via HTTP API
# ============================================================================

# DEPRECATED: Use notify::send_release_summary() instead
# This function is kept for backward compatibility only
notify::email::send_success_email() {
    local version="$1"
    local author="$2"
    local module_list="$3"
    local duration="$4"
    local verification_status="${5:-}"
    
    # Load mapping configuration
    notify::email::load_mapping 2>/dev/null || true
    
    # Check endpoint
    local endpoint_env="${EMAIL_ENDPOINT_ENV:-MSP_EMAIL_ENDPOINT}"
    local endpoint="${!endpoint_env:-}"
    
    if [[ -z "$endpoint" ]]; then
        echo "Warning: Email endpoint not set (${endpoint_env}); skipping email." >&2
        return 0
    fi
    
    # Determine environment (test or prod)
    local env_mode="${MSP_SLACK_ALERT_ENV:-prod}"
    if [[ "$env_mode" != "test" ]]; then
        env_mode="prod"
    fi
    
    # Get recipient list
    local emails=()
    if [[ "$env_mode" == "test" ]]; then
        for email in "${EMAIL_SUCCESS_LIST_TEST[@]}"; do
            [[ -n "$email" ]] && emails+=("$email")
        done
    else
        for email in "${EMAIL_SUCCESS_LIST_PROD[@]}"; do
            [[ -n "$email" ]] && emails+=("$email")
        done
    fi
    
    if [[ ${#emails[@]} -eq 0 ]]; then
        echo "Warning: No email recipients configured for $env_mode mode" >&2
        return 0
    fi
    
    # Render subject and body
    local email_subject
    email_subject="$(notify::email::render_subject "$version")"
    
    local email_body
    email_body="$(notify::email::render_success_template "$version" "$author" "$module_list" "$duration" "$verification_status")"
    
    # Build JSON array for recipients
    local emails_json=""
    local first=1
    for email in "${emails[@]}"; do
        if [[ $first -eq 1 ]]; then
            first=0
            emails_json="\"$email\""
        else
            emails_json="$emails_json, \"$email\""
        fi
    done
    
    # Escape JSON special characters in email_body
    local escaped_body
    escaped_body="$(printf "%s" "$email_body" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')"
    
    # Construct JSON payload
    local json_payload
    json_payload=$(cat <<EOF
{
  "to": [$emails_json],
  "from": "${EMAIL_FROM:-msp-no-reply@newsbreak.com}",
  "html": "$escaped_body",
  "subject": "$email_subject",
  "emailTopic": "msp-release"
}
EOF
)
    
    # Send HTTP POST request (soft-fail)
    if curl -s -X POST "$endpoint" \
        -H "Content-Type: application/json" \
        -d "$json_payload" >/dev/null 2>&1; then
        echo "Email notification sent successfully to ${#emails[@]} recipient(s)" >&2
        return 0
    else
        echo "Warning: Failed to send email notification (non-blocking)" >&2
        return 0  # Soft-fail
    fi
}
