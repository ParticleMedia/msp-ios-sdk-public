#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

# Modular SPM Release Script
# Releases Swift Package Manager packages
#
# Phase 2 Step 4: Config-driven release
# This script now uses environment variables from msp-release.sh instead of CLI arguments.

set -e

# Source the common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ============================================
# Unified ROOT_DIR resolution (final version)
# ============================================
if [[ -z "${ROOT_DIR:-}" ]]; then
    # First try Git repo root (most reliable)
    if command -v git >/dev/null 2>&1; then
        git_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
        if [[ -n "$git_root" ]]; then
            ROOT_DIR="$git_root"
        fi
    fi

    # Fallback to walking up from SCRIPT_DIR
    if [[ -z "${ROOT_DIR:-}" ]]; then
        ROOT_DIR="$SCRIPT_DIR"
        while [[ "$ROOT_DIR" != "/" ]] && [[ "${ROOT_DIR##*/}" != "Scripts" ]]; do
            ROOT_DIR="$(dirname "$ROOT_DIR")"
        done
        if [[ "${ROOT_DIR##*/}" == "Scripts" ]]; then
            ROOT_DIR="$(dirname "$ROOT_DIR")"
        fi
    fi
fi

export ROOT_DIR

# ============================================================================
# Load Notification Functions
# ============================================================================
# Load Slack notification functions if available
if [[ -f "$ROOT_DIR/Scripts/notify/slack.sh" ]]; then
    # shellcheck source=Scripts/notify/slack.sh
    source "$ROOT_DIR/Scripts/notify/slack.sh"
    log_debug "[NOTIFY] Loaded Slack notification functions from: Scripts/notify/slack.sh" 2>/dev/null || true
else
    # Define stub functions to prevent errors (backward compatibility)
    log_debug "[NOTIFY] Slack notification functions not found, using stub functions" 2>/dev/null || true
    notify_release_failure() { :; }
    notify_release_success() { :; }
    notify_release_success_with_summary() { :; }
    notify_release_warning() { :; }
fi

source "$ROOT_DIR/Scripts/lib/release-common.sh"

# Load release state utilities (state.sh is already loaded by release-common.sh, but we can source it again if needed)
# Use absolute path to ensure correct location
if [[ -f "$ROOT_DIR/Scripts/release/utils/state.sh" ]]; then
    source "$ROOT_DIR/Scripts/release/utils/state.sh" 2>/dev/null || true
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
        log_error "RELEASE_VERSION not set. Did you forget to run via msp-release.sh?"
        log_info "Usage: msp-release.sh spm <VERSION>"
        log_info "   or: $0 <VERSION> [OPTIONS]  (direct call for debugging)"
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
DEFAULT_SPM_PACKAGES="NovaCore NovaAdapter"
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
    echo "  1. Update NovaCore Package.swift version"
    echo "  2. Update NovaAdapter Package.swift version and dependency"
    echo "  3. Create git tags for SPM packages"
    echo "  4. Push tags to remote"
}

# Validate inputs
validate_inputs() {
    if [[ -z "$VERSION" ]]; then
        log_error "Version is required"
        show_help
        exit 1
    fi
    
    # Set release branch if not provided
    if [[ -z "$RELEASE_BRANCH" ]]; then
        RELEASE_BRANCH="release/$VERSION"
    fi
    
    log_info "SPM release configuration:"
    log_info "  Version: $VERSION"
    log_info "  Release Branch: $RELEASE_BRANCH"
    log_info "  Dry Run: $DRY_RUN"
    if [[ -n "${SPM_PACKAGES:-}" ]]; then
        log_info "  SPM Packages: $SPM_PACKAGES"
    fi
}

# Check if we're on the correct release branch
check_release_branch() {
    log_step "Checking release branch"
    
    # Skip branch check in dry-run mode
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Skipping release branch check"
        return 0
    fi
    
    local current_branch=$(git branch --show-current)
    # Allow feature/spm_impl branch for development/testing
    if [[ "$current_branch" != "$RELEASE_BRANCH" ]] && [[ "$current_branch" != "feature/spm_impl" ]]; then
        log_error "Not on release branch '$RELEASE_BRANCH' or feature/spm_impl. Current branch: '$current_branch'"
        log_info "Please checkout the release branch first:"
        log_info "  git checkout $RELEASE_BRANCH"
        log_info "  or use feature/spm_impl for development/testing"
        exit 1
    fi
    
    if [[ "$current_branch" == "feature/spm_impl" ]]; then
        log_warn "Running on feature/spm_impl branch (development mode)"
    fi
    
    log_success "On correct release branch: $RELEASE_BRANCH"
}

# Update Package.swift version
update_package_swift_version() {
    local package_file="$1"
    local version="$2"
    
    if [[ ! -f "$package_file" ]]; then
        log_warning "Package.swift not found: $package_file"
        return 0
    fi
    
    log_step "Updating version in $package_file to $version"
    
    # Create backup
    cp "$package_file" "${package_file}.backup"
    
    # Update version in Package.swift
    sed -i '' "s|let version = \".*\"|let version = \"${version}\"|g" "$package_file"
    
    log_success "Updated version in $package_file"
}

