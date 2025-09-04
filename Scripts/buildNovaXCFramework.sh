#!/bin/bash

# Source shared color library
source "Scripts/lib/colors.sh"

# Usage function
show_usage() {
    color_highlight "═══════════════════════════════════════════════════════════════"
    color_highlight "NovaCore XCFramework Build Script - Usage Instructions"
    color_highlight "═══════════════════════════════════════════════════════════════"
    echo ""
    color_info "Usage:"
    echo "  ./Scripts/buildNovaXCFramework.sh [OPTIONS]"
    echo ""
    color_info "Options:"
    echo "  SKIP_CODE_SIGN=1    Skip code signing (for development/testing)"
    echo "  SKIP_CODE_SIGN=0    Use code signing (default, for production)"
    echo ""
    color_info "Examples:"
    echo "  ./Scripts/buildNovaXCFramework.sh                    # Build with code signing"
    echo "  SKIP_CODE_SIGN=1 ./Scripts/buildNovaXCFramework.sh   # Build without code signing"
    echo ""
    color_info "What this script does:"
    echo "  1. Installs CocoaPods dependencies"
    echo "  2. Builds NovaCore.xcframework for iOS device and simulator"
    echo "  3. Creates universal binary with arm64 and x86_64 architectures"
    echo "  4. Deploys to NovaAdapter/NovaCore.xcframework"
    echo ""
    color_warning "Note: Code signing requires valid iOS Development certificate."
    color_warning "Use SKIP_CODE_SIGN=1 if you don't have signing certificates."
    echo ""
}

# Check for help flag
if [[ "$1" == "-h" || "$1" == "--help" || "$1" == "help" ]]; then
    show_usage
    exit 0
fi

# Default code signing behavior (enabled by default)
SKIP_CODE_SIGN=${SKIP_CODE_SIGN:-0}

# CI environment detection
CI=${CI:-false}
if [ "$CI" = "true" ]; then
    color_warning "🔧 CI environment detected - enabling optimizations"
fi

# Build Configuration Note:
# This script uses ONLY Release configuration for production builds.
# Debug configuration is not used because:
# 1. Release builds are optimized for production (smaller, faster)
# 2. Debug builds can cause runtime performance issues
# 3. Production frameworks should never use Debug configuration
# 4. If Release builds fail, the issue should be fixed rather than worked around

# Enable strict error handling
set -e  # Exit immediately if a command exits with a non-zero status
set -o pipefail  # Exit if any command in a pipeline fails

# Error handling function
handle_error() {
    local exit_code=$?
    local line_number=$1
    echo ""
    color_error "❌ ERROR: Build failed at line $line_number with exit code $exit_code"
    color_error "Last command: $BASH_COMMAND"
    color_warning "Stack trace:"
    local frame=0
    while caller $frame; do
        ((frame++))
    done
    exit $exit_code
}

# Set up error trap
trap 'handle_error $LINENO' ERR

# Function to print section headers
print_section() {
    echo ""
    color_highlight "═══════════════════════════════════════════════════════════════"
    color_highlight "$1"
    color_highlight "═══════════════════════════════════════════════════════════════"
    echo ""
}

# Function to print step information
print_step() {
    color_info "🔧 $1"
}

# Function to print success message
print_success() {
    color_success "✅ $1"
}

# Function to print warning message
print_warning() {
    color_warning "⚠️  $1"
}

# Function to check if command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        color_error "❌ ERROR: $1 command not found"
        exit 1
    fi
}

# Function to check if path exists
check_path() {
    if [[ ! -e "$1" ]]; then
        color_error "❌ ERROR: $1 not found"
        exit 1
    fi
}

