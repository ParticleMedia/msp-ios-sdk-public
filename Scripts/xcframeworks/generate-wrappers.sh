#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# Automated Wrapper Generator
# Generates SwiftPM wrapper packages for CocoaPods SDKs that don't support SPM
# Usage: ./Scripts/xcframeworks/generate-wrappers.sh [--wrapper <name>] [--all]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/lib/paths.sh
source "$ROOT_DIR/Scripts/lib/paths.sh"
# shellcheck source=Scripts/lib/colors.sh
source "$ROOT_DIR/Scripts/lib/colors.sh"
# shellcheck source=Scripts/lib/ui.sh
source "$ROOT_DIR/Scripts/lib/ui.sh"

# Ensure logger functions are available in subprocess
# (Force reload by unsetting the guard variable, as parent may have already sourced)
if [[ -f "$ROOT_DIR/Scripts/release/utils/logger.sh" ]]; then
    unset MSP_LOGGER_LOADED
    # shellcheck source=Scripts/release/utils/logger.sh
    source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true
fi

init_paths

# Wrapper definitions: scheme_name:output_wrapper:sdk_name:source_path:pods_dir
# Using case statement instead of associative array for bash 3.2 compatibility
get_wrapper_config() {
    local wrapper_key="$1"
    case "$wrapper_key" in
        "Shimmer")
            echo "Shimmer:ShimmerWrapper:Shimmer::Pods/Shimmer"
            ;;
        "FBAudienceNetwork")
            echo "FBAudienceNetwork:FBAudienceNetworkWrapper:FBAudienceNetwork::Pods/FBAudienceNetwork"
            ;;
        "IronSourceSDK")
            echo ":IronSourceSDKWrapper:IronSourceSDK:Pods/IronSourceSDK/IronSource/IronSource.xcframework:Pods/IronSourceSDK"
            ;;
        "OpenWrapSDK")
            echo ":OpenWrapSDKWrapper:OpenWrapSDK:Pods/OpenWrapSDK/OpenWrapSDK/OpenWrapSDK.xcframework:Pods/OpenWrapSDK"
            ;;
        "MintegralAdSDK")
            echo ":MintegralAdSDKWrapper:MintegralAdSDK:Pods/MintegralAdSDK/Fmk/MTGSDK.xcframework:Pods/MintegralAdSDK"
            ;;
        "MobileFuseSDK")
            echo ":MobileFuseSDKWrapper:MobileFuseSDK:Pods/MobileFuseSDK/MobileFuseSDK.xcframework:Pods/MobileFuseSDK"
            ;;
        "InMobiSDK")
            echo ":InMobiSDKWrapper:InMobiSDK:Pods/InMobiSDK/InMobiSDK.xcframework:Pods/InMobiSDK"
            ;;
        *)
            echo ""
            ;;
    esac
}

# List of all wrapper keys
WRAPPER_KEYS=(
    "Shimmer"
    "FBAudienceNetwork"
    "IronSourceSDK"
    "OpenWrapSDK"
    "MintegralAdSDK"
    "MobileFuseSDK"
    "InMobiSDK"
)

generate_package_swift() {
    local wrapper_name="$1"
    local sdk_name="$2"
    local module_name="${3:-$sdk_name}"
    local platforms="${4:-iOS(.v12)}"
    
    local package_path="$ROOT_DIR/${wrapper_name}/Package.swift"
    mkdir -p "$(dirname "$package_path")"
    
    cat > "$package_path" <<PACKAGE_SWIFT
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "${wrapper_name}",
    platforms: [
        .${platforms}
    ],
    products: [
        .library(
            name: "${wrapper_name}",
            targets: ["${wrapper_name}"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "${module_name}",
            path: "Frameworks/${sdk_name}.xcframework"
        ),
        .target(
            name: "${wrapper_name}",
            dependencies: ["${module_name}"],
            path: "Sources/${wrapper_name}",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ]
        )
    ]
)
PACKAGE_SWIFT
    
    log::info "XCFW" "Generated: $package_path"
}

