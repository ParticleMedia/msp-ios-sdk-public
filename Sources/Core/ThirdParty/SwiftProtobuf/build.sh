#!/bin/bash
# ============================================================================
# SwiftProtobuf XCFramework Builder
# ============================================================================
# Purpose: Build SwiftProtobuf as a standalone XCFramework from Swift Package
# Usage:   cd Sources/Core/ThirdParty/SwiftProtobuf && ./build.sh
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR"
BUILD_DIR="$SCRIPT_DIR/.build"
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Clean previous builds
rm -rf "$OUTPUT_DIR/SwiftProtobuf.xcframework"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cd "$TEMP_DIR"

echo "═══════════════════════════════════════════════════════════"
echo "Building SwiftProtobuf.xcframework"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "Step 1: Cloning SwiftProtobuf repository..."
git clone --depth 1 https://github.com/apple/swift-protobuf.git . 2>&1 | tail -5

echo ""
echo "Step 2: Initializing git submodules..."
git submodule update --init --recursive 2>&1 | tail -5 || echo "  Submodules already initialized or not needed"

echo ""
echo "Step 3: Using xcodebuild with Swift Package..."
SCHEME_NAME="SwiftProtobuf"
echo "  ✅ Using scheme: $SCHEME_NAME (Swift Package)"

echo ""
echo "Step 4: Building for iOS device (arm64)..."
IOS_DERIVED_DATA="$TEMP_DIR/ios_derived"
mkdir -p "$IOS_DERIVED_DATA"
xcodebuild build \
    -scheme SwiftProtobuf \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$IOS_DERIVED_DATA" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    DEFINES_MODULE=YES \
    CLANG_ENABLE_MODULES=YES \
    IPHONEOS_DEPLOYMENT_TARGET=15.0 \
    ONLY_ACTIVE_ARCH=NO \
    2>&1 | tail -15

echo ""
echo "Step 5: Building for iOS Simulator (arm64 + x86_64)..."
SIM_DERIVED_DATA="$TEMP_DIR/sim_derived"
mkdir -p "$SIM_DERIVED_DATA"
xcodebuild build \
    -scheme SwiftProtobuf \
    -configuration Release \
    -destination "generic/platform=iOS Simulator" \
    -derivedDataPath "$SIM_DERIVED_DATA" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    DEFINES_MODULE=YES \
    CLANG_ENABLE_MODULES=YES \
    IPHONEOS_DEPLOYMENT_TARGET=15.0 \
    ONLY_ACTIVE_ARCH=NO \
    2>&1 | tail -15

echo ""
echo "Step 6: Finding Swift modules in DerivedData..."
IOS_MODULE=$(find "$IOS_DERIVED_DATA" -path "*/Build/Products/Release-iphoneos/SwiftProtobuf.swiftmodule" -type d 2>/dev/null | head -1)
SIM_MODULE=$(find "$SIM_DERIVED_DATA" -path "*/Build/Products/Release-iphonesimulator/SwiftProtobuf.swiftmodule" -type d 2>/dev/null | head -1)

IOS_FW=""
SIM_FW=""

# Check if frameworks exist
IOS_FW=$(find "$IOS_DERIVED_DATA" -name "SwiftProtobuf.framework" -type d 2>/dev/null | head -1)
SIM_FW=$(find "$SIM_DERIVED_DATA" -name "SwiftProtobuf.framework" -type d 2>/dev/null | head -1)

