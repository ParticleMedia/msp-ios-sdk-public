#!/usr/bin/env bash
# ============================================================================
# CocoaPods Environment Cleanup
# ============================================================================
# Purpose: Clean CocoaPods environment and reinstall pods
#
# Safety: Only cleans CocoaPods artifacts and DerivedData.
#
# Usage:   ./Scripts/target-switching/cleanup_pods.sh
# ============================================================================

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/target-switching/common.sh
source "$SCRIPT_DIR/common.sh"

ensure_repo_root

if [[ ! -f "$ROOT_DIR/Podfile" ]]; then
    log_error "Podfile not found. Not a CocoaPods project."
    exit 1
fi

echo "============================================================================"
echo "CocoaPods Environment Cleanup"
echo "============================================================================"
echo ""

# Step 1: Deintegrate CocoaPods (must be in repo root)
log_step "1" "Deintegrating CocoaPods"
cd "$ROOT_DIR"
if command -v bundle &>/dev/null && [[ -f "$ROOT_DIR/Gemfile" ]]; then
    if bundle exec pod deintegrate 2>/dev/null; then
        log_success "CocoaPods deintegrated"
    else
        log_warning "pod deintegrate failed (may not be integrated)"
    fi
else
    log_warning "bundle not available, skipping deintegrate"
fi

# Step 2: Remove Pods directory
log_step "2" "Removing Pods directory"
if safe_remove_directory "$PODS_DIR" "Pods"; then
    log_success "Pods directory removed"
else
    log_warning "Pods directory not found"
fi

# Step 3: Remove CocoaPods workspace
log_step "3" "Removing CocoaPods workspace"
if safe_remove_workspace "$PODS_WORKSPACE"; then
    log_success "CocoaPods workspace removed"
else
    log_warning "CocoaPods workspace not found"
fi

# Step 4: Clean DerivedData
log_step "4" "Cleaning DerivedData"
DERIVED_DATA_DIR="$HOME/Library/Developer/Xcode/DerivedData"
if [[ -d "$DERIVED_DATA_DIR" ]]; then
    rm -rf "$DERIVED_DATA_DIR"/*
    log_success "DerivedData cleaned"
else
    log_warning "DerivedData directory not found"
fi

# Step 5: Install CocoaPods
log_step "5" "Installing CocoaPods"
cd "$ROOT_DIR"
if command -v bundle &>/dev/null && [[ -f "$ROOT_DIR/Gemfile" ]]; then
    # Ensure UTF-8 encoding for CocoaPods
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
    if bundle exec pod install; then
        log_success "CocoaPods installed"
    else
        log_error "pod install failed"
        log_info "Try setting: export LANG=en_US.UTF-8"
        exit 1
    fi
else
    log_error "bundle not available or Gemfile missing"
    exit 1
fi

echo ""
echo "============================================================================"
echo "Cleanup Complete"
echo "============================================================================"
echo ""
log_success "CocoaPods environment cleaned and reinstalled"

