#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Wrapper Package Validator
# ============================================================================
# Purpose: Validates all wrapper packages for correctness and completeness.
#
# Safety: Read-only validation. Never modifies files or directories.
#
# Usage:   ./Scripts/xcframeworks/validate-wrappers.sh
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/lib/paths.sh
source "$ROOT_DIR/Scripts/lib/paths.sh"
# shellcheck source=Scripts/lib/colors.sh
source "$ROOT_DIR/Scripts/lib/colors.sh"
# shellcheck source=Scripts/lib/ui.sh
source "$ROOT_DIR/Scripts/lib/ui.sh"
# shellcheck source=Scripts/lib/validation-helpers.sh
source "$ROOT_DIR/Scripts/lib/validation-helpers.sh"
# shellcheck source=Scripts/lib/wrapper-config.sh
source "$ROOT_DIR/Scripts/lib/wrapper-config.sh"

# Ensure logger functions are available in subprocess
# (Force reload by unsetting the guard variable, as parent may have already sourced)
if [[ -f "$ROOT_DIR/Scripts/release/utils/logger.sh" ]]; then
    unset MSP_LOGGER_LOADED
    # shellcheck source=Scripts/release/utils/logger.sh
    source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true
fi

init_paths
init_validation_counters

# ============================================================================
# 1. DIRECTORY CHECKS
# ============================================================================

check_directories() {
    print_section "1. Checking Directory Structure"
    
    for wrapper in "${WRAPPER_NAMES[@]}"; do
        local wrapper_dir="$ROOT_DIR/$wrapper"
        
        # Check wrapper directory exists
        if [[ ! -d "$wrapper_dir" ]]; then
            print_fail "Wrapper directory missing: $wrapper"
            continue
        fi
        
        print_ok "Wrapper directory exists: $wrapper"
        
        # Check Frameworks/ directory
        local frameworks_dir="$wrapper_dir/Frameworks"
        if [[ ! -d "$frameworks_dir" ]]; then
            print_fail "Frameworks/ directory missing: $wrapper/Frameworks"
        else
            print_ok "Frameworks/ directory exists: $wrapper"
        fi
        
        # Check Package.swift
        local package_swift="$wrapper_dir/Package.swift"
        if [[ ! -f "$package_swift" ]]; then
            print_fail "Package.swift missing: $wrapper/Package.swift"
        else
            print_ok "Package.swift exists: $wrapper"
        fi
    done
}

# ============================================================================
# 2. XCFRAMEWORK VALIDATION
# ============================================================================

