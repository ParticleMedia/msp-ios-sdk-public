#!/usr/bin/env bash
# ============================================================================
# Common Functions for Target Switching
# ============================================================================
# Purpose: Shared utilities for all target switching scripts
#
# Usage:   source Scripts/target-switching/common.sh
# ============================================================================

set -euo pipefail

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/lib/paths.sh
source "$ROOT_DIR/Scripts/lib/paths.sh"
# shellcheck source=Scripts/lib/colors.sh
source "$ROOT_DIR/Scripts/lib/colors.sh"
# shellcheck source=Scripts/lib/ui.sh
source "$ROOT_DIR/Scripts/lib/ui.sh"

# Initialize paths
init_paths

# ============================================================================
# Constants
# ============================================================================

readonly SPM_WORKSPACE="$ROOT_DIR/msp-ios-sdk.xcworkspace"
# Note: Podfile specifies workspace 'msp-ios-sdk', so CocoaPods also creates msp-ios-sdk.xcworkspace
# Both SPM and Pods modes use the same workspace name, but with different contents
readonly PODS_WORKSPACE="$ROOT_DIR/msp-ios-sdk.xcworkspace"
readonly PODS_DIR="$ROOT_DIR/Pods"
readonly WORKSPACE_SPEC="$ROOT_DIR/workspace.yml"
readonly PROJECT_SPEC="$ROOT_DIR/MSPDemoApp/project.yml"

# ============================================================================
# Logging Functions (UI system)
# ============================================================================
# All logging functions are now provided by lib/ui.sh
# These are kept for backward compatibility during migration

log_warning() {
    log_warn "$1"
}

# ============================================================================
# Safety Checks
# ============================================================================

ensure_repo_root() {
    if [[ ! -f "$ROOT_DIR/.git/config" ]] && [[ ! -f "$ROOT_DIR/Podfile" ]]; then
        log_error "Not in MSP iOS SDK repository. Aborting."
        exit 1
    fi
}

# ============================================================================
# Workspace Detection
# ============================================================================

is_spm_mode() {
    [[ -d "$SPM_WORKSPACE" ]] && [[ ! -d "$PODS_WORKSPACE" ]] && [[ ! -d "$PODS_DIR" ]]
}

is_pods_mode() {
    [[ -d "$PODS_WORKSPACE" ]] && [[ -d "$PODS_DIR" ]] && [[ ! -d "$SPM_WORKSPACE" ]]
}

detect_current_mode() {
    if is_spm_mode; then
        echo "spm"
    elif is_pods_mode; then
        echo "pods"
    else
        echo "mixed"
    fi
}

# ============================================================================
# Safe Workspace Removal
# ============================================================================

# Safely remove a workspace directory, ensuring we never delete internal
# project.xcworkspace folders inside .xcodeproj bundles
safe_remove_workspace() {
    local workspace_path="$1"
    
    if [[ ! -d "$workspace_path" ]]; then
        return 0
    fi
    
    # Verify path is within repo root (safety check)
    if [[ "$workspace_path" != "$ROOT_DIR"* ]]; then
        log_error "Refusing to remove workspace outside repo root: $workspace_path"
        return 1
    fi
    
    # Verify it's actually a workspace (has contents.xcworkspacedata)
    if [[ ! -f "$workspace_path/contents.xcworkspacedata" ]]; then
        log_warning "Path does not appear to be a workspace: $workspace_path"
        return 1
    fi
    
    # Double-check we're not inside an .xcodeproj bundle
    if [[ "$workspace_path" == *".xcodeproj/"* ]]; then
        log_error "Refusing to delete workspace inside .xcodeproj: $workspace_path"
        return 1
    fi
    
    log_info "Removing workspace: $(basename "$workspace_path")"
    
    # Try standard rm -rf first
    if rm -rf "$workspace_path" 2>/dev/null; then
        # Verify removal succeeded
        if [[ ! -d "$workspace_path" ]]; then
            return 0
        fi
    fi
    
    # Fallback: Use find -delete
    log_warn "Standard removal failed, trying find -delete method"
    if find "$workspace_path" -delete 2>/dev/null; then
        if [[ ! -d "$workspace_path" ]]; then
            return 0
        fi
    fi
    
    # Last resort: Retry with force
    log_warn "Attempting forced removal with retry"
    local retry_count=0
    local max_retries=3
    while [[ $retry_count -lt $max_retries ]] && [[ -d "$workspace_path" ]]; do
        sleep 1
        rm -rf "$workspace_path" 2>/dev/null || true
        ((retry_count++))
    done
    
    # Final check
    if [[ -d "$workspace_path" ]]; then
        log_error "Failed to remove workspace after $max_retries attempts: $workspace_path"
        return 1
    fi
    
    return 0
}

# ============================================================================
# Safe Directory Removal
# ============================================================================

