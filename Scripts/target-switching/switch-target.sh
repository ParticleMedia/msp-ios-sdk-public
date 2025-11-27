#!/usr/bin/env bash
# ============================================================================
# Target Switching Script - Intelligent Mode Switcher
# ============================================================================
# Purpose: Switch between CocoaPods and Swift Package Manager (SPM) targets.
#          Ensures both modes build successfully with proper validation.
#
# Usage:   ./Scripts/target-switching/switch-target.sh [spm|pods]
# ============================================================================

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/target-switching/common.sh
source "$SCRIPT_DIR/common.sh"

ensure_repo_root

TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
    log_info "Usage: $0 [spm|pods]"
    log_info ""
    log_info "Examples:"
    log_info "  $0 spm    # Switch to Swift Package Manager"
    log_info "  $0 pods   # Switch to CocoaPods"
    exit 1
fi

if [[ "$TARGET" != "spm" ]] && [[ "$TARGET" != "pods" ]]; then
    log_error "Invalid target. Must be 'spm' or 'pods'"
    exit 1
fi

# Display title
if [[ "$TARGET" == "spm" ]]; then
    log_title "Switching to Swift Package Manager (SPM)"
else
    log_title "Switching to CocoaPods"
fi

log_info "Repository: $ROOT_DIR"

# ============================================================================
# INTELLIGENT MODE DETECTION
# ============================================================================

# Detect current mode before switching
CURRENT_MODE=$(detect_current_mode)
if [[ "$CURRENT_MODE" == "$TARGET" ]]; then
    log_warn "Already in $TARGET mode"
    log_info "Re-running switch to ensure clean state..."
elif [[ "$CURRENT_MODE" == "mixed" ]]; then
    log_warn "Detected mixed environment (both SPM and Pods artifacts present)"
    log_info "This will be cleaned up during switch..."
fi

# ============================================================================
# SPM TARGET SWITCHING
# ============================================================================

