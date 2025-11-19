#!/usr/bin/env bash
# ============================================================================
# SwiftPM Cache & Workspace Cleanup Script
# ============================================================================
# Purpose: Resolve Xcode "duplicate GUID" errors by cleaning all SwiftPM
#          caches, DerivedData, and stale workspace artifacts.
#
# Safety: Only cleans SwiftPM/Xcode caches and untracked artifacts.
#         Never modifies tracked git files.
#
# Usage:   ./Scripts/cleanup-swiftpm-caches.sh
# ============================================================================

set -euo pipefail

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=Scripts/lib/paths.sh
source "$ROOT_DIR/Scripts/lib/paths.sh"
# shellcheck source=Scripts/lib/colors.sh
source "$ROOT_DIR/Scripts/lib/colors.sh"

# Initialize paths (note: cleanup-swiftpm-caches.sh is in Scripts/ root, so ROOT_DIR is already correct)
# init_paths would recalculate, so we skip it here

echo "============================================================================"
echo "SwiftPM Cache & Workspace Cleanup"
echo "============================================================================"
echo ""
echo "This script will clean:"
echo "  1. Xcode DerivedData (global)"
echo "  2. SwiftPM global caches"
echo "  3. Local .swiftpm directories"
echo "  4. Hidden SwiftPM workspaces and SourcePackages"
echo ""
echo "Repository: $ROOT_DIR"
echo ""

# Safety check: ensure we're in the correct repo
if [[ ! -f "$ROOT_DIR/.git/config" ]] && [[ ! -f "$ROOT_DIR/Podfile" ]]; then
    echo -e "${RED}ERROR: Not in MSP iOS SDK repository. Aborting.${NC}" >&2
    exit 1
fi

# Confirm before proceeding
read -p "Continue with cleanup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "============================================================================"
echo "Step 1: Cleaning Xcode DerivedData"
echo "============================================================================"

