#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch M, shared) ---
# shellcheck source=/dev/null
_msp_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$_msp_root" ] && [ -f "$_msp_root/Scripts/lib/worktree_guard.sh" ]; then
  . "$_msp_root/Scripts/lib/worktree_guard.sh"
  msp_enforce_main_repo_or_exit
fi
unset _msp_root
# --- End MSP Worktree Safety Guard (Patch M, shared) ---

# Modular SPM Release Script
# Releases Swift Package Manager packages
#
# Phase 2 Step 4: Config-driven release
# This script now uses environment variables from msp-release.sh instead of CLI arguments.

set -euo pipefail

# Source path helpers and common library
# shellcheck source=Scripts/lib/path-helpers.sh
source "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/path-helpers.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# Load Notification Functions
# ============================================================================
# Load Slack notification functions if available
if [[ -f "$ROOT_DIR/Scripts/notify/slack.sh" ]]; then
    # shellcheck source=Scripts/notify/slack.sh
    source "$ROOT_DIR/Scripts/notify/slack.sh"
    log::debug "SPM" "[NOTIFY] Loaded Slack notification functions from: Scripts/notify/slack.sh" 2>/dev/null || true
else
    # Define stub functions to prevent errors (backward compatibility)
    log::debug "SPM" "[NOTIFY] Slack notification functions not found, using stub functions" 2>/dev/null || true
    notify_release_failure() { :; }
    notify_release_success() { :; }
    notify_release_success_with_summary() { :; }
    notify_release_warning() { :; }
fi

source "$ROOT_DIR/Scripts/lib/release-common.sh"

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
    echo -e "${red}ERROR: $(basename "$0") exiting with code $e.${nc}" >&2
    if [[ -n "${LAST_ERROR:-}" ]]; then
      echo -e "${red}ERROR MESSAGE: ${LAST_ERROR}${nc}" >&2
    fi
  fi
  exit $e
}
trap _log_exit_reason EXIT

# Load release state utilities (state.sh is already loaded by release-common.sh, but we can source it again if needed)
# Use absolute path to ensure correct location
if [[ -f "$ROOT_DIR/Scripts/release/utils/state.sh" ]]; then
    source "$ROOT_DIR/Scripts/release/utils/state.sh" 2>/dev/null || true
fi

# ============================================================================
# Source Shared Modules (DRY Principle)
# ============================================================================
# These modules provide reusable functionality across release scripts

# Shared input validation (version, branch validation)
if [[ -f "$ROOT_DIR/Scripts/lib/shared/input_validation.sh" ]]; then
    source "$ROOT_DIR/Scripts/lib/shared/input_validation.sh"
fi

# Shared CDN verification (wait, verify URLs)
if [[ -f "$ROOT_DIR/Scripts/lib/shared/cdn_verify.sh" ]]; then
    source "$ROOT_DIR/Scripts/lib/shared/cdn_verify.sh"
fi

# R015b: Source step lifecycle module for unified step management
if [[ -f "$ROOT_DIR/Scripts/lib/shared/step_lifecycle.sh" ]]; then
    source "$ROOT_DIR/Scripts/lib/shared/step_lifecycle.sh" 2>/dev/null || true
    log::debug "SPM" "[PUBLISH] Loaded step_lifecycle.sh module"
fi

# ============================================================================
# Source SPM-Specific Modules (DRY Principle)
# ============================================================================
# These modules are specific to SPM release workflow

# SPM XCFramework zip operations (create, checksum, upload)
if [[ -f "$SCRIPT_DIR/lib/xcframework_zip.sh" ]]; then
    source "$SCRIPT_DIR/lib/xcframework_zip.sh"
fi

# SPM CDN verification (availability, checksum verification)
if [[ -f "$SCRIPT_DIR/lib/cdn_verification.sh" ]]; then
    source "$SCRIPT_DIR/lib/cdn_verification.sh"
fi

# ============================================================================
# Environment Variable Validation
# ============================================================================
# Check if required environment variables are set (from msp-release.sh)
# If not set, fall back to CLI argument parsing for backward compatibility

if [[ -z "${RELEASE_VERSION:-}" ]]; then
    # Backward compatibility: extract from CLI if called directly
    if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
        RELEASE_VERSION="$1"
        shift
    else
        log::error "SPM" "RELEASE_VERSION not set. Did you forget to run via msp-release.sh?"
        log::info "SPM" "Usage: msp-release.sh spm <VERSION>"
        log::info "SPM" "   or: $0 <VERSION> [OPTIONS]  (direct call for debugging)"
        exit 1
    fi
fi

# Use environment variables with CLI fallback for backward compatibility
VERSION="${RELEASE_VERSION:-}"
RELEASE_BRANCH="${RELEASE_BRANCH:-}"
RELEASE_NOTES="${RELEASE_NOTES:-}"
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"

# Default SPM packages if SPM_PACKAGES not set (backward compatibility)
# Includes all adapters that support binary distribution
DEFAULT_SPM_PACKAGES="NovaCore MSPNovaAdapter MSPAmazonAdapter MSPMolocoAdapter MSPLiftoffAdapter"
SPM_PACKAGES="${SPM_PACKAGES:-$DEFAULT_SPM_PACKAGES}"

# ============================================================================
# Backward Compatibility: CLI Argument Parsing
# ============================================================================
# Only used if script is called directly (not via msp-release.sh)
parse_arguments() {
    # Only parse if we have remaining CLI args (backward compatibility)
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                echo "Modular SPM Release Script v2.0.0-phase2"
                exit 0
                ;;
            --release-branch)
                RELEASE_BRANCH="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --verbose)
                VERBOSE="true"
                shift
                ;;
            --release-notes)
                RELEASE_NOTES="$2"
                shift 2
                ;;
            *)
                # Unknown argument - ignore (already processed VERSION above)
                shift
                ;;
        esac
    done
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS] <VERSION>"
    echo ""
    echo "Arguments:"
    echo "  VERSION                 Version to release (e.g., 0.0.2-migration-spm)"
    echo ""
    echo "Options:"
    echo "  --release-branch BRANCH Release branch to work on (default: release/VERSION)"
    echo "  --release-notes NOTES   Release notes for this version"
    echo "  --dry-run               Show what would be done without executing"
    echo "  --verbose               Enable verbose output"
    echo "  --help, -h              Show this help message"
    echo "  --version, -v           Show version information"
    echo ""
    echo "SPM Release Workflow:"
    echo "  1. Ensure all XCFrameworks are built (binary adapters)"
    echo "  2. Sync ThirdParty XCFrameworks from Pods directory"
    echo "  3. Process binary targets and generate Package.swift with remote URLs"
    echo "  4. Create unified SPM git tag (all products share same version)"
    echo "  5. Push tag to remote"
}

# Validate inputs
validate_inputs() {
    if [[ -z "$VERSION" ]]; then
        log::error "SPM" "Version is required"
        show_help
        exit 1
    fi
    
    # Set release branch if not provided
    if [[ -z "$RELEASE_BRANCH" ]]; then
        RELEASE_BRANCH="release/$VERSION"
    fi
    
    log::info "SPM" "SPM release configuration:"
    log::info "SPM" "  Version: $VERSION"
    log::info "SPM" "  Release Branch: $RELEASE_BRANCH"
    log::info "SPM" "  Dry Run: $DRY_RUN"
    if [[ -n "${SPM_PACKAGES:-}" ]]; then
        log::info "SPM" "  SPM Packages: $SPM_PACKAGES"
    fi
}

# Check if we're on the correct release branch
check_release_branch() {
    log::step "SPM" "Checking release branch"
    
    # Skip branch check in dry-run mode
    if [[ "$DRY_RUN" == "true" ]]; then
        log::info "SPM" "DRY RUN: Skipping release branch check"
        return 0
    fi
    
    local current_branch=$(git branch --show-current)
    # Allow feature/spm_impl branch for development/testing
    if [[ "$current_branch" != "$RELEASE_BRANCH" ]] && [[ "$current_branch" != "feature/spm_impl" ]]; then
        log::error "SPM" "Not on release branch '$RELEASE_BRANCH' or feature/spm_impl. Current branch: '$current_branch'"
        log::info "SPM" "Please checkout the release branch first:"
        log::info "SPM" "  git checkout $RELEASE_BRANCH"
        log::info "SPM" "  or use feature/spm_impl for development/testing"
        exit 1
    fi
    
    if [[ "$current_branch" == "feature/spm_impl" ]]; then
        log::warn "SPM" "Running on feature/spm_impl branch (development mode)"
    fi
    
    log::success "SPM" "On correct release branch: $RELEASE_BRANCH"
}