if [[ "$TARGET" == "spm" ]]; then
    log_section "Environment Cleanup"
    
    # Step 1: Clean CocoaPods
    log_step "Cleaning CocoaPods environment"
    
    # Remove CocoaPods workspace first (may hold references to Pods)
    if [[ -d "$PODS_WORKSPACE" ]]; then
        if grep -q "Pods/Pods.xcodeproj" "$PODS_WORKSPACE/contents.xcworkspacedata" 2>/dev/null; then
            if safe_remove_workspace "$PODS_WORKSPACE"; then
                log_success "CocoaPods workspace removed"
            else
                log_error "Failed to remove CocoaPods workspace"
                exit 1
            fi
        else
            if safe_remove_workspace "$PODS_WORKSPACE"; then
                log_success "Stale workspace removed"
            else
                log_warn "Failed to remove workspace (may not be CocoaPods workspace)"
            fi
        fi
    else
        log_info "CocoaPods workspace already removed"
    fi
    
    # Remove Pods directory (after workspace to avoid lock issues)
    if [[ -d "$PODS_DIR" ]]; then
        if safe_remove_directory "$PODS_DIR" "Pods"; then
            log_success "Pods/ removed"
        else
            log_error "Failed to remove Pods/ directory"
            log_info "This may be due to file locks. Try closing Xcode and retrying."
            exit 1
        fi
    else
        log_info "Pods/ already removed"
    fi
    
    # Step 1.5: Restore Package.swift if it was disabled
    log_section "Restoring Package.swift"
    log_step "Checking for Package.swift.disabled"
    if [[ -f "$ROOT_DIR/Package.swift.disabled" ]]; then
        mv "$ROOT_DIR/Package.swift.disabled" "$ROOT_DIR/Package.swift"
        log_success "Package.swift restored from Package.swift.disabled"
    elif [[ -f "$ROOT_DIR/Package.swift" ]]; then
        log_info "Package.swift already exists"
    else
        log_error "Package.swift not found! SPM mode requires Package.swift"
        log_info "Try: git checkout Package.swift"
        exit 1
    fi
    
    # Step 2: Clean SPM
    log_step "Cleaning SwiftPM environment"
    if "$SCRIPT_DIR/cleanup_spm.sh" --force; then
        log_success "SPM cleanup completed"
    else
        log_warn "SPM cleanup had warnings (continuing)"
    fi
    
    # Step 3: Verify required XCFrameworks using validate_xcframeworks.sh
    log_section "XCFramework Validation"
    
    log_step "Running XCFramework validation"
    if "$SCRIPT_DIR/validate_xcframeworks.sh"; then
        log_success "All XCFrameworks validated successfully"
    else
        log_warn "XCFramework validation failed - some required XCFrameworks are missing"
        log_info ""
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "Auto-syncing XCFrameworks from CocoaPods..."
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Auto-run spm_sync_all.sh to fetch missing XCFrameworks
        SPM_SYNC_SCRIPT="$ROOT_DIR/Scripts/spm-sync/spm_sync_all.sh"
        if [[ -x "$SPM_SYNC_SCRIPT" ]]; then
            log_step "Running spm_sync_all.sh to extract XCFrameworks from Pods"
            if "$SPM_SYNC_SCRIPT"; then
                log_success "XCFramework sync completed"
                
                # Re-validate after sync
                log_step "Re-validating XCFrameworks after sync"
                if "$SCRIPT_DIR/validate_xcframeworks.sh"; then
                    log_success "All XCFrameworks now validated successfully"
                else
                    log_error "XCFramework validation still failing after sync"
                    log_error "Please check the output above and manually resolve the issues"
                    exit 1
                fi
            else
                log_error "spm_sync_all.sh failed"
                log_info ""
                log_info "Manual fix required:"
                log_info "  1. Run: pod install"
                log_info "  2. Run: ./Scripts/spm-sync/spm_sync_all.sh"
                log_info "  3. Build Core XCFrameworks: ./Scripts/xcframeworks/build-core.sh"
                log_info "  4. Then retry: ./Scripts/target-switching/switch-target.sh spm"
                exit 1
            fi
        else
            log_error "spm_sync_all.sh not found or not executable: $SPM_SYNC_SCRIPT"
            log_info ""
            log_info "Required XCFrameworks for SPM mode:"
            log_info "  - Build/XCFrameworks/MSPSharedLibraries.xcframework"
            log_info "  - Build/XCFrameworks/MSPiOSCore.xcframework"
            log_info "  - Build/XCFrameworks/NovaCore.xcframework"
            log_info "  - Build/XCFrameworks/MSPCore.xcframework"
            log_info "  - Build/XCFrameworks/MSPOMSDK.xcframework"
            log_info "  - ThirdParty/PrebidMobile/PrebidMobile.xcframework"
            exit 1
        fi
    fi
    
    # Step 4: Generate YAML specs
    log_section "YAML Generation"
    log_step "Generating YAML specs"
    if "$SCRIPT_DIR/generate_workspace.sh" spm; then
        log_success "YAML specs generated"
    else
        log_error "YAML generation failed"
        exit 1
    fi
    
    # Step 5: Generate Xcode project from YAML
    log_section "Xcode Project Generation"
    log_step "Generating Xcode project from YAML"
    if command -v xcodegen &>/dev/null; then
        if xcodegen generate --spec "$PROJECT_SPEC" 2>&1; then
            log_success "Xcode project regenerated successfully"
        else
            log_fatal "Xcode project generation failed"
            exit 1
        fi
    else
        log_fatal "xcodegen not found. Install via: brew install xcodegen"
        exit 1
    fi
    
    # Step 6: Generate workspace
    if [[ -f "$ROOT_DIR/Scripts/tools/generate-workspace.sh" ]]; then
        log_step "Generating workspace"
        if "$ROOT_DIR/Scripts/tools/generate-workspace.sh" 2>&1; then
            log_success "Workspace generated"
        else
            log_warn "Workspace generation had issues (continuing)"
        fi
    fi
    
    # Step 7: Final XCFramework verification and MSPOMSDK validation
    log_section "Final Verification"
    log_step "Verifying all required XCFrameworks"
    if ! check_required_xcframeworks >/dev/null 2>&1; then
        errors=$?
        log_error "$errors required XCFramework(s) missing - SPM mode cannot proceed"
        check_required_xcframeworks 2>&1 | grep -E "missing:|invalid:" || true
        exit 1
    fi
    log_success "All required XCFrameworks verified"
    
    # Validate MSPOMSDK.xcframework specifically (critical for SPM mode)
    log_step "Validating MSPOMSDK.xcframework"
    mspomsdk_xcf="$ROOT_DIR/Build/XCFrameworks/MSPOMSDK.xcframework"
    omsdk_xcf="$ROOT_DIR/Sources/Core/MSPOMSDK/OMSDK_Newsbreak1.xcframework"
    if [[ ! -d "$mspomsdk_xcf" ]]; then
        log_error "MSPOMSDK.xcframework is missing from Build/XCFrameworks/"
        log_error "This XCFramework is required for SPM mode"
        exit 1
    elif [[ ! -f "$mspomsdk_xcf/Info.plist" ]]; then
        log_error "MSPOMSDK.xcframework is invalid (missing Info.plist)"
        log_error "Re-build: ./Scripts/xcframeworks/build-core.sh"
        exit 1
    else
        log_success "MSPOMSDK.xcframework validated"
    fi
    
    # Also check embedded OMSDK
    if [[ ! -d "$omsdk_xcf" ]]; then
        log_warn "OMSDK_Newsbreak1.xcframework missing from Sources/Core/MSPOMSDK/"
    else
        log_success "OMSDK_Newsbreak1.xcframework present"
    fi
    
    # Step 8: Validate environment (SPM mode specific checks)
    log_section "Environment Validation"
    log_step "Validating SPM environment"
    if validate_environment "spm"; then
        log_success "Environment validation passed"
    else
        errors=$?
        log_error "Environment validation failed ($errors error(s))"
        log_info "SPM mode requires:"
        log_info "  - No Pods/ directory"
        log_info "  - MSPDemoApp-SPM target in project.yml"
        log_info "  - All required XCFrameworks present"
        exit 1
    fi
    
    # Step 9: Open Xcode
    log_section "Opening Xcode"
    log_step "Opening Xcode"
    PROJECT_DIR="$(dirname "$PROJECT_SPEC")"
    if [[ -d "$PROJECT_DIR/MSPDemoApp.xcodeproj" ]]; then
        open "$PROJECT_DIR/MSPDemoApp.xcodeproj"
        log_success "Xcode opened with SPM project"
    else
        log_error "Xcode project not found: $PROJECT_DIR/MSPDemoApp.xcodeproj"
        exit 1
    fi

