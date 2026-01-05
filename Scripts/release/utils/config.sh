#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Release Configuration Parser
# ============================================================================
# Purpose: Minimal YAML parser for release.yaml configuration files.
#          Supports the specific structure used by msp-release.sh.
#
# Usage:
#   source Scripts/release/utils/config.sh
#   load_config "path/to/release.yaml"
#   echo "${CONFIG[version]}"
#   echo "${CONFIG[pods_modules]}"
#
# Supported Fields:
#   - version, release_branch, base_branch
#   - pods.enabled, pods.modules (array)
#   - spm.enabled, spm.packages (array)
#   - notifications.slack_channel, notifications.dm_on_failure
#
# Override Priority:
#   1. CLI flags (applied after config load)
#   2. Config file values
#   3. Default values (set by init_config_defaults)
# ============================================================================

# Prevent multiple sourcing
[[ -n "${_RELEASE_CONFIG_SOURCED:-}" ]] && return 0
readonly _RELEASE_CONFIG_SOURCED=1

# ============================================================================
# Global Configuration Store
# ============================================================================
# Note: Bash 3.x on macOS doesn't support associative arrays declared with
# `declare -A` at global scope reliably. We use a workaround with separate vars.

# Scalar values
CONFIG_VERSION=""
CONFIG_RELEASE_BRANCH=""
CONFIG_BASE_BRANCH=""
CONFIG_PODS_ENABLED=""
CONFIG_SPM_ENABLED=""
CONFIG_SLACK_CHANNEL=""
CONFIG_DM_ON_FAILURE=""
CONFIG_PODS_REMOTE_URL=""
CONFIG_PODS_REMOTE_PRIMARY_PRODUCT=""
CONFIG_SPM_REMOTE_URL=""
CONFIG_SPM_REMOTE_PRODUCT_NAME=""

# Array values (space-separated strings for bash 3.x compatibility)
CONFIG_PODS_MODULES=""
CONFIG_SPM_PACKAGES=""

# Config file path (for debugging)
CONFIG_FILE_PATH=""

# ============================================================================
# Default Values
# ============================================================================
init_config_defaults() {
    CONFIG_VERSION=""
    CONFIG_RELEASE_BRANCH=""
    CONFIG_BASE_BRANCH="main"
    CONFIG_PODS_ENABLED="true"
    CONFIG_SPM_ENABLED="true"
    CONFIG_SLACK_CHANNEL="#msp-release"
    CONFIG_DM_ON_FAILURE="true"
    
    # Default pod modules (in dependency order)
    CONFIG_PODS_MODULES="MSPSharedLibraries MSPPrebidAdapter MSPCore MSPGoogleAdapter MSPFacebookAdapter NovaAdapter AmazonAdapter MolocoAdapter LiftoffAdapter"
    
    # Default SPM packages
    CONFIG_SPM_PACKAGES="NovaCore NovaAdapter"
    
    # Remote verification defaults
    CONFIG_PODS_REMOTE_URL=""
    CONFIG_PODS_REMOTE_PRIMARY_PRODUCT="MSPCore"
    CONFIG_SPM_REMOTE_URL=""
    CONFIG_SPM_REMOTE_PRODUCT_NAME="MSPAds"
    
    # Verification settings
    CONFIG_VERIFY_SPM_STRICT="true"
    CONFIG_VERIFY_MATRIX_DEFAULT_VERSION="1.0.0"
    CONFIG_VERIFY_MATRIX_VERSION=""
    
    CONFIG_FILE_PATH=""
}

# Initialize defaults on source
init_config_defaults

# ============================================================================
# YAML Parser (Minimal Implementation)
# ============================================================================
# This parser handles the specific YAML structure of release.yaml.
# It is NOT a general-purpose YAML parser.

# Parse a simple YAML value (strips quotes and whitespace)
_parse_yaml_value() {
    local value="$1"
    # Remove leading/trailing whitespace
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    # Remove surrounding quotes
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"
    echo "$value"
}

