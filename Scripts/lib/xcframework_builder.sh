#!/bin/bash
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

# XCFramework Builder Library for MSP iOS SDK
# This module provides centralized XCFramework building logic

# Source dependencies
source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# XCFramework build constants
XCFRAMEWORK_BUILD_TIMEOUT=1800  # 30 minutes
MAX_BUILD_ATTEMPTS=3

# Build configuration for XCFrameworks
get_xcframework_build_settings() {
    local skip_code_sign="${SKIP_CODE_SIGN:-0}"
    local configuration="${CONFIGURATION:-Release}"
    
    local settings="SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES ONLY_ACTIVE_ARCH=NO CONFIGURATION=$configuration IPHONEOS_DEPLOYMENT_TARGET=${IPHONEOS_DEPLOYMENT_TARGET:-15.0}"
    
    # Add code signing settings
    if [[ "$skip_code_sign" == "1" ]]; then
        settings="$settings CODE_SIGN_IDENTITY= CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO"
    fi
    
    # Add CI-specific optimizations
    if [[ "$CI" == "true" ]]; then
        settings="$settings COMPILER_INDEX_STORE_ENABLE=NO SWIFT_COMPILATION_MODE=wholemodule SWIFT_OPTIMIZATION_LEVEL=-Onone GCC_OPTIMIZATION_LEVEL=0"
    fi
    
    echo "$settings"
}

# Build XCFramework for a specific framework
build_xcframework() {
    local framework_name="$1"
    local scheme="$2"
    local project_path="$3"
    local output_dir="$4"
    local deploy_dir="$5"
    local xcframework_name="$6"
    
    echo "🔧 Building $framework_name XCFramework"
    
    # Validate inputs
    if [[ -z "$framework_name" || -z "$scheme" || -z "$project_path" ]]; then
        echo "❌ ERROR: Missing required parameters for XCFramework build"
        return 1
    fi
    
    # Create output directories and clean existing artifacts
    mkdir -p "$output_dir" "$deploy_dir"
    
    # Clean existing XCFramework if it exists
    if [[ -d "$output_dir/$xcframework_name" ]]; then
        echo "🧹 Cleaning existing XCFramework: $output_dir/$xcframework_name"
        rm -rf "$output_dir/$xcframework_name"
    fi
    
    # Get build settings
    local build_settings=$(get_xcframework_build_settings)
    
    # Build for iOS device
    echo "ℹ️ Building $framework_name for iOS device (arm64)"
    if ! build_for_platform "$project_path" "$scheme" "iphoneos" "arm64" "$build_settings"; then
        echo "❌ ERROR: Failed to build $framework_name for iOS device"
        return 1
    fi
    
    # Build for iOS simulator
    echo "ℹ️ Building $framework_name for iOS simulator (arm64 + x86_64)"
    if ! build_for_platform "$project_path" "$scheme" "iphonesimulator" "arm64 x86_64" "$build_settings"; then
        echo "❌ ERROR: Failed to build $framework_name for iOS simulator"
        return 1
    fi
    
    # Create XCFramework
    echo "ℹ️ Creating $xcframework_name"
    if ! create_xcframework "$project_path" "$scheme" "$output_dir" "$xcframework_name"; then
        echo "❌ ERROR: Failed to create $xcframework_name"
        return 1
    fi
    
    # Deploy to final location
    echo "ℹ️ Deploying $xcframework_name to $deploy_dir"
    if ! deploy_xcframework "$output_dir/$xcframework_name" "$deploy_dir/$xcframework_name"; then
        echo "❌ ERROR: Failed to deploy $xcframework_name"
        return 1
    fi
    
    echo "✅ $framework_name XCFramework built and deployed successfully"
    return 0
}