safe_remove_directory() {
    local dir_path="$1"
    local description="${2:-directory}"
    
    if [[ ! -d "$dir_path" ]]; then
        return 0
    fi
    
    # Verify path is within repo root (safety check)
    if [[ "$dir_path" != "$ROOT_DIR"* ]]; then
        log_error "Refusing to remove directory outside repo root: $dir_path"
        return 1
    fi
    
    log_info "Removing $description: $(basename "$dir_path")"
    
    # Try standard rm -rf first
    if rm -rf "$dir_path" 2>/dev/null; then
        # Verify removal succeeded
        if [[ ! -d "$dir_path" ]]; then
            return 0
        fi
    fi
    
    # Fallback: Use find -delete for stubborn directories
    log_warn "Standard removal failed, trying find -delete method"
    if find "$dir_path" -delete 2>/dev/null; then
        if [[ ! -d "$dir_path" ]]; then
            return 0
        fi
    fi
    
    # Last resort: Try with force and wait
    log_warn "Attempting forced removal with retry"
    local retry_count=0
    local max_retries=3
    while [[ $retry_count -lt $max_retries ]] && [[ -d "$dir_path" ]]; do
        sleep 1
        rm -rf "$dir_path" 2>/dev/null || true
        ((retry_count++))
    done
    
    # Final check
    if [[ -d "$dir_path" ]]; then
        log_error "Failed to remove $description after $max_retries attempts: $dir_path"
        log_info "Directory may be locked or in use. Try closing Xcode and retrying."
        return 1
    fi
    
    return 0
}

# ============================================================================
# XCFramework Detection
# ============================================================================

check_xcframeworks_exist() {
    local missing=0
    local wrappers=(
        "ShimmerWrapper"
        "FBAudienceNetworkWrapper"
        "IronSourceSDKWrapper"
        "OpenWrapSDKWrapper"
        "MintegralAdSDKWrapper"
        "MobileFuseSDKWrapper"
        "InMobiSDKWrapper"
    )
    
    for wrapper in "${wrappers[@]}"; do
        local wrapper_dir="$ROOT_DIR/$wrapper"
        local frameworks_dir="$wrapper_dir/Frameworks"
        
        if [[ ! -d "$wrapper_dir" ]]; then
            log_warning "Wrapper directory missing: $wrapper"
            ((missing++))
            continue
        fi
        
        if [[ ! -d "$frameworks_dir" ]]; then
            log_warning "Frameworks directory missing: $wrapper/Frameworks"
            ((missing++))
            continue
        fi
        
        # Check for at least one .xcframework
        local xcframeworks
        xcframeworks=$(find "$frameworks_dir" -maxdepth 1 -name "*.xcframework" -type d 2>/dev/null | wc -l | tr -d ' ')
        
        if [[ "$xcframeworks" -eq 0 ]]; then
            log_warning "No xcframeworks found in: $wrapper/Frameworks"
            ((missing++))
        fi
    done
    
    return $missing
}

# ============================================================================
# Validation
# ============================================================================

validate_environment() {
    local target="$1"
    local errors=0
    
    # Validate YAML files exist
    if [[ ! -f "$PROJECT_SPEC" ]]; then
        log_error "project.yml missing: $PROJECT_SPEC"
        ((errors++))
    fi
    
    if [[ ! -f "$WORKSPACE_SPEC" ]]; then
        log_error "workspace.yml missing: $WORKSPACE_SPEC"
        ((errors++))
    fi
    
    # Validate YAML content matches target mode
    if [[ "$target" == "spm" ]]; then
        if [[ -d "$PODS_DIR" ]]; then
            log_error "Pods/ directory exists (should be removed for SPM)"
            ((errors++))
        fi
        
        # Check project.yml has SPM target, not Pods target
        if grep -q "^  MSPDemoApp:$" "$PROJECT_SPEC" 2>/dev/null; then
            log_error "project.yml contains MSPDemoApp target (should be MSPDemoApp-SPM for SPM mode)"
            ((errors++))
        fi
        
        if ! grep -q "^  MSPDemoApp-SPM:$" "$PROJECT_SPEC" 2>/dev/null; then
            log_error "project.yml missing MSPDemoApp-SPM target (required for SPM mode)"
            ((errors++))
        fi
        
        # Check for Pods xcconfig references
        if grep -q "Pods.*xcconfig\|Pods-MSPDemoApp" "$PROJECT_SPEC" 2>/dev/null; then
            log_error "project.yml contains Pods xcconfig references (should not in SPM mode)"
            ((errors++))
        fi
        
        # Check workspace.yml doesn't include Pods project
        if grep -q "Pods/Pods.xcodeproj" "$WORKSPACE_SPEC" 2>/dev/null; then
            log_error "workspace.yml contains Pods project (should not in SPM mode)"
            ((errors++))
        fi
        
    elif [[ "$target" == "pods" ]]; then
        if [[ ! -d "$PODS_DIR" ]]; then
            log_error "Pods/ directory missing (required for CocoaPods)"
            ((errors++))
        fi
        
        # Check project.yml has Pods target, not SPM target
        if ! grep -q "^  MSPDemoApp:$" "$PROJECT_SPEC" 2>/dev/null; then
            log_error "project.yml missing MSPDemoApp target (required for Pods mode)"
            ((errors++))
        fi
        
        if grep -q "^  MSPDemoApp-SPM:$" "$PROJECT_SPEC" 2>/dev/null; then
            log_error "project.yml contains MSPDemoApp-SPM target (should be MSPDemoApp for Pods mode)"
            ((errors++))
        fi
        
        # Check for Pods xcconfig references
        if ! grep -q "Pods.*xcconfig\|Pods-MSPDemoApp" "$PROJECT_SPEC" 2>/dev/null; then
            log_error "project.yml missing Pods xcconfig references (required for Pods mode)"
            ((errors++))
        fi
    fi
    
    return $errors
}

