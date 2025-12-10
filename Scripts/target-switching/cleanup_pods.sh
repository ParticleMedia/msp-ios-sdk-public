#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch K, shared) ---
# shellcheck source=/dev/null
if command -v git >/dev/null 2>&1; then
  MSP_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$MSP_REPO_ROOT" ] && [ -f "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh" ]; then
    # shellcheck source=/dev/null
    . "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh"
    msp_enforce_main_repo_or_exit
  fi
fi
# --- End MSP Worktree Safety Guard (Patch K, shared) ---
# ============================================================================
# CocoaPods Environment Cleanup (Hardened Version)
# ============================================================================
# Purpose: Clean CocoaPods environment and reinstall pods
#
# Safety:
#   - Only cleans CocoaPods artifacts and DerivedData
#   - Never deletes Build/XCFrameworks/ or ThirdParty/
#   - Never deletes Sources/
#   - Never modifies Package.swift.disabled
#
# Usage:   ./Scripts/target-switching/cleanup_pods.sh [--force]
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
    if [[ -t 0 ]]; then  # Only prompt if running interactively
        read -p "Continue with CocoaPods cleanup and reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cleanup cancelled."
            exit 0
        fi
    fi
fi

if [[ ! -f "$ROOT_DIR/Podfile" ]]; then
    log_error "Podfile not found. Not a CocoaPods project."
    exit 1
fi

log_title "CocoaPods Environment Cleanup"

# Safety info
log_info "Protected directories (will NOT be deleted):"
log_info "  - Build/XCFrameworks/"
log_info "  - ThirdParty/"
log_info "  - Sources/"
log_info "  - Package.swift.template (developer-maintained)"

# ============================================================================
# Step 1: Deintegrate CocoaPods
# ============================================================================
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
    if command -v pod &>/dev/null; then
        if pod deintegrate 2>/dev/null; then
            log_success "CocoaPods deintegrated"
        else
            log_info "pod deintegrate failed (may not be integrated)"
        fi
    else
        log_warn "pod command not available, skipping deintegrate"
    fi
fi

# ============================================================================
# Step 2: Remove Pods directory
# ============================================================================
log_section "Removing Pods Directory"
log_step "Removing Pods directory"
if [[ -d "$PODS_DIR" ]]; then
    if safe_remove_directory "$PODS_DIR" "Pods"; then
        log_success "Pods directory removed"
    else
        log_warn "Failed to remove Pods directory"
    fi
else
    log_info "Pods directory not found"
fi

# ============================================================================
# Step 3: Remove Podfile.lock
# ============================================================================
log_section "Removing Podfile.lock"
log_step "Removing Podfile.lock"
if [[ -f "$ROOT_DIR/Podfile.lock" ]]; then
    rm -f "$ROOT_DIR/Podfile.lock"
    log_success "Podfile.lock removed"
else
    log_info "Podfile.lock not found"
fi

# ============================================================================
# Step 4: Remove CocoaPods workspace
# ============================================================================
log_section "Removing CocoaPods Workspace"
log_step "Removing CocoaPods workspace"
if [[ -d "$PODS_WORKSPACE" ]]; then
    if safe_remove_workspace "$PODS_WORKSPACE"; then
        log_success "CocoaPods workspace removed"
    else
        log_warn "Failed to remove CocoaPods workspace"
    fi
else
    log_info "CocoaPods workspace not found"
fi

# ============================================================================
# Step 5: Clean DerivedData
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
# Step 6: Install CocoaPods
# ============================================================================
log_section "Installing CocoaPods"
log_step "Running pod install"
cd "$ROOT_DIR"

# Ensure UTF-8 encoding for CocoaPods
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

pod_exit_code=0
if command -v bundle &>/dev/null && [[ -f "$ROOT_DIR/Gemfile" ]]; then
    if bundle exec pod install 2>&1; then
        log_success "CocoaPods installed"
    else
        pod_exit_code=$?
        log_error "pod install failed (exit code: $pod_exit_code)"
        log_info "This may be due to network issues or dependency conflicts"
        log_info "Try running manually: bundle exec pod install"
    fi
else
    if command -v pod &>/dev/null; then
        if pod install 2>&1; then
            log_success "CocoaPods installed"
        else
            pod_exit_code=$?
            log_error "pod install failed (exit code: $pod_exit_code)"
            log_info "Try running manually: pod install"
        fi
    else
        log_error "pod command not available"
        exit 1
    fi
fi

# ============================================================================
# Summary
# ============================================================================
log_title "Cleanup Complete"

if [[ $pod_exit_code -eq 0 ]]; then
    log_success "CocoaPods environment cleaned and reinstalled"
else
    log_warn "CocoaPods environment cleaned but pod install had issues (exit: $pod_exit_code)"
    exit $pod_exit_code
fi
