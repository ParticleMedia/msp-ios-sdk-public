#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
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
# Fix PODS_DIR readonly variable conflict
# Only declare PODS_DIR as readonly if it doesn't already exist
if [[ -z "${PODS_DIR:-}" ]]; then
    readonly PODS_DIR="$ROOT_DIR/Pods"
elif ! readonly -p 2>/dev/null | grep -q "^declare -r PODS_DIR="; then
    # PODS_DIR exists but is not readonly, make it readonly
    readonly PODS_DIR
fi
readonly WORKSPACE_SPEC="$ROOT_DIR/workspace.yml"
readonly PROJECT_SPEC="$ROOT_DIR/Examples/MSPDemoApp/project.yml"

# Package.swift paths (Template-based architecture)
# Package.swift.template - Developer-maintained, tracked in Git
# Package.swift - Generated from template in SPM mode, deleted in Pods mode
readonly PACKAGE_SWIFT="$ROOT_DIR/Package.swift"
readonly PACKAGE_SWIFT_TEMPLATE="$ROOT_DIR/Package.swift.template"
readonly PACKAGE_SWIFT_DISABLED="$ROOT_DIR/Package.swift.disabled"  # Legacy, will be removed

# XCFramework directories
readonly XCFRAMEWORK_DIR="$ROOT_DIR/Build/XCFrameworks"
readonly BINARY_DIR="$ROOT_DIR/Binary"  # Future migration target

# ============================================================================
# Package.swift State Management
# ============================================================================
# These functions manage the Package.swift file to prevent Xcode from
# auto-detecting SPM packages when in Pods mode.

# Check if Package.swift state is correct for a given mode (Template Architecture)
check_package_swift_state() {
    local target_mode="$1"
    
    # Template must ALWAYS exist (developer-maintained)
    if [[ ! -f "$PACKAGE_SWIFT_TEMPLATE" ]]; then
        log_warn "Package.swift.template is missing! This is a developer-maintained file."
        return 1
    fi
    
    case "$target_mode" in
        pods|pods-dev|pods-release)
            # Pods modes: Package.swift must NOT exist
            if [[ -f "$PACKAGE_SWIFT" ]]; then
                return 1  # Invalid state - Package.swift should be deleted
            fi
            return 0
            ;;
        spm|spm-release)
            # SPM modes: Package.swift must exist (copied from template)
            if [[ ! -f "$PACKAGE_SWIFT" ]]; then
                return 1  # Invalid state - Package.swift should exist
            fi
            return 0
            ;;
    esac
    return 1
}

# Ensure Package.swift is in correct state for Pods mode (Template Architecture)
# In Pods mode: Delete Package.swift (template remains untouched)
ensure_package_swift_disabled() {
    log_step "Ensuring Package.swift is removed for Pods mode"
    
    # Verify template exists (developer-maintained)
    if [[ ! -f "$PACKAGE_SWIFT_TEMPLATE" ]]; then
        log_error "Package.swift.template is missing! Cannot proceed."
        log_info "This is a developer-maintained file that must exist in the repository."
        return 1
    fi
    
    # Clean up legacy .disabled file if it exists
    if [[ -f "$PACKAGE_SWIFT_DISABLED" ]]; then
        log_info "Removing legacy Package.swift.disabled"
        rm -f "$PACKAGE_SWIFT_DISABLED"
    fi
    
    # Delete runtime Package.swift (generated from template in SPM mode)
    if [[ -f "$PACKAGE_SWIFT" ]]; then
        rm -f "$PACKAGE_SWIFT"
        log_success "Package.swift removed (template preserved at Package.swift.template)"
    else
        log_info "Package.swift already removed"
    fi
}

