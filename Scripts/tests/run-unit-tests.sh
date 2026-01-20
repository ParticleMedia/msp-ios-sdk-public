#!/bin/bash
set -euo pipefail

# MSP iOS SDK Unit Test Runner
# Usage: ./Scripts/tests/run-unit-tests.sh [scheme] [destination]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

SCHEME="${1:-AllTests}"
DESTINATION="${2:-platform=iOS Simulator,name=iPhone 15}"

echo "============================================"
echo "MSP iOS SDK Unit Test Runner"
echo "============================================"
echo "Scheme: $SCHEME"
echo "Destination: $DESTINATION"
echo "============================================"

cd "$ROOT_DIR"

# Run tests with xcodebuild
xcodebuild test \
    -workspace msp-ios-sdk.xcworkspace \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -resultBundlePath "build/TestResults.xcresult" \
    | xcpretty --color || {
        echo "❌ Tests failed"
        exit 1
    }

echo "✅ All tests passed"
