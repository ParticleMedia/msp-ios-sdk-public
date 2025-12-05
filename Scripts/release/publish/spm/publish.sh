#!/bin/bash

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
    if [[ "$current_branch" != "$RELEASE_BRANCH" ]]; then
        log_error "Not on release branch '$RELEASE_BRANCH'. Current branch: '$current_branch'"
        log_info "Please checkout the release branch first:"
        log_info "  git checkout $RELEASE_BRANCH"
        exit 1
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
        # In preflight mode, allow soft-fail
        if [[ "${MSP_RELEASE_TIER:-preflight}" == "production" ]]; then
            return 1
        else
            log_warn "[SPM][WARN] Preflight mode: skipping local validation"
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
    git push origin --tags
    
    log_success "Pushed SPM tags to remote"
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
    
    # Create tag for this package
    create_spm_tag "$package_name" "$version"
    
    log_success "$package_name SPM package released"
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
    
    # Check release branch
    check_release_branch
    
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
    
    # Task 2: Ensure Package.swift exists before SPM operations
    # Package.swift is generated from Package.swift.template and should not be committed
    local repo_package_swift="$ROOT_DIR/Package.swift"
    local package_swift_template="$ROOT_DIR/Package.swift.template"
    local generate_script="$ROOT_DIR/Scripts/spm-sync/generate_package_swift.sh"
    
    if [[ ! -f "$repo_package_swift" ]]; then
        log_step "Package.swift not found, generating from template"
        if [[ -f "$package_swift_template" ]]; then
            # Try to generate from template
            if [[ -x "$generate_script" ]]; then
                log_info "[SPM][INFO] Generating Package.swift using generate_package_swift.sh"
                "$generate_script" || {
                    log_warn "[SPM][WARN] Failed to generate Package.swift, trying template copy"
                    cp "$package_swift_template" "$repo_package_swift" 2>/dev/null || true
                }
            elif [[ -f "$package_swift_template" ]]; then
                log_info "[SPM][INFO] Copying Package.swift from template"
                cp "$package_swift_template" "$repo_package_swift" 2>/dev/null || true
            fi
        fi
        
        if [[ ! -f "$repo_package_swift" ]]; then
            log_error "[SPM][ERROR] Package.swift not found at: $repo_package_swift"
            log_error "[SPM][ERROR] Template not found at: $package_swift_template"
            log_error "[SPM][ERROR] SPM local validation requires Package.swift to be generated first"
            if [[ "${MSP_RELEASE_TIER:-preflight}" == "production" ]]; then
                return 1
            else
                log_warn "[SPM][WARN] Preflight mode: continuing without Package.swift validation"
                return 0
            fi
        else
            log_success "[SPM][INFO] Package.swift found at: $repo_package_swift"
        fi
    else
        log_info "[SPM][INFO] Package.swift found at: $repo_package_swift"
    fi
    
    # Phase 4 TASK 2: SPM Manifest strong validation
    local release_mode="${MSP_RELEASE_MODE:-cli}"
    local release_tier="${MSP_RELEASE_TIER:-preflight}"
    local release_mode_upper=$(echo "$release_mode" | tr '[:lower:]' '[:upper:]' 2>/dev/null || echo "$release_mode" | awk '{print toupper($0)}')
    echo "[MSP][ORCH] Mode: ${release_mode_upper} — validating SPM manifest"
    
    # Check if swift is available
    if ! command -v swift >/dev/null 2>&1; then
        log_error "Swift is not installed. Cannot validate SPM manifest."
        if [[ "$release_tier" == "production" ]]; then
            exit 1
        fi
    fi
    
    # Phase 4: SPM Manifest validation
    log_section "Phase 4: SPM Manifest Validation"
    
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
    
    # Convert SPM_PACKAGES space-separated string to array
    local spm_packages_array=()
    for package in $SPM_PACKAGES; do
        spm_packages_array+=("$package")
    done
    
    if [[ ${#spm_packages_array[@]} -eq 0 ]]; then
        log_warn "SPM_PACKAGES is empty. Using default package list for backward compatibility."
        spm_packages_array=("NovaCore" "NovaAdapter")
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