DERIVED_DATA_DIR="$HOME/Library/Developer/Xcode/DerivedData"
if [[ -d "$DERIVED_DATA_DIR" ]]; then
    echo "Removing: $DERIVED_DATA_DIR"
    rm -rf "$DERIVED_DATA_DIR"/*
    echo -e "${GREEN}✓${NC} Xcode DerivedData cleaned"
else
    echo -e "${YELLOW}⚠${NC} DerivedData directory not found (may be first run)"
fi

echo ""
echo "============================================================================"
echo "Step 2: Cleaning SwiftPM Global Caches"
echo "============================================================================"

# SwiftPM cache directory
SWIFTPM_CACHE="$HOME/Library/Caches/org.swift.swiftpm"
if [[ -d "$SWIFTPM_CACHE" ]]; then
    echo "Removing: $SWIFTPM_CACHE"
    rm -rf "$SWIFTPM_CACHE"/*
    echo -e "${GREEN}✓${NC} SwiftPM cache cleaned"
else
    echo -e "${YELLOW}⚠${NC} SwiftPM cache directory not found"
fi

# SwiftPM config directory
SWIFTPM_CONFIG="$HOME/.swiftpm"
if [[ -d "$SWIFTPM_CONFIG" ]]; then
    echo "Removing: $SWIFTPM_CONFIG"
    rm -rf "$SWIFTPM_CONFIG"
    echo -e "${GREEN}✓${NC} SwiftPM config cleaned"
else
    echo -e "${YELLOW}⚠${NC} SwiftPM config directory not found"
fi

echo ""
echo "============================================================================"
echo "Step 3: Cleaning Local .swiftpm Directories"
echo "============================================================================"

# Find and remove all .swiftpm directories within the repo
SWIFTPM_COUNT=0
while IFS= read -r -d '' dir; do
    if [[ "$dir" == "$ROOT_DIR"* ]]; then
        echo "Removing: $dir"
        rm -rf "$dir"
        ((SWIFTPM_COUNT++))
    fi
done < <(find "$ROOT_DIR" -type d -name ".swiftpm" -print0 2>/dev/null || true)

if [[ $SWIFTPM_COUNT -gt 0 ]]; then
    echo -e "${GREEN}✓${NC} Removed $SWIFTPM_COUNT .swiftpm directory/ies"
else
    echo -e "${YELLOW}⚠${NC} No .swiftpm directories found"
fi

echo ""
echo "============================================================================"
echo "Step 4: Cleaning Hidden SwiftPM Workspaces and SourcePackages"
echo "============================================================================"

# Find and remove Package.swift.xcworkspace files
WORKSPACE_COUNT=0
while IFS= read -r -d '' workspace; do
    if [[ "$workspace" == "$ROOT_DIR"* ]]; then
        echo "Removing: $workspace"
        rm -rf "$workspace"
        ((WORKSPACE_COUNT++))
    fi
done < <(find "$ROOT_DIR" -type d -name "Package.swift.xcworkspace" -print0 2>/dev/null || true)

if [[ $WORKSPACE_COUNT -gt 0 ]]; then
    echo -e "${GREEN}✓${NC} Removed $WORKSPACE_COUNT Package.swift.xcworkspace"
else
    echo -e "${YELLOW}⚠${NC} No Package.swift.xcworkspace found"
fi

# Find and remove SourcePackages directories
SOURCEPACKAGES_COUNT=0
while IFS= read -r -d '' dir; do
    if [[ "$dir" == "$ROOT_DIR"* ]]; then
        echo "Removing: $dir"
        rm -rf "$dir"
        ((SOURCEPACKAGES_COUNT++))
    fi
done < <(find "$ROOT_DIR" -type d -name "SourcePackages" -print0 2>/dev/null || true)

if [[ $SOURCEPACKAGES_COUNT -gt 0 ]]; then
    echo -e "${GREEN}✓${NC} Removed $SOURCEPACKAGES_COUNT SourcePackages directory/ies"
else
    echo -e "${YELLOW}⚠${NC} No SourcePackages directories found"
fi

# Find and remove project.xcworkspace under SourcePackages (if any remain)
PROJECT_WORKSPACE_COUNT=0
while IFS= read -r -d '' workspace; do
    if [[ "$workspace" == "$ROOT_DIR"* ]]; then
        echo "Removing: $workspace"
        rm -rf "$workspace"
        ((PROJECT_WORKSPACE_COUNT++))
    fi
done < <(find "$ROOT_DIR" -type d -path "*/SourcePackages/*/project.xcworkspace" -print0 2>/dev/null || true)

if [[ $PROJECT_WORKSPACE_COUNT -gt 0 ]]; then
    echo -e "${GREEN}✓${NC} Removed $PROJECT_WORKSPACE_COUNT project.xcworkspace under SourcePackages"
else
    echo -e "${YELLOW}⚠${NC} No project.xcworkspace under SourcePackages found"
fi

# Also clean .build directories (SwiftPM build artifacts)
BUILD_COUNT=0
while IFS= read -r -d '' dir; do
    if [[ "$dir" == "$ROOT_DIR"* ]]; then
        echo "Removing: $dir"
        rm -rf "$dir"
        ((BUILD_COUNT++))
    fi
done < <(find "$ROOT_DIR" -type d -name ".build" -print0 2>/dev/null || true)

if [[ $BUILD_COUNT -gt 0 ]]; then
    echo -e "${GREEN}✓${NC} Removed $BUILD_COUNT .build directory/ies"
else
    echo -e "${YELLOW}⚠${NC} No .build directories found"
fi

echo ""
echo "============================================================================"
echo "Step 5: Regenerating Workspace"
echo "============================================================================"

# Regenerate workspace using update.sh
UPDATE_SCRIPT="$ROOT_DIR/Scripts/workspace/update.sh"
if [[ -f "$UPDATE_SCRIPT" ]]; then
    echo "Running: Scripts/workspace/update.sh"
    "$UPDATE_SCRIPT"
    echo -e "${GREEN}✓${NC} Workspace regenerated"
else
    echo -e "${YELLOW}⚠${NC} Scripts/workspace/update.sh not found. Skipping workspace regeneration."
fi

echo ""
echo "============================================================================"
echo "Cleanup Complete"
echo "============================================================================"
echo ""
echo -e "${GREEN}✓${NC} All SwiftPM caches and stale artifacts have been removed."
echo ""
echo "Next steps:"
echo "  1. Close Xcode completely (if open)"
echo "  2. Reopen the workspace: msp-ios-sdk.xcworkspace"
echo "  3. Let Xcode resolve packages (File → Packages → Resolve Package Versions)"
echo "  4. Build MSPDemoApp-SPM target"
echo ""
echo "If errors persist, try:"
echo "  - Restart Xcode"
echo "  - Run: xcodebuild -resolvePackageDependencies -workspace msp-ios-sdk.xcworkspace"
echo ""

