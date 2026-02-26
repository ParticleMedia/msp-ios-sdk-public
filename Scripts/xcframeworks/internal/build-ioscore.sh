#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

# MSPiOSCore XCFramework Build Script
# This script now uses the shared XCFramework builder library

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

cd "$ROOT_DIR" || exit 1


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

# R029f: Source xcodegen module for unified generation
if [[ -f "$ROOT_DIR/Scripts/lib/xcodegen.sh" ]]; then
    # shellcheck source=Scripts/lib/xcodegen.sh
    source "$ROOT_DIR/Scripts/lib/xcodegen.sh" 2>/dev/null || true
fi

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
    echo "  3. Deploys to Build/ReleaseArtifacts/XCFrameworks/MSPiOSCore.xcframework"
    echo ""
    color_warning "Note: Code signing requires valid iOS Development certificate."
    color_warning "Use SKIP_CODE_SIGN=1 if you don't have signing certificates."
    echo ""
}

if [[ "$1" == "-h" || "$1" == "--help" || "$1" == "help" ]]; then
    show_usage
    exit 0
fi

SKIP_CODE_SIGN=${SKIP_CODE_SIGN:-0}

CI=${CI:-false}
if [ "$CI" = "true" ]; then
    color_warning "🔧 CI environment detected - enabling optimizations"
fi

set -euo pipefail

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
    
    # Ensure we're in the project root (updated for new structure)
    if [[ ! -f ".git/config" ]] && [[ ! -d "Examples/MSPDemoApp" ]] && [[ ! -d "Sources/Core/MSPiOSCore" ]]; then
        color_error "❌ ERROR: Not in project root directory"
        color_error "Current directory: $(pwd)"
        color_error "ROOT_DIR: $ROOT_DIR"
        exit 1
    fi
    
    if [[ "$SKIP_CODE_SIGN" == "1" ]]; then
        color_warning "🔓 Code signing: DISABLED (development mode)"
    else
        color_success "🔒 Code signing: ENABLED (production mode)"
    fi
    
    echo "🔧 Checking required commands..."
    if ! command -v xcodebuild &> /dev/null; then
        echo "❌ ERROR: xcodebuild command not found"
        exit 1
    fi
    echo "✅ All required commands are available"
    
    echo "🔧 Checking required project files and generating MSPCore project..."

    if ! command -v xcodegen &> /dev/null; then
        color_error "❌ ERROR: xcodegen command not found"
        color_error "Please install XcodeGen: brew install xcodegen"
        exit 1
    fi
    
    MSPCORE_PROJECT_SPEC="$ROOT_DIR/Sources/Core/MSPCore/project.yml"
    if [[ ! -f "$MSPCORE_PROJECT_SPEC" ]]; then
        color_error "❌ ERROR: Sources/Core/MSPCore/project.yml not found"
        color_error "MSPCore migration to XcodeGen requires project.yml"
        exit 1
    fi
    
    echo "🔧 Generating MSPCore.xcodeproj from project.yml..."
    # R029f: Use xcodegen.sh module if available, fallback to direct call
    local mspcore_xcodegen_success=false
    if command -v xcodegen_generate &>/dev/null; then
        if xcodegen_generate "$MSPCORE_PROJECT_SPEC" "$(dirname "$MSPCORE_PROJECT_SPEC")"; then
            mspcore_xcodegen_success=true
        fi
    else
        if xcodegen generate --spec "$MSPCORE_PROJECT_SPEC"; then
            mspcore_xcodegen_success=true
        fi
    fi

    if [[ "$mspcore_xcodegen_success" == "true" ]]; then
        echo "✅ MSPCore.xcodeproj generated successfully from project.yml"
    else
        color_error "❌ ERROR: Failed to generate MSPCore.xcodeproj from project.yml"
        exit 1
    fi
    
    if [[ ! -d "Sources/Core/MSPCore/MSPCore.xcodeproj" ]]; then
        color_error "❌ ERROR: Generated MSPCore.xcodeproj not found"
        color_error "Expected: Sources/Core/MSPCore/MSPCore.xcodeproj"
        exit 1
    fi
    echo "✅ MSPCore project found (generated from project.yml)"
    
    echo "🔧 Cleaning previous build artifacts..."
    rm -rf "Build/Temp/MSPiOSCore/xcframework"
    mkdir -p "Build/Temp/MSPiOSCore/xcframework"
    echo "✅ Build directory cleaned and created"
    
    # Note: MSPCore source builds MSPiOSCore.xcframework (output name differs from source)
    if build_xcframework \
        "MSPCore" \
        "MSPCore" \
        "Sources/Core/MSPCore/MSPCore" \
        "Build/Temp/MSPiOSCore/xcframework" \
        "Build/ReleaseArtifacts/XCFrameworks" \
        "MSPiOSCore.xcframework"; then
        
        echo "✅ MSPiOSCore XCFramework built successfully"
        
        if validate_xcframework "Build/ReleaseArtifacts/XCFrameworks/MSPiOSCore.xcframework" "MSPiOSCore"; then
            echo "✅ MSPiOSCore XCFramework validation passed"
        else
            echo "❌ ERROR: MSPiOSCore XCFramework validation failed"
            exit 1
        fi
        
        echo "🔧 Build Summary"
        color_success "🎉 MSPiOSCore.xcframework build completed successfully!"
        color_info "📁 Output location: Build/ReleaseArtifacts/XCFrameworks/MSPiOSCore.xcframework"
        
        if command -v du &> /dev/null; then
            local framework_size=$(du -sh "Build/ReleaseArtifacts/XCFrameworks/MSPiOSCore.xcframework" 2>/dev/null | cut -f1)
            color_info "📦 Framework size: $framework_size"
        fi
        
        return 0
    else
        echo "❌ ERROR: Failed to build MSPiOSCore XCFramework"
        exit 1
    fi
}

main "$@"
