#!/usr/bin/env bash
# ============================================================================
# SwiftPM Environment Cleanup
# ============================================================================
# Purpose: Safely remove all SwiftPM artifacts without touching tracked files
#
# Safety: Only removes untracked SwiftPM artifacts. Never modifies tracked files.
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

# Step 1: Remove .swiftpm directories (but not inside .xcodeproj)
log_section "Removing .swiftpm Directories"
log_step "Scanning for .swiftpm directories"
SWIFTPM_COUNT=0
while IFS= read -r -d '' dir; do
    # Skip if inside .xcodeproj bundle
    if [[ "$dir" == *".xcodeproj/"* ]]; then
        continue
    fi
    if [[ "$dir" == "$ROOT_DIR"* ]]; then
        log_info "Removing: ${dir#$ROOT_DIR/}"
        rm -rf "$dir"
        ((SWIFTPM_COUNT++))
    fi
done < <(find "$ROOT_DIR" -type d -name ".swiftpm" ! -path "*/Pods/*" ! -path "*/.git/*" ! -path "*/MSPSharedLibraries/*" ! -path "*/MSPOMSDK/*" ! -path "*/NovaAdapter/*" -print0 2>/dev/null || true)

if [[ $SWIFTPM_COUNT -gt 0 ]]; then
    log_success "Removed $SWIFTPM_COUNT .swiftpm directory/ies"
else
    log_info "No .swiftpm directories found"
fi

# Step 2: Remove SourcePackages directories
log_section "Removing SourcePackages Directories"
log_step "Scanning for SourcePackages directories"
SOURCEPACKAGES_COUNT=0
while IFS= read -r -d '' dir; do
    # Skip if inside .xcodeproj bundle
    if [[ "$dir" == *".xcodeproj/"* ]]; then
        continue
    fi
    if [[ "$dir" == "$ROOT_DIR"* ]]; then
        log_info "Removing: ${dir#$ROOT_DIR/}"
        rm -rf "$dir"
        ((SOURCEPACKAGES_COUNT++))
    fi
done < <(find "$ROOT_DIR" -type d -name "SourcePackages" ! -path "*/Pods/*" ! -path "*/.git/*" ! -path "*/MSPSharedLibraries/*" ! -path "*/MSPOMSDK/*" ! -path "*/NovaAdapter/*" -print0 2>/dev/null || true)

if [[ $SOURCEPACKAGES_COUNT -gt 0 ]]; then
    log_success "Removed $SOURCEPACKAGES_COUNT SourcePackages directory/ies"
else
    log_info "No SourcePackages directories found"
fi

# Step 3: Remove .build directories
log_section "Removing .build Directories"
log_step "Scanning for .build directories"
BUILD_COUNT=0
while IFS= read -r -d '' dir; do
    # Skip if inside .xcodeproj bundle
    if [[ "$dir" == *".xcodeproj/"* ]]; then
        continue
    fi
    if [[ "$dir" == "$ROOT_DIR"* ]]; then
        log_info "Removing: ${dir#$ROOT_DIR/}"
        rm -rf "$dir"
        ((BUILD_COUNT++))
    fi
done < <(find "$ROOT_DIR" -type d -name ".build" ! -path "*/Pods/*" ! -path "*/.git/*" ! -path "*/MSPSharedLibraries/*" ! -path "*/MSPOMSDK/*" ! -path "*/NovaAdapter/*" -print0 2>/dev/null || true)

if [[ $BUILD_COUNT -gt 0 ]]; then
    log_success "Removed $BUILD_COUNT .build directory/ies"
else
    log_info "No .build directories found"
fi

# Step 4: Remove SPM workspace (but only if it's the main one)
log_section "Removing SPM Workspace"
log_step "Removing SPM workspace"
if safe_remove_workspace "$SPM_WORKSPACE"; then
    log_success "SPM workspace removed"
else
    log_info "SPM workspace not found or already removed"
fi

# Step 5: Clean DerivedData
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

log_title "Cleanup Complete"
log_success "SwiftPM environment cleaned"
