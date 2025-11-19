#!/bin/bash

# Release Common Library
# Shared functions and configurations for all release scripts

# Try to source UI system (if available)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source colors and UI system if available
if [[ -f "$ROOT_DIR/Scripts/lib/colors.sh" ]]; then
    # shellcheck source=Scripts/lib/colors.sh
    source "$ROOT_DIR/Scripts/lib/colors.sh" 2>/dev/null || true
fi

if [[ -f "$ROOT_DIR/Scripts/lib/ui.sh" ]]; then
    # shellcheck source=Scripts/lib/ui.sh
    source "$ROOT_DIR/Scripts/lib/ui.sh" 2>/dev/null || true
fi

# Fallback color definitions (if colors.sh not available)
: "${RED:=\033[0;31m}"
: "${GREEN:=\033[0;32m}"
: "${YELLOW:=\033[1;33m}"
: "${BLUE:=\033[0;34m}"
: "${PURPLE:=\033[0;35m}"
: "${NC:=\033[0m}"

# Logging functions (use UI system if available, fallback to simple functions)
if command -v log_info &>/dev/null && command -v log_success &>/dev/null; then
    # UI system available - use it but keep function names for compatibility
    log_warning() {
        log_warn "$1"
    }
    
    log_release() {
        if should_use_colors; then
            printf "${PURPLE}🚀${NC} %s\n" "$1"
        else
            printf "🚀 %s\n" "$1"
        fi
    }
    
    log_debug() {
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "🔍 $1"
        fi
    }
    
    print_section() {
        log_section "$1"
    }
else
    # Fallback logging functions
    log_info() {
        echo -e "${BLUE}ℹ️  $1${NC}"
    }

    log_success() {
        echo -e "${GREEN}✅ $1${NC}"
    }

    log_warning() {
        echo -e "${YELLOW}⚠️  $1${NC}"
    }

    log_error() {
        echo -e "${RED}❌ $1${NC}"
    }

    log_step() {
        echo -e "${BLUE}🔧 $1${NC}"
    }

    log_release() {
        echo -e "${PURPLE}🚀 $1${NC}"
    }

    log_debug() {
        if [[ "$VERBOSE" == "true" ]]; then
            echo -e "${BLUE}🔍 $1${NC}"
        fi
    }

    print_section() {
        echo ""
        echo "═══════════════════════════════════════════════════════════════════"
        echo "$1"
        echo "═══════════════════════════════════════════════════════════════════"
        echo ""
    }
fi

print_subsection() {
    echo -e "${BLUE}--- $1 ---${NC}"
}

# Pod configurations - Single source of truth
# Order matters: dependencies must be released before dependents
POD_RELEASE_ORDER=(
    "MSPSharedLibraries"    # No dependencies
    "MSPOMSDK"              # Depends on MSPSharedLibraries
    "MSPFacebookAdapter"    # Depends on MSPSharedLibraries
    "MSPGoogleAdapter"      # Depends on MSPSharedLibraries
    "NovaAdapter"           # Depends on MSPSharedLibraries, MSPOMSDK
    "AmazonAdapter"         # Depends on MSPSharedLibraries
    "PrebidAdapter"         # Depends on MSPSharedLibraries
    "MSPCore"               # Depends on MSPSharedLibraries, PrebidAdapter
)

# All pods to be released
ALL_PODS=("MSPSharedLibraries" "PrebidAdapter" "NovaAdapter" "MSPFacebookAdapter" "MSPGoogleAdapter" "AmazonAdapter" "MSPCore")

# Dependency mapping (using functions instead of associative arrays for bash 3.x compatibility)
get_pod_dependencies_internal() {
    case "$1" in
        "MSPSharedLibraries") echo "" ;;
        "MSPOMSDK") echo "MSPSharedLibraries" ;;
        "MSPFacebookAdapter") echo "MSPSharedLibraries" ;;
        "MSPGoogleAdapter") echo "MSPSharedLibraries" ;;
        "NovaAdapter") echo "MSPSharedLibraries MSPOMSDK" ;;
        "AmazonAdapter") echo "MSPSharedLibraries" ;;
        "PrebidAdapter") echo "MSPSharedLibraries" ;;
        "MSPCore") echo "MSPSharedLibraries PrebidAdapter" ;;
        *) echo "" ;;
    esac
}