# ============================================================================
# SPM CDN and URL Verification Functions (moved to top for early availability)
# ============================================================================
# These functions are used throughout the SPM release process and must be
# defined before they are called. Moved from script end to here to fix
# "command not found" errors.
# ============================================================================

# Wait for GitHub CDN to propagate Release assets globally
# Uses shared CDN wait module with SPM-specific wait time
wait_for_spm_cdn_propagation() {
    # Map SPM-specific env var to shared module's expected var
    export MSP_CDN_WAIT_TIME="${MSP_SPM_CDN_WAIT_TIME:-120}"

    if command -v cdn_wait_for_propagation &>/dev/null; then
        cdn_wait_for_propagation "SPM"
    else
        # Fallback: simple wait if shared module not available
        local wait_time="${MSP_CDN_WAIT_TIME:-120}"
        log::info "SPM" "Waiting ${wait_time}s for CDN propagation..."
        sleep "$wait_time"
        log::success "SPM" "✓ CDN propagation wait complete"
    fi
}

# ============================================================================
# CDN Verification Functions (Thin Wrappers)
# ============================================================================
# These functions delegate to lib/cdn_verification.sh for actual implementation.
# Kept for backward compatibility with existing callers.

# Verify CDN availability for all SPM zips
# Delegates to: spm_verify_cdn_availability (lib/cdn_verification.sh)
verify_spm_cdn_availability() {
    if command -v spm_verify_cdn_availability &>/dev/null; then
        spm_verify_cdn_availability "$@"
    else
        log::error "SPM" "spm_verify_cdn_availability not available. Source lib/cdn_verification.sh"
        return 1
    fi
}

# Probe zip URL availability with retries
# Delegates to: spm_probe_zip_url (lib/xcframework_zip.sh)
probe_spm_zip_url() {
    if command -v spm_probe_zip_url &>/dev/null; then
        spm_probe_zip_url "$@"
    else
        log::error "SPM" "spm_probe_zip_url not available. Source lib/xcframework_zip.sh"
        return 1
    fi
}

# Verify checksums by downloading from CDN and comparing
# Delegates to: spm_verify_checksum_from_cdn (lib/cdn_verification.sh)
verify_spm_checksum_from_cdn() {
    if command -v spm_verify_checksum_from_cdn &>/dev/null; then
        spm_verify_checksum_from_cdn "$@"
    else
        log::error "SPM" "spm_verify_checksum_from_cdn not available. Source lib/cdn_verification.sh"
        return 1
    fi
}

# ============================================================================
# Package.swift Management Functions
# ============================================================================

# Update Package.swift version
update_package_swift_version() {
    local package_file="$1"
    local version="$2"
    
    if [[ ! -f "$package_file" ]]; then
        log::warn "SPM" "Package.swift not found: $package_file"
        return 0
    fi
    
    log::step "SPM" "Updating version in $package_file to $version"

    # Update version in Package.swift (in-place, no backup needed)
    sed -i '' "s|let version = \".*\"|let version = \"${version}\"|g" "$package_file"

    log::success "SPM" "Updated version in $package_file"
}

# Update Package.swift dependency
update_package_swift_dependency() {
    local package_file="$1"
    local dependency_name="$2"
    local version="$3"
    
    if [[ ! -f "$package_file" ]]; then
        log::warn "SPM" "Package.swift not found: $package_file"
        return 0
    fi
    
    log::step "SPM" "Updating $dependency_name dependency in $package_file to $version"
    
    # Update dependency version
    sed -i '' "s|\.package(url: \"https://github\.com/ParticleMedia/msp-ios-sdk-public\.git\", from: \".*\")|.package(url: \"https://github.com/ParticleMedia/msp-ios-sdk-public.git\", from: \"${version}\")|g" "$package_file"
    
    log::success "SPM" "Updated $dependency_name dependency in $package_file"
}

# Create git tag for SPM package
create_spm_tag() {
    local package_name="$1"
    local version="$2"
    local tag_name="${package_name}-${version}"
    
    log::step "SPM" "Creating git tag for SPM package: $tag_name"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log::info "SPM" "DRY RUN: Would create tag $tag_name"
        return 0
    fi
    
    # Check if tag already exists
    if git tag -l | grep -q "^${tag_name}$"; then
        log::warn "SPM" "Tag $tag_name already exists"
        return 0
    fi
    
    # Create tag
    if git tag "$tag_name"; then
        log::success "SPM" "Created tag: $tag_name"
        
        # Track tag creation in state
        if command -v msp_state_mark_git_flag &>/dev/null; then
            msp_state_mark_git_flag "tag_created" true
            if command -v msp_state_set_tag_name &>/dev/null; then
                # Track the last tag created (SPM may create multiple tags)
                msp_state_set_tag_name "$tag_name"
            fi
        fi
    else
        log::error "SPM" "Failed to create tag: $tag_name"
        return 1
    fi
}

# ============================================================================
# Resume Helper
# ============================================================================
_msp_spm_should_skip_step() {
    local step="$1"
    
    if [[ "${MSP_RESUME_MODE:-0}" != "1" ]]; then
        return 1
    fi
    
    local status
    status="$(msp_state_get_step_status "$step" 2>/dev/null || echo "unknown")"
    
    if [[ "$status" == "success" || "$status" == "skipped" ]]; then
        return 0
    fi
    
    return 1
}

