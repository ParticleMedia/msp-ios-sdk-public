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
readonly PROJECT_SPEC="$ROOT_DIR/Examples/MSPDemoApp/project.yml"

# Package.swift paths
readonly PACKAGE_SWIFT="$ROOT_DIR/Package.swift"
readonly PACKAGE_SWIFT_DISABLED="$ROOT_DIR/Package.swift.disabled"

# ============================================================================
# Package.swift State Management
# ============================================================================
# These functions manage the Package.swift file to prevent Xcode from
# auto-detecting SPM packages when in Pods mode.

# Check if Package.swift state is correct for a given mode
check_package_swift_state() {
    local target_mode="$1"
    
    if [[ "$target_mode" == "pods" ]]; then
        # Pods mode: Package.swift must NOT exist, Package.swift.disabled must exist
        if [[ -f "$PACKAGE_SWIFT" ]]; then
            return 1  # Invalid state
        fi
        if [[ ! -f "$PACKAGE_SWIFT_DISABLED" ]]; then
            return 1  # Invalid state
        fi
        return 0
    elif [[ "$target_mode" == "spm" ]]; then
        # SPM mode: Package.swift must exist, Package.swift.disabled must NOT exist
        if [[ ! -f "$PACKAGE_SWIFT" ]]; then
            return 1  # Invalid state
        fi
        if [[ -f "$PACKAGE_SWIFT_DISABLED" ]]; then
            return 1  # Invalid state
        fi
        return 0
    fi
    return 1
}

# Ensure Package.swift is in correct state for Pods mode
ensure_package_swift_disabled() {
    log_step "Ensuring Package.swift is disabled for Pods mode"
    
    # Handle edge case: both files exist
    if [[ -f "$PACKAGE_SWIFT" ]] && [[ -f "$PACKAGE_SWIFT_DISABLED" ]]; then
        log_warn "Both Package.swift and Package.swift.disabled exist!"
        log_info "Removing Package.swift (keeping .disabled version)"
        rm -f "$PACKAGE_SWIFT"
    fi
    
    # If Package.swift exists, rename to disabled
    if [[ -f "$PACKAGE_SWIFT" ]]; then
        mv "$PACKAGE_SWIFT" "$PACKAGE_SWIFT_DISABLED"
        log_success "Package.swift → Package.swift.disabled"
    elif [[ -f "$PACKAGE_SWIFT_DISABLED" ]]; then
        log_info "Package.swift already disabled"
    else
        log_warn "Neither Package.swift nor Package.swift.disabled exists!"
        log_info "This may require: git checkout Package.swift"
    fi
}

# Ensure Package.swift is in correct state for SPM mode
ensure_package_swift_enabled() {
    log_step "Ensuring Package.swift is enabled for SPM mode"
    
    # Handle edge case: both files exist
    if [[ -f "$PACKAGE_SWIFT" ]] && [[ -f "$PACKAGE_SWIFT_DISABLED" ]]; then
        log_warn "Both Package.swift and Package.swift.disabled exist!"
        log_info "Removing Package.swift.disabled (keeping active version)"
        rm -f "$PACKAGE_SWIFT_DISABLED"
    fi
    
    # If disabled version exists, restore it
    if [[ -f "$PACKAGE_SWIFT_DISABLED" ]]; then
        mv "$PACKAGE_SWIFT_DISABLED" "$PACKAGE_SWIFT"
        log_success "Package.swift.disabled → Package.swift"
    elif [[ -f "$PACKAGE_SWIFT" ]]; then
        log_info "Package.swift already enabled"
    else
        log_error "Neither Package.swift nor Package.swift.disabled exists!"
        log_info "SPM mode requires Package.swift. Try: git checkout Package.swift"
        return 1
    fi
    return 0
}

