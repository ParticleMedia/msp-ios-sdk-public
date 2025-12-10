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
# XCFramework Validation Script
# ============================================================================
# Purpose: Validates all required XCFrameworks exist and are valid.
#          Used by switch-target.sh before mode switching.
#
# Usage:   ./Scripts/target-switching/validate_xcframeworks.sh
#
# Exit codes:
#   0 - All XCFrameworks valid
#   1 - One or more XCFrameworks missing or invalid
# ============================================================================

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/target-switching/common.sh
source "$SCRIPT_DIR/common.sh"

ensure_repo_root

# ============================================================================
# Configuration
# ============================================================================

# Use arrays from common.sh
# CORE_XCFRAMEWORKS, THIRDPARTY_XCFRAMEWORKS, EMBEDDED_XCFRAMEWORKS, ADAPTER_SOURCES

# ============================================================================
# Validation Functions
# ============================================================================

validate_xcframework() {
    local xcf_path="$1"
    local xcf_name="$(basename "$xcf_path")"
    
    # Check directory exists
    if [[ ! -d "$ROOT_DIR/$xcf_path" ]]; then
        log_error "❌ MISSING: $xcf_path"
        return 1
    fi
    
    # Check Info.plist exists
    if [[ ! -f "$ROOT_DIR/$xcf_path/Info.plist" ]]; then
        log_error "❌ INVALID (no Info.plist): $xcf_path"
        return 1
    fi
    
    # Check for at least one slice
    local slice_count=0
    for slice in "$ROOT_DIR/$xcf_path"/ios-*; do
        if [[ -d "$slice" ]]; then
            ((slice_count++))
        fi
    done
    
    if [[ $slice_count -eq 0 ]]; then
        log_error "❌ INVALID (no iOS slices): $xcf_path"
        return 1
    fi
    
    log_success "✓ $xcf_name"
    return 0
}

validate_adapter_source() {
    local adapter_path="$1"
    local adapter_name="$(basename "$adapter_path")"
    
    # Check directory exists
    if [[ ! -d "$ROOT_DIR/$adapter_path" ]]; then
        log_error "❌ MISSING: $adapter_path"
        return 1
    fi
    
    # Check for Swift files
    local swift_count=0
    swift_count=$(find "$ROOT_DIR/$adapter_path" -name "*.swift" -type f 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ $swift_count -eq 0 ]]; then
        log_error "❌ INVALID (no Swift files): $adapter_path"
        return 1
    fi
    
    log_success "✓ $adapter_name ($swift_count Swift files)"
    return 0
}

# ============================================================================
# Version Verification Functions
# ============================================================================

# Get version from CocoaPods lockfile
get_pods_version() {
    local pod_name="$1"
    local lockfile="$ROOT_DIR/Podfile.lock"
    
    if [[ ! -f "$lockfile" ]]; then
        echo "unknown"
        return
    fi
    
    # Extract version from Podfile.lock (format: "  - PodName (x.y.z)")
    local version
    version=$(grep -E "^  - ${pod_name} \\(" "$lockfile" 2>/dev/null | head -1 | sed -E 's/.*\(([0-9.]+)\).*/\1/' || echo "unknown")
    echo "$version"
}