# Parse array items from YAML (handles "- item" format)
_parse_yaml_array() {
    local file="$1"
    local start_key="$2"
    local result=""
    local in_array=false
    local indent_level=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Check if we've found the array key
        if [[ "$line" =~ ^[[:space:]]*${start_key}:[[:space:]]*$ ]]; then
            in_array=true
            # Calculate indent level
            local stripped="${line#"${line%%[![:space:]]*}"}"
            indent_level=$(( ${#line} - ${#stripped} ))
            continue
        fi
        
        if [[ "$in_array" == true ]]; then
            # Check if line starts with "- " at appropriate indent
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+ ]]; then
                # Extract the value after "- "
                local item="${line#*- }"
                item=$(_parse_yaml_value "$item")
                if [[ -n "$result" ]]; then
                    result="$result $item"
                else
                    result="$item"
                fi
            elif [[ ! "$line" =~ ^[[:space:]] ]] || [[ "$line" =~ ^[[:space:]]*[a-zA-Z_]+: ]]; then
                # New top-level key or less indented key - end of array
                break
            fi
        fi
    done < "$file"
    
    echo "$result"
}

# Load configuration from YAML file
load_config() {
    local config_file="$1"
    
    if [[ -z "$config_file" ]]; then
        echo "Error: No config file specified" >&2
        return 1
    fi
    
    if [[ ! -f "$config_file" ]]; then
        echo "Error: Config file not found: $config_file" >&2
        return 1
    fi
    
    # Initialize with defaults first
    init_config_defaults
    CONFIG_FILE_PATH="$config_file"
    
    local current_section=""
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Detect section headers (pods:, spm:, notifications:)
        if [[ "$line" =~ ^([a-zA-Z_]+):[[:space:]]*$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            continue
        fi
        
        # Parse top-level scalar values
        if [[ "$line" =~ ^([a-zA-Z_]+):[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value=$(_parse_yaml_value "${BASH_REMATCH[2]}")
            
            case "$key" in
                version)
                    CONFIG_VERSION="$value"
                    ;;
                release_branch)
                    CONFIG_RELEASE_BRANCH="$value"
                    ;;
                base_branch)
                    CONFIG_BASE_BRANCH="$value"
                    ;;
            esac
            continue
        fi
        
        # Parse section values (indented)
        if [[ "$line" =~ ^[[:space:]]+([a-zA-Z_]+):[[:space:]]*(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value=$(_parse_yaml_value "${BASH_REMATCH[2]}")
            
            case "$current_section" in
                pods)
                    case "$key" in
                        enabled)
                            CONFIG_PODS_ENABLED="$value"
                            ;;
                        remote_url)
                            CONFIG_PODS_REMOTE_URL="$value"
                            ;;
                        remote_primary_product)
                            CONFIG_PODS_REMOTE_PRIMARY_PRODUCT="$value"
                            ;;
                    esac
                    ;;
                spm)
                    case "$key" in
                        enabled)
                            CONFIG_SPM_ENABLED="$value"
                            ;;
                        remote_url)
                            CONFIG_SPM_REMOTE_URL="$value"
                            ;;
                        remote_product_name)
                            CONFIG_SPM_REMOTE_PRODUCT_NAME="$value"
                            ;;
                    esac
                    ;;
                notifications)
                    case "$key" in
                        slack_channel)
                            CONFIG_SLACK_CHANNEL="$value"
                            ;;
                        dm_on_failure)
                            CONFIG_DM_ON_FAILURE="$value"
                            ;;
                    esac
                    ;;
                verify)
                    case "$key" in
                        spm_strict)
                            # Normalize boolean value
                            if [[ "$value" == "true" ]] || [[ "$value" == "1" ]] || [[ "$value" == "yes" ]]; then
                                CONFIG_VERIFY_SPM_STRICT="true"
                            else
                                CONFIG_VERIFY_SPM_STRICT="false"
                            fi
                            ;;
                        matrix_default_version)
                            CONFIG_VERIFY_MATRIX_VERSION="$value"
                            ;;
                    esac
                    ;;
            esac
        fi
    done < "$config_file"
    
    # Parse array fields separately (they need special handling)
    local pods_modules
    pods_modules=$(_parse_yaml_array "$config_file" "modules")
    if [[ -n "$pods_modules" ]]; then
        CONFIG_PODS_MODULES="$pods_modules"
    fi
    
    local spm_packages
    spm_packages=$(_parse_yaml_array "$config_file" "packages")
    if [[ -n "$spm_packages" ]]; then
        CONFIG_SPM_PACKAGES="$spm_packages"
    fi
    
    return 0
}