# Function to get pod dependencies
get_pod_dependencies() {
    local pod="$1"
    get_pod_dependencies_internal "$pod"
}

# Function to check if pod is valid
is_valid_pod() {
    local pod="$1"
    for allowed_pod in "${ALLOWED_PODS[@]}"; do
        if [[ "$pod" == "$allowed_pod" ]]; then
            return 0
        fi
    done
    return 1
}

# Function to get release order for a specific pod
get_release_order_for_pod() {
    local target_pod="$1"
    local order=()
    
    # Add dependencies first
    local deps=$(get_pod_dependencies "$target_pod")
    if [[ -n "$deps" ]]; then
        for dep in $deps; do
            if [[ " ${POD_RELEASE_ORDER[@]} " =~ " $dep " ]]; then
                order+=("$dep")
            fi
        done
    fi
    
    # Add the target pod
    order+=("$target_pod")
    
    echo "${order[@]}"
}

# Function to validate release order
validate_release_order() {
    local pods=("$@")
    local errors=()
    
    for pod in "${pods[@]}"; do
        local deps=$(get_pod_dependencies "$pod")
        if [[ -n "$deps" ]]; then
            for dep in $deps; do
                # Check if dependency comes before the pod in the release order
                local pod_index=-1
                local dep_index=-1
                
                for i in "${!POD_RELEASE_ORDER[@]}"; do
                    if [[ "${POD_RELEASE_ORDER[$i]}" == "$pod" ]]; then
                        pod_index=$i
                    fi
                    if [[ "${POD_RELEASE_ORDER[$i]}" == "$dep" ]]; then
                        dep_index=$i
                    fi
                done
                
                if [[ $dep_index -gt $pod_index ]]; then
                    errors+=("$pod depends on $dep, but $dep comes after $pod in release order")
                fi
            done
        fi
    done
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        log_error "Release order validation failed:"
        for error in "${errors[@]}"; do
            log_error "  - $error"
        done
        return 1
    fi
    
    return 0
}

# Function to update podspec dependency version
update_podspec_dependency_version() {
    local podspec_file="$1"
    local dependency_name="$2"
    local version="$3"
    
    if [[ ! -f "$podspec_file" ]]; then
        log_error "Podspec file not found: $podspec_file"
        return 1
    fi
    
    # Update dependency version
    sed -i '' "s|spec\.dependency '$dependency_name'[^,]*|spec.dependency '$dependency_name', '$version'|g" "$podspec_file"
    
    log_success "Updated $dependency_name dependency to version $version in $podspec_file"
}

# Function to update podspec to HTTP zip format
update_podspec_to_zip_format() {
    local podspec_file="$1"
    local version="$2"
    
    if [[ ! -f "$podspec_file" ]]; then
        log_error "Podspec file not found: $podspec_file"
        return 1
    fi
    
    # Create backup
    cp "$podspec_file" "${podspec_file}.backup"
    
    # Update version
    sed -i '' "s|spec\.version.*=.*\".*\"|spec.version = \"${version}\"|g" "$podspec_file"
    
    # Update source to use HTTP zip format
    sed -i '' "s|spec\.source.*=.*{.*:git.*=>.*\"https://github\.com/.*\.git\".*:tag.*=>.*\"#{spec\.version}\".*}|spec.source = {\n    http: \"https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/$(basename "$podspec_file" .podspec)-${version}.zip\",\n    type: \"zip\"\n  }|g" "$podspec_file"
    
    
    log_success "Updated $podspec_file to use HTTP zip source format"
}