# Update Package.swift dependency
update_package_swift_dependency() {
    local package_file="$1"
    local dependency_name="$2"
    local version="$3"
    
    if [[ ! -f "$package_file" ]]; then
        log_warning "Package.swift not found: $package_file"
        return 0
    fi
    
    log_step "Updating $dependency_name dependency in $package_file to $version"
    
    # Update dependency version
    sed -i '' "s|\.package(url: \"https://github\.com/ParticleMedia/msp-ios-sdk-public\.git\", from: \".*\")|.package(url: \"https://github.com/ParticleMedia/msp-ios-sdk-public.git\", from: \"${version}\")|g" "$package_file"
    
    log_success "Updated $dependency_name dependency in $package_file"
}

# Create git tag for SPM package
create_spm_tag() {
    local package_name="$1"
    local version="$2"
    local tag_name="${package_name}-${version}"
    
    log_step "Creating git tag for SPM package: $tag_name"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would create tag $tag_name"
        return 0
    fi
    
    # Check if tag already exists
    if git tag -l | grep -q "^${tag_name}$"; then
        log_warning "Tag $tag_name already exists"
        return 0
    fi
    
    # Create tag
    if git tag "$tag_name"; then
        log_success "Created tag: $tag_name"
        
        # Track tag creation in state
        if command -v msp_state_mark_git_flag &>/dev/null; then
            msp_state_mark_git_flag "tag_created" true
            if command -v msp_state_set_tag_name &>/dev/null; then
                # Track the last tag created (SPM may create multiple tags)
                msp_state_set_tag_name "$tag_name"
            fi
        fi
    else
        log_error "Failed to create tag: $tag_name"
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
    # Check if we should skip this step in resume mode
    if _msp_spm_should_skip_step "spm_local_validation"; then
        log_info "Resuming: skipping spm_local_validation (status already success/skipped)"
        return 0
    fi
    
    # Check if local validation should be skipped via environment variable
    if [[ "${SKIP_SPM_LOCAL_VALIDATION:-false}" == "true" ]] || [[ "${SKIP_SPM_LOCAL_VALIDATION:-false}" == "1" ]]; then
        log_info "Skipping SPM local build validation (SKIP_SPM_LOCAL_VALIDATION=true)"
        msp_state_mark_step_skipped "spm_local_validation" "SPM local validation skipped due to SKIP_SPM_LOCAL_VALIDATION=true"
        return 0
    fi
    
    msp_state_mark_step_running "spm_local_validation"
    
    log_section "SPM Local Build Validation"
    
    # DRY_RUN shortcut
    if [[ "$DRY_RUN" == "true" ]] || [[ "$DRY_RUN" == "1" ]]; then
        log_info "[DRY_RUN] Skipping SPM local build validation"
        msp_state_mark_step_skipped "spm_local_validation" "SPM local validation skipped due to DRY_RUN"
        return 0
    fi
    
    # Get SPM product name with fallback
    local spm_product_name="${SPM_REMOTE_PRODUCT_NAME:-MSPAds}"
    
    # Create temp directory
    log_step "Creating temporary test package"
    local SPM_LOCAL_TMPDIR
    SPM_LOCAL_TMPDIR="$(mktemp -d -t msp_spm_local_XXXXXX)"
    if [[ ! -d "$SPM_LOCAL_TMPDIR" ]]; then
        log_error "Failed to create temporary directory"
        return 1
    fi
    
    # Cleanup function
    local cleanup_on_exit=true
    if [[ "${DEBUG:-false}" == "true" ]] || [[ "${VERBOSE:-false}" == "true" ]]; then
        cleanup_on_exit=false
        log_info "DEBUG/VERBOSE mode: keeping test directory at $SPM_LOCAL_TMPDIR"
    fi
    
    cleanup_temp_dir() {
        if [[ "$cleanup_on_exit" == "true" ]]; then
            log_step "Cleaning up temporary directory"
            rm -rf "$SPM_LOCAL_TMPDIR" 2>/dev/null || true
        fi
    }
    
    trap cleanup_temp_dir EXIT
    
    cd "$SPM_LOCAL_TMPDIR" || {
        log_error "Failed to change to temporary directory"
        return 1
    }
    
    # Initialize minimal SwiftPM executable package
    log_step "Initializing SwiftPM test package"
    if ! swift package init --type executable --name MSP_SPMLocalTest 2>&1; then
        log_error "Failed to initialize Swift package"
        return 1
    fi
    
    log_success "Swift package initialized"
    
    # Get absolute path to repo Package.swift
    local repo_package_swift="$ROOT_DIR/Package.swift"
    if [[ ! -f "$repo_package_swift" ]]; then
        log_error "[SPM][ERROR] Package.swift not found at: $repo_package_swift"
        log_error "[SPM][ERROR] SPM local validation requires Package.swift to be generated first"
        # Phase B Step 5: In dry-run mode, allow soft-fail
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            return 1
        else
            log_warn "[SPM][WARN] Dry-run mode: skipping local validation"
            return 0
        fi
    else
        log_info "[SPM][INFO] Package.swift found at: $repo_package_swift"
    fi
    
    local repo_abs_path
    repo_abs_path="$(cd "$ROOT_DIR" && pwd)"
    
    # Create test Package.swift that depends on local repo Package.swift
    log_step "Creating test Package.swift with local dependency"
    local test_package_swift="$SPM_LOCAL_TMPDIR/Package.swift"
    
    cat > "$test_package_swift" << EOF
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MSP_SPMLocalTest",
    dependencies: [
        .package(path: "$repo_abs_path")
    ],
    targets: [
        .executableTarget(
            name: "MSP_SPMLocalTest",
            dependencies: [
                .product(name: "$spm_product_name", package: "msp-ios-sdk")
            ]
        )
    ]
)
EOF
    
    log_info "Test Package.swift created with dependency on: $repo_abs_path"
    
    # Update main.swift to import the product
    log_step "Updating main.swift to import SPM product"
    local main_swift="$SPM_LOCAL_TMPDIR/Sources/MSP_SPMLocalTest/main.swift"
    if [[ -f "$main_swift" ]]; then
        cat > "$main_swift" << EOF
