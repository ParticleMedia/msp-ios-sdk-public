#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/lib/release-common.sh
source "$ROOT_DIR/Scripts/lib/release-common.sh"

# ============================================================================
# Pods Remote Verification
# ============================================================================
verify_pods_remote() {
    local version="$1"
    
    if [[ -z "$version" ]]; then
        log_error "Version is required for Pods remote verification"
        return 1
    fi
    
    log_section "CocoaPods Remote Verification"
    
    # DRY_RUN shortcut
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Skipping Pods remote verification"
        log_info "Would verify: pod 'MSPCore', '~> $version'"
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
    
    # Generate minimal SwiftUI TestApp
    log_step "Generating minimal TestApp"
    
    # Create main.swift (SwiftUI minimal app)
    cat > "$testapp_dir/main.swift" << 'SWIFT_EOF'
import SwiftUI

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
SWIFT_EOF
    
    # Create Podfile
    log_step "Generating Podfile"
    
    cat > "$testapp_dir/Podfile" << EOF
platform :ios, '15.0'
use_frameworks!

target 'TestApp' do
  pod 'MSPCore', '~> $version'
  pod 'NovaAdapter', '~> $version'
  pod 'MSPGoogleAdapter', '~> $version'
  pod 'MSPFacebookAdapter', '~> $version'
end
EOF
    
    log_info "Podfile created with version constraint: ~> $version"
    
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
    if ! pod install --silent 2>&1; then
        log_error "pod install failed"
        log_info "This may indicate:"
        log_info "  - Version $version is not yet available in CocoaPods trunk"
        log_info "  - Network connectivity issues"
        log_info "  - Podspec validation errors"
        return 1
    fi
    
    log_success "Pods installed successfully"
    
    # Verify workspace exists
    if [[ ! -f "$testapp_dir/TestApp.xcworkspace/contents.xcworkspacedata" ]]; then
        log_error "Workspace file not found after pod install"
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
# SPM Remote Verification (Placeholder)
# ============================================================================
verify_spm_remote() {
    local version="$1"
    
    log_section "SPM Remote Verification (TODO)"
    
    log_info "SPM verification is not implemented yet. Skipping."
    log_info "Will be implemented in Phase 3 Step 2."
    
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
    
    # 2: Verify SPM release (PLACEHOLDER ONLY)
    if ! verify_spm_remote "$version"; then
        log_warn "SPM verification returned non-zero (placeholder - ignoring)"
    fi
    
    log_success "Remote verification complete!"
    return 0
}

# Export functions
export -f verify_pods_remote verify_spm_remote verify_main

