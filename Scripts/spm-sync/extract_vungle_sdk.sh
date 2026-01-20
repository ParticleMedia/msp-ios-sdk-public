#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "[1/3] Extracting VungleAds.xcframework"

# Check if already exists
if [ -d "ThirdParty/VungleAds/VungleAds.xcframework" ]; then
    echo "✓ VungleAds.xcframework already exists"
    exit 0
fi

# Create directory
mkdir -p ThirdParty/VungleAds

# Check if Pods directory exists
if [ ! -d "Pods" ]; then
    echo "✗ Pods directory not found. Please run 'pod install' first."
    exit 1
fi

# Find VungleAds in Pods (note: might be under VungleAds or Vungle-SDK)
VUNGLE_POD_DIR=$(find Pods -name "VungleAds*" -o -name "Vungle-SDK*" -type d -maxdepth 2 | head -1)

if [ -z "$VUNGLE_POD_DIR" ]; then
    echo "✗ VungleAds not found in Pods"
    echo "Please add VungleAds to Podfile and run 'pod install'"
    exit 1
fi

echo "Found: $VUNGLE_POD_DIR"

# Find and copy xcframework
XCFRAMEWORK=$(find "$VUNGLE_POD_DIR" -name "*.xcframework" -type d | head -1)

if [ -z "$XCFRAMEWORK" ]; then
    echo "✗ No xcframework found in $VUNGLE_POD_DIR"
    exit 1
fi

echo "Copying: $XCFRAMEWORK"
cp -R "$XCFRAMEWORK" ThirdParty/VungleAds/

# Rename if needed (ensure it's named VungleAds.xcframework)
COPIED_FRAMEWORK=$(ls ThirdParty/VungleAds/*.xcframework 2>/dev/null | head -1)
if [ -n "$COPIED_FRAMEWORK" ] && [ "$(basename "$COPIED_FRAMEWORK")" != "VungleAds.xcframework" ]; then
    mv "$COPIED_FRAMEWORK" ThirdParty/VungleAds/VungleAds.xcframework
fi

echo "✓ Extracted VungleAds.xcframework to ThirdParty/VungleAds/"

