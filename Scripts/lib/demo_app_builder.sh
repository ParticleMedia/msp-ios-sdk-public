#!/bin/bash

# Demo App Builder Library
# This script provides reusable functions for building the demo app
# Source this script in other scripts to use these functions

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to detect linking mode based on available artifacts
detect_linking_mode() {
    if [ -d "MSPSharedLibraries/MSPiOSCore.xcframework" ] && [ -d "NovaAdapter/NovaCore.xcframework" ]; then
        echo "framework"
    else
        echo "static"
    fi
}

# Function to build demo app with framework linking
build_demo_app_framework() {
    local destination=${1:-'platform=iOS Simulator,name=iPhone 15'}
    local configuration=${2:-Debug}
    local derived_data_path=${3:-/tmp/MSPDemoApp-DerivedData}
    
    print_status $BLUE "🔧 Building MSPDemoApp with XCFramework linking..."
    
    xcodebuild -workspace msp-ios-sdk.xcworkspace \
               -scheme MSPDemoApp \
               -destination "$destination" \
               -configuration "$configuration" \
               -derivedDataPath "$derived_data_path" \
               -parallelizeTargets \
               -jobs 4 \
               build
    
    if [ $? -eq 0 ]; then
        print_status $GREEN "✅ MSPDemoApp build completed successfully with XCFramework linking"
        return 0
    else
        print_status $RED "❌ MSPDemoApp build failed with XCFramework linking"
        return 1
    fi
}

# Function to build demo app with static library linking
build_demo_app_static() {
    local destination=${1:-'platform=iOS Simulator,name=iPhone 15'}
    local configuration=${2:-Debug}
    local derived_data_path=${3:-/tmp/MSPDemoApp-DerivedData}
    
    print_status $BLUE "🔧 Building MSPDemoApp with static library linking..."
    
    # First, ensure the static libraries are built
    print_status $YELLOW "📱 Building static libraries first..."
    
    # Build MSPCore as static library
    if [ -d "MSPCore" ]; then
        print_status $BLUE "🔨 Building MSPCore static library..."
        xcodebuild -project MSPCore/MSPCore.xcodeproj \
                   -scheme MSPCore \
                   -destination "$destination" \
                   -configuration "$configuration" \
                   -derivedDataPath /tmp/MSPCore-DerivedData \
                   build
    fi
    
    # Build NovaCore as static library
    if [ -d "NovaCore" ]; then
        print_status $BLUE "🔨 Building NovaCore static library..."
        xcodebuild -project NovaCore/NovaCore.xcodeproj \
                   -scheme NovaCore \
                   -destination "$destination" \
                   -configuration "$configuration" \
                   -derivedDataPath /tmp/NovaCore-DerivedData \
                   build
    fi
    
    # Now build the demo app
    print_status $BLUE "📱 Building MSPDemoApp with static libraries..."
    
    xcodebuild -workspace msp-ios-sdk.xcworkspace \
               -scheme MSPDemoApp \
               -destination "$destination" \
               -configuration "$configuration" \
               -derivedDataPath "$derived_data_path" \
               -parallelizeTargets \
               -jobs 4 \
               build
    
    if [ $? -eq 0 ]; then
        print_status $GREEN "✅ MSPDemoApp build completed successfully with static library linking"
        return 0
    else
        print_status $RED "❌ MSPDemoApp build failed with static library linking"
        return 1
    fi
}

# Main function to build demo app with automatic mode detection
build_demo_app() {
    local destination=${1:-'platform=iOS Simulator,name=iPhone 15'}
    local configuration=${2:-Debug}
    local derived_data_path=${3:-/tmp/MSPDemoApp-DerivedData}
    
    print_status $BLUE "🔧 Building MSPDemoApp locally with automatic linking mode detection..."
    
    # Check if we're in the right directory
    if [ ! -d "MSPDemoApp" ]; then
        print_status $RED "❌ Error: MSPDemoApp directory not found. Run this script from the project root."
        return 1
    fi
    
    # Detect linking mode
    local linking_mode=$(detect_linking_mode)
    
    if [ "$linking_mode" = "framework" ]; then
        print_status $GREEN "✅ XCFrameworks found - using framework linking mode"
        build_demo_app_framework "$destination" "$configuration" "$derived_data_path"
    else
        print_status $YELLOW "ℹ️ XCFrameworks not found - using static library linking mode"
        build_demo_app_static "$destination" "$configuration" "$derived_data_path"
    fi
    
    local build_result=$?
    
    if [ $build_result -eq 0 ]; then
        print_status $GREEN "🎉 Demo app build completed successfully!"
    else
        print_status $RED "💥 Demo app build failed!"
    fi
    
    return $build_result
}

# Function to validate demo app structure (useful for CI fallback)
validate_demo_app_structure() {
    print_status $BLUE "🔍 Validating MSPDemoApp structure and dependencies..."
    
    # Check if MSPDemoApp project structure is valid
    if [ -d "MSPDemoApp" ] && [ -f "MSPDemoApp/MSPDemoApp.xcodeproj/project.pbxproj" ]; then
        print_status $GREEN "✅ MSPDemoApp project structure is valid"
    else
        print_status $RED "❌ MSPDemoApp project structure is invalid"
        return 1
    fi
    
    # Check if required files exist
    local required_files=(
        "MSPDemoApp/MSPDemoApp/AppDelegate.swift"
        "MSPDemoApp/MSPDemoApp/Info.plist"
        "MSPDemoApp/MSPDemoApp.xcodeproj/project.pbxproj"
    )
    
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            print_status $GREEN "✅ Found required file: $file"
        else
            print_status $RED "❌ Missing required file: $file"
            return 1
        fi
    done
    
    # Check if XCFrameworks exist (if any)
    if [ -d "MSPSharedLibraries/MSPiOSCore.xcframework" ]; then
        print_status $GREEN "✅ MSPiOSCore.xcframework found"
    else
        print_status $YELLOW "⚠️ MSPiOSCore.xcframework not found"
    fi
    
    if [ -d "NovaAdapter/NovaCore.xcframework" ]; then
        print_status $GREEN "✅ NovaCore.xcframework found"
    else
        print_status $YELLOW "⚠️ NovaCore.xcframework not found"
    fi
    
    print_status $GREEN "✅ MSPDemoApp structure and dependency validation completed successfully"
    return 0
}

# Export functions for use in other scripts
export -f build_demo_app
export -f build_demo_app_framework
export -f build_demo_app_static
export -f validate_demo_app_structure
export -f detect_linking_mode
export -f print_status
