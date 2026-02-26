#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch K, shared) ---
# shellcheck source=/dev/null
if command -v git >/dev/null 2>&1; then
  MSP_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$MSP_REPO_ROOT" ] && [ -f "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh" ]; then
    # shellcheck source=/dev/null
    . "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh"
    msp_enforce_main_repo_or_exit
  fi
fi
# --- End MSP Worktree Safety Guard (Patch K, shared) ---

# Framework Configuration Library for MSP iOS SDK
# This module provides centralized framework configuration management

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

declare -A FRAMEWORK_CONFIGS

init_framework_configs() {
    # MSPiOSCore configuration
    FRAMEWORK_CONFIGS["MSPiOSCore"]="name=MSPiOSCore;scheme=MSPiOSCore;output_dir=Build/Temp/MSPiOSCore;deploy_dir=MSPSharedLibraries;xcframework_name=MSPiOSCore.xcframework;source_only=false;podspec=MSPiOSCore/MSPiOSCore.podspec;project_path=MSPiOSCore/MSPiOSCore"
    
    # NovaCore configuration
    FRAMEWORK_CONFIGS["NovaCore"]="name=NovaCore;scheme=NovaCore;output_dir=Build/Temp/NovaCore;deploy_dir=NovaAdapter;xcframework_name=NovaCore.xcframework;source_only=false;podspec=NovaCore/NovaCore.podspec;project_path=NovaCore/NovaCore"
    
    # MSPCore configuration (source only)
    FRAMEWORK_CONFIGS["MSPCore"]="name=MSPCore;scheme=MSPCore;output_dir=;deploy_dir=;xcframework_name=;source_only=true;podspec=MSPCore/MSPCore.podspec;project_path=MSPCore/MSPCore"
}

parse_config_value() {
    local config_string="$1"
    local key="$2"
    
    if [[ -z "$config_string" || -z "$key" ]]; then
        return 1
    fi
    
    echo "$config_string" | grep -o "$key=[^;]*" | cut -d'=' -f2-
}

load_framework_config() {
    local framework_name="$1"

    if [[ -z "$framework_name" ]]; then
        log::error "FWCONFIG" "Framework name is required"
        return $EXIT_CONFIG_ERROR
    fi

    if [[ ${#FRAMEWORK_CONFIGS[@]} -eq 0 ]]; then
        init_framework_configs
    fi

    local config_string="${FRAMEWORK_CONFIGS[$framework_name]}"
    if [[ -z "$config_string" ]]; then
        log::error "FWCONFIG" "Configuration not found for framework: $framework_name"
        return $EXIT_CONFIG_ERROR
    fi

    FRAMEWORK_NAME=$(parse_config_value "$config_string" "name")
    FRAMEWORK_SCHEME=$(parse_config_value "$config_string" "scheme")
    FRAMEWORK_OUTPUT_DIR=$(parse_config_value "$config_string" "output_dir")
    FRAMEWORK_DEPLOY_DIR=$(parse_config_value "$config_string" "deploy_dir")
    FRAMEWORK_XCFRAMEWORK_NAME=$(parse_config_value "$config_string" "xcframework_name")
    FRAMEWORK_SOURCE_ONLY=$(parse_config_value "$config_string" "source_only")
    FRAMEWORK_PODSPEC=$(parse_config_value "$config_string" "podspec")
    FRAMEWORK_PROJECT_PATH=$(parse_config_value "$config_string" "project_path")

    if [[ -z "$FRAMEWORK_NAME" || -z "$FRAMEWORK_SCHEME" ]]; then
        log::error "FWCONFIG" "Invalid configuration for framework: $framework_name"
        return $EXIT_CONFIG_ERROR
    fi

    log::debug "FWCONFIG" "Loaded configuration for $framework_name: scheme=$FRAMEWORK_SCHEME, source_only=$FRAMEWORK_SOURCE_ONLY"
    return $EXIT_SUCCESS
}

get_available_frameworks() {
    if [[ ${#FRAMEWORK_CONFIGS[@]} -eq 0 ]]; then
        init_framework_configs
    fi
    
    echo "${!FRAMEWORK_CONFIGS[@]}"
}

get_xcframework_frameworks() {
    local frameworks=()
    
    for framework in $(get_available_frameworks); do
        if load_framework_config "$framework" && [[ "$FRAMEWORK_SOURCE_ONLY" != "true" ]]; then
            frameworks+=("$framework")
        fi
    done
    
    echo "${frameworks[@]}"
}

get_source_only_frameworks() {
    local frameworks=()
    
    for framework in $(get_available_frameworks); do
        if load_framework_config "$framework" && [[ "$FRAMEWORK_SOURCE_ONLY" == "true" ]]; then
            frameworks+=("$framework")
        fi
    done
    
    echo "${frameworks[@]}"
}

validate_framework_config() {
    local framework_name="$1"

    if ! load_framework_config "$framework_name"; then
        return $EXIT_CONFIG_ERROR
    fi

    local project_path="$FRAMEWORK_PROJECT_PATH"
    if [[ -n "$project_path" ]]; then
        if [[ ! -d "$project_path" ]]; then
            log::error "FWCONFIG" "Project path not found: $project_path"
            return $EXIT_CONFIG_ERROR
        fi

        if [[ ! -f "$project_path.xcodeproj/project.pbxproj" ]] && [[ ! -f "$project_path.xcworkspace/contents.xcworkspacedata" ]]; then
            log::error "FWCONFIG" "Neither .xcodeproj nor .xcworkspace found at: $project_path"
            return $EXIT_CONFIG_ERROR
        fi
    fi

    if [[ -n "$FRAMEWORK_PODSPEC" ]] && [[ ! -f "$FRAMEWORK_PODSPEC" ]]; then
        log::warn "FWCONFIG" "Podspec not found: $FRAMEWORK_PODSPEC"
    fi

    log::success "FWCONFIG" "Framework configuration validation passed for $framework_name"
    return $EXIT_SUCCESS
}

get_framework_build_order() {
    # For now, return a simple order - this could be enhanced with dependency analysis
    echo "MSPiOSCore NovaCore MSPCore"
}

needs_xcframework_build() {
    local framework_name="$1"
    
    if ! load_framework_config "$framework_name"; then
        return 1
    fi
    
    [[ "$FRAMEWORK_SOURCE_ONLY" != "true" ]]
}

needs_podspec_validation() {
    local framework_name="$1"
    
    if ! load_framework_config "$framework_name"; then
        return 1
    fi
    
    [[ -n "$FRAMEWORK_PODSPEC" ]]
}

get_framework_display_name() {
    local framework_name="$1"
    
    case "$framework_name" in
        "MSPiOSCore") echo "MSP iOS Core" ;;
        "NovaCore") echo "Nova Core" ;;
        "MSPCore") echo "MSP Core" ;;
        *) echo "$framework_name" ;;
    esac
}

get_framework_description() {
    local framework_name="$1"
    
    case "$framework_name" in
        "MSPiOSCore") echo "Core iOS SDK framework for MSP platform" ;;
        "NovaCore") echo "Nova advertising framework core" ;;
        "MSPCore") echo "MSP core functionality (source only)" ;;
        *) echo "Framework: $framework_name" ;;
    esac
}

export -f init_framework_configs
export -f parse_config_value
export -f load_framework_config
export -f get_available_frameworks
export -f get_xcframework_frameworks
export -f get_source_only_frameworks
export -f validate_framework_config
export -f get_framework_build_order
export -f needs_xcframework_build
export -f needs_podspec_validation
export -f get_framework_display_name
export -f get_framework_description
