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

# Log exit reason on failure (helps debug silent failures from set -e or subshells)
_log_exit_reason() {
  local e=$?
  if [[ $e -ne 0 ]]; then
    local red=""
    local nc=""
    if [[ -t 2 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
      red="\033[1;31m"
      nc="\033[0m"
    fi
    echo -e "${red}ERROR: switch-target.sh exiting with code $e.${nc}" >&2
    if [[ -n "${LAST_ERROR:-}" ]]; then
      echo -e "${red}ERROR MESSAGE: ${LAST_ERROR}${nc}" >&2
    fi
  fi
  exit $e
}
trap _log_exit_reason EXIT

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

# Ensure logger functions are available in subprocess
# (Force reload by unsetting the guard variable, as parent may have already sourced)
if [[ -f "$ROOT_DIR/Scripts/release/utils/logger.sh" ]]; then
    unset MSP_LOGGER_LOADED
    # shellcheck source=Scripts/release/utils/logger.sh
    source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true
fi

# Source process utilities for timeout protection
if [[ -f "$ROOT_DIR/Scripts/lib/process_utils.sh" ]]; then
    # shellcheck source=Scripts/lib/process_utils.sh
    source "$ROOT_DIR/Scripts/lib/process_utils.sh" 2>/dev/null || true
fi

# R029c: Source xcodegen module for unified generation
if [[ -f "$ROOT_DIR/Scripts/lib/xcodegen.sh" ]]; then
    # shellcheck source=Scripts/lib/xcodegen.sh
    source "$ROOT_DIR/Scripts/lib/xcodegen.sh" 2>/dev/null || true
fi

# R040d: Source config loader extension for CocoaPods settings
if [[ -f "$ROOT_DIR/Scripts/lib/config_loader_ext.sh" ]]; then
    # shellcheck source=Scripts/lib/config_loader_ext.sh
    source "$ROOT_DIR/Scripts/lib/config_loader_ext.sh" 2>/dev/null || true
    load_cocoapods_config 2>/dev/null || true
fi

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

# Check if npm install is needed for Git hooks (Husky)
# This is a non-blocking warning - script continues regardless
check_npm_install() {
    # Only check if package.json exists (indicating this repo uses npm)
    if [[ -f "$ROOT_DIR/package.json" ]]; then
        if [[ ! -d "$ROOT_DIR/node_modules" ]]; then
            log::warn "TARGET" "Git hooks not installed (node_modules missing)"
            log::info "TARGET" "Run 'npm install' to set up commit hooks (Husky)"
            log::info "TARGET" "This ensures commit message format validation"
            echo ""
        elif [[ ! -d "$ROOT_DIR/node_modules/husky" ]]; then
            log::warn "TARGET" "Husky not found in node_modules"
            log::info "TARGET" "Run 'npm install' to set up Git commit hooks"
            echo ""
        elif [[ ! -d "$ROOT_DIR/.husky" ]]; then
            log::warn "TARGET" "Husky hooks directory (.husky/) not found"
            log::info "TARGET" "Git hooks may not be properly configured"
            log::info "TARGET" "Try running 'npm install' to fix this"
            echo ""
        fi
    fi
}

# Check if pod install error is network-related
is_network_error() {
    local error_output="$1"
    # Check for common network error patterns
    if echo "$error_output" | grep -qiE "(network|connection|timeout|DNS|resolve|unreachable|failed to download|CDN|specs repo|repository)" || \
       echo "$error_output" | grep -qiE "(curl|fetch|download).*failed" || \
       echo "$error_output" | grep -qiE "Unable to find.*spec" || \
       echo "$error_output" | grep -qiE "CDN.*error"; then
        return 0  # Network error detected
    fi
    return 1  # Not a network error
}

# Run pod install with automatic retry on network errors
run_pod_install_with_retry() {
    local msp_release="${1:-0}"
    local msp_mode="${2:-pods-dev}"
    # R040d: Use configurable values from cocoapods-config.yaml
    local max_attempts="${PODS_MAX_UPDATE_ATTEMPTS:-3}"  # Initial attempt + retries
    local retry_delay="${PODS_RETRY_DELAY:-10}"          # Wait between retries
    local pod_install_timeout="${PODS_POD_INSTALL_TIMEOUT:-1800}"
    local attempt=1
    local last_error_output=""
    
    # UTF-8 environment required for CocoaPods
    export LANG="en_US.UTF-8"
    export LC_ALL="en_US.UTF-8"
    export RUBYOPT="-EUTF-8:UTF-8"
    
    while [[ $attempt -le $max_attempts ]]; do
        if [[ $attempt -gt 1 ]]; then
            log::info "TARGET" "Retrying pod install (attempt $attempt/$max_attempts) after ${retry_delay}s delay..."
            sleep $retry_delay
        fi
        
        log::info "TARGET" "Running pod install (attempt $attempt/$max_attempts)..."
        
        # Capture both stdout and stderr
        local temp_output
        temp_output="$(mktemp)"
        
        # Build pod install command with environment variables
        local pod_cmd_args=()
        pod_cmd_args+=(env)
        pod_cmd_args+=(LANG="en_US.UTF-8")
        pod_cmd_args+=(LC_ALL="en_US.UTF-8")
        pod_cmd_args+=(RUBYOPT="-EUTF-8:UTF-8")
        pod_cmd_args+=(MSP_RELEASE="$msp_release")
        if [[ "$msp_mode" == "pods-dev" ]]; then
            pod_cmd_args+=(MSP_MODE="pods-dev")
        fi
        pod_cmd_args+=(bundle exec pod install)
        
        # Run pod install with timeout
        local exit_code=0
        if command -v run_with_timeout &>/dev/null; then
            if run_with_timeout "$pod_install_timeout" "${pod_cmd_args[@]}" > "$temp_output" 2>&1; then
                log::success "TARGET" "pod install completed successfully (attempt $attempt)"
                rm -f "$temp_output"
                return 0
            else
                exit_code=$?
            fi
        else
            # Fallback: run without timeout
            if "${pod_cmd_args[@]}" > "$temp_output" 2>&1; then
                log::success "TARGET" "pod install completed successfully (attempt $attempt)"
                rm -f "$temp_output"
                return 0
            else
                exit_code=$?
            fi
        fi
        
        # Read error output
        last_error_output="$(cat "$temp_output" 2>/dev/null || echo "")"
        rm -f "$temp_output"
        
        # Check if it's a timeout (exit code 124)
        if [[ $exit_code -eq 124 ]]; then
            log::error "TARGET" "pod install TIMED OUT after $((pod_install_timeout/60)) minutes (attempt $attempt/$max_attempts)"
            if [[ $attempt -lt $max_attempts ]]; then
                log::info "TARGET" "Timeout may be due to network issues, will retry..."
            else
                log::error "TARGET" "All retry attempts exhausted"
                return 1
            fi
        # Check if it's a network error
        elif is_network_error "$last_error_output"; then
            log::warn "TARGET" "Network error detected in pod install (attempt $attempt/$max_attempts)"
            log::info "TARGET" "Error details: $(echo "$last_error_output" | tail -5 | sed 's/^/  /')"
            if [[ $attempt -lt $max_attempts ]]; then
                log::info "TARGET" "Will retry after ${retry_delay}s..."
            else
                log::error "TARGET" "All retry attempts exhausted"
                log::error "TARGET" "Final error output:"
                echo "$last_error_output" | tail -20 | sed 's/^/  /' >&2
                return 1
            fi
        else
            # Non-network error, don't retry
            log::error "TARGET" "pod install failed with non-network error (exit code $exit_code)"
            log::error "TARGET" "Error output:"
            echo "$last_error_output" | tail -20 | sed 's/^/  /' >&2
            return 1
        fi
        
        ((attempt++)) || true
    done
    
    log::error "TARGET" "pod install failed after $max_attempts attempts"
    return 1
}

print_usage() {
    log::info "TARGET" "Usage: $0 {pods-dev|pods-release|spm-release}"
    log::info "TARGET" ""
    log::info "TARGET" "Modes:"
    log::info "TARGET" "  pods-dev      CocoaPods with source files (internal development)"
    log::info "TARGET" "  pods-release  CocoaPods with binary XCFrameworks (pre-release validation)"
    log::info "TARGET" "  spm-release   Swift Package Manager with binary XCFrameworks"
    log::info "TARGET" ""
    log::info "TARGET" "Examples:"
    log::info "TARGET" "  $0 pods-dev      # Switch to development mode (default for SDK engineers)"
    log::info "TARGET" "  $0 pods-release  # Switch to release validation mode"
    log::info "TARGET" "  $0 spm-release   # Switch to SPM release mode"
}

# Validate XCFrameworks exist for release modes
validate_xcframeworks_for_release() {
    log::step "TARGET" "Validating XCFrameworks for release mode"
    
    local errors=0
    local xcf_dir="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks"
    local bin_dir="$ROOT_DIR/Build/ReleaseArtifacts/Binary"
    
    # Check if ReleaseArtifacts/Binary exists and use it instead
    if [[ -d "$bin_dir" ]] && [[ "$(ls -A "$bin_dir" 2>/dev/null)" ]]; then
        xcf_dir="$bin_dir"
        log::info "TARGET" "Using ReleaseArtifacts/Binary for XCFrameworks"
    else
        log::info "TARGET" "Using Build/ReleaseArtifacts/XCFrameworks for XCFrameworks"
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
            log::error "TARGET" "Missing required XCFramework: ${xcf}.xcframework"
            ((errors++)) || true
        elif [[ ! -f "$xcf_dir/${xcf}.xcframework/Info.plist" ]]; then
            log::error "TARGET" "Invalid XCFramework (no Info.plist): ${xcf}.xcframework"
            ((errors++)) || true
        fi
    done
    
    if [[ $errors -gt 0 ]]; then
        log::error "TARGET" "$errors XCFramework(s) missing or invalid"
        log::info "TARGET" ""
        log::info "TARGET" "To build missing XCFrameworks:"
        log::info "TARGET" "  ./Scripts/xcframeworks/build-core.sh"
        return 1
    fi
    
    log::success "TARGET" "All required XCFrameworks validated"
    return 0
}

# Generate Info.plist from template
generate_info_plist() {
    log::step "TARGET" "Generating Info.plist from template"
    
    if [[ -f "$INFO_PLIST_TEMPLATE" ]]; then
        cp "$INFO_PLIST_TEMPLATE" "$INFO_PLIST_OUTPUT"
        log::success "TARGET" "Info.plist generated"
    else
        log::warn "TARGET" "Info.plist.template not found - skipping"
    fi
}

# Run xcodegen
run_xcodegen() {
    log::step "TARGET" "Generating Xcode project from YAML"

    if ! command -v xcodegen &>/dev/null; then
        log_fatal "xcodegen not found. Install via: brew install xcodegen"
        exit 1
    fi

    # R029c: Use xcodegen.sh module if available, fallback to direct call
    local xcodegen_success=false
    if command -v xcodegen_generate &>/dev/null; then
        if xcodegen_generate "$PROJECT_SPEC" "$(dirname "$PROJECT_SPEC")" 2>&1; then
            xcodegen_success=true
        fi
    else
        if xcodegen generate --spec "$PROJECT_SPEC" 2>&1; then
            xcodegen_success=true
        fi
    fi

    if [[ "$xcodegen_success" == "true" ]]; then
        log::success "TARGET" "Xcode project generated"
    else
        log_fatal "xcodegen failed"
        exit 1
    fi
}

# Create workspace symlink at project root
# The actual workspace is generated inside .generated/ to keep root clean
# The symlink allows developers to always use: open msp-ios-sdk.xcworkspace
create_workspace_symlink() {
    log::step "TARGET" "Creating workspace symlink at project root"
    
    local GENERATED_WORKSPACE="$ROOT_DIR/.generated/msp-ios-sdk.xcworkspace"
    local ROOT_SYMLINK="$ROOT_DIR/msp-ios-sdk.xcworkspace"
    
    if [[ ! -d "$GENERATED_WORKSPACE" ]]; then
        log::error "TARGET" "Generated workspace not found at: $GENERATED_WORKSPACE"
        log::error "TARGET" "Workspace generation must have failed - cannot create symlink"
        return 1
    fi
    
    # Verify workspace is valid (has contents.xcworkspacedata)
    if [[ ! -f "$GENERATED_WORKSPACE/contents.xcworkspacedata" ]]; then
        log::error "TARGET" "Workspace exists but is invalid (missing contents.xcworkspacedata): $GENERATED_WORKSPACE"
        return 1
    fi
    
    # Remove existing symlink or directory (force overwrite)
    rm -f "$ROOT_SYMLINK" 2>/dev/null || true
    
    # Create symlink pointing to generated workspace
    if ln -sf ".generated/msp-ios-sdk.xcworkspace" "$ROOT_SYMLINK"; then
        log::success "TARGET" "Workspace symlink created: msp-ios-sdk.xcworkspace → .generated/msp-ios-sdk.xcworkspace"
    else
        log::error "TARGET" "Failed to create workspace symlink"
        return 1
    fi
    
    return 0
}

# Pre-stage XCFrameworks for Pods build
prestage_xcframeworks() {
    log::step "TARGET" "Pre-staging XCFrameworks for Pods build"
    
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
        log::warn "TARGET" "Pods/Target Support Files not found - skipping XCFramework staging"
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
        log::success "TARGET" "Pre-staged XCFrameworks to ${#TARGET_DIRS[@]} location(s)"
    else
        log::warn "TARGET" "No XCFrameworks staged"
    fi
}

# Ensure a pod that uses prepare_command (git clone) has FULL source before pod install.
# CocoaPods generates the pod target from source_files at pod install time. If Sources/ was
# missing or partial, the generated project has incomplete files and "missing type" build errors.
#
# We use "canary paths": a list of relative paths (files or dirs) under the source root that must
# exist. If all exist, we treat the tree as complete. No magic file counts—just paths that only
# exist in a full clone (e.g. Image/ for Kingfisher, or key .swift files for flat layouts).
#
# Usage: ensure_prepare_command_pod_sources <pod_name> <pod_dir_rel> <git_url> <branch_or_tag> \
#   <clone_subdir_name> <source_dir_in_repo> <canary1> [canary2 ...]
#
# Example: ensure_prepare_command_pod_sources "MSPKingfisher" "ThirdParty/MSPKingfisher" \
#   "https://github.com/onevcat/Kingfisher.git" "$(get_podspec_git_tag ThirdParty/MSPKingfisher/MSPKingfisher.podspec)" "kingfisher" "Sources" "Image" "General"
ensure_prepare_command_pod_sources() {
    local pod_name="$1"
    local pod_dir_rel="$2"
    local git_url="$3"
    local branch_or_tag="$4"
    local clone_subdir_name="$5"   # e.g. kingfisher -> clone into temp/kingfisher
    local source_dir_in_repo="$6"  # e.g. Sources -> we copy temp/kingfisher/Sources to pod_dir/Sources
    shift 6
    local canary_paths=("$@")      # paths under source root that must exist (files or dirs)

    local pod_dir="$ROOT_DIR/$pod_dir_rel"
    local sources_dir="$pod_dir/$source_dir_in_repo"
    local canaries_ok=1

    if [[ -d "$sources_dir" ]]; then
        for path in "${canary_paths[@]}"; do
            [[ -z "$path" ]] && continue
            if [[ ! -e "$sources_dir/$path" ]]; then
                canaries_ok=0
                break
            fi
        done
        if [[ $canaries_ok -eq 1 ]]; then
            log_success "$pod_name sources already present (canary paths OK)"
            return 0
        fi
        log_info "$pod_name source tree incomplete (canary path(s) missing); re-downloading"
        rm -rf "$sources_dir"
    fi

    log_step "Ensuring $pod_name sources (required for pods-dev; avoids 'missing type' build errors)"
    if [[ ! -d "$pod_dir" ]]; then
        log_error "$pod_name directory missing: $pod_dir"
        exit 1
    fi

    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local clone_log
    clone_log="$(mktemp)"
    trap 'rm -f "$clone_log"' EXIT

    log_info "Downloading $pod_name source (branch/tag: $branch_or_tag)..."
    if ! git clone --depth 1 --branch "$branch_or_tag" "$git_url" "$tmp_dir/$clone_subdir_name" > "$clone_log" 2>&1; then
        log_error "Failed to clone $pod_name source (network or git issue)"
        log_info "Git clone output (for troubleshooting):"
        sed 's/^/  /' "$clone_log" >&2
        log_info "Ensure you have network access and git installed, then re-run switch-target.sh pods-dev"
        rm -rf "$tmp_dir"
        exit 1
    fi

    local cloned_sources="$tmp_dir/$clone_subdir_name/$source_dir_in_repo"
    if [[ ! -d "$cloned_sources" ]]; then
        log_error "Cloned $pod_name repo missing $source_dir_in_repo/ directory"
        rm -rf "$tmp_dir"
        exit 1
    fi

    rm -rf "$sources_dir"
    cp -R "$cloned_sources" "$sources_dir"
    rm -rf "$tmp_dir"
    rm -f "$clone_log"

    for path in "${canary_paths[@]}"; do
        [[ -z "$path" ]] && continue
        if [[ ! -e "$sources_dir/$path" ]]; then
            log_error "$pod_name source tree incomplete after copy (missing $source_dir_in_repo/$path)"
            exit 1
        fi
    done
    log_success "$pod_name sources ready at $sources_dir"
    return 0
}

# Read git tag from a podspec (s.source => { :git => "...", :tag => "X.Y.Z" }). Single source of truth for version.
get_podspec_git_tag() {
    local podspec_path="$ROOT_DIR/$1"
    if [[ ! -f "$podspec_path" ]]; then
        log_error "Podspec not found: $podspec_path"
        return 1
    fi
    local tag
    tag=$(sed -n 's/.*:tag *=> *"\([^"]*\)".*/\1/p' "$podspec_path" | head -1)
    if [[ -z "$tag" ]]; then
        log_error "Could not read :tag from podspec: $podspec_path"
        return 1
    fi
    echo "$tag"
}

# Ensure all pods that rely on prepare_command (git clone) have full source before pod install.
# Each pod lists "canary" paths (relative to Sources/) that must exist; no magic file counts.
# Version (branch/tag) is read from each podspec so we only maintain it in one place.
ensure_all_prepare_command_pod_sources() {
    local kf_tag snap_tag
    kf_tag=$(get_podspec_git_tag "ThirdParty/MSPKingfisher/MSPKingfisher.podspec") || return 1
    snap_tag=$(get_podspec_git_tag "ThirdParty/MSPSnapKit/MSPSnapKit.podspec") || return 1

    # MSPKingfisher: Kingfisher has Sources/{Cache,Extensions,General,Image,...}; need Image + General for core types
    ensure_prepare_command_pod_sources \
        "MSPKingfisher" \
        "ThirdParty/MSPKingfisher" \
        "https://github.com/onevcat/Kingfisher.git" \
        "$kf_tag" \
        "kingfisher" \
        "Sources" \
        "Image" "General"

    # MSPSnapKit: SnapKit has flat Sources/*.swift; require two core files so we don't accept empty or truncated copy
    ensure_prepare_command_pod_sources \
        "MSPSnapKit" \
        "ThirdParty/MSPSnapKit" \
        "https://github.com/SnapKit/SnapKit.git" \
        "$snap_tag" \
        "snapkit" \
        "Sources" \
        "Constraint.swift" "LayoutConstraint.swift"
}

# Validate final state for a mode
validate_final_state() {
    local mode="$1"
    local errors=0
    
    log::step "TARGET" "Validating final state for $mode"
    
    case "$mode" in
        pods-dev|pods-release)
            # Pods/ must exist
            if [[ ! -d "$PODS_DIR" ]]; then
                log::error "TARGET" "Pods/ directory missing"
                ((errors++)) || true
            fi
            
            # Package.swift must NOT exist
            if [[ -f "$PACKAGE_SWIFT" ]]; then
                log::error "TARGET" "Package.swift exists (should be removed in Pods mode)"
                ((errors++)) || true
            fi
            
            # Package.swift.template must exist
            if [[ ! -f "$PACKAGE_SWIFT_TEMPLATE" ]]; then
                log::error "TARGET" "Package.swift.template missing"
                ((errors++)) || true
            fi
            
            # project.yml must have MSPDemoApp target
            if ! grep -q "^  MSPDemoApp:$" "$PROJECT_SPEC" 2>/dev/null; then
                log::error "TARGET" "project.yml missing MSPDemoApp target"
                ((errors++)) || true
            fi
            
            # project.yml must have packages: {}
            if ! grep -q "^packages: {}$" "$PROJECT_SPEC" 2>/dev/null; then
                log::error "TARGET" "project.yml should have packages: {} in Pods mode"
                ((errors++)) || true
            fi
            ;;
            
        spm-release)
            # Pods/ must NOT exist
            if [[ -d "$PODS_DIR" ]]; then
                log::error "TARGET" "Pods/ directory exists (should be removed in SPM mode)"
                ((errors++)) || true
            fi
            
            # Package.swift must exist
            if [[ ! -f "$PACKAGE_SWIFT" ]]; then
                log::error "TARGET" "Package.swift missing (required for SPM mode)"
                ((errors++)) || true
            fi
            
            # project.yml must have MSPDemoApp-SPM target
            if ! grep -q "^  MSPDemoApp-SPM:$" "$PROJECT_SPEC" 2>/dev/null; then
                log::error "TARGET" "project.yml missing MSPDemoApp-SPM target"
                ((errors++)) || true
            fi
            ;;
    esac
    
    if [[ $errors -gt 0 ]]; then
        log::error "TARGET" "Validation failed with $errors error(s)"
        return 1
    fi
    
    log::success "TARGET" "Validation passed"
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
        log::success "TARGET" "Ready for ${mode} workflow"
    else
        log::error "TARGET" "Switch failed - see errors above"
    fi
}

