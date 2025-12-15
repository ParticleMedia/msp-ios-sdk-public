#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Target Switching Script - Dual-Track Architecture Support
# ============================================================================
# Purpose: Switch between development and release modes for CocoaPods and SPM.
#
# Modes:
#   pods-dev     - CocoaPods with source files (internal development)
#   pods-release - CocoaPods with binary XCFrameworks (pre-release validation)
#   spm-release  - Swift Package Manager with binary XCFrameworks (SPM release)
#
# Usage:
#   ./Scripts/switch-target.sh pods-dev
#   ./Scripts/switch-target.sh pods-release
#   ./Scripts/switch-target.sh spm-release
#
# Environment:
#   MSP_RELEASE=0 (pods-dev)    - Podspecs use source_files
#   MSP_RELEASE=1 (pods-release) - Podspecs use vendored_frameworks
#
# ============================================================================

set -euo pipefail

# Source common functions
# IMPORTANT: Save SCRIPT_DIR before sourcing common.sh, which will overwrite it
SWITCH_TARGET_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SWITCH_TARGET_SCRIPT_DIR/.." && pwd)"

# Validate helper script directory exists
if [[ ! -d "$SWITCH_TARGET_SCRIPT_DIR/target-switching" ]]; then
    echo "ERROR: helper script folder missing:" >&2
    echo "  $SWITCH_TARGET_SCRIPT_DIR/target-switching" >&2
    echo "Expected location: Scripts/target-switching/" >&2
    exit 1
fi

# shellcheck source=Scripts/target-switching/common.sh
source "$SWITCH_TARGET_SCRIPT_DIR/target-switching/common.sh"

ensure_repo_root

# ============================================================================
# CONSTANTS (XCFramework paths are defined in common.sh)
# ============================================================================

# Info.plist paths
INFO_PLIST_TEMPLATE="$ROOT_DIR/Examples/MSPDemoApp/Info.plist.template"
INFO_PLIST_OUTPUT="$ROOT_DIR/Examples/MSPDemoApp/MSPDemoApp/Info.plist"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

print_usage() {
    log_info "Usage: $0 {pods-dev|pods-release|spm-release}"
    log_info ""
    log_info "Modes:"
    log_info "  pods-dev      CocoaPods with source files (internal development)"
    log_info "  pods-release  CocoaPods with binary XCFrameworks (pre-release validation)"
    log_info "  spm-release   Swift Package Manager with binary XCFrameworks"
    log_info ""
    log_info "Examples:"
    log_info "  $0 pods-dev      # Switch to development mode (default for SDK engineers)"
    log_info "  $0 pods-release  # Switch to release validation mode"
    log_info "  $0 spm-release   # Switch to SPM release mode"
}

# Validate XCFrameworks exist for release modes
validate_xcframeworks_for_release() {
    log_step "Validating XCFrameworks for release mode"
    
    local errors=0
    local xcf_dir="$ROOT_DIR/Build/XCFrameworks"
    local bin_dir="$ROOT_DIR/Binary"
    
    # Check if Binary/ exists and use it instead
    if [[ -d "$bin_dir" ]] && [[ "$(ls -A "$bin_dir" 2>/dev/null)" ]]; then
        xcf_dir="$bin_dir"
        log_info "Using Binary/ directory for XCFrameworks"
    else
        log_info "Using Build/XCFrameworks/ for XCFrameworks"
    fi
    
    # Required core XCFrameworks
    local required_xcframeworks=(
        "MSPSharedLibraries"
        "MSPiOSCore"
        "MSPCore"
        "NovaCore"
        "MSPOMSDK"
    )
    
    for xcf in "${required_xcframeworks[@]}"; do
        if [[ ! -d "$xcf_dir/${xcf}.xcframework" ]]; then
            log_error "Missing required XCFramework: ${xcf}.xcframework"
            ((errors++)) || true
        elif [[ ! -f "$xcf_dir/${xcf}.xcframework/Info.plist" ]]; then
            log_error "Invalid XCFramework (no Info.plist): ${xcf}.xcframework"
            ((errors++)) || true
        fi
    done
    
    if [[ $errors -gt 0 ]]; then
        log_error "$errors XCFramework(s) missing or invalid"
        log_info ""
        log_info "To build missing XCFrameworks:"
        log_info "  ./Scripts/xcframeworks/build-core.sh"
        return 1
    fi
    
    log_success "All required XCFrameworks validated"
    return 0
}