# Build for specific platform and architecture
build_for_platform() {
    local project_path="$1"
    local scheme="$2"
    local platform="$3"
    local archs="$4"
    local build_settings="$5"
    
    local derived_data_path="/tmp/${scheme}-${platform}-DerivedData"
    local archive_path="/tmp/${scheme}-${platform}.xcarchive"
    
    # Determine build command - prefer workspace if available, otherwise use project
    local build_command
    if [[ -f "msp-ios-sdk.xcworkspace" ]]; then
        build_command="xcodebuild -workspace msp-ios-sdk.xcworkspace"
        echo "🔧 Using main workspace for build"
    elif [[ -f "$project_path.xcworkspace" ]]; then
        build_command="xcodebuild -workspace $project_path.xcworkspace"
    elif [[ -d "$project_path.xcodeproj" ]]; then
        build_command="xcodebuild -project $project_path.xcodeproj"
        echo "🔧 Using project file for build (no workspace needed)"
    else
        echo "❌ ERROR: No workspace or project found at: $project_path"
        return 1
    fi
    
        # Execute build with retry logic
    local attempt=1
    while [[ $attempt -le $MAX_BUILD_ATTEMPTS ]]; do
        echo "🔍 Build attempt $attempt for $scheme on $platform"
        
        if $build_command \
            -scheme "$scheme" \
            -destination "generic/platform=$platform" \
            -archivePath "$archive_path" \
            -derivedDataPath "$derived_data_path" \
            -parallelizeTargets \
            -jobs 4 \
            -quiet \
            $build_settings \
            archive; then
            
            echo "🔍 Build succeeded for $scheme on $platform"
            return 0
        else
            echo "⚠️ Build attempt $attempt failed for $scheme on $platform"
            ((attempt++))
            
            if [[ $attempt -le $MAX_BUILD_ATTEMPTS ]]; then
                echo "ℹ️ Retrying build in 5 seconds..."
                sleep 5
            fi
        fi
    done

echo "❌ ERROR: All build attempts failed for $scheme on $platform"
return 1
}

# Create XCFramework from built products
create_xcframework() {
    local project_path="$1"
    local scheme="$2"
    local output_dir="$3"
    local xcframework_name="$4"
    
    echo "🔍 Creating XCFramework for $scheme..."
    echo "🔍 Project path: $project_path"
    echo "🔍 Output directory: $output_dir"
    echo "🔍 XCFramework name: $xcframework_name"
    
    # Find built frameworks
    echo "🔍 Searching for device framework..."
    local device_framework=$(find_built_framework "$project_path" "$scheme" "iphoneos")
    echo "🔍 Device framework found at: $device_framework"
    
    echo "🔍 Searching for simulator framework..."
    local simulator_framework=$(find_built_framework "$project_path" "$scheme" "iphonesimulator")
    echo "🔍 Simulator framework found at: $simulator_framework"
    
    if [[ -z "$device_framework" || -z "$simulator_framework" ]]; then
        echo "❌ ERROR: Could not find built frameworks for XCFramework creation"
        echo "❌ Device framework: $device_framework"
        echo "❌ Simulator framework: $simulator_framework"
        return 1
    fi
    
    # Verify frameworks exist and are valid
    if [[ ! -d "$device_framework" ]]; then
        echo "❌ ERROR: Device framework not found at: $device_framework"
        return 1
    fi
    
    if [[ ! -d "$simulator_framework" ]]; then
        echo "❌ ERROR: Simulator framework not found at: $simulator_framework"
        return 1
    fi
    
    echo "🔍 Device framework contents:"
    ls -la "$device_framework" || echo "❌ Cannot list device framework contents"
    
    echo "🔍 Simulator framework contents:"
    ls -la "$simulator_framework" || echo "❌ Cannot list simulator framework contents"
    
    # Clean existing XCFramework if it exists
    if [[ -d "$output_dir/$xcframework_name" ]]; then
        echo "🧹 Cleaning existing XCFramework..."
        rm -rf "$output_dir/$xcframework_name"
    fi
    
    # Create output directory
    mkdir -p "$output_dir"
    
    echo "🔍 Creating XCFramework with command:"
    echo "xcodebuild -create-xcframework -framework \"$device_framework\" -framework \"$simulator_framework\" -output \"$output_dir/$xcframework_name\""
    
    # Create XCFramework
    # Handle CI environment path issues by using absolute paths
    local device_framework_abs
    local simulator_framework_abs
    local output_abs
    
    # Try to get absolute paths, with fallback to original paths
    if command -v realpath &> /dev/null; then
        device_framework_abs=$(realpath "$device_framework")
        simulator_framework_abs=$(realpath "$simulator_framework")
        output_abs=$(realpath "$output_dir")
        echo "🔍 Using realpath for absolute paths"
    else
        # Fallback: try to resolve symlinks manually
        device_framework_abs=$(cd "$(dirname "$device_framework")" && pwd)/$(basename "$device_framework")
        simulator_framework_abs=$(cd "$(dirname "$simulator_framework")" && pwd)/$(basename "$simulator_framework")
        output_abs=$(cd "$output_dir" && pwd)
        echo "🔍 Using manual path resolution (realpath not available)"
    fi
    
    echo "🔍 Using absolute paths for XCFramework creation:"
    echo "🔍 Device framework: $device_framework_abs"
    echo "🔍 Simulator framework: $simulator_framework_abs"
    echo "🔍 Output directory: $output_abs"
    
    xcodebuild -create-xcframework \
        -framework "$device_framework_abs" \
        -framework "$simulator_framework_abs" \
        -output "$output_abs/$xcframework_name"
    
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        echo "🔍 XCFramework created successfully: $output_dir/$xcframework_name"
        return 0
    else
        echo "❌ ERROR: Failed to create XCFramework (exit code: $exit_code)"
        return 1
    fi
}

