#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch K, shared) ---
# shellcheck source=/dev/null
if command -v git >/dev/null 2>&1; then
  MSP_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$MSP_REPO_ROOT" ] && [ -f "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh" ]; then
    # shellcheck source=/dev/null
    . "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh"
    msp_enforce_main_repo_or_exit
  fi
fi
# --- End MSP Worktree Safety Guard (Patch K, shared) ---

# Asset Synchronization Script for NovaCore
# This script synchronizes assets from NBAssets.xcassets to NBResourceBundle.bundle
# to prevent production bugs caused by out-of-sync assets. Only files under
# NovaCore/NovaCore/Resources are treated as the single source of truth; anything
# manually placed inside NBResourceBundle.bundle will be overwritten on each run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly PROJECT_ROOT
# Try new structure first (Sources/Core/), fallback to old structure
if [[ -d "$PROJECT_ROOT/Sources/Core/NovaCore/NovaCore" ]]; then
    readonly NOVACORE_DIR="$PROJECT_ROOT/Sources/Core/NovaCore/NovaCore"
elif [[ -d "$PROJECT_ROOT/NovaCore/NovaCore" ]]; then
    readonly NOVACORE_DIR="$PROJECT_ROOT/NovaCore/NovaCore"
else
    echo "ERROR: NovaCore directory not found" >&2
    echo "Checked locations:" >&2
    echo "  - $PROJECT_ROOT/Sources/Core/NovaCore/NovaCore" >&2
    echo "  - $PROJECT_ROOT/NovaCore/NovaCore" >&2
    exit 1
fi
readonly ASSETS_SOURCE="$NOVACORE_DIR/NBAssets.xcassets"
readonly BUNDLE_TARGET="$NOVACORE_DIR/NBResourceBundle.bundle"
readonly TEMP_DIR="/tmp/nova_asset_sync_$$"

ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly ROOT_DIR
# shellcheck source=Scripts/lib/common.sh
source "$ROOT_DIR/Scripts/lib/common.sh" 2>/dev/null || true

# Color output functions (use unified logging if available, fallback to simple functions)
if command -v log::info &>/dev/null; then
    print_info() { log::info "SYNC" "$1"; }
    print_success() { log::success "SYNC" "$1"; }
    print_warning() { log::warn "SYNC" "$1"; }
    print_error() { log::error "SYNC" "$1"; }
else
    print_info() { echo "[INFO] $1"; }
    print_success() { echo "[SUCCESS] $1"; }
    print_warning() { echo "[WARNING] $1"; }
    print_error() { echo "[ERROR] $1" >&2; }
fi

cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

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

extract_asset_names() {
    local asset_names=()
    
    # Find all .imageset directories
    while IFS= read -r -d '' imageset_dir; do
        local asset_name=$(basename "$imageset_dir" .imageset)
        asset_names+=("$asset_name")
    done < <(find "$ASSETS_SOURCE" -name "*.imageset" -type d -print0)
    
    printf '%s\n' "${asset_names[@]}" | sort
}

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

# Mirror arbitrary resource directories into bundle, skipping unwanted files
copy_resource_tree() {
    local output_dir="$TEMP_DIR/NBResourceBundle.bundle"
    local resource_root="$NOVACORE_DIR/Resources"

    print_info "Copying supplemental resources..."

    if [[ ! -d "$resource_root" ]]; then
        print_warning "Resource directory not found: $resource_root"
        return
    fi

    # rsync-style path filtering using find while avoiding Swift code and editor cruft
    local copied=false
    while IFS= read -r -d '' source_path; do
        local rel_path="${source_path#$resource_root/}"
        local dest_path="$output_dir/$rel_path"

        mkdir -p "$(dirname "$dest_path")"
        cp "$source_path" "$dest_path"
        copied=true
    done < <(find "$resource_root" -type f \
        ! -name "*.swift" \
        ! -name "*.DS_Store" \
        ! -name "*.xcassets" \
        -print0)

    if [[ "$copied" == true ]]; then
        print_success "Copied supplemental resources into bundle"

        print_info "Bundle resource files:"
        find "$output_dir" -type f \
            ! -name "Assets.car" \
            -print | while read -r file; do
                local relative_path="${file#$output_dir/}"
                local size=$(stat -f%z "$file" 2>/dev/null || echo "0")
                print_info "  - $relative_path ($size bytes)"
            done
    else
        print_warning "No supplemental resources copied"
    fi
}

update_target_bundle() {
    local temp_bundle="$TEMP_DIR/NBResourceBundle.bundle"
    
    print_info "Updating target bundle..."
    
    # Remove old bundle and replace with new one (no backup needed for automated sync)
    rm -rf "$BUNDLE_TARGET"
    cp -R "$temp_bundle" "$BUNDLE_TARGET"
    
    print_success "Target bundle updated successfully"
}

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

main() {
    print_info "Starting asset synchronization..."
    print_info "Project root: $PROJECT_ROOT"
    
    # Change to project root for relative path consistency
    cd "$PROJECT_ROOT"

    check_dependencies
    validate_paths
    create_temp_bundle
    compile_assets
    verify_compiled_assets
    copy_resource_tree
    update_target_bundle
    generate_asset_report
    
    print_success "Asset synchronization completed successfully!"
    print_info "Assets from NBAssets.xcassets have been synchronized to NBResourceBundle.bundle"
}

main