# Function to get project root
get_project_root() {
    cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

# Function to ensure project root
ensure_project_root() {
    local project_root=$(get_project_root)
    if [[ "$(pwd)" != "$project_root" ]]; then
        cd "$project_root"
    fi
}

# Retry logic with exponential backoff
retry_with_backoff() {
    local max_attempts="$1"
    local base_delay="$2"
    local command_name="$3"
    shift 3
    local command=("$@")
    
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log_debug "Attempt $attempt/$max_attempts: $command_name"
        
        if "${command[@]}"; then
            log_success "$command_name succeeded on attempt $attempt"
            return 0
        else
            log_warning "$command_name failed (attempt $attempt/$max_attempts)"
            
            if [[ $attempt -lt $max_attempts ]]; then
                # Exponential backoff: base_delay * 2^(attempt-1)
                local delay=$((base_delay * (1 << (attempt - 1))))
                log_info "Retrying $command_name in ${delay} seconds..."
                sleep $delay
            fi
        fi
        
        ((attempt++))
    done
    
    log_error "$command_name failed after $max_attempts attempts"
    return 1
}

# Validate podspec with retry logic
validate_podspec_with_retry() {
    local podspec="$1"
    local max_attempts=3
    local base_delay=5
    
    log_step "Validating podspec with retry: $(basename "$podspec")"
    
    retry_with_backoff $max_attempts $base_delay "podspec validation" \
        validate_podspec "$podspec"
}

# Publish podspec with retry logic
publish_podspec_with_retry() {
    local podspec="$1"
    local max_attempts=3
    local base_delay=10
    
    log_step "Publishing podspec with retry: $(basename "$podspec")"
    
    # First update the specs repo with retry
    if ! retry_with_backoff 3 5 "specs repo update" update_specs_repo; then
        log_warning "Failed to update specs repo, continuing anyway..."
    fi
    
    # Then publish with retry
    retry_with_backoff $max_attempts $base_delay "podspec publishing" \
        publish_podspec "$podspec"
}

# GitHub release with retry logic
create_github_release_with_retry() {
    local pod="$1"
    local version="$2"
    local max_attempts=3
    local base_delay=5
    
    log_step "Creating GitHub release with retry for $pod"
    
    retry_with_backoff $max_attempts $base_delay "GitHub release creation" \
        create_github_release_internal "$pod" "$version"
}

# Internal GitHub release function (to be called by retry logic)
create_github_release_internal() {
    local pod="$1"
    local version="$2"
    
    # Create zip file
    local zip_name="${pod}-${version}.zip"
    if [[ -d "$pod" ]]; then
        zip -r "$zip_name" "$pod" >/dev/null 2>&1
    else
        log_warning "Pod directory $pod not found, skipping zip creation"
        return 0
    fi
    
    # Create or update GitHub release
    if gh release view "$version" --repo "ParticleMedia/msp-ios-sdk-public" &>/dev/null; then
        log_info "Release $version already exists, uploading assets"
        gh release upload "$version" "$zip_name" --repo "ParticleMedia/msp-ios-sdk-public" --clobber
    else
        log_info "Creating new release $version"
        gh release create "$version" "$zip_name" --repo "ParticleMedia/msp-ios-sdk-public"
    fi
    
    # Clean up zip file
    rm -f "$zip_name"
    
    return 0
}

# Slack Notification Functions
# =============================

# Load Slack configuration from config file if it exists
# Falls back to environment variables if config file is not found
# Environment variables take precedence over config file values
load_slack_config() {
    # Get the directory where this script is located
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # Resolve the config file path relative to the script directory
    # Script is in Scripts/lib/, config is in Scripts/config/
    local config_dir="$(cd "$script_dir/../config" 2>/dev/null && pwd)"
    if [[ -z "$config_dir" ]]; then
        # Fallback: try to find config directory from project root
        local project_root="$(cd "$script_dir/../.." 2>/dev/null && pwd)"
        if [[ -n "$project_root" ]]; then
            config_dir="$project_root/Scripts/config"
        fi
    fi
    local config_file="${config_dir}/slack.conf"
    
    if [[ -f "$config_file" ]]; then
        log_debug "Loading Slack configuration from: $config_file"
        
        # Read the config file line by line
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip comments and empty lines
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${line// }" ]] && continue
            
            # Parse key=value pairs
            if [[ "$line" =~ ^[[:space:]]*([^=]+)=(.*)$ ]]; then
                local key="${BASH_REMATCH[1]}"
                local value="${BASH_REMATCH[2]}"
                
                # Remove leading/trailing whitespace from key
                key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                
                # Remove leading/trailing whitespace and quotes from value
                value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
                
                # Only set if not already set in environment (environment takes precedence)
                if [[ -n "$key" ]] && [[ -n "$value" ]]; then
                    case "$key" in
                        SLACK_WEBHOOK_URL)
                            [[ -z "${SLACK_WEBHOOK_URL:-}" ]] && export SLACK_WEBHOOK_URL="$value"
                            ;;
                        SLACK_CHANNEL)
                            [[ -z "${SLACK_CHANNEL:-}" ]] && export SLACK_CHANNEL="$value"
                            ;;
                        SLACK_USERNAME)
                            [[ -z "${SLACK_USERNAME:-}" ]] && export SLACK_USERNAME="$value"
                            ;;
                        SLACK_ICON_EMOJI)
                            [[ -z "${SLACK_ICON_EMOJI:-}" ]] && export SLACK_ICON_EMOJI="$value"
                            ;;
                    esac
                fi
            fi
        done < "$config_file"
    else
        log_debug "Slack config file not found: $config_file (using environment variables or defaults)"
    fi
}

