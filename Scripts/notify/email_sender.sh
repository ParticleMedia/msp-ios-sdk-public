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
    local mapping_file="${ROOT_DIR:-.}/Scripts/config/notify_mapping.yaml"
    
    if [[ ! -f "$mapping_file" ]]; then
        echo "Warning: notify_mapping.yaml not found" >&2
        return 1
    fi
    
    # Parse YAML to get email.from
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
            EMAIL_FROM="$(echo "$yaml_data" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('email', {}).get('from', 'msp-no-reply@newsbreak.com'))" 2>/dev/null || echo "msp-no-reply@newsbreak.com")"
        fi
    fi
    
    # Load recipient list from email_mapping.yaml (for backward compatibility)
    local email_mapping_file="${ROOT_DIR:-.}/Scripts/config/email_mapping.yaml"
    if [[ -f "$email_mapping_file" ]]; then
        if command -v python3 >/dev/null 2>&1; then
            local email_yaml_data
            email_yaml_data="$(python3 <<'PYEOF'
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
"$email_mapping_file" 2>/dev/null || echo "{}")"
            
            if [[ -n "$email_yaml_data" ]] && [[ "$email_yaml_data" != "{}" ]]; then
                # Determine environment
                local env_mode="${MSP_SLACK_ALERT_ENV:-prod}"
                if [[ "$env_mode" != "test" ]]; then
                    env_mode="prod"
                fi
                
                # Get recipient list
                local recipients_json
                recipients_json="$(echo "$email_yaml_data" | python3 -c "import sys, json; data=json.load(sys.stdin); emails=data.get('success_list', {}).get('$env_mode', []); print(json.dumps(emails))" 2>/dev/null || echo "[]")"
                
                # Parse recipients
                if [[ -n "$recipients_json" ]] && [[ "$recipients_json" != "[]" ]]; then
                    EMAIL_RECIPIENTS=()
                    local idx=0
                    echo "$recipients_json" | python3 -c "import sys, json; emails=json.load(sys.stdin); [print(e) for e in emails]" 2>/dev/null | while IFS= read -r email; do
                        EMAIL_RECIPIENTS[$idx]="$email"
                        idx=$((idx + 1))
                    done
                fi
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
    
    # Escape JSON special characters in html_body
    local escaped_body
    escaped_body="$(printf "%s" "$html_body" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')"
    
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

