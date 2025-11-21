#!/bin/bash

# MSPiOSCore XCFramework Build Script
# This script now uses the shared XCFramework builder library

# Source the shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Ensure we're in repo root
cd "$ROOT_DIR" || exit 1

# Source with fallback
if [[ -f "$ROOT_DIR/Scripts/lib/colors.sh" ]]; then
    source "$ROOT_DIR/Scripts/lib/colors.sh"
else
    color_highlight() { echo "== $1 =="; }
    color_info() { echo "INFO: $1"; }
    color_success() { echo "✓ $1"; }
    color_warning() { echo "⚠ $1"; }
    color_error() { echo "✗ $1" >&2; }
fi

if [[ -f "$ROOT_DIR/Scripts/lib/xcframework_builder.sh" ]]; then
    source "$ROOT_DIR/Scripts/lib/xcframework_builder.sh"
else
    color_error "xcframework_builder.sh not found"
    exit 1
fi

# Usage function
show_usage() {
    color_highlight "═══════════════════════════════════════════════════════════════"
    color_highlight "MSPiOSCore XCFramework Build Script - Usage Instructions"
    color_highlight "═══════════════════════════════════════════════════════════════"
    echo ""
    color_info "Usage:"
    echo "  ./Scripts/buildiOSCoreXCFramework.sh [OPTIONS]"
    echo ""
    color_info "Options:"
    echo "  SKIP_CODE_SIGN=1    Skip code signing (for development/testing)"
    echo "  SKIP_CODE_SIGN=0    Use code signing (default, for production)"
    echo ""
    color_info "Examples:"
    echo "  ./Scripts/buildiOSCoreXCFramework.sh                    # Build with code signing"
    echo "  SKIP_CODE_SIGN=1 ./Scripts/buildiOSCoreXCFramework.sh   # Build without code signing"
    echo ""
    color_info "What this script does:"
    echo "  1. Builds MSPiOSCore.xcframework for iOS device and simulator"
    echo "  2. Creates universal binary with arm64 and x86_64 architectures"
    echo "  3. Deploys to MSPSharedLibraries/MSPiOSCore.xcframework"
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

# Enable strict error handling
set -e
set -o pipefail

# Utility functions
ensure_project_root() {
    # Simple function to ensure we're in the right directory
    if [[ ! -f ".git/config" ]] && [[ ! -d "MSPDemoApp" ]] && [[ ! -d "MSPiOSCore" ]]; then
        color_error "❌ ERROR: Not in project root directory"
        color_error "Current directory: $(pwd)"
        color_error "ROOT_DIR: $ROOT_DIR"
        exit 1
    fi
}

# Main build function using shared library
main() {
    echo "🔧 Starting MSPiOSCore XCFramework build"
    
    # Ensure we're in the project root
    ensure_project_root
    
    # Show build configuration
    if [[ "$SKIP_CODE_SIGN" == "1" ]]; then
        color_warning "🔓 Code signing: DISABLED (development mode)"
    else
        color_success "🔒 Code signing: ENABLED (production mode)"
    fi
    
    # Check required commands
    echo "🔧 Checking required commands..."
    if ! command -v xcodebuild &> /dev/null; then
        echo "❌ ERROR: xcodebuild command not found"
        exit 1
    fi
    echo "✅ All required commands are available"
    
    # Check required files - MSPiOSCore can be built from its own project
    echo "🔧 Checking required project files..."
    if [[ ! -d "MSPiOSCore/MSPiOSCore.xcodeproj" ]]; then
        color_error "❌ ERROR: MSPiOSCore project not found"
        exit 1
    fi
    echo "✅ MSPiOSCore project found"
    
    # Clean previous build artifacts
    echo "🔧 Cleaning previous build artifacts..."
    rm -rf "outputMSPiOSCore/xcframework"
    mkdir -p "outputMSPiOSCore/xcframework"
    echo "✅ Build directory cleaned and created"
    
    # Build XCFramework using shared library
    if build_xcframework \
        "MSPiOSCore" \
        "MSPiOSCore" \
        "MSPiOSCore/MSPiOSCore" \
        "outputMSPiOSCore/xcframework" \
        "MSPSharedLibraries" \
        "MSPiOSCore.xcframework"; then
        
        echo "✅ MSPiOSCore XCFramework built successfully"
        
        # Validate the built XCFramework
        if validate_xcframework "MSPSharedLibraries/MSPiOSCore.xcframework" "MSPiOSCore"; then
            echo "✅ MSPiOSCore XCFramework validation passed"
        else
            echo "❌ ERROR: MSPiOSCore XCFramework validation failed"
            exit 1
        fi
        
        # Show build summary
        echo "🔧 Build Summary"
        color_success "🎉 MSPiOSCore.xcframework build completed successfully!"
        color_info "📁 Output location: MSPSharedLibraries/MSPiOSCore.xcframework"
        
        # Show framework size
        if command -v du &> /dev/null; then
            local framework_size=$(du -sh "MSPSharedLibraries/MSPiOSCore.xcframework" 2>/dev/null | cut -f1)
            color_info "📦 Framework size: $framework_size"
        fi
        
        return 0
    else
        echo "❌ ERROR: Failed to build MSPiOSCore XCFramework"
        exit 1
    fi
}

# Execute main function
main "$@"