# Load Slack configuration (environment variables take precedence)
load_slack_config

# Slack configuration with defaults
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
SLACK_CHANNEL="${SLACK_CHANNEL:-#releases}"
SLACK_USERNAME="${SLACK_USERNAME:-MSP iOS SDK Bot}"
SLACK_ICON_EMOJI="${SLACK_ICON_EMOJI:-:rocket:}"

# Environment detection
get_environment() {
    if [[ -n "$JENKINS_URL" ]]; then
        echo "jenkins"
    elif [[ -n "$GITHUB_ACTIONS" ]]; then
        echo "github-actions"
    elif [[ -n "$CI" ]]; then
        echo "ci"
    else
        echo "local"
    fi
}

# Convert markdown to Slack formatting
format_release_notes_for_slack() {
    local release_notes="$1"
    
    if [[ -z "$release_notes" ]]; then
        echo ""
        return
    fi
    
    # Convert markdown headers to Slack bold
    local formatted_notes=$(echo "$release_notes" | sed 's/^## \(.*\)$/*\1*/g')
    formatted_notes=$(echo "$formatted_notes" | sed 's/^### \(.*\)$/*\1*/g')
    
    # Convert markdown lists to Slack formatting
    formatted_notes=$(echo "$formatted_notes" | sed 's/^- /• /g')
    
    # Clean up extra whitespace but preserve line breaks
    formatted_notes=$(echo "$formatted_notes" | sed 's/^[[:space:]]*//g' | sed 's/[[:space:]]*$//g')
    
    # Replace multiple newlines with single newline
    formatted_notes=$(echo "$formatted_notes" | tr -s '\n')
    
    # Truncate if too long for Slack (count characters including newlines)
    local char_count=$(echo "$formatted_notes" | wc -c)
    if [[ $char_count -gt 200 ]]; then
        # Truncate to 197 characters and add ellipsis
        formatted_notes=$(echo "$formatted_notes" | head -c 197)
        formatted_notes="${formatted_notes}..."
    fi
    
    echo "$formatted_notes"
}

# Get environment-specific information
get_environment_info() {
    local env=$(get_environment)
    case "$env" in
        "jenkins")
            echo "Jenkins Build #${BUILD_NUMBER:-unknown}"
            ;;
        "github-actions")
            echo "GitHub Actions - ${GITHUB_WORKFLOW:-unknown workflow}"
            ;;
        "ci")
            echo "CI Environment"
            ;;
        "local")
            # Handle hostnames with spaces properly
            local hostname=$(hostname)
            echo "Local Development - $(whoami)@${hostname}"
            ;;
        *)
            echo "Unknown Environment"
            ;;
    esac
}

# Send Slack notification
send_slack_notification() {
    local message="$1"
    local color="${2:-good}"
    local title="${3:-}"
    local fields="${4:-}"
    
    if [[ -z "$SLACK_WEBHOOK_URL" ]]; then
        log_warning "SLACK_WEBHOOK_URL not set, skipping Slack notification"
        return 0
    fi
    
    # Escape special characters for JSON
    local escaped_message=$(echo "$message" | sed 's/"/\\"/g' | sed 's/\\/\\\\/g')
    local escaped_title=$(echo "$title" | sed 's/"/\\"/g' | sed 's/\\/\\\\/g')
    local escaped_footer=$(get_environment_info | sed 's/"/\\"/g' | sed 's/\\/\\\\/g')
    
    # Build the JSON payload
    local json_payload=$(cat <<EOF
{
    "channel": "$SLACK_CHANNEL",
    "username": "$SLACK_USERNAME",
    "icon_emoji": "$SLACK_ICON_EMOJI",
    "text": "$escaped_message",
    "attachments": [
        {
            "color": "$color",
            "title": "$escaped_title",
            "fields": [$fields],
            "footer": "$escaped_footer",
            "ts": $(date +%s)
        }
    ]
}
EOF
)
    
    # Send the notification
    local response=$(curl -s -X POST -H 'Content-type: application/json' \
        --data "$json_payload" \
        "$SLACK_WEBHOOK_URL" 2>/dev/null)
    
    if [[ "$response" == "ok" ]]; then
        log_success "Slack notification sent successfully"
    else
        log_warning "Failed to send Slack notification: $response"
    fi
}

