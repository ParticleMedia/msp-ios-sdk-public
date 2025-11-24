#!/bin/bash
# ============================================================================
# Lottie XCFramework Builder
# ============================================================================
# Purpose: Build Lottie as a standalone XCFramework
# Usage:   cd Sources/Core/ThirdParty/Lottie && ./build.sh
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR"
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

echo "═══════════════════════════════════════════════════════════"
echo "Building Lottie.xcframework"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "Step 1: Cloning Lottie repository..."
git clone --depth 1 --branch 4.4.0 https://github.com/airbnb/lottie-ios.git . 2>&1 | tail -5 || \
git clone --depth 1 https://github.com/airbnb/lottie-ios.git . 2>&1 | tail -5

echo ""
echo "Step 2: Checking project type..."

# Check if it's a Swift Package
if [ -f "Package.swift" ]; then
  echo "  ✅ Detected Swift Package Manager project"
  
  # For SPM projects, we need to generate an Xcode project or use swift build
  # First, try to see if there's a generated .xcodeproj
  if [ -d "Lottie.xcodeproj" ]; then
    PROJECT_FILE="Lottie.xcodeproj"
    echo "  ✅ Found existing Xcode project: $PROJECT_FILE"
  else
    echo "  Generating Xcode project from Package.swift..."
    swift package generate-xcodeproj 2>&1 | tail -5 || {
      echo "  ⚠️  generate-xcodeproj failed, trying alternative method..."
      # Alternative: Use xcodebuild directly with Package.swift
      # This requires Xcode 11+ which supports building SPM packages directly
    }
    
    if [ -d "Lottie.xcodeproj" ]; then
      PROJECT_FILE="Lottie.xcodeproj"
    else
      # Try building directly with SPM
      echo "  Building with Swift Package Manager directly..."
      SCHEME_NAME="Lottie"
      BUILD_METHOD="spm_direct"
    fi
  fi
else
  # Traditional Xcode project
  echo "  ✅ Detected Xcode project"
  PROJECT_FILE=$(find . -maxdepth 2 -name "*.xcodeproj" -type d | head -1)
  if [ -z "$PROJECT_FILE" ]; then
    echo "❌ ERROR: No .xcodeproj found"
    exit 1
  fi
  echo "  Found project: $PROJECT_FILE"
fi

# Determine scheme name
if [ -z "${SCHEME_NAME:-}" ]; then
  if [ -n "${PROJECT_FILE:-}" ]; then
    echo ""
    echo "Step 3: Detecting scheme name..."
    SCHEME_LIST=$(xcodebuild -project "$PROJECT_FILE" -list 2>&1 || xcodebuild -list 2>&1)
    
    # Try to extract scheme from the list
    SCHEME_NAME=$(echo "$SCHEME_LIST" | grep -A 20 "Schemes:" | grep -v "Schemes:" | grep -v "^--" | grep -v "^$" | head -1 | xargs)
    
    # If still not found, try common names
    if [ -z "$SCHEME_NAME" ] || [ "$SCHEME_NAME" = "" ]; then
      for scheme in "Lottie" "lottie-ios" "LottieiOS" "Lottie (iOS)"; do
        if echo "$SCHEME_LIST" | grep -qi "$scheme"; then
          SCHEME_NAME="$scheme"
          break
        fi
      done
    fi
    
    if [ -z "$SCHEME_NAME" ] || [ "$SCHEME_NAME" = "" ]; then
      echo "  Available schemes:"
      echo "$SCHEME_LIST" | grep -A 20 "Schemes:" || echo "$SCHEME_LIST"
      echo ""
      echo "❌ ERROR: Could not detect scheme name"
      echo "Please check the output above and specify the scheme manually"
      exit 1
    fi
    
    echo "  ✅ Using scheme: $SCHEME_NAME"
  else
    # SPM direct build
    SCHEME_NAME="Lottie"
    echo "  ✅ Using SPM scheme: $SCHEME_NAME"
  fi
fi