# Generate Info.plist from template
generate_info_plist() {
    log_step "Generating Info.plist from template"
    
    if [[ -f "$INFO_PLIST_TEMPLATE" ]]; then
        cp "$INFO_PLIST_TEMPLATE" "$INFO_PLIST_OUTPUT"
        log_success "Info.plist generated"
    else
        log_warn "Info.plist.template not found - skipping"
    fi
}

# Run xcodegen
run_xcodegen() {
    log_step "Generating Xcode project from YAML"
    
    if ! command -v xcodegen &>/dev/null; then
        log_fatal "xcodegen not found. Install via: brew install xcodegen"
        exit 1
    fi
    
    if xcodegen generate --spec "$PROJECT_SPEC" 2>&1; then
        log_success "Xcode project generated"
    else
        log_fatal "xcodegen failed"
        exit 1
    fi
}

# Create workspace symlink at project root
# The actual workspace is generated inside .generated/ to keep root clean
# The symlink allows developers to always use: open msp-ios-sdk.xcworkspace
create_workspace_symlink() {
    log_step "Creating workspace symlink at project root"
    
    local GENERATED_WORKSPACE="$ROOT_DIR/.generated/msp-ios-sdk.xcworkspace"
    local ROOT_SYMLINK="$ROOT_DIR/msp-ios-sdk.xcworkspace"
    
    if [[ ! -d "$GENERATED_WORKSPACE" ]]; then
        log_error "Generated workspace not found at: $GENERATED_WORKSPACE"
        log_error "Workspace generation must have failed - cannot create symlink"
        return 1
    fi
    
    # Verify workspace is valid (has contents.xcworkspacedata)
    if [[ ! -f "$GENERATED_WORKSPACE/contents.xcworkspacedata" ]]; then
        log_error "Workspace exists but is invalid (missing contents.xcworkspacedata): $GENERATED_WORKSPACE"
        return 1
    fi
    
    # Remove existing symlink or directory (force overwrite)
    rm -f "$ROOT_SYMLINK" 2>/dev/null || true
    
    # Create symlink pointing to generated workspace
    if ln -sf ".generated/msp-ios-sdk.xcworkspace" "$ROOT_SYMLINK"; then
        log_success "Workspace symlink created: msp-ios-sdk.xcworkspace → .generated/msp-ios-sdk.xcworkspace"
    else
        log_error "Failed to create workspace symlink"
        return 1
    fi
    
    return 0
}

# Pre-stage XCFrameworks for Pods build
prestage_xcframeworks() {
    log_step "Pre-staging XCFrameworks for Pods build"
    
    local DD_PREFIX="$HOME/Library/Developer/Xcode/DerivedData"
    local TARGET_DIRS=()
    
    # Predictable path for round-trip tests
    TARGET_DIRS+=("$DD_PREFIX/msp-ios-sdk-roundtrip/Build/Products/Debug-iphonesimulator/XCFrameworkIntermediates")
    
    # Any existing DerivedData folders
    while IFS= read -r dir; do
        [[ -n "$dir" ]] && TARGET_DIRS+=("$dir/Build/Products/Debug-iphonesimulator/XCFrameworkIntermediates")
    done < <(find "$DD_PREFIX" -maxdepth 1 -name "msp-ios-sdk-*" -type d 2>/dev/null)
    
    local SCRIPTS_DIR="$PODS_DIR/Target Support Files"
    if [[ ! -d "$SCRIPTS_DIR" ]]; then
        log_warn "Pods/Target Support Files not found - skipping XCFramework staging"
        return 0
    fi
    
    local total_staged=0
    for PODS_XCFRAMEWORKS_BUILD_DIR in "${TARGET_DIRS[@]}"; do
        mkdir -p "$PODS_XCFRAMEWORKS_BUILD_DIR"
        
        export PODS_ROOT="$PODS_DIR"
        export PODS_CONFIGURATION_BUILD_DIR="${PODS_XCFRAMEWORKS_BUILD_DIR%/XCFrameworkIntermediates}"
        export PODS_XCFRAMEWORKS_BUILD_DIR="$PODS_XCFRAMEWORKS_BUILD_DIR"
        export ARCHS="arm64"
        export PLATFORM_NAME="iphonesimulator"
        
        local script_count=0
        while IFS= read -r script; do
            [[ -z "$script" ]] && continue
            if /bin/sh "$script" >/dev/null 2>&1; then
                ((script_count++)) || true
            fi
        done < <(find "$SCRIPTS_DIR" -name "*-xcframeworks.sh" 2>/dev/null | sort)
        
        [[ $script_count -gt 0 ]] && ((total_staged++)) || true
    done
    
    if [[ $total_staged -gt 0 ]]; then
        log_success "Pre-staged XCFrameworks to ${#TARGET_DIRS[@]} location(s)"
    else
        log_warn "No XCFrameworks staged"
    fi
}

