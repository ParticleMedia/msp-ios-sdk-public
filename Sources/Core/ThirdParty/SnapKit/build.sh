#!/bin/bash
# ============================================================================
# SnapKit XCFramework Builder
# ============================================================================
# Purpose: Build SnapKit as a standalone XCFramework
# Usage:   cd Sources/Core/ThirdParty/SnapKit && ./build.sh
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR"
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

echo "═══════════════════════════════════════════════════════════"
echo "Building SnapKit.xcframework"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "Step 1: Cloning SnapKit repository..."
git clone --depth 1 --branch 5.6.0 https://github.com/SnapKit/SnapKit.git . 2>&1 | tail -5 || \
git clone --depth 1 https://github.com/SnapKit/SnapKit.git . 2>&1 | tail -5

echo ""
echo "Step 2: Building for iOS device (arm64)..."
xcodebuild archive \
    -scheme SnapKit \
    -destination "generic/platform=iOS" \
    -archivePath "$TEMP_DIR/ios.xcarchive" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    SWIFT_VERIFY_EMITTED_MODULE_INTERFACE=NO \
    OTHER_SWIFT_FLAGS="-no-verify-emitted-module-interface" \
    2>&1 | tail -10

echo ""
echo "Step 3: Building for iOS Simulator (arm64 + x86_64)..."
xcodebuild archive \
    -scheme SnapKit \
    -destination "generic/platform=iOS Simulator" \
    -archivePath "$TEMP_DIR/simulator.xcarchive" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    SWIFT_VERIFY_EMITTED_MODULE_INTERFACE=NO \
    OTHER_SWIFT_FLAGS="-no-verify-emitted-module-interface" \
    2>&1 | tail -10

echo ""
echo "Step 4: Finding frameworks in archives..."
IOS_FW=$(find "$TEMP_DIR/ios.xcarchive" -name "SnapKit.framework" -type d 2>/dev/null | head -1)
SIM_FW=$(find "$TEMP_DIR/simulator.xcarchive" -name "SnapKit.framework" -type d 2>/dev/null | head -1)

if [ -z "$IOS_FW" ] || [ -z "$SIM_FW" ]; then
    echo "❌ ERROR: Could not find frameworks in archives"
    echo "  iOS framework: $([ -n "$IOS_FW" ] && echo "✅ $IOS_FW" || echo "❌ Not found")"
    echo "  Simulator framework: $([ -n "$SIM_FW" ] && echo "✅ $SIM_FW" || echo "❌ Not found")"
    exit 1
fi

echo "  ✅ iOS framework: $IOS_FW"
echo "  ✅ Simulator framework: $SIM_FW"

echo ""
echo "Step 5: Creating XCFramework..."
# Remove existing XCFramework if it exists to avoid copy conflicts
rm -rf "$OUTPUT_DIR/SnapKit.xcframework"

xcodebuild -create-xcframework \
    -framework "$IOS_FW" \
    -framework "$SIM_FW" \
    -output "$OUTPUT_DIR/SnapKit.xcframework" \
    2>&1

if [ -d "$OUTPUT_DIR/SnapKit.xcframework" ]; then
    echo ""
    echo "✅ XCFramework created successfully!"
    echo "  Location: $OUTPUT_DIR/SnapKit.xcframework"
    du -sh "$OUTPUT_DIR/SnapKit.xcframework"
    echo ""
    echo "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
    echo "✅ Build complete!"
else
    echo "❌ ERROR: XCFramework creation failed"
    rm -rf "$TEMP_DIR"
    exit 1
fi

