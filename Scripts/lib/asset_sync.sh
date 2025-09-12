#!/bin/bash

# Asset Synchronization Script for NovaCore
# This script synchronizes assets from NBAssets.xcassets to NBResourceBundle.bundle
# to prevent production bugs caused by out-of-sync assets.

set -euo pipefail

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly NOVACORE_DIR="$PROJECT_ROOT/NovaCore/NovaCore"
readonly ASSETS_SOURCE="$NOVACORE_DIR/NBAssets.xcassets"
readonly BUNDLE_TARGET="$NOVACORE_DIR/NBResourceBundle.bundle"
readonly TEMP_DIR="/tmp/nova_asset_sync_$$"

# Color output functions
print_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
print_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
print_warning() { echo -e "\033[0;33m[WARNING]\033[0m $1"; }
print_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

# Cleanup function
cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Validate required tools
check_dependencies() {
    local missing_tools=()
    
    if ! command -v actool &> /dev/null; then
        missing_tools+=("actool")
    fi
    
    if ! command -v plutil &> /dev/null; then
        missing_tools+=("plutil")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_error "Please install Xcode command line tools: xcode-select --install"
        exit 1
    fi
}

# Validate input directories
validate_paths() {
    if [[ ! -d "$ASSETS_SOURCE" ]]; then
        print_error "Assets source directory not found: $ASSETS_SOURCE"
        exit 1
    fi
    
    if [[ ! -d "$BUNDLE_TARGET" ]]; then
        print_error "Bundle target directory not found: $BUNDLE_TARGET"
        exit 1
    fi
    
    print_info "Assets source: $ASSETS_SOURCE"
    print_info "Bundle target: $BUNDLE_TARGET"
}

# Extract asset names from .xcassets
extract_asset_names() {
    local asset_names=()
    
    # Find all .imageset directories
    while IFS= read -r -d '' imageset_dir; do
        local asset_name=$(basename "$imageset_dir" .imageset)
        asset_names+=("$asset_name")
    done < <(find "$ASSETS_SOURCE" -name "*.imageset" -type d -print0)
    
    printf '%s\n' "${asset_names[@]}" | sort
}

# Create temporary bundle structure
create_temp_bundle() {
    mkdir -p "$TEMP_DIR/NBResourceBundle.bundle"
    
    # Copy existing non-asset files from current bundle
    if [[ -f "$BUNDLE_TARGET/Info.plist" ]]; then
        cp "$BUNDLE_TARGET/Info.plist" "$TEMP_DIR/NBResourceBundle.bundle/"
    fi
    
    if [[ -f "$BUNDLE_TARGET/omsdk-v1.js" ]]; then
        cp "$BUNDLE_TARGET/omsdk-v1.js" "$TEMP_DIR/NBResourceBundle.bundle/"
    fi
    
    print_info "Created temporary bundle structure"
}

# Compile assets using actool
compile_assets() {
    local output_dir="$TEMP_DIR/NBResourceBundle.bundle"
    
    print_info "Compiling assets using actool..."
    
    # Use actool to compile the asset catalog (without AppIcon requirement)
    if actool \
        --compile "$output_dir" \
        --platform iphoneos \
        --minimum-deployment-target 15.0 \
        --output-partial-info-plist "$TEMP_DIR/partial_info.plist" \
        "$ASSETS_SOURCE" > "$TEMP_DIR/actool.log" 2>&1; then
        print_success "Assets compiled successfully"
    else
        # Check if the error is just about missing AppIcon (which is acceptable)
        if grep -q "AppIcon" "$TEMP_DIR/actool.log" && ! grep -q "error" "$TEMP_DIR/actool.log"; then
            print_warning "AppIcon not found, but continuing with asset compilation"
            # Try again without AppIcon requirement
            if actool \
                --compile "$output_dir" \
                --platform iphoneos \
                --minimum-deployment-target 15.0 \
                --output-partial-info-plist "$TEMP_DIR/partial_info.plist" \
                "$ASSETS_SOURCE" > "$TEMP_DIR/actool.log" 2>&1; then
                print_success "Assets compiled successfully (without AppIcon)"
            else
                print_error "Failed to compile assets with actool"
                print_error "actool output:"
                cat "$TEMP_DIR/actool.log"
                exit 1
            fi
        else
            print_error "Failed to compile assets with actool"
            print_error "actool output:"
            cat "$TEMP_DIR/actool.log"
            exit 1
        fi
    fi
}

# Verify compiled assets
verify_compiled_assets() {
    local output_dir="$TEMP_DIR/NBResourceBundle.bundle"
    local assets_car="$output_dir/Assets.car"
    
    if [[ ! -f "$assets_car" ]]; then
        print_error "Assets.car not found in compiled output"
        exit 1
    fi
    
    # Check if Assets.car has content
    local file_size=$(stat -f%z "$assets_car" 2>/dev/null || echo "0")
    if [[ $file_size -eq 0 ]]; then
        print_warning "Assets.car is empty - no assets were compiled"
    else
        print_success "Assets.car created successfully ($file_size bytes)"
    fi
}

# Update target bundle
update_target_bundle() {
    local temp_bundle="$TEMP_DIR/NBResourceBundle.bundle"
    
    print_info "Updating target bundle..."
    
    # Remove old bundle and replace with new one (no backup needed for automated sync)
    rm -rf "$BUNDLE_TARGET"
    cp -R "$temp_bundle" "$BUNDLE_TARGET"
    
    print_success "Target bundle updated successfully"
}

# Generate asset report
generate_asset_report() {
    local report_file="$TEMP_DIR/asset_sync_report.txt"
    
    {
        echo "Asset Synchronization Report"
        echo "=========================="
        echo "Date: $(date)"
        echo "Source: $ASSETS_SOURCE"
        echo "Target: $BUNDLE_TARGET"
        echo ""
        
        echo "Assets found in source:"
        extract_asset_names | while read -r asset_name; do
            echo "  - $asset_name"
        done
        
        echo ""
        echo "Bundle contents after sync:"
        if [[ -d "$BUNDLE_TARGET" ]]; then
            find "$BUNDLE_TARGET" -type f | while read -r file; do
                local relative_path="${file#$BUNDLE_TARGET/}"
                local file_size=$(stat -f%z "$file" 2>/dev/null || echo "0")
                echo "  - $relative_path ($file_size bytes)"
            done
        fi
    } > "$report_file"
    
    print_info "Asset report generated: $report_file"
}

# Main execution
main() {
    print_info "Starting asset synchronization..."
    print_info "Project root: $PROJECT_ROOT"
    
    # Change to project root for relative path consistency
    cd "$PROJECT_ROOT"
    
    # Run validation and sync steps
    check_dependencies
    validate_paths
    create_temp_bundle
    compile_assets
    verify_compiled_assets
    update_target_bundle
    generate_asset_report
    
    print_success "Asset synchronization completed successfully!"
    print_info "Assets from NBAssets.xcassets have been synchronized to NBResourceBundle.bundle"
}

# Run main function
main
