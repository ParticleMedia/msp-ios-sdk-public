#!/usr/bin/env bash
# ============================================================================
# Target Switching Validator
# ============================================================================
# Purpose: Validates environment before/after switching between CocoaPods
#          and Swift Package Manager (SPM) targets.
#
# Safety: Read-only validation. Never modifies files or directories.
#
# Usage:   ./Scripts/target-switching/switch-target-validator.sh
# ============================================================================

set -euo pipefail

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/lib/paths.sh
source "$ROOT_DIR/Scripts/lib/paths.sh"
# shellcheck source=Scripts/lib/colors.sh
source "$ROOT_DIR/Scripts/lib/colors.sh"
# shellcheck source=Scripts/lib/validation-helpers.sh
source "$ROOT_DIR/Scripts/lib/validation-helpers.sh"
# shellcheck source=Scripts/lib/wrapper-config.sh
source "$ROOT_DIR/Scripts/lib/wrapper-config.sh"

# Initialize paths and counters
init_paths
init_validation_counters

# Bold text
BOLD='\033[1m'

# ============================================================================
# 1. CHECK FOR ILLEGAL MIXED ENVIRONMENT
# ============================================================================

check_mixed_environment() {
    print_section "1. Checking for Illegal Mixed Environment"
    
    local has_swiftpm=false
    local has_pods=false
    local has_sourcepackages=false
    
    # Check for .swiftpm
    if find "$ROOT_DIR" -type d -name ".swiftpm" ! -path "*/Pods/*" ! -path "*/.git/*" -print -quit 2>/dev/null | grep -q .; then
        has_swiftpm=true
    fi
    
    # Check for Pods/
    if [[ -d "$ROOT_DIR/Pods" ]]; then
        has_pods=true
    fi
    
    # Check for SourcePackages/
    if find "$ROOT_DIR" -type d -name "SourcePackages" ! -path "*/Pods/*" ! -path "*/.git/*" -print -quit 2>/dev/null | grep -q .; then
        has_sourcepackages=true
    fi
    
    # Fail if .swiftpm exists AND Pods/ exists
    if [[ "$has_swiftpm" == "true" ]] && [[ "$has_pods" == "true" ]]; then
        print_fail "Illegal mixed environment: .swiftpm exists while Pods/ exists"
        echo "    Both SwiftPM and CocoaPods artifacts detected. Clean one before switching."
    else
        print_ok "No .swiftpm + Pods/ conflict"
    fi
    
    # Fail if SourcePackages/ exists while Pods/ exists
    if [[ "$has_sourcepackages" == "true" ]] && [[ "$has_pods" == "true" ]]; then
        print_fail "Illegal mixed environment: SourcePackages/ exists while Pods/ exists"
        echo "    SwiftPM SourcePackages detected alongside CocoaPods. Clean one before switching."
    else
        print_ok "No SourcePackages/ + Pods/ conflict"
    fi
    
    # Check for Pod headers in DerivedData for SPM target
    local derived_data="$HOME/Library/Developer/Xcode/DerivedData"
    if [[ -d "$derived_data" ]]; then
        local pod_headers_found=false
        while IFS= read -r -d '' header; do
            if [[ "$header" == *"Pods"* ]] && [[ "$header" == *"MSPDemoApp-SPM"* ]]; then
                pod_headers_found=true
                break
            fi
        done < <(find "$derived_data" -name "*.h" -type f -print0 2>/dev/null | head -c 4096 | tr '\0' '\n' | head -10 | tr '\n' '\0' || true)
        
        if [[ "$pod_headers_found" == "true" ]]; then
            print_fail "Pod headers found in DerivedData for SPM target"
            echo "    CocoaPods artifacts detected in SPM target's DerivedData. Clean DerivedData."
        else
            print_ok "No Pod headers in SPM DerivedData"
        fi
    fi
    
    # Check for .xcworkspace inside SPM folders
    local workspace_in_spm=false
    while IFS= read -r -d '' workspace; do
        if [[ "$workspace" != "$ROOT_DIR/msp-ios-sdk.xcworkspace"* ]] && \
           [[ "$workspace" != "$ROOT_DIR/Pods"* ]] && \
           [[ "$workspace" == "$ROOT_DIR"* ]]; then
            # Check if it's inside a Package.swift directory
            local workspace_dir="$(dirname "$workspace")"
            if [[ -f "$workspace_dir/Package.swift" ]] || [[ "$workspace_dir" == *"Wrapper"* ]]; then
                workspace_in_spm=true
                print_fail "Illegal .xcworkspace found in SPM folder: $workspace"
            fi
        fi
    done < <(find "$ROOT_DIR" -type d -name "*.xcworkspace" ! -path "*/Pods/*" ! -path "*/.git/*" -print0 2>/dev/null || true)
    
    if [[ "$workspace_in_spm" == "false" ]]; then
        print_ok "No .xcworkspace in SPM folders"
    fi
}

