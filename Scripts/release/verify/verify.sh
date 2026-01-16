#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ========================================
# Unified ROOT_DIR resolution (final)
# ========================================
# The root dir is always the directory that contains
# the parent Scripts/ folder where msp-release.sh lives.
if [[ -z "${ROOT_DIR:-}" ]]; then
    # Find Scripts/ directory by going up until we find it, then go up one more level
    ROOT_DIR="$SCRIPT_DIR"
    while [[ "$ROOT_DIR" != "/" ]] && [[ "${ROOT_DIR##*/}" != "Scripts" ]]; do
        ROOT_DIR="$(dirname "$ROOT_DIR")"
    done
    # If we found Scripts/, go up one more level to get repo root
    if [[ "${ROOT_DIR##*/}" == "Scripts" ]]; then
        ROOT_DIR="$(dirname "$ROOT_DIR")"
    fi
fi
export ROOT_DIR

# shellcheck source=Scripts/lib/release-common.sh
source "$ROOT_DIR/Scripts/lib/release-common.sh"

# Load release state utilities
source "$SCRIPT_DIR/../utils/state.sh"

if [[ "${MSP_DISABLE_POST_VERIFICATION:-0}" == "1" ]] || [[ "${MSP_DISABLE_POST_VERIFICATION:-false}" == "true" ]]; then
    log_warn "Verification disabled (MSP_DISABLE_POST_VERIFICATION=1) — skipping verify.sh"
    exit 0
fi

