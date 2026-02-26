#!/usr/bin/env bash
set -euo pipefail

LOG_PREFIX="[regenerate-workspace]"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
UPDATE_SCRIPT="$PROJECT_ROOT/Scripts/workspace/update.sh"

if [ ! -x "$UPDATE_SCRIPT" ]; then
  echo "❌ Workspace update script not found or not executable: $UPDATE_SCRIPT" >&2
  exit 1
fi

if [ ! -d "$PROJECT_ROOT/Pods" ]; then
  echo "❌ Pods directory not found. Run 'pod install' first." >&2
  exit 1
fi

echo "$LOG_PREFIX Regenerating workspace after pod install..."
echo "$LOG_PREFIX This ensures all Pod projects are included in the workspace"

# Run update.sh but skip pod install (since it's already done)
# We set CI="" to skip pod install, but Pods should already exist
echo "$LOG_PREFIX Running update.sh to regenerate workspace..."
if ! CI="" bash "$UPDATE_SCRIPT"; then
  echo "❌ Failed to regenerate workspace" >&2
  exit 1
fi

WORKSPACE_PATH="$PROJECT_ROOT/msp-ios-sdk.xcworkspace"
if [ ! -d "$WORKSPACE_PATH" ]; then
  echo "❌ Workspace not found after regeneration: $WORKSPACE_PATH" >&2
  exit 1
fi

echo "$LOG_PREFIX Verifying workspace contains Pod projects..."
if [ -f "$WORKSPACE_PATH/contents.xcworkspacedata" ]; then
  POD_PROJECTS_COUNT=$(grep -c "Pods/" "$WORKSPACE_PATH/contents.xcworkspacedata" || echo "0")
  echo "$LOG_PREFIX Found $POD_PROJECTS_COUNT Pod project reference(s) in workspace"
  
  # Check for individual Pod projects that should be included
  POD_XCODEPROJ_COUNT=$(find "$PROJECT_ROOT/Pods" -maxdepth 2 -name "*.xcodeproj" -type d 2>/dev/null | wc -l | tr -d ' ')
  echo "$LOG_PREFIX Found $POD_XCODEPROJ_COUNT Pod .xcodeproj directory(ies) in Pods/"
  
  if [ "$POD_PROJECTS_COUNT" -eq 0 ] && [ "$POD_XCODEPROJ_COUNT" -gt 0 ]; then
    echo "⚠️  Warning: Pod projects exist but are not in workspace" >&2
    echo "$LOG_PREFIX This may cause scheme validation to fail" >&2
    echo "$LOG_PREFIX Workspace contents:" >&2
    cat "$WORKSPACE_PATH/contents.xcworkspacedata" >&2 || true
  fi
fi

echo "✅ Workspace regenerated: $WORKSPACE_PATH"