# ============================================================================
# COCOAPODS TARGET SWITCHING
# ============================================================================

elif [[ "$TARGET" == "pods" ]]; then
    log_section "Environment Cleanup"
    
    # Step 1: Clean SPM
    log_step "Cleaning SwiftPM environment"
    if "$SCRIPT_DIR/cleanup_spm.sh" --force; then
        log_success "SPM cleanup completed"
    else
        log_warn "SPM cleanup had warnings (continuing)"
    fi
    
    # Step 1.5: CRITICAL - Disable Package.swift to prevent Xcode from auto-detecting SPM
    log_section "Disabling Package.swift"
    log_step "Renaming Package.swift to Package.swift.disabled"
    if [[ -f "$ROOT_DIR/Package.swift" ]]; then
        mv "$ROOT_DIR/Package.swift" "$ROOT_DIR/Package.swift.disabled"
        log_success "Package.swift renamed to Package.swift.disabled"
        log_info "This prevents Xcode from auto-detecting SPM packages in Pods mode"
    elif [[ -f "$ROOT_DIR/Package.swift.disabled" ]]; then
        log_info "Package.swift already disabled"
    else
        log_warn "Package.swift not found (may need to restore from git)"
    fi
    
    # Remove SPM workspace (if it exists and is SPM-only)
    if [[ -d "$SPM_WORKSPACE" ]]; then
        if ! grep -q "Pods/Pods.xcodeproj" "$SPM_WORKSPACE/contents.xcworkspacedata" 2>/dev/null; then
            safe_remove_workspace "$SPM_WORKSPACE"
            log_success "SPM workspace removed"
        else
            log_info "Workspace contains Pods (will be regenerated by pod install)"
        fi
    else
        log_info "SPM workspace already removed"
    fi
    
    # Step 2: Ensure MSPiOSCore.xcframework exists (required for adapters)
    log_section "XCFramework Prerequisites"
    log_step "Checking MSPiOSCore.xcframework"
    if [[ ! -d "$ROOT_DIR/Sources/Core/MSPSharedLibraries/MSPiOSCore.xcframework" ]] && [[ ! -d "$ROOT_DIR/Build/XCFrameworks/MSPiOSCore.xcframework" ]]; then
        log_warn "MSPiOSCore.xcframework missing - building it now"
        BUILD_IOSCORE_SCRIPT="$ROOT_DIR/Scripts/xcframeworks/internal/build-ioscore.sh"
        if [[ -f "$BUILD_IOSCORE_SCRIPT" ]]; then
            log_info "Building MSPiOSCore.xcframework..."
            if SKIP_CODE_SIGN="${SKIP_CODE_SIGN:-1}" bash "$BUILD_IOSCORE_SCRIPT" 2>&1; then
                log_success "MSPiOSCore.xcframework built successfully"
            else
                log_error "Failed to build MSPiOSCore.xcframework"
                log_error "Adapters require MSPiOSCore - Pods mode cannot proceed"
                exit 1
            fi
        else
            log_error "MSPiOSCore build script not found: $BUILD_IOSCORE_SCRIPT"
            exit 1
        fi
    else
        log_success "MSPiOSCore.xcframework found"
    fi
    
    # Step 3: Clean and install CocoaPods
    log_section "CocoaPods Installation"
    log_step "Cleaning and installing CocoaPods"
    if "$SCRIPT_DIR/cleanup_pods.sh"; then
        log_success "CocoaPods environment cleaned and reinstalled"
    else
        cleanup_exit=$?
        log_warn "CocoaPods cleanup had issues (exit code: $cleanup_exit)"
        # Check if Pods directory exists (critical for Pods mode)
        if [[ ! -d "$PODS_DIR" ]]; then
            log_error "Pods/ directory missing after cleanup - Pods mode cannot continue"
            exit 1
        fi
        log_info "Continuing despite cleanup warnings (Pods/ exists)"
    fi
    
    # Step 4: Generate YAML specs (needed for workspace generation)
    log_section "YAML Generation"
    log_step "Generating YAML specs"
    if "$SCRIPT_DIR/generate_workspace.sh" pods; then
        log_success "YAML specs generated"
    else
        log_error "YAML generation failed"
        exit 1
    fi
    
    # Step 6: Generate Xcode project from YAML
    log_section "Xcode Project Generation"
    log_step "Generating Xcode project from YAML"
    if command -v xcodegen &>/dev/null; then
        if xcodegen generate --spec "$PROJECT_SPEC" 2>&1; then
            log_success "Xcode project regenerated successfully"
        else
            log_fatal "Xcode project generation failed"
            exit 1
        fi
    else
        log_fatal "xcodegen not found. Install via: brew install xcodegen"
        exit 1
    fi
    
    # Step 7: Generate workspace (required for NovaCore build)
    if [[ -f "$ROOT_DIR/Scripts/tools/generate-workspace.sh" ]]; then
        log_step "Generating workspace"
        if "$ROOT_DIR/Scripts/tools/generate-workspace.sh" 2>&1; then
            log_success "Workspace generated"
        else
            log_warn "Workspace generation had issues (continuing)"
        fi
    fi
    
    # Step 8: Check Core XCFrameworks (Pods mode only - optionally build if missing)
    log_section "Core XCFramework Check"
    log_step "Checking Core XCFrameworks"
    
    core_xcframeworks_missing=0
    for xcf in "MSPSharedLibraries" "MSPiOSCore" "NovaCore" "MSPCore" "MSPOMSDK"; do
        if [[ ! -d "$ROOT_DIR/Build/XCFrameworks/${xcf}.xcframework" ]]; then
            log_warn "${xcf}.xcframework missing from Build/XCFrameworks/"
            ((core_xcframeworks_missing++))
        fi
    done
    
    if [[ $core_xcframeworks_missing -gt 0 ]]; then
        log_warn "$core_xcframeworks_missing Core XCFramework(s) missing"
        log_info "Core XCFrameworks can be built with: ./Scripts/xcframeworks/build-core.sh"
        log_info "Continuing with Pods mode setup..."
    else
        log_success "All Core XCFrameworks present"
    fi
    
    # Check ThirdParty/PrebidMobile
    if [[ ! -d "$ROOT_DIR/ThirdParty/PrebidMobile/PrebidMobile.xcframework" ]]; then
        log_warn "PrebidMobile.xcframework missing from ThirdParty/PrebidMobile/"
        log_info "This is required for MSPPrebidAdapter to compile"
    else
        log_success "PrebidMobile.xcframework present"
    fi
    
    # Step 9: Verify no SPM packages in project.yml (critical for Pods mode isolation)
    log_section "SPM Isolation Check"
    log_step "Verifying SPM packages are excluded from Pods mode"
    
    # Check if packages block exists and is empty
    packages_empty=false
    if grep -q "^packages: {}$" "$PROJECT_SPEC" 2>/dev/null; then
        packages_empty=true
    elif grep -q "^packages:$" "$PROJECT_SPEC" 2>/dev/null; then
        # Check if packages block has any entries
        if ! grep -A 20 "^packages:" "$PROJECT_SPEC" | grep -qE "^  [A-Za-z]"; then
            packages_empty=true
        fi
    else
        # No packages block at all - also acceptable for Pods mode
        packages_empty=true
    fi
    
    if [[ "$packages_empty" == "true" ]]; then
        log_success "SPM packages correctly excluded (Pods mode isolation verified)"
    else
        log_error "❌ CRITICAL: project.yml contains SPM packages in Pods mode"
        log_error ""
        log_error "Pods mode MUST have empty packages: {} to prevent SwiftPM resolution."
        log_error "SwiftPM resolution in Pods mode causes binary target errors."
        log_error ""
        log_error "Current packages block:"
        grep -A 10 "^packages:" "$PROJECT_SPEC" | head -15 || true
        log_error ""
        log_error "This is a YAML generation error. Check generate_workspace.sh"
        exit 1
    fi
    
    # Step 10: Validate environment (Pods mode specific checks)
    log_section "Environment Validation"
    log_step "Validating Pods environment"
    if validate_environment "pods"; then
        log_success "Environment validation passed"
    else
        errors=$?
        log_error "Environment validation failed ($errors error(s))"
        log_info "Pods mode requires:"
        log_info "  - Pods/ directory exists"
        log_info "  - Workspace contains Pods/Pods.xcodeproj"
        log_info "  - project.yml has packages: {} (no SPM packages)"
        log_info "  - MSPDemoApp target (not MSPDemoApp-SPM)"
        exit 1
    fi
    
    # Step 11: Open Xcode (workspace created by pod install or generate-workspace.sh)
    log_section "Opening Xcode"
    log_step "Opening Xcode workspace"
    if [[ -d "$PODS_WORKSPACE" ]]; then
        # Verify workspace contains Pods
        if grep -q "Pods/Pods.xcodeproj" "$PODS_WORKSPACE/contents.xcworkspacedata" 2>/dev/null; then
            open "$PODS_WORKSPACE"
            log_success "Xcode opened with CocoaPods workspace"
        else
            log_warn "Workspace exists but doesn't contain Pods - may need regeneration"
            open "$PODS_WORKSPACE"
        fi
    else
        log_warn "CocoaPods workspace not found. Opening project directory instead..."
        PROJECT_DIR="$(dirname "$PROJECT_SPEC")"
        if [[ -d "$PROJECT_DIR/MSPDemoApp.xcodeproj" ]]; then
            open "$PROJECT_DIR/MSPDemoApp.xcodeproj"
            log_warn "Opened project instead of workspace - Pods integration may be incomplete"
        else
            open "$PROJECT_DIR"
            log_warn "Opened directory - Xcode project may not be generated"
        fi
    fi