# ============================================================================
# MODE: pods-dev (Development mode with source files)
# ============================================================================

switch_pods_dev() {
    log_title "Switching to PODS-DEV Mode"
    log::info "TARGET" "Mode: CocoaPods with source files (internal development)"
    log::info "TARGET" "MSP_RELEASE=0, MSP_MODE=pods-dev"
    log::info "TARGET" ""
    
    check_npm_install
    
    export MSP_RELEASE=0
    export MSP_MODE=pods-dev
    
    # Step 1: Clean SPM artifacts
    log_section "Environment Cleanup"
    log::step "TARGET" "Cleaning SPM artifacts"
    if "$SWITCH_TARGET_SCRIPT_DIR/target-switching/cleanup_spm.sh" --force 2>/dev/null; then
        log::success "TARGET" "SPM cleanup completed"
    else
        log::warn "TARGET" "SPM cleanup had warnings (continuing)"
    fi
    
    # Step 2: Remove Package.swift
    log::step "TARGET" "Removing Package.swift"
    ensure_package_swift_disabled
    
    # Step 3: Clean existing Pods to force regeneration
    # This ensures CocoaPods removes XCFramework copy phases in pods-dev mode
    log::step "TARGET" "Cleaning existing Pods (force regeneration)"
    if [[ -d "$PODS_DIR" ]]; then
        rm -rf "$PODS_DIR"
        log::success "TARGET" "Pods/ removed"
    fi
    if [[ -f "$ROOT_DIR/Podfile.lock" ]]; then
        rm -f "$ROOT_DIR/Podfile.lock"
        log::success "TARGET" "Podfile.lock removed"
    fi
    
    # Also clean DemoApp Pods directory if it exists
    local DEMOAPP_PODS_DIR="$ROOT_DIR/Examples/DemoApp/Pods"
    local DEMOAPP_PODFILE_LOCK="$ROOT_DIR/Examples/DemoApp/Podfile.lock"
    if [[ -d "$DEMOAPP_PODS_DIR" ]]; then
        rm -rf "$DEMOAPP_PODS_DIR"
        log::success "TARGET" "Examples/DemoApp/Pods/ removed"
    fi
    if [[ -f "$DEMOAPP_PODFILE_LOCK" ]]; then
        rm -f "$DEMOAPP_PODFILE_LOCK"
        log::success "TARGET" "Examples/DemoApp/Podfile.lock removed"
    fi
    
    # Step 4: Generate project.yml from templates (BEFORE pod install)
    # CRITICAL: MSPDemoApp.xcodeproj must exist BEFORE pod install runs
    log_section "YAML Generation"
    log::step "TARGET" "Generating project.yml from templates (excluding MSPDemoApp - handled by generate_workspace.sh)"
    if [[ -x "$SWITCH_TARGET_SCRIPT_DIR/target-switching/generate_project_templates.sh" ]]; then
        "$SWITCH_TARGET_SCRIPT_DIR/target-switching/generate_project_templates.sh"
    fi
    
    # Step 4.5: Generate workspace YAML (which also generates MSPDemoApp/project.yml with proper placeholders)
    # CRITICAL: generate_workspace.sh generates MSPDemoApp/project.yml with placeholders replaced
    log::step "TARGET" "Generating workspace/project YAML (includes MSPDemoApp/project.yml)"
    if "$SWITCH_TARGET_SCRIPT_DIR/target-switching/generate_workspace.sh" pods-dev; then
        log::success "TARGET" "Workspace YAML generated (MSPDemoApp/project.yml created with placeholders replaced)"
    else
        log::error "TARGET" "Workspace YAML generation failed"
        exit 1
    fi
    
    # Step 5: Generate MSPDemoApp.xcodeproj from project.yml (BEFORE pod install)
    # CRITICAL: Podfile references 'Examples/MSPDemoApp/MSPDemoApp' - project MUST exist
    log_section "Xcode Project Generation (Pre-pod-install)"
    log::step "TARGET" "Generating MSPDemoApp.xcodeproj from project.yml"
    
    if [[ ! -f "$PROJECT_SPEC" ]]; then
        log::error "TARGET" "project.yml not found: $PROJECT_SPEC"
        log::error "TARGET" "Workspace YAML generation must have failed"
        exit 1
    fi
    
    if ! command -v xcodegen &>/dev/null; then
        log_fatal "xcodegen not found. Install via: brew install xcodegen"
        exit 1
    fi
    
    # Generate MSPDemoApp project (run from project directory for correct relative paths)
    local PROJECT_DIR="$(dirname "$PROJECT_SPEC")"
    local PROJECT_YML_NAME="$(basename "$PROJECT_SPEC")"
    # R029c: Use xcodegen.sh module if available, fallback to direct call
    local demoapp_xcodegen_success=false
    if command -v xcodegen_generate &>/dev/null; then
        if xcodegen_generate "$PROJECT_SPEC" "$PROJECT_DIR" 2>&1; then
            demoapp_xcodegen_success=true
        fi
    else
        if (cd "$PROJECT_DIR" && xcodegen generate --spec "$PROJECT_YML_NAME" 2>&1); then
            demoapp_xcodegen_success=true
        fi
    fi

    if [[ "$demoapp_xcodegen_success" != "true" ]]; then
        log::error "TARGET" "Failed to generate MSPDemoApp.xcodeproj from project.yml"
        log::error "TARGET" "This must succeed before pod install can run"
        exit 1
    fi
    
    # Verify project was generated at expected location
    local EXPECTED_PROJECT="$PROJECT_DIR/MSPDemoApp.xcodeproj"
    if [[ ! -d "$EXPECTED_PROJECT" ]]; then
        log::error "TARGET" "MSPDemoApp.xcodeproj not found at expected location: $EXPECTED_PROJECT"
        log::error "TARGET" "XcodeGen generation appeared to succeed but project is missing"
        exit 1
    fi
    
    log::success "TARGET" "MSPDemoApp.xcodeproj generated: $EXPECTED_PROJECT"
    
    # Step 6: Precondition check before pod install
    log_section "Precondition Check"
    log::step "TARGET" "Verifying MSPDemoApp.xcodeproj exists before pod install"
    local PODFILE_PROJECT_PATH="$ROOT_DIR/Examples/MSPDemoApp/MSPDemoApp.xcodeproj"
    if [[ ! -d "$PODFILE_PROJECT_PATH" ]]; then
        log::error "TARGET" "MSPDemoApp.xcodeproj missing at Podfile-expected path: $PODFILE_PROJECT_PATH"
        log::error "TARGET" "Podfile references: project 'Examples/MSPDemoApp/MSPDemoApp'"
        log::error "TARGET" "Project generation step must have failed - cannot proceed with pod install"
        exit 1
    fi
    
    if [[ ! -f "$PODFILE_PROJECT_PATH/project.pbxproj" ]]; then
        log::error "TARGET" "MSPDemoApp.xcodeproj exists but is invalid (missing project.pbxproj)"
        log::error "TARGET" "XcodeGen generation may have failed silently"
        exit 1
    fi
    
    log::success "TARGET" "MSPDemoApp.xcodeproj verified: $PODFILE_PROJECT_PATH"

    # Step 6.5: Ensure prepare_command pod sources exist before pod install
    # MSPKingfisher/MSPSnapKit Sources/ are gitignored and must be downloaded
    # before pod install can resolve them. On a clean clone these won't exist.
    log::step "TARGET" "Ensuring prepare_command pod sources (MSPKingfisher, MSPSnapKit)"
    ensure_all_prepare_command_pod_sources

    # Step 7: Run pod install (AFTER project generation)
    # CRITICAL: pod install requires MSPDemoApp.xcodeproj to exist
    log_section "CocoaPods Installation"
    log::step "TARGET" "Running pod install (MSP_RELEASE=0, MSP_MODE=pods-dev)"
    log::info "TARGET" "All modules compiled from SOURCE (path-based pods)"
    log::info "TARGET" "XCFramework copy phases will be REMOVED by Podfile post_install"
    
    cd "$ROOT_DIR"
    # Run pod install with automatic retry on network errors
    # Retry logic: up to 3 attempts (initial + 2 retries), 10s delay between retries
    # Timeout: 30 minutes per attempt
    # Rationale: First-time install (no Podfile.lock) can take 15-20 min for specs repo update + dependency resolution
    # Safety margin: 30 min = 1.5-2x observed time (increased from 20 min due to observed timeouts)
    log::info "TARGET" "Running pod install with automatic network error retry (max 3 attempts, 10s delay)..."
    if run_pod_install_with_retry 0 "pods-dev"; then
        log::success "TARGET" "pod install completed (pure source mode)"
    else
        log::error "TARGET" "pod install failed after all retry attempts"
        log::error "TARGET" ""
        log::error "TARGET" "Troubleshooting:"
        log::error "TARGET" "  1. Check network: curl -I https://cdn.cocoapods.org"
        log::error "TARGET" "  2. Manually update specs: pod repo update"
        log::error "TARGET" "  3. Check Podfile for complex dependencies"
        exit 1
    fi
    
    # Step 8: Regenerate workspace YAML (AFTER pod install)
    # Workspace generation includes Pods project, so it must be regenerated after pod install
    # CRITICAL: Do NOT regenerate MSPDemoApp.xcodeproj after pod install!
    # CocoaPods owns the build graph and dependencies after pod install.
    # XcodeGen must only run BEFORE pod install (Step 5).
    log_section "Workspace YAML Regeneration"
    log::step "TARGET" "Regenerating workspace YAML (includes Pods project)"
    log::info "TARGET" "Note: MSPDemoApp.xcodeproj is NOT regenerated - CocoaPods owns build dependencies"
    if "$SWITCH_TARGET_SCRIPT_DIR/target-switching/generate_workspace.sh" pods-dev; then
        log::success "TARGET" "Workspace YAML regenerated (includes Pods project)"
    else
        log::error "TARGET" "Workspace YAML regeneration failed"
        exit 1
    fi
    
    # Step 9: Create workspace symlink at root
    log_section "Workspace Symlink"
    if ! create_workspace_symlink; then
        log::error "TARGET" "Failed to create workspace symlink - workspace generation must have failed"
        print_summary "pods-dev" "FAILED"
        exit 1
    fi
    
    # Step 10: Generate Info.plist
    log_section "Info.plist Generation"
    generate_info_plist
    
    # Step 11: Validate final state
    log_section "Validation"
    if ! validate_final_state "pods-dev"; then
        print_summary "pods-dev" "FAILED"
        exit 1
    fi
    
    # Step 11.5: Final workspace existence check (strong contract)
    log_section "Final Workspace Verification"
    local FINAL_WORKSPACE="$ROOT_DIR/msp-ios-sdk.xcworkspace"
    if [[ ! -L "$FINAL_WORKSPACE" ]] && [[ ! -d "$FINAL_WORKSPACE" ]]; then
        log::error "TARGET" "Workspace does not exist at expected location: $FINAL_WORKSPACE"
        log::error "TARGET" "This violates the pods-dev contract - workspace MUST exist on success"
        print_summary "pods-dev" "FAILED"
        exit 1
    fi
    
    if [[ -L "$FINAL_WORKSPACE" ]]; then
        local SYMLINK_TARGET
        SYMLINK_TARGET="$(readlink "$FINAL_WORKSPACE" 2>/dev/null || echo "")"
        if [[ -z "$SYMLINK_TARGET" ]] || [[ ! -d "$ROOT_DIR/$SYMLINK_TARGET" ]]; then
            log::error "TARGET" "Workspace symlink is broken: $FINAL_WORKSPACE → $SYMLINK_TARGET"
            log::error "TARGET" "Target does not exist or is not accessible"
            print_summary "pods-dev" "FAILED"
            exit 1
        fi
    fi
    
    log::success "TARGET" "Workspace verified: $FINAL_WORKSPACE exists and is valid"
    
    # Step 12: Git cleanliness check
    log_section "Git Status Check"
    verify_git_cleanliness || log::warn "TARGET" "Git status not fully clean"
    
    # Step 13: Open Xcode
    log_section "Opening Xcode"
    if [[ -L "$ROOT_DIR/msp-ios-sdk.xcworkspace" ]] || [[ -d "$ROOT_DIR/msp-ios-sdk.xcworkspace" ]]; then
        open "$ROOT_DIR/msp-ios-sdk.xcworkspace"
        log::success "TARGET" "Opened workspace"
    fi
    
    print_summary "pods-dev" "SUCCESS"
    
    log_section "Next Steps"
    log::info "TARGET" "1. Build MSPDemoApp target in Xcode"
    log::info "TARGET" "2. All modules compile from source files"
    log::info "TARGET" "3. Make code changes and iterate quickly"
}