# Send release success notification
notify_release_success() {
    local release_type="$1"
    local version="$2"
    local pods="$3"
    local duration="${4:-unknown}"
    local release_notes="${5:-}"
    
    local message="🚀 *${release_type} Release Successful!*"
    local title="Release Details"
    local fields=""
    
    # Add version field
    fields+="{\"title\": \"Version\", \"value\": \"$version\", \"short\": true},"
    
    # Add pods field
    if [[ -n "$pods" ]]; then
        fields+="{\"title\": \"Released Pods\", \"value\": \"$pods\", \"short\": true},"
    fi
    
    # Add duration field
    fields+="{\"title\": \"Duration\", \"value\": \"$duration\", \"short\": true},"
    
    # Add environment field
    fields+="{\"title\": \"Environment\", \"value\": \"$(get_environment_info)\", \"short\": true}"
    
    # Add release notes if provided
    if [[ -n "$release_notes" ]]; then
        local formatted_notes=$(format_release_notes_for_slack "$release_notes")
        fields+=",{\"title\": \"Release Notes\", \"value\": \"$formatted_notes\", \"short\": false}"
    fi
    
    send_slack_notification "$message" "good" "$title" "$fields"
}

# Send release failure notification
notify_release_failure() {
    local release_type="$1"
    local version="$2"
    local error_message="$3"
    local failed_step="${4:-unknown}"
    
    local message="❌ *${release_type} Release Failed!*"
    local title="Release Error Details"
    local fields=""
    
    # Add version field
    fields+="{\"title\": \"Version\", \"value\": \"$version\", \"short\": true},"
    
    # Add failed step field
    fields+="{\"title\": \"Failed Step\", \"value\": \"$failed_step\", \"short\": true},"
    
    # Add error message field
    fields+="{\"title\": \"Error Message\", \"value\": \"$error_message\", \"short\": false},"
    
    # Add environment field
    fields+="{\"title\": \"Environment\", \"value\": \"$(get_environment_info)\", \"short\": true}"
    
    send_slack_notification "$message" "danger" "$title" "$fields"
}

# Send release warning notification
notify_release_warning() {
    local release_type="$1"
    local version="$2"
    local warning_message="$3"
    local warning_step="${4:-unknown}"
    
    local message="⚠️ *${release_type} Release Completed with Warnings*"
    local title="Release Warning Details"
    local fields=""
    
    # Add version field
    fields+="{\"title\": \"Version\", \"value\": \"$version\", \"short\": true},"
    
    # Add warning step field
    fields+="{\"title\": \"Warning Step\", \"value\": \"$warning_step\", \"short\": true},"
    
    # Add warning message field
    fields+="{\"title\": \"Warning Message\", \"value\": \"$warning_message\", \"short\": false},"
    
    # Add environment field
    fields+="{\"title\": \"Environment\", \"value\": \"$(get_environment_info)\", \"short\": true}"
    
    send_slack_notification "$message" "warning" "$title" "$fields"
}

# Send release start notification
notify_release_start() {
    local release_type="$1"
    local version="$2"
    local pods="$3"
    local release_notes="${4:-}"
    
    local message="🔄 *${release_type} Release Started*"
    local title="Release Information"
    local fields=""
    
    # Add version field
    fields+="{\"title\": \"Version\", \"value\": \"$version\", \"short\": true},"
    
    # Add pods field
    if [[ -n "$pods" ]]; then
        fields+="{\"title\": \"Pods to Release\", \"value\": \"$pods\", \"short\": true},"
    fi
    
    # Add environment field
    fields+="{\"title\": \"Environment\", \"value\": \"$(get_environment_info)\", \"short\": true}"
    
    # Add release notes if provided
    if [[ -n "$release_notes" ]]; then
        local formatted_notes=$(format_release_notes_for_slack "$release_notes")
        fields+=",{\"title\": \"Release Notes\", \"value\": \"$formatted_notes\", \"short\": false}"
    fi
    
    send_slack_notification "$message" "#36a64f" "$title" "$fields"
}