# Ensure Package.swift is in correct state for SPM mode (Template Architecture)
# In SPM mode: Copy template to Package.swift
# For spm-release: Generate core-only Package.swift (excludes missing third-party SDKs)
ensure_package_swift_enabled() {
    local mode="${1:-spm}"  # Default to 'spm', can be 'spm-release' for core-only generation
    
    log_step "Ensuring Package.swift is generated from template for SPM mode"
    
    # Verify template exists (developer-maintained)
    if [[ ! -f "$PACKAGE_SWIFT_TEMPLATE" ]]; then
        log_error "Package.swift.template is missing! Cannot proceed."
        log_info "This is a developer-maintained file that must exist in the repository."
        return 1
    fi
    
    # Clean up legacy .disabled file if it exists
    if [[ -f "$PACKAGE_SWIFT_DISABLED" ]]; then
        log_info "Removing legacy Package.swift.disabled"
        rm -f "$PACKAGE_SWIFT_DISABLED"
    fi
    
    # For spm-release mode: Generate core-only Package.swift
    if [[ "$mode" == "spm-release" ]]; then
        log_info "Generating core-only Package.swift for spm-release (excluding missing third-party SDKs)"
        generate_core_only_package_swift
        log_success "Package.swift generated (core-only mode)"
        return 0
    fi
    
    # For regular spm mode: Copy template to runtime Package.swift
    cp "$PACKAGE_SWIFT_TEMPLATE" "$PACKAGE_SWIFT"
    log_success "Package.swift generated from Package.swift.template"
    return 0
}

# Generate core-only Package.swift for spm-release mode
# Excludes: adapter products/targets and missing third-party SDKs
# Includes: core modules (MSPCore, MSPiOSCore, NovaCore, MSPSharedLibraries, MSPOMSDK) + PrebidMobile
generate_core_only_package_swift() {
    local temp_package="/tmp/Package.swift.core-only.$$"
    local ruby_script="$ROOT_DIR/Scripts/target-switching/generate_core_only_package_swift.rb"
    
    # Use Ruby script for robust filtering (consistent with podspec manipulation)
    if [[ -f "$ruby_script" ]] && command -v ruby >/dev/null 2>&1; then
        if ! ruby "$ruby_script" "$PACKAGE_SWIFT_TEMPLATE" "$temp_package"; then
            log_error "Failed to generate core-only Package.swift"
            return 1
        fi
    else
        log_error "Ruby script not found or ruby not available: $ruby_script"
        return 1
    fi
    
    # Move the generated file to final location
    mv "$temp_package" "$PACKAGE_SWIFT"
}

# Auto-fix Package.swift state for current mode (called during validation)
auto_fix_package_swift_state() {
    local target_mode="$1"
    
    case "$target_mode" in
        pods|pods-dev|pods-release)
            if [[ -f "$PACKAGE_SWIFT" ]]; then
                log_warn "⚠️ Pods mode detected but Package.swift exists. Auto-removing..."
                ensure_package_swift_disabled
            fi
            ;;
        spm|spm-release)
            if [[ ! -f "$PACKAGE_SWIFT" ]]; then
                log_warn "⚠️ SPM mode detected but Package.swift is missing. Auto-generating..."
                ensure_package_swift_enabled
            fi
            ;;
    esac
}

# ============================================================================
# Git Cleanliness Verification (Template Architecture)
# ============================================================================
# After switching modes, verify that git status is clean.
# All switching-generated files should be in .gitignore.

