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
    printf "Usage: %s [spm|pods]\n" "$0"
    printf "\n"
    printf "Examples:\n"
    printf "  %s spm    # Switch to Swift Package Manager\n" "$0"
    printf "  %s pods   # Switch to CocoaPods\n" "$0"
    exit 1
fi

if [[ "$TARGET" != "spm" ]] && [[ "$TARGET" != "pods" ]]; then
    log_error "Invalid target. Must be 'spm' or 'pods'"
    exit 1
fi

printf "============================================================================\n"
printf "Target Switching: %s\n" "$TARGET"
printf "============================================================================\n"
printf "\n"
printf "Repository: %s\n" "$ROOT_DIR"
printf "\n"

# ============================================================================
# SPM TARGET SWITCHING
# ============================================================================

if [[ "$TARGET" == "spm" ]]; then
    log_info "Switching to Swift Package Manager (SPM)..."
    
    # Step 1: Clean CocoaPods
    log_step "1" "Cleaning CocoaPods environment"
    if [[ -d "$PODS_DIR" ]]; then
        safe_remove_directory "$PODS_DIR" "Pods"
        log_success "Pods/ removed"
    else
        log_warning "Pods/ already removed"
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
        log_warning "CocoaPods workspace already removed"
    fi
    
    # Step 2: Clean SPM
    log_step "2" "Cleaning SwiftPM environment"
    if "$SCRIPT_DIR/cleanup_spm.sh" --force; then
        log_success "SPM cleanup completed"
    else
        log_warning "SPM cleanup had warnings (continuing)"
    fi
    
    # Step 3: Check xcframeworks (warn only, don't build)
    log_step "3" "Checking wrapper xcframeworks"
    if check_xcframeworks_exist; then
        missing=0
    else
        missing=$?
    fi
    if [[ $missing -gt 0 ]]; then
        log_warning "$missing wrapper(s) missing xcframeworks"
        log_info "To build xcframeworks, run:"
        log_info "  1. bundle exec pod install"
        log_info "  2. Scripts/target-switching/build-xcframeworks.sh"
    else
        log_success "All xcframeworks present"
    fi
    
    # Step 4: Generate YAML specs (only)
    log_step "4" "Generating YAML specs"
    if "$SCRIPT_DIR/generate_workspace.sh" spm; then
        log_success "YAML specs generated"
    else
        log_error "YAML generation failed"
        exit 1
    fi
    
    # Step 5: Validate environment
    log_step "5" "Validating environment"
    if validate_environment "spm"; then
        log_success "Environment validation passed"
    else
        errors=$?
        log_error "Environment validation failed ($errors error(s))"
        exit 1
    fi
    
    # Step 6: Open Xcode (workspace will be created by Xcode if needed)
    log_step "6" "Opening Xcode"
    if [[ -f "$PROJECT_SPEC" ]]; then
        # Open the project spec - Xcode will handle workspace creation
        PROJECT_DIR="$(dirname "$PROJECT_SPEC")"
        if [[ -d "$PROJECT_DIR/MSPDemoApp.xcodeproj" ]]; then
            open "$PROJECT_DIR/MSPDemoApp.xcodeproj"
            log_success "Xcode opened with SPM project"
        else
            log_warning "Xcode project not found. Run 'xcodegen generate' to create it."
            log_info "Opening project directory instead..."
            open "$PROJECT_DIR"
        fi
    else
        log_error "project.yml not found: $PROJECT_SPEC"
        exit 1
    fi

# ============================================================================
# COCOAPODS TARGET SWITCHING
# ============================================================================

elif [[ "$TARGET" == "pods" ]]; then
    log_info "Switching to CocoaPods..."
    
    # Step 1: Clean SPM
    log_step "1" "Cleaning SwiftPM environment"
    if "$SCRIPT_DIR/cleanup_spm.sh" --force; then
        log_success "SPM cleanup completed"
    else
        log_warning "SPM cleanup had warnings (continuing)"
    fi
    
    # Remove SPM workspace (if it exists and is SPM-only)
    if [[ -d "$SPM_WORKSPACE" ]]; then
        # Check if it's an SPM workspace (no Pods reference)
        if ! grep -q "Pods/Pods.xcodeproj" "$SPM_WORKSPACE/contents.xcworkspacedata" 2>/dev/null; then
            safe_remove_workspace "$SPM_WORKSPACE"
            log_success "SPM workspace removed"
        else
            log_warning "Workspace contains Pods (will be regenerated by pod install)"
        fi
    else
        log_warning "SPM workspace already removed"
    fi
    
    # Step 2: Clean and install CocoaPods
    log_step "2" "Cleaning and installing CocoaPods"
    if "$SCRIPT_DIR/cleanup_pods.sh"; then
        log_success "CocoaPods environment cleaned and reinstalled"
    else
        log_error "CocoaPods cleanup and install failed"
        exit 1
    fi
    
    # Step 3: Generate YAML specs (only)
    log_step "3" "Generating YAML specs"
    if "$SCRIPT_DIR/generate_workspace.sh" pods; then
        log_success "YAML specs generated"
    else
        log_error "YAML generation failed"
        exit 1
    fi
    
    # Step 4: Validate wrappers (if Pods exist)
    log_step "4" "Validating wrapper xcframeworks"
    if [[ -d "$PODS_DIR" ]]; then
        VALIDATE_SCRIPT="$ROOT_DIR/Scripts/xcframeworks/validate-wrappers.sh"
        if [[ -f "$VALIDATE_SCRIPT" ]]; then
            if "$VALIDATE_SCRIPT" 2>/dev/null; then
                log_success "Wrapper validation passed"
            else
                log_warning "Wrapper validation had warnings or failures"
            fi
        else
            log_warning "Wrapper validation script not found"
        fi
    else
        log_warning "Pods/ not found, skipping wrapper validation"
    fi
    
    # Step 5: Validate environment
    log_step "5" "Validating environment"
    if validate_environment "pods"; then
        log_success "Environment validation passed"
    else
        errors=$?
        log_error "Environment validation failed ($errors error(s))"
        exit 1
    fi
    
    # Step 6: Open Xcode (workspace created by pod install)
    log_step "6" "Opening Xcode"
    if [[ -d "$PODS_WORKSPACE" ]]; then
        open "$PODS_WORKSPACE"
        log_success "Xcode opened with CocoaPods workspace"
    else
        log_warning "CocoaPods workspace not found. Opening project directory instead..."
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

printf "\n"
printf "============================================================================\n"
printf "Switching Complete\n"
printf "============================================================================\n"
printf "\n"
log_success "Successfully switched to: $TARGET"
printf "\n"
printf "Next steps:\n"
if [[ "$TARGET" == "spm" ]]; then
    printf "  1. If needed, run 'xcodegen generate' to regenerate Xcode project from YAML\n"
    printf "  2. Wait for Xcode to resolve packages (File → Packages → Resolve Package Versions)\n"
    printf "  3. Build MSPDemoApp-SPM target\n"
else
    printf "  1. If needed, run 'xcodegen generate' to regenerate Xcode project from YAML\n"
    printf "  2. Build MSPDemoApp target\n"
    printf "  3. Verify all adapters are working\n"
fi
printf "\n"
log_info "Note: Only YAML files (project.yml, workspace.yml) were modified"
log_info "      Xcode project files (.pbxproj, .xcscheme) are NOT modified by switching"
printf "\n"