# Validate final state for a mode
validate_final_state() {
    local mode="$1"
    local errors=0
    
    log_step "Validating final state for $mode"
    
    case "$mode" in
        pods-dev|pods-release)
            # Pods/ must exist
            if [[ ! -d "$PODS_DIR" ]]; then
                log_error "Pods/ directory missing"
                ((errors++)) || true
            fi
            
            # Package.swift must NOT exist
            if [[ -f "$PACKAGE_SWIFT" ]]; then
                log_error "Package.swift exists (should be removed in Pods mode)"
                ((errors++)) || true
            fi
            
            # Package.swift.template must exist
            if [[ ! -f "$PACKAGE_SWIFT_TEMPLATE" ]]; then
                log_error "Package.swift.template missing"
                ((errors++)) || true
            fi
            
            # project.yml must have MSPDemoApp target
            if ! grep -q "^  MSPDemoApp:$" "$PROJECT_SPEC" 2>/dev/null; then
                log_error "project.yml missing MSPDemoApp target"
                ((errors++)) || true
            fi
            
            # project.yml must have packages: {}
            if ! grep -q "^packages: {}$" "$PROJECT_SPEC" 2>/dev/null; then
                log_error "project.yml should have packages: {} in Pods mode"
                ((errors++)) || true
            fi
            ;;
            
        spm-release)
            # Pods/ must NOT exist
            if [[ -d "$PODS_DIR" ]]; then
                log_error "Pods/ directory exists (should be removed in SPM mode)"
                ((errors++)) || true
            fi
            
            # Package.swift must exist
            if [[ ! -f "$PACKAGE_SWIFT" ]]; then
                log_error "Package.swift missing (required for SPM mode)"
                ((errors++)) || true
            fi
            
            # project.yml must have MSPDemoApp-SPM target
            if ! grep -q "^  MSPDemoApp-SPM:$" "$PROJECT_SPEC" 2>/dev/null; then
                log_error "project.yml missing MSPDemoApp-SPM target"
                ((errors++)) || true
            fi
            ;;
    esac
    
    if [[ $errors -gt 0 ]]; then
        log_error "Validation failed with $errors error(s)"
        return 1
    fi
    
    log_success "Validation passed"
    return 0
}

# Print final summary
print_summary() {
    local mode="$1"
    local status="$2"
    
    log_title "Switch Complete"
    
    echo ""
    echo "┌─────────────────────────────────────────────────────────────────┐"
    echo "│                       SWITCH SUMMARY                           │"
    echo "├─────────────────────────────────────────────────────────────────┤"
    printf "│ %-20s %-42s │\n" "Mode:" "$mode"
    printf "│ %-20s %-42s │\n" "Status:" "$status"
    
    case "$mode" in
        pods-dev)
            printf "│ %-20s %-42s │\n" "MSP_RELEASE:" "0 (source mode)"
            printf "│ %-20s %-42s │\n" "Podspecs:" "Using source_files"
            printf "│ %-20s %-42s │\n" "Package.swift:" "Removed"
            ;;
        pods-release)
            printf "│ %-20s %-42s │\n" "MSP_RELEASE:" "1 (binary mode)"
            printf "│ %-20s %-42s │\n" "Podspecs:" "Using vendored_frameworks"
            printf "│ %-20s %-42s │\n" "Package.swift:" "Removed"
            ;;
        spm-release)
            printf "│ %-20s %-42s │\n" "MSP_RELEASE:" "N/A"
            printf "│ %-20s %-42s │\n" "Package.swift:" "Generated from template"
            printf "│ %-20s %-42s │\n" "Pods:" "Removed"
            ;;
    esac
    
    echo "└─────────────────────────────────────────────────────────────────┘"
    echo ""
    
    if [[ "$status" == "SUCCESS" ]]; then
        log_success "Ready for ${mode} workflow"
    else
        log_error "Switch failed - see errors above"
    fi
}