# Send individual pod release notification
notify_pod_release() {
    local pod="$1"
    local version="$2"
    local pod_status="$3"  # success, failure, warning
    local message="$4"
    
    local emoji=""
    local color=""
    
    case "$pod_status" in
        "success")
            emoji="✅"
            color="good"
            ;;
        "failure")
            emoji="❌"
            color="danger"
            ;;
        "warning")
            emoji="⚠️"
            color="warning"
            ;;
        *)
            emoji="ℹ️"
            color="#36a64f"
            ;;
    esac
    
    local slack_message="${emoji} *${pod}* v${version}"
    if [[ -n "$message" ]]; then
        slack_message+="
$message"
    fi
    
    local fields="{\"title\": \"Pod\", \"value\": \"$pod\", \"short\": true},"
    fields+="{\"title\": \"Version\", \"value\": \"$version\", \"short\": true},"
    fields+="{\"title\": \"Status\", \"value\": \"$pod_status\", \"short\": true}"
    
    send_slack_notification "$slack_message" "$color" "Pod Release Update" "$fields"
}

# Send release summary notification
notify_release_summary() {
    local release_type="$1"
    local version="$2"
    local total_pods="$3"
    local successful_pods="$4"
    local failed_pods="$5"
    local duration="$6"
    
    local message="📊 *${release_type} Release Summary*"
    local title="Release Statistics"
    local fields=""
    
    # Add version field
    fields+="{\"title\": \"Version\", \"value\": \"$version\", \"short\": true},"
    
    # Add total pods field
    fields+="{\"title\": \"Total Pods\", \"value\": \"$total_pods\", \"short\": true},"
    
    # Add successful pods field
    fields+="{\"title\": \"Successful\", \"value\": \"$successful_pods\", \"short\": true},"
    
    # Add failed pods field
    fields+="{\"title\": \"Failed\", \"value\": \"$failed_pods\", \"short\": true},"
    
    # Add duration field
    fields+="{\"title\": \"Duration\", \"value\": \"$duration\", \"short\": true},"
    
    # Add environment field
    fields+="{\"title\": \"Environment\", \"value\": \"$(get_environment_info)\", \"short\": true}"
    
    local color="good"
    if [[ "$failed_pods" -gt 0 ]]; then
        color="danger"
    elif [[ "$successful_pods" -lt "$total_pods" ]]; then
        color="warning"
    fi
    
    send_slack_notification "$message" "$color" "$title" "$fields"
}

# Send combined release success notification with summary
notify_release_success_with_summary() {
    local release_type="$1"
    local version="$2"
    local pods="$3"
    local duration="${4:-unknown}"
    local release_notes="${5:-}"
    local total_pods="$6"
    local successful_pods="$7"
    local failed_pods="$8"
    local release_branch="${9:-}"
    
    local message="🚀 *${release_type} Release Successful!*"
    local title="Release Details & Summary"
    local fields=""
    
    # Add version field
    fields+="{\"title\": \"Version\", \"value\": \"$version\", \"short\": true}"
    
    # Add release branch field if provided
    if [[ -n "$release_branch" ]]; then
        fields+=",{\"title\": \"Release Branch\", \"value\": \"$release_branch\", \"short\": true}"
    fi
    
    # Add duration field
    fields+=",{\"title\": \"Duration\", \"value\": \"$duration\", \"short\": true}"
    
    # Add released pods field
    if [[ -n "$pods" ]]; then
        fields+=",{\"title\": \"Released Pods\", \"value\": \"$pods\", \"short\": true}"
    fi
    
    # Add environment field
    fields+=",{\"title\": \"Environment\", \"value\": \"$(get_environment_info)\", \"short\": true}"
    
    # Add release notes if provided
    if [[ -n "$release_notes" ]]; then
        local formatted_notes=$(format_release_notes_for_slack "$release_notes")
        fields+=",{\"title\": \"Release Notes\", \"value\": \"$formatted_notes\", \"short\": false}"
    fi
    
    # Add summary statistics
    fields+=",{\"title\": \"Total Pods\", \"value\": \"$total_pods\", \"short\": true}"
    fields+=",{\"title\": \"Successful\", \"value\": \"$successful_pods\", \"short\": true}"
    fields+=",{\"title\": \"Failed\", \"value\": \"$failed_pods\", \"short\": true}"
    
    local color="good"
    if [[ "$failed_pods" -gt 0 ]]; then
        color="danger"
    elif [[ "$successful_pods" -lt "$total_pods" ]]; then
        color="warning"
    fi
    
    send_slack_notification "$message" "$color" "$title" "$fields"
}

