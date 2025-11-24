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
    
    # Step 2: Clean SPM
    log_step "Cleaning SwiftPM environment"
    if "$SCRIPT_DIR/cleanup_spm.sh" --force; then
        log_success "SPM cleanup completed"
    else
        log_warn "SPM cleanup had warnings (continuing)"
    fi
    
    # Step 3: Verify required XCFrameworks (DO NOT build NovaCore in SPM mode)
    log_section "XCFramework Validation"
    
    # Check wrapper XCFrameworks (non-blocking warning)
    log_step "Checking wrapper XCFrameworks"
    wrapper_missing=0
    if ! check_xcframeworks_exist >/dev/null 2>&1; then
        wrapper_missing=$?
    fi
    if [[ $wrapper_missing -gt 0 ]]; then
        log_warn "$wrapper_missing wrapper(s) missing XCFrameworks"
        log_info "Wrapper XCFrameworks are optional but recommended for SPM mode"
        log_info "To build wrapper XCFrameworks:"
        log_info "  1. Switch to Pods mode: ./Scripts/target-switching/switch-target.sh pods"
        log_info "  2. Build wrappers: Scripts/xcframeworks/build-all.sh"
        log_info "  3. Switch back to SPM mode"
    else
        log_success "All wrapper XCFrameworks present"
    fi
    
    # Check required XCFrameworks (blocking - SPM mode cannot proceed without these)
    log_step "Checking required XCFrameworks"
    required_missing=0
    check_required_xcframeworks >/dev/null 2>&1 || required_missing=$?
    
    if [[ $required_missing -gt 0 ]]; then
        log_error "$required_missing required XCFramework(s) missing"
        
        # Check specifically for NovaCore with detailed error message
        if [[ ! -d "$ROOT_DIR/NovaAdapter/NovaCore.xcframework" ]]; then
            log_error "❌ NovaCore.xcframework is MISSING"
            log_info ""
            log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log_info "NovaCore.xcframework MUST be built in Pods mode."
            log_info "It requires Pods dependencies: Kingfisher, SnapKit, Shimmer, lottie-ios, MSPOMSDK"
            log_info ""
            log_info "SPM mode CANNOT build NovaCore (no Pods dependencies available)."
            log_info ""
            log_info "To fix this:"
            log_info "  1. Run: ./Scripts/target-switching/switch-target.sh pods"
            log_info "  2. NovaCore will be built automatically during Pods mode setup"
            log_info "  3. Then run: ./Scripts/target-switching/switch-target.sh spm"
            log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            exit 1
        fi
        
        # Check other required XCFrameworks with detailed output
        log_error "Other missing required XCFrameworks:"
        check_required_xcframeworks 2>&1 | grep -E "missing:|invalid:" || true
        log_error ""
        log_error "All required XCFrameworks must exist before SPM mode can proceed."
        log_error "Missing XCFrameworks must be built or copied manually."
        exit 1
    fi
    
    # Validate XCFramework integrity (check Info.plist exists)
    log_step "Validating XCFramework integrity"
    local invalid_count=0
    local required_xcframeworks=(
        "MSPSharedLibraries/PrebidMobile.xcframework"
        "MSPSharedLibraries/OMSDK_Newsbreak1.xcframework"
        "MSPOMSDK/OMSDK_Newsbreak1.xcframework"
        "NovaAdapter/NovaCore.xcframework"
    )
    
    for xcf in "${required_xcframeworks[@]}"; do
        local xcf_path="$ROOT_DIR/$xcf"
        if [[ ! -f "$xcf_path/Info.plist" ]]; then
            log_error "Invalid XCFramework (missing Info.plist): $xcf"
            ((invalid_count++))
        fi
    done
    
    if [[ $invalid_count -gt 0 ]]; then
        log_error "$invalid_count XCFramework(s) are invalid or corrupted"
        log_error "Re-build the affected XCFrameworks in Pods mode"
        exit 1
    fi
    
    log_success "All required XCFrameworks present and valid"
    
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
    local mspomsdk_xcf="$ROOT_DIR/MSPOMSDK/OMSDK_Newsbreak1.xcframework"
    if [[ ! -d "$mspomsdk_xcf" ]]; then
        log_error "MSPOMSDK.xcframework (OMSDK_Newsbreak1.xcframework) is missing"
        log_error "This XCFramework is required for SPM mode"
        exit 1
    elif [[ ! -f "$mspomsdk_xcf/Info.plist" ]]; then
        log_error "MSPOMSDK.xcframework is invalid (missing Info.plist)"
        log_error "Re-build or restore this XCFramework"
        exit 1
    else
        log_success "MSPOMSDK.xcframework validated"
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
        local cleanup_exit=$?
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
    
    # Step 8: Build NovaCore.xcframework (Pods mode only - requires Pods dependencies and workspace)
    log_section "NovaCore XCFramework Build"
    log_step "Checking NovaCore.xcframework"
    if [[ ! -d "$ROOT_DIR/Sources/Adapters/NovaAdapter/NovaCore.xcframework" ]] && [[ ! -d "$ROOT_DIR/Build/XCFrameworks/NovaCore.xcframework" ]]; then
        log_warn "NovaCore.xcframework missing - building it now"
        log_info "NovaCore requires Pods dependencies (Kingfisher, SnapKit, Shimmer, lottie-ios, MSPOMSDK)"
        log_info "Building from workspace to ensure Pods are available"
        
        # Verify workspace exists (required for NovaCore build)
        if [[ ! -d "$PODS_WORKSPACE" ]]; then
            log_error "Workspace not found - cannot build NovaCore"
            log_error "Workspace is required for NovaCore build (includes Pods projects)"
            exit 1
        fi
        
        BUILD_NOVA_SCRIPT="$ROOT_DIR/Scripts/xcframeworks/internal/build-nova.sh"
        if [[ -f "$BUILD_NOVA_SCRIPT" ]]; then
            log_info "Building NovaCore.xcframework from workspace..."
            if SKIP_CODE_SIGN="${SKIP_CODE_SIGN:-1}" bash "$BUILD_NOVA_SCRIPT" 2>&1; then
                log_success "NovaCore.xcframework built successfully"
            else
                log_error "Failed to build NovaCore.xcframework"
                log_error "NovaCore build requires Pods dependencies and workspace - ensure pod install completed successfully"
                exit 1
            fi
        else
            log_error "NovaCore build script not found: $BUILD_NOVA_SCRIPT"
            exit 1
        fi
    else
        log_success "NovaCore.xcframework found"
    fi
    
    # Step 9: Verify no SPM packages in project.yml (critical for Pods mode isolation)
    log_section "SPM Isolation Check"
    log_step "Verifying SPM packages are excluded from Pods mode"
    
    # Check if packages block exists and is empty
    local packages_empty=false
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