echo ""
echo "Step 4: Building for iOS device (arm64)..."
if [ "${BUILD_METHOD:-}" = "spm_direct" ]; then
  # Build using SPM directly (Xcode 11+)
  xcodebuild archive \
    -scheme "$SCHEME_NAME" \
    -destination "generic/platform=iOS" \
    -archivePath "$TEMP_DIR/ios.xcarchive" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    SWIFT_VERIFY_EMITTED_MODULE_INTERFACE=NO \
    OTHER_SWIFT_FLAGS="-no-verify-emitted-module-interface" \
    2>&1 | tail -15
else
  xcodebuild archive \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME_NAME" \
    -destination "generic/platform=iOS" \
    -archivePath "$TEMP_DIR/ios.xcarchive" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    SWIFT_VERIFY_EMITTED_MODULE_INTERFACE=NO \
    OTHER_SWIFT_FLAGS="-no-verify-emitted-module-interface" \
    2>&1 | tail -15
fi

echo ""
echo "Step 5: Building for iOS Simulator (arm64 + x86_64)..."
if [ "${BUILD_METHOD:-}" = "spm_direct" ]; then
  xcodebuild archive \
    -scheme "$SCHEME_NAME" \
    -destination "generic/platform=iOS Simulator" \
    -archivePath "$TEMP_DIR/simulator.xcarchive" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    SWIFT_VERIFY_EMITTED_MODULE_INTERFACE=NO \
    OTHER_SWIFT_FLAGS="-no-verify-emitted-module-interface" \
    2>&1 | tail -15
else
  xcodebuild archive \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME_NAME" \
    -destination "generic/platform=iOS Simulator" \
    -archivePath "$TEMP_DIR/simulator.xcarchive" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    SWIFT_VERIFY_EMITTED_MODULE_INTERFACE=NO \
    OTHER_SWIFT_FLAGS="-no-verify-emitted-module-interface" \
    2>&1 | tail -15
fi

echo ""
echo "Step 6: Finding frameworks in archives..."
IOS_FW=$(find "$TEMP_DIR/ios.xcarchive" -name "Lottie.framework" -type d 2>/dev/null | head -1)
SIM_FW=$(find "$TEMP_DIR/simulator.xcarchive" -name "Lottie.framework" -type d 2>/dev/null | head -1)

if [ -z "$IOS_FW" ] || [ -z "$SIM_FW" ]; then
  echo "❌ ERROR: Could not find frameworks in archives"
  echo "  iOS framework: $([ -n "$IOS_FW" ] && echo "✅ $IOS_FW" || echo "❌ Not found")"
  echo "  Simulator framework: $([ -n "$SIM_FW" ] && echo "✅ $SIM_FW" || echo "❌ Not found")"
  echo ""
  echo "Debug: Searching for any frameworks..."
  find "$TEMP_DIR" -name "*.framework" -type d 2>/dev/null | head -10
  exit 1
fi

echo "  ✅ iOS framework: $IOS_FW"
echo "  ✅ Simulator framework: $SIM_FW"

echo ""
echo "Step 7: Creating XCFramework..."
# Remove existing XCFramework if it exists to avoid copy conflicts
rm -rf "$OUTPUT_DIR/Lottie.xcframework"

xcodebuild -create-xcframework \
  -framework "$IOS_FW" \
  -framework "$SIM_FW" \
  -output "$OUTPUT_DIR/Lottie.xcframework" \
  2>&1

if [ -d "$OUTPUT_DIR/Lottie.xcframework" ]; then
  echo ""
  echo "✅ XCFramework created successfully!"
  echo "  Location: $OUTPUT_DIR/Lottie.xcframework"
  du -sh "$OUTPUT_DIR/Lottie.xcframework"
  echo ""
  echo "Cleaning up temporary files..."
  rm -rf "$TEMP_DIR"
  echo "✅ Build complete!"
else
  echo "❌ ERROR: XCFramework creation failed"
  rm -rf "$TEMP_DIR"
  exit 1
fi