# SPM Local Build Validation
spm_local_validation() {
    # Verification only runs in full mode
    if [[ "${MSP_RELEASE_MODE:-simple}" != "full" ]]; then
        log::info "SPM" "Skipping SPM local build validation (simple mode)"
        msp_state_mark_step_skipped "spm_local_validation" "SPM local validation skipped (simple mode)"
        return 0
    fi
    
    # Honor orchestrator/CLI skip flag
    if [[ "${MSP_SKIP_SPM_LOCAL_BUILD:-false}" == "true" ]] || [[ "${MSP_SKIP_SPM_LOCAL_BUILD:-0}" == "1" ]]; then
        log::info "SPM" "Skipping SPM local build validation (MSP_SKIP_SPM_LOCAL_BUILD=true)"
        msp_state_mark_step_skipped "spm_local_validation" "SPM local validation skipped due to MSP_SKIP_SPM_LOCAL_BUILD"
        return 0
    fi
    
    # Check if we should skip this step in resume mode
    if _msp_spm_should_skip_step "spm_local_validation"; then
        log::info "SPM" "Resuming: skipping spm_local_validation (status already success/skipped)"
        return 0
    fi
    
    # Check if local validation should be skipped via environment variable
    if [[ "${SKIP_SPM_LOCAL_VALIDATION:-false}" == "true" ]] || [[ "${SKIP_SPM_LOCAL_VALIDATION:-false}" == "1" ]]; then
        log::info "SPM" "Skipping SPM local build validation (SKIP_SPM_LOCAL_VALIDATION=true)"
        msp_state_mark_step_skipped "spm_local_validation" "SPM local validation skipped due to SKIP_SPM_LOCAL_VALIDATION=true"
        return 0
    fi
    
    msp_state_mark_step_running "spm_local_validation"
    
    log_section "SPM Local Build Validation"
    
    # DRY_RUN shortcut
    if [[ "$DRY_RUN" == "true" ]] || [[ "$DRY_RUN" == "1" ]]; then
        log::info "SPM" "[DRY_RUN] Skipping SPM local build validation"
        msp_state_mark_step_skipped "spm_local_validation" "SPM local validation skipped due to DRY_RUN"
        return 0
    fi
    
    # Get SPM product name with fallback
    local spm_product_name="${SPM_REMOTE_PRODUCT_NAME:-MSPAds}"
    local spm_import_name="$spm_product_name"
    if [[ "$spm_product_name" == "MSPAds" ]]; then
        # MSPAds is a composite product; import one of its targets instead.
        spm_import_name="MSPCoreLinker"
    fi
    
    # Create temp directory
    log::step "SPM" "Creating temporary test package"
    SPM_LOCAL_TMPDIR="$(mktemp -d -t msp_spm_local_XXXXXX)"
    if [[ ! -d "$SPM_LOCAL_TMPDIR" ]]; then
        log::error "SPM" "Failed to create temporary directory"
        return 1
    fi
    
    # Cleanup function
    local cleanup_on_exit=true
    if [[ "${DEBUG:-false}" == "true" ]] || [[ "${VERBOSE:-false}" == "true" ]]; then
        cleanup_on_exit=false
        log::info "SPM" "DEBUG/VERBOSE mode: keeping test directory at $SPM_LOCAL_TMPDIR"
    fi
    
    cleanup_temp_dir() {
        local cleanup_flag="${cleanup_on_exit:-true}"
        local tmpdir="${1:-}"
        if [[ "$cleanup_flag" == "true" && -n "$tmpdir" ]]; then
            log::step "SPM" "Cleaning up temporary directory"
            rm -rf "$tmpdir" 2>/dev/null || true
        fi
    }
    
    # Save and compose with existing EXIT trap so error logging is preserved
    local _prev_exit_trap
    _prev_exit_trap=$(trap -p EXIT | sed "s/^trap -- '//;s/' EXIT$//" || echo "")
    # shellcheck disable=SC2064
    trap "cleanup_temp_dir \"$SPM_LOCAL_TMPDIR\"; ${_prev_exit_trap:-:}" EXIT
    
    cd "$SPM_LOCAL_TMPDIR" || {
        log::error "SPM" "Failed to change to temporary directory"
        return 1
    }
    
    # Keep all caches/artifacts inside the temp directory to avoid permission issues
    local build_path="$SPM_LOCAL_TMPDIR/.build"
    local module_cache_path="$SPM_LOCAL_TMPDIR/.clang-module-cache"
    local cache_root="$SPM_LOCAL_TMPDIR/.cache"
    mkdir -p "$build_path" "$module_cache_path" "$cache_root" 2>/dev/null || true
    export CLANG_MODULE_CACHE_PATH="$module_cache_path"
    export XDG_CACHE_HOME="$cache_root"
    
    # Initialize minimal SwiftPM library package
    log::step "SPM" "Initializing SwiftPM test package"
    if ! swift package init --type library --name MSP_SPMLocalTest 2>&1; then
        log::error "SPM" "Failed to initialize Swift package"
        return 1
    fi
    
    log::success "SPM" "Swift package initialized"
    
    # Generate core-only Package.swift for local validation to avoid missing third-party binaries
    # Note: We invoke the Ruby script directly instead of sourcing target-switching/common.sh,
    # because common.sh's dependency chain (colors.sh, lib/common.sh) uses git rev-parse
    # which fails in non-git temp directories.
    local ruby_script="$ROOT_DIR/Scripts/target-switching/generate_core_only_package_swift.rb"
    local pkg_template="$ROOT_DIR/Package.swift.template"
    local pkg_output="$ROOT_DIR/Package.swift"

    if [[ -f "$ruby_script" ]] && [[ -f "$pkg_template" ]] && command -v ruby >/dev/null 2>&1; then
        log::step "SPM" "Generating core-only Package.swift for SPM local validation"
        if ! ruby "$ruby_script" "$pkg_template" "$pkg_output"; then
            log::error "SPM" "Failed to generate core-only Package.swift"
            return 1
        fi
        log::success "SPM" "Core-only Package.swift generated"
    else
        log::warn "SPM" "Ruby script or template not available; using existing Package.swift"
    fi

    # Get absolute path to repo Package.swift
    local repo_package_swift="$ROOT_DIR/Package.swift"
    if [[ ! -f "$repo_package_swift" ]]; then
        log::error "SPM" "[SPM][ERROR] Package.swift not found at: $repo_package_swift"
        log::error "SPM" "[SPM][ERROR] SPM local validation requires Package.swift to be generated first"
        # Phase B Step 5: In dry-run mode, allow soft-fail
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            return 1
        else
            log::warn "SPM" "[SPM][WARN] Dry-run mode: skipping local validation"
            return 0
        fi
    else
        log::info "SPM" "[SPM][INFO] Package.swift found at: $repo_package_swift"
    fi
    
    local repo_abs_path
    repo_abs_path="$(cd "$ROOT_DIR" && pwd)"
    
    # Create test Package.swift that depends on local repo Package.swift
    log::step "SPM" "Creating test Package.swift with local dependency"
    local test_package_swift="$SPM_LOCAL_TMPDIR/Package.swift"
    
    cat > "$test_package_swift" << EOF
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MSP_SPMLocalTest",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "MSP_SPMLocalTest", targets: ["MSP_SPMLocalTest"])
    ],
    dependencies: [
        .package(path: "$repo_abs_path")
    ],
    targets: [
        .target(
            name: "MSP_SPMLocalTest",
            dependencies: [
                .product(name: "$spm_product_name", package: "msp-ios-sdk")
            ]
        )
    ]
)
EOF
    
    log::info "SPM" "Test Package.swift created with dependency on: $repo_abs_path"
    
    # Update library source to import the product
    log::step "SPM" "Updating library source to import SPM product"
    local source_swift="$SPM_LOCAL_TMPDIR/Sources/MSP_SPMLocalTest/MSP_SPMLocalTest.swift"
    if [[ -f "$source_swift" ]]; then
        cat > "$source_swift" << EOF
import Foundation
import ${spm_import_name}

// No runtime code needed; import validates SPM linkage.
EOF
        log::info "SPM" "Library source updated with import: $spm_import_name"
    fi
    
    # Run swift package resolve
    log::step "SPM" "Resolving Swift package dependencies"
    local resolve_output
    local resolve_exit_code
    
    if [[ "$VERBOSE" == "true" ]]; then
        if swift package --disable-sandbox resolve 2>&1; then
            resolve_exit_code=0
        else
            resolve_exit_code=$?
        fi
    else
        resolve_output=$(swift package --disable-sandbox resolve 2>&1)
        resolve_exit_code=$?
    fi
    
    if [[ $resolve_exit_code -ne 0 ]]; then
        log::error "SPM" "swift package resolve failed (exit code: $resolve_exit_code)"
        if [[ "$VERBOSE" != "true" && -n "$resolve_output" ]]; then
            log::info "SPM" "Resolve output (last 20 lines):"
            echo "$resolve_output" | tail -20 | sed 's/^/  /'
        fi
        return 1
    fi
    
    log::success "SPM" "Swift package resolved successfully"
    
    # Prepare SwiftPM build inputs (Swift 6 removed generate-xcodeproj)
    log::step "SPM" "Preparing SwiftPM build environment"
    local ios_sdk_path
    ios_sdk_path="$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || true)"
    if [[ -z "$ios_sdk_path" || ! -d "$ios_sdk_path" ]]; then
        log::error "SPM" "Failed to locate iOS SDK path via xcrun"
        return 1
    fi
    
    local ios_triple="${MSP_SPM_IOS_TRIPLE:-arm64-apple-ios15.0}"
    mkdir -p "$build_path" "$module_cache_path" "$cache_root" 2>/dev/null || true
    
    # Build for iOS to match supported platform
    log::step "SPM" "Building Swift package (iOS release configuration)"
    log::info "SPM" "Using SDK: $ios_sdk_path"
    log::info "SPM" "Using triple: $ios_triple"
    
    local build_output=""
    local build_exit_code=0
    local build_cmd=(
        swift build
        --disable-sandbox
        --configuration release
        --triple "$ios_triple"
        --sdk "$ios_sdk_path"
        --build-path "$build_path"
        --product MSP_SPMLocalTest
    )
    
    if [[ "$VERBOSE" == "true" ]]; then
        if "${build_cmd[@]}"; then
            build_exit_code=0
        else
            build_exit_code=$?
        fi
    else
        build_output=$("${build_cmd[@]}" 2>&1)
        build_exit_code=$?
    fi
    
    if [[ $build_exit_code -ne 0 ]]; then
        log::error "SPM" "swift build failed (exit code: $build_exit_code)"
        if [[ "$VERBOSE" != "true" && -n "$build_output" ]]; then
            log::info "SPM" "Build output (last 20 lines):"
            echo "$build_output" | tail -20 | sed 's/^/  /'
        fi
        log::error "SPM" "SPM Local Build Validation Failed"
        msp_state_mark_step_failed "spm_local_validation" "SPM local validation failed" "1"
        return 1
    fi
    
    log::success "SPM" "Swift package built successfully (SwiftPM iOS build)"
    
    # Produce summary
    ui_divider
    log::success "SPM" "SPM Local Build Validation Summary"
    ui_kv "Temp Directory" "$SPM_LOCAL_TMPDIR"
    ui_kv "SPM Product" "$spm_product_name"
    ui_kv "Status" "Success"
    ui_divider
    
    # Disable cleanup if we got here successfully (for inspection)
    if [[ "${KEEP_VERIFY_ARTIFACTS:-false}" == "true" ]]; then
        cleanup_on_exit=false
        log::info "SPM" "Artifacts kept at: $SPM_LOCAL_TMPDIR"
    fi
    
    msp_state_mark_step_success "spm_local_validation"
    return 0
}

