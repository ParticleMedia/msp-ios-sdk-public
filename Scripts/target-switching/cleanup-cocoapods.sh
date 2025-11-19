#!/usr/bin/env bash
# ============================================================================
# CocoaPods Environment Cleanup
# ============================================================================
# Purpose: Clean CocoaPods environment and reinstall pods.
#
# Safety: Only cleans CocoaPods artifacts and DerivedData.
#
# Usage:   ./Scripts/target-switching/cleanup-cocoapods.sh
# ============================================================================

set -euo pipefail

# Get script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source shared libraries
# shellcheck source=Scripts/lib/paths.sh
source "$ROOT_DIR/Scripts/lib/paths.sh"
# shellcheck source=Scripts/lib/colors.sh
source "$ROOT_DIR/Scripts/lib/colors.sh"

# Initialize paths
init_paths

echo "============================================================================"
echo "CocoaPods Environment Cleanup"
echo "============================================================================"
echo ""
echo "Repository: $ROOT_DIR"
echo ""

# Safety check
if [[ ! -f "$ROOT_DIR/Podfile" ]]; then
    echo -e "${RED}ERROR: Podfile not found. Not a CocoaPods project.${NC}" >&2
    exit 1
fi

echo "Step 1: Deintegrating CocoaPods..."
if command -v bundle &>/dev/null && [[ -f "$ROOT_DIR/Gemfile" ]]; then
    cd "$ROOT_DIR"
    bundle exec pod deintegrate || {
        echo -e "${YELLOW}⚠${NC} pod deintegrate failed (may not be integrated)"
    }
    echo -e "${GREEN}✓${NC} CocoaPods deintegrated"
else
    echo -e "${YELLOW}⚠${NC} bundle not available, skipping deintegrate"
fi

echo ""
echo "Step 2: Cleaning DerivedData..."
DERIVED_DATA_DIR="$HOME/Library/Developer/Xcode/DerivedData"
if [[ -d "$DERIVED_DATA_DIR" ]]; then
    rm -rf "$DERIVED_DATA_DIR"/*
    echo -e "${GREEN}✓${NC} DerivedData cleaned"
else
    echo -e "${YELLOW}⚠${NC} DerivedData directory not found"
fi

echo ""
echo "Step 3: Installing CocoaPods..."
if command -v bundle &>/dev/null && [[ -f "$ROOT_DIR/Gemfile" ]]; then
    cd "$ROOT_DIR"
    bundle exec pod install
    echo -e "${GREEN}✓${NC} CocoaPods installed"
else
    echo -e "${RED}ERROR: bundle not available or Gemfile missing${NC}" >&2
    exit 1
fi

echo ""
echo "============================================================================"
echo "Cleanup Complete"
echo "============================================================================"
echo ""
echo -e "${GREEN}✓${NC} CocoaPods environment cleaned and reinstalled"
echo ""

