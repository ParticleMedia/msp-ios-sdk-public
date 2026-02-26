#!/usr/bin/env bash
# ============================================================================
# Shared XCFramework Validation Module (R026)
# ============================================================================
# Module: lib/shared/xcframework_validate.sh
# Purpose: Unified XCFramework validation operations
#
# Functions:
#   - xcf_validate_exists: Check if XCFramework exists
#   - xcf_validate_structure: Validate XCFramework structure (Info.plist, slices)
#   - xcf_validate_content: Validate XCFramework content (modulemap, headers)
#   - xcf_validate_full: Complete validation (structure + content)
#   - xcf_validate_slices: Validate required platform slices
#   - xcf_validate_modulemap: Validate module.modulemap file
#   - xcf_validate_no_hardcoded_paths: Check for hardcoded build paths
#
# Environment Variables:
#   - MSP_XCFRAMEWORK_REQUIRED_SLICES: Required platform slices (default: ios-arm64,ios-arm64_x86_64-simulator)
#   - MSP_XCFRAMEWORK_STRICT_VALIDATION: Enable strict validation mode (default: false)
#
# Dependencies:
#   - Logging functions (log::info, log::error, log::success) - optional
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_SHARED_XCFRAMEWORK_VALIDATE_SOURCED:-}" ]] && return 0
readonly _SHARED_XCFRAMEWORK_VALIDATE_SOURCED=1

# ============================================================================
# Configuration Defaults
# ============================================================================

XCFRAMEWORK_VALIDATE_DEFAULT_DEVICE_SLICE="ios-arm64"
XCFRAMEWORK_VALIDATE_DEFAULT_SIMULATOR_SLICE="ios-arm64_x86_64-simulator"

# ============================================================================
# Internal Helpers
# ============================================================================

_xcf_validate_log() {
    local level="$1"
    local tag="${2:-XCF}"
    local msg="$3"

    if command -v "log::${level}" &>/dev/null; then
        "log::${level}" "$tag" "$msg"
    else
        echo "[$level][$tag] $msg" >&2
    fi
}

# ============================================================================
# Validate Exists
# ============================================================================
# Checks if an XCFramework exists at the given path
#
# Args:
#   $1: xcframework_path - Path to .xcframework directory
#   $2: log_tag - Optional log tag
#
# Returns:
#   0 if exists, 1 if not
# ============================================================================
xcf_validate_exists() {
    local xcframework_path="$1"
    local log_tag="${2:-XCF}"

    if [[ -z "$xcframework_path" ]]; then
        _xcf_validate_log "error" "$log_tag" "XCFramework path not provided"
        return 1
    fi

    if [[ ! -d "$xcframework_path" ]]; then
        _xcf_validate_log "error" "$log_tag" "XCFramework not found: $xcframework_path"
        return 1
    fi

    # Check for .xcframework extension
    if [[ "$xcframework_path" != *.xcframework ]]; then
        _xcf_validate_log "warn" "$log_tag" "Path does not have .xcframework extension: $xcframework_path"
    fi

    _xcf_validate_log "success" "$log_tag" "✓ XCFramework exists: $(basename "$xcframework_path")"
    return 0
}