# ============================================================================
# Config Getters (for cleaner access)
# ============================================================================

get_config_version() {
    echo "$CONFIG_VERSION"
}

get_config_release_branch() {
    if [[ -n "$CONFIG_RELEASE_BRANCH" ]]; then
        echo "$CONFIG_RELEASE_BRANCH"
    elif [[ -n "$CONFIG_VERSION" ]]; then
        echo "release/$CONFIG_VERSION"
    else
        echo ""
    fi
}

get_config_base_branch() {
    echo "$CONFIG_BASE_BRANCH"
}

get_config_pods_enabled() {
    echo "$CONFIG_PODS_ENABLED"
}

get_config_spm_enabled() {
    echo "$CONFIG_SPM_ENABLED"
}

get_config_pods_modules() {
    echo "$CONFIG_PODS_MODULES"
}

get_config_spm_packages() {
    echo "$CONFIG_SPM_PACKAGES"
}

get_config_slack_channel() {
    echo "$CONFIG_SLACK_CHANNEL"
}

get_config_dm_on_failure() {
    echo "$CONFIG_DM_ON_FAILURE"
}

get_config_pods_remote_url() {
    echo "$CONFIG_PODS_REMOTE_URL"
}

get_config_pods_remote_primary_product() {
    echo "$CONFIG_PODS_REMOTE_PRIMARY_PRODUCT"
}

get_config_spm_remote_url() {
    echo "$CONFIG_SPM_REMOTE_URL"
}

get_config_spm_remote_product_name() {
    echo "$CONFIG_SPM_REMOTE_PRODUCT_NAME"
}

get_config_verify_spm_strict() {
    echo "$CONFIG_VERIFY_SPM_STRICT"
}

get_config_verify_matrix_version() {
    echo "${CONFIG_VERIFY_MATRIX_VERSION:-$CONFIG_VERIFY_MATRIX_DEFAULT_VERSION}"
}

# ============================================================================
# Config Setters (for CLI overrides)
# ============================================================================

set_config_version() {
    CONFIG_VERSION="$1"
}

set_config_release_branch() {
    CONFIG_RELEASE_BRANCH="$1"
}

set_config_base_branch() {
    CONFIG_BASE_BRANCH="$1"
}

set_config_pods_enabled() {
    CONFIG_PODS_ENABLED="$1"
}

set_config_spm_enabled() {
    CONFIG_SPM_ENABLED="$1"
}

set_config_pods_modules() {
    CONFIG_PODS_MODULES="$1"
}

set_config_spm_packages() {
    CONFIG_SPM_PACKAGES="$1"
}

# ============================================================================
# Config Validation
# ============================================================================

validate_config() {
    local errors=0
    
    # Version is required for actual releases (not for --help, etc.)
    # This is checked at runtime, not here
    
    # Base branch should not be empty
    if [[ -z "$CONFIG_BASE_BRANCH" ]]; then
        echo "Warning: base_branch is empty, using 'main'" >&2
        CONFIG_BASE_BRANCH="main"
    fi
    
    # At least one of pods or spm should be enabled
    if [[ "$CONFIG_PODS_ENABLED" != "true" && "$CONFIG_SPM_ENABLED" != "true" ]]; then
        echo "Warning: Both pods and spm are disabled, nothing to release" >&2
    fi
    
    return $errors
}

