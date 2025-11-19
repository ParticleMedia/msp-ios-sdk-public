#!/usr/bin/env bash
# Build All XCFrameworks
# Builds all wrapper xcframeworks and ensures they're fresh
# Usage: ./Scripts/xcframeworks/build-all.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Building All XCFrameworks"
echo "=========================================="
echo ""

# Clean all temporary build directories
echo "Cleaning temporary build directories..."
find "$ROOT_DIR" -type d -name ".build-*-tmp" -exec rm -rf {} + 2>/dev/null || true
echo "✓ Cleaned temporary directories"

# Build all wrappers using generate-wrappers.sh
echo ""
echo "Building all wrapper xcframeworks..."
"$SCRIPT_DIR/generate-wrappers.sh" --all

echo ""
echo "=========================================="
echo "Verifying xcframeworks..."
echo "=========================================="

# Verify all xcframeworks exist
declare -a WRAPPER_NAMES=(
    "ShimmerWrapper"
    "FBAudienceNetworkWrapper"
    "IronSourceSDKWrapper"
    "OpenWrapSDKWrapper"
    "MintegralAdSDKWrapper"
    "MobileFuseSDKWrapper"
    "InMobiSDKWrapper"
)

ERRORS=0
for wrapper in "${WRAPPER_NAMES[@]}"; do
    # Check both temp and final locations
    temp_path="$ROOT_DIR/Scripts/xcframeworks/output-temp/$wrapper/Frameworks"
    final_path="$ROOT_DIR/$wrapper/Frameworks"
    if [[ -d "$temp_path" ]] && [[ -n "$(find "$temp_path" -name "*.xcframework" -type d 2>/dev/null)" ]]; then
        echo "✓ $wrapper: xcframework found (temp)"
    elif [[ -d "$final_path" ]] && [[ -n "$(find "$final_path" -name "*.xcframework" -type d 2>/dev/null)" ]]; then
        echo "✓ $wrapper: xcframework found (final)"
    else
        echo "✗ $wrapper: xcframework missing"
        ((ERRORS++))
    fi
done

if [[ $ERRORS -gt 0 ]]; then
    echo ""
    echo "ERROR: $ERRORS xcframeworks are missing" >&2
    exit 1
fi

echo ""
echo "=========================================="
echo "All xcframeworks built successfully"
echo "=========================================="

