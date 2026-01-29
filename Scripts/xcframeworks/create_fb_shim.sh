#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Create FBAudienceNetwork Shim Framework
# ============================================================================
# Purpose: Create a headers-only framework with custom modulemap (no link directives)
# Usage:   ./Scripts/xcframeworks/create_fb_shim.sh
# ============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC_FW="$ROOT_DIR/Pods/FBAudienceNetwork/Static/FBAudienceNetwork.xcframework/ios-arm64/FBAudienceNetwork.framework"
SHIM_DIR="$ROOT_DIR/Sources/Wrappers/FBAudienceNetworkShim/FBAudienceNetwork.framework"

echo "=== Creating FBAudienceNetwork Shim Framework ==="

# Check source framework exists
if [[ ! -d "$SRC_FW" ]]; then
  echo "ERROR: Source framework not found: $SRC_FW" >&2
  echo "Run 'pod install' first" >&2
  exit 1
fi

# Create shim framework directories
mkdir -p "$SHIM_DIR/Headers"
mkdir -p "$SHIM_DIR/Modules"

# Copy headers
echo "Copying headers from $SRC_FW/Headers..."
cp -R "$SRC_FW/Headers/"* "$SHIM_DIR/Headers/"

# Create custom modulemap (without link directives)
echo "Creating custom module.modulemap (no link directives)..."
cat > "$SHIM_DIR/Modules/module.modulemap" << 'EOF'
framework module FBAudienceNetwork {
    umbrella header "FBAudienceNetwork.h"
    export *
    module * { export * }
    requires objc, blocks
}
EOF

echo "✅ FBAudienceNetwork shim framework created at: $SHIM_DIR"
echo "   - Headers: $(ls "$SHIM_DIR/Headers" | wc -l | xargs) files"
echo "   - module.modulemap: no link directives (prevents auto-linking)"