# Push tags to remote
push_spm_tags() {
    log::step "SPM" "Pushing SPM tags to remote"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log::info "SPM" "DRY RUN: Would push tags to remote"
        return 0
    fi
    
    # Push all tags
    spm_publish_tags "$VERSION"
    
    log::success "SPM" "Pushed SPM tags to remote"
}

# ============================================================================
# SPM Cloud Distribution Functions (Thin Wrappers)
# ============================================================================
# These functions delegate to lib/xcframework_zip.sh for actual implementation.
# Kept for backward compatibility with existing callers.

# Create deterministic zip file from XCFramework
# Delegates to: spm_create_deterministic_zip (lib/xcframework_zip.sh)
create_deterministic_zip() {
    if command -v spm_create_deterministic_zip &>/dev/null; then
        spm_create_deterministic_zip "$@"
    else
        log::error "SPM" "spm_create_deterministic_zip not available. Source lib/xcframework_zip.sh"
        return 1
    fi
}

# Compute checksum for zip file using swift package compute-checksum
# Delegates to: spm_compute_zip_checksum (lib/xcframework_zip.sh)
compute_zip_checksum() {
    if command -v spm_compute_zip_checksum &>/dev/null; then
        spm_compute_zip_checksum "$@"
    else
        log::error "SPM" "spm_compute_zip_checksum not available. Source lib/xcframework_zip.sh"
        return 1
    fi
}

# Upload zip file to GitHub Release
# Delegates to: spm_upload_to_github_release (lib/xcframework_zip.sh)
upload_xcframework_to_github_release() {
    if command -v spm_upload_to_github_release &>/dev/null; then
        spm_upload_to_github_release "$@"
    else
        log::error "SPM" "spm_upload_to_github_release not available. Source lib/xcframework_zip.sh"
        return 1
    fi
}

