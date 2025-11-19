#!/usr/bin/env bash
# ============================================================================
# Build All XCFrameworks
# ============================================================================
# Purpose: Wrapper script to build all wrapper xcframeworks.
#
# Usage:   ./Scripts/target-switching/build-xcframeworks.sh
# ============================================================================

set -euo pipefail

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/lib/paths.sh
source "$ROOT_DIR/Scripts/lib/paths.sh"
# shellcheck source=Scripts/lib/colors.sh
source "$ROOT_DIR/Scripts/lib/colors.sh"

# Initialize paths
init_paths

echo "============================================================================"
echo "Building All XCFrameworks"
echo "============================================================================"
echo ""

# Call the main build-all script
BUILD_SCRIPT="$ROOT_DIR/Scripts/xcframeworks/build-all.sh"

if [[ ! -f "$BUILD_SCRIPT" ]]; then
    echo "ERROR: build-all.sh not found: $BUILD_SCRIPT" >&2
    exit 1
fi

"$BUILD_SCRIPT"

echo ""
echo -e "${GREEN}✓${NC} All xcframeworks built successfully"
echo ""