# Function to build xcodebuild archive with optional code signing
build_archive() {
    local scheme=$1
    local destination=$2
    local archive_path=$3
    local sdk=$4
    local additional_flags=$5
    
    # CI-specific optimizations
    local ci_flags=""
    if [ "$CI" = "true" ]; then
        color_warning "🔧 CI environment detected - applying build optimizations"
        ci_flags="\
        -derivedDataPath /tmp/NovaCore-DerivedData \
        -parallelizeTargets \
        -jobs 4 \
        -quiet \
        -showBuildTimingSummary \
        SWIFT_OPTIMIZATION_LEVEL=-Onone \
        SWIFT_COMPILATION_MODE=wholemodule \
        GCC_OPTIMIZATION_LEVEL=0"
    fi
    
    local build_command="xcodebuild archive \
        -workspace msp-ios-sdk.xcworkspace \
        -scheme \"$scheme\" \
        -destination=\"$destination\" \
        -archivePath \"$archive_path\" \
        SKIP_INSTALL=NO \
        -configuration Release \
        -sdk \"$sdk\" \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        $ci_flags"
    
    # Add code signing flags if SKIP_CODE_SIGN is enabled
    if [ "$SKIP_CODE_SIGN" = "1" ]; then
        build_command="$build_command \
        CODE_SIGN_IDENTITY=\"\" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO"
    fi
    
    # Add any additional flags
    if [ -n "$additional_flags" ]; then
        build_command="$build_command $additional_flags"
    fi
    
    color_info "Executing: $build_command"
    
    # Execute build command with retry logic for CI
    if [ "$CI" = "true" ]; then
        color_warning "🔧 Attempting CI-optimized build with retries..."
        
        # Try up to 3 times with the same Release configuration
        local attempt=1
        local max_attempts=3
        
        while [ $attempt -le $max_attempts ]; do
            color_info "🔍 Build attempt $attempt/$max_attempts..."
            
            if eval $build_command; then
                color_success "✅ Build succeeded on attempt $attempt"
                return 0
            fi
            
            if [ $attempt -lt $max_attempts ]; then
                color_warning "⚠️  Build attempt $attempt failed, retrying in 5 seconds..."
                sleep 5
            fi
            
            ((attempt++))
        done
        
        color_error "❌ All $max_attempts build attempts failed with Release configuration"
        color_error "❌ This suggests a configuration issue that needs to be fixed"
        return 1
    else
        # Local build - single attempt
        if eval $build_command; then
            return 0
        else
            color_error "❌ Local build failed"
            return 1
        fi
    fi
}

# Main build process
print_section "Starting NovaCore XCFramework Build"

# Ensure we're in the project root directory
print_step "Checking project root directory..."
if [[ ! -d "msp-ios-sdk.xcworkspace" ]]; then
    color_error "❌ ERROR: Please run this script from the project root directory"
    color_error "Current directory: $(pwd)"
    color_error "Expected to find: msp-ios-sdk.xcworkspace"
    exit 1
fi
print_success "Project root directory verified"

# Check required commands
print_step "Checking required commands..."
check_command "xcodebuild"
check_command "pod"
print_success "All required commands are available"

# Check required files
print_step "Checking required project files..."
check_path "Podfile"
print_success "All required project files found"

# Clean previous build artifacts
print_step "Cleaning previous build artifacts..."
rm -rf "$PWD/outputNova/xcframework"
mkdir -p "$PWD/outputNova/xcframework"
print_success "Build directory cleaned and created"

# Install pods
print_section "Installing CocoaPods Dependencies"
print_step "Running pod install..."
if pod install --repo-update; then
    print_success "CocoaPods dependencies installed successfully"
    
    # Check for problematic dependencies in CI
    if [ "$CI" = "true" ]; then
        print_step "Checking for problematic dependencies in CI environment..."
        
        # Check if MarketplaceKit is available (NewsBreak-specific framework)
        if ! find Pods -name "*MarketplaceKit*" -type d >/dev/null 2>&1; then
            color_warning "⚠️  WARNING: MarketplaceKit not found in CI environment"
            color_warning "   This may cause linking issues with GoogleAdapter and FacebookAdapter"
            color_warning "   Consider adding MarketplaceKit.xcframework to CI environment"
        fi
        
        # Check Swift runtime libraries
        if ! find Pods -name "*swiftXPC*" -o -name "*swift_Builtin_float*" >/dev/null 2>&1; then
            color_warning "⚠️  WARNING: Some Swift runtime libraries may be missing"
            color_warning "   This may cause linking issues in CI environment"
        fi
    fi
else
    color_error "❌ ERROR: Failed to install CocoaPods dependencies"
    exit 1
fi