# ============================================================================
# 2. CHECK MISSING OR BROKEN ARTIFACTS
# ============================================================================

check_missing_artifacts() {
    print_section "2. Checking Missing or Broken Artifacts"
    
    for wrapper in "${WRAPPER_NAMES[@]}"; do
        local wrapper_dir="$ROOT_DIR/$wrapper"
        
        # Check wrapper directory exists
        if [[ ! -d "$wrapper_dir" ]]; then
            print_fail "Wrapper directory missing: $wrapper"
            continue
        fi
        
        # Check Frameworks/ directory exists
        local frameworks_dir="$wrapper_dir/Frameworks"
        if [[ ! -d "$frameworks_dir" ]]; then
            print_fail "Frameworks/ directory missing: $wrapper/Frameworks"
        else
            print_ok "Frameworks/ exists: $wrapper"
        fi
        
        # Determine expected xcframework name
        local sdk_name
        sdk_name=$(get_sdk_name "$wrapper")
        
        # Check xcframework exists (check both temp and final locations)
        local temp_path="$ROOT_DIR/Scripts/xcframeworks/output-temp/$wrapper/Frameworks/$sdk_name.xcframework"
        local final_path="$frameworks_dir/$sdk_name.xcframework"
        
        if [[ -d "$final_path" ]]; then
            print_ok "XCFramework exists: $wrapper/$sdk_name.xcframework"
        elif [[ -d "$temp_path" ]]; then
            print_ok "XCFramework exists (temp): $wrapper/$sdk_name.xcframework"
        else
            print_fail "XCFramework missing: $wrapper/$sdk_name.xcframework"
        fi
        
        # Check Package.swift exists
        local package_swift="$wrapper_dir/Package.swift"
        if [[ -f "$package_swift" ]]; then
            print_ok "Package.swift exists: $wrapper"
        else
            print_fail "Package.swift missing: $wrapper/Package.swift"
        fi
        
        # Check builder script exists
        local script_name
        script_name=$(get_builder_script "$wrapper")
        local builder_script=""
        if [[ -n "$script_name" ]]; then
            builder_script="Scripts/xcframeworks/wrappers/$script_name"
        fi
        
        if [[ -n "$builder_script" ]] && [[ -f "$ROOT_DIR/$builder_script" ]]; then
            print_ok "Builder script exists: $builder_script"
        elif [[ -n "$builder_script" ]]; then
            print_fail "Builder script missing: $builder_script"
        fi
    done
}

# ============================================================================
# 3. CHECK WRAPPER VALIDITY
# ============================================================================