# Test Slack notification
test_slack_notification() {
    log_step "Testing Slack notification..."
    
    if [[ -z "$SLACK_WEBHOOK_URL" ]]; then
        log_error "SLACK_WEBHOOK_URL not set. Please set it to test notifications."
        return 1
    fi
    
    local message="🧪 *Test Notification*"
    local title="Slack Integration Test"
    local fields="{\"title\": \"Test\", \"value\": \"This is a test notification from MSP iOS SDK Release Bot\", \"short\": false},"
    fields+="{\"title\": \"Environment\", \"value\": \"$(get_environment_info)\", \"short\": true},"
    fields+="{\"title\": \"Timestamp\", \"value\": \"$(date)\", \"short\": true}"
    
    send_slack_notification "$message" "good" "$title" "$fields"
}

# Release Notes Generation Functions
# ==================================

# Generate release notes from git commits
generate_release_notes_from_git() {
    local version="$1"
    local previous_version="${2:-}"
    local release_type="${3:-Release}"
    
    log_step "Generating release notes from git commits"
    
    # Get the previous tag if not provided
    if [[ -z "$previous_version" ]]; then
        previous_version=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    fi
    
    # Generate release notes
    local release_notes=""
    
    if [[ -n "$previous_version" ]]; then
        release_notes="## ${release_type} ${version}\n\n"
        release_notes+="### Changes since ${previous_version}:\n\n"
        
        # Get commits since previous version
        local commits=$(git log --oneline --pretty=format:"- %s (%h)" "${previous_version}..HEAD" 2>/dev/null)
        
        if [[ -n "$commits" ]]; then
            release_notes+="$commits"
        else
            release_notes+="- No changes detected"
        fi
    else
        release_notes="## ${release_type} ${version}\n\n"
        release_notes+="### Initial release\n\n"
        release_notes+="- First release of ${release_type}"
    fi
    
    echo "$release_notes"
}

# Generate release notes from template
generate_release_notes_from_template() {
    local version="$1"
    local release_type="${2:-Release}"
    local template_file="${3:-}"
    
    log_step "Generating release notes from template"
    
    if [[ -n "$template_file" && -f "$template_file" ]]; then
        # Use custom template
        local release_notes=$(cat "$template_file")
        # Replace placeholders
        release_notes=$(echo "$release_notes" | sed "s/{{VERSION}}/$version/g")
        release_notes=$(echo "$release_notes" | sed "s/{{RELEASE_TYPE}}/$release_type/g")
        release_notes=$(echo "$release_notes" | sed "s/{{DATE}}/$(date '+%Y-%m-%d')/g")
        echo "$release_notes"
    else
        # Use default template
        local release_notes="## ${release_type} ${version}\n\n"
        release_notes+="### What's New\n"
        release_notes+="- Bug fixes and improvements\n"
        release_notes+="- Performance optimizations\n"
        release_notes+="- Enhanced stability\n\n"
        release_notes+="### Technical Details\n"
        release_notes+="- Version: ${version}\n"
        release_notes+="- Release Date: $(date '+%Y-%m-%d')\n"
        release_notes+="- Environment: $(get_environment_info)"
        echo "$release_notes"
    fi
}

