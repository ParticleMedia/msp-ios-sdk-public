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
# 2. CHECK MISSING OR BROKEN ARTIFACTS (Updated for new architecture - Round 26)
# ============================================================================

check_missing_artifacts() {
    print_section "2. Checking Missing or Broken Artifacts"
    
    # Check Core XCFrameworks
    local core_xcframeworks=(
        "Build/XCFrameworks/MSPSharedLibraries.xcframework"
        "Build/XCFrameworks/MSPiOSCore.xcframework"
        "Build/XCFrameworks/NovaCore.xcframework"
        "Build/XCFrameworks/MSPCore.xcframework"
        "Build/XCFrameworks/MSPOMSDK.xcframework"
    )
    
    for xcf in "${core_xcframeworks[@]}"; do
        local xcf_path="$ROOT_DIR/$xcf"
        local xcf_name="$(basename "$xcf")"
        
        if [[ -d "$xcf_path" ]]; then
            if [[ -f "$xcf_path/Info.plist" ]]; then
                print_ok "Core XCFramework valid: $xcf_name"
            else
                print_fail "Core XCFramework invalid (no Info.plist): $xcf_name"
            fi
        else
            print_fail "Core XCFramework missing: $xcf"
        fi
    done
    
    # Check ThirdParty XCFrameworks
    local thirdparty_xcframeworks=(
        "ThirdParty/PrebidMobile/PrebidMobile.xcframework"
    )
    
    for xcf in "${thirdparty_xcframeworks[@]}"; do
        local xcf_path="$ROOT_DIR/$xcf"
        local xcf_name="$(basename "$xcf")"
        
        if [[ -d "$xcf_path" ]]; then
            if [[ -f "$xcf_path/Info.plist" ]]; then
                print_ok "ThirdParty XCFramework valid: $xcf_name"
            else
                print_fail "ThirdParty XCFramework invalid (no Info.plist): $xcf_name"
            fi
        else
            print_fail "ThirdParty XCFramework missing: $xcf"
        fi
    done
    
    # Check Adapter Sources
    local adapters=(
        "Sources/Adapters/MSPPrebidAdapter/MSPPrebidAdapter"
        "Sources/Adapters/MSPGoogleAdapter/MSPGoogleAdapter"
        "Sources/Adapters/MSPFacebookAdapter/MSPFacebookAdapter"
        "Sources/Adapters/NovaAdapter/NovaAdapter"
        "Sources/Adapters/AmazonAdapter/AmazonAdapter"
        "Sources/Adapters/UnityAdapter/UnityAdapter"
        "Sources/Adapters/InmobiAdapter/InmobiAdapter"
        "Sources/Adapters/MobilefuseAdapter/MobilefuseAdapter"
        "Sources/Adapters/MintegralAdapter/MintegralAdapter"
        "Sources/Adapters/PubmaticAdapter/PubmaticAdapter"
    )
    
    for adapter in "${adapters[@]}"; do
        local adapter_path="$ROOT_DIR/$adapter"
        local adapter_name="$(basename "$adapter")"
        
        if [[ -d "$adapter_path" ]]; then
            local swift_count=$(find "$adapter_path" -name "*.swift" -type f 2>/dev/null | wc -l | tr -d ' ')
            if [[ $swift_count -gt 0 ]]; then
                print_ok "Adapter source valid: $adapter_name ($swift_count Swift files)"
            else
                print_fail "Adapter source empty (no Swift files): $adapter_name"
            fi
        else
            print_fail "Adapter source missing: $adapter"
        fi
    done
    
    # Check Package.swift
    if [[ -f "$ROOT_DIR/Package.swift" ]]; then
        print_ok "Package.swift exists"
    else
        print_fail "Package.swift missing"
    fi
}

# ============================================================================
# 3. CHECK XCFRAMEWORK VALIDITY (Updated for new architecture - Round 26)
# ============================================================================

check_wrapper_validity() {
    print_section "3. Checking XCFramework Validity"
    
    # Core XCFrameworks to validate
    local core_xcframeworks=(
        "Build/XCFrameworks/MSPSharedLibraries.xcframework"
        "Build/XCFrameworks/MSPiOSCore.xcframework"
        "Build/XCFrameworks/NovaCore.xcframework"
        "Build/XCFrameworks/MSPCore.xcframework"
        "Build/XCFrameworks/MSPOMSDK.xcframework"
        "ThirdParty/PrebidMobile/PrebidMobile.xcframework"
    )
    
    for xcf_rel in "${core_xcframeworks[@]}"; do
        local xcframework_path="$ROOT_DIR/$xcf_rel"
        local xcf_name="$(basename "$xcf_rel" .xcframework)"
        
        if [[ ! -d "$xcframework_path" ]]; then
            print_warn "Skipping validation: $xcf_rel not found"
            continue
        fi
        
        # Check xcframework structure
        if [[ ! -f "$xcframework_path/Info.plist" ]]; then
            print_fail "Invalid xcframework: $xcf_name missing Info.plist"
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
            print_fail "Missing iOS device slice (arm64): $xcf_name"
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
                        print_ok "Device slice valid (arm64): $xcf_name"
                    else
                        print_fail "Device slice missing arm64: $xcf_name"
                    fi
                else
                    print_warn "lipo not available, skipping architecture check"
                fi
            else
                print_fail "Framework binary not found: $xcf_name (device slice)"
            fi
        fi
        
        # Validate simulator slice
        if [[ -z "$ios_sim_slice" ]]; then
            print_warn "Missing iOS simulator slice: $xcf_name"
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
                        print_ok "Simulator slice valid: $xcf_name ($archs)"
                    else
                        print_fail "Simulator slice missing arm64/x86_64: $xcf_name"
                    fi
                else
                    print_warn "lipo not available, skipping architecture check"
                fi
            else
                print_fail "Framework binary not found: $xcf_name (simulator slice)"
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
    # Note: This script uses validation-helpers.sh functions (print_section, print_ok, print_fail)
    # which are separate from the target-switching UI system
    # shellcheck source=Scripts/target-switching/common.sh
    source "$SCRIPT_DIR/common.sh" 2>/dev/null || true
    
    if command -v log_title &>/dev/null; then
        log_title "Target Switching Validator"
        log_info "Repository: $ROOT_DIR"
    else
        echo "============================================================================"
        echo "Target Switching Validator"
        echo "============================================================================"
        echo ""
        echo "Repository: $ROOT_DIR"
        echo ""
    fi
    
    # Safety check
    if ! validate_repo_root "$ROOT_DIR"; then
        if command -v log_error &>/dev/null; then
            log_error "Not in MSP iOS SDK repository. Aborting."
        else
            echo -e "${RED}ERROR: Not in MSP iOS SDK repository. Aborting.${NC}" >&2
        fi
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