# ============================================================================
# Pods Remote Verification
# ============================================================================
verify_pods_remote() {
    local version="$1"
    
    if [[ -z "$version" ]]; then
        log_error "Version is required for Pods remote verification"
        return 1
    fi
    
    # Check if we should skip this step in resume mode
    if [[ "${MSP_RESUME_MODE:-0}" == "1" ]]; then
        local status
        status="$(msp_state_get_step_status "pods_remote_verify" 2>/dev/null || echo "unknown")"
        if [[ "$status" == "success" || "$status" == "skipped" ]]; then
            log_info "Resuming: skipping pods_remote_verify (status already ${status})"
            return 0
        fi
    fi
    
    msp_state_mark_step_running "pods_remote_verify"
    
    log_section "CocoaPods Remote Verification"
    
    # DRY_RUN shortcut
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Skipping Pods remote verification"
        log_info "Would verify: pod 'MSPCore', '~> $version'"
        msp_state_mark_step_skipped "pods_remote_verify" "Pods remote verify skipped due to DRY_RUN"
        return 0
    fi
    
    # Create isolated temp directory
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local verify_dir="/tmp/msp-verify/$timestamp"
    local testapp_dir="$verify_dir/TestApp"
    
    log_step "Creating isolated test environment"
    log_info "Temp directory: $verify_dir"
    
    mkdir -p "$testapp_dir"
    cd "$testapp_dir" || {
        log_error "Failed to create test directory"
        msp_state_mark_step_failed "pods_remote_verify" "Failed to create test directory" "1"
        return 1
    }
    
    # Cleanup function
    local cleanup_on_exit=true
    if [[ "${DEBUG:-false}" == "true" ]] || [[ "${VERBOSE:-false}" == "true" ]]; then
        cleanup_on_exit=false
        log_info "DEBUG/VERBOSE mode: keeping test directory at $verify_dir"
    fi
    
    cleanup_verify_dir() {
        if [[ "$cleanup_on_exit" == "true" ]]; then
            log_step "Cleaning up test directory"
            rm -rf "$verify_dir" 2>/dev/null || true
        fi
    }
    
    trap cleanup_verify_dir EXIT
    
    # Configuration: Read from environment with defaults
    local pods_remote_url="${PODS_REMOTE_URL:-}"
    local pods_primary_product="${PODS_REMOTE_PRIMARY_PRODUCT:-MSPCore}"
    
    # Check if PODS_REMOTE_URL is set
    if [[ -z "$pods_remote_url" ]]; then
        log_warn "PODS_REMOTE_URL is not set. Skipping Pods remote verification."
        log_info "To enable Pods verification, set PODS_REMOTE_URL environment variable."
        msp_state_mark_step_skipped "pods_remote_verify" "Pods remote verify skipped due to PODS_REMOTE_URL not set"
        return 0
    fi
    
    log_info "Using remote URL: $pods_remote_url"
    log_info "Primary product: $pods_primary_product"
    log_info "Version: $version"
    
    # Generate minimal SwiftUI TestApp
    log_step "Generating minimal TestApp"
    
    # Create main.swift (SwiftUI minimal app) with dynamic import
    cat > "$testapp_dir/main.swift" << EOF
import SwiftUI
import ${pods_primary_product}

@main
struct TestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            Text("MSP Verification Test")
                .font(.title)
            Text("If you see this, the app built successfully.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
EOF
    
    # Create Podfile
    log_step "Generating Podfile"
    
    cat > "$testapp_dir/Podfile" << EOF
source '$pods_remote_url'
source 'https://cdn.cocoapods.org/'

platform :ios, '15.0'
use_frameworks!

target 'TestApp' do
  pod '${pods_primary_product}', '~> $version'
end
EOF
    
    log_info "Podfile created with version constraint: ~> $version"
    log_info "Podfile uses remote source: $pods_remote_url"
    
    # Update pod repo
    log_step "Updating CocoaPods repository"
    if ! pod repo update 2>&1 | grep -v "Updating spec repo" | grep -v "^$" || true; then
        log_warn "pod repo update had warnings (continuing)"
    fi
    
    # Check if version is available remotely
    log_step "Checking if version $version is available remotely"
    if ! pod search MSPCore --simple 2>/dev/null | grep -q "$version"; then
        log_warn "Version $version may not be available in pod search (this is normal for very recent releases)"
        log_info "Attempting pod install anyway..."
    fi
    
    # Run pod install
    log_step "Installing pods from remote trunk"
    local install_exit_code=0
    if ! pod install --silent 2>&1; then
        install_exit_code=$?
        log_error "pod install failed"
        log_info "This may indicate:"
        log_info "  - Version $version is not yet available in CocoaPods trunk"
        log_info "  - Network connectivity issues"
        log_info "  - Podspec validation errors"
        msp_state_mark_step_failed "pods_remote_verify" "pod install failed" "$install_exit_code"
        return 1
    fi
    
    log_success "Pods installed successfully"
    
    # Verify workspace exists
    if [[ ! -f "$testapp_dir/TestApp.xcworkspace/contents.xcworkspacedata" ]]; then
        log_error "Workspace file not found after pod install"
        msp_state_mark_step_failed "pods_remote_verify" "Workspace file not found after pod install" "1"
        return 1
    fi
    
    log_info "Workspace created: TestApp.xcworkspace"
    
    # Build with xcodebuild
    log_step "Building TestApp with xcodebuild"
    
    local build_output
    local build_exit_code
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Running: xcodebuild -workspace TestApp.xcworkspace -scheme TestApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15'"
        if xcodebuild -workspace TestApp.xcworkspace \
                      -scheme TestApp \
                      -sdk iphonesimulator \
                      -destination 'platform=iOS Simulator,name=iPhone 15' \
                      build 2>&1; then
            build_exit_code=0
        else
            build_exit_code=$?
        fi
    else
        build_output=$(xcodebuild -workspace TestApp.xcworkspace \
                                  -scheme TestApp \
                                  -sdk iphonesimulator \
                                  -destination 'platform=iOS Simulator,name=iPhone 15' \
                                  build 2>&1)
        build_exit_code=$?
    fi
    
    if [[ $build_exit_code -ne 0 ]]; then
        log_error "xcodebuild failed with exit code $build_exit_code"
        if [[ "$VERBOSE" != "true" && -n "$build_output" ]]; then
            log_info "Build output (last 20 lines):"
            echo "$build_output" | tail -20 | sed 's/^/  /'
        fi
        msp_state_mark_step_failed "pods_remote_verify" "xcodebuild failed" "$build_exit_code"
        return 1
    fi
    
    log_success "Build succeeded"
    
    # Validate DerivedData contains MSP libraries
    log_step "Validating installed frameworks"
    
    local derived_data
    derived_data=$(xcodebuild -workspace TestApp.xcworkspace -showBuildSettings 2>/dev/null | grep -m1 "BUILD_DIR" | sed 's/.*= *//' | sed 's/Build\/Products/DerivedData/' || echo "")
    
    if [[ -n "$derived_data" ]]; then
        local framework_path="$derived_data/Build/Products/Debug-iphonesimulator"
        if [[ -d "$framework_path" ]]; then
            local msp_frameworks
            msp_frameworks=$(find "$framework_path" -name "*.framework" -type d 2>/dev/null | grep -i "msp\|nova" | wc -l | tr -d ' ')
            if [[ "$msp_frameworks" -gt 0 ]]; then
                log_info "Found $msp_frameworks MSP-related framework(s) in build products"
            else
                log_warn "No MSP frameworks found in build products (may be normal for static linking)"
            fi
        fi
    fi
    
    # Produce summary
    ui_divider
    log_success "Pods Remote Verification Summary"
    ui_kv "Remote pods available" "YES"
    ui_kv "Build succeeded" "YES"
    ui_kv "Installed version" "$version"
    ui_kv "Test directory" "$verify_dir"
    ui_divider
    
    # Disable cleanup if we got here successfully (for inspection)
    if [[ "${KEEP_VERIFY_ARTIFACTS:-false}" == "true" ]]; then
        cleanup_on_exit=false
        log_info "Artifacts kept at: $verify_dir"
    fi
    
    return 0
}

# ============================================================================
# SPM Remote Verification
# ============================================================================
verify_spm_remote() {
    local version="$1"
    
    if [[ -z "$version" ]]; then
        log_error "Version is required for SPM remote verification"
        return 1
    fi
    
    # Check if we should skip this step in resume mode
    if [[ "${MSP_RESUME_MODE:-0}" == "1" ]]; then
        local status
        status="$(msp_state_get_step_status "spm_remote_verify" 2>/dev/null || echo "unknown")"
        if [[ "$status" == "success" || "$status" == "skipped" ]]; then
            log_info "Resuming: skipping spm_remote_verify (status already ${status})"
            return 0
        fi
    fi
    
    msp_state_mark_step_running "spm_remote_verify"
    
    log_section "SPM Remote Verification"
    
    # DRY_RUN shortcut
    local dry_run_value="${DRY_RUN:-false}"
    if [[ "$dry_run_value" == "true" ]] || [[ "$dry_run_value" == "1" ]] || [[ "$dry_run_value" == "yes" ]]; then
        log_info "[DRY RUN] Skipping SPM remote verification"
        msp_state_mark_step_skipped "spm_remote_verify" "SPM remote verify skipped due to DRY_RUN"
        return 0
    fi
    
    # Configuration: Read from environment with defaults
    local spm_remote_url="${SPM_REMOTE_URL:-}"
    local spm_package_name="${SPM_REMOTE_PACKAGE_NAME:-msp-ios-sdk}"
    local spm_product_name="${SPM_REMOTE_PRODUCT_NAME:-MSPAds}"
    
    # Fallback to default if empty
    if [[ -z "$spm_product_name" ]]; then
        spm_product_name="MSPAds"
    fi
    
    # Check if SPM_REMOTE_URL is set
    if [[ -z "$spm_remote_url" ]]; then
        log_warn "SPM_REMOTE_URL is not set. Skipping SPM remote verification."
        log_info "To enable SPM verification, set SPM_REMOTE_URL environment variable."
        msp_state_mark_step_skipped "spm_remote_verify" "SPM remote verify skipped due to SPM_REMOTE_URL not set"
        return 0
    fi
    
    log_info "Using remote URL: $spm_remote_url"
    log_info "Package name: $spm_package_name"
    log_info "Product name: $spm_product_name"
    log_info "Version: $version"
    
    # Create temp directory
    log_step "Creating temporary SPM test package"
    local temp_dir
    temp_dir=$(mktemp -d -t msp-spm-verify-XXXXXX)
    if [[ ! -d "$temp_dir" ]]; then
        log_error "Failed to create temporary directory"
        return 1
    fi
    
    # Cleanup function
    local cleanup_on_exit=true
    if [[ "${DEBUG:-false}" == "true" ]] || [[ "${VERBOSE:-false}" == "true" ]]; then
        cleanup_on_exit=false
        log_info "DEBUG/VERBOSE mode: keeping test directory at $temp_dir"
    fi
    
    cleanup_temp_dir() {
        if [[ "$cleanup_on_exit" == "true" ]]; then
            log_step "Cleaning up temporary directory"
            rm -rf "$temp_dir" 2>/dev/null || true
        fi
    }
    
    trap cleanup_temp_dir EXIT
    
    cd "$temp_dir" || {
        log_error "Failed to change to temporary directory"
        msp_state_mark_step_failed "spm_remote_verify" "Failed to change to temporary directory" "1"
        return 1
    }
    
    # Create minimal SwiftPM executable package
    log_step "Initializing SwiftPM test package"
    
    if ! swift package init --type executable --name TestSPMApp 2>&1; then
        log_error "Failed to initialize Swift package"
        msp_state_mark_step_failed "spm_remote_verify" "Failed to initialize Swift package" "1"
        return 1
    fi
    
    log_success "Swift package initialized"
    
    # Patch Package.swift to add remote dependency
    log_step "Adding remote SPM dependency to Package.swift"
    
    local package_swift="$temp_dir/Package.swift"
    if [[ ! -f "$package_swift" ]]; then
        log_error "Package.swift not found after initialization"
        msp_state_mark_step_failed "spm_remote_verify" "Package.swift not found after initialization" "1"
        return 1
    fi
    
    # Read existing Package.swift and inject dependency
    local package_content
    package_content=$(cat "$package_swift")
    
    # Create modified Package.swift with remote dependency
    cat > "$package_swift" << EOF
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TestSPMApp",
    dependencies: [
        .package(url: "$spm_remote_url", .exact("$version"))
    ],
    targets: [
        .executableTarget(
            name: "TestSPMApp",
            dependencies: [
                .product(name: "${spm_product_name}", package: "$spm_package_name")
            ]
        )
    ]
)
EOF
    
    log_info "Package.swift updated with remote dependency"
    
    # Update main.swift to use the remote product
    log_step "Updating main.swift to use remote product"
    
    local main_swift="$temp_dir/Sources/TestSPMApp/main.swift"
    if [[ -f "$main_swift" ]]; then
        cat > "$main_swift" << EOF
import Foundation
import ${spm_product_name}
// Import the remote product to verify it's available
// Note: This is a minimal test - actual usage would require proper imports

print("MSP SPM Verification Test")
print("If you see this, the package resolved and built successfully.")
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
        log_info "This may indicate:"
        log_info "  - Version $version is not yet available in the remote repository"
        log_info "  - Network connectivity issues"
        log_info "  - Invalid remote URL: $spm_remote_url"
        
        # Check strict mode
        if [[ "${VERIFY_SPM_STRICT:-true}" == "true" ]]; then
            log_error "SPM remote verification FAILED (strict mode). Blocking release."
            return 1
        else
            log_warn "SPM remote verification failed (soft mode). Continuing."
            return 0
        fi
    fi
    
    log_success "Swift package resolved successfully"
    
    # Run swift build
    log_step "Building Swift package"
    
    local build_output
    local build_exit_code
    
    if [[ "$VERBOSE" == "true" ]]; then
        if swift build 2>&1; then
            build_exit_code=0
        else
            build_exit_code=$?
        fi
    else
        build_output=$(swift build 2>&1)
        build_exit_code=$?
    fi
    
    if [[ $build_exit_code -ne 0 ]]; then
        log_error "swift build failed (exit code: $build_exit_code)"
        if [[ "$VERBOSE" != "true" && -n "$build_output" ]]; then
            log_info "Build output (last 20 lines):"
            echo "$build_output" | tail -20 | sed 's/^/  /'
        fi
        log_info "This may indicate:"
        log_info "  - Build errors in the remote package"
        log_info "  - Incompatible Swift version"
        log_info "  - Missing dependencies"
        
        # Check strict mode
        if [[ "${VERIFY_SPM_STRICT:-true}" == "true" ]]; then
            log_error "SPM remote verification FAILED (strict mode). Blocking release."
            msp_state_mark_step_failed "spm_remote_verify" "swift build failed (strict mode)" "$build_exit_code"
            return 1
        else
            log_warn "SPM remote verification failed (soft mode). Continuing."
            msp_state_mark_step_failed "spm_remote_verify" "swift build failed (soft mode)" "$build_exit_code"
            return 0
        fi
    fi
    
    log_success "Swift package built successfully"
    
    # Produce summary
    ui_divider
    log_success "SPM Remote Verification Summary"
    ui_kv "Remote URL" "$spm_remote_url"
    ui_kv "Version" "$version"
    ui_kv "Package" "$spm_package_name"
    ui_kv "Product" "$spm_product_name"
    ui_kv "Resolved" "YES"
    ui_kv "Built" "YES"
    ui_kv "Test directory" "$temp_dir"
    ui_divider
    
    # Disable cleanup if we got here successfully (for inspection)
    if [[ "${KEEP_VERIFY_ARTIFACTS:-false}" == "true" ]]; then
        cleanup_on_exit=false
        log_info "Artifacts kept at: $temp_dir"
    fi
    
    msp_state_mark_step_success "spm_remote_verify"
    return 0
}

# ============================================================================
# Main Verification Entrypoint
# ============================================================================
verify_main() {
    local version="$1"
    
    if [[ -z "$version" ]]; then
        log_error "Version is required for verification"
        return 1
    fi
    
    log_section "Start Remote Verification"
    ui_kv "Version" "$version"
    echo ""
    
    # 1: Verify CocoaPods release (FULL)
    if ! verify_pods_remote "$version"; then
        log_error "CocoaPods remote verification failed"
        return 1
    fi
    
    echo ""
    
    # 2: Verify SPM release (strict by default, configurable)
    if ! verify_spm_remote "$version"; then
        log_error "SPM remote verification failed"
        return 1
    fi
    
    log_success "Remote verification complete!"
    return 0
}

# Export functions
export -f verify_pods_remote verify_spm_remote verify_main