# ============================================================================
# MODE: pods-release (Release validation with binary XCFrameworks)
# ============================================================================

switch_pods_release() {
    log_title "Switching to PODS-RELEASE Mode"
    log::info "TARGET" "Mode: CocoaPods with binary XCFrameworks (pre-release validation)"
    log::info "TARGET" "MSP_RELEASE=1, MSP_MODE=pods-release"
    log::info "TARGET" ""
    
    check_npm_install
    
    export MSP_RELEASE=1
    export MSP_MODE=pods-release
    
    # Step 1: Validate XCFrameworks exist
    log_section "XCFramework Validation"
    if ! validate_xcframeworks_for_release; then
        log::error "TARGET" "Cannot switch to pods-release without XCFrameworks"
        log::info "TARGET" "Build XCFrameworks first: ./Scripts/xcframeworks/build-core.sh"
        exit 1
    fi
    
    # Step 2: Clean SPM artifacts
    log_section "Environment Cleanup"
    log::step "TARGET" "Cleaning SPM artifacts"
    if "$SWITCH_TARGET_SCRIPT_DIR/target-switching/cleanup_spm.sh" --force 2>/dev/null; then
        log::success "TARGET" "SPM cleanup completed"
    else
        log::warn "TARGET" "SPM cleanup had warnings (continuing)"
    fi
    
    # Step 3: Remove Package.swift
    log::step "TARGET" "Removing Package.swift"
    ensure_package_swift_disabled
    
    # Step 4: Generate project.yml from templates
    log_section "YAML Generation"
    log::step "TARGET" "Generating project.yml from templates"
    if [[ -x "$SWITCH_TARGET_SCRIPT_DIR/target-switching/generate_project_templates.sh" ]]; then
        "$SWITCH_TARGET_SCRIPT_DIR/target-switching/generate_project_templates.sh"
    fi
    
    log::step "TARGET" "Generating workspace/project YAML"
    if "$SWITCH_TARGET_SCRIPT_DIR/target-switching/generate_workspace.sh" pods-release; then
        log::success "TARGET" "YAML generated"
    else
        log::error "TARGET" "YAML generation failed"
        exit 1
    fi
    
    # Step 4.5: Ensure prepare_command pod sources exist before pod install
    log::step "TARGET" "Ensuring prepare_command pod sources (MSPKingfisher, MSPSnapKit)"
    ensure_all_prepare_command_pod_sources

    # Step 5: Run pod install (with MSP_RELEASE=1)
    log_section "CocoaPods Installation"
    log::step "TARGET" "Running pod install (MSP_RELEASE=1)"
    log::info "TARGET" "Core modules use BINARY XCFrameworks, adapters use SOURCE"

    cd "$ROOT_DIR"
    # Run pod install with automatic retry on network errors
    # Retry logic: up to 3 attempts (initial + 2 retries), 10s delay between retries
    # Timeout: 30 minutes per attempt
    # Rationale: Same as pods-dev mode - first-time install can be slow (increased from 20 min)
    log::info "TARGET" "Running pod install with automatic network error retry (max 3 attempts, 10s delay)..."
    if run_pod_install_with_retry 1 ""; then
        log::success "TARGET" "pod install completed"
    else
        log::error "TARGET" "pod install failed after all retry attempts"
        log::error "TARGET" "This usually indicates network or dependency resolution issues"
        exit 1
    fi
    
    # Step 6: Generate Xcode project
    log_section "Xcode Project Generation"
    run_xcodegen
    
    # Step 7: Create workspace symlink at root
    log_section "Workspace Symlink"
    if ! create_workspace_symlink; then
        log::error "TARGET" "Failed to create workspace symlink - workspace generation must have failed"
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
        log::error "TARGET" "Workspace does not exist at expected location: $FINAL_WORKSPACE"
        log::error "TARGET" "This violates the pods-release contract - workspace MUST exist on success"
        print_summary "pods-release" "FAILED"
        exit 1
    fi
    
    if [[ -L "$FINAL_WORKSPACE" ]]; then
        local SYMLINK_TARGET
        SYMLINK_TARGET="$(readlink "$FINAL_WORKSPACE" 2>/dev/null || echo "")"
        if [[ -z "$SYMLINK_TARGET" ]] || [[ ! -d "$ROOT_DIR/$SYMLINK_TARGET" ]]; then
            log::error "TARGET" "Workspace symlink is broken: $FINAL_WORKSPACE → $SYMLINK_TARGET"
            log::error "TARGET" "Target does not exist or is not accessible"
            print_summary "pods-release" "FAILED"
            exit 1
        fi
    fi
    
    log::success "TARGET" "Workspace verified: $FINAL_WORKSPACE exists and is valid"
    
    # Step 11: Git cleanliness check
    log_section "Git Status Check"
    verify_git_cleanliness || log::warn "TARGET" "Git status not fully clean"
    
    # Step 12: Open Xcode
    log_section "Opening Xcode"
    if [[ -L "$ROOT_DIR/msp-ios-sdk.xcworkspace" ]] || [[ -d "$ROOT_DIR/msp-ios-sdk.xcworkspace" ]]; then
        open "$ROOT_DIR/msp-ios-sdk.xcworkspace"
        log::success "TARGET" "Opened workspace"
    fi
    
    print_summary "pods-release" "SUCCESS"
    
    log_section "Next Steps"
    log::info "TARGET" "1. Build MSPDemoApp target in Xcode"
    log::info "TARGET" "2. Verify XCFrameworks link correctly"
    log::info "TARGET" "3. Run integration tests before release"
}

