#!/usr/bin/env bash
# ============================================================================
# Target Switching Script
# ============================================================================
# Purpose: Switch between CocoaPods and Swift Package Manager (SPM) targets.
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
# SPM TARGET SWITCHING
# ============================================================================

if [[ "$TARGET" == "spm" ]]; then
    log_section "Environment Cleanup"
    
    # Step 1: Clean CocoaPods
    log_step "Cleaning CocoaPods environment"
    if [[ -d "$PODS_DIR" ]]; then
        safe_remove_directory "$PODS_DIR" "Pods"
        log_success "Pods/ removed"
    else
        log_info "Pods/ already removed"
    fi
    
    # Remove CocoaPods workspace (if it exists)
    if [[ -d "$PODS_WORKSPACE" ]]; then
        # Check if it's a CocoaPods workspace (has Pods reference)
        if grep -q "Pods/Pods.xcodeproj" "$PODS_WORKSPACE/contents.xcworkspacedata" 2>/dev/null; then
            safe_remove_workspace "$PODS_WORKSPACE"
            log_success "CocoaPods workspace removed"
        else
            # It might be an SPM workspace, we'll regenerate it
            safe_remove_workspace "$PODS_WORKSPACE"
            log_success "Stale workspace removed"
        fi
    else
        log_info "CocoaPods workspace already removed"
    fi
    
    # Step 2: Clean SPM
    log_step "Cleaning SwiftPM environment"
    if "$SCRIPT_DIR/cleanup_spm.sh" --force; then
        log_success "SPM cleanup completed"
    else
        log_warn "SPM cleanup had warnings (continuing)"
    fi
    
    # Step 3: Check xcframeworks (warn only, don't build)
    log_section "XCFramework Validation"
    log_step "Checking wrapper xcframeworks"
    if check_xcframeworks_exist; then
        missing=0
    else
        missing=$?
    fi
    if [[ $missing -gt 0 ]]; then
        log_warn "$missing wrapper(s) missing xcframeworks"
        log_info "To build xcframeworks, run:"
        log_info "  1. bundle exec pod install"
        log_info "  2. Scripts/target-switching/build-xcframeworks.sh"
    else
        log_success "All xcframeworks present"
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
    
    # Step 6: Generate workspace (for Pods mode, but also useful for SPM)
    if [[ -f "$ROOT_DIR/Scripts/tools/generate-workspace.sh" ]]; then
        log_step "Generating workspace"
        if "$ROOT_DIR/Scripts/tools/generate-workspace.sh" 2>&1; then
            log_success "Workspace generated"
        else
            log_warn "Workspace generation had issues (continuing)"
        fi
    fi
    
    # Step 7: Validate environment
    log_section "Environment Validation"
    log_step "Validating environment"
    if validate_environment "spm"; then
        log_success "Environment validation passed"
    else
        errors=$?
        log_error "Environment validation failed ($errors error(s))"
        exit 1
    fi
    
    # Step 8: Open Xcode
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
        # Check if it's an SPM workspace (no Pods reference)
        if ! grep -q "Pods/Pods.xcodeproj" "$SPM_WORKSPACE/contents.xcworkspacedata" 2>/dev/null; then
            safe_remove_workspace "$SPM_WORKSPACE"
            log_success "SPM workspace removed"
        else
            log_info "Workspace contains Pods (will be regenerated by pod install)"
        fi
    else
        log_info "SPM workspace already removed"
    fi
    
    # Step 2: Clean and install CocoaPods
    log_step "Cleaning and installing CocoaPods"
    if "$SCRIPT_DIR/cleanup_pods.sh"; then
        log_success "CocoaPods environment cleaned and reinstalled"
    else
        log_error "CocoaPods cleanup and install failed"
        exit 1
    fi
    
    # Step 3: Generate YAML specs
    log_section "YAML Generation"
    log_step "Generating YAML specs"
    if "$SCRIPT_DIR/generate_workspace.sh" pods; then
        log_success "YAML specs generated"
    else
        log_error "YAML generation failed"
        exit 1
    fi
    
    # Step 4: Generate Xcode project from YAML
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
    
    # Step 5: Generate workspace
    if [[ -f "$ROOT_DIR/Scripts/tools/generate-workspace.sh" ]]; then
        log_step "Generating workspace"
        if "$ROOT_DIR/Scripts/tools/generate-workspace.sh" 2>&1; then
            log_success "Workspace generated"
        else
            log_warn "Workspace generation had issues (continuing)"
        fi
    fi
    
    # Step 6: Validate wrappers (if Pods exist)
    log_section "Wrapper Validation"
    log_step "Validating wrapper xcframeworks"
    if [[ -d "$PODS_DIR" ]]; then
        VALIDATE_SCRIPT="$ROOT_DIR/Scripts/xcframeworks/validate-wrappers.sh"
        if [[ -f "$VALIDATE_SCRIPT" ]]; then
            if "$VALIDATE_SCRIPT" 2>/dev/null; then
                log_success "Wrapper validation passed"
            else
                log_warn "Wrapper validation had warnings or failures"
            fi
        else
            log_warn "Wrapper validation script not found"
        fi
    else
        log_warn "Pods/ not found, skipping wrapper validation"
    fi
    
    # Step 7: Validate environment
    log_section "Environment Validation"
    log_step "Validating environment"
    if validate_environment "pods"; then
        log_success "Environment validation passed"
    else
        errors=$?
        log_error "Environment validation failed ($errors error(s))"
        exit 1
    fi
    
    # Step 8: Open Xcode (workspace created by pod install or generate-workspace.sh)
    log_section "Opening Xcode"
    log_step "Opening Xcode"
    if [[ -d "$PODS_WORKSPACE" ]]; then
        open "$PODS_WORKSPACE"
        log_success "Xcode opened with CocoaPods workspace"
    else
        log_warn "CocoaPods workspace not found. Opening project directory instead..."
        PROJECT_DIR="$(dirname "$PROJECT_SPEC")"
        if [[ -d "$PROJECT_DIR/MSPDemoApp.xcodeproj" ]]; then
            open "$PROJECT_DIR/MSPDemoApp.xcodeproj"
        else
            open "$PROJECT_DIR"
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
    log_info "2. Build MSPDemoApp-SPM target"
else
    log_info "1. Build MSPDemoApp target"
    log_info "2. Verify all adapters are working"
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
