#!/usr/bin/env bash
# ============================================================================
# CocoaPods Environment Cleanup (Updated for new SDK architecture - Round 26)
# ============================================================================
# Purpose: Clean CocoaPods environment and reinstall pods
#
# Safety: 
#   - Only cleans CocoaPods artifacts and DerivedData
#   - Never deletes Build/XCFrameworks/ or ThirdParty/
#   - Never deletes Sources/
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

log_title "CocoaPods Environment Cleanup"

# Safety check: Ensure we never delete protected directories
log_info "Protected directories (will NOT be deleted):"
log_info "  - Build/XCFrameworks/"
log_info "  - ThirdParty/"
log_info "  - Sources/"

# Step 1: Deintegrate CocoaPods (must be in repo root)
log_section "Deintegrating CocoaPods"
log_step "Running pod deintegrate"
cd "$ROOT_DIR"
if command -v bundle &>/dev/null && [[ -f "$ROOT_DIR/Gemfile" ]]; then
    if bundle exec pod deintegrate 2>/dev/null; then
        log_success "CocoaPods deintegrated"
    else
        log_info "pod deintegrate failed (may not be integrated)"
    fi
else
    log_warn "bundle not available, skipping deintegrate"
fi

# Step 2: Remove Pods directory
log_section "Removing Pods Directory"
log_step "Removing Pods directory"
if safe_remove_directory "$PODS_DIR" "Pods"; then
    log_success "Pods directory removed"
else
    log_info "Pods directory not found"
fi

# Step 3: Remove CocoaPods workspace
log_section "Removing CocoaPods Workspace"
log_step "Removing CocoaPods workspace"
if safe_remove_workspace "$PODS_WORKSPACE"; then
    log_success "CocoaPods workspace removed"
else
    log_info "CocoaPods workspace not found"
fi

# Step 4: Clean DerivedData
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

# Step 5: Install CocoaPods
log_section "Installing CocoaPods"
log_step "Running pod install"
cd "$ROOT_DIR"
if command -v bundle &>/dev/null && [[ -f "$ROOT_DIR/Gemfile" ]]; then
    # Ensure UTF-8 encoding for CocoaPods
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
    if bundle exec pod install 2>&1; then
        log_success "CocoaPods installed"
    else
        local pod_exit=$?
        log_error "pod install failed (exit code: $pod_exit)"
        log_info "This may be due to network issues or dependency conflicts"
        log_info "Try running manually: bundle exec pod install"
        # Don't exit - allow script to continue for validation
        # The validate_environment function will catch missing Pods
        return $pod_exit
    fi
else
    log_error "bundle not available or Gemfile missing"
    exit 1
fi

log_title "Cleanup Complete"
log_success "CocoaPods environment cleaned and reinstalled"