# Build for iOS device
print_section "Building NovaCore for iOS Device"
print_step "Building iOS device archive..."
if build_archive "NovaCore" "iOS" "$PWD/outputNova/xcframework/NovaCore-iOS" "iphoneos"; then
    print_success "iOS device archive created successfully"
else
    color_error "❌ ERROR: Failed to create iOS device archive"
    exit 1
fi

# Verify iOS archive
check_path "$PWD/outputNova/xcframework/NovaCore-iOS.xcarchive/Products/Library/Frameworks/NovaCore.framework"
print_success "iOS device framework verified"

# Build for iOS Simulator
print_section "Building NovaCore for iOS Simulator"
print_step "Building iOS simulator archive with universal binary (arm64 + x86_64)..."
if build_archive "NovaCore" "generic/platform=iOS Simulator" "$PWD/outputNova/xcframework/NovaCore-Simulator" "iphonesimulator" "ONLY_ACTIVE_ARCH=NO VALID_ARCHS=\"arm64 x86_64\" ARCHS=\"arm64 x86_64\" EXCLUDED_ARCHS=\"\""; then
    print_success "iOS simulator archive created successfully"
else
    color_error "❌ ERROR: Failed to create iOS simulator archive"
    exit 1
fi

# Verify simulator archive
check_path "$PWD/outputNova/xcframework/NovaCore-Simulator.xcarchive/Products/Library/Frameworks/NovaCore.framework"
print_success "iOS simulator framework verified"

# Create XCFramework
print_section "Creating NovaCore.xcframework"
print_step "Combining device and simulator frameworks into XCFramework..."
if xcodebuild -create-xcframework \
    -framework "$PWD/outputNova/xcframework/NovaCore-iOS.xcarchive/Products/Library/Frameworks/NovaCore.framework" \
    -framework "$PWD/outputNova/xcframework/NovaCore-Simulator.xcarchive/Products/Library/Frameworks/NovaCore.framework" \
    -output "$PWD/outputNova/xcframework/NovaCore.xcframework"; then
    print_success "NovaCore.xcframework created successfully"
else
    color_error "❌ ERROR: Failed to create NovaCore.xcframework"
    exit 1
fi

# Verify XCFramework
check_path "$PWD/outputNova/xcframework/NovaCore.xcframework"
print_success "NovaCore.xcframework verified"

# Check XCFramework contents
print_step "Verifying XCFramework contents..."
if [ -f "$PWD/outputNova/xcframework/NovaCore.xcframework/Info.plist" ]; then
    color_info "📋 XCFramework Info.plist contents:"
    plutil -p "$PWD/outputNova/xcframework/NovaCore.xcframework/Info.plist" | grep -E "(LibraryIdentifier|SupportedArchitectures)" || true
    print_success "XCFramework structure verified"
else
    color_error "❌ ERROR: XCFramework Info.plist not found"
    exit 1
fi

# Copy to NovaAdapter
print_section "Deploying NovaCore.xcframework to NovaAdapter"
SOURCE_XCFRAMEWORK="$PWD/outputNova/xcframework/NovaCore.xcframework"
DESTINATION_DIR="$PWD/NovaAdapter"

print_step "Removing previous NovaCore.xcframework from NovaAdapter..."
rm -rf "$DESTINATION_DIR/NovaCore.xcframework"

print_step "Copying new NovaCore.xcframework to NovaAdapter..."
if cp -R "$SOURCE_XCFRAMEWORK" "$DESTINATION_DIR/"; then
    print_success "NovaCore.xcframework copied to NovaAdapter successfully"
else
    color_error "❌ ERROR: Failed to copy NovaCore.xcframework to NovaAdapter"
    exit 1
fi

# Verify final deployment
check_path "$DESTINATION_DIR/NovaCore.xcframework"
print_success "Final deployment verified"

# Build summary
print_section "Build Summary"
    color_success "🎉 NovaCore.xcframework build completed successfully!"
    color_info "📁 Output location: $DESTINATION_DIR/NovaCore.xcframework"
    color_info "📅 Completed at: $(date)"

# Show framework size
if command -v du &> /dev/null; then
    framework_size=$(du -sh "$DESTINATION_DIR/NovaCore.xcframework" 2>/dev/null | cut -f1)
    color_info "📦 Framework size: $framework_size"
fi
