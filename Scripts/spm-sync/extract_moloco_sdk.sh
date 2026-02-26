#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "[1/3] Extracting MolocoSDKiOS.xcframework"

if [ -d "ThirdParty/MolocoSDKiOS/MolocoSDKiOS.xcframework" ]; then
    echo "✓ MolocoSDKiOS.xcframework already exists"
    exit 0
fi

mkdir -p ThirdParty/MolocoSDKiOS

if [ ! -d "Pods" ]; then
    echo "✗ Pods directory not found. Please run 'pod install' first."
    exit 1
fi

MOLOCO_POD_DIR=$(find Pods -name "MolocoSDKiOS" -type d -maxdepth 2 | head -1)

if [ -z "$MOLOCO_POD_DIR" ]; then
    echo "✗ MolocoSDKiOS not found in Pods"
    echo "Please add MolocoSDKiOS to Podfile and run 'pod install'"
    exit 1
fi

echo "Found: $MOLOCO_POD_DIR"

XCFRAMEWORK=$(find "$MOLOCO_POD_DIR" -name "*.xcframework" -type d | head -1)

if [ -z "$XCFRAMEWORK" ]; then
    echo "✗ No xcframework found in $MOLOCO_POD_DIR"
    exit 1
fi

echo "Copying: $XCFRAMEWORK"
cp -R "$XCFRAMEWORK" ThirdParty/MolocoSDKiOS/

echo "✓ Extracted MolocoSDKiOS.xcframework to ThirdParty/MolocoSDKiOS/"