# Generate simple release notes from bullet points
generate_simple_release_notes() {
    local version="$1"
    local release_type="${2:-Release}"
    local bullet_points="$3"
    
    log_step "Generating simple release notes"
    
    local release_notes="## Release ${version}\n\n"
    release_notes+="### What's New\n"
    
    # Process bullet points - each line becomes a bullet point
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Remove leading dashes or bullets if present
            line=$(echo "$line" | sed 's/^[-•]\s*//')
            release_notes+="- ${line}\n"
        fi
    done <<< "$bullet_points"
    
    release_notes+="\n### Technical Details\n"
    release_notes+="- Version: ${version}\n"
    release_notes+="- Release Date: $(date '+%Y-%m-%d')\n"
    release_notes+="- Environment: $(get_environment_info)"
    
    echo "$release_notes"
}

# Prompt user for release notes
prompt_for_release_notes() {
    local version="$1"
    local release_type="${2:-Release}"
    
    log_step "Prompting for release notes"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "📝 Release Notes for ${release_type} ${version}"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "Please enter release notes (press Enter twice when done):"
    echo ""
    
    local release_notes=""
    local line
    local empty_lines=0
    
    while IFS= read -r line; do
        if [[ -z "$line" ]]; then
            ((empty_lines++))
            if [[ $empty_lines -ge 2 ]]; then
                break
            fi
        else
            empty_lines=0
        fi
        
        if [[ -n "$release_notes" ]]; then
            release_notes+="\n$line"
        else
            release_notes="$line"
        fi
    done
    
    echo ""
    echo "Release notes captured:"
    echo "───────────────────────────────────────────────────────────────────"
    echo -e "$release_notes"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""
    
    echo "$release_notes"
}

# Get release notes from various sources
get_release_notes() {
    local version="$1"
    local release_type="${2:-Release}"
    local source="${3:-auto}"
    local template_file="${4:-}"
    local previous_version="${5:-}"
    
    case "$source" in
        "git")
            generate_release_notes_from_git "$version" "$previous_version" "$release_type"
            ;;
        "template")
            generate_release_notes_from_template "$version" "$release_type" "$template_file"
            ;;
        "prompt")
            prompt_for_release_notes "$version" "$release_type"
            ;;
        "simple")
            # Use custom release notes as bullet points
            local custom_notes="${6:-}"
            if [[ -n "$custom_notes" ]]; then
                generate_simple_release_notes "$version" "$release_type" "$custom_notes"
            else
                log_warning "No custom notes provided for simple source"
                generate_release_notes_from_template "$version" "$release_type" "$template_file"
            fi
            ;;
        "auto")
            # Try git first, then fall back to template
            local git_notes=$(generate_release_notes_from_git "$version" "$previous_version" "$release_type")
            if [[ -n "$git_notes" && "$git_notes" != *"No changes detected"* ]]; then
                echo "$git_notes"
            else
                generate_release_notes_from_template "$version" "$release_type" "$template_file"
            fi
            ;;
        *)
            log_warning "Unknown release notes source: $source"
            generate_release_notes_from_template "$version" "$release_type" "$template_file"
            ;;
    esac
}

# Update Config.plist version
update_config_plist_version() {
    local version="$1"
    local config_plist="MSPCore/MSPCore/Resources/Config.plist"
    
    if [[ ! -f "$config_plist" ]]; then
        log_error "Config.plist not found: $config_plist"
        return 1
    fi
    
    log_step "Updating SDKVersion in Config.plist to $version"
    
    # Create backup
    cp "$config_plist" "${config_plist}.backup"
    
    # Update SDKVersion in Config.plist
    sed -i '' "s|<string>.*</string>|<string>${version}</string>|g" "$config_plist"
    
    log_success "Updated SDKVersion in Config.plist to $version"
}

# Export functions for use in other scripts
export -f log_info log_success log_warning log_error log_step log_release log_debug print_section print_subsection
export -f get_pod_dependencies is_valid_pod get_release_order_for_pod validate_release_order
export -f update_podspec_dependency_version update_podspec_to_zip_format
export -f get_project_root ensure_project_root
export -f retry_with_backoff validate_podspec_with_retry publish_podspec_with_retry
export -f create_github_release_with_retry create_github_release_internal
export -f get_environment get_environment_info format_release_notes_for_slack send_slack_notification
export -f notify_release_success notify_release_failure notify_release_warning notify_release_start notify_release_success_with_summary
export -f notify_pod_release notify_release_summary test_slack_notification
export -f generate_release_notes_from_git generate_release_notes_from_template generate_simple_release_notes prompt_for_release_notes get_release_notes
export -f update_config_plist_version
