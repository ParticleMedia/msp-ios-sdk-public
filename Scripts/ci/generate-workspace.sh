#!/usr/bin/env bash
set -euo pipefail

LOG_PREFIX="[generate-workspace]"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
UPDATE_SCRIPT="$PROJECT_ROOT/Scripts/workspace/update.sh"

if [ ! -x "$UPDATE_SCRIPT" ]; then
  echo "❌ Workspace update script not found or not executable: $UPDATE_SCRIPT" >&2
  exit 1
fi

echo "$LOG_PREFIX Generating workspace and MSPDemoApp project (XcodeGen)..."
# Skip pod install inside update.sh by clearing CI
CI="" bash "$UPDATE_SCRIPT" || echo "⚠️  Workspace generation had warnings, continuing..."

DEMOAPP_DIR="$PROJECT_ROOT/Examples/MSPDemoApp"
DEMOAPP_SPEC="$DEMOAPP_DIR/project.yml"
DEMOAPP_XCODEPROJ="$DEMOAPP_DIR/MSPDemoApp.xcodeproj"

if [ -f "$DEMOAPP_SPEC" ]; then
  echo "$LOG_PREFIX Generating MSPDemoApp.xcodeproj from $DEMOAPP_SPEC..."
  (cd "$DEMOAPP_DIR" && xcodegen generate --spec project.yml) || {
    echo "❌ Failed to generate MSPDemoApp.xcodeproj in $DEMOAPP_DIR" >&2
    exit 1
  }
  if [ ! -d "$DEMOAPP_XCODEPROJ" ]; then
    echo "❌ MSPDemoApp.xcodeproj not found after generation: $DEMOAPP_XCODEPROJ" >&2
    exit 1
  fi
  echo "✅ MSPDemoApp.xcodeproj generated successfully"
else
  echo "⚠️  MSPDemoApp project.yml not found at $DEMOAPP_SPEC; skipping demo app generation"
fi

WORKSPACE_PATH="$PROJECT_ROOT/msp-ios-sdk.xcworkspace"
if [ ! -d "$WORKSPACE_PATH" ]; then
  echo "❌ Workspace not found after generation: $WORKSPACE_PATH" >&2
  exit 1
fi

echo "✅ Workspace generated: $WORKSPACE_PATH"