# Get version from Package.resolved
get_spm_version() {
    local package_name="$1"
    local resolved_file="$ROOT_DIR/Examples/MSPDemoApp/MSPDemoApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    
    # Also check alternative locations
    if [[ ! -f "$resolved_file" ]]; then
        resolved_file="$ROOT_DIR/Package.resolved"
    fi
    
    if [[ ! -f "$resolved_file" ]]; then
        echo "not-resolved"
        return
    fi
    
    # Extract version from Package.resolved (JSON format v2)
    local version
    version=$(grep -A 5 "\"identity\" : \"${package_name}\"" "$resolved_file" 2>/dev/null | grep -E '"version"' | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' | head -1 || echo "unknown")
    echo "$version"
}

# Validate version match between Pods and SPM
validate_dependency_versions() {
    local errors=0
    
    log_section "Dependency Version Verification"
    log_info "Comparing CocoaPods and SPM dependency versions..."
    
    # SwiftProtobuf version check
    local pods_swiftprotobuf spm_swiftprotobuf
    pods_swiftprotobuf=$(get_pods_version "SwiftProtobuf")
    spm_swiftprotobuf=$(get_spm_version "swift-protobuf")
    
    if [[ "$pods_swiftprotobuf" != "unknown" ]] && [[ "$spm_swiftprotobuf" != "not-resolved" ]] && [[ "$spm_swiftprotobuf" != "unknown" ]]; then
        if [[ "$pods_swiftprotobuf" == "$spm_swiftprotobuf" ]]; then
            log_success "✓ SwiftProtobuf: Pods=$pods_swiftprotobuf, SPM=$spm_swiftprotobuf (match)"
        else
            log_error "❌ SwiftProtobuf version mismatch: Pods=$pods_swiftprotobuf, SPM=$spm_swiftprotobuf"
            log_error "   Update Package.swift to use exact: \"$pods_swiftprotobuf\""
            ((errors++))
        fi
    else
        log_warn "⚠ SwiftProtobuf: Pods=$pods_swiftprotobuf, SPM=$spm_swiftprotobuf (unable to verify)"
    fi
    
    # Lottie version check
    local pods_lottie spm_lottie
    pods_lottie=$(get_pods_version "lottie-ios")
    spm_lottie=$(get_spm_version "lottie-ios")
    
    if [[ "$pods_lottie" != "unknown" ]] && [[ "$spm_lottie" != "not-resolved" ]] && [[ "$spm_lottie" != "unknown" ]]; then
        if [[ "$pods_lottie" == "$spm_lottie" ]]; then
            log_success "✓ Lottie: Pods=$pods_lottie, SPM=$spm_lottie (match)"
        else
            log_error "❌ Lottie version mismatch: Pods=$pods_lottie, SPM=$spm_lottie"
            log_error "   Update Package.swift to use exact: \"$pods_lottie\""
            ((errors++))
        fi
    else
        log_warn "⚠ Lottie: Pods=$pods_lottie, SPM=$spm_lottie (unable to verify)"
    fi
    
    return $errors
}

# ============================================================================
# Main Validation
# ============================================================================

main() {
    log_title "XCFramework Validation"
    log_info "Repository: $ROOT_DIR"
    
    local total_errors=0
    
    # Validate Core XCFrameworks
    log_section "Core XCFrameworks (Build/XCFrameworks/)"
    for xcf in "${CORE_XCFRAMEWORKS[@]}"; do
        if ! validate_xcframework "$xcf"; then
            ((total_errors++))
        fi
    done
    
    # Validate ThirdParty XCFrameworks
    log_section "ThirdParty XCFrameworks"
    for xcf in "${THIRDPARTY_XCFRAMEWORKS[@]}"; do
        if ! validate_xcframework "$xcf"; then
            ((total_errors++))
        fi
    done
    
    # Validate Embedded XCFrameworks
    log_section "Embedded XCFrameworks"
    for xcf in "${EMBEDDED_XCFRAMEWORKS[@]}"; do
        if ! validate_xcframework "$xcf"; then
            ((total_errors++))
        fi
    done
    
    # Validate Adapter Sources (non-fatal - warnings only)
    # Adapters are source-only and their absence should not block validation
    log_section "Adapter Source Modules (non-fatal)"
    local adapter_warnings=0
    for adapter in "${ADAPTER_SOURCES[@]}"; do
        if ! validate_adapter_source "$adapter"; then
            ((adapter_warnings++)) || true
            # Note: We don't increment total_errors for adapter issues
        fi
    done
    
    if [[ $adapter_warnings -gt 0 ]]; then
        log_warn "$adapter_warnings adapter source(s) have issues (non-blocking)"
    fi
    
    # Validate Dependency Versions (SwiftProtobuf, Lottie)
    if ! validate_dependency_versions; then
        version_errors=$?
        ((total_errors += version_errors))
    fi
    
    # Summary
    log_section "Validation Summary"
    
    if [[ $total_errors -eq 0 ]]; then
        log_success "All required XCFrameworks validated successfully!"
        echo ""
        log_info "Core XCFrameworks:       ${#CORE_XCFRAMEWORKS[@]} ✓"
        log_info "ThirdParty XCFrameworks: ${#THIRDPARTY_XCFRAMEWORKS[@]} ✓"
        log_info "Embedded XCFrameworks:   ${#EMBEDDED_XCFRAMEWORKS[@]} ✓"
        log_info "Adapter Sources:         ${#ADAPTER_SOURCES[@]} (warnings: $adapter_warnings)"
        echo ""
        log_info "NOTE: Adapter issues are non-fatal. Adapters are SOURCE-ONLY."
        exit 0
    else
        log_error "Validation failed with $total_errors error(s)"
        echo ""
        log_info "REQUIRED XCFrameworks (must exist):"
        log_info "  - MSPCore, MSPiOSCore, MSPSharedLibraries, MSPOMSDK, NovaCore"
        log_info ""
        log_info "To fix missing XCFrameworks:"
        log_info "  1. Run: ./Scripts/xcframeworks/build-core.sh"
        log_info "  2. Ensure ThirdParty/PrebidMobile/PrebidMobile.xcframework exists"
        log_info ""
        log_info "NOTE: Adapter XCFrameworks are NOT required (adapters are source-only)."
        exit 1
    fi
}

main "$@"