# ============================================================================
# MODE: pods-dev (Development mode with source files)
# ============================================================================

switch_pods_dev() {
    log_title "Switching to PODS-DEV Mode"
    log_info "Mode: CocoaPods with source files (internal development)"
    log_info "MSP_RELEASE=0, MSP_MODE=pods-dev"
    log_info ""
    
    # Export environment variables for podspecs and Podfile
    export MSP_RELEASE=0
    export MSP_MODE=pods-dev
    
    # Step 1: Clean SPM artifacts
    log_section "Environment Cleanup"
    log_step "Cleaning SPM artifacts"
    if "$SWITCH_TARGET_SCRIPT_DIR/target-switching/cleanup_spm.sh" --force 2>/dev/null; then
        log_success "SPM cleanup completed"
    else
        log_warn "SPM cleanup had warnings (continuing)"
    fi
    
    # Step 2: Remove Package.swift
    log_step "Removing Package.swift"
    ensure_package_swift_disabled
    
    # Step 3: Clean existing Pods to force regeneration
    # This ensures CocoaPods removes XCFramework copy phases in pods-dev mode
    log_step "Cleaning existing Pods (force regeneration)"
    if [[ -d "$PODS_DIR" ]]; then
        rm -rf "$PODS_DIR"
        log_success "Pods/ removed"
    fi
    if [[ -f "$ROOT_DIR/Podfile.lock" ]]; then
        rm -f "$ROOT_DIR/Podfile.lock"
        log_success "Podfile.lock removed"
    fi
    
    # Also clean DemoApp Pods directory if it exists
    local DEMOAPP_PODS_DIR="$ROOT_DIR/Examples/DemoApp/Pods"
    local DEMOAPP_PODFILE_LOCK="$ROOT_DIR/Examples/DemoApp/Podfile.lock"
    if [[ -d "$DEMOAPP_PODS_DIR" ]]; then
        rm -rf "$DEMOAPP_PODS_DIR"
        log_success "Examples/DemoApp/Pods/ removed"
    fi
    if [[ -f "$DEMOAPP_PODFILE_LOCK" ]]; then
        rm -f "$DEMOAPP_PODFILE_LOCK"
        log_success "Examples/DemoApp/Podfile.lock removed"
    fi
    
    # Step 4: Run pod install FIRST (before XcodeGen)
    # This is critical: XcodeGen needs the xcconfig files that pod install generates
    log_section "CocoaPods Installation"
    log_step "Running pod install (MSP_RELEASE=0, MSP_MODE=pods-dev)"
    log_info "All modules compiled from SOURCE (path-based pods)"
    log_info "XCFramework copy phases will be REMOVED by Podfile post_install"
    
    cd "$ROOT_DIR"
    if MSP_RELEASE=0 MSP_MODE=pods-dev pod install; then
        log_success "pod install completed (pure source mode)"
    else
        log_error "pod install failed"
        exit 1
    fi
    
    # Step 5: Generate project.yml from templates (AFTER pod install)
    log_section "YAML Generation"
    log_step "Generating project.yml from templates"
    if [[ -x "$SWITCH_TARGET_SCRIPT_DIR/target-switching/generate_project_templates.sh" ]]; then
        "$SWITCH_TARGET_SCRIPT_DIR/target-switching/generate_project_templates.sh"
    fi
    
    log_step "Generating workspace/project YAML"
    if "$SWITCH_TARGET_SCRIPT_DIR/target-switching/generate_workspace.sh" pods-dev; then
        log_success "YAML generated"
    else
        log_error "YAML generation failed"
        exit 1
    fi
    
    # Step 6: Generate Xcode project (now xcconfig files exist)
    log_section "Xcode Project Generation"
    run_xcodegen
    
    # Step 7: Create workspace symlink at root
    log_section "Workspace Symlink"
    if ! create_workspace_symlink; then
        log_error "Failed to create workspace symlink - workspace generation must have failed"
        print_summary "pods-dev" "FAILED"
        exit 1
    fi
    
    # Step 8: Generate Info.plist
    log_section "Info.plist Generation"
    generate_info_plist
    
    # Step 9: Validate final state
    log_section "Validation"
    if ! validate_final_state "pods-dev"; then
        print_summary "pods-dev" "FAILED"
        exit 1
    fi
    
    # Step 9.5: Final workspace existence check (strong contract)
    log_section "Final Workspace Verification"
    local FINAL_WORKSPACE="$ROOT_DIR/msp-ios-sdk.xcworkspace"
    if [[ ! -L "$FINAL_WORKSPACE" ]] && [[ ! -d "$FINAL_WORKSPACE" ]]; then
        log_error "Workspace does not exist at expected location: $FINAL_WORKSPACE"
        log_error "This violates the pods-dev contract - workspace MUST exist on success"
        print_summary "pods-dev" "FAILED"
        exit 1
    fi
    
    if [[ -L "$FINAL_WORKSPACE" ]]; then
        local SYMLINK_TARGET
        SYMLINK_TARGET="$(readlink "$FINAL_WORKSPACE" 2>/dev/null || echo "")"
        if [[ -z "$SYMLINK_TARGET" ]] || [[ ! -d "$ROOT_DIR/$SYMLINK_TARGET" ]]; then
            log_error "Workspace symlink is broken: $FINAL_WORKSPACE → $SYMLINK_TARGET"
            log_error "Target does not exist or is not accessible"
            print_summary "pods-dev" "FAILED"
            exit 1
        fi
    fi
    
    log_success "Workspace verified: $FINAL_WORKSPACE exists and is valid"
    
    # Step 10: Git cleanliness check
    log_section "Git Status Check"
    verify_git_cleanliness || log_warn "Git status not fully clean"
    
    # Step 11: Open Xcode
    log_section "Opening Xcode"
    if [[ -L "$ROOT_DIR/msp-ios-sdk.xcworkspace" ]] || [[ -d "$ROOT_DIR/msp-ios-sdk.xcworkspace" ]]; then
        open "$ROOT_DIR/msp-ios-sdk.xcworkspace"
        log_success "Opened workspace"
    fi
    
    print_summary "pods-dev" "SUCCESS"
    
    log_section "Next Steps"
    log_info "1. Build MSPDemoApp target in Xcode"
    log_info "2. All modules compile from source files"
    log_info "3. Make code changes and iterate quickly"
}