verify_git_cleanliness() {
    log_step "Verifying git status is clean after switching"
    
    local dirty_files
    dirty_files=$(git status --porcelain 2>/dev/null || echo "")
    
    if [[ -z "$dirty_files" ]]; then
        log_success "Git status is clean - switching did not modify tracked files"
        return 0
    fi
    
    # Filter out expected untracked files (should be in .gitignore)
    local unexpected_files=""
    while IFS= read -r line; do
        # Skip empty lines
        [[ -z "$line" ]] && continue
        
        # Get the status and file path
        local status="${line:0:2}"
        local filepath="${line:3}"
        
        # Skip untracked files that should be in .gitignore
        # (These are expected but may not be ignored yet)
        case "$filepath" in
            Package.swift|workspace.yml|Examples/*/project.yml|.generated/*|msp-ios-sdk.xcworkspace)
                log_warn "File should be in .gitignore: $filepath"
                ;;
            *)
                unexpected_files+="$line"$'\n'
                ;;
        esac
    done <<< "$dirty_files"
    
    if [[ -n "$unexpected_files" ]]; then
        log_error "Unexpected files modified by switching:"
        echo "$unexpected_files" | while IFS= read -r line; do
            [[ -n "$line" ]] && log_error "  $line"
        done
        log_error "Switching should NEVER modify tracked files!"
        return 1
    fi
    
    log_success "Git status check passed (only switching-generated files present)"
    return 0
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
        ((errors++)) || true
    fi
    
    if [[ ! -f "$WORKSPACE_SPEC" ]]; then
        log_error "workspace.yml missing: $WORKSPACE_SPEC"
        ((errors++)) || true
    fi
    
    # Validate Package.swift state (Template Architecture)
    # Template must ALWAYS exist (developer-maintained)
    if [[ ! -f "$PACKAGE_SWIFT_TEMPLATE" ]]; then
        log_error "Package.swift.template missing (developer-maintained file)"
        ((errors++)) || true
    fi
    
    # Clean up legacy .disabled file if it exists
    if [[ -f "$PACKAGE_SWIFT_DISABLED" ]]; then
        log_warn "Legacy Package.swift.disabled found - removing"
        rm -f "$PACKAGE_SWIFT_DISABLED"
    fi
    
    # Mode-specific validation
    case "$target" in
        spm|spm-release)
            # SPM mode: Package.swift must exist (copied from template)
            if [[ ! -f "$PACKAGE_SWIFT" ]]; then
                log_error "Package.swift missing (required for SPM mode)"
                ((errors++)) || true
            fi
            
            if [[ -d "$PODS_DIR" ]]; then
                log_error "Pods/ directory exists (should be removed for SPM)"
                ((errors++)) || true
            fi
            
            # Check project.yml has SPM target, not Pods target
            if grep -q "^  MSPDemoApp:$" "$PROJECT_SPEC" 2>/dev/null; then
                log_error "project.yml contains MSPDemoApp target (should be MSPDemoApp-SPM for SPM mode)"
                ((errors++)) || true
            fi
            
            if ! grep -q "^  MSPDemoApp-SPM:$" "$PROJECT_SPEC" 2>/dev/null; then
                log_error "project.yml missing MSPDemoApp-SPM target (required for SPM mode)"
                ((errors++)) || true
            fi
            
            # Check for Pods xcconfig references
            if grep -q "Pods.*xcconfig\|Pods-MSPDemoApp" "$PROJECT_SPEC" 2>/dev/null; then
                log_error "project.yml contains Pods xcconfig references (should not in SPM mode)"
                ((errors++)) || true
            fi
            
            # Check workspace.yml doesn't include Pods project
            if grep -q "Pods/Pods.xcodeproj" "$WORKSPACE_SPEC" 2>/dev/null; then
                log_error "workspace.yml contains Pods project (should not in SPM mode)"
                ((errors++)) || true
            fi
            
            # Verify required XCFrameworks exist
            if ! check_required_xcframeworks >/dev/null 2>&1; then
                xcf_missing=$?
                log_error "$xcf_missing required XCFramework(s) missing for SPM mode"
                ((errors++)) || true
            fi
            ;;
            
        pods|pods-dev|pods-release)
            # Pods mode: Package.swift must NOT exist (deleted, template preserved)
            if [[ -f "$PACKAGE_SWIFT" ]]; then
                log_error "Package.swift exists (should be removed in Pods mode)"
                ((errors++)) || true
            fi
            
            if [[ ! -d "$PODS_DIR" ]]; then
                log_error "Pods/ directory missing (required for CocoaPods)"
                ((errors++)) || true
            fi
            
            # Check project.yml has Pods target, not SPM target
            if ! grep -q "^  MSPDemoApp:$" "$PROJECT_SPEC" 2>/dev/null; then
                log_error "project.yml missing MSPDemoApp target (required for Pods mode)"
                ((errors++)) || true
            fi
            
            if grep -q "^  MSPDemoApp-SPM:$" "$PROJECT_SPEC" 2>/dev/null; then
                log_error "project.yml contains MSPDemoApp-SPM target (should be MSPDemoApp for Pods mode)"
                ((errors++)) || true
            fi
            
            # Check for Pods xcconfig references
            if ! grep -q "Pods.*xcconfig\|Pods-MSPDemoApp" "$PROJECT_SPEC" 2>/dev/null; then
                log_error "project.yml missing Pods xcconfig references (required for Pods mode)"
                ((errors++)) || true
            fi
            
            # Check that packages section is empty (no SwiftPM packages in Pods mode)
            if grep -q "^packages:" "$PROJECT_SPEC" 2>/dev/null; then
                if ! grep -q "^packages: {}$" "$PROJECT_SPEC" 2>/dev/null; then
                    # Check if there are any package entries (not just empty)
                    if grep -A 1 "^packages:" "$PROJECT_SPEC" 2>/dev/null | grep -qE "^  [A-Za-z]"; then
                        log_error "project.yml contains SwiftPM packages (should be empty in Pods mode)"
                        ((errors++)) || true
                    fi
                fi
            fi
            ;;
    esac
    
    return $errors
}

