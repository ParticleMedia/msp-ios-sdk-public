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
        echo "Cleanup cancelled."
        exit 0
    fi
fi

printf "============================================================================\n"
printf "SwiftPM Environment Cleanup\n"
printf "============================================================================\n"
printf "\n"

# Step 1: Remove .swiftpm directories (but not inside .xcodeproj)
log_step "1" "Removing .swiftpm directories"
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
done < <(find "$ROOT_DIR" -type d -name ".swiftpm" ! -path "*/Pods/*" ! -path "*/.git/*" -print0 2>/dev/null || true)

if [[ $SWIFTPM_COUNT -gt 0 ]]; then
    log_success "Removed $SWIFTPM_COUNT .swiftpm directory/ies"
else
    log_warning "No .swiftpm directories found"
fi

# Step 2: Remove SourcePackages directories
log_step "2" "Removing SourcePackages directories"
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
done < <(find "$ROOT_DIR" -type d -name "SourcePackages" ! -path "*/Pods/*" ! -path "*/.git/*" -print0 2>/dev/null || true)

if [[ $SOURCEPACKAGES_COUNT -gt 0 ]]; then
    log_success "Removed $SOURCEPACKAGES_COUNT SourcePackages directory/ies"
else
    log_warning "No SourcePackages directories found"
fi

# Step 3: Remove .build directories
log_step "3" "Removing .build directories"
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
done < <(find "$ROOT_DIR" -type d -name ".build" ! -path "*/Pods/*" ! -path "*/.git/*" -print0 2>/dev/null || true)

if [[ $BUILD_COUNT -gt 0 ]]; then
    log_success "Removed $BUILD_COUNT .build directory/ies"
else
    log_warning "No .build directories found"
fi

# Step 4: Remove SPM workspace (but only if it's the main one)
log_step "4" "Removing SPM workspace"
if safe_remove_workspace "$SPM_WORKSPACE"; then
    log_success "SPM workspace removed"
else
    log_warning "SPM workspace not found or already removed"
fi

# Step 5: Clean DerivedData
log_step "5" "Cleaning DerivedData"
DERIVED_DATA_DIR="$HOME/Library/Developer/Xcode/DerivedData"
if [[ -d "$DERIVED_DATA_DIR" ]]; then
    rm -rf "$DERIVED_DATA_DIR"/*
    log_success "DerivedData cleaned"
else
    log_warning "DerivedData directory not found"
fi

printf "\n"
printf "============================================================================\n"
printf "Cleanup Complete\n"
printf "============================================================================\n"
printf "\n"
log_success "SwiftPM environment cleaned"