# ============================================================================
# MODE: pods-release (Release validation with binary XCFrameworks)
# ============================================================================

switch_pods_release() {
    log_title "Switching to PODS-RELEASE Mode"
    log_info "Mode: CocoaPods with binary XCFrameworks (pre-release validation)"
    log_info "MSP_RELEASE=1, MSP_MODE=pods-release"
    log_info ""
    
    # Export environment variables for podspecs and Podfile
    export MSP_RELEASE=1
    export MSP_MODE=pods-release
    
    # Step 1: Validate XCFrameworks exist
    log_section "XCFramework Validation"
    if ! validate_xcframeworks_for_release; then
        log_error "Cannot switch to pods-release without XCFrameworks"
        log_info "Build XCFrameworks first: ./Scripts/xcframeworks/build-core.sh"
        exit 1
    fi
    
    # Step 2: Clean SPM artifacts
    log_section "Environment Cleanup"
    log_step "Cleaning SPM artifacts"
    if "$SWITCH_TARGET_SCRIPT_DIR/target-switching/cleanup_spm.sh" --force 2>/dev/null; then
        log_success "SPM cleanup completed"
    else
        log_warn "SPM cleanup had warnings (continuing)"
    fi
    
    # Step 3: Remove Package.swift
    log_step "Removing Package.swift"
    ensure_package_swift_disabled
    
    # Step 4: Generate project.yml from templates
    log_section "YAML Generation"
    log_step "Generating project.yml from templates"
    if [[ -x "$SWITCH_TARGET_SCRIPT_DIR/target-switching/generate_project_templates.sh" ]]; then
        "$SWITCH_TARGET_SCRIPT_DIR/target-switching/generate_project_templates.sh"
    fi
    
    log_step "Generating workspace/project YAML"
    if "$SWITCH_TARGET_SCRIPT_DIR/target-switching/generate_workspace.sh" pods-release; then
        log_success "YAML generated"
    else
        log_error "YAML generation failed"
        exit 1
    fi
    
    # Step 5: Run pod install (with MSP_RELEASE=1)
    log_section "CocoaPods Installation"
    log_step "Running pod install (MSP_RELEASE=1)"
    log_info "Core modules use BINARY XCFrameworks, adapters use SOURCE"
    
    cd "$ROOT_DIR"
    if MSP_RELEASE=1 pod install; then
        log_success "pod install completed"
    else
        log_error "pod install failed"
        exit 1
    fi
    
    # Step 6: Generate Xcode project
    log_section "Xcode Project Generation"
    run_xcodegen
    
    # Step 7: Create workspace symlink at root
    log_section "Workspace Symlink"
    if ! create_workspace_symlink; then
        log_error "Failed to create workspace symlink - workspace generation must have failed"
        print_summary "pods-release" "FAILED"
        exit 1
    fi
    
    # Step 8: Pre-stage XCFrameworks
    log_section "XCFramework Staging"
    prestage_xcframeworks
    
    # Step 9: Generate Info.plist
    log_section "Info.plist Generation"
    generate_info_plist
    
    # Step 10: Validate final state
    log_section "Validation"
    if ! validate_final_state "pods-release"; then
        print_summary "pods-release" "FAILED"
        exit 1
    fi
    
    # Step 10.5: Final workspace existence check (strong contract)
    log_section "Final Workspace Verification"
    local FINAL_WORKSPACE="$ROOT_DIR/msp-ios-sdk.xcworkspace"
    if [[ ! -L "$FINAL_WORKSPACE" ]] && [[ ! -d "$FINAL_WORKSPACE" ]]; then
        log_error "Workspace does not exist at expected location: $FINAL_WORKSPACE"
        log_error "This violates the pods-release contract - workspace MUST exist on success"
        print_summary "pods-release" "FAILED"
        exit 1
    fi
    
    if [[ -L "$FINAL_WORKSPACE" ]]; then
        local SYMLINK_TARGET
        SYMLINK_TARGET="$(readlink "$FINAL_WORKSPACE" 2>/dev/null || echo "")"
        if [[ -z "$SYMLINK_TARGET" ]] || [[ ! -d "$ROOT_DIR/$SYMLINK_TARGET" ]]; then
            log_error "Workspace symlink is broken: $FINAL_WORKSPACE → $SYMLINK_TARGET"
            log_error "Target does not exist or is not accessible"
            print_summary "pods-release" "FAILED"
            exit 1
        fi
    fi
    
    log_success "Workspace verified: $FINAL_WORKSPACE exists and is valid"
    
    # Step 11: Git cleanliness check
    log_section "Git Status Check"
    verify_git_cleanliness || log_warn "Git status not fully clean"
    
    # Step 12: Open Xcode
    log_section "Opening Xcode"
    if [[ -L "$ROOT_DIR/msp-ios-sdk.xcworkspace" ]] || [[ -d "$ROOT_DIR/msp-ios-sdk.xcworkspace" ]]; then
        open "$ROOT_DIR/msp-ios-sdk.xcworkspace"
        log_success "Opened workspace"
    fi
    
    print_summary "pods-release" "SUCCESS"
    
    log_section "Next Steps"
    log_info "1. Build MSPDemoApp target in Xcode"
    log_info "2. Verify XCFrameworks link correctly"
    log_info "3. Run integration tests before release"
}

