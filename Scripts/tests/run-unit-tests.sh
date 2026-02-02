#!/bin/bash
set -euo pipefail

# MSP iOS SDK Unit Test Runner
# Usage: ./Scripts/tests/run-unit-tests.sh [scheme] [destination]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

SCHEME="${1:-AllTests}"
DESTINATION="${2:-platform=iOS Simulator,name=iPhone 15}"

WORKSPACE_PATH=""
PROJECT_PATH=""
if [[ -d "$ROOT_DIR/msp-ios-sdk.xcworkspace" ]]; then
    WORKSPACE_PATH="$ROOT_DIR/msp-ios-sdk.xcworkspace"
elif [[ -d "$ROOT_DIR/.generated/msp-ios-sdk.xcworkspace" ]]; then
    WORKSPACE_PATH="$ROOT_DIR/.generated/msp-ios-sdk.xcworkspace"
elif [[ -d "$ROOT_DIR/Examples/MSPDemoApp/MSPDemoApp.xcodeproj" ]]; then
    PROJECT_PATH="$ROOT_DIR/Examples/MSPDemoApp/MSPDemoApp.xcodeproj"
fi

echo "============================================"
echo "MSP iOS SDK Unit Test Runner"
echo "============================================"
echo "Scheme: $SCHEME"
echo "Destination: $DESTINATION"
if [[ -n "$WORKSPACE_PATH" ]]; then
    echo "Workspace: $WORKSPACE_PATH"
elif [[ -n "$PROJECT_PATH" ]]; then
    echo "Project: $PROJECT_PATH"
else
    echo "Workspace/Project: NOT FOUND"
fi
echo "============================================"

cd "$ROOT_DIR"

if [[ -z "$WORKSPACE_PATH" && -z "$PROJECT_PATH" ]]; then
    echo "❌ No workspace or project found for test execution"
    echo "Hint: Run Scripts/workspace/update.sh to regenerate the workspace"
    exit 1
fi

BUILD_ARGS=(
    test
    -scheme "$SCHEME"
    -destination "$DESTINATION"
    -resultBundlePath "build/TestResults.xcresult"
)

if [[ -n "$WORKSPACE_PATH" ]]; then
    BUILD_ARGS+=(-workspace "$WORKSPACE_PATH")
else
    BUILD_ARGS+=(-project "$PROJECT_PATH")
fi

if command -v xcpretty &>/dev/null; then
    xcodebuild "${BUILD_ARGS[@]}" | xcpretty --color || {
        echo "❌ Tests failed"
        exit 1
    }
else
    xcodebuild "${BUILD_ARGS[@]}" || {
        echo "❌ Tests failed (xcpretty not installed)"
        exit 1
    }
fi

echo "✅ All tests passed"
