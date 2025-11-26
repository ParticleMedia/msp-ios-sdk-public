#!/usr/bin/env bash
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
    
    # Validate Adapter Sources
    log_section "Adapter Source Modules"
    for adapter in "${ADAPTER_SOURCES[@]}"; do
        if ! validate_adapter_source "$adapter"; then
            ((total_errors++))
        fi
    done
    
    # Summary
    log_section "Validation Summary"
    
    if [[ $total_errors -eq 0 ]]; then
        log_success "All XCFrameworks and adapters validated successfully!"
        echo ""
        log_info "Core XCFrameworks:     ${#CORE_XCFRAMEWORKS[@]} ✓"
        log_info "ThirdParty XCFrameworks: ${#THIRDPARTY_XCFRAMEWORKS[@]} ✓"
        log_info "Embedded XCFrameworks:   ${#EMBEDDED_XCFRAMEWORKS[@]} ✓"
        log_info "Adapter Sources:         ${#ADAPTER_SOURCES[@]} ✓"
        exit 0
    else
        log_error "Validation failed with $total_errors error(s)"
        echo ""
        log_info "To fix missing XCFrameworks:"
        log_info "  1. Run: ./Scripts/xcframeworks/build-core.sh"
        log_info "  2. Ensure ThirdParty/PrebidMobile/PrebidMobile.xcframework exists"
        log_info ""
        log_info "To fix missing adapters:"
        log_info "  Check Sources/Adapters/ directory structure"
        exit 1
    fi
}

main "$@"

