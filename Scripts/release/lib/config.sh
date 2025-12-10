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

    # Use awk to parse YAML - more reliable than bash regex
    # Use match() function instead of ~ operator to handle special characters in branch names
    local branch_escaped="${branch_name////\/}"
    result=$(awk -v branch="$branch_escaped" -v key="$key_name" '
        BEGIN { in_rules=0; in_branch=0 }
        /^[[:space:]]*branch_policy:/ { in_rules=1; next }
        in_rules && /^[[:space:]]*rules:/ { next }
        in_rules && match($0, "^[[:space:]]+" branch ":") { in_branch=1; next }
        in_branch && match($0, "^[[:space:]]+" key ":") {
            gsub(/^[[:space:]]+/, "");
            gsub(/^[^:]+:[[:space:]]*/, "");
            gsub(/^[[:space:]]+|[[:space:]]+$/, "");
            gsub(/^"|"$/, "");
            print;
            exit
        }
        in_branch && /^[[:space:]]{0,4}[^[:space:]]/ && !match($0, "^[[:space:]]+" branch ":") {
            exit
        }
    ' "$config_file" 2>/dev/null)

    if [[ -n "$result" ]]; then
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

# ============================================================================
# Tier-Specific Configuration Cache (Patch M+Config Phase 2)
# ============================================================================

# ============================================================================
# Parse Tier-Specific Configuration Value
# ============================================================================
_msp_parse_tier_config_value() {
    local tier="$1"
    local key="$2"
    local config_file="${3:-$MSP_RELEASE_CONFIG_FILE}"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    # Use awk to parse tier-specific config
    local result
    result=$(awk -v tier="$tier" -v key="$key" '
        BEGIN { in_tier=0; found=0 }
        /^'"$tier"':/ { 
            in_tier=1
            next
        }
        in_tier && /^[[:space:]]+'"$key"':/ {
            # Extract value
            gsub(/^[[:space:]]+'"$key"':[[:space:]]*/, "")
            gsub(/^[[:space:]]+|[[:space:]]+$/, "")
            gsub(/^"|"$/, "")
            print
            found=1
            exit
        }
        in_tier && /^[a-z_]+:/ && !/^[[:space:]]+/ {
            # Left tier section (found next top-level key)
            exit
        }
        END {
            if (!found) exit 1
        }
    ' "$config_file" 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        echo "$result"
        return 0
    fi
    
    return 1
}

# ============================================================================
# Get Tier-Specific Configuration Value (with caching)
# ============================================================================
msp_cfg_get() {
    local key="$1"
    local tier="${2:-${MSP_RELEASE_TIER:-preflight}}"
    
    # Normalize tier name
    if [[ "$tier" == "production" ]]; then
        tier="release"
    fi
    
    # Validate tier
    if [[ "$tier" != "preflight" ]] && [[ "$tier" != "release" ]]; then
        echo "[CONFIG][ERROR] Invalid tier: $tier (must be 'preflight' or 'release')" >&2
        return 1
    fi
    
    # Check cache first
    local cache_key="${tier}.${key}"
    if [[ -n "$(echo "$_MSP_CFG_CACHE" | grep "^${cache_key}=" | cut -d= -f2-)" ]]; then
        echo "$(echo "$_MSP_CFG_CACHE" | grep "^${cache_key}=" | cut -d= -f2-)"
        return 0
    fi
    
    # Load config if needed
    if [[ -z "$MSP_RELEASE_CONFIG_FILE" ]] || [[ ! -f "$MSP_RELEASE_CONFIG_FILE" ]]; then
        msp_load_release_config || {
            echo "[CONFIG][ERROR] Failed to load configuration file" >&2
            return 1
        }
    fi
    
    # Parse value
    local value
    value=$(_msp_parse_tier_config_value "$tier" "$key" "$MSP_RELEASE_CONFIG_FILE" 2>/dev/null)
    
    if [[ -z "$value" ]]; then
        echo "[CONFIG][ERROR] Configuration key '$key' not found for tier '$tier'" >&2
        echo "[CONFIG][ERROR] Check Scripts/release/config/release_config.yaml" >&2
        return 1
    fi
    
    # Cache and return
    _MSP_CFG_CACHE="${cache_key}=$value"
    echo "$value"
    return 0
}

# ============================================================================
# Check if Configuration Key is Enabled
# ============================================================================
is_enabled() {
    local key="$1"
    local tier="${2:-${MSP_RELEASE_TIER:-preflight}}"
    
    local value
    value=$(msp_cfg_get "$key" "$tier" 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        # If key not found, fail-safe: return false
        return 1
    fi
    
    # Check if value is true (case-insensitive)
    local value_lower
    value_lower=$(echo "$value" | tr '[:upper:]' '[:lower:]')
    [[ "$value_lower" == "true" ]]
}

# ============================================================================
# Update Export Functions
# ============================================================================
# Re-export with new functions
export -f msp_cfg_get \
         is_enabled 2>/dev/null || true
