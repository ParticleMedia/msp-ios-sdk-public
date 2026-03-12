#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch M, shared) ---
# shellcheck source=/dev/null
_msp_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$_msp_root" ] && [ -f "$_msp_root/Scripts/lib/worktree_guard.sh" ]; then
  . "$_msp_root/Scripts/lib/worktree_guard.sh"
  msp_enforce_main_repo_or_exit
fi
unset _msp_root
# --- End MSP Worktree Safety Guard (Patch M, shared) ---
# ============================================================================
# SwiftPM Environment Cleanup (Hardened Version)
# ============================================================================
# Purpose: Comprehensively remove ALL SwiftPM artifacts to ensure clean
#          Pods-only mode without any SPM side effects.
#
# This script removes:
#   - Package.resolved (root, inside workspaces, inside projects)
#   - .swiftpm directories (everywhere)
#   - swiftpm directories inside xcshareddata and xcuserdata
#   - SourcePackages directories
#   - .build directories
#   - DerivedData cache
#
# Safety:
#   - Never deletes Build/ReleaseArtifacts/XCFrameworks/ or ThirdParty/
#   - Never deletes Sources/
#   - Never modifies Package.swift (that's handled by switch-target.sh)
#
# Usage:   ./Scripts/target-switching/cleanup_spm.sh [--force]
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/target-switching/common.sh
source "$SCRIPT_DIR/common.sh"

ensure_repo_root

FORCE="${1:-}"

if [[ "$FORCE" != "--force" ]]; then
    read -p "Continue with SwiftPM cleanup? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log::info "TARGET" "Cleanup cancelled."
        exit 0
    fi
fi

log_title "SwiftPM Environment Cleanup"

# Safety info
log::info "TARGET" "Protected directories (will NOT be deleted):"
log::info "TARGET" "  - Build/ReleaseArtifacts/XCFrameworks/"
log::info "TARGET" "  - ThirdParty/"
log::info "TARGET" "  - Sources/"

# ============================================================================
# Step 1: Remove ALL Package.resolved files
# ============================================================================
log_section "Removing Package.resolved Files"
log::step "TARGET" "Scanning for Package.resolved files"
PACKAGE_RESOLVED_COUNT=0

# Remove root Package.resolved
if [[ -f "$ROOT_DIR/Package.resolved" ]]; then
    rm -f "$ROOT_DIR/Package.resolved"
    ((PACKAGE_RESOLVED_COUNT++)) || true
    log::info "TARGET" "Removed: Package.resolved (root)"
fi

# Remove Package.resolved from inside workspaces
while IFS= read -r -d '' resolved_file; do
    if [[ -f "$resolved_file" ]]; then
        log::info "TARGET" "Removing: ${resolved_file#$ROOT_DIR/}"
        rm -f "$resolved_file"
        ((PACKAGE_RESOLVED_COUNT++)) || true
    fi
done < <(find "$ROOT_DIR" -path "*.xcworkspace/*/Package.resolved" -type f ! -path "*/Pods/*" -print0 2>/dev/null || true)

# Remove Package.resolved from inside .xcodeproj bundles
while IFS= read -r -d '' resolved_file; do
    if [[ -f "$resolved_file" ]]; then
        log::info "TARGET" "Removing: ${resolved_file#$ROOT_DIR/}"
        rm -f "$resolved_file"
        ((PACKAGE_RESOLVED_COUNT++)) || true
    fi
done < <(find "$ROOT_DIR" -path "*.xcodeproj/*/Package.resolved" -type f ! -path "*/Pods/*" -print0 2>/dev/null || true)

if [[ $PACKAGE_RESOLVED_COUNT -gt 0 ]]; then
    log::success "TARGET" "Removed $PACKAGE_RESOLVED_COUNT Package.resolved file(s)"
else
    log::info "TARGET" "No Package.resolved files found"
fi

# ============================================================================
# Step 2: Remove ALL .swiftpm directories
# ============================================================================
log_section "Removing .swiftpm Directories"
log::step "TARGET" "Scanning for .swiftpm directories"
SWIFTPM_COUNT=0

# Remove .swiftpm directories everywhere
while IFS= read -r -d '' dir; do
    if [[ "$dir" == "$ROOT_DIR"* ]] && [[ -d "$dir" ]]; then
        log::info "TARGET" "Removing: ${dir#$ROOT_DIR/}"
        rm -rf "$dir"
        ((SWIFTPM_COUNT++)) || true
    fi
done < <(find "$ROOT_DIR" -type d -name ".swiftpm" ! -path "*/Pods/*" ! -path "*/.git/*" -print0 2>/dev/null || true)

if [[ $SWIFTPM_COUNT -gt 0 ]]; then
    log::success "TARGET" "Removed $SWIFTPM_COUNT .swiftpm directory/ies"
else
    log::info "TARGET" "No .swiftpm directories found"
fi

# ============================================================================
# Step 3: Remove swiftpm directories inside xcshareddata and xcuserdata
# ============================================================================
log_section "Removing Xcode SPM Caches"
log::step "TARGET" "Scanning for swiftpm directories inside Xcode bundles"
XCODE_SPM_COUNT=0

# Remove */xcshareddata/swiftpm/
while IFS= read -r -d '' dir; do
    if [[ "$dir" == "$ROOT_DIR"* ]] && [[ -d "$dir" ]]; then
        log::info "TARGET" "Removing: ${dir#$ROOT_DIR/}"
        rm -rf "$dir"
        ((XCODE_SPM_COUNT++)) || true
    fi