# If frameworks not found, create framework structure from Swift modules
if [ -z "$IOS_FW" ] || [ -z "$SIM_FW" ]; then
    echo "  Frameworks not found, creating framework structure from Swift modules..."
    
    if [ -z "$IOS_MODULE" ] || [ -z "$SIM_MODULE" ]; then
        echo "  ❌ ERROR: Could not find frameworks or Swift modules in archives"
        echo "  iOS framework: $([ -n "$IOS_FW" ] && echo "✅ $IOS_FW" || echo "❌ Not found")"
        echo "  Simulator framework: $([ -n "$SIM_FW" ] && echo "✅ $SIM_FW" || echo "❌ Not found")"
        echo "  iOS module: $([ -n "$IOS_MODULE" ] && echo "✅ $IOS_MODULE" || echo "❌ Not found")"
        echo "  Simulator module: $([ -n "$SIM_MODULE" ] && echo "✅ $SIM_MODULE" || echo "❌ Not found")"
        exit 1
    fi
    
    # Create framework structure from Swift module
    echo "  Creating framework structure from Swift modules..."
    IOS_FW_DIR="$TEMP_DIR/ios_framework"
    SIM_FW_DIR="$TEMP_DIR/sim_framework"
    mkdir -p "$IOS_FW_DIR/SwiftProtobuf.framework/Modules"
    mkdir -p "$SIM_FW_DIR/SwiftProtobuf.framework/Modules"
    
    # Copy Swift module
    cp -R "$IOS_MODULE" "$IOS_FW_DIR/SwiftProtobuf.framework/Modules/SwiftProtobuf.swiftmodule"
    cp -R "$SIM_MODULE" "$SIM_FW_DIR/SwiftProtobuf.framework/Modules/SwiftProtobuf.swiftmodule"
    
    # Find .o files and copy them as framework binary
    IOS_O=$(find "$IOS_DERIVED_DATA" -path "*/Build/Products/Release-iphoneos/SwiftProtobuf.o" -type f 2>/dev/null | head -1)
    SIM_O=$(find "$SIM_DERIVED_DATA" -path "*/Build/Products/Release-iphonesimulator/SwiftProtobuf.o" -type f 2>/dev/null | head -1)
    
    if [ -n "$IOS_O" ] && [ -f "$IOS_O" ]; then
        # Copy .o file as framework binary
        cp "$IOS_O" "$IOS_FW_DIR/SwiftProtobuf.framework/SwiftProtobuf"
    else
        echo "  ⚠️  Warning: iOS .o file not found, creating empty binary"
        touch "$IOS_FW_DIR/SwiftProtobuf.framework/SwiftProtobuf"
    fi
    
    if [ -n "$SIM_O" ] && [ -f "$SIM_O" ]; then
        # Copy .o file as framework binary
        cp "$SIM_O" "$SIM_FW_DIR/SwiftProtobuf.framework/SwiftProtobuf"
    else
        echo "  ⚠️  Warning: Simulator .o file not found, creating empty binary"
        touch "$SIM_FW_DIR/SwiftProtobuf.framework/SwiftProtobuf"
    fi
    
    # Create Info.plist
    cat > "$IOS_FW_DIR/SwiftProtobuf.framework/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SwiftProtobuf</string>
    <key>CFBundleIdentifier</key>
    <string>com.apple.SwiftProtobuf</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>SwiftProtobuf</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>15.0</string>
</dict>
</plist>
EOF
    cp "$IOS_FW_DIR/SwiftProtobuf.framework/Info.plist" "$SIM_FW_DIR/SwiftProtobuf.framework/Info.plist"
    
    IOS_FW="$IOS_FW_DIR/SwiftProtobuf.framework"
    SIM_FW="$SIM_FW_DIR/SwiftProtobuf.framework"
    echo "  ✅ Created iOS framework: $IOS_FW"
    echo "  ✅ Created Simulator framework: $SIM_FW"
fi

echo "  ✅ iOS framework: $IOS_FW"
echo "  ✅ Simulator framework: $SIM_FW"

echo ""
echo "Step 7: Creating XCFramework..."
rm -rf "$OUTPUT_DIR/SwiftProtobuf.xcframework"

xcodebuild -create-xcframework \
    -framework "$IOS_FW" \
    -framework "$SIM_FW" \
    -output "$OUTPUT_DIR/SwiftProtobuf.xcframework" \
    2>&1

if [ ! -d "$OUTPUT_DIR/SwiftProtobuf.xcframework" ]; then
    echo "  ❌ ERROR: SwiftProtobuf.xcframework creation failed"
    exit 1
fi

echo ""
echo "✅ XCFramework created successfully!"
echo "  Location: $OUTPUT_DIR/SwiftProtobuf.xcframework"
du -sh "$OUTPUT_DIR/SwiftProtobuf.xcframework"
echo ""