import Foundation
import ${spm_product_name}

print("MSP SPM Local Validation Test")
print("If you see this, the local build succeeded.")
EOF
        log_info "main.swift updated with import: $spm_product_name"
    fi
    
    # Run swift package resolve
    log_step "Resolving Swift package dependencies"
    local resolve_output
    local resolve_exit_code
    
    if [[ "$VERBOSE" == "true" ]]; then
        if swift package resolve 2>&1; then
            resolve_exit_code=0
        else
            resolve_exit_code=$?
        fi
    else
        resolve_output=$(swift package resolve 2>&1)
        resolve_exit_code=$?
    fi
    
    if [[ $resolve_exit_code -ne 0 ]]; then
        log_error "swift package resolve failed (exit code: $resolve_exit_code)"
        if [[ "$VERBOSE" != "true" && -n "$resolve_output" ]]; then
            log_info "Resolve output (last 20 lines):"
            echo "$resolve_output" | tail -20 | sed 's/^/  /'
        fi
        return 1
    fi
    
    log_success "Swift package resolved successfully"
    
    # Run swift build -c release
    log_step "Building Swift package (release configuration)"
    local build_output
    local build_exit_code
    
    if [[ "$VERBOSE" == "true" ]]; then
        if swift build -c release 2>&1; then
            build_exit_code=0
        else
            build_exit_code=$?
        fi
    else
        build_output=$(swift build -c release 2>&1)
        build_exit_code=$?
    fi
    
    if [[ $build_exit_code -ne 0 ]]; then
        log_error "swift build failed (exit code: $build_exit_code)"
        if [[ "$VERBOSE" != "true" && -n "$build_output" ]]; then
            log_info "Build output (last 20 lines):"
            echo "$build_output" | tail -20 | sed 's/^/  /'
        fi
        log_error "SPM Local Build Validation Failed"
        msp_state_mark_step_failed "spm_local_validation" "SPM local validation failed" "1"
        return 1
    fi
    
    log_success "Swift package built successfully"
    
    # Produce summary
    ui_divider
    log_success "SPM Local Build Validation Summary"
    ui_kv "Temp Directory" "$SPM_LOCAL_TMPDIR"
    ui_kv "SPM Product" "$spm_product_name"
    ui_kv "Status" "Success"
    ui_divider
    
    # Disable cleanup if we got here successfully (for inspection)
    if [[ "${KEEP_VERIFY_ARTIFACTS:-false}" == "true" ]]; then
        cleanup_on_exit=false
        log_info "Artifacts kept at: $SPM_LOCAL_TMPDIR"
    fi
    
    msp_state_mark_step_success "spm_local_validation"
    return 0
}

# Push tags to remote
push_spm_tags() {
    log_step "Pushing SPM tags to remote"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would push tags to remote"
        return 0
    fi
    
    # Push all tags
    spm_publish_tags "$VERSION"
    
    log_success "Pushed SPM tags to remote"
}

# ============================================================================
# SPM Cloud Distribution Functions
# ============================================================================

# Create deterministic zip file from XCFramework
create_deterministic_zip() {
    local xcframework_path="$1"
    local zip_output_path="$2"
    local framework_name="$3"
    
    if [[ ! -d "$xcframework_path" ]]; then
        log_error "XCFramework not found: $xcframework_path"
        return 1
    fi
    
    log_step "Creating deterministic zip for $framework_name"
    
    # Create temporary directory for zip creation
    local temp_zip_dir
    temp_zip_dir="$(mktemp -d -t msp_spm_zip_XXXXXX)"
    if [[ ! -d "$temp_zip_dir" ]]; then
        log_error "Failed to create temporary directory for zip"
        return 1
    fi
    
    # Copy XCFramework to temp directory
    cp -R "$xcframework_path" "$temp_zip_dir/$(basename "$xcframework_path")"
    
    # Set deterministic timestamp to ensure consistent checksums across builds
    # Use a fixed date (2025-01-01 00:00:00 UTC) for all files
    log_info "Setting deterministic timestamps for reproducible zip"
    find "$temp_zip_dir" -exec touch -t 202501010000.00 {} \;
    
    # Create deterministic zip file
    # -r: recursive
    # -X: exclude extra file attributes (ensures cross-platform reproducibility)
    # -q: quiet mode
    log_info "Creating deterministic zip file"
    (cd "$temp_zip_dir" && TZ=UTC zip -r -X -q "$zip_output_path" .)
    local zip_exit_code=$?
    
    # Cleanup
    rm -rf "$temp_zip_dir"
    
    if [[ $zip_exit_code -ne 0 ]] || [[ ! -f "$zip_output_path" ]]; then
        log_error "Failed to create zip file: $zip_output_path"
        return 1
    fi
    
    log_success "Created deterministic zip: $zip_output_path"
    return 0
}

