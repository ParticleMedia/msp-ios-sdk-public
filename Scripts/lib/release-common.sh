#!/bin/bash

# Release Common Library
# Shared functions and configurations for all release scripts

# Try to source UI system (if available)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

# ============================================================================
# Slack Notification Functions (Extracted to notify/slack.sh)
# ============================================================================
# Phase 1 Refactoring: Slack functions have been extracted to a dedicated module.
# This source statement provides backward compatibility.
# See: Scripts/notify/slack.sh for the implementation.

# Source the Slack notification module
if [[ -f "$ROOT_DIR/Scripts/notify/slack.sh" ]]; then
    # shellcheck source=Scripts/notify/slack.sh
    source "$ROOT_DIR/Scripts/notify/slack.sh"
else
    # Fallback: Define stub functions if module not found
    log_warning "notify/slack.sh not found - Slack notifications will be disabled"
    send_slack_notification() { log_warning "Slack notifications disabled (module not found)"; }
    notify_release_success() { :; }
    notify_release_failure() { :; }
    notify_release_warning() { :; }
    notify_release_start() { :; }
    notify_pod_release() { :; }
    notify_release_summary() { :; }
    notify_release_success_with_summary() { :; }
    test_slack_notification() { log_error "Slack notifications disabled (module not found)"; return 1; }
fi

# Backward compatibility: Re-export environment functions
# These are now defined in notify/slack.sh but may be used by other scripts
get_environment() {
    get_slack_environment
}

get_environment_info() {
    get_slack_environment_info
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
# Note: Logging functions may come from lib/ui.sh or fallbacks defined above
export -f log_info log_success log_warning log_error log_step log_release log_debug print_section print_subsection 2>/dev/null || true

# Export pod configuration functions
export -f get_pod_dependencies is_valid_pod get_release_order_for_pod validate_release_order

# Export podspec utilities
export -f update_podspec_dependency_version update_podspec_to_zip_format

# Export project utilities
export -f get_project_root ensure_project_root

# Export retry utilities
export -f retry_with_backoff validate_podspec_with_retry publish_podspec_with_retry

# Export GitHub release utilities
export -f create_github_release_with_retry create_github_release_internal

# Export environment functions (backward compatibility wrappers)
export -f get_environment get_environment_info

# Export release notes functions
export -f generate_release_notes_from_git generate_release_notes_from_template generate_simple_release_notes prompt_for_release_notes get_release_notes

# Export version update functions
export -f update_config_plist_version

# Note: Slack notification functions are exported by Scripts/notify/slack.sh
# The following are available after sourcing this file:
#   - send_slack_notification
#   - notify_release_success, notify_release_failure, notify_release_warning
#   - notify_release_start, notify_pod_release, notify_release_summary
#   - notify_release_success_with_summary, test_slack_notification
#   - format_release_notes_for_slack