# ============================================================================
# Config Summary (for verbose output)
# ============================================================================

print_config_summary() {
    echo ""
    echo "┌─────────────────────────────────────────────────────────────────┐"
    echo "│                     Release Configuration                       │"
    echo "├─────────────────────────────────────────────────────────────────┤"
    
    if [[ -n "$CONFIG_FILE_PATH" ]]; then
        echo "│ Config File: $(printf '%-50s' "$CONFIG_FILE_PATH") │"
    else
        echo "│ Config File: (none - using defaults)                          │"
    fi
    
    echo "├─────────────────────────────────────────────────────────────────┤"
    printf "│ %-20s %-42s │\n" "Version:" "${CONFIG_VERSION:-<not set>}"
    printf "│ %-20s %-42s │\n" "Release Branch:" "$(get_config_release_branch)"
    printf "│ %-20s %-42s │\n" "Base Branch:" "$CONFIG_BASE_BRANCH"
    echo "├─────────────────────────────────────────────────────────────────┤"
    printf "│ %-20s %-42s │\n" "Pods Enabled:" "$CONFIG_PODS_ENABLED"
    printf "│ %-20s %-42s │\n" "Pods Modules:" "$(echo $CONFIG_PODS_MODULES | wc -w | tr -d ' ') module(s)"
    echo "├─────────────────────────────────────────────────────────────────┤"
    printf "│ %-20s %-42s │\n" "SPM Enabled:" "$CONFIG_SPM_ENABLED"
    printf "│ %-20s %-42s │\n" "SPM Packages:" "$(echo $CONFIG_SPM_PACKAGES | wc -w | tr -d ' ') package(s)"
    echo "├─────────────────────────────────────────────────────────────────┤"
    printf "│ %-20s %-42s │\n" "Slack Channel:" "$CONFIG_SLACK_CHANNEL"
    printf "│ %-20s %-42s │\n" "DM on Failure:" "$CONFIG_DM_ON_FAILURE"
    echo "└─────────────────────────────────────────────────────────────────┘"
    echo ""
}

# Print detailed config (for debugging)
print_config_debug() {
    echo "=== Config Debug ==="
    echo "CONFIG_FILE_PATH=$CONFIG_FILE_PATH"
    echo "CONFIG_VERSION=$CONFIG_VERSION"
    echo "CONFIG_RELEASE_BRANCH=$CONFIG_RELEASE_BRANCH"
    echo "CONFIG_BASE_BRANCH=$CONFIG_BASE_BRANCH"
    echo "CONFIG_PODS_ENABLED=$CONFIG_PODS_ENABLED"
    echo "CONFIG_PODS_MODULES=$CONFIG_PODS_MODULES"
    echo "CONFIG_SPM_ENABLED=$CONFIG_SPM_ENABLED"
    echo "CONFIG_SPM_PACKAGES=$CONFIG_SPM_PACKAGES"
    echo "CONFIG_SLACK_CHANNEL=$CONFIG_SLACK_CHANNEL"
    echo "CONFIG_DM_ON_FAILURE=$CONFIG_DM_ON_FAILURE"
    echo "===================="
}

# ============================================================================
# Export Functions
# ============================================================================
export -f init_config_defaults
export -f load_config
export -f get_config_version get_config_release_branch get_config_base_branch
export -f get_config_pods_enabled get_config_spm_enabled
export -f get_config_pods_modules get_config_spm_packages
export -f get_config_slack_channel get_config_dm_on_failure
export -f get_config_pods_remote_url get_config_pods_remote_primary_product
export -f get_config_spm_remote_url get_config_spm_remote_product_name
export -f get_config_verify_spm_strict get_config_verify_matrix_version
export -f set_config_version set_config_release_branch set_config_base_branch
export -f set_config_pods_enabled set_config_spm_enabled
export -f set_config_pods_modules set_config_spm_packages
export -f validate_config print_config_summary print_config_debug

