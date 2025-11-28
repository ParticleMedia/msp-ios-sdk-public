#!/bin/bash

# Fix Unicode encoding issues for CocoaPods
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Source shared color library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Ensure we're in repo root
cd "$ROOT_DIR" || exit 1

# Source colors with fallback
if [[ -f "$ROOT_DIR/Scripts/lib/colors.sh" ]]; then
    source "$ROOT_DIR/Scripts/lib/colors.sh"
else
    # Fallback color functions
    color_highlight() { echo "== $1 =="; }
    color_info() { echo "INFO: $1"; }
    color_success() { echo "✓ $1"; }
    color_warning() { echo "⚠ $1"; }
    color_error() { echo "✗ $1" >&2; }
fi

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
set -euo pipefail  # Exit on error, undefined vars, and pipe failures

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

# Function to print info message
print_info() {
    color_info "ℹ️  $1"
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
    local additional_flags="${5:-}"
    
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
    
    # Build with BUILD_LIBRARY_FOR_DISTRIBUTION=YES for NovaCore
    # Disable module interface verification for MSPOMSDK to avoid "underlying Objective-C module not found" errors
    # We pass this as a build setting override for the MSPOMSDK target
    local build_command=""
    if [[ -n "$NOVA_WORKSPACE" ]]; then
        build_command="xcodebuild archive \
            -workspace \"$NOVA_WORKSPACE\" \
            -scheme \"$scheme\" \
            -destination=\"$destination\" \
            -archivePath \"$archive_path\" \
            SKIP_INSTALL=NO \
            -configuration Release \
            -sdk \"$sdk\" \
            BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
            'OTHER_SWIFT_FLAGS[MSPOMSDK]=\$(inherited) -no-verify-emitted-module-interface' \
            $ci_flags"
    elif [[ -n "$NOVA_PROJECT" ]]; then
        build_command="xcodebuild archive \
            -project \"$NOVA_PROJECT\" \
            -scheme \"$scheme\" \
            -destination=\"$destination\" \
            -archivePath \"$archive_path\" \
            SKIP_INSTALL=NO \
            -configuration Release \
            -sdk \"$sdk\" \
            BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
            'OTHER_SWIFT_FLAGS[MSPOMSDK]=\$(inherited) -no-verify-emitted-module-interface' \
            $ci_flags"
    else
        color_error "❌ ERROR: No workspace or project available for build"
        return 1
    fi
    
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

# Ensure we're in the project root directory (already cd'd above)
print_step "Checking project root directory..."
if [[ ! -f ".git/config" ]] && [[ ! -d "MSPDemoApp" ]]; then
    color_error "❌ ERROR: Not in project root directory"
    color_error "Current directory: $(pwd)"
    color_error "ROOT_DIR: $ROOT_DIR"
    exit 1
fi
print_success "Project root directory verified: $ROOT_DIR"

# Check required commands
print_step "Checking required commands..."
check_command "xcodebuild"
# pod command is optional - only needed if Podfile exists and Pods not installed
print_success "All required commands are available"

# Check required files and generate NovaCore project from XcodeGen
print_step "Checking required project files and generating NovaCore project..."

# Check if XcodeGen is available
if ! command -v xcodegen &> /dev/null; then
    color_error "❌ ERROR: xcodegen command not found"
    color_error "Please install XcodeGen: brew install xcodegen"
    exit 1
fi

# Generate NovaCore project from project.yml (XcodeGen-managed)
# Try new structure first (Sources/Core/), fallback to old structure
if [[ -f "$ROOT_DIR/Sources/Core/NovaCore/project.yml" ]]; then
    NOVA_PROJECT_SPEC="$ROOT_DIR/Sources/Core/NovaCore/project.yml"
elif [[ -f "$ROOT_DIR/NovaCore/project.yml" ]]; then
    NOVA_PROJECT_SPEC="$ROOT_DIR/NovaCore/project.yml"
else
    color_error "❌ ERROR: NovaCore/project.yml not found"
    color_error "Checked locations:"
    color_error "  - $ROOT_DIR/Sources/Core/NovaCore/project.yml"
    color_error "  - $ROOT_DIR/NovaCore/project.yml"
    color_error "NovaCore migration to XcodeGen requires project.yml"
    exit 1
fi

print_step "Generating NovaCore.xcodeproj from project.yml..."
# Run xcodegen from the project directory to ensure relative paths resolve correctly
PROJECT_DIR=$(dirname "$NOVA_PROJECT_SPEC")
if (cd "$PROJECT_DIR" && xcodegen generate --spec "$(basename "$NOVA_PROJECT_SPEC")"); then
    print_success "NovaCore.xcodeproj generated successfully from project.yml"
else
    color_error "❌ ERROR: Failed to generate NovaCore.xcodeproj from project.yml"
    exit 1
fi

# Verify generated project exists
NOVA_WORKSPACE=""
NOVA_PROJECT=""

# Determine project location based on project.yml location
if [[ "$NOVA_PROJECT_SPEC" == *"Sources/Core/NovaCore"* ]]; then
    EXPECTED_PROJECT="$ROOT_DIR/Sources/Core/NovaCore/NovaCore.xcodeproj"
else
    EXPECTED_PROJECT="$ROOT_DIR/NovaCore/NovaCore.xcodeproj"
fi

# Check if scheme exists in workspace before using it
# Prefer project if workspace doesn't have the scheme
if [[ -d "$ROOT_DIR/.generated/msp-ios-sdk.xcworkspace" ]]; then
    # Check if NovaCore scheme exists in workspace
    if xcodebuild -workspace "$ROOT_DIR/.generated/msp-ios-sdk.xcworkspace" -list 2>/dev/null | grep -qE "^\s*NovaCore\s*$"; then
        NOVA_WORKSPACE="$ROOT_DIR/.generated/msp-ios-sdk.xcworkspace"
        print_success "Workspace found with NovaCore scheme: .generated/msp-ios-sdk.xcworkspace (will use for build)"
    elif [[ -d "$EXPECTED_PROJECT" ]]; then
        NOVA_PROJECT="$EXPECTED_PROJECT"
        print_success "NovaCore project found: $EXPECTED_PROJECT (workspace doesn't have NovaCore scheme, using project)"
    else
        color_error "❌ ERROR: Generated NovaCore.xcodeproj not found"
        color_error "Expected: $EXPECTED_PROJECT"
        exit 1
    fi
elif [[ -d "$ROOT_DIR/msp-ios-sdk.xcworkspace" ]]; then
    # Check if NovaCore scheme exists in workspace
    if xcodebuild -workspace "$ROOT_DIR/msp-ios-sdk.xcworkspace" -list 2>/dev/null | grep -qE "^\s*NovaCore\s*$"; then
        NOVA_WORKSPACE="$ROOT_DIR/msp-ios-sdk.xcworkspace"
        print_success "Workspace found with NovaCore scheme: msp-ios-sdk.xcworkspace (will use for build)"
    elif [[ -d "$EXPECTED_PROJECT" ]]; then
        NOVA_PROJECT="$EXPECTED_PROJECT"
        print_success "NovaCore project found: $EXPECTED_PROJECT (workspace doesn't have NovaCore scheme, using project)"
    else
        color_error "❌ ERROR: Generated NovaCore.xcodeproj not found"
        color_error "Expected: $EXPECTED_PROJECT"
        exit 1
    fi
elif [[ -d "$EXPECTED_PROJECT" ]]; then
    NOVA_PROJECT="$EXPECTED_PROJECT"
    print_success "NovaCore project found: $EXPECTED_PROJECT (generated from project.yml)"
else
    color_error "❌ ERROR: Generated NovaCore.xcodeproj not found"
    color_error "Expected: $EXPECTED_PROJECT"
    exit 1
fi

# Clean previous build artifacts
print_step "Cleaning previous build artifacts..."
rm -rf "$PWD/Build/Temp/NovaCore/xcframework"
mkdir -p "$PWD/Build/Temp/NovaCore/xcframework"
print_success "Build directory cleaned and created"

# NovaCore doesn't use Pods - it uses XCFramework integration
# Only install Pods if we're using the workspace AND it requires Pods
# But since NovaCore can be built from its own project, skip Pods installation
if [[ -n "$NOVA_WORKSPACE" ]] && [[ -f "$ROOT_DIR/Podfile" ]] && [[ ! -d "$ROOT_DIR/Pods" ]]; then
    print_section "Installing CocoaPods Dependencies"
    print_step "Workspace requires Pods - installing dependencies (NovaCore doesn't need them)..."

# Try multiple strategies for CocoaPods installation
install_cocoapods_with_retry() {
    local max_attempts=3
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        print_step "Attempt $attempt/$max_attempts: Installing CocoaPods dependencies..."
        
        if bundle exec pod install --repo-update; then
            print_success "CocoaPods dependencies installed successfully"
            return 0
        else
            print_warning "CocoaPods installation failed (attempt $attempt/$max_attempts)"
            
            if [[ $attempt -lt $max_attempts ]]; then
                # Try troubleshooting strategies
                print_step "Applying troubleshooting strategies..."
                
                # Strategy 1: Clean cache
                if bundle exec pod cache clean --all >/dev/null 2>&1; then
                    print_info "Cache cleaned successfully"
                fi
                
                # Strategy 2: Try without repo update
                if [[ $attempt -eq 2 ]]; then
                    print_step "Trying without repository update..."
                    if bundle exec pod install --no-repo-update; then
                        print_success "CocoaPods dependencies installed without repo update"
                        return 0
                    fi
                fi
                
                # Strategy 3: Try with alternative sources
                if [[ $attempt -eq 3 ]]; then
                    print_step "Trying with alternative sources..."
                    if try_alternative_sources; then
                        print_success "CocoaPods dependencies installed with alternative sources"
                        return 0
                    fi
                fi
                
                local delay=$((attempt * 5))
                print_info "Retrying in ${delay} seconds..."
                sleep $delay
            fi
        fi
        
        ((attempt++))
    done
    
    color_error "Failed to install CocoaPods dependencies after $max_attempts attempts"
    return 1
}

# Try alternative CocoaPods sources
try_alternative_sources() {
    # Create a temporary Podfile with alternative sources
    local temp_podfile="Podfile.temp"
    local original_podfile="Podfile"
    
    if [[ -f "$original_podfile" ]]; then
        # Create fallback Podfile with alternative sources (GitHub as primary backup)
        cat > "$temp_podfile" << 'EOF'
# Fallback Podfile with alternative sources
# Primary backup: GitHub CocoaPods Specs repository
source 'https://github.com/CocoaPods/Specs.git'
# Secondary backup: CDN
source 'https://cdn.cocoapods.org/'

# Use the original Podfile content but with fallback sources
EOF
        
        # Append original Podfile content (excluding source lines)
        grep -v "^source " "$original_podfile" >> "$temp_podfile"
        
        print_info "Trying CocoaPods installation with GitHub source as backup..."
        
        # Try to install with fallback Podfile
        if bundle exec pod install --podfile="$temp_podfile" --no-repo-update; then
            # Replace original with working fallback
            mv "$temp_podfile" "$original_podfile"
            print_success "CocoaPods installation succeeded using GitHub source backup"
            return 0
        else
            print_warning "GitHub source backup also failed, trying CDN fallback..."
            
            # Try with CDN only as last resort
            cat > "$temp_podfile" << 'EOF'
# Last resort Podfile with CDN source only
source 'https://cdn.cocoapods.org/'

# Use the original Podfile content but with CDN source
EOF
            grep -v "^source " "$original_podfile" >> "$temp_podfile"
            
            if bundle exec pod install --podfile="$temp_podfile" --no-repo-update; then
                mv "$temp_podfile" "$original_podfile"
                print_success "CocoaPods installation succeeded using CDN fallback"
                return 0
            else
                # Clean up
                rm -f "$temp_podfile"
            fi
        fi
    fi
    
    return 1
}

    # Execute the installation
    if install_cocoapods_with_retry; then
        print_success "CocoaPods installation completed successfully"
    else
        color_warning "CocoaPods installation failed, but continuing (workspace may already be set up)"
    fi
else
    print_info "Pods already installed or not needed (SPM mode)"
fi

# Check for problematic dependencies in CI
if [ "$CI" = "true" ]; then
    print_step "Checking for problematic dependencies in CI environment..."
    
    # Check if MarketplaceKit is available (NewsBreak-specific framework)
    if ! find Pods -name "*MarketplaceKit*" -type d >/dev/null 2>&1; then
        color_warning "⚠️  WARNING: MarketplaceKit not found in CI environment"
        color_warning "   This may cause linking issues with MSPGoogleAdapter and MSPFacebookAdapter"
        color_warning "   Consider adding MarketplaceKit.xcframework to CI environment"
    fi
    
    # Check Swift runtime libraries
    if ! find Pods -name "*swiftXPC*" -o -name "*swift_Builtin_float*" >/dev/null 2>&1; then
        color_warning "⚠️  WARNING: Some Swift runtime libraries may be missing"
        color_warning "   This may cause linking issues in CI environment"
    fi
fi

# Synchronize assets
print_section "Synchronizing Assets"
print_step "Synchronizing assets from NBAssets.xcassets to NBResourceBundle.bundle..."
if "$ROOT_DIR/Scripts/lib/asset_sync.sh"; then
    print_success "Assets synchronized successfully"
else
    color_error "❌ ERROR: Failed to synchronize assets"
    exit 1
fi

# Validate asset synchronization
print_step "Validating asset synchronization..."
if "$ROOT_DIR/Scripts/lib/asset_validation.sh" --quiet; then
    print_success "Asset validation passed - all assets are synchronized"
else
    color_error "❌ ERROR: Asset validation failed - assets are out of sync"
    color_error "Please run '$ROOT_DIR/Scripts/lib/asset_sync.sh' to fix asset synchronization"
    exit 1
fi

# NovaCore project has Pods references and REQUIRES Pods dependencies
# When building in Pods mode, Pods should already be installed
# This section ensures Pods are available for NovaCore build
if [[ -n "$NOVA_PROJECT" ]]; then
    if [[ ! -d "$ROOT_DIR/Pods" ]]; then
        color_error "❌ ERROR: Pods directory not found"
        color_error "NovaCore requires Pods dependencies (Kingfisher, SnapKit, Shimmer, lottie-ios, MSPOMSDK)"
        color_error "Please run 'pod install' first, or switch to Pods mode:"
        color_error "  ./Scripts/switch-target.sh pods-dev"
        exit 1
    fi
    
    # Verify Pods structure exists for NovaCore
    if [[ ! -d "$ROOT_DIR/Pods/Target Support Files/Pods-NovaCore" ]]; then
        color_warning "⚠️  Pods-NovaCore target support files not found"
        color_warning "This may indicate pod install did not complete successfully"
        color_warning "Try running: bundle exec pod install"
    fi
fi

# Build for iOS device
print_section "Building NovaCore for iOS Device"
print_step "Building iOS device archive..."
if build_archive "NovaCore" "iOS" "$PWD/Build/Temp/NovaCore/xcframework/NovaCore-iOS" "iphoneos"; then
    print_success "iOS device archive created successfully"
else
    color_error "❌ ERROR: Failed to create iOS device archive"
    exit 1
fi

# Verify iOS archive
check_path "$PWD/Build/Temp/NovaCore/xcframework/NovaCore-iOS.xcarchive/Products/Library/Frameworks/NovaCore.framework"
print_success "iOS device framework verified"

# Build for iOS Simulator
print_section "Building NovaCore for iOS Simulator"
print_step "Building iOS simulator archive with universal binary (arm64 + x86_64)..."
if build_archive "NovaCore" "generic/platform=iOS Simulator" "$PWD/Build/Temp/NovaCore/xcframework/NovaCore-Simulator" "iphonesimulator" "ONLY_ACTIVE_ARCH=NO VALID_ARCHS=\"arm64 x86_64\" ARCHS=\"arm64 x86_64\" EXCLUDED_ARCHS=\"\""; then
    print_success "iOS simulator archive created successfully"
else
    color_error "❌ ERROR: Failed to create iOS simulator archive"
    exit 1
fi

# Verify simulator archive
check_path "$PWD/Build/Temp/NovaCore/xcframework/NovaCore-Simulator.xcarchive/Products/Library/Frameworks/NovaCore.framework"
print_success "iOS simulator framework verified"

# Create XCFramework
print_section "Creating NovaCore.xcframework"
print_step "Combining device and simulator frameworks into XCFramework..."
if xcodebuild -create-xcframework \
    -framework "$PWD/Build/Temp/NovaCore/xcframework/NovaCore-iOS.xcarchive/Products/Library/Frameworks/NovaCore.framework" \
    -framework "$PWD/Build/Temp/NovaCore/xcframework/NovaCore-Simulator.xcarchive/Products/Library/Frameworks/NovaCore.framework" \
    -output "$PWD/Build/Temp/NovaCore/xcframework/NovaCore.xcframework"; then
    print_success "NovaCore.xcframework created successfully"
else
    color_error "❌ ERROR: Failed to create NovaCore.xcframework"
    exit 1
fi

# Verify XCFramework
check_path "$PWD/Build/Temp/NovaCore/xcframework/NovaCore.xcframework"
print_success "NovaCore.xcframework verified"

# Check XCFramework contents
print_step "Verifying XCFramework contents..."
if [ -f "$PWD/Build/Temp/NovaCore/xcframework/NovaCore.xcframework/Info.plist" ]; then
    color_info "📋 XCFramework Info.plist contents:"
    plutil -p "$PWD/Build/Temp/NovaCore/xcframework/NovaCore.xcframework/Info.plist" | grep -E "(LibraryIdentifier|SupportedArchitectures)" || true
    print_success "XCFramework structure verified"
else
    color_error "❌ ERROR: XCFramework Info.plist not found"
    exit 1
fi

# Copy to NovaAdapter
print_section "Deploying NovaCore.xcframework to NovaAdapter"
SOURCE_XCFRAMEWORK="$PWD/Build/Temp/NovaCore/xcframework/NovaCore.xcframework"
DESTINATION_DIR="$PWD/NovaAdapter"
DESTINATION_XCFRAMEWORK="$DESTINATION_DIR/NovaCore.xcframework"
TEMP_XCFRAMEWORK="$DESTINATION_DIR/NovaCore.xcframework.tmp"

print_step "Copying new NovaCore.xcframework to temporary location..."
if [[ -d "$DESTINATION_XCFRAMEWORK" ]]; then
    # Backup existing XCFramework before atomic replacement
    mv "$DESTINATION_XCFRAMEWORK" "$TEMP_XCFRAMEWORK.backup" 2>/dev/null || true
fi

if cp -R "$SOURCE_XCFRAMEWORK" "$TEMP_XCFRAMEWORK"; then
    # Atomic move: replace old XCFramework with new one
    mv "$TEMP_XCFRAMEWORK" "$DESTINATION_XCFRAMEWORK"
    rm -rf "$TEMP_XCFRAMEWORK.backup" 2>/dev/null || true
    print_success "NovaCore.xcframework copied to NovaAdapter successfully"
else
    color_error "❌ ERROR: Failed to copy NovaCore.xcframework to NovaAdapter"
    # Restore backup if copy failed
    mv "$TEMP_XCFRAMEWORK.backup" "$DESTINATION_XCFRAMEWORK" 2>/dev/null || true
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