# ============================================================================
# MODE: spm-release (SPM with binary XCFrameworks)
# ============================================================================

switch_spm_release() {
    log_title "Switching to SPM-RELEASE Mode"
    log::info "TARGET" "Mode: Swift Package Manager with binary XCFrameworks"
    log::info "TARGET" ""
    
    check_npm_install
    
    # Step 1: Validate XCFrameworks exist
    log_section "XCFramework Validation"
    if ! validate_xcframeworks_for_release; then
        log::error "TARGET" "Cannot switch to spm-release without XCFrameworks"
        log::info "TARGET" "Build XCFrameworks first: ./Scripts/xcframeworks/build-core.sh"
        exit 1
    fi
    
    # Step 2: Clean CocoaPods artifacts
    log_section "Environment Cleanup"
    log::step "TARGET" "Cleaning CocoaPods artifacts"
    
    # Remove workspace first
    if [[ -d "$PODS_WORKSPACE" ]]; then
        safe_remove_workspace "$PODS_WORKSPACE"
        log::success "TARGET" "Workspace removed"
    fi
    
    # Remove Pods directory
    if [[ -d "$PODS_DIR" ]]; then
        if safe_remove_directory "$PODS_DIR" "Pods"; then
            log::success "TARGET" "Pods/ removed"
        else
            log::error "TARGET" "Failed to remove Pods/"
            exit 1
        fi
    fi
    
    # Step 3: Clean SPM caches
    log::step "TARGET" "Cleaning SPM caches"
    if "$SWITCH_TARGET_SCRIPT_DIR/target-switching/cleanup_spm.sh" --force 2>/dev/null; then
        log::success "TARGET" "SPM cleanup completed"
    else
        log::warn "TARGET" "SPM cleanup had warnings (continuing)"
    fi
    
    # Step 4: Generate Package.swift from template
    log_section "Package.swift Generation"
    log::step "TARGET" "Generating Package.swift from template"
    if ! ensure_package_swift_enabled "spm-release"; then
        log::error "TARGET" "Failed to generate Package.swift"
        exit 1
    fi
    
    # Step 5: Generate project.yml from templates
    log_section "YAML Generation"
    log::step "TARGET" "Generating project.yml from templates"
    if [[ -x "$SWITCH_TARGET_SCRIPT_DIR/target-switching/generate_project_templates.sh" ]]; then
        "$SWITCH_TARGET_SCRIPT_DIR/target-switching/generate_project_templates.sh"
    fi
    
    log::step "TARGET" "Generating workspace/project YAML"
    if "$SWITCH_TARGET_SCRIPT_DIR/target-switching/generate_workspace.sh" spm-release; then
        log::success "TARGET" "YAML generated"
    else
        log::error "TARGET" "YAML generation failed"
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
    log::step "TARGET" "Verifying XCFramework paths in Package.swift"
    
    local missing_refs=0
    for xcf in "MSPSharedLibraries" "MSPiOSCore" "MSPCore" "NovaCore" "MSPOMSDK"; do
        if ! grep -q "\"${xcf}\"" "$PACKAGE_SWIFT" 2>/dev/null; then
            log::warn "TARGET" "Package.swift missing reference to: $xcf"
            ((missing_refs++)) || true
        fi
    done
    
    if [[ $missing_refs -eq 0 ]]; then
        log::success "TARGET" "All XCFramework references found in Package.swift"
    else
        log::warn "TARGET" "$missing_refs module(s) not referenced in Package.swift"
    fi
    
    # Step 10: Validate final state
    log_section "Validation"
    if ! validate_final_state "spm-release"; then
        print_summary "spm-release" "FAILED"
        exit 1
    fi
    
    # Step 11: Git cleanliness check
    log_section "Git Status Check"
    verify_git_cleanliness || log::warn "TARGET" "Git status not fully clean"
    
    # Step 12: Open Xcode project
    # Note: SPM mode uses the .xcodeproj directly with Package.swift dependencies
    log_section "Opening Xcode"
    local PROJECT_DIR="$(dirname "$PROJECT_SPEC")"
    if [[ -d "$PROJECT_DIR/MSPDemoApp.xcodeproj" ]]; then
        open "$PROJECT_DIR/MSPDemoApp.xcodeproj"
        log::success "TARGET" "Opened SPM project"
    fi
    
    print_summary "spm-release" "SUCCESS"
    
    log_section "Next Steps"
    log::info "TARGET" "1. Wait for Xcode to resolve packages"
    log::info "TARGET" "2. Build MSPDemoApp-SPM target"
    log::info "TARGET" "3. Verify all XCFrameworks link correctly"
}

# ============================================================================
# BACKWARD COMPATIBILITY: Support old 'pods' and 'spm' commands
# ============================================================================

switch_legacy_pods() {
    log::warn "TARGET" "Deprecated: 'pods' mode is now 'pods-dev'"
    log::info "TARGET" "Redirecting to pods-dev mode..."
    log::info "TARGET" ""
    switch_pods_dev
}

switch_legacy_spm() {
    log::warn "TARGET" "Deprecated: 'spm' mode is now 'spm-release'"
    log::info "TARGET" "Redirecting to spm-release mode..."
    log::info "TARGET" ""
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
        log::error "TARGET" "Unknown mode: $MODE"
        log::info "TARGET" ""
        print_usage
        exit 1
        ;;
esac