# ============================================================================
# MODE: spm-release (SPM with binary XCFrameworks)
# ============================================================================

switch_spm_release() {
    log_title "Switching to SPM-RELEASE Mode"
    log_info "Mode: Swift Package Manager with binary XCFrameworks"
    log_info ""
    
    # Step 1: Validate XCFrameworks exist
    log_section "XCFramework Validation"
    if ! validate_xcframeworks_for_release; then
        log_error "Cannot switch to spm-release without XCFrameworks"
        log_info "Build XCFrameworks first: ./Scripts/xcframeworks/build-core.sh"
        exit 1
    fi
    
    # Step 2: Clean CocoaPods artifacts
    log_section "Environment Cleanup"
    log_step "Cleaning CocoaPods artifacts"
    
    # Remove workspace first
    if [[ -d "$PODS_WORKSPACE" ]]; then
        safe_remove_workspace "$PODS_WORKSPACE"
        log_success "Workspace removed"
    fi
    
    # Remove Pods directory
    if [[ -d "$PODS_DIR" ]]; then
        if safe_remove_directory "$PODS_DIR" "Pods"; then
            log_success "Pods/ removed"
        else
            log_error "Failed to remove Pods/"
            exit 1
        fi
    fi
    
    # Step 3: Clean SPM caches
    log_step "Cleaning SPM caches"
    if "$SWITCH_TARGET_SCRIPT_DIR/target-switching/cleanup_spm.sh" --force 2>/dev/null; then
        log_success "SPM cleanup completed"
    else
        log_warn "SPM cleanup had warnings (continuing)"
    fi
    
    # Step 4: Generate Package.swift from template
    log_section "Package.swift Generation"
    log_step "Generating Package.swift from template"
    if ! ensure_package_swift_enabled; then
        log_error "Failed to generate Package.swift"
        exit 1
    fi
    
    # Step 5: Generate project.yml from templates
    log_section "YAML Generation"
    log_step "Generating project.yml from templates"
    if [[ -x "$SWITCH_TARGET_SCRIPT_DIR/target-switching/generate_project_templates.sh" ]]; then
        "$SWITCH_TARGET_SCRIPT_DIR/target-switching/generate_project_templates.sh"
    fi
    
    log_step "Generating workspace/project YAML"
    if "$SWITCH_TARGET_SCRIPT_DIR/target-switching/generate_workspace.sh" spm-release; then
        log_success "YAML generated"
    else
        log_error "YAML generation failed"
        exit 1
    fi
    
    # Step 6: Generate Xcode project
    log_section "Xcode Project Generation"
    run_xcodegen
    
    # Step 7: Create workspace symlink at root (for consistency)
    log_section "Workspace Symlink"
    create_workspace_symlink
    
    # Step 8: Generate Info.plist
    log_section "Info.plist Generation"
    generate_info_plist
    
    # Step 9: Validate XCFrameworks in Package.swift paths
    log_section "Package.swift Validation"
    log_step "Verifying XCFramework paths in Package.swift"
    
    local missing_refs=0
    for xcf in "MSPSharedLibraries" "MSPiOSCore" "MSPCore" "NovaCore" "MSPOMSDK"; do
        if ! grep -q "\"${xcf}\"" "$PACKAGE_SWIFT" 2>/dev/null; then
            log_warn "Package.swift missing reference to: $xcf"
            ((missing_refs++)) || true
        fi
    done
    
    if [[ $missing_refs -eq 0 ]]; then
        log_success "All XCFramework references found in Package.swift"
    else
        log_warn "$missing_refs module(s) not referenced in Package.swift"
    fi
    
    # Step 10: Validate final state
    log_section "Validation"
    if ! validate_final_state "spm-release"; then
        print_summary "spm-release" "FAILED"
        exit 1
    fi
    
    # Step 11: Git cleanliness check
    log_section "Git Status Check"
    verify_git_cleanliness || log_warn "Git status not fully clean"
    
    # Step 12: Open Xcode project
    # Note: SPM mode uses the .xcodeproj directly with Package.swift dependencies
    log_section "Opening Xcode"
    local PROJECT_DIR="$(dirname "$PROJECT_SPEC")"
    if [[ -d "$PROJECT_DIR/MSPDemoApp.xcodeproj" ]]; then
        open "$PROJECT_DIR/MSPDemoApp.xcodeproj"
        log_success "Opened SPM project"
    fi
    
    print_summary "spm-release" "SUCCESS"
    
    log_section "Next Steps"
    log_info "1. Wait for Xcode to resolve packages"
    log_info "2. Build MSPDemoApp-SPM target"
    log_info "3. Verify all XCFrameworks link correctly"
}

# ============================================================================
# BACKWARD COMPATIBILITY: Support old 'pods' and 'spm' commands
# ============================================================================

switch_legacy_pods() {
    log_warn "Deprecated: 'pods' mode is now 'pods-dev'"
    log_info "Redirecting to pods-dev mode..."
    log_info ""
    switch_pods_dev
}

switch_legacy_spm() {
    log_warn "Deprecated: 'spm' mode is now 'spm-release'"
    log_info "Redirecting to spm-release mode..."
    log_info ""
    switch_spm_release
}

# ============================================================================
# MAIN DISPATCH
# ============================================================================

MODE="${1:-}"

if [[ -z "$MODE" ]]; then
    print_usage
    exit 1
fi

case "$MODE" in
    pods-dev)
        switch_pods_dev
        ;;
    pods-release)
        switch_pods_release
        ;;
    spm-release)
        switch_spm_release
        ;;
    # Backward compatibility
    pods)
        switch_legacy_pods
        ;;
    spm)
        switch_legacy_spm
        ;;
    -h|--help|help)
        print_usage
        exit 0
        ;;
    *)
        log_error "Unknown mode: $MODE"
        log_info ""
        print_usage
        exit 1
        ;;
esac