# Auto-fix Package.swift state for current mode (called during validation)
auto_fix_package_swift_state() {
    local target_mode="$1"
    
    if [[ "$target_mode" == "pods" ]]; then
        if [[ -f "$PACKAGE_SWIFT" ]]; then
            log_warn "⚠️ Pods mode detected but Package.swift exists. Auto-disabling..."
            ensure_package_swift_disabled
        fi
    elif [[ "$target_mode" == "spm" ]]; then
        if [[ ! -f "$PACKAGE_SWIFT" ]] && [[ -f "$PACKAGE_SWIFT_DISABLED" ]]; then
            log_warn "⚠️ SPM mode detected but Package.swift is disabled. Auto-restoring..."
            ensure_package_swift_enabled
        fi
    fi
}

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
    
    # Protect critical XCFrameworks - NEVER delete these directories or their contents
    # Updated for new SDK architecture (Round 26)
    local protected_paths=(
        # Canonical ThirdParty location
        "ThirdParty/PrebidMobile/PrebidMobile.xcframework"
        # Embedded OMSDK
        "Sources/Core/MSPOMSDK/OMSDK_Newsbreak1.xcframework"
        # Core XCFrameworks in Build/
        "Build/XCFrameworks/MSPSharedLibraries.xcframework"
        "Build/XCFrameworks/MSPiOSCore.xcframework"
        "Build/XCFrameworks/NovaCore.xcframework"
        "Build/XCFrameworks/MSPCore.xcframework"
        "Build/XCFrameworks/MSPOMSDK.xcframework"
    )
    
    # Check if the directory path matches any protected XCFramework
    for protected in "${protected_paths[@]}"; do
        if [[ "$dir_path" == *"$protected"* ]] || [[ "$dir_path" == "$ROOT_DIR/$protected" ]]; then
            log_error "Refusing to delete protected XCFramework: $protected"
            log_error "Path: $dir_path"
            return 1
        fi
    done
    
    # Also protect parent directories that contain protected XCFrameworks
    if [[ "$dir_path" == "$ROOT_DIR/ThirdParty/PrebidMobile" ]] || \
       [[ "$dir_path" == "$ROOT_DIR/Build/XCFrameworks" ]] || \
       [[ "$dir_path" == "$ROOT_DIR/Sources/Core/MSPOMSDK" ]]; then
        log_error "Refusing to delete directory containing protected XCFrameworks: $dir_path"
        return 1
    fi
    
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
# XCFramework Detection (Updated for new SDK architecture - Round 26)
# ============================================================================

# Core XCFrameworks required for both SPM and Pods modes
CORE_XCFRAMEWORKS=(
    "Build/XCFrameworks/MSPSharedLibraries.xcframework"
    "Build/XCFrameworks/MSPiOSCore.xcframework"
    "Build/XCFrameworks/NovaCore.xcframework"
    "Build/XCFrameworks/MSPCore.xcframework"
    "Build/XCFrameworks/MSPOMSDK.xcframework"
)

# Third-party XCFrameworks (canonical paths)
THIRDPARTY_XCFRAMEWORKS=(
    "ThirdParty/PrebidMobile/PrebidMobile.xcframework"
)

# Embedded XCFrameworks
EMBEDDED_XCFRAMEWORKS=(
    "Sources/Core/MSPOMSDK/OMSDK_Newsbreak1.xcframework"
)

