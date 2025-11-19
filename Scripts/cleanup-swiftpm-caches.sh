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
# shellcheck source=Scripts/lib/ui.sh
source "$ROOT_DIR/Scripts/lib/ui.sh"

# Initialize paths (note: cleanup-swiftpm-caches.sh is in Scripts/ root, so ROOT_DIR is already correct)
# init_paths would recalculate, so we skip it here

log_title "SwiftPM Cache & Workspace Cleanup"

log_info "This script will clean:"
log_info "  1. Xcode DerivedData (global)"
log_info "  2. SwiftPM global caches"
log_info "  3. Local .swiftpm directories"
log_info "  4. Hidden SwiftPM workspaces and SourcePackages"
log_info ""
log_info "Repository: $ROOT_DIR"

# Safety check: ensure we're in the correct repo
if [[ ! -f "$ROOT_DIR/.git/config" ]] && [[ ! -f "$ROOT_DIR/Podfile" ]]; then
    log_error "Not in MSP iOS SDK repository. Aborting."
    exit 1
fi

# Confirm before proceeding
read -p "Continue with cleanup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Cleanup cancelled."
    exit 0
fi

log_section "Cleaning Xcode DerivedData"
log_step "Cleaning Xcode DerivedData"

DERIVED_DATA_DIR="$HOME/Library/Developer/Xcode/DerivedData"
if [[ -d "$DERIVED_DATA_DIR" ]]; then
    log_info "Removing: $DERIVED_DATA_DIR"
    rm -rf "$DERIVED_DATA_DIR"/*
    log_success "Xcode DerivedData cleaned"
else
    log_warn "DerivedData directory not found (may be first run)"
fi

log_section "Cleaning SwiftPM Global Caches"
log_step "Cleaning SwiftPM global caches"

# SwiftPM cache directory
SWIFTPM_CACHE="$HOME/Library/Caches/org.swift.swiftpm"
if [[ -d "$SWIFTPM_CACHE" ]]; then
    log_info "Removing: $SWIFTPM_CACHE"
    rm -rf "$SWIFTPM_CACHE"/*
    log_success "SwiftPM cache cleaned"
else
    log_warn "SwiftPM cache directory not found"
fi

# SwiftPM config directory
SWIFTPM_CONFIG="$HOME/.swiftpm"
if [[ -d "$SWIFTPM_CONFIG" ]]; then
    log_info "Removing: $SWIFTPM_CONFIG"
    rm -rf "$SWIFTPM_CONFIG"
    log_success "SwiftPM config cleaned"
else
    log_warn "SwiftPM config directory not found"
fi

log_section "Cleaning Local .swiftpm Directories"
log_step "Cleaning local .swiftpm directories"

# Find and remove all .swiftpm directories within the repo
SWIFTPM_COUNT=0
while IFS= read -r -d '' dir; do
    if [[ "$dir" == "$ROOT_DIR"* ]]; then
        log_info "Removing: ${dir#$ROOT_DIR/}"
        rm -rf "$dir"
        ((SWIFTPM_COUNT++))
    fi
done < <(find "$ROOT_DIR" -type d -name ".swiftpm" -print0 2>/dev/null || true)

if [[ $SWIFTPM_COUNT -gt 0 ]]; then
    log_success "Removed $SWIFTPM_COUNT .swiftpm directory/ies"
else
    log_info "No .swiftpm directories found"
fi

log_section "Cleaning Hidden SwiftPM Workspaces and SourcePackages"
log_step "Cleaning hidden SwiftPM workspaces and SourcePackages"

# Find and remove Package.swift.xcworkspace files
WORKSPACE_COUNT=0
while IFS= read -r -d '' workspace; do
    if [[ "$workspace" == "$ROOT_DIR"* ]]; then
        log_info "Removing: ${workspace#$ROOT_DIR/}"
        rm -rf "$workspace"
        ((WORKSPACE_COUNT++))
    fi
done < <(find "$ROOT_DIR" -type d -name "Package.swift.xcworkspace" -print0 2>/dev/null || true)

if [[ $WORKSPACE_COUNT -gt 0 ]]; then
    log_success "Removed $WORKSPACE_COUNT Package.swift.xcworkspace"
else
    log_info "No Package.swift.xcworkspace found"
fi

# Find and remove SourcePackages directories
SOURCEPACKAGES_COUNT=0
while IFS= read -r -d '' dir; do
    if [[ "$dir" == "$ROOT_DIR"* ]]; then
        log_info "Removing: ${dir#$ROOT_DIR/}"
        rm -rf "$dir"
        ((SOURCEPACKAGES_COUNT++))
    fi
done < <(find "$ROOT_DIR" -type d -name "SourcePackages" -print0 2>/dev/null || true)

if [[ $SOURCEPACKAGES_COUNT -gt 0 ]]; then
    log_success "Removed $SOURCEPACKAGES_COUNT SourcePackages directory/ies"
else
    log_info "No SourcePackages directories found"
fi

# Find and remove project.xcworkspace under SourcePackages (if any remain)
PROJECT_WORKSPACE_COUNT=0
while IFS= read -r -d '' workspace; do
    if [[ "$workspace" == "$ROOT_DIR"* ]]; then
        log_info "Removing: ${workspace#$ROOT_DIR/}"
        rm -rf "$workspace"
        ((PROJECT_WORKSPACE_COUNT++))
    fi
done < <(find "$ROOT_DIR" -type d -path "*/SourcePackages/*/project.xcworkspace" -print0 2>/dev/null || true)

if [[ $PROJECT_WORKSPACE_COUNT -gt 0 ]]; then
    log_success "Removed $PROJECT_WORKSPACE_COUNT project.xcworkspace under SourcePackages"
else
    log_info "No project.xcworkspace under SourcePackages found"
fi

# Also clean .build directories (SwiftPM build artifacts)
BUILD_COUNT=0
while IFS= read -r -d '' dir; do
    if [[ "$dir" == "$ROOT_DIR"* ]]; then
        log_info "Removing: ${dir#$ROOT_DIR/}"
        rm -rf "$dir"
        ((BUILD_COUNT++))
    fi
done < <(find "$ROOT_DIR" -type d -name ".build" -print0 2>/dev/null || true)

if [[ $BUILD_COUNT -gt 0 ]]; then
    log_success "Removed $BUILD_COUNT .build directory/ies"
else
    log_info "No .build directories found"
fi

log_section "Regenerating Workspace"
log_step "Regenerating workspace"

# Regenerate workspace using update.sh
UPDATE_SCRIPT="$ROOT_DIR/Scripts/workspace/update.sh"
if [[ -f "$UPDATE_SCRIPT" ]]; then
    log_info "Running: Scripts/workspace/update.sh"
    "$UPDATE_SCRIPT"
    log_success "Workspace regenerated"
else
    log_warn "Scripts/workspace/update.sh not found. Skipping workspace regeneration."
fi

log_title "Cleanup Complete"
log_success "All SwiftPM caches and stale artifacts have been removed."

log_section "Next Steps"
log_info "1. Close Xcode completely (if open)"
log_info "2. Reopen the workspace: msp-ios-sdk.xcworkspace"
log_info "3. Let Xcode resolve packages (File → Packages → Resolve Package Versions)"
log_info "4. Build MSPDemoApp-SPM target"
log_info ""
log_info "If errors persist, try:"
log_info "  - Restart Xcode"
log_info "  - Run: xcodebuild -resolvePackageDependencies -workspace msp-ios-sdk.xcworkspace"

