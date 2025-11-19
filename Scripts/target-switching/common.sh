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
# Logging Functions
# ============================================================================

log_step() {
    local step_num="$1"
    local step_name="$2"
    echo ""
    echo "Step $step_num: $step_name..."
}

log_success() {
    echo -e "  ${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "  ${RED}✗${NC} $1" >&2
}

log_info() {
    echo "  $1"
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
    rm -rf "$workspace_path"
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
    
    log_info "Removing $description: $(basename "$dir_path")"
    rm -rf "$dir_path"
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
    
    # Note: Both SPM and Pods modes use msp-ios-sdk.xcworkspace (per Podfile configuration)
    # We distinguish them by checking for Pods/ directory and workspace contents
    
    if [[ "$target" == "spm" ]]; then
        if [[ -d "$PODS_DIR" ]]; then
            log_error "Pods/ directory exists (should be removed for SPM)"
            ((errors++))
        fi
        
        if [[ ! -d "$SPM_WORKSPACE" ]]; then
            log_error "SPM workspace missing: msp-ios-sdk.xcworkspace"
            ((errors++))
        fi
        
        # Check if workspace contains Pods (should not in SPM mode)
        if [[ -d "$SPM_WORKSPACE" ]] && grep -q "Pods/Pods.xcodeproj" "$SPM_WORKSPACE/contents.xcworkspacedata" 2>/dev/null; then
            log_error "SPM workspace contains Pods reference (should not)"
            ((errors++))
        fi
        
    elif [[ "$target" == "pods" ]]; then
        if [[ ! -d "$PODS_DIR" ]]; then
            log_error "Pods/ directory missing (required for CocoaPods)"
            ((errors++))
        fi
        
        if [[ ! -d "$PODS_WORKSPACE" ]]; then
            log_error "CocoaPods workspace missing: msp-ios-sdk.xcworkspace"
            ((errors++))
        fi
        
        # Note: With :integrate_targets => false in Podfile, CocoaPods doesn't add Pods/Pods.xcodeproj
        # to the workspace. The workspace.yml includes it for xcodegen reference, but the actual
        # workspace created by pod install may not have it. So we don't check for Pods in workspace.
    fi
    
    return $errors
}