# Find built framework in archive or derived data
find_built_framework() {
    local project_path="$1"
    local scheme="$2"
    local platform="$3"
    
    # First, try to find framework in the archive
    local archive_path="/tmp/${scheme}-${platform}.xcarchive"
    if [[ -d "$archive_path" ]]; then
        local archive_framework="$archive_path/Products/Library/Frameworks/${scheme}.framework"
        if [[ -d "$archive_framework" ]]; then
            echo "🔍 Found framework in archive at: $archive_framework" >&2
            echo "$archive_framework"
            return 0
        fi
    fi
    
    # Fallback: Try multiple possible derived data paths
    local possible_paths=(
        "/tmp/${scheme}-${platform}-DerivedData"
        "/tmp/${scheme}-DerivedData"
        "/tmp/MSPiOSCore-${platform}-DerivedData"
        "/tmp/MSPiOSCore-DerivedData"
        "/tmp/${scheme}-${platform}-DerivedData"
        "/tmp/${scheme}-DerivedData"
    )
    
    for derived_data_path in "${possible_paths[@]}"; do
        if [[ -d "$derived_data_path" ]]; then
            local build_products="$derived_data_path/Build/Products"
            if [[ -d "$build_products" ]]; then
                local framework=$(find "$build_products" -name "*.framework" -type d | head -1)
                if [[ -n "$framework" ]]; then
                    echo "🔍 Found framework at: $framework" >&2
                    echo "$framework"
                    return 0
                fi
            fi
        fi
    done
    
    # If not found in standard locations, try to find it anywhere in /tmp
    echo "🔍 Searching for framework in /tmp directories..." >&2
    local framework=$(find /tmp -name "${scheme}.framework" -type d 2>/dev/null | head -1)
    if [[ -n "$framework" ]]; then
        echo "🔍 Found framework at: $framework" >&2
        return 0
    fi
    
    echo "❌ ERROR: Could not find ${scheme}.framework" >&2
    return 1
}

# Deploy XCFramework to final location
deploy_xcframework() {
    local source="$1"
    local destination="$2"
    
    # Remove existing destination
    if [[ -d "$destination" ]]; then
        rm -rf "$destination"
    fi
    
    # Copy XCFramework
    if cp -R "$source" "$destination"; then
        echo "🔍 XCFramework deployed to: $destination"
        return 0
    else
        echo "❌ ERROR: Failed to deploy XCFramework to: $destination"
        return 1
    fi
}

# Validate XCFramework
validate_xcframework() {
    local xcframework_path="$1"
    local framework_name="$2"
    
    if [[ ! -d "$xcframework_path" ]]; then
        echo "❌ ERROR: $framework_name XCFramework not found at: $xcframework_path"
        return 1
    fi
    
    # Check for required architectures
    local info_plist="$xcframework_path/Info.plist"
    if [[ ! -f "$info_plist" ]]; then
        echo "❌ ERROR: $framework_name XCFramework Info.plist not found"
        return 1
    fi
    
    # Check for supported platforms
    local supported_platforms=$(plutil -extract SupportedPlatforms raw "$info_plist" 2>/dev/null || echo "")
    if [[ -z "$supported_platforms" ]]; then
        echo "⚠️ WARNING: $framework_name XCFramework supported platforms not found"
    else
        echo "🔍 $framework_name XCFramework supports: $supported_platforms"
    fi
    
    echo "✅ $framework_name XCFramework validation passed"
    return 0
}

# Clean build artifacts
clean_xcframework_builds() {
    local scheme="$1"
    
    echo "ℹ️ Cleaning build artifacts for $scheme"
    
    # Clean derived data
    rm -rf "/tmp/${scheme}-iphoneos-DerivedData"
    rm -rf "/tmp/${scheme}-iphonesimulator-DerivedData"
    
    echo "🔍 Build artifacts cleaned for $scheme"
}

# Export functions for use in other scripts
export -f build_xcframework
export -f build_for_platform
export -f create_xcframework
export -f deploy_xcframework
export -f validate_xcframework
export -f clean_xcframework_builds
export -f get_xcframework_build_settings