generate_wrapper_source() {
    local wrapper_name="$1"
    local module_name="$2"
    
    local sources_dir="$ROOT_DIR/${wrapper_name}/Sources/${wrapper_name}"
    mkdir -p "$sources_dir"
    
    local source_file="$sources_dir/${wrapper_name}.swift"
    cat > "$source_file" <<SWIFT_SOURCE
// Re-export ${module_name} module to make all ${module_name} APIs available
@_exported import ${module_name}
SWIFT_SOURCE
    
    log::info "XCFW" "Generated: $source_file"
}

create_wrapper_structure() {
    local wrapper_name="$1"
    
    mkdir -p "$ROOT_DIR/${wrapper_name}/Frameworks"
    mkdir -p "$ROOT_DIR/${wrapper_name}/Sources/${wrapper_name}/include"
    
    log::info "XCFW" "Created directory structure for $wrapper_name"
}

process_wrapper() {
    local wrapper_key="$1"
    local wrapper_config
    wrapper_config=$(get_wrapper_config "$wrapper_key")
    
    if [[ -z "$wrapper_config" ]]; then
        log::error "XCFW" "Unknown wrapper: $wrapper_key"
        return 1
    fi
    
    IFS=':' read -r scheme output_wrapper sdk_name source_path pods_dir <<< "$wrapper_config" || {
        log::error "XCFW" "Failed to parse wrapper config for: $wrapper_key"
        return 1
    }
    
    log_section "Processing: $wrapper_key"
    echo "Scheme: $scheme"
    echo "Output: $output_wrapper"
    echo "SDK Name: $sdk_name"
    echo "Source Path: $source_path"
    echo "Pods Dir: $pods_dir"
    
    create_wrapper_structure "$output_wrapper"
    
    # Determine module name (for binary target)
    local module_name="$sdk_name"
    case "$wrapper_key" in
        "IronSourceSDK")
            module_name="IronSource"
            ;;
        "MintegralAdSDK")
            module_name="MTGSDK"
            ;;
    esac
    
    # Generate Package.swift
    generate_package_swift "$output_wrapper" "$sdk_name" "$module_name"
    
    # Generate wrapper source
    generate_wrapper_source "$output_wrapper" "$module_name"
    
    # Build xcframework if source path is provided (copy mode) or scheme is provided (build mode)
    if [[ -n "$source_path" ]]; then
        log::step "XCFW" "Building xcframework (copy mode)"
        "$SCRIPT_DIR/builder.sh" \
            --copy \
            --source-path "$ROOT_DIR/$source_path" \
            --output "$output_wrapper" \
            --sdk-name "$sdk_name" \
            --pods-dir "$ROOT_DIR/$pods_dir" || {
            log::warn "XCFW" "Failed to build xcframework for $wrapper_key"
        }
    elif [[ -n "$scheme" ]]; then
        log::step "XCFW" "Building xcframework (build mode)"
        "$SCRIPT_DIR/builder.sh" \
            --scheme "$scheme" \
            --output "$output_wrapper" \
            --sdk-name "$sdk_name" \
            --pods-dir "$ROOT_DIR/$pods_dir" || {
            log::warn "XCFW" "Failed to build xcframework for $wrapper_key"
        }
    else
        log::warn "XCFW" "No build method specified for $wrapper_key"
    fi
    
    log::success "XCFW" "Completed: $wrapper_key"
}

# Main execution
MAIN() {
    local process_all=false
    local specific_wrapper=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                process_all=true
                shift
                ;;
            --wrapper)
                specific_wrapper="$2"
                shift 2
                ;;
            *)
                log::error "XCFW" "Unknown option: $1"
                log::info "XCFW" "Usage: $0 [--all] [--wrapper <name>]"
                exit 1
                ;;
        esac
    done
    
    log_title "Wrapper Generator"
    
    if [[ "$process_all" == true ]]; then
        log::info "XCFW" "Processing all wrappers..."
        for wrapper_key in "${WRAPPER_KEYS[@]}"; do
            process_wrapper "$wrapper_key"
        done
    elif [[ -n "$specific_wrapper" ]]; then
        process_wrapper "$specific_wrapper"
    else
        log::error "XCFW" "Must specify --all or --wrapper <name>"
        exit 1
    fi
    
    log_title "Wrapper Generation Complete"
    log::success "XCFW" "All wrappers processed successfully"
}

MAIN "$@"