# Compute checksum for zip file using swift package compute-checksum
compute_zip_checksum() {
    local zip_path="$1"
    
    if [[ ! -f "$zip_path" ]]; then
        log_error "Zip file not found: $zip_path"
        return 1
    fi
    
    log_step "Computing checksum for $(basename "$zip_path")"
    
    # Use swift package compute-checksum (preferred method)
    if command -v swift >/dev/null 2>&1; then
        local checksum
        checksum=$(swift package compute-checksum "$zip_path" 2>/dev/null)
        if [[ -n "$checksum" ]] && [[ ${#checksum} -eq 64 ]]; then
            log_success "Computed checksum: $checksum"
            echo "$checksum"
            return 0
        else
            log_warn "swift package compute-checksum failed or returned invalid checksum, falling back to shasum"
        fi
    fi
    
    # Fallback to shasum
    if command -v shasum >/dev/null 2>&1; then
        local checksum
        checksum=$(shasum -a 256 "$zip_path" 2>/dev/null | cut -d' ' -f1)
        if [[ -n "$checksum" ]] && [[ ${#checksum} -eq 64 ]]; then
            log_success "Computed checksum (shasum): $checksum"
            echo "$checksum"
            return 0
        else
            log_error "shasum failed to compute checksum"
            return 1
        fi
    fi
    
    log_error "Neither swift package compute-checksum nor shasum is available"
    return 1
}

# Upload zip file to GitHub Release
upload_xcframework_to_github_release() {
    local zip_path="$1"
    local framework_name="$2"
    local version="$3"
    
    if [[ ! -f "$zip_path" ]]; then
        log_error "Zip file not found: $zip_path"
        return 1
    fi
    
    log_step "Uploading $framework_name to GitHub Release"
    
    if [[ "$DRY_RUN" == "true" ]] || [[ "${DRY_RUN:-false}" == "1" ]]; then
        local zip_url="https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/$(basename "$zip_path")"
        log_info "DRY RUN: Would upload $zip_path to GitHub Release $version"
        log_info "DRY RUN: Generated URL: $zip_url"
        return 0
    fi
    
    # Check if GitHub CLI is available
    if ! command -v gh >/dev/null 2>&1; then
        log_error "GitHub CLI (gh) is not available"
        return 1
    fi
    
    # Create or update GitHub release with retry logic
    local gh_release_created=false
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        if gh release view "$version" --repo "ParticleMedia/msp-ios-sdk-public" &>/dev/null; then
            log_info "Release $version already exists, uploading asset (attempt $((retry_count + 1))/$max_retries)"
            if gh release upload "$version" "$zip_path" --repo "ParticleMedia/msp-ios-sdk-public" --clobber; then
                gh_release_created=true
                break
            else
                ((retry_count++))
                if [[ $retry_count -lt $max_retries ]]; then
                    log_warn "Upload failed, retrying in 5 seconds..."
                    sleep 5
                fi
            fi
        else
            log_info "Creating new release $version (attempt $((retry_count + 1))/$max_retries)"
            if gh release create "$version" "$zip_path" --repo "ParticleMedia/msp-ios-sdk-public" --title "Release $version" --notes "Release $version" --latest; then
                gh_release_created=true
                break
            else
                ((retry_count++))
                if [[ $retry_count -lt $max_retries ]]; then
                    log_warn "Release creation failed, retrying in 5 seconds..."
                    sleep 5
                fi
            fi
        fi
    done
    
    if [[ "$gh_release_created" == "true" ]]; then
        log_success "Uploaded $framework_name to GitHub Release $version"
        return 0
    else
        log_error "Failed to upload $framework_name to GitHub Release"
        return 1
    fi
}

# Process all XCFrameworks for cloud distribution
process_binary_targets_for_cloud_distribution() {
    local version="$1"
    
    log_section "Processing Binary Targets for Cloud Distribution"
    
    # Find XCFrameworks for core modules (NovaCore, NovaAdapter) in Build/XCFrameworks/
    # For real release, we only process core modules, not all third-party SDKs
    local xcframeworks=()
    
    log_step "Scanning for core module XCFrameworks"
    
    # Only scan Build/XCFrameworks/ for core modules
    if [[ -d "$ROOT_DIR/Build/XCFrameworks" ]]; then
        # Process core modules: NovaCore, NovaAdapter
        local core_modules=("NovaCore" "NovaAdapter")
        for module in "${core_modules[@]}"; do
            local xcframework_path="$ROOT_DIR/Build/XCFrameworks/${module}.xcframework"
            if [[ -d "$xcframework_path" ]]; then
                xcframeworks+=("$xcframework_path")
                log_info "Found core module: $module"
            else
                log_warn "Core module XCFramework not found: $xcframework_path"
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
        log_warn "No XCFrameworks found in ThirdParty/ or Build/XCFrameworks/"
        return 0
    fi
    
    log_info "Found ${#xcframeworks[@]} XCFramework(s) to process"
    
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
        
        log_step "Processing $framework_name"
        
        # Create deterministic zip
        if ! create_deterministic_zip "$xcframework_path" "$zip_path" "$framework_name"; then
            log_error "Failed to create zip for $framework_name"
            ((failed_count++))
            continue
        fi
        
        # Compute checksum
        local checksum
        checksum=$(compute_zip_checksum "$zip_path")
        if [[ -z "$checksum" ]]; then
            log_error "Failed to compute checksum for $framework_name"
            rm -f "$zip_path"
            ((failed_count++))
            
            # Send Slack alert on checksum failure
            if [[ "$DRY_RUN" != "true" ]]; then
                if command -v notify_release_failure &>/dev/null; then
                    notify_release_failure "SPM" "$version" "Failed to compute checksum for $framework_name" "Checksum Computation"
                fi
            fi
            return 1
        fi
        
        # Store checksum for Package.swift update
        framework_checksums+=("$framework_name|$checksum|$zip_name")
        
        # Upload to GitHub Release (only in real release, not dry run)
        if [[ "$DRY_RUN" != "true" ]]; then
            if ! upload_xcframework_to_github_release "$zip_path" "$framework_name" "$version"; then
                log_error "Failed to upload $framework_name to GitHub Release"
                ((failed_count++))
                continue
            fi
        else
            log_info "DRY RUN: Would upload $framework_name to GitHub Release"
        fi
        
        ((processed_count++))
        log_success "Processed $framework_name (checksum: ${checksum:0:16}...)"
    done
    
    log_info "Processed $processed_count XCFramework(s), $failed_count failed"
    
    # Update Package.swift with URL and checksum
    if [[ ${#framework_checksums[@]} -gt 0 ]]; then
        log_step "Updating Package.swift with cloud distribution URLs and checksums"
        if update_package_swift_binary_targets "$version" "${framework_checksums[@]}"; then
            log_success "Updated Package.swift with cloud distribution information"
        else
            log_error "Failed to update Package.swift"
            return 1
        fi
    fi
    
    if [[ $failed_count -gt 0 ]]; then
        log_error "Some XCFrameworks failed to process"
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
        log_error "Package.swift not found: $package_swift"
        return 1
    fi
    
    log_step "Updating Package.swift binary targets"
    
    # Create backup
    local backup_file="${package_swift}.backup-$(date +%Y%m%d-%H%M%S)"
    cp "$package_swift" "$backup_file"
    log_info "Created backup: $backup_file"
    
    # Read Package.swift content
    local package_content
    package_content=$(cat "$package_swift")
    
    # Process each framework using the standalone Ruby script
    for framework_info in "${framework_checksums[@]}"; do
        IFS='|' read -r framework_name checksum zip_name <<< "$framework_info"
        
        local url="https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/${zip_name}"
        
        log_info "Updating $framework_name: path → url + checksum"
        
        # Use standalone Ruby script for robust replacement
        local ruby_script="$ROOT_DIR/Scripts/spm/update_manifest.rb"
        if [[ ! -f "$ruby_script" ]]; then
            log_error "Ruby script not found: $ruby_script"
            mv "$backup_file" "$package_swift"
            return 1
        fi
        
        if ! ruby "$ruby_script" "$package_swift" "$framework_name" "$url" "$checksum"; then
            log_error "Failed to update Package.swift for $framework_name"
            # Restore backup
            mv "$backup_file" "$package_swift"
            return 1
        fi
    done
    
    # Write updated content
    echo "$package_content" > "$package_swift"
    
    log_success "Updated Package.swift with cloud distribution URLs and checksums"
    
    # Show preview of changes
    if [[ "$DRY_RUN" == "true" ]] || [[ "${DRY_RUN:-false}" == "1" ]] || [[ "${VERBOSE:-false}" == "true" ]]; then
        log_info "Package.swift changes preview:"
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
        log_warn "Package.swift not found for $package_name, skipping version update"
    fi
    
    # Update Package.swift version if found
    if [[ -n "$package_file" ]]; then
        update_package_swift_version "$package_file" "$version"
    fi
    
    # Update dependencies if this package depends on other SPM packages
    # For example, NovaAdapter depends on NovaCore
    if [[ "$package_name" == "NovaAdapter" ]]; then
        if [[ -n "$package_file" ]]; then
            update_package_swift_dependency "$package_file" "NovaCore" "$version"
        fi
    fi
    
    log_success "$package_name SPM package prepared"
}


# Main function
main() {
    # Initialize state for standalone SPM flow
    msp_state_init "run"
    
    # Check if SPM publish should be skipped
    if [[ "${SPM_ENABLED:-true}" == "false" ]] || [[ "${SKIP_SPM:-false}" == "true" ]]; then
        msp_state_mark_step_skipped "spm_publish" "SPM publish skipped due to SPM_ENABLED=false or SKIP_SPM=true"
        msp_state_mark_step_skipped "spm_local_validation" "SPM local validation skipped due to SPM_ENABLED=false or SKIP_SPM=true"
        log_info "SPM publish skipped"
        return 0
    fi
    
    # Backward compatibility: parse remaining CLI arguments if any
    # (Only used if script is called directly, not via msp-release.sh)
    if [[ $# -gt 0 ]]; then
        parse_arguments "$@"
    fi
    
    # Validate inputs
    validate_inputs
    
    # Ensure we're in the project root
    ensure_project_root
    
    # Check release branch (skip in DRY_RUN mode)
    if [[ "$DRY_RUN" != "true" ]] && [[ "${DRY_RUN:-false}" != "1" ]]; then
        check_release_branch
    else
        log_info "DRY RUN: Skipping release branch check"
    fi
    
    # Record start time for duration calculation
    local start_time=$(date +%s)
    
    # Check if we should skip this step in resume mode
    if _msp_spm_should_skip_step "spm_publish"; then
        log_info "Resuming: skipping spm_publish (status already success/skipped)"
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
        log_step "Running sync_thirdparty_pods.sh to ensure XCFrameworks are in place"
        if bash "$ROOT_DIR/Scripts/spm/sync_thirdparty_pods.sh"; then
            log_success "Third-party XCFrameworks synced successfully"
        else
            log_warn "sync_thirdparty_pods.sh failed, but continuing..."
        fi
    else
        log_warn "sync_thirdparty_pods.sh not found, skipping sync step"
    fi
    
    # Process binary targets for cloud distribution (zip + checksum + URL conversion)
    log_section "Phase: Cloud Distribution Processing"
    if ! process_binary_targets_for_cloud_distribution "$VERSION"; then
        log_error "Cloud distribution processing failed"
        if [[ "$DRY_RUN" != "true" ]] && [[ "${DRY_RUN:-false}" != "1" ]]; then
            if command -v notify_release_failure &>/dev/null; then
                notify_release_failure "SPM" "$VERSION" "Cloud distribution processing failed" "Cloud Distribution"
            fi
        fi
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
        log_step "Package.swift not found, generating core-only Package.swift for spm-release"
        if ! ensure_package_swift_enabled "spm-release"; then
            log_error "[SPM][ERROR] Failed to generate core-only Package.swift"
                return 1
            fi
        log_success "[SPM][INFO] Package.swift generated (core-only mode)"
    else
        log_info "[SPM][INFO] Package.swift found at: $repo_package_swift"
    fi
    
    # Phase 4 TASK 2: SPM Manifest strong validation
    # Phase B Step 5: Use DRY_RUN instead of MSP_RELEASE_TIER
    local release_mode="${MSP_RELEASE_MODE:-cli}"
    local dry_run="${DRY_RUN:-true}"
    local release_mode_upper=$(echo "$release_mode" | tr '[:lower:]' '[:upper:]' 2>/dev/null || echo "$release_mode" | awk '{print toupper($0)}')
    echo "[MSP][ORCH] Mode: ${release_mode_upper} — validating SPM manifest"
    
    # Check if swift is available
    if ! command -v swift >/dev/null 2>&1; then
        log_error "Swift is not installed. Cannot validate SPM manifest."
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
        for package in $SPM_PACKAGES; do
            spm_packages_array+=("$package")
        done
    fi
    
    # Use default packages if array is empty
    if [[ ${#spm_packages_array[@]} -eq 0 ]]; then
        log_info "SPM_PACKAGES not set or empty, using default package list"
        spm_packages_array=("NovaCore" "NovaAdapter")
    fi
    
    log_info "SPM packages to validate: ${spm_packages_array[*]}"
    
    local manifest_errors=()
    local manifest_warnings=()
    local manifest_status="unknown"
    
    # Get remote repository URL
    local remote_url
    remote_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
    if [[ -z "$remote_url" ]]; then
        log_warn "Could not determine remote repository URL"
        manifest_warnings+=("Remote URL not found")
    fi
    
    # Convert git URL to raw GitHub URL if needed
    local raw_base_url=""
    if [[ "$remote_url" =~ github\.com ]]; then
        raw_base_url=$(echo "$remote_url" | sed 's|\.git$||' | sed 's|git@github.com:|https://raw.githubusercontent.com/|' | sed 's|https://github.com/|https://raw.githubusercontent.com/|')
    fi
    
    # Validate each SPM package
    for package in "${spm_packages_array[@]}"; do
        log_step "Validating SPM manifest for $package"
        
        # Find Package.swift file
        local package_file=""
        if [[ -f "$package/Package.swift" ]]; then
            package_file="$package/Package.swift"
        elif [[ -f "$ROOT_DIR/$package/Package.swift" ]]; then
            package_file="$ROOT_DIR/$package/Package.swift"
        elif [[ -f "Package.swift" ]]; then
            package_file="Package.swift"
        fi
        
        if [[ -z "$package_file" ]] || [[ ! -f "$package_file" ]]; then
            log_error "Package.swift not found for $package"
            manifest_errors+=("Package.swift not found: $package")
            continue
        fi
        
        # Dump local manifest
        local local_manifest_file="/tmp/local_manifest_${package}_$$.json"
        if command -v swift >/dev/null 2>&1; then
            if swift package dump-package --package-path "$(dirname "$package_file")" > "$local_manifest_file" 2>/dev/null; then
                log_success "Dumped local manifest for $package"
            else
                log_error "Failed to dump local manifest for $package"
                manifest_errors+=("Failed to dump local manifest: $package")
                continue
            fi
        else
            log_warn "Swift not available, skipping manifest dump for $package"
            manifest_warnings+=("Swift not available for $package")
            continue
        fi
        
        # Check tag existence
        local package_tag="${package}-${VERSION}"
        if git rev-parse "$package_tag" >/dev/null 2>&1; then
            log_warn "Tag $package_tag already exists"
            if [[ "${MSP_ALLOW_EXISTING_TAG:-0}" != "1" ]]; then
                manifest_errors+=("Tag already exists: $package_tag (use MSP_ALLOW_EXISTING_TAG=1 to override)")
            else
                manifest_warnings+=("Tag already exists (override allowed): $package_tag")
            fi
        fi
        
        # Get remote manifest if possible
        if [[ -n "$raw_base_url" ]] && [[ -n "$package_file" ]]; then
            local remote_manifest_url="${raw_base_url}/${package_tag}/$(basename "$package_file")"
            local remote_manifest_file="/tmp/remote_manifest_${package}_$$.swift"
            
            log_step "Fetching remote manifest from $remote_manifest_url"
            if curl -s -f "$remote_manifest_url" > "$remote_manifest_file" 2>/dev/null; then
                log_success "Fetched remote manifest for $package"
                
                # Basic validation: check if remote manifest is parseable
                if ! swift package dump-package --package-path "$(dirname "$remote_manifest_file")" >/dev/null 2>&1; then
                    manifest_warnings+=("Remote manifest may not be parseable: $package")
                fi
            else
                log_warn "Could not fetch remote manifest (tag may not exist yet): $package"
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
            elif [[ ${#manifest_errors[@]} -gt 0 ]] && [[ "$release_tier" != "production" ]]; then
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
        log_error "SPM manifest validation failed with ${#manifest_errors[@]} error(s):"
        for error in "${manifest_errors[@]}"; do
            log_error "  - $error"
        done
        
        if [[ "$release_tier" == "production" ]]; then
            log_error "[MSP][ORCH] Production release: SPM manifest errors are not allowed"
            exit 1
        else
            log_warn "[MSP][ORCH] Preflight release: SPM manifest errors are non-blocking"
        fi
    fi
    
    if [[ ${#manifest_warnings[@]} -gt 0 ]]; then
        log_warn "SPM manifest validation warnings (${#manifest_warnings[@]}):"
        for warning in "${manifest_warnings[@]}"; do
            log_warn "  - $warning"
        done
    fi
    
    if [[ ${#manifest_errors[@]} -eq 0 ]]; then
        log_success "SPM manifest validation passed"
    fi
    
    # Skip individual start notifications - only send final success/failure
    
    # spm_packages_array is already initialized in Phase 4 (SPM Manifest validation)
    # Reuse the same array for consistency
    if [[ ${#spm_packages_array[@]} -eq 0 ]]; then
        log_warn "spm_packages_array is empty. Re-initializing from SPM_PACKAGES."
        # Convert SPM_PACKAGES space-separated string to array
        spm_packages_array=()
        if [[ -n "${SPM_PACKAGES:-}" ]]; then
            for package in $SPM_PACKAGES; do
                spm_packages_array+=("$package")
            done
        fi
        
        if [[ ${#spm_packages_array[@]} -eq 0 ]]; then
            log_warn "SPM_PACKAGES is empty. Using default package list for backward compatibility."
            spm_packages_array=("NovaCore" "NovaAdapter")
        fi
    fi
    
    log_info "Releasing SPM packages from SPM_PACKAGES: ${spm_packages_array[*]}"
    
    # Track release statistics
    local total_packages=${#spm_packages_array[@]}
    local successful_packages=0
    local failed_packages=0
    local failed_package_names=()
    local successful_package_names=()
    
    # Release each SPM package in order
    for package in "${spm_packages_array[@]}"; do
        if release_spm_package "$package" "$VERSION"; then
            ((successful_packages++))
            successful_package_names+=("$package")
        else
            ((failed_packages++))
            failed_package_names+=("$package")
            if [[ "$DRY_RUN" != "true" ]]; then
                notify_release_failure "SPM" "$VERSION" "$package release failed" "Package Release"
            fi
            msp_state_mark_step_failed "spm_publish" "$package release failed" "1"
            exit 1
        fi
    done
    
    # Run local SPM build validation (before publish)
    log_step "Running local SPM build validation"
    if ! spm_local_validation; then
        log_error "Local SPM validation failed — aborting SPM release"
        if [[ "$DRY_RUN" != "true" ]]; then
            notify_release_failure "SPM" "$VERSION" "Local SPM build validation failed" "Local Validation"
        fi
        msp_state_mark_step_failed "spm_publish" "SPM publish failed due to local validation failure" "1"
        return 1
    fi
    
    # Push all tags
    if push_spm_tags; then
        log_success "All SPM tags pushed successfully"
    else
        if [[ "$DRY_RUN" != "true" ]]; then
            notify_release_failure "SPM" "$VERSION" "Failed to push SPM tags" "Tag Push"
        fi
        msp_state_mark_step_failed "spm_publish" "Failed to push SPM tags" "1"
        exit 1
    fi
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local duration_formatted=$(printf "%02d:%02d:%02d" $((duration/3600)) $((duration%3600/60)) $((duration%60)))
    
    print_section "SPM Release Process Completed Successfully"
    log_success "All SPM packages released successfully for version: $VERSION"
    log_info "SPM packages available at:"
    for package in "${successful_package_names[@]}"; do
        log_info "  $package: https://github.com/ParticleMedia/msp-ios-sdk-public.git (tag: ${package}-${VERSION})"
    done
    
    # Send single comprehensive success notification (skip in dry-run mode)
    if [[ "$DRY_RUN" != "true" ]]; then
        local spm_packages_list=$(IFS=", "; echo "${successful_package_names[*]}")
        notify_release_success_with_summary "SPM" "$VERSION" "$spm_packages_list" "$duration_formatted" "$RELEASE_NOTES" "$total_packages" "$successful_packages" "$failed_packages" "$RELEASE_BRANCH"
    fi
    
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

# Run main function with all arguments
main "$@"

# ============================================================================
# SPM Tag Publishing with Tier Awareness (Patch M)
# ============================================================================
spm_publish_tags() {
    local version="$1"
    
    # If version is not provided, try to extract from Package.swift
    if [[ -z "$version" ]]; then
        local package_swift="$ROOT_DIR/Package.swift"
        if [[ -f "$package_swift" ]]; then
            log_info "[SPM] Extracting version from Package.swift"
            # Extract version from Package.swift: let version = "0.3.0-rc.5"
            version=$(grep -E '^\s*let\s+version\s*=\s*"' "$package_swift" | head -1 | sed -E 's/.*let\s+version\s*=\s*"([^"]+)".*/\1/' || echo "")
            if [[ -z "$version" ]]; then
                log_error "[SPM] spm_publish_tags: Could not extract version from Package.swift"
                return 1
            fi
            log_info "[SPM] Extracted version from Package.swift: $version"
        else
            log_error "[SPM] spm_publish_tags: version is required and Package.swift not found"
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
        log_info "[SPM] [CONFIG] Skipping tag & remote publish (config: spm.enabled=false, version: $version)"
        return 0
    fi
    
    # Real release tier behavior - check config (Patch M+CONFIG)
    if ! should_real_publish; then
        local branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
        log_error "[SPM][BLOCKED] Real tag & remote publish not allowed on branch: $branch"
        log_error "[SPM][BLOCKED] Check Scripts/release/config/release_config.yaml for branch policy"
        return 1
    fi
    
    # Real release tier behavior
    log_info "[SPM] Creating and pushing tags for $version"
    
    # Get SPM packages list (from environment or default)
    local spm_packages_list="${SPM_PACKAGES:-NovaCore NovaAdapter}"
    
    # Create tags for each SPM package
    for package in $spm_packages_list; do
        local tag_name="${package}-${version}"
        
        log_step "Creating git tag for SPM package: $tag_name"
        
        # Check if tag already exists locally
        if git tag -l | grep -q "^${tag_name}$"; then
            log_warning "Tag $tag_name already exists locally, deleting..."
            if git tag -d "$tag_name" 2>/dev/null; then
                log_info "Deleted local tag: $tag_name"
            else
                log_warning "Failed to delete local tag: $tag_name (may not exist)"
            fi
        fi
        
        # Check if tag exists on remote
        if git ls-remote --tags origin 2>/dev/null | grep -q "refs/tags/${tag_name}$"; then
            log_warning "Tag $tag_name already exists on remote, deleting..."
            if git push origin ":refs/tags/${tag_name}" 2>/dev/null; then
                log_info "Deleted remote tag: $tag_name"
            else
                log_warning "Failed to delete remote tag: $tag_name (may not exist or no permission)"
            fi
        fi
        
        # Create tag
        if git tag "$tag_name"; then
            log_success "Created tag: $tag_name"
        else
            log_error "Failed to create tag: $tag_name"
            return 1
        fi
    done
    
    # Push tags to remote
    log_step "Pushing tags to remote"
    if git push origin --tags; then
        log_success "Pushed tags to remote"
    else
        log_error "Failed to push tags to remote"
        return 1
    fi
    
}
