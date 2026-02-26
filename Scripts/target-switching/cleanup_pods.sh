#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# CocoaPods Environment Cleanup (Hardened Version)
# ============================================================================
# Purpose: Clean CocoaPods environment and reinstall pods
#
# Safety:
#   - Only cleans CocoaPods artifacts and DerivedData
#   - Never deletes Build/ReleaseArtifacts/XCFrameworks/ or ThirdParty/
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

# R036c: Source cocoapods.sh module for unified pod operations
COCOAPODS_MODULE_AVAILABLE=false
if [[ -f "$ROOT_DIR/Scripts/lib/cocoapods.sh" ]]; then
    # shellcheck source=Scripts/lib/cocoapods.sh
    source "$ROOT_DIR/Scripts/lib/cocoapods.sh" 2>/dev/null || true
    if command -v install_pods &>/dev/null; then
        COCOAPODS_MODULE_AVAILABLE=true
    fi
fi

ensure_repo_root

FORCE="${1:-}"

if [[ "$FORCE" != "--force" ]]; then
    if [[ -t 0 ]]; then  # Only prompt if running interactively
        read -p "Continue with CocoaPods cleanup and reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log::info "TARGET" "Cleanup cancelled."
            exit 0
        fi
    fi
fi

if [[ ! -f "$ROOT_DIR/Podfile" ]]; then
    log::error "TARGET" "Podfile not found. Not a CocoaPods project."
    exit 1
fi

log_title "CocoaPods Environment Cleanup"

# Safety info
log::info "TARGET" "Protected directories (will NOT be deleted):"
log::info "TARGET" "  - Build/ReleaseArtifacts/XCFrameworks/"
log::info "TARGET" "  - ThirdParty/"
log::info "TARGET" "  - Sources/"
log::info "TARGET" "  - Package.swift.template (developer-maintained)"

# ============================================================================
# Step 1: Deintegrate CocoaPods
# ============================================================================
log_section "Deintegrating CocoaPods"
log::step "TARGET" "Running pod deintegrate"
cd "$ROOT_DIR"
if command -v bundle &>/dev/null && [[ -f "$ROOT_DIR/Gemfile" ]]; then
    if bundle exec pod deintegrate 2>/dev/null; then
        log::success "TARGET" "CocoaPods deintegrated"
    else
        log::info "TARGET" "pod deintegrate failed (may not be integrated)"
    fi
else
    if command -v pod &>/dev/null; then
        if pod deintegrate 2>/dev/null; then
            log::success "TARGET" "CocoaPods deintegrated"
        else
            log::info "TARGET" "pod deintegrate failed (may not be integrated)"
        fi
    else
        log::warn "TARGET" "pod command not available, skipping deintegrate"
    fi
fi

# ============================================================================
# Step 2: Remove Pods directory
# ============================================================================
log_section "Removing Pods Directory"
log::step "TARGET" "Removing Pods directory"
if [[ -d "$PODS_DIR" ]]; then
    if safe_remove_directory "$PODS_DIR" "Pods"; then
        log::success "TARGET" "Pods directory removed"
    else
        log::warn "TARGET" "Failed to remove Pods directory"
    fi
else
    log::info "TARGET" "Pods directory not found"
fi

# ============================================================================
# Step 3: Remove Podfile.lock
# ============================================================================
log_section "Removing Podfile.lock"
log::step "TARGET" "Removing Podfile.lock"
if [[ -f "$ROOT_DIR/Podfile.lock" ]]; then
    rm -f "$ROOT_DIR/Podfile.lock"
    log::success "TARGET" "Podfile.lock removed"
else
    log::info "TARGET" "Podfile.lock not found"
fi

# ============================================================================
# Step 4: Remove CocoaPods workspace
# ============================================================================
log_section "Removing CocoaPods Workspace"
log::step "TARGET" "Removing CocoaPods workspace"
if [[ -d "$PODS_WORKSPACE" ]]; then
    if safe_remove_workspace "$PODS_WORKSPACE"; then
        log::success "TARGET" "CocoaPods workspace removed"
    else
        log::warn "TARGET" "Failed to remove CocoaPods workspace"
    fi
else
    log::info "TARGET" "CocoaPods workspace not found"
fi

# ============================================================================
# Step 5: Clean DerivedData
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
# Step 6: Install CocoaPods
# ============================================================================
log_section "Installing CocoaPods"
log::step "TARGET" "Running pod install"
cd "$ROOT_DIR"

# Ensure UTF-8 encoding for CocoaPods
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

pod_exit_code=0

# R036c: Use cocoapods.sh module's install_pods() if available
if [[ "$COCOAPODS_MODULE_AVAILABLE" == "true" ]]; then
    if install_pods 2>&1; then
        log::success "TARGET" "CocoaPods installed (via cocoapods.sh module)"
    else
        pod_exit_code=$?
        log::error "TARGET" "pod install failed (exit code: $pod_exit_code)"
        log::info "TARGET" "This may be due to network issues or dependency conflicts"
        log::info "TARGET" "Try running manually: bundle exec pod install"
    fi
elif command -v bundle &>/dev/null && [[ -f "$ROOT_DIR/Gemfile" ]]; then
    # Fallback: Direct bundle exec pod install
    if bundle exec pod install 2>&1; then
        log::success "TARGET" "CocoaPods installed"
    else
        pod_exit_code=$?
        log::error "TARGET" "pod install failed (exit code: $pod_exit_code)"
        log::info "TARGET" "This may be due to network issues or dependency conflicts"
        log::info "TARGET" "Try running manually: bundle exec pod install"
    fi
else
    # Fallback: Direct pod install
    if command -v pod &>/dev/null; then
        if pod install 2>&1; then
            log::success "TARGET" "CocoaPods installed"
        else
            pod_exit_code=$?
            log::error "TARGET" "pod install failed (exit code: $pod_exit_code)"
            log::info "TARGET" "Try running manually: pod install"
        fi
    else
        log::error "TARGET" "pod command not available"
        exit 1
    fi
fi

# ============================================================================
# Summary
# ============================================================================
log_title "Cleanup Complete"

if [[ $pod_exit_code -eq 0 ]]; then
    log::success "TARGET" "CocoaPods environment cleaned and reinstalled"
else
    log::warn "TARGET" "CocoaPods environment cleaned but pod install had issues (exit: $pod_exit_code)"
    exit $pod_exit_code
fi