fi

# ============================================================================
# SUMMARY
# ============================================================================

log_title "Switching Complete"

log_success "Successfully switched to: $TARGET"

log_section "Next Steps"

if [[ "$TARGET" == "spm" ]]; then
    log_info "1. Wait for Xcode to resolve packages (File → Packages → Resolve Package Versions)"
    log_info "2. Build MSPDemoApp-SPM target (simulator or device)"
    log_info "3. Verify all XCFrameworks are correctly linked"
    log_info ""
    log_info "Note: If you see 'binary target does not contain a binary artifact' errors:"
    log_info "      - Verify all required XCFrameworks exist and have valid Info.plist"
    log_info "      - Check that XCFramework paths in Package.swift are correct"
else
    log_info "1. Build MSPDemoApp target (simulator or device)"
    log_info "2. Verify all adapters compile successfully"
    log_info "3. If NovaCore build failed, check Pods dependencies are installed"
    log_info ""
    log_info "Note: Pods mode requires:"
    log_info "      - All Pods dependencies installed (pod install completed)"
    log_info "      - Workspace includes Pods/Pods.xcodeproj"
    log_info "      - No SPM packages in project.yml (packages: {})"
fi

log_info ""
log_info "Note: YAML files (project.yml, workspace.yml) are the source of truth"
log_info "      Xcode project files (.pbxproj, .xcscheme) are auto-generated and may change"
log_info ""

# Check for generated file changes (informational only)
if [[ -f "$ROOT_DIR/Scripts/tools/check-project-diff.sh" ]]; then
    log_section "Project File Status"
    "$ROOT_DIR/Scripts/tools/check-project-diff.sh" || true
fi