check_wrapper_validity() {
    print_section "3. Checking Wrapper Validity"
    
    for wrapper in "${WRAPPER_NAMES[@]}"; do
        local wrapper_dir="$ROOT_DIR/$wrapper"
        local frameworks_dir="$wrapper_dir/Frameworks"
        
        # Determine expected xcframework name
        local sdk_name
        sdk_name=$(get_sdk_name "$wrapper")
        
        # Check both temp and final locations
        local xcframework_path=""
        if [[ -d "$frameworks_dir/$sdk_name.xcframework" ]]; then
            xcframework_path="$frameworks_dir/$sdk_name.xcframework"
        elif [[ -d "$ROOT_DIR/Scripts/xcframeworks/output-temp/$wrapper/Frameworks/$sdk_name.xcframework" ]]; then
            xcframework_path="$ROOT_DIR/Scripts/xcframeworks/output-temp/$wrapper/Frameworks/$sdk_name.xcframework"
        fi
        
        if [[ -z "$xcframework_path" ]] || [[ ! -d "$xcframework_path" ]]; then
            print_warn "Skipping validation: $wrapper/$sdk_name.xcframework not found"
            continue
        fi
        
        # Check xcframework structure
        if [[ ! -f "$xcframework_path/Info.plist" ]]; then
            print_fail "Invalid xcframework: $wrapper/$sdk_name.xcframework missing Info.plist"
            continue
        fi
        
        # Find iOS device and simulator slices
        local ios_device_slice=""
        local ios_sim_slice=""
        
        for slice in "$xcframework_path"/ios-*; do
            if [[ -d "$slice" ]]; then
                local slice_name="$(basename "$slice")"
                if [[ "$slice_name" == "ios-arm64" ]]; then
                    ios_device_slice="$slice"
                elif [[ "$slice_name" == "ios-arm64_x86_64-simulator" ]] || [[ "$slice_name" == "ios-x86_64-simulator" ]]; then
                    ios_sim_slice="$slice"
                fi
            fi
        done
        
        # Validate device slice
        if [[ -z "$ios_device_slice" ]]; then
            print_fail "Missing iOS device slice (arm64): $wrapper/$sdk_name.xcframework"
        else
            local framework_binary=""
            for framework in "$ios_device_slice"/*.framework; do
                if [[ -d "$framework" ]]; then
                    local binary_name="$(basename "$framework" .framework)"
                    framework_binary="$framework/$binary_name"
                    break
                fi
            done
            
            if [[ -n "$framework_binary" ]] && [[ -f "$framework_binary" ]]; then
                # Check architecture
                if command -v lipo &>/dev/null; then
                    local archs="$(lipo -archs "$framework_binary" 2>/dev/null || echo "")"
                    if [[ "$archs" == *"arm64"* ]]; then
                        print_ok "Device slice valid (arm64): $wrapper"
                    else
                        print_fail "Device slice missing arm64: $wrapper"
                    fi
                else
                    print_warn "lipo not available, skipping architecture check"
                fi
                
                # Check minimum iOS version
                if command -v otool &>/dev/null; then
                    local min_version="$(otool -l "$framework_binary" 2>/dev/null | grep -A 3 "LC_VERSION_MIN_IPHONEOS" | grep "version" | awk '{print $2}' | head -1 || echo "")"
                    if [[ -n "$min_version" ]]; then
                        local major_version="${min_version%%.*}"
                        if [[ "$major_version" -ge 12 ]]; then
                            print_ok "iOS minimum version >= 12.0: $wrapper (v$min_version)"
                        else
                            print_fail "iOS minimum version < 12.0: $wrapper (v$min_version)"
                        fi
                    else
                        print_warn "Could not determine iOS minimum version: $wrapper"
                    fi
                else
                    print_warn "otool not available, skipping iOS version check"
                fi
            else
                print_fail "Framework binary not found: $wrapper/$sdk_name.xcframework (device slice)"
            fi
        fi
        
        # Validate simulator slice
        if [[ -z "$ios_sim_slice" ]]; then
            print_warn "Missing iOS simulator slice: $wrapper/$sdk_name.xcframework"
        else
            local framework_binary=""
            for framework in "$ios_sim_slice"/*.framework; do
                if [[ -d "$framework" ]]; then
                    local binary_name="$(basename "$framework" .framework)"
                    framework_binary="$framework/$binary_name"
                    break
                fi
            done
            
            if [[ -n "$framework_binary" ]] && [[ -f "$framework_binary" ]]; then
                # Check architecture
                if command -v lipo &>/dev/null; then
                    local archs="$(lipo -archs "$framework_binary" 2>/dev/null || echo "")"
                    if [[ "$archs" == *"arm64"* ]] || [[ "$archs" == *"x86_64"* ]]; then
                        print_ok "Simulator slice valid: $wrapper ($archs)"
                    else
                        print_fail "Simulator slice missing arm64/x86_64: $wrapper"
                    fi
                else
                    print_warn "lipo not available, skipping architecture check"
                fi
            else
                print_fail "Framework binary not found: $wrapper/$sdk_name.xcframework (simulator slice)"
            fi
        fi
    done
}

# ============================================================================
# 4. CHECK .gitignore PROPERLY CONFIGURED
# ============================================================================

check_gitignore() {
    print_section "4. Checking .gitignore Configuration"
    
    local gitignore_file="$ROOT_DIR/.gitignore"
    
    if [[ ! -f "$gitignore_file" ]]; then
        print_fail ".gitignore file missing"
        return
    fi
    
    # Check for xcframework ignore patterns
    local has_xcframework_pattern=false
    if grep -qE "\*\*/\*\.xcframework|\.xcframework" "$gitignore_file" 2>/dev/null; then
        has_xcframework_pattern=true
    fi
    
    if [[ "$has_xcframework_pattern" == "true" ]]; then
        print_ok ".gitignore contains xcframework ignore patterns"
    else
        print_warn ".gitignore missing xcframework ignore patterns"
    fi
    
    # Check for tracked xcframeworks
    local tracked_xcframeworks=0
    while IFS= read -r -d '' file; do
        if [[ "$file" == *".xcframework"* ]]; then
            ((tracked_xcframeworks++))
            if [[ $tracked_xcframeworks -eq 1 ]]; then
                print_warn "Tracked xcframeworks found (showing first few):"
            fi
            if [[ $tracked_xcframeworks -le 5 ]]; then
                echo "    $file"
            fi
        fi
    done < <(cd "$ROOT_DIR" && git ls-files -z 2>/dev/null || true)
    
    if [[ $tracked_xcframeworks -eq 0 ]]; then
        print_ok "No tracked xcframeworks in git"
    elif [[ $tracked_xcframeworks -gt 5 ]]; then
        echo "    ... and $((tracked_xcframeworks - 5)) more"
    fi
}

