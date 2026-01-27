#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
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

# Source common functions
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
        log_info "Cleanup cancelled."
        exit 0
    fi
fi

log_title "SwiftPM Environment Cleanup"

# Safety info
log_info "Protected directories (will NOT be deleted):"
log_info "  - Build/ReleaseArtifacts/XCFrameworks/"
log_info "  - ThirdParty/"
log_info "  - Sources/"

# ============================================================================
# Step 1: Remove ALL Package.resolved files
# ============================================================================
log_section "Removing Package.resolved Files"
log_step "Scanning for Package.resolved files"
PACKAGE_RESOLVED_COUNT=0

# Remove root Package.resolved
if [[ -f "$ROOT_DIR/Package.resolved" ]]; then
    rm -f "$ROOT_DIR/Package.resolved"
    ((PACKAGE_RESOLVED_COUNT++)) || true
    log_info "Removed: Package.resolved (root)"
fi

# Remove Package.resolved from inside workspaces
while IFS= read -r -d '' resolved_file; do
    if [[ -f "$resolved_file" ]]; then
        log_info "Removing: ${resolved_file#$ROOT_DIR/}"
        rm -f "$resolved_file"
        ((PACKAGE_RESOLVED_COUNT++)) || true
    fi
done < <(find "$ROOT_DIR" -path "*.xcworkspace/*/Package.resolved" -type f ! -path "*/Pods/*" -print0 2>/dev/null || true)

# Remove Package.resolved from inside .xcodeproj bundles
while IFS= read -r -d '' resolved_file; do
    if [[ -f "$resolved_file" ]]; then
        log_info "Removing: ${resolved_file#$ROOT_DIR/}"
        rm -f "$resolved_file"
        ((PACKAGE_RESOLVED_COUNT++)) || true
    fi
done < <(find "$ROOT_DIR" -path "*.xcodeproj/*/Package.resolved" -type f ! -path "*/Pods/*" -print0 2>/dev/null || true)

if [[ $PACKAGE_RESOLVED_COUNT -gt 0 ]]; then
    log_success "Removed $PACKAGE_RESOLVED_COUNT Package.resolved file(s)"
else
    log_info "No Package.resolved files found"
fi

# ============================================================================
# Step 2: Remove ALL .swiftpm directories
# ============================================================================
log_section "Removing .swiftpm Directories"
log_step "Scanning for .swiftpm directories"
SWIFTPM_COUNT=0

# Remove .swiftpm directories everywhere
while IFS= read -r -d '' dir; do
    if [[ "$dir" == "$ROOT_DIR"* ]] && [[ -d "$dir" ]]; then
        log_info "Removing: ${dir#$ROOT_DIR/}"
        rm -rf "$dir"
        ((SWIFTPM_COUNT++)) || true
    fi
done < <(find "$ROOT_DIR" -type d -name ".swiftpm" ! -path "*/Pods/*" ! -path "*/.git/*" -print0 2>/dev/null || true)

if [[ $SWIFTPM_COUNT -gt 0 ]]; then
    log_success "Removed $SWIFTPM_COUNT .swiftpm directory/ies"
else
    log_info "No .swiftpm directories found"
fi

# ============================================================================
# Step 3: Remove swiftpm directories inside xcshareddata and xcuserdata
# ============================================================================
log_section "Removing Xcode SPM Caches"
log_step "Scanning for swiftpm directories inside Xcode bundles"
XCODE_SPM_COUNT=0

# Remove */xcshareddata/swiftpm/
while IFS= read -r -d '' dir; do
    if [[ "$dir" == "$ROOT_DIR"* ]] && [[ -d "$dir" ]]; then
        log_info "Removing: ${dir#$ROOT_DIR/}"
        rm -rf "$dir"
        ((XCODE_SPM_COUNT++)) || true
    fi
done < <(find "$ROOT_DIR" -type d -path "*/xcshareddata/swiftpm" ! -path "*/Pods/*" -print0 2>/dev/null || true)

# Remove */xcuserdata/*/swiftpm/
while IFS= read -r -d '' dir; do
    if [[ "$dir" == "$ROOT_DIR"* ]] && [[ -d "$dir" ]]; then
        log_info "Removing: ${dir#$ROOT_DIR/}"
        rm -rf "$dir"
        ((XCODE_SPM_COUNT++)) || true
    fi
done < <(find "$ROOT_DIR" -type d -path "*/xcuserdata/*/swiftpm" ! -path "*/Pods/*" -print0 2>/dev/null || true)

