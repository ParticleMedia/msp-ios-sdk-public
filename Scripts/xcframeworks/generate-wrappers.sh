#!/usr/bin/env bash
# Automated Wrapper Generator
# Generates SwiftPM wrapper packages for CocoaPods SDKs that don't support SPM
# Usage: ./Scripts/xcframeworks/generate-wrappers.sh [--wrapper <name>] [--all]

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wrapper definitions: scheme_name:output_wrapper:sdk_name:source_path:pods_dir
declare -A WRAPPERS=(
    ["Shimmer"]="Shimmer:ShimmerWrapper:Shimmer::Pods/Shimmer"
    ["FBAudienceNetwork"]="FBAudienceNetwork:FBAudienceNetworkWrapper:FBAudienceNetwork::Pods/FBAudienceNetwork"
    ["IronSourceSDK"]=":IronSourceSDKWrapper:IronSourceSDK:Pods/IronSourceSDK/IronSource/IronSource.xcframework:Pods/IronSourceSDK"
    ["OpenWrapSDK"]=":OpenWrapSDKWrapper:OpenWrapSDK:Pods/OpenWrapSDK/OpenWrapSDK/OpenWrapSDK.xcframework:Pods/OpenWrapSDK"
    ["MintegralAdSDK"]=":MintegralAdSDKWrapper:MintegralAdSDK:Pods/MintegralAdSDK/Fmk/MTGSDK.xcframework:Pods/MintegralAdSDK"
    ["MobileFuseSDK"]=":MobileFuseSDKWrapper:MobileFuseSDK:Pods/MobileFuseSDK/MobileFuseSDK.xcframework:Pods/MobileFuseSDK"
    ["InMobiSDK"]=":InMobiSDKWrapper:InMobiSDK:Pods/InMobiSDK/InMobiSDK.xcframework:Pods/InMobiSDK"
)

# Function to generate Package.swift for a wrapper
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
    
    echo "Generated: $package_path"
}

# Function to generate wrapper source file
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
    
    echo "Generated: $source_file"
}

# Function to create wrapper directory structure
create_wrapper_structure() {
    local wrapper_name="$1"
    
    mkdir -p "$ROOT_DIR/${wrapper_name}/Frameworks"
    mkdir -p "$ROOT_DIR/${wrapper_name}/Sources/${wrapper_name}/include"
    
    echo "Created directory structure for $wrapper_name"
}

# Function to process a single wrapper
process_wrapper() {
    local wrapper_key="$1"
    local wrapper_config="${WRAPPERS[$wrapper_key]}"
    
    if [[ -z "$wrapper_config" ]]; then
        echo "ERROR: Unknown wrapper: $wrapper_key" >&2
        return 1
    fi
    
    IFS=':' read -r scheme output_wrapper sdk_name source_path pods_dir <<< "$wrapper_config" || {
        echo "ERROR: Failed to parse wrapper config for: $wrapper_key" >&2
        return 1
    }
    
    echo ""
    echo "=========================================="
    echo "Processing: $wrapper_key"
    echo "=========================================="
    echo "Scheme: $scheme"
    echo "Output: $output_wrapper"
    echo "SDK Name: $sdk_name"
    echo "Source Path: $source_path"
    echo "Pods Dir: $pods_dir"
    
    # Create directory structure
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
        echo "Building xcframework (copy mode)..."
        "$SCRIPT_DIR/builder.sh" \
            --copy \
            --source-path "$ROOT_DIR/$source_path" \
            --output "$output_wrapper" \
            --sdk-name "$sdk_name" \
            --pods-dir "$ROOT_DIR/$pods_dir" || {
            echo "WARNING: Failed to build xcframework for $wrapper_key" >&2
        }
    elif [[ -n "$scheme" ]]; then
        echo "Building xcframework (build mode)..."
        "$SCRIPT_DIR/builder.sh" \
            --scheme "$scheme" \
            --output "$output_wrapper" \
            --sdk-name "$sdk_name" \
            --pods-dir "$ROOT_DIR/$pods_dir" || {
            echo "WARNING: Failed to build xcframework for $wrapper_key" >&2
        }
    else
        echo "WARNING: No build method specified for $wrapper_key" >&2
    fi
    
    echo "✓ Completed: $wrapper_key"
}

# Main execution
MAIN() {
    local process_all=false
    local specific_wrapper=""
    
    # Parse arguments
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
                echo "ERROR: Unknown option: $1" >&2
                echo "Usage: $0 [--all] [--wrapper <name>]" >&2
                exit 1
                ;;
        esac
    done
    
    echo "=========================================="
    echo "Wrapper Generator"
    echo "=========================================="
    echo ""
    
    if [[ "$process_all" == true ]]; then
        echo "Processing all wrappers..."
        for wrapper_key in "${!WRAPPERS[@]}"; do
            process_wrapper "$wrapper_key"
        done
    elif [[ -n "$specific_wrapper" ]]; then
        process_wrapper "$specific_wrapper"
    else
        echo "ERROR: Must specify --all or --wrapper <name>" >&2
        exit 1
    fi
    
    echo ""
    echo "=========================================="
    echo "Wrapper generation complete"
    echo "=========================================="
}

MAIN "$@"

