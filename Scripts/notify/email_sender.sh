#!/bin/bash
# ============================================================================
# Email Notification Sender (Internal)
# ============================================================================
# Purpose: Internal Email sending via HTTP API
#          DO NOT call directly from orchestrator
#
# Usage:   Source this file and call internal functions
# ============================================================================

set -euo pipefail

# ============================================================================
# Load Email Configuration
# ============================================================================

_notify_email::load_config() {
    # Load email.from from notify_mapping.yaml
    local mapping_file="${ROOT_DIR:-.}/Scripts/config/notify_mapping.yaml"
    
    if [[ -f "$mapping_file" ]] && command -v python3 >/dev/null 2>&1; then
        local yaml_data
        yaml_data="$(python3 <<'PYEOF'
import yaml
import json
import sys

try:
    with open(sys.argv[1], 'r') as f:
        data = yaml.safe_load(f)
    print(json.dumps(data))
except Exception:
    print(json.dumps({}))
PYEOF
"$mapping_file" 2>/dev/null || echo "{}")"
        
        if [[ -n "$yaml_data" ]] && [[ "$yaml_data" != "{}" ]]; then
            EMAIL_FROM="$(echo "$yaml_data" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('email', {}).get('from', 'msp-no-reply@newsbreak.com'))" 2>/dev/null || echo "msp-no-reply@newsbreak.com")"
        fi
    fi
    
    # Load recipient list from email_mapping.yaml
    local email_mapping_file="${ROOT_DIR:-.}/Scripts/config/email_mapping.yaml"
    if [[ -f "$email_mapping_file" ]] && command -v python3 >/dev/null 2>&1; then
        local email_yaml_data
        email_yaml_data="$(python3 <<'PYEOF'
import yaml
import json
import sys

try:
    with open(sys.argv[1], 'r') as f:
        data = yaml.safe_load(f)
    print(json.dumps(data))
except Exception:
    print(json.dumps({}))
PYEOF
"$email_mapping_file" 2>/dev/null || echo "{}")"
            
        if [[ -n "$email_yaml_data" ]] && [[ "$email_yaml_data" != "{}" ]]; then
            # Determine environment (test or prod)
            local env_mode="${MSP_SLACK_ALERT_ENV:-prod}"
            [[ "$env_mode" != "test" ]] && env_mode="prod"
            
            # Get recipient list
            local recipients_json
            recipients_json="$(echo "$email_yaml_data" | python3 -c "import sys, json; data=json.load(sys.stdin); emails=data.get('success_list', {}).get('$env_mode', []); print(json.dumps(emails))" 2>/dev/null || echo "[]")"
            
            # Parse recipients into array
            EMAIL_RECIPIENTS=()
            if [[ -n "$recipients_json" ]] && [[ "$recipients_json" != "[]" ]]; then
                local idx=0
                while IFS= read -r email; do
                    [[ -n "$email" ]] && EMAIL_RECIPIENTS[$idx]="$email"
                    idx=$((idx + 1))
                done < <(echo "$recipients_json" | python3 -c "import sys, json; emails=json.load(sys.stdin); [print(e) for e in emails]" 2>/dev/null)
            fi
        fi
    fi
    
    return 0
}

# ============================================================================
# Internal Email Sender
# ============================================================================

EMAIL_FROM="msp-no-reply@newsbreak.com"
declare -a EMAIL_RECIPIENTS

notify::email::send() {
    local subject="$1"
    local html_body="$2"
    
    # Check if email is disabled (for testing)
    if [[ "${MSP_EMAIL_DISABLED:-0}" == "1" ]]; then
        echo "[notify][email] Email disabled for test mode" >&2
        return 0
    fi
    
    # Load configuration
    _notify_email::load_config 2>/dev/null || true
    
    # Check endpoint
    local endpoint="${MSP_EMAIL_ENDPOINT:-}"
    if [[ -z "$endpoint" ]]; then
        echo "Warning: Email endpoint not set (MSP_EMAIL_ENDPOINT); skipping email." >&2
        return 0
    fi
    
    # Check recipients
    if [[ ${#EMAIL_RECIPIENTS[@]} -eq 0 ]]; then
        echo "Warning: No email recipients configured" >&2
        return 0
    fi
    
    # Build JSON array for recipients
    local emails_json=""
    local first=1
    for email in "${EMAIL_RECIPIENTS[@]}"; do
        if [[ $first -eq 1 ]]; then
            first=0
            emails_json="\"$email\""
        else
            emails_json="$emails_json, \"$email\""
        fi
    done
    
    # Escape JSON special characters in html_body using Python
    local escaped_body
    if command -v python3 >/dev/null 2>&1; then
        escaped_body="$(echo "$html_body" | python3 -c "import sys, json; print(json.dumps(sys.stdin.read()))" 2>/dev/null | sed 's/^"//; s/"$//')"
    else
        # Fallback: basic escaping
        escaped_body="$(printf "%s" "$html_body" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')"
    fi
    
    # Construct JSON payload
    local json_payload
    json_payload=$(cat <<EOF
{
  "to": [$emails_json],
  "from": "${EMAIL_FROM}",
  "html": "$escaped_body",
  "subject": "$subject",
  "emailTopic": "msp-release"
}
EOF
)
    
    # Send HTTP POST request (soft-fail)
    if curl -s -X POST "$endpoint" \
        -H "Content-Type: application/json" \
        -d "$json_payload" >/dev/null 2>&1; then
        echo "Email notification sent successfully to ${#EMAIL_RECIPIENTS[@]} recipient(s)" >&2
        return 0
    else
        echo "Warning: Failed to send email notification (non-blocking)" >&2
        return 0  # Soft-fail
    fi
}