done < <(find "$ROOT_DIR" -type d -path "*/xcshareddata/swiftpm" ! -path "*/Pods/*" -print0 2>/dev/null || true)

# Remove */xcuserdata/*/swiftpm/
while IFS= read -r -d '' dir; do
    if [[ "$dir" == "$ROOT_DIR"* ]] && [[ -d "$dir" ]]; then
        log::info "TARGET" "Removing: ${dir#$ROOT_DIR/}"
        rm -rf "$dir"
        ((XCODE_SPM_COUNT++)) || true
    fi
done < <(find "$ROOT_DIR" -type d -path "*/xcuserdata/*/swiftpm" ! -path "*/Pods/*" -print0 2>/dev/null || true)

# Remove swiftpm directories inside .xcodeproj/project.xcworkspace/
while IFS= read -r -d '' dir; do
    if [[ "$dir" == "$ROOT_DIR"* ]] && [[ -d "$dir" ]]; then
        log::info "TARGET" "Removing: ${dir#$ROOT_DIR/}"
        rm -rf "$dir"
        ((XCODE_SPM_COUNT++)) || true
    fi
done < <(find "$ROOT_DIR" -type d -name "swiftpm" -path "*/.xcodeproj/*" ! -path "*/Pods/*" -print0 2>/dev/null || true)

if [[ $XCODE_SPM_COUNT -gt 0 ]]; then
    log::success "TARGET" "Removed $XCODE_SPM_COUNT Xcode SPM cache directory/ies"
else
    log::info "TARGET" "No Xcode SPM caches found"
fi

# ============================================================================
# Step 4: Remove SourcePackages directories
# ============================================================================
log_section "Removing SourcePackages Directories"
log::step "TARGET" "Scanning for SourcePackages directories"
SOURCEPACKAGES_COUNT=0

while IFS= read -r -d '' dir; do
    if [[ "$dir" == "$ROOT_DIR"* ]] && [[ -d "$dir" ]]; then
        log::info "TARGET" "Removing: ${dir#$ROOT_DIR/}"
        rm -rf "$dir"
        ((SOURCEPACKAGES_COUNT++)) || true
    fi
done < <(find "$ROOT_DIR" -type d -name "SourcePackages" ! -path "*/Pods/*" ! -path "*/.git/*" -print0 2>/dev/null || true)

if [[ $SOURCEPACKAGES_COUNT -gt 0 ]]; then
    log::success "TARGET" "Removed $SOURCEPACKAGES_COUNT SourcePackages directory/ies"
else
    log::info "TARGET" "No SourcePackages directories found"
fi

# ============================================================================
# Step 5: Remove .build directories
# ============================================================================
log_section "Removing .build Directories"
log::step "TARGET" "Scanning for .build directories"
BUILD_COUNT=0

while IFS= read -r -d '' dir; do
    if [[ "$dir" == "$ROOT_DIR"* ]] && [[ -d "$dir" ]]; then
        log::info "TARGET" "Removing: ${dir#$ROOT_DIR/}"
        rm -rf "$dir"
        ((BUILD_COUNT++)) || true
    fi
done < <(find "$ROOT_DIR" -type d -name ".build" ! -path "*/Pods/*" ! -path "*/.git/*" -print0 2>/dev/null || true)

if [[ $BUILD_COUNT -gt 0 ]]; then
    log::success "TARGET" "Removed $BUILD_COUNT .build directory/ies"
else
    log::info "TARGET" "No .build directories found"
fi

# ============================================================================
# Step 6: Remove SPM workspace
# ============================================================================
log_section "Removing SPM Workspace"
log::step "TARGET" "Removing SPM workspace"
if [[ -d "$SPM_WORKSPACE" ]]; then
    if safe_remove_workspace "$SPM_WORKSPACE"; then
        log::success "TARGET" "SPM workspace removed"
    else
        log::warn "TARGET" "Failed to remove SPM workspace"
    fi
else
    log::info "TARGET" "SPM workspace not found or already removed"
fi

# ============================================================================
# Step 7: Clean DerivedData
# ============================================================================
log_section "Cleaning DerivedData"
log::step "TARGET" "Cleaning DerivedData cache"
DERIVED_DATA_DIR="$HOME/Library/Developer/Xcode/DerivedData"
if [[ -d "$DERIVED_DATA_DIR" ]]; then
    # Use find to remove contents, ignoring errors for locked files
    find "$DERIVED_DATA_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
    log::success "TARGET" "DerivedData cleaned"
else
    log::info "TARGET" "DerivedData directory not found"
fi

# ============================================================================
# Summary
# ============================================================================
log_title "Cleanup Complete"

TOTAL_REMOVED=$((PACKAGE_RESOLVED_COUNT + SWIFTPM_COUNT + XCODE_SPM_COUNT + SOURCEPACKAGES_COUNT + BUILD_COUNT))
log::success "TARGET" "SwiftPM environment cleaned"
log::info "TARGET" "Total items removed: $TOTAL_REMOVED"
log::info "TARGET" ""
log::info "TARGET" "Removed:"
log::info "TARGET" "  - Package.resolved files: $PACKAGE_RESOLVED_COUNT"
log::info "TARGET" "  - .swiftpm directories: $SWIFTPM_COUNT"
log::info "TARGET" "  - Xcode SPM caches: $XCODE_SPM_COUNT"
log::info "TARGET" "  - SourcePackages: $SOURCEPACKAGES_COUNT"
log::info "TARGET" "  - .build directories: $BUILD_COUNT"