# Process all XCFrameworks for cloud distribution
process_binary_targets_for_cloud_distribution() {
    local version="$1"
    
    log_section "Processing Binary Targets for Cloud Distribution"
    
    # Ensure Package.swift exists before updating it
    # Source common.sh to access ensure_package_swift_enabled function
    if [[ -f "$ROOT_DIR/Scripts/target-switching/common.sh" ]]; then
        source "$ROOT_DIR/Scripts/target-switching/common.sh" 2>/dev/null || true
    fi
    
    local repo_package_swift="$ROOT_DIR/Package.swift"
    if [[ ! -f "$repo_package_swift" ]]; then
        log::step "SPM" "Package.swift not found, generating core-only Package.swift for cloud distribution"
        if command -v ensure_package_swift_enabled &>/dev/null; then
            if ! ensure_package_swift_enabled "spm-release"; then
                log::error "SPM" "[SPM][ERROR] Failed to generate core-only Package.swift"
                return 1
            fi
            log::success "SPM" "[SPM][INFO] Package.swift generated (core-only mode)"
        else
            log::error "SPM" "[SPM][ERROR] ensure_package_swift_enabled function not available"
            log::error "SPM" "[SPM][ERROR] Cannot generate Package.swift automatically"
            return 1
        fi
    else
        log::info "SPM" "[SPM][INFO] Package.swift found at: $repo_package_swift"
    fi
    
    # Find XCFrameworks for core modules (NovaCore, MSPNovaAdapter) in Build/ReleaseArtifacts/XCFrameworks/
    # For real release, we only process core modules, not all third-party SDKs
    local xcframeworks=()
    
    log::step "SPM" "Scanning for core module XCFrameworks"
    
    # Scan Build/ReleaseArtifacts/XCFrameworks/ for core modules and binary adapters
    if [[ -d "$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks" ]]; then
        # Process core modules: Only include actual binary targets
        # MSPNovaAdapter is a source-based target (.target), not a binary target (.binaryTarget)
        # It doesn't need binary distribution (zip/CDN)
        local core_modules=("NovaCore")
        for module in "${core_modules[@]}"; do
            local xcframework_path="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks/${module}.xcframework"
            if [[ -d "$xcframework_path" ]]; then
                xcframeworks+=("$xcframework_path")
                log::info "SPM" "Found core module: $module"
            else
                log::warn "SPM" "Core module XCFramework not found: $xcframework_path"
            fi
        done
        
        # Process binary adapter modules (MSPAmazonAdapter, MSPMolocoAdapter, MSPLiftoffAdapter)
        # These adapters use binary XCFrameworks for distribution
        local binary_adapters=("MSPAmazonAdapter" "MSPMolocoAdapter" "MSPLiftoffAdapter")
        for adapter in "${binary_adapters[@]}"; do
            local xcframework_path="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks/${adapter}.xcframework"
            if [[ -d "$xcframework_path" ]]; then
                xcframeworks+=("$xcframework_path")
                log::info "SPM" "Found binary adapter: $adapter"
            else
                log::warn "SPM" "Binary adapter XCFramework not found: $xcframework_path"
                log::warn "SPM" "  Run: ./Scripts/xcframeworks/build-adapters.sh to build it"
            fi
        done
    fi
    
    # Optionally include third-party XCFrameworks if needed (for full distribution)
    # Uncomment below to include all third-party SDKs
    # if [[ -d "$ROOT_DIR/ThirdParty" ]]; then
    #     while IFS= read -r -d '' xcframework; do
    #         xcframeworks+=("$xcframework")
    #     done < <(find "$ROOT_DIR/ThirdParty" -name "*.xcframework" -type d -print0 2>/dev/null)
    # fi
    
    if [[ ${#xcframeworks[@]} -eq 0 ]]; then
        log::warn "SPM" "No XCFrameworks found in ThirdParty/ or Build/ReleaseArtifacts/XCFrameworks/"
        return 0
    fi
    
    log::info "SPM" "Found ${#xcframeworks[@]} XCFramework(s) to process"
    
    # Create directory for zip files
    local zip_dir="$ROOT_DIR/Build/SPMZips"
    mkdir -p "$zip_dir"
    
    # Process each XCFramework
    local processed_count=0
    local failed_count=0
    local framework_checksums=()
    
    for xcframework_path in "${xcframeworks[@]}"; do
        local framework_name
        framework_name="$(basename "$xcframework_path" .xcframework)"
        local zip_name="${framework_name}.xcframework.zip"
        local zip_path="$zip_dir/$zip_name"
        
        log::step "SPM" "Processing $framework_name"
        
        # Create deterministic zip
        if ! create_deterministic_zip "$xcframework_path" "$zip_path" "$framework_name"; then
            log::error "SPM" "Failed to create zip for $framework_name"
            ((failed_count++)) || true
            continue
        fi
        
        # Compute checksum
        local checksum
        checksum=$(compute_zip_checksum "$zip_path")
        if [[ -z "$checksum" ]]; then
            log::error "SPM" "Failed to compute checksum for $framework_name"
            rm -f "$zip_path"
            ((failed_count++)) || true
            
            return 1
        fi
        
        # Store checksum for Package.swift update
        framework_checksums+=("$framework_name|$checksum|$zip_name")
        
        # Upload to GitHub Release (only in real release, not dry run)
        if [[ "$DRY_RUN" != "true" ]]; then
            if ! upload_xcframework_to_github_release "$zip_path" "$framework_name" "$version"; then
                log::error "SPM" "Failed to upload $framework_name to GitHub Release"
                ((failed_count++)) || true
                continue
            fi
        else
            log::info "SPM" "DRY RUN: Would upload $framework_name to GitHub Release"
        fi
        
        ((processed_count++)) || true
        log::success "SPM" "Processed $framework_name (checksum: ${checksum:0:16}...)"
    done
    
    log::info "SPM" "Processed $processed_count XCFramework(s), $failed_count failed"
    
    # Update Package.swift with URL and checksum
    if [[ ${#framework_checksums[@]} -gt 0 ]]; then
        log::step "SPM" "Updating Package.swift with cloud distribution URLs and checksums"
        if update_package_swift_binary_targets "$version" "${framework_checksums[@]}"; then
            log::success "SPM" "Updated Package.swift with cloud distribution information"
        else
            log::error "SPM" "Failed to update Package.swift"
            return 1
        fi
        
        # ========================================================================
        # Phase 1: CDN Propagation Wait and Verification
        # ========================================================================
        if [[ "$DRY_RUN" != "true" ]]; then
            # ════════════════════════════════════════════════════════════════════════════
            # Optimization: Skip CDN wait if assets already verified accessible
            # ════════════════════════════════════════════════════════════════════════════
            # CocoaPods release already uploaded zips and waited for CDN propagation.
            # Do a quick check first - if assets are already accessible, skip the wait.
            # ════════════════════════════════════════════════════════════════════════════

            local cdn_already_ready=true
            log::info "SPM" "Quick CDN accessibility check (skipping full wait if already ready)..."

            for framework_info in "${framework_checksums[@]}"; do
                IFS='|' read -r framework_name checksum zip_name <<< "$framework_info"
                local zip_url="https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/${zip_name}"
                
                # Quick HEAD request to check if file is accessible
                local http_code
                http_code=$(curl -sI -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$zip_url" 2>/dev/null || echo "000")
                if [[ "$http_code" == "000" ]]; then
                    log::debug "SPM" "  $framework_name: curl failed (network issue?), will wait for CDN"
                    cdn_already_ready=false
                    break
                elif ! echo "$http_code" | grep -q "^200\|^302"; then
                    cdn_already_ready=false
                    log::info "SPM" "  $framework_name: HTTP $http_code, will wait for CDN"
                    break
                else
                    log::info "SPM" "  $framework_name: Already accessible ✓"
                fi
            done

            if [[ "$cdn_already_ready" == "true" ]]; then
                log::success "SPM" "✓ All CDN assets already accessible (skipping propagation wait)"
                log::info "SPM" "  CocoaPods release likely already completed CDN propagation"
            else
                # Original CDN wait logic
                log::info "SPM" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                log::info "SPM" "Step 1: Wait for CDN propagation"
                log::info "SPM" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                wait_for_spm_cdn_propagation
            fi

            # Step 2: Verify CDN availability
            log::info "SPM" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log::info "SPM" "Step 2: Verify CDN availability"
            log::info "SPM" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            if ! verify_spm_cdn_availability "$version" "${framework_checksums[@]}"; then
                log::error "SPM" "CDN verification failed"
                echo ""

                if [[ "${MSP_SKIP_SPM_CDN_VERIFICATION:-false}" == "true" ]]; then
                    log::warn "SPM" "⚠️  Continuing despite CDN verification failure (MSP_SKIP_SPM_CDN_VERIFICATION=true)"
                    log::warn "SPM" "⚠️  Users may experience 404 errors when resolving Package.swift"
                else
                    log::error "SPM" "❌ Aborting SPM release due to CDN verification failure"
                    log::error "SPM" "   Set MSP_SKIP_SPM_CDN_VERIFICATION=true to continue anyway (NOT recommended)"
                    return 1
                fi
            fi
            
            # Step 3: Verify checksums from CDN (Phase 2)
            log::info "SPM" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log::info "SPM" "Step 3: Verify checksums from CDN"
            log::info "SPM" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            if ! verify_spm_checksum_from_cdn "$version" "${framework_checksums[@]}"; then
                log::error "SPM" "Checksum verification failed"
                echo ""

                if [[ "${MSP_SKIP_SPM_CHECKSUM_VERIFICATION:-false}" == "true" ]]; then
                    log::warn "SPM" "⚠️  Continuing despite checksum verification failure (MSP_SKIP_SPM_CHECKSUM_VERIFICATION=true)"
                    log::warn "SPM" "⚠️  Users may experience checksum mismatch errors"
                else
                    log::error "SPM" "❌ Aborting SPM release due to checksum verification failure"
                    log::error "SPM" "   Set MSP_SKIP_SPM_CHECKSUM_VERIFICATION=true to continue anyway (NOT recommended)"
                    return 1
                fi
            fi
        elif [[ "$DRY_RUN" == "true" ]]; then
            log::info "SPM" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log::info "SPM" "DRY RUN: Skipping CDN wait and verification"
            log::info "SPM" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        fi
    fi
    
    if [[ $failed_count -gt 0 ]]; then
        log::error "SPM" "Some XCFrameworks failed to process"
        return 1
    fi
    
    return 0
}

# Update Package.swift binary targets from path: to url: + checksum:
update_package_swift_binary_targets() {
    local version="$1"
    shift
    local framework_checksums=("$@")
    
    local package_swift="$ROOT_DIR/Package.swift"
    if [[ ! -f "$package_swift" ]]; then
        log::error "SPM" "Package.swift not found: $package_swift"
        return 1
    fi
    
    log::step "SPM" "Updating Package.swift binary targets"

    # Read Package.swift content (reference copy for diagnostics)
    local package_content
    package_content=$(cat "$package_swift")
    
    # Process each framework using the standalone Ruby script
    for framework_info in "${framework_checksums[@]}"; do
        IFS='|' read -r framework_name checksum zip_name <<< "$framework_info"
        
        # Skip source-based targets (no zip file)
        if [[ -z "$zip_name" ]] || [[ ! "$zip_name" =~ \.zip$ ]]; then
            log::debug "SPM" "Skipping $framework_name (source-based target, no zip file)"
            continue
        fi
        
        local url="https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/${zip_name}"
        
        log::info "SPM" "Updating $framework_name: path → url + checksum"
        
        # Use standalone Ruby script for robust replacement
        local ruby_script="$ROOT_DIR/Scripts/spm/update_manifest.rb"
        if [[ ! -f "$ruby_script" ]]; then
            log::error "SPM" "Ruby script not found: $ruby_script"
            mv "$backup_file" "$package_swift"
            return 1
        fi
        
        if ! ruby "$ruby_script" "$package_swift" "$framework_name" "$url" "$checksum"; then
            log::error "SPM" "Failed to update Package.swift for $framework_name"
            # Restore backup
            mv "$backup_file" "$package_swift"
            return 1
        fi
    done
    
    # ════════════════════════════════════════════════════════════════════════════
    # FIX: Don't overwrite Package.swift - Ruby script already updated it in-place
    # ════════════════════════════════════════════════════════════════════════════
    # Ruby script modifies Package.swift directly, so we don't need to write it again
    # The original echo "$package_content" > "$package_swift" was overwriting Ruby's changes!
    # ════════════════════════════════════════════════════════════════════════════
    # REMOVED: echo "$package_content" > "$package_swift"
    
    log::success "SPM" "Updated Package.swift with cloud distribution URLs and checksums"
    
    # ========================================================================
    # Phase 1: Commit Package.swift to Git
    # ========================================================================
    if [[ "$DRY_RUN" != "true" ]] && [[ "${DRY_RUN:-false}" != "1" ]]; then
        log::step "SPM" "Committing Package.swift to git"

        # Check if Package.swift has changes
        if git diff --quiet "$package_swift"; then
            log::info "SPM" "Package.swift has no changes, skipping commit"
        else
            # Add Package.swift to staging area
            if ! git add "$package_swift"; then
                log::error "SPM" "Failed to git add Package.swift"
                return 1
            fi

            # Prepare commit message with framework list
            local framework_list=""
            for framework_info in "${framework_checksums[@]}"; do
                IFS='|' read -r framework_name checksum zip_name <<< "$framework_info"
                if [[ -n "$framework_list" ]]; then
                    framework_list+=", "
                fi
                framework_list+="$framework_name"
            done

            # Commit with descriptive message
            local commit_message="chore(spm): update Package.swift for release $version

Convert binaryTarget definitions from path: to url: + checksum:

Frameworks: $framework_list

This commit updates Package.swift to use remote GitHub Release URLs
for binary distribution, enabling SPM users to resolve dependencies
without requiring local XCFrameworks.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

            if ! git commit -m "$commit_message"; then
                log::error "SPM" "Failed to git commit Package.swift"
                return 1
            fi

            # Show commit info
            local commit_hash=$(git rev-parse --short HEAD)
            log::success "SPM" "✓ Committed Package.swift to git"
            log::info "SPM" "  Commit: $commit_hash"
            log::info "SPM" "  Message: chore(spm): update Package.swift for release $version"
        fi
    else
        log::info "SPM" "DRY RUN: Skipping git commit for Package.swift"
    fi
    
    # Show preview of changes
    if [[ "$DRY_RUN" == "true" ]] || [[ "${DRY_RUN:-false}" == "1" ]] || [[ "${VERBOSE:-false}" == "true" ]]; then
        log::info "SPM" "Package.swift changes preview:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        for framework_info in "${framework_checksums[@]}"; do
            IFS='|' read -r framework_name checksum zip_name <<< "$framework_info"
            local url="https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/${zip_name}"
            echo "  $framework_name:"
            echo "    Before: path: \"...\""
            echo "    After:  url: \"$url\""
            echo "            checksum: \"${checksum:0:16}...\""
        done
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
    
    return 0
}

# Release a single SPM package
release_spm_package() {
    local package_name="$1"
    local version="$2"
    
    log_section "Releasing $package_name SPM package"
    
    # Find Package.swift file for this package
    # SPM packages may be in different locations
    local package_file=""
    if [[ -f "$package_name/Package.swift" ]]; then
        package_file="$package_name/Package.swift"
    elif [[ -f "Sources/$package_name/Package.swift" ]]; then
        package_file="Sources/$package_name/Package.swift"
    elif [[ -f "$ROOT_DIR/$package_name/Package.swift" ]]; then
        package_file="$ROOT_DIR/$package_name/Package.swift"
    else
        log::warn "SPM" "Package.swift not found for $package_name, skipping version update"
    fi
    
    # Update Package.swift version if found
    if [[ -n "$package_file" ]]; then
        update_package_swift_version "$package_file" "$version"
    fi
    
    # Update dependencies if this package depends on other SPM packages
    # For example, MSPNovaAdapter depends on NovaCore
    if [[ "$package_name" == "NovaAdapter" ]]; then
        if [[ -n "$package_file" ]]; then
            update_package_swift_dependency "$package_file" "NovaCore" "$version"
        fi
    fi
    
    log::success "SPM" "$package_name SPM package prepared"
}


# Main function
main() {
    # Initialize state for standalone SPM flow
    msp_state_init "run"
    
    # Check if SPM publish should be skipped
    if [[ "${SPM_ENABLED:-true}" == "false" ]] || [[ "${SKIP_SPM:-false}" == "true" ]]; then
        msp_state_mark_step_skipped "spm_publish" "SPM publish skipped due to SPM_ENABLED=false or SKIP_SPM=true"
        msp_state_mark_step_skipped "spm_local_validation" "SPM local validation skipped due to SPM_ENABLED=false or SKIP_SPM=true"
        log::info "SPM" "SPM publish skipped"
        return 0
    fi
    
    # Backward compatibility: parse remaining CLI arguments if any
    # (Only used if script is called directly, not via msp-release.sh)
    if [[ $# -gt 0 ]]; then
        parse_arguments "$@"
    fi
    
    # Validate inputs
    validate_inputs
    
    # Step 0: Ensure all required XCFrameworks are built before SPM release
    # This prevents "XCFramework not found" errors during packaging
    log_section "Pre-release: Ensuring XCFrameworks are built"
    if [[ "$DRY_RUN" != "true" ]] && [[ "${DRY_RUN:-false}" != "1" ]]; then
        if [[ -f "$ROOT_DIR/Scripts/release/utils/ensure_xcframeworks.sh" ]]; then
            log::step "SPM" "Ensuring binary adapter XCFrameworks are built..."
            if ! "$ROOT_DIR/Scripts/release/utils/ensure_xcframeworks.sh" ensure; then
                log::error "SPM" "Failed to ensure XCFrameworks are built"
                log::error "SPM" "Please run: ./Scripts/xcframeworks/build-adapters.sh"
                msp_state_mark_step_failed "spm_publish" "XCFramework build failed" "1"
                return 1
            fi
            log::success "SPM" "All binary adapter XCFrameworks are ready"
        else
            log::warn "SPM" "ensure_xcframeworks.sh not found, skipping XCFramework check"
            log::warn "SPM" "Make sure XCFrameworks are built before SPM release"
        fi
    else
        log::info "SPM" "DRY RUN: Skipping XCFramework build check"
    fi
    
    # Ensure we're in the project root
    ensure_project_root
    
    # Check release branch (skip in DRY_RUN mode)
    if [[ "$DRY_RUN" != "true" ]] && [[ "${DRY_RUN:-false}" != "1" ]]; then
        check_release_branch
    else
        log::info "SPM" "DRY RUN: Skipping release branch check"
    fi
    
    # Record start time for duration calculation
    local start_time=$(date +%s)
    
    # Check if we should skip this step in resume mode
    if _msp_spm_should_skip_step "spm_publish"; then
        log::info "SPM" "Resuming: skipping spm_publish (status already success/skipped)"
        return 0
    fi
    
    # Mark spm_publish step as running
    msp_state_mark_step_running "spm_publish"
    
    print_section "Starting SPM Release Process for Version: $VERSION"
    
    # Send Slack notification for cloud distribution start
    if command -v notify_release_warning &>/dev/null; then
        if [[ "$DRY_RUN" == "true" ]] || [[ "${DRY_RUN:-false}" == "1" ]]; then
            notify_release_warning "SPM" "$VERSION" "Starting DRY RUN: Cloud distribution processing for binary targets" "Cloud Distribution (Dry Run)"
        else
            notify_release_warning "SPM" "$VERSION" "Starting cloud distribution processing for binary targets" "Cloud Distribution"
        fi
    fi
    
    # Execute sync_thirdparty_pods.sh to ensure XCFrameworks are in place
    log_section "Phase: Sync Third-Party XCFrameworks from Pods"
    if [[ -f "$ROOT_DIR/Scripts/spm/sync_thirdparty_pods.sh" ]]; then
        log::step "SPM" "Running sync_thirdparty_pods.sh to ensure XCFrameworks are in place"
        if bash "$ROOT_DIR/Scripts/spm/sync_thirdparty_pods.sh"; then
            log::success "SPM" "Third-party XCFrameworks synced successfully"
        else
            log::warn "SPM" "sync_thirdparty_pods.sh failed, but continuing..."
        fi
    else
        log::warn "SPM" "sync_thirdparty_pods.sh not found, skipping sync step"
    fi
    
    # Process binary targets for cloud distribution (zip + checksum + URL conversion)
    log_section "Phase: Cloud Distribution Processing"
    if ! process_binary_targets_for_cloud_distribution "$VERSION"; then
        log::error "SPM" "Cloud distribution processing failed"
        msp_state_mark_step_failed "spm_publish" "Cloud distribution processing failed" "1"
        return 1
    fi
    
    # Task 2: Ensure Package.swift exists before SPM operations
    # For spm-release mode: Generate core-only Package.swift (excludes missing third-party SDKs)
    # Source common.sh to access ensure_package_swift_enabled function
    if [[ -f "$ROOT_DIR/Scripts/target-switching/common.sh" ]]; then
        source "$ROOT_DIR/Scripts/target-switching/common.sh"
    fi
    
    local repo_package_swift="$ROOT_DIR/Package.swift"
    
    if [[ ! -f "$repo_package_swift" ]]; then
        log::step "SPM" "Package.swift not found, generating core-only Package.swift for spm-release"
        if ! ensure_package_swift_enabled "spm-release"; then
            log::error "SPM" "[SPM][ERROR] Failed to generate core-only Package.swift"
                return 1
            fi
        log::success "SPM" "[SPM][INFO] Package.swift generated (core-only mode)"
    else
        log::info "SPM" "[SPM][INFO] Package.swift found at: $repo_package_swift"
    fi
    
    # Phase 4 TASK 2: SPM Manifest strong validation
    # Phase B Step 5: Use DRY_RUN instead of MSP_RELEASE_TIER
    local release_mode="${MSP_RELEASE_MODE:-cli}"
    local dry_run="${DRY_RUN:-true}"
    local release_mode_upper=$(echo "$release_mode" | tr '[:lower:]' '[:upper:]' 2>/dev/null || echo "$release_mode" | awk '{print toupper($0)}')
    echo "[MSP][ORCH] Mode: ${release_mode_upper} — validating SPM manifest"
    
    # Check if swift is available
    if ! command -v swift >/dev/null 2>&1; then
        log::error "SPM" "Swift is not installed. Cannot validate SPM manifest."
        if [[ "$dry_run" == "false" ]]; then
            exit 1
        fi
    fi
    
    # Phase 4: SPM Manifest validation
    log_section "Phase 4: SPM Manifest Validation"
    
    # Initialize spm_packages_array before use (fix unbound variable error)
    local spm_packages_array=()
    if [[ -n "${SPM_PACKAGES:-}" ]]; then
        # Convert SPM_PACKAGES space-separated string to array
        # shellcheck disable=SC2086 -- intentional word-splitting: SPM_PACKAGES is a space-delimited name list
        for package in $SPM_PACKAGES; do
            spm_packages_array+=("$package")
        done
    fi

    # Use default packages if array is empty
    if [[ ${#spm_packages_array[@]} -eq 0 ]]; then
        log::info "SPM" "SPM_PACKAGES not set or empty, using default package list"
        spm_packages_array=("NovaCore" "NovaAdapter")
    fi
    
    log::info "SPM" "SPM packages to validate: ${spm_packages_array[*]}"
    
    local manifest_errors=()
    local manifest_warnings=()
    local manifest_status="unknown"
    
    # Get remote repository URL
    local remote_url
    remote_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
    if [[ -z "$remote_url" ]]; then
        log::warn "SPM" "Could not determine remote repository URL"
        manifest_warnings+=("Remote URL not found")
    fi
    
    # Convert git URL to raw GitHub URL if needed
    local raw_base_url=""
    if [[ "$remote_url" =~ github\.com ]]; then
        raw_base_url=$(echo "$remote_url" | sed 's|\.git$||' | sed 's|git@github.com:|https://raw.githubusercontent.com/|' | sed 's|https://github.com/|https://raw.githubusercontent.com/|')
    fi
    
    # Use main Package.swift for validation (all packages are defined in one file)
    local main_package_swift="$ROOT_DIR/Package.swift"
    if [[ ! -f "$main_package_swift" ]]; then
        log::error "SPM" "Main Package.swift not found at $main_package_swift"
        manifest_errors+=("Main Package.swift not found")
        # Skip individual package validation if main Package.swift is missing
        log::error "SPM" "Cannot validate individual packages without main Package.swift"
    else
        # Validate each SPM package
        for package in "${spm_packages_array[@]}"; do
            log::step "SPM" "Validating SPM manifest for $package"
            
            # Check if package name exists in Package.swift (basic validation)
            if ! grep -q "\"$package\"" "$main_package_swift" && ! grep -q "'$package'" "$main_package_swift"; then
                log::warn "SPM" "Package name '$package' not found in Package.swift (may be using different name)"
                manifest_warnings+=("Package name not found in Package.swift: $package")
            fi
            
            # Dump local manifest from main Package.swift
            local local_manifest_file="/tmp/local_manifest_${package}_$$.json"
            if command -v swift >/dev/null 2>&1; then
                if swift package dump-package --package-path "$ROOT_DIR" > "$local_manifest_file" 2>/dev/null; then
                    log::success "SPM" "Dumped local manifest for $package from main Package.swift"
                else
                    log::error "SPM" "Failed to dump local manifest for $package"
                    manifest_errors+=("Failed to dump local manifest: $package")
                    continue
                fi
            else
                log::warn "SPM" "Swift not available, skipping manifest dump for $package"
                manifest_warnings+=("Swift not available for $package")
                continue
            fi
            
            # Check tag existence
            local package_tag="${package}-${VERSION}"
            if git rev-parse "$package_tag" >/dev/null 2>&1; then
                log::warn "SPM" "Tag $package_tag already exists"
                if [[ "${MSP_ALLOW_EXISTING_TAG:-0}" != "1" && "${MSP_ALLOW_EXISTING_TAG:-false}" != "true" ]]; then
                    manifest_errors+=("Tag already exists: $package_tag (use MSP_ALLOW_EXISTING_TAG=1 to override)")
                else
                    manifest_warnings+=("Tag already exists (override allowed): $package_tag")
                fi
            fi
            
            # Get remote manifest if possible (use main Package.swift from tag)
            if [[ -n "$raw_base_url" ]]; then
                local remote_manifest_url="${raw_base_url}/${package_tag}/Package.swift"
                local remote_manifest_file="/tmp/remote_manifest_${package}_$$.swift"
                
                log::step "SPM" "Fetching remote manifest from $remote_manifest_url"
                if curl -s -f "$remote_manifest_url" > "$remote_manifest_file" 2>/dev/null; then
                    log::success "SPM" "Fetched remote manifest for $package"
                    
                    # Basic validation: check if remote manifest is parseable
                    if ! swift package dump-package --package-path "$(dirname "$remote_manifest_file")" >/dev/null 2>&1; then
                        manifest_warnings+=("Remote manifest may not be parseable: $package")
                    fi
                else
                    log::warn "SPM" "Could not fetch remote manifest (tag may not exist yet): $package"
                    manifest_warnings+=("Remote manifest not available (expected for new releases): $package")
                fi
            fi
            
            # Extract version from local manifest
            if [[ -f "$local_manifest_file" ]] && command -v jq >/dev/null 2>&1; then
                local manifest_version
                manifest_version=$(jq -r '.version // empty' "$local_manifest_file" 2>/dev/null || echo "")
                if [[ -n "$manifest_version" ]] && [[ "$manifest_version" != "$VERSION" ]]; then
                    manifest_errors+=("Version mismatch in manifest: expected $VERSION, found $manifest_version")
                fi
            fi
            
            # Cleanup temp files
            rm -f "$local_manifest_file" "$remote_manifest_file" 2>/dev/null || true
        done
    fi
    
    # Record manifest validation results in state
    if command -v msp_state_is_enabled &>/dev/null && msp_state_is_enabled; then
        local state_file="$ROOT_DIR/.msp-release-state.json"
        if [[ -f "$state_file" ]] && command -v jq >/dev/null 2>&1; then
            local errors_json="[]"
            local warnings_json="[]"
            
            if [[ ${#manifest_errors[@]} -gt 0 ]]; then
                errors_json=$(printf '%s\n' "${manifest_errors[@]}" | jq -R . | jq -s .)
            fi
            
            if [[ ${#manifest_warnings[@]} -gt 0 ]]; then
                warnings_json=$(printf '%s\n' "${manifest_warnings[@]}" | jq -R . | jq -s .)
            fi
            
            if [[ ${#manifest_errors[@]} -eq 0 ]]; then
                manifest_status="success"
            elif [[ ${#manifest_errors[@]} -gt 0 ]] && [[ "$dry_run" != "false" ]]; then
                manifest_status="warning"
            else
                manifest_status="error"
            fi
            
            jq ".steps.spm_manifest = {
                status: \"$manifest_status\",
                errors: $errors_json,
                warnings: $warnings_json
            }" "$state_file" > "${state_file}.tmp" 2>/dev/null && \
                mv "${state_file}.tmp" "$state_file" 2>/dev/null || true
        fi
    fi
    
    # Handle validation results
    if [[ ${#manifest_errors[@]} -gt 0 ]]; then
        log::error "SPM" "SPM manifest validation failed with ${#manifest_errors[@]} error(s):"
        for error in "${manifest_errors[@]}"; do
            log::error "SPM" "  - $error"
        done
        
        if [[ "$dry_run" == "false" ]]; then
            log::error "SPM" "[MSP][ORCH] Production release: SPM manifest errors are not allowed"
            exit 1
        else
            log::warn "SPM" "[MSP][ORCH] Preflight release: SPM manifest errors are non-blocking"
        fi
    fi
    
    if [[ ${#manifest_warnings[@]} -gt 0 ]]; then
        log::warn "SPM" "SPM manifest validation warnings (${#manifest_warnings[@]}):"
        for warning in "${manifest_warnings[@]}"; do
            log::warn "SPM" "  - $warning"
        done
    fi
    
    if [[ ${#manifest_errors[@]} -eq 0 ]]; then
        log::success "SPM" "SPM manifest validation passed"
    fi
    
    # Skip individual start notifications - only send final success/failure
    
    # spm_packages_array is already initialized in Phase 4 (SPM Manifest validation)
    # Reuse the same array for consistency
    if [[ ${#spm_packages_array[@]} -eq 0 ]]; then
        log::warn "SPM" "spm_packages_array is empty. Re-initializing from SPM_PACKAGES."
        # Convert SPM_PACKAGES space-separated string to array
        spm_packages_array=()
        if [[ -n "${SPM_PACKAGES:-}" ]]; then
            # shellcheck disable=SC2086 -- intentional word-splitting: SPM_PACKAGES is a space-delimited name list
            for package in $SPM_PACKAGES; do
                spm_packages_array+=("$package")
            done
        fi
        
        if [[ ${#spm_packages_array[@]} -eq 0 ]]; then
            log::warn "SPM" "SPM_PACKAGES is empty. Using default package list for backward compatibility."
            spm_packages_array=("NovaCore" "NovaAdapter")
        fi
    fi
    
    log::info "SPM" "Releasing SPM packages from SPM_PACKAGES: ${spm_packages_array[*]}"
    
    # Track release statistics
    local total_packages=${#spm_packages_array[@]}
    local successful_packages=0
    local failed_packages=0
    local failed_package_names=()
    local successful_package_names=()
    
    # Release each SPM package in order
    for package in "${spm_packages_array[@]}"; do
        if release_spm_package "$package" "$VERSION"; then
            ((successful_packages++)) || true
            successful_package_names+=("$package")
        else
            ((failed_packages++)) || true
            failed_package_names+=("$package")
            msp_state_mark_step_failed "spm_publish" "$package release failed" "1"
            exit 1
        fi
    done
    
    # Run local SPM build validation (before publish)
    log::step "SPM" "Running local SPM build validation"
    if ! spm_local_validation; then
        log::error "SPM" "Local SPM validation failed — aborting SPM release"
        msp_state_mark_step_failed "spm_publish" "SPM publish failed due to local validation failure" "1"
        return 1
    fi
    
    # Push all tags
    if push_spm_tags; then
        log::success "SPM" "All SPM tags pushed successfully"
    else
        msp_state_mark_step_failed "spm_publish" "Failed to push SPM tags" "1"
        exit 1
    fi
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local duration_formatted=$(printf "%02d:%02d:%02d" $((duration/3600)) $((duration%3600/60)) $((duration%60)))
    
    print_section "SPM Release Process Completed Successfully"
    log::success "SPM" "All SPM packages released successfully for version: $VERSION"
    log::info "SPM" "SPM packages available at:"
    for package in "${successful_package_names[@]}"; do
        log::info "SPM" "  $package: https://github.com/ParticleMedia/msp-ios-sdk-public.git (tag: ${package}-${VERSION})"
    done
    
    # Mark spm_publish step as successful
    msp_state_mark_step_success "spm_publish"
}

# Entry point
# If RELEASE_VERSION is set from environment (via msp-release.sh), use it directly
# Otherwise, require CLI arguments for backward compatibility
if [[ -z "${RELEASE_VERSION:-}" && $# -eq 0 ]]; then
    show_help
    exit 1
fi

# ============================================================================
# SPM Tag Publishing with Tier Awareness (Patch M)
# ============================================================================
spm_publish_tags() {
    local version="$1"

    # If version is not provided, try to extract from Package.swift
    if [[ -z "$version" ]]; then
        local package_swift="$ROOT_DIR/Package.swift"
        if [[ -f "$package_swift" ]]; then
            log::info "SPM" "[SPM] Extracting version from Package.swift"
            # Extract version from Package.swift: let version = "0.3.0-rc.5"
            version=$(grep -E '^\s*let\s+version\s*=\s*"' "$package_swift" | head -1 | sed -E 's/.*let\s+version\s*=\s*"([^"]+)".*/\1/' || echo "")
            if [[ -z "$version" ]]; then
                log::error "SPM" "[SPM] spm_publish_tags: Could not extract version from Package.swift"
                return 1
            fi
            log::info "SPM" "[SPM] Extracted version from Package.swift: $version"
        else
            log::error "SPM" "[SPM] spm_publish_tags: version is required and Package.swift not found"
            return 1
        fi
    fi

    # Source release-common.sh for config-driven gating
    if [[ -f "$ROOT_DIR/Scripts/lib/release-common.sh" ]]; then
        source "$ROOT_DIR/Scripts/lib/release-common.sh" 2>/dev/null || true
    fi

    # Source config if not already loaded
    if ! command -v should_real_publish &>/dev/null; then
        if [[ -f "$ROOT_DIR/Scripts/release/lib/config.sh" ]]; then
            source "$ROOT_DIR/Scripts/release/lib/config.sh" 2>/dev/null || true
            msp_load_release_config 2>/dev/null || true
        fi
    fi

    # Config-driven gating: skip if spm.enabled is false
    if ! is_enabled "spm.enabled"; then
        log::info "SPM" "[SPM] [CONFIG] Skipping tag & remote publish (config: spm.enabled=false, version: $version)"
        return 0
    fi

    # Real release tier behavior - check config (Patch M+CONFIG)
    if ! should_real_publish; then
        local branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
        log::error "SPM" "[SPM][BLOCKED] Real tag & remote publish not allowed on branch: $branch"
        log::error "SPM" "[SPM][BLOCKED] Check Scripts/config/release.yaml for branch policy"
        return 1
    fi

    # Real release tier behavior
    log::info "SPM" "[SPM] Creating and pushing tag for version: $version"
    log::info "SPM" "[SPM] All SPM products will share the same version tag (standard SPM practice)"

    # SPM standard: Single tag for entire Package.swift
    # All products (NovaCore, MSPNovaAdapter, MSPAmazonAdapter, etc.) use the same version
    local tag_name="$version"

    log::step "SPM" "Creating unified SPM git tag: $tag_name"

    # ════════════════════════════════════════════════════════════════════════════
    # Idempotent Tag Handling: Check if tag already exists and points to HEAD
    # ════════════════════════════════════════════════════════════════════════════
    # If CocoaPods has already created and pushed the tag correctly, skip recreation
    # This prevents unnecessary tag deletion/recreation and potential race conditions
    # ════════════════════════════════════════════════════════════════════════════

    local current_head_sha
    current_head_sha=$(git rev-parse HEAD 2>/dev/null)

    local local_tag_sha=""
    local remote_tag_sha=""
    local tag_is_correct=false

    # Check local tag
    if git tag -l | grep -q "^${tag_name}$"; then
        # Use ^{commit} to dereference annotated tags to their underlying commit SHA
        local_tag_sha=$(git rev-parse "refs/tags/${tag_name}^{commit}" 2>/dev/null || echo "")
        if [[ "$local_tag_sha" == "$current_head_sha" ]]; then
            log::info "SPM" "Local tag $tag_name already exists and points to correct commit"
            tag_is_correct=true
        else
            log::warn "SPM" "Local tag $tag_name exists but points to wrong commit"
            log::warn "SPM" "  Expected: $current_head_sha"
            log::warn "SPM" "  Actual:   $local_tag_sha"
            log::info "SPM" "Deleting incorrect local tag..."
            git tag -d "$tag_name" 2>/dev/null || true
        fi
    fi

    # Check remote tag (origin) with timeout
    # Use ^{} pattern to get the dereferenced commit SHA for annotated tags
    remote_tag_sha=$(timeout 30 git ls-remote --tags origin "refs/tags/${tag_name}" "refs/tags/${tag_name}^{}" 2>/dev/null | tail -1 | cut -f1 || echo "")
    if [[ -n "$remote_tag_sha" ]]; then
        if [[ "$remote_tag_sha" == "$current_head_sha" ]]; then
            log::info "SPM" "Remote tag $tag_name already exists on origin and points to correct commit"
            # If both local and remote are correct, skip all tag operations
            if [[ "$tag_is_correct" == "true" ]]; then
                log::success "SPM" "✓ Tag $tag_name already exists and is correct (skipping tag creation)"
                log::info "SPM" "  This tag was likely created by CocoaPods release"
                return 0
            fi
        else
            log::warn "SPM" "Remote tag $tag_name exists on origin but points to wrong commit"
            log::warn "SPM" "  Expected: $current_head_sha"
            log::warn "SPM" "  Actual:   $remote_tag_sha"
            log::info "SPM" "Deleting incorrect remote tag..."
            timeout 30 git push origin ":refs/tags/${tag_name}" 2>/dev/null || true
            sleep 2  # Wait for remote to process deletion
        fi
    fi

    # Only create tag if it doesn't exist locally or was deleted
    if ! git tag -l | grep -q "^${tag_name}$"; then
        # Create tag
        if git tag -a "$tag_name" -m "SPM Release $version

Products included:
- MSPAds (umbrella product)
- MSPCore, MSPiOSCore, MSPSharedLibraries (core modules)
- NovaCore, MSPNovaAdapter (Nova ad network)
- MSPAmazonAdapter (Amazon Publisher Services)
- MSPMolocoAdapter (Moloco advertising)
- MSPLiftoffAdapter (Liftoff/Vungle advertising)
- MSPGoogleAdapter, MSPFacebookAdapter, MSPPrebidAdapter (adapters)
- And more...

All binary XCFrameworks are available via GitHub Release assets."; then
            log::success "SPM" "Created unified SPM tag: $tag_name"
        else
            log::error "SPM" "Failed to create tag: $tag_name"
            return 1
        fi
    fi

    # Push tags to remote (only if not already there)
    if [[ -z "$remote_tag_sha" ]] || [[ "$remote_tag_sha" != "$current_head_sha" ]]; then
        log::step "SPM" "Pushing tags to remote"
        if git push origin --tags; then
            log::success "SPM" "Pushed tags to remote"
        else
            log::error "SPM" "Failed to push tags to remote"
            return 1
        fi
    else
        log::info "SPM" "Tag already exists on remote with correct SHA, skipping push"
    fi

}

# Run main function with all arguments
main "$@"