# ============================================================================
# Validate Slices
# ============================================================================
# Validates that required platform slices exist
#
# Args:
#   $1: xcframework_path - Path to .xcframework directory
#   $2: log_tag - Optional log tag
#
# Returns:
#   0 if all slices exist, 1 if any missing
# ============================================================================
xcf_validate_slices() {
    local xcframework_path="$1"
    local log_tag="${2:-XCF}"

    if [[ ! -d "$xcframework_path" ]]; then
        _xcf_validate_log "error" "$log_tag" "XCFramework not found: $xcframework_path"
        return 1
    fi

    local device_slice="${MSP_XCFRAMEWORK_DEVICE_SLICE:-$XCFRAMEWORK_VALIDATE_DEFAULT_DEVICE_SLICE}"
    local simulator_slice="${MSP_XCFRAMEWORK_SIMULATOR_SLICE:-$XCFRAMEWORK_VALIDATE_DEFAULT_SIMULATOR_SLICE}"

    local missing_slices=()

    # Check device slice
    if [[ ! -d "$xcframework_path/$device_slice" ]]; then
        # Try alternative names (arm64 variants)
        local found=false
        for variant in "ios-arm64" "ios-arm64-maccatalyst"; do
            if [[ -d "$xcframework_path/$variant" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == "false" ]]; then
            missing_slices+=("$device_slice")
        fi
    fi

    # Check simulator slice
    if [[ ! -d "$xcframework_path/$simulator_slice" ]]; then
        # Try alternative names
        local found=false
        for variant in "ios-arm64_x86_64-simulator" "ios-x86_64-simulator" "ios-arm64-simulator"; do
            if [[ -d "$xcframework_path/$variant" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == "false" ]]; then
            missing_slices+=("$simulator_slice")
        fi
    fi

    if [[ ${#missing_slices[@]} -gt 0 ]]; then
        _xcf_validate_log "error" "$log_tag" "Missing platform slices: ${missing_slices[*]}"
        _xcf_validate_log "info" "$log_tag" "Available slices:"
        for slice in "$xcframework_path"/*/; do
            if [[ -d "$slice" ]]; then
                _xcf_validate_log "info" "$log_tag" "  - $(basename "$slice")"
            fi
        done
        return 1
    fi

    _xcf_validate_log "success" "$log_tag" "✓ Platform slices validated"
    return 0
}

# ============================================================================
# Validate Info.plist
# ============================================================================
# Validates Info.plist exists and contains required keys
#
# Args:
#   $1: xcframework_path - Path to .xcframework directory
#   $2: log_tag - Optional log tag
#
# Returns:
#   0 if valid, 1 if invalid
# ============================================================================
xcf_validate_info_plist() {
    local xcframework_path="$1"
    local log_tag="${2:-XCF}"

    local info_plist="$xcframework_path/Info.plist"

    if [[ ! -f "$info_plist" ]]; then
        _xcf_validate_log "error" "$log_tag" "Info.plist not found: $info_plist"
        return 1
    fi

    # Check for required keys using plutil
    if command -v plutil &>/dev/null; then
        if ! plutil -lint "$info_plist" &>/dev/null; then
            _xcf_validate_log "error" "$log_tag" "Info.plist is not valid"
            return 1
        fi
    fi

    _xcf_validate_log "success" "$log_tag" "✓ Info.plist validated"
    return 0
}

# ============================================================================
# Validate Structure
# ============================================================================
# Validates XCFramework structure (Info.plist, slices)
#
# Args:
#   $1: xcframework_path - Path to .xcframework directory
#   $2: log_tag - Optional log tag
#
# Returns:
#   0 if valid, 1 if invalid
# ============================================================================
xcf_validate_structure() {
    local xcframework_path="$1"
    local log_tag="${2:-XCF}"

    _xcf_validate_log "info" "$log_tag" "Validating structure: $(basename "$xcframework_path")"

    # Check existence
    if ! xcf_validate_exists "$xcframework_path" "$log_tag"; then
        return 1
    fi

    # Check Info.plist
    if ! xcf_validate_info_plist "$xcframework_path" "$log_tag"; then
        return 1
    fi

    # Check slices
    if ! xcf_validate_slices "$xcframework_path" "$log_tag"; then
        return 1
    fi

    _xcf_validate_log "success" "$log_tag" "✓ Structure validation passed"
    return 0
}

# ============================================================================
# Validate Modulemap
# ============================================================================
# Validates module.modulemap exists and contains required structure
#
# Args:
#   $1: xcframework_path - Path to .xcframework directory
#   $2: module_name - Expected module name
#   $3: log_tag - Optional log tag
#
# Returns:
#   0 if valid, 1 if invalid
# ============================================================================
xcf_validate_modulemap() {
    local xcframework_path="$1"
    local module_name="$2"
    local log_tag="${3:-XCF}"

    if [[ ! -d "$xcframework_path" ]]; then
        _xcf_validate_log "error" "$log_tag" "XCFramework not found: $xcframework_path"
        return 1
    fi

    # Find modulemap in any slice
    local modulemap_found=false
    local modulemap_path=""

    for slice_dir in "$xcframework_path"/*/; do
        if [[ -d "$slice_dir" ]]; then
            # Check in framework
            for framework_dir in "$slice_dir"/*.framework; do
                if [[ -d "$framework_dir" ]]; then
                    local mm="$framework_dir/Modules/module.modulemap"
                    if [[ -f "$mm" ]]; then
                        modulemap_found=true
                        modulemap_path="$mm"
                        break 2
                    fi
                fi
            done
        fi
    done

    if [[ "$modulemap_found" == "false" ]]; then
        _xcf_validate_log "error" "$log_tag" "module.modulemap not found in any slice"
        return 1
    fi

    # Check modulemap contains module declaration
    if [[ -n "$module_name" ]]; then
        if ! grep -q "framework module $module_name" "$modulemap_path" 2>/dev/null && \
           ! grep -q "module $module_name" "$modulemap_path" 2>/dev/null; then
            _xcf_validate_log "warn" "$log_tag" "Module name '$module_name' not found in modulemap"
            # This is a warning, not an error
        fi
    fi

    _xcf_validate_log "success" "$log_tag" "✓ module.modulemap validated"
    return 0
}

# ============================================================================
# Validate No Hardcoded Paths
# ============================================================================
# Checks for hardcoded build paths in .swiftinterface files
#
# Args:
#   $1: xcframework_path - Path to .xcframework directory
#   $2: log_tag - Optional log tag
#
# Returns:
#   0 if no hardcoded paths, 1 if found
# ============================================================================
xcf_validate_no_hardcoded_paths() {
    local xcframework_path="$1"
    local log_tag="${2:-XCF}"

    if [[ ! -d "$xcframework_path" ]]; then
        _xcf_validate_log "error" "$log_tag" "XCFramework not found: $xcframework_path"
        return 1
    fi

    # Common hardcoded path patterns to check
    local patterns=(
        "/Users/"
        "/private/var/"
        "/var/folders/"
        "DerivedData"
    )

    local found_issues=false

    # Find all .swiftinterface files
    while IFS= read -r -d '' swiftinterface; do
        for pattern in "${patterns[@]}"; do
            if grep -q "$pattern" "$swiftinterface" 2>/dev/null; then
                _xcf_validate_log "warn" "$log_tag" "Hardcoded path found in: $(basename "$swiftinterface")"
                _xcf_validate_log "info" "$log_tag" "  Pattern: $pattern"
                found_issues=true
            fi
        done
    done < <(find "$xcframework_path" -name "*.swiftinterface" -print0 2>/dev/null)

    if [[ "$found_issues" == "true" ]]; then
        if [[ "${MSP_XCFRAMEWORK_STRICT_VALIDATION:-false}" == "true" ]]; then
            _xcf_validate_log "error" "$log_tag" "Hardcoded paths detected (strict mode)"
            return 1
        else
            _xcf_validate_log "warn" "$log_tag" "⚠️ Hardcoded paths detected (non-fatal)"
        fi
    else
        _xcf_validate_log "success" "$log_tag" "✓ No hardcoded paths detected"
    fi

    return 0
}

# ============================================================================
# Validate Content
# ============================================================================
# Validates XCFramework content (modulemap, umbrella header)
#
# Args:
#   $1: xcframework_path - Path to .xcframework directory
#   $2: module_name - Expected module name
#   $3: log_tag - Optional log tag
#
# Returns:
#   0 if valid, 1 if invalid
# ============================================================================
xcf_validate_content() {
    local xcframework_path="$1"
    local module_name="$2"
    local log_tag="${3:-XCF}"

    _xcf_validate_log "info" "$log_tag" "Validating content: $(basename "$xcframework_path")"

    # Check modulemap
    if ! xcf_validate_modulemap "$xcframework_path" "$module_name" "$log_tag"; then
        return 1
    fi

    # Check for hardcoded paths (optional, based on strict mode)
    xcf_validate_no_hardcoded_paths "$xcframework_path" "$log_tag"
    # Note: This is non-fatal unless strict mode is enabled

    _xcf_validate_log "success" "$log_tag" "✓ Content validation passed"
    return 0
}

# ============================================================================
# Validate Full
# ============================================================================
# Complete validation combining structure and content checks
#
# Args:
#   $1: xcframework_path - Path to .xcframework directory
#   $2: module_name - Expected module name (optional)
#   $3: log_tag - Optional log tag
#
# Returns:
#   0 if valid, 1 if invalid
# ============================================================================
xcf_validate_full() {
    local xcframework_path="$1"
    local module_name="${2:-}"
    local log_tag="${3:-XCF}"

    _xcf_validate_log "info" "$log_tag" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    _xcf_validate_log "info" "$log_tag" "Full Validation: $(basename "$xcframework_path")"
    _xcf_validate_log "info" "$log_tag" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Validate structure
    _xcf_validate_log "info" "$log_tag" ""
    _xcf_validate_log "info" "$log_tag" "Step 1: Structure validation"
    if ! xcf_validate_structure "$xcframework_path" "$log_tag"; then
        _xcf_validate_log "error" "$log_tag" "✗ Full validation failed (structure)"
        return 1
    fi

    # Validate content (if module name provided)
    if [[ -n "$module_name" ]]; then
        _xcf_validate_log "info" "$log_tag" ""
        _xcf_validate_log "info" "$log_tag" "Step 2: Content validation"
        if ! xcf_validate_content "$xcframework_path" "$module_name" "$log_tag"; then
            _xcf_validate_log "error" "$log_tag" "✗ Full validation failed (content)"
            return 1
        fi
    fi

    _xcf_validate_log "success" "$log_tag" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    _xcf_validate_log "success" "$log_tag" "Full Validation Passed ✓"
    _xcf_validate_log "success" "$log_tag" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    return 0
}

# ============================================================================
# Validate Multiple XCFrameworks
# ============================================================================
# Validates multiple XCFrameworks in batch
#
# Args:
#   $1: log_tag - Log tag
#   $@: xcframework_paths - Array of XCFramework paths
#
# Returns:
#   0 if all valid, 1 if any invalid
# ============================================================================
xcf_validate_batch() {
    local log_tag="$1"
    shift
    local xcframework_paths=("$@")

    local total=${#xcframework_paths[@]}
    local passed=0
    local failed=0

    _xcf_validate_log "info" "$log_tag" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    _xcf_validate_log "info" "$log_tag" "Batch Validation: $total XCFrameworks"
    _xcf_validate_log "info" "$log_tag" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for xcf_path in "${xcframework_paths[@]}"; do
        if xcf_validate_structure "$xcf_path" "$log_tag"; then
            ((passed++)) || true
        else
            ((failed++)) || true
        fi
    done

    _xcf_validate_log "info" "$log_tag" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    _xcf_validate_log "info" "$log_tag" "Results: $passed passed, $failed failed"
    _xcf_validate_log "info" "$log_tag" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ $failed -gt 0 ]]; then
        return 1
    fi

    return 0
}

# ============================================================================
# Export Functions
# ============================================================================

export -f xcf_validate_exists 2>/dev/null || true
export -f xcf_validate_slices 2>/dev/null || true
export -f xcf_validate_info_plist 2>/dev/null || true
export -f xcf_validate_structure 2>/dev/null || true
export -f xcf_validate_modulemap 2>/dev/null || true
export -f xcf_validate_no_hardcoded_paths 2>/dev/null || true
export -f xcf_validate_content 2>/dev/null || true
export -f xcf_validate_full 2>/dev/null || true
export -f xcf_validate_batch 2>/dev/null || true
