#!/bin/bash

# ============================================================================
# Email Notification Utilities for Release Scripts
# ============================================================================
# Provides email broadcast functionality for global release success
# All functions are soft-fail (return 0, never raise exit code)
# ============================================================================

# Load email mapping from YAML config
# Sets EMAIL_SUCCESS_LIST_TEST, EMAIL_SUCCESS_LIST_PROD, EMAIL_SMTP_* variables
# Returns 0 on success, 1 if file missing or parsing fails (soft-fail)
notify::email::load_mapping() {
    local mapping_file="${ROOT_DIR:-.}/Scripts/config/email_mapping.yaml"
    
    # Soft-fail if file missing
    [[ ! -f "$mapping_file" ]] && return 0
    
    # Parse YAML using python3 (soft-fail on error)
    eval "$(python3 - <<EOF
import yaml, json, sys, os
try:
    with open("$mapping_file", 'r') as f:
        d = yaml.safe_load(f)
    
    # Extract success_list
    success_list = d.get("success_list", {})
    test_list = success_list.get("test", [])
    prod_list = success_list.get("prod", [])
    
    # Escape for shell
    test_json = json.dumps(test_list).replace("'", "'\"'\"'")
    prod_json = json.dumps(prod_list).replace("'", "'\"'\"'")
    
    print("EMAIL_SUCCESS_LIST_TEST='"+test_json+"'")
    print("EMAIL_SUCCESS_LIST_PROD='"+prod_json+"'")
    
    # Extract SMTP config
    smtp = d.get("smtp", {})
    print("EMAIL_SMTP_HOST='"+str(smtp.get("host", "")).replace("'", "'\"'\"'")+"'")
    print("EMAIL_SMTP_PORT='"+str(smtp.get("port", "")).replace("'", "'\"'\"'")+"'")
    print("EMAIL_SMTP_USERNAME='"+str(smtp.get("username", "")).replace("'", "'\"'\"'")+"'")
    print("EMAIL_SMTP_PASSWORD_ENV='"+str(smtp.get("password_env", "")).replace("'", "'\"'\"'")+"'")
    
    # Extract templates
    templates = d.get("templates", {})
    success_template = templates.get("success", "").replace("'", "'\"'\"'").replace("\n", "\\n")
    print("EMAIL_TEMPLATE_SUCCESS='"+success_template+"'")
except Exception as e:
    # Silent failure - return empty variables
    pass
EOF
    )" 2>/dev/null || return 0
    
    return 0
}

# Render success email template
# Replaces placeholders: {{VERSION}}, {{AUTHOR}}, {{MODULE_LIST}}, {{DURATION}}, {{REMOTE_STATUS}}
# Returns rendered template on stdout
notify::email::render_success_template() {
    local version="$1"
    local author="$2"
    local module_list="$3"
    local duration="$4"
    local remote_status="${5:-}"
    
    # Load mapping to get template
    notify::email::load_mapping 2>/dev/null || true
    
    # Use config template if available
    if [[ -n "${EMAIL_TEMPLATE_SUCCESS:-}" ]]; then
        local template="${EMAIL_TEMPLATE_SUCCESS}"
        # Replace placeholders using parameter expansion
        template="${template//\{\{VERSION\}\}/$version}"
        template="${template//\{\{AUTHOR\}\}/${author:-unknown}}"
        template="${template//\{\{MODULE_LIST\}\}/$module_list}"
        template="${template//\{\{DURATION\}\}/$duration}"
        # Replace {{REMOTE_STATUS}} if present
        if [[ -n "$remote_status" ]]; then
            template="${template//\{\{REMOTE_STATUS\}\}/$remote_status}"
        else
            template="${template//\{\{REMOTE_STATUS\}\}/}"
        fi
        # Convert \n to actual newlines
        echo -e "$template"
        return 0
    fi
    
    # Fallback to hard-coded default template
    local email_body="MSP Release Success 🎉\nVersion: $version\nAuthor: ${author:-unknown}\nModules:\n$module_list\nDuration: $duration"
    if [[ -n "$remote_status" ]]; then
        email_body="$email_body\n\nRemote Verification:\n$remote_status"
    fi
    printf "$email_body\n"
}

# Send success email broadcast
# Parameters: version, author_email, module_list (newline-separated), duration
# Soft-fail always (returns 0)
notify::email::send_success_email() {
    local version="$1"
    local author_email="$2"
    local module_list="$3"
    local duration="$4"
    
    # Load mapping (soft-fail if missing)
    notify::email::load_mapping 2>/dev/null || return 0
    
    # Determine TEST/PROD mode
    local is_test=false
    if [[ "${MSP_SLACK_ALERT_ENV:-}" == "test" ]]; then
        is_test=true
    fi
    
    # Get recipient list based on mode
    local recipients_json=""
    if [[ "$is_test" == "true" ]]; then
        recipients_json="${EMAIL_SUCCESS_LIST_TEST:-[]}"
    else
        recipients_json="${EMAIL_SUCCESS_LIST_PROD:-[]}"
    fi
    
    # Parse recipients from JSON array
    local recipients
    recipients=$(python3 - <<EOF
import json
try:
    recipients = json.loads('$recipients_json')
    for r in recipients:
        print(r)
except:
    pass
EOF
    ) 2>/dev/null || return 0
    
    # Skip if no recipients
    if [[ -z "$recipients" ]]; then
        return 0
    fi
    
    # Get SMTP config
    local smtp_host="${EMAIL_SMTP_HOST:-}"
    local smtp_port="${EMAIL_SMTP_PORT:-}"
    local smtp_username="${EMAIL_SMTP_USERNAME:-}"
    local password_env="${EMAIL_SMTP_PASSWORD_ENV:-}"
    
    # Skip if SMTP config missing
    if [[ -z "$smtp_host" ]] || [[ -z "$smtp_port" ]] || [[ -z "$smtp_username" ]] || [[ -z "$password_env" ]]; then
        return 0
    fi
    
    # Get password from environment variable
    local smtp_password="${!password_env:-}"
    if [[ -z "$smtp_password" ]]; then
        return 0
    fi
    
    # Get verification status from environment (includes remote, local, and device)
    local verify_status="${REMOTE_VERIFY_STATUS:-}"
    
    # Render email body (module_list is already formatted with dashes from orchestrator)
    local email_body
    email_body="$(notify::email::render_success_template "$version" "$author_email" "$module_list" "$duration" "$verify_status")" || return 0
    
    # Create temporary file for email content
    local tmp_file
    tmp_file=$(mktemp) || return 0
    
    # Write email headers and body
    {
        echo "From: $smtp_username"
        echo "To: $(echo "$recipients" | head -1)"
        echo "Subject: MSP Release Success - Version $version"
        echo "Content-Type: text/plain; charset=utf-8"
        echo ""
        echo "$email_body"
    } > "$tmp_file" || {
        rm -f "$tmp_file"
        return 0
    }
    
    # Send email to each recipient (soft-fail on any error)
    echo "$recipients" | while IFS= read -r recipient; do
        [[ -z "$recipient" ]] && continue
        
        # Use curl's SMTP support
        curl -s --url "smtp://$smtp_host:$smtp_port" \
            --ssl \
            --mail-from "$smtp_username" \
            --mail-rcpt "$recipient" \
            --upload-file "$tmp_file" \
            --user "$smtp_username:$smtp_password" \
            >/dev/null 2>&1 || true
    done
    
    # Clean up
    rm -f "$tmp_file" 2>/dev/null || true
    
    return 0
}

# Export all functions
export -f notify::email::load_mapping notify::email::render_success_template notify::email::send_success_email 2>/dev/null || true