# ============================================================================
# 5. CHECK FOR STALE CACHE FOLDERS
# ============================================================================

check_stale_caches() {
    print_section "5. Checking for Stale Cache Folders"
    
    # Check for .swiftpm/
    local swiftpm_count=0
    while IFS= read -r -d '' dir; do
        if [[ "$dir" == "$ROOT_DIR"* ]]; then
            ((swiftpm_count++))
            if [[ $swiftpm_count -eq 1 ]]; then
                print_warn "Stale .swiftpm/ directories found:"
            fi
            if [[ $swiftpm_count -le 3 ]]; then
                echo "    ${dir#$ROOT_DIR/}"
            fi
        fi
    done < <(find "$ROOT_DIR" -type d -name ".swiftpm" ! -path "*/Pods/*" ! -path "*/.git/*" -print0 2>/dev/null || true)
    
    if [[ $swiftpm_count -eq 0 ]]; then
        print_ok "No .swiftpm/ directories found"
    elif [[ $swiftpm_count -gt 3 ]]; then
        echo "    ... and $((swiftpm_count - 3)) more"
    fi
    
    # Check for SourcePackages/
    local sourcepackages_count=0
    while IFS= read -r -d '' dir; do
        if [[ "$dir" == "$ROOT_DIR"* ]]; then
            ((sourcepackages_count++))
            if [[ $sourcepackages_count -eq 1 ]]; then
                print_warn "Stale SourcePackages/ directories found:"
            fi
            if [[ $sourcepackages_count -le 3 ]]; then
                echo "    ${dir#$ROOT_DIR/}"
            fi
        fi
    done < <(find "$ROOT_DIR" -type d -name "SourcePackages" ! -path "*/Pods/*" ! -path "*/.git/*" -print0 2>/dev/null || true)
    
    if [[ $sourcepackages_count -eq 0 ]]; then
        print_ok "No SourcePackages/ directories found"
    elif [[ $sourcepackages_count -gt 3 ]]; then
        echo "    ... and $((sourcepackages_count - 3)) more"
    fi
    
    # Check for DerivedData/ in repo
    if [[ -d "$ROOT_DIR/DerivedData" ]]; then
        print_warn "DerivedData/ directory found in repository"
        echo "    Consider removing: rm -rf DerivedData/"
    else
        print_ok "No DerivedData/ in repository"
    fi
    
    # Recommend cleanup if any stale caches found
    if [[ $swiftpm_count -gt 0 ]] || [[ $sourcepackages_count -gt 0 ]] || [[ -d "$ROOT_DIR/DerivedData" ]]; then
        echo ""
        echo "    ${YELLOW}Recommendation:${NC} Run cleanup script:"
        echo "    ./Scripts/cleanup-swiftpm-caches.sh"
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    echo "============================================================================"
    echo "${BOLD}Target Switching Validator${NC}"
    echo "============================================================================"
    echo ""
    echo "Repository: $ROOT_DIR"
    echo ""
    
# Safety check
if ! validate_repo_root "$ROOT_DIR"; then
    echo -e "${RED}ERROR: Not in MSP iOS SDK repository. Aborting.${NC}" >&2
    exit 1
fi
    
    # Run all checks
    check_mixed_environment
    check_missing_artifacts
    check_wrapper_validity
    check_gitignore
    check_stale_caches
    
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