check_xcframeworks() {
    print_section "2. Validating XCFrameworks"
    
    for wrapper in "${WRAPPER_NAMES[@]}"; do
        local wrapper_dir="$ROOT_DIR/$wrapper"
        local frameworks_dir="$wrapper_dir/Frameworks"
        local sdk_name
        sdk_name=$(get_sdk_name "$wrapper")
        
        if [[ -z "$sdk_name" ]]; then
            print_fail "Unknown SDK name for wrapper: $wrapper"
            continue
        fi
        
        # Find xcframeworks (check both temp and final locations)
        local xcframework_path=""
        local temp_path="$ROOT_DIR/Scripts/xcframeworks/output-temp/$wrapper/Frameworks/$sdk_name.xcframework"
        local final_path="$frameworks_dir/$sdk_name.xcframework"
        
        if [[ -d "$final_path" ]]; then
            xcframework_path="$final_path"
        elif [[ -d "$temp_path" ]]; then
            xcframework_path="$temp_path"
        fi
        
        if [[ -z "$xcframework_path" ]] || [[ ! -d "$xcframework_path" ]]; then
            print_fail "XCFramework missing: $wrapper/$sdk_name.xcframework"
            continue
        fi
        
        # Count xcframeworks in Frameworks directory
        local xcframework_count=$(find "$frameworks_dir" -maxdepth 1 -type d -name "*.xcframework" 2>/dev/null | wc -l | tr -d ' ')
        
        if [[ $xcframework_count -eq 0 ]]; then
            print_fail "No xcframeworks found in: $wrapper/Frameworks"
        elif [[ $xcframework_count -eq 1 ]]; then
            print_ok "Exactly 1 xcframework found: $wrapper"
        else
            print_warn "Multiple xcframeworks found ($xcframework_count): $wrapper/Frameworks"
        fi
        
        # Check Info.plist
        if [[ ! -f "$xcframework_path/Info.plist" ]]; then
            print_fail "Info.plist missing: $wrapper/$sdk_name.xcframework"
            continue
        fi
        
        # Check required slices
        local has_ios_device=false
        local has_ios_sim=false
        
        for slice in "$xcframework_path"/ios-*; do
            if [[ -d "$slice" ]]; then
                local slice_name="$(basename "$slice")"
                
                if [[ "$slice_name" == "ios-arm64" ]]; then
                    has_ios_device=true
                    print_ok "iOS device slice found: $wrapper (arm64)"
                    
                    # Check architecture
                    local framework_binary=""
                    for framework in "$slice"/*.framework; do
                        if [[ -d "$framework" ]]; then
                            local binary_name="$(basename "$framework" .framework)"
                            framework_binary="$framework/$binary_name"
                            break
                        fi
                    done
                    
                    if [[ -n "$framework_binary" ]] && [[ -f "$framework_binary" ]]; then
                        if command -v lipo &>/dev/null; then
                            local archs="$(lipo -archs "$framework_binary" 2>/dev/null || echo "")"
                            echo "    Architectures: $archs"
                            if [[ "$archs" == *"arm64"* ]]; then
                                print_ok "Device slice contains arm64: $wrapper"
                            else
                                print_fail "Device slice missing arm64: $wrapper"
                            fi
                        fi
                    fi
                elif [[ "$slice_name" == "ios-arm64_x86_64-simulator" ]] || [[ "$slice_name" == "ios-x86_64-simulator" ]]; then
                    has_ios_sim=true
                    print_ok "iOS simulator slice found: $wrapper ($slice_name)"
                    
                    # Check architecture
                    local framework_binary=""
                    for framework in "$slice"/*.framework; do
                        if [[ -d "$framework" ]]; then
                            local binary_name="$(basename "$framework" .framework)"
                            framework_binary="$framework/$binary_name"
                            break
                        fi
                    done
                    
                    if [[ -n "$framework_binary" ]] && [[ -f "$framework_binary" ]]; then
                        if command -v lipo &>/dev/null; then
                            local archs="$(lipo -archs "$framework_binary" 2>/dev/null || echo "")"
                            echo "    Architectures: $archs"
                            if [[ "$archs" == *"arm64"* ]] || [[ "$archs" == *"x86_64"* ]]; then
                                print_ok "Simulator slice contains required archs: $wrapper"
                            else
                                print_fail "Simulator slice missing arm64/x86_64: $wrapper"
                            fi
                        fi
                    fi
                fi
            fi
        done
        
        if [[ "$has_ios_device" == "false" ]]; then
            print_fail "Missing required slice: $wrapper (ios-arm64)"
        fi
        
        if [[ "$has_ios_sim" == "false" ]]; then
            print_fail "Missing required slice: $wrapper (ios-arm64_x86_64-simulator or ios-x86_64-simulator)"
        fi
    done
}

# ============================================================================
# 3. PACKAGE.SWIFT VALIDATION
# ============================================================================

check_package_swift() {
    print_section "3. Validating Package.swift Files"
    
    for wrapper in "${WRAPPER_NAMES[@]}"; do
        local package_swift="$ROOT_DIR/$wrapper/Package.swift"
        
        if [[ ! -f "$package_swift" ]]; then
            print_fail "Package.swift missing: $wrapper"
            continue
        fi
        
        # Check for binaryTarget
        if ! grep -q "binaryTarget" "$package_swift" 2>/dev/null; then
            print_fail "Package.swift missing binaryTarget: $wrapper"
        else
            print_ok "Package.swift contains binaryTarget: $wrapper"
        fi
        
        # Check framework path reference
        local sdk_name
        sdk_name=$(get_sdk_name "$wrapper")
        if [[ -n "$sdk_name" ]]; then
            local expected_path="Frameworks/$sdk_name.xcframework"
            if grep -q "$expected_path" "$package_swift" 2>/dev/null; then
                print_ok "Package.swift references correct path: $wrapper"
            else
                print_fail "Package.swift path mismatch: $wrapper (expected: $expected_path)"
            fi
        fi
        
        # Check for incorrect relative paths (e.g., ../)
        if grep -qE "\.\./" "$package_swift" 2>/dev/null; then
            print_warn "Package.swift contains relative paths (../): $wrapper"
        else
            print_ok "Package.swift uses correct paths: $wrapper"
        fi
    done
}

# ============================================================================
# 4. BUILDER SCRIPT VALIDATION
# ============================================================================

check_builder_scripts() {
    print_section "4. Validating Builder Scripts"
    
    # Check generic builder script
    local builder_script="$ROOT_DIR/Scripts/xcframeworks/builder.sh"
    if [[ -f "$builder_script" ]]; then
        if [[ -x "$builder_script" ]]; then
            print_ok "Generic builder script exists and is executable: builder.sh"
        else
            print_warn "Generic builder script not executable: builder.sh"
        fi
    else
        print_fail "Generic builder script missing: builder.sh"
    fi
    
    # Check wrapper-specific builder scripts
    for wrapper in "${WRAPPER_NAMES[@]}"; do
        local script_name
        script_name=$(get_builder_script "$wrapper")
        if [[ -z "$script_name" ]]; then
            continue
        fi
        
        local wrapper_script="$ROOT_DIR/Scripts/xcframeworks/wrappers/$script_name"
        
        if [[ -f "$wrapper_script" ]]; then
            if [[ -x "$wrapper_script" ]]; then
                print_ok "Builder script exists and is executable: $script_name"
            else
                print_warn "Builder script not executable: $script_name"
            fi
            
            # Check if it calls the generic builder
            if grep -q "builder.sh" "$wrapper_script" 2>/dev/null; then
                print_ok "Builder script calls generic builder: $script_name"
            else
                print_warn "Builder script may not call generic builder: $script_name"
            fi
        else
            print_fail "Builder script missing: $script_name"
        fi
    done
}

# ============================================================================
# 5. CHECK FOR STALE FILES
# ============================================================================

check_stale_files() {
    print_section "5. Checking for Stale Files"
    
    for wrapper in "${WRAPPER_NAMES[@]}"; do
        local frameworks_dir="$ROOT_DIR/$wrapper/Frameworks"
        
        if [[ ! -d "$frameworks_dir" ]]; then
            continue
        fi
        
        # Check if Frameworks/ is empty
        if [[ -z "$(ls -A "$frameworks_dir" 2>/dev/null)" ]]; then
            print_warn "Frameworks/ directory is empty: $wrapper"
        fi
        
        # Count xcframeworks
        local xcframework_count=$(find "$frameworks_dir" -maxdepth 1 -type d -name "*.xcframework" 2>/dev/null | wc -l | tr -d ' ')
        
        if [[ $xcframework_count -gt 1 ]]; then
            print_warn "Multiple xcframeworks found ($xcframework_count): $wrapper/Frameworks"
            echo "    Consider cleaning stale frameworks"
        fi
    done
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log_title "Wrapper Package Validator"
    log::info "XCFW" "Repository: $ROOT_DIR"
    
    # Safety check
    if ! validate_repo_root "$ROOT_DIR"; then
        log::error "XCFW" "Not in MSP iOS SDK repository. Aborting."
        exit 1
    fi
    
    # Run all checks
    check_directories
    check_xcframeworks
    check_package_swift
    check_builder_scripts
    check_stale_files
    
    # Print summary
    print_validation_summary
    
    # Print result and exit
    if print_validation_result; then
        exit 0
    else
        exit 1
    fi
}

main "$@"

