#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

# ============================================================================
# MSP Release Configuration Loader (Patch M+CONFIG)
# ============================================================================
# Purpose: Load branch policy configuration from YAML file
#          Provides branch-aware policy checks without external dependencies
#
# Usage:
#   source Scripts/release/lib/config.sh
#   msp_load_release_config
#   if should_real_publish; then
#       echo "Real publish allowed"
#   fi
# ============================================================================

# Prevent multiple sourcing
[[ -n "${_MSP_RELEASE_CONFIG_SOURCED:-}" ]] && return 0
readonly _MSP_RELEASE_CONFIG_SOURCED=1

# ============================================================================
# Configuration File Path
# ============================================================================
MSP_RELEASE_CONFIG_FILE=""

# ============================================================================
# Load Configuration File
# ============================================================================
msp_load_release_config() {
    local repo_root
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
    
    if [[ -z "$repo_root" ]]; then
        echo "[CONFIG][ERROR] Cannot determine repository root" >&2
        return 1
    fi
    
    MSP_RELEASE_CONFIG_FILE="$repo_root/Scripts/release/config/release_config.yaml"
    
    if [[ ! -f "$MSP_RELEASE_CONFIG_FILE" ]]; then
        echo "[CONFIG][WARN] Configuration file not found: $MSP_RELEASE_CONFIG_FILE" >&2
        echo "[CONFIG][WARN] Using fail-safe defaults (preflight only)" >&2
        return 1
    fi
    
    return 0
}

# ============================================================================
# Simple YAML Parser for Branch Policy
# ============================================================================
_msp_parse_yaml_value() {
    local key_path="$1"
    local config_file="${2:-$MSP_RELEASE_CONFIG_FILE}"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    # Parse key_path: branch_policy.rules.main.allow_real_publish or branch_policy.rules.feature/spm_impl.allow_real_publish
    # Extract branch name (may contain slashes) and key
    local branch_name=""
    local key_name=""
    
    # Match: branch_policy.rules.<branch_name>.<key_name>
    # Branch name can contain slashes, so we capture everything until the last dot
    if [[ "$key_path" =~ branch_policy\.rules\.(.+)\.(.+)$ ]]; then
        branch_name="${BASH_REMATCH[1]}"
        key_name="${BASH_REMATCH[2]}"
    else
        return 1
    fi
    
    # Remove quotes from branch_name if present
    branch_name="${branch_name//\"/}"
    branch_name="${branch_name//\'/}"
    
    # Find the section in YAML file
    local in_section=0
    local found_key=0
    local result=""
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Check if we're entering the branch section (handle both quoted and unquoted, with slashes)
        if [[ "$line" =~ ^[[:space:]]*"${branch_name}":[[:space:]]*$ ]] || [[ "$line" =~ ^[[:space:]]*${branch_name}:[[:space:]]*$ ]]; then
            in_section=1
            continue
        fi
        
        # Check if we're leaving the section (new top-level key at column 0)
        if [[ $in_section -eq 1 ]] && [[ "$line" =~ ^[^[:space:]] ]]; then
            break
        fi
        
        # If we're in the section, look for the key
        if [[ $in_section -eq 1 ]] && [[ "$line" =~ ^[[:space:]]+${key_name}:[[:space:]]*(.+)$ ]]; then
            result="${BASH_REMATCH[1]}"
            # Remove quotes and trim whitespace
            result="${result//\"/}"
            result="${result//\'/}"
            # Trim leading whitespace
            result="${result#"${result%%[![:space:]]*}"}"
            # Trim trailing whitespace
            result="${result%"${result##*[![:space:]]}"}"
            found_key=1
            break
        fi
    done < "$config_file"
    
    if [[ $found_key -eq 1 ]] && [[ -n "$result" ]]; then
        echo "$result"
        return 0
    fi
    
    return 1
}

# ============================================================================
# Get Branch Policy Value with Pattern Matching
# ============================================================================
msp_get_branch_policy_value() {
    local key="$1"
    local branch="${2:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")}"
    
    if [[ -z "$branch" ]]; then
        echo "[CONFIG][ERROR] Cannot determine current branch" >&2
        return 1
    fi
    
    if [[ -z "$MSP_RELEASE_CONFIG_FILE" ]] || [[ ! -f "$MSP_RELEASE_CONFIG_FILE" ]]; then
        msp_load_release_config || return 1
    fi
    
    # Try exact match first
    local exact_path="branch_policy.rules.$branch.$key"
    local value
    value=$(_msp_parse_yaml_value "$exact_path" "$MSP_RELEASE_CONFIG_FILE" 2>/dev/null)
    
    if [[ -n "$value" ]]; then
        echo "$value"
        return 0
    fi
    
    # Try regex patterns (quoted strings in YAML)
    local pattern
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Extract pattern from lines like: "release/.*": or "feature/.+":
        if [[ "$line" =~ ^[[:space:]]*\"([^\"]+)\":[[:space:]]*$ ]]; then
            pattern="${BASH_REMATCH[1]}"
            
            # Check if branch matches pattern (convert regex to bash pattern)
            local bash_pattern="${pattern//\./\.}"  # Escape dots
            bash_pattern="${bash_pattern//\+/\+}"   # Escape plus
            bash_pattern="${bash_pattern//\*/.*}"    # Convert * to .*
            bash_pattern="${bash_pattern//\?/.}"     # Convert ? to .
            
            if [[ "$branch" =~ ^${bash_pattern}$ ]]; then
                # Found matching pattern, get the value
                local pattern_path="branch_policy.rules.\"$pattern\".$key"
                value=$(_msp_parse_yaml_value "$pattern_path" "$MSP_RELEASE_CONFIG_FILE" 2>/dev/null)
                if [[ -n "$value" ]]; then
                    echo "$value"
                    return 0
                fi
            fi
        fi
    done < <(grep -E "^[[:space:]]*\"[^\"]+\":" "$MSP_RELEASE_CONFIG_FILE" 2>/dev/null)
    
    # No match found - fail-safe: return false for real/test publish, true for preflight
    if [[ "$key" == "allow_preflight" ]]; then
        echo "true"
        return 0
    else
        echo "false"
        return 1
    fi
}

# ============================================================================
# Policy Check Functions
# ============================================================================
should_real_publish() {
    local value
    value=$(msp_get_branch_policy_value "allow_real_publish" 2>/dev/null)
    [[ "$value" == "true" ]]
}

should_test_publish() {
    local value
    value=$(msp_get_branch_policy_value "allow_test_publish" 2>/dev/null)
    [[ "$value" == "true" ]]
}

should_preflight_run() {
    local value
    value=$(msp_get_branch_policy_value "allow_preflight" 2>/dev/null)
    [[ "$value" == "true" ]]
}

# ============================================================================
# Export Functions
# ============================================================================
export -f msp_load_release_config \
         msp_get_branch_policy_value \
         should_real_publish \
         should_test_publish \
         should_preflight_run 2>/dev/null || true
