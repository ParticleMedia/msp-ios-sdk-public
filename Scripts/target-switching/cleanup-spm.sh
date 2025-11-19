#!/usr/bin/env bash
# ============================================================================
# SwiftPM Environment Cleanup
# ============================================================================
# Purpose: Clean SwiftPM environment and remove all SPM artifacts.
#
# Safety: Only removes untracked SwiftPM artifacts. Never modifies tracked files.
#
# Usage:   ./Scripts/target-switching/cleanup-spm.sh
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
echo "SwiftPM Environment Cleanup"
echo "============================================================================"
echo ""
echo "Repository: $ROOT_DIR"
echo ""

# Safety check
if [[ ! -f "$ROOT_DIR/.git/config" ]] && [[ ! -f "$ROOT_DIR/Podfile" ]]; then
    echo -e "${RED}ERROR: Not in MSP iOS SDK repository. Aborting.${NC}" >&2
    exit 1
fi

# Confirm before proceeding
read -p "Continue with SwiftPM cleanup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Step 1: Removing .swiftpm/ directories..."
SWIFTPM_COUNT=0
while IFS= read -r -d '' dir; do
    if [[ "$dir" == "$ROOT_DIR"* ]]; then
        echo "Removing: ${dir#$ROOT_DIR/}"
        rm -rf "$dir"
        ((SWIFTPM_COUNT++))
    fi
done < <(find "$ROOT_DIR" -type d -name ".swiftpm" ! -path "*/Pods/*" ! -path "*/.git/*" -print0 2>/dev/null || true)

if [[ $SWIFTPM_COUNT -gt 0 ]]; then
    echo -e "${GREEN}✓${NC} Removed $SWIFTPM_COUNT .swiftpm directory/ies"
else
    echo -e "${YELLOW}⚠${NC} No .swiftpm directories found"
fi

echo ""
echo "Step 2: Removing SourcePackages/ directories..."
SOURCEPACKAGES_COUNT=0
while IFS= read -r -d '' dir; do
    if [[ "$dir" == "$ROOT_DIR"* ]]; then
        echo "Removing: ${dir#$ROOT_DIR/}"
        rm -rf "$dir"
        ((SOURCEPACKAGES_COUNT++))
    fi
done < <(find "$ROOT_DIR" -type d -name "SourcePackages" ! -path "*/Pods/*" ! -path "*/.git/*" -print0 2>/dev/null || true)

if [[ $SOURCEPACKAGES_COUNT -gt 0 ]]; then
    echo -e "${GREEN}✓${NC} Removed $SOURCEPACKAGES_COUNT SourcePackages directory/ies"
else
    echo -e "${YELLOW}⚠${NC} No SourcePackages directories found"
fi

echo ""
echo "Step 3: Removing SwiftPM workspaces..."
WORKSPACE_COUNT=0
while IFS= read -r -d '' workspace; do
    if [[ "$workspace" == "$ROOT_DIR"* ]] && \
       [[ "$workspace" != "$ROOT_DIR/msp-ios-sdk.xcworkspace"* ]] && \
       [[ "$workspace" != "$ROOT_DIR/Pods"* ]]; then
        echo "Removing: ${workspace#$ROOT_DIR/}"
        rm -rf "$workspace"
        ((WORKSPACE_COUNT++))
    fi
done < <(find "$ROOT_DIR" -type d -name "*.xcworkspace" ! -path "*/Pods/*" ! -path "*/.git/*" -print0 2>/dev/null || true)

if [[ $WORKSPACE_COUNT -gt 0 ]]; then
    echo -e "${GREEN}✓${NC} Removed $WORKSPACE_COUNT SwiftPM workspace(s)"
else
    echo -e "${YELLOW}⚠${NC} No SwiftPM workspaces found"
fi

echo ""
echo "Step 4: Removing .build/ directories..."
BUILD_COUNT=0
while IFS= read -r -d '' dir; do
    if [[ "$dir" == "$ROOT_DIR"* ]]; then
        echo "Removing: ${dir#$ROOT_DIR/}"
        rm -rf "$dir"
        ((BUILD_COUNT++))
    fi
done < <(find "$ROOT_DIR" -type d -name ".build" ! -path "*/Pods/*" ! -path "*/.git/*" -print0 2>/dev/null || true)

if [[ $BUILD_COUNT -gt 0 ]]; then
    echo -e "${GREEN}✓${NC} Removed $BUILD_COUNT .build directory/ies"
else
    echo -e "${YELLOW}⚠${NC} No .build directories found"
fi

echo ""
echo "Step 5: Cleaning DerivedData..."
DERIVED_DATA_DIR="$HOME/Library/Developer/Xcode/DerivedData"
if [[ -d "$DERIVED_DATA_DIR" ]]; then
    rm -rf "$DERIVED_DATA_DIR"/*
    echo -e "${GREEN}✓${NC} DerivedData cleaned"
else
    echo -e "${YELLOW}⚠${NC} DerivedData directory not found"
fi

echo ""
echo "============================================================================"
echo "Cleanup Complete"
echo "============================================================================"
echo ""
echo -e "${GREEN}✓${NC} SwiftPM environment cleaned"
echo ""