# Remove swiftpm directories inside .xcodeproj/project.xcworkspace/
while IFS= read -r -d '' dir; do
    if [[ "$dir" == "$ROOT_DIR"* ]] && [[ -d "$dir" ]]; then
        log_info "Removing: ${dir#$ROOT_DIR/}"
        rm -rf "$dir"
        ((XCODE_SPM_COUNT++)) || true
    fi
done < <(find "$ROOT_DIR" -type d -name "swiftpm" -path "*/.xcodeproj/*" ! -path "*/Pods/*" -print0 2>/dev/null || true)

if [[ $XCODE_SPM_COUNT -gt 0 ]]; then
    log_success "Removed $XCODE_SPM_COUNT Xcode SPM cache directory/ies"
else
    log_info "No Xcode SPM caches found"
fi

# ============================================================================
# Step 4: Remove SourcePackages directories
# ============================================================================
log_section "Removing SourcePackages Directories"
log_step "Scanning for SourcePackages directories"
SOURCEPACKAGES_COUNT=0

while IFS= read -r -d '' dir; do
    if [[ "$dir" == "$ROOT_DIR"* ]] && [[ -d "$dir" ]]; then
        log_info "Removing: ${dir#$ROOT_DIR/}"
        rm -rf "$dir"
        ((SOURCEPACKAGES_COUNT++)) || true
    fi
done < <(find "$ROOT_DIR" -type d -name "SourcePackages" ! -path "*/Pods/*" ! -path "*/.git/*" -print0 2>/dev/null || true)

if [[ $SOURCEPACKAGES_COUNT -gt 0 ]]; then
    log_success "Removed $SOURCEPACKAGES_COUNT SourcePackages directory/ies"
else
    log_info "No SourcePackages directories found"
fi

# ============================================================================
# Step 5: Remove .build directories
# ============================================================================
log_section "Removing .build Directories"
log_step "Scanning for .build directories"
BUILD_COUNT=0

while IFS= read -r -d '' dir; do
    if [[ "$dir" == "$ROOT_DIR"* ]] && [[ -d "$dir" ]]; then
        log_info "Removing: ${dir#$ROOT_DIR/}"
        rm -rf "$dir"
        ((BUILD_COUNT++)) || true
    fi
done < <(find "$ROOT_DIR" -type d -name ".build" ! -path "*/Pods/*" ! -path "*/.git/*" -print0 2>/dev/null || true)

if [[ $BUILD_COUNT -gt 0 ]]; then
    log_success "Removed $BUILD_COUNT .build directory/ies"
else
    log_info "No .build directories found"
fi

# ============================================================================
# Step 6: Remove SPM workspace
# ============================================================================
log_section "Removing SPM Workspace"
log_step "Removing SPM workspace"
if [[ -d "$SPM_WORKSPACE" ]]; then
    if safe_remove_workspace "$SPM_WORKSPACE"; then
        log_success "SPM workspace removed"
    else
        log_warn "Failed to remove SPM workspace"
    fi
else
    log_info "SPM workspace not found or already removed"
fi

# ============================================================================
# Step 7: Clean DerivedData
# ============================================================================
log_section "Cleaning DerivedData"
log_step "Cleaning DerivedData cache"
DERIVED_DATA_DIR="$HOME/Library/Developer/Xcode/DerivedData"
if [[ -d "$DERIVED_DATA_DIR" ]]; then
    # Use find to remove contents, ignoring errors for locked files
    find "$DERIVED_DATA_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
    log_success "DerivedData cleaned"
else
    log_info "DerivedData directory not found"
fi

# ============================================================================
# Summary
# ============================================================================
log_title "Cleanup Complete"

TOTAL_REMOVED=$((PACKAGE_RESOLVED_COUNT + SWIFTPM_COUNT + XCODE_SPM_COUNT + SOURCEPACKAGES_COUNT + BUILD_COUNT))
log_success "SwiftPM environment cleaned"
log_info "Total items removed: $TOTAL_REMOVED"
log_info ""
log_info "Removed:"
log_info "  - Package.resolved files: $PACKAGE_RESOLVED_COUNT"
log_info "  - .swiftpm directories: $SWIFTPM_COUNT"
log_info "  - Xcode SPM caches: $XCODE_SPM_COUNT"
log_info "  - SourcePackages: $SOURCEPACKAGES_COUNT"
log_info "  - .build directories: $BUILD_COUNT"