# Adapter source directories (must exist for both modes)
ADAPTER_SOURCES=(
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

check_xcframeworks_exist() {
    local missing=0
    
    # Check Core XCFrameworks
    for xcf in "${CORE_XCFRAMEWORKS[@]}"; do
        local xcf_path="$ROOT_DIR/$xcf"
        if [[ ! -d "$xcf_path" ]]; then
            log_warning "Core XCFramework missing: $xcf"
            ((missing++))
        elif [[ ! -f "$xcf_path/Info.plist" ]]; then
            log_warning "Core XCFramework invalid (missing Info.plist): $xcf"
            ((missing++))
        fi
    done
    
    # Check ThirdParty XCFrameworks
    for xcf in "${THIRDPARTY_XCFRAMEWORKS[@]}"; do
        local xcf_path="$ROOT_DIR/$xcf"
        if [[ ! -d "$xcf_path" ]]; then
            log_warning "ThirdParty XCFramework missing: $xcf"
            ((missing++))
        elif [[ ! -f "$xcf_path/Info.plist" ]]; then
            log_warning "ThirdParty XCFramework invalid (missing Info.plist): $xcf"
            ((missing++))
        fi
    done
    
    return $missing
}

# Check required XCFrameworks for SPM mode
check_required_xcframeworks() {
    local missing=0
    
    # All Core XCFrameworks are required
    for xcf in "${CORE_XCFRAMEWORKS[@]}"; do
        local xcf_path="$ROOT_DIR/$xcf"
        if [[ ! -d "$xcf_path" ]]; then
            log_warning "Required XCFramework missing: $xcf"
            ((missing++))
        elif [[ ! -f "$xcf_path/Info.plist" ]]; then
            log_warning "Required XCFramework invalid (missing Info.plist): $xcf"
            ((missing++))
        fi
    done
    
    # ThirdParty XCFrameworks are required
    for xcf in "${THIRDPARTY_XCFRAMEWORKS[@]}"; do
        local xcf_path="$ROOT_DIR/$xcf"
        if [[ ! -d "$xcf_path" ]]; then
            log_warning "Required ThirdParty XCFramework missing: $xcf"
            ((missing++))
        elif [[ ! -f "$xcf_path/Info.plist" ]]; then
            log_warning "Required ThirdParty XCFramework invalid (missing Info.plist): $xcf"
            ((missing++))
        fi
    done
    
    # Embedded XCFrameworks are required
    for xcf in "${EMBEDDED_XCFRAMEWORKS[@]}"; do
        local xcf_path="$ROOT_DIR/$xcf"
        if [[ ! -d "$xcf_path" ]]; then
            log_warning "Required embedded XCFramework missing: $xcf"
            ((missing++))
        elif [[ ! -f "$xcf_path/Info.plist" ]]; then
            log_warning "Required embedded XCFramework invalid (missing Info.plist): $xcf"
            ((missing++))
        fi
    done
    
    return $missing
}

# Check adapter source directories exist
check_adapter_sources() {
    local missing=0
    
    for adapter in "${ADAPTER_SOURCES[@]}"; do
        local adapter_path="$ROOT_DIR/$adapter"
        if [[ ! -d "$adapter_path" ]]; then
            log_warning "Adapter source missing: $adapter"
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
    
    # Validate Package.swift state
    if [[ "$target" == "spm" ]]; then
        # SPM mode: Package.swift must exist
        if [[ ! -f "$PACKAGE_SWIFT" ]]; then
            log_error "Package.swift missing (required for SPM mode)"
            ((errors++))
        fi
        if [[ -f "$PACKAGE_SWIFT_DISABLED" ]]; then
            log_error "Package.swift.disabled exists (should not in SPM mode)"
            ((errors++))
        fi
    elif [[ "$target" == "pods" ]]; then
        # Pods mode: Package.swift must NOT exist
        if [[ -f "$PACKAGE_SWIFT" ]]; then
            log_error "Package.swift exists (should be disabled in Pods mode)"
            ((errors++))
        fi
        if [[ ! -f "$PACKAGE_SWIFT_DISABLED" ]]; then
            log_error "Package.swift.disabled missing (required for Pods mode)"
            ((errors++))
        fi
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
        
        # Verify required XCFrameworks exist
        if ! check_required_xcframeworks >/dev/null 2>&1; then
            xcf_missing=$?
            log_error "$xcf_missing required XCFramework(s) missing for SPM mode"
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
        
        # Check that packages section is empty (no SwiftPM packages in Pods mode)
        if grep -q "^packages:" "$PROJECT_SPEC" 2>/dev/null; then
            if ! grep -q "^packages: {}$" "$PROJECT_SPEC" 2>/dev/null; then
                # Check if there are any package entries (not just empty)
                if grep -A 1 "^packages:" "$PROJECT_SPEC" 2>/dev/null | grep -qE "^  [A-Za-z]"; then
                    log_error "project.yml contains SwiftPM packages (should be empty in Pods mode)"
                    ((errors++))
                fi
            fi
        fi
    fi
    
    return $errors
}

