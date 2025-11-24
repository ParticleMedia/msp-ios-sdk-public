#!/bin/bash

# Framework Configuration Library for MSP iOS SDK
# This module provides centralized framework configuration management

# Source dependencies
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# Framework configuration definitions
declare -A FRAMEWORK_CONFIGS

# Initialize framework configurations
init_framework_configs() {
    # MSPiOSCore configuration
    FRAMEWORK_CONFIGS["MSPiOSCore"]="name=MSPiOSCore;scheme=MSPiOSCore;output_dir=Build/Temp/MSPiOSCore;deploy_dir=MSPSharedLibraries;xcframework_name=MSPiOSCore.xcframework;source_only=false;podspec=MSPiOSCore/MSPiOSCore.podspec;project_path=MSPiOSCore/MSPiOSCore"
    
    # NovaCore configuration
    FRAMEWORK_CONFIGS["NovaCore"]="name=NovaCore;scheme=NovaCore;output_dir=Build/Temp/NovaCore;deploy_dir=NovaAdapter;xcframework_name=NovaCore.xcframework;source_only=false;podspec=NovaCore/NovaCore.podspec;project_path=NovaCore/NovaCore"
    
    # MSPCore configuration (source only)
    FRAMEWORK_CONFIGS["MSPCore"]="name=MSPCore;scheme=MSPCore;output_dir=;deploy_dir=;xcframework_name=;source_only=true;podspec=MSPCore/MSPCore.podspec;project_path=MSPCore/MSPCore"
}

# Parse configuration value from semicolon-separated string
parse_config_value() {
    local config_string="$1"
    local key="$2"
    
    if [[ -z "$config_string" || -z "$key" ]]; then
        return 1
    fi
    
    echo "$config_string" | grep -o "$key=[^;]*" | cut -d'=' -f2-
}

# Load framework configuration
load_framework_config() {
    local framework_name="$1"
    
    if [[ -z "$framework_name" ]]; then
        log_error "Framework name is required"
        return $EXIT_CONFIG_ERROR
    fi
    
    # Initialize configs if not already done
    if [[ ${#FRAMEWORK_CONFIGS[@]} -eq 0 ]]; then
        init_framework_configs
    fi
    
    local config_string="${FRAMEWORK_CONFIGS[$framework_name]}"
    if [[ -z "$config_string" ]]; then
        log_error "Configuration not found for framework: $framework_name"
        return $EXIT_CONFIG_ERROR
    fi
    
    # Parse configuration values
    FRAMEWORK_NAME=$(parse_config_value "$config_string" "name")
    FRAMEWORK_SCHEME=$(parse_config_value "$config_string" "scheme")
    FRAMEWORK_OUTPUT_DIR=$(parse_config_value "$config_string" "output_dir")
    FRAMEWORK_DEPLOY_DIR=$(parse_config_value "$config_string" "deploy_dir")
    FRAMEWORK_XCFRAMEWORK_NAME=$(parse_config_value "$config_string" "xcframework_name")
    FRAMEWORK_SOURCE_ONLY=$(parse_config_value "$config_string" "source_only")
    FRAMEWORK_PODSPEC=$(parse_config_value "$config_string" "podspec")
    FRAMEWORK_PROJECT_PATH=$(parse_config_value "$config_string" "project_path")
    
    # Validate required fields
    if [[ -z "$FRAMEWORK_NAME" || -z "$FRAMEWORK_SCHEME" ]]; then
        log_error "Invalid configuration for framework: $framework_name"
        return $EXIT_CONFIG_ERROR
    fi
    
    log_debug "Loaded configuration for $framework_name: scheme=$FRAMEWORK_SCHEME, source_only=$FRAMEWORK_SOURCE_ONLY"
    return $EXIT_SUCCESS
}

# Get list of available frameworks
get_available_frameworks() {
    # Initialize configs if not already done
    if [[ ${#FRAMEWORK_CONFIGS[@]} -eq 0 ]]; then
        init_framework_configs
    fi
    
    echo "${!FRAMEWORK_CONFIGS[@]}"
}

# Get list of XCFramework frameworks (non-source-only)
get_xcframework_frameworks() {
    local frameworks=()
    
    for framework in $(get_available_frameworks); do
        if load_framework_config "$framework" && [[ "$FRAMEWORK_SOURCE_ONLY" != "true" ]]; then
            frameworks+=("$framework")
        fi
    done
    
    echo "${frameworks[@]}"
}

# Get list of source-only frameworks
get_source_only_frameworks() {
    local frameworks=()
    
    for framework in $(get_available_frameworks); do
        if load_framework_config "$framework" && [[ "$FRAMEWORK_SOURCE_ONLY" == "true" ]]; then
            frameworks+=("$framework")
        fi
    done
    
    echo "${frameworks[@]}"
}

# Validate framework configuration
validate_framework_config() {
    local framework_name="$1"
    
    if ! load_framework_config "$framework_name"; then
        return $EXIT_CONFIG_ERROR
    fi
    
    # Check if project/workspace exists
    local project_path="$FRAMEWORK_PROJECT_PATH"
    if [[ -n "$project_path" ]]; then
        if [[ ! -d "$project_path" ]]; then
            log_error "Project path not found: $project_path"
            return $EXIT_CONFIG_ERROR
        fi
        
        # Check for project or workspace file
        if [[ ! -f "$project_path.xcodeproj/project.pbxproj" ]] && [[ ! -f "$project_path.xcworkspace/contents.xcworkspacedata" ]]; then
            log_error "Neither .xcodeproj nor .xcworkspace found at: $project_path"
            return $EXIT_CONFIG_ERROR
        fi
    fi
    
    # Check if podspec exists
    if [[ -n "$FRAMEWORK_PODSPEC" ]] && [[ ! -f "$FRAMEWORK_PODSPEC" ]]; then
        log_warning "Podspec not found: $FRAMEWORK_PODSPEC"
    fi
    
    log_success "Framework configuration validation passed for $framework_name"
    return $EXIT_SUCCESS
}

# Get framework build order (dependencies)
get_framework_build_order() {
    # For now, return a simple order - this could be enhanced with dependency analysis
    echo "MSPiOSCore NovaCore MSPCore"
}

# Check if framework needs XCFramework build
needs_xcframework_build() {
    local framework_name="$1"
    
    if ! load_framework_config "$framework_name"; then
        return 1
    fi
    
    [[ "$FRAMEWORK_SOURCE_ONLY" != "true" ]]
}

# Check if framework needs podspec validation
needs_podspec_validation() {
    local framework_name="$1"
    
    if ! load_framework_config "$framework_name"; then
        return 1
    fi
    
    [[ -n "$FRAMEWORK_PODSPEC" ]]
}

# Get framework display name
get_framework_display_name() {
    local framework_name="$1"
    
    case "$framework_name" in
        "MSPiOSCore") echo "MSP iOS Core" ;;
        "NovaCore") echo "Nova Core" ;;
        "MSPCore") echo "MSP Core" ;;
        *) echo "$framework_name" ;;
    esac
}

# Get framework description
get_framework_description() {
    local framework_name="$1"
    
    case "$framework_name" in
        "MSPiOSCore") echo "Core iOS SDK framework for MSP platform" ;;
        "NovaCore") echo "Nova advertising framework core" ;;
        "MSPCore") echo "MSP core functionality (source only)" ;;
        *) echo "Framework: $framework_name" ;;
    esac
}

# Export functions for use in other scripts
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
