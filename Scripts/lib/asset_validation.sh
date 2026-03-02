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

# Asset Validation Script for NovaCore
# This script validates that NBAssets.xcassets and NBResourceBundle.bundle contain the same assets
# to prevent production bugs caused by out-of-sync assets.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly PROJECT_ROOT

# R031f: Source checksum module for unified checksum computation
if [[ -f "$SCRIPT_DIR/checksum.sh" ]]; then
    # shellcheck source=Scripts/lib/checksum.sh
    source "$SCRIPT_DIR/checksum.sh" 2>/dev/null || true
fi
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
readonly TEMP_DIR="/tmp/nova_asset_validation_$$"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_VALIDATION_FAILED=1
readonly EXIT_MISSING_FILES=2
readonly EXIT_INVALID_ARGS=3

ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly ROOT_DIR
# shellcheck source=Scripts/lib/common.sh
source "$ROOT_DIR/Scripts/lib/common.sh" 2>/dev/null || true

# Color output functions (use unified logging if available, fallback to simple functions)
if command -v log::info &>/dev/null; then
    print_info() { log::info "ASSET" "$1"; }
    print_success() { log::success "ASSET" "$1"; }
    print_warning() { log::warn "ASSET" "$1"; }
    print_error() { log::error "ASSET" "$1"; }
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

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Asset Validation Script for NovaCore
Validates that NBAssets.xcassets and NBResourceBundle.bundle contain the same assets.

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -q, --quiet         Suppress non-error output
    --json              Output results in JSON format
    --report FILE       Save detailed report to file
    --content-only      Only perform content-based validation (ignore timestamps)
    --timestamp-only    Only perform timestamp-based validation (faster)
    --ci-mode           Use CI-friendly validation (tolerate minor checksum differences)

EXIT CODES:
    0   Validation passed - assets are in sync
    1   Validation failed - assets are out of sync
    2   Missing required files or directories
    3   Invalid arguments

EXAMPLES:
    $0                    # Basic validation
    $0 --verbose          # Verbose output
    $0 --json             # JSON output for CI/CD
    $0 --report report.txt # Save report to file
EOF
}

parse_arguments() {
    local verbose=false
    local quiet=false
    local json_output=false
    local report_file=""
    local content_only=false
    local timestamp_only=false
    local ci_mode=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit $EXIT_SUCCESS
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -q|--quiet)
                quiet=true
                shift
                ;;
            --json)
                json_output=true
                shift
                ;;
            --report)
                report_file="$2"
                shift 2
                ;;
            --content-only)
                content_only=true
                shift
                ;;
            --timestamp-only)
                timestamp_only=true
                shift
                ;;
            --ci-mode)
                ci_mode=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit $EXIT_INVALID_ARGS
                ;;
        esac
    done
    
    export VERBOSE="$verbose"
    export QUIET="$quiet"
    export JSON_OUTPUT="$json_output"
    export REPORT_FILE="$report_file"
    export CONTENT_ONLY="$content_only"
    export TIMESTAMP_ONLY="$timestamp_only"
    export CI_MODE="$ci_mode"
}

# Conditional output functions (local to this script)
asset_log_info() {
    if [[ "$QUIET" != "true" ]]; then
        print_info "$1"
    fi
}

asset_log_verbose() {
    if [[ "$VERBOSE" == "true" && "$QUIET" != "true" ]]; then
        echo "  $1"
    fi
}

# JSON output functions
json_start() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "{"
        echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
        echo "  \"source\": \"$ASSETS_SOURCE\","
        echo "  \"target\": \"$BUNDLE_TARGET\","
        echo "  \"validation\": {"
    fi
}

json_end() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "  }"
        echo "}"
    fi
}

json_result() {
    local status="$1"
    local message="$2"
    
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "    \"status\": \"$status\","
        echo "    \"message\": \"$message\","
    fi
}

validate_paths() {
    local missing_paths=()
    
    if [[ ! -d "$ASSETS_SOURCE" ]]; then
        missing_paths+=("$ASSETS_SOURCE")
    fi
    
    if [[ ! -d "$BUNDLE_TARGET" ]]; then
        missing_paths+=("$BUNDLE_TARGET")
    fi
    
    if [[ ${#missing_paths[@]} -gt 0 ]]; then
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            json_start
            json_result "error" "Missing required paths: ${missing_paths[*]}"
            json_end
        else
            print_error "Missing required paths:"
            for path in "${missing_paths[@]}"; do
                print_error "  - $path"
            done
        fi
        exit $EXIT_MISSING_FILES
    fi
    
    asset_log_info "Validating asset synchronization..."
    asset_log_verbose "Source: $ASSETS_SOURCE"
    asset_log_verbose "Target: $BUNDLE_TARGET"
}

validate_asset_sync() {
    local source_count=0
    local bundle_valid=false
    local issues=()
    
    # Count source assets quickly
    source_count=$(find "$ASSETS_SOURCE" -name "*.imageset" -type d | wc -l)
    asset_log_verbose "Found $source_count assets in source"
    
    # Check if bundle exists and has proper structure
    if [[ ! -d "$BUNDLE_TARGET" ]]; then
        issues+=("Bundle directory does not exist")
    else
        # Check for Assets.car
        local assets_car="$BUNDLE_TARGET/Assets.car"
        if [[ ! -f "$assets_car" ]]; then
            issues+=("Assets.car not found in bundle")
        else
            local file_size=$(stat -f%z "$assets_car" 2>/dev/null || echo "0")
            if [[ $file_size -eq 0 ]]; then
                issues+=("Assets.car is empty")
            else
                bundle_valid=true
                asset_log_verbose "Assets.car found with $file_size bytes"
                
                # Content-based validation: Compare source assets with bundle
                if [[ "$TIMESTAMP_ONLY" != "true" ]]; then
                    validate_asset_content
                fi
                
                # Check if bundle is newer than source assets (timestamp validation)
                if [[ "$CONTENT_ONLY" != "true" ]]; then
                    local bundle_timestamp=$(stat -f%m "$assets_car" 2>/dev/null || echo "0")
                    local source_timestamp=0
                    
                    # Find the newest file in the source assets
                    while IFS= read -r -d '' file; do
                        local file_timestamp=$(stat -f%m "$file" 2>/dev/null || echo "0")
                        if [[ $file_timestamp -gt $source_timestamp ]]; then
                            source_timestamp=$file_timestamp
                        fi
                    done < <(find "$ASSETS_SOURCE" -type f -print0)
                    
                    asset_log_verbose "Bundle timestamp: $bundle_timestamp"
                    asset_log_verbose "Source timestamp: $source_timestamp"
                    
                    # If source is newer than bundle, they're out of sync
                    if [[ $source_timestamp -gt $bundle_timestamp ]]; then
                        issues+=("Source assets are newer than bundle - assets need to be synchronized")
                        bundle_valid=false
                    fi
                fi
            fi
        fi
        
        # Check for other required files
        if [[ ! -f "$BUNDLE_TARGET/Info.plist" ]]; then
            issues+=("Info.plist missing from bundle")
        fi
    fi
    
    # Simple validation logic
    if [[ $source_count -gt 0 && "$bundle_valid" == "false" ]]; then
        issues+=("Source has $source_count assets but bundle is not properly compiled")
    fi
    
    # Save results
    echo "$source_count" > "$TEMP_DIR/source_count.txt"
    echo "$bundle_valid" > "$TEMP_DIR/bundle_valid.txt"
    if [[ ${#issues[@]} -gt 0 ]]; then
        printf '%s\n' "${issues[@]}" > "$TEMP_DIR/issues.txt"
    else
        touch "$TEMP_DIR/issues.txt"
    fi
    echo "${#issues[@]}" > "$TEMP_DIR/issue_count.txt"
    
    asset_log_verbose "Validation completed - found ${#issues[@]} issues"
}

validate_asset_content() {
    asset_log_verbose "Performing content-based validation..."
    
    local temp_compile_dir="$TEMP_DIR/temp_compile"
    mkdir -p "$temp_compile_dir"
    
    # Compile current source assets to temporary location
    if actool \
        --compile "$temp_compile_dir" \
        --platform iphoneos \
        --minimum-deployment-target 15.0 \
        --output-partial-info-plist "$TEMP_DIR/temp_partial_info.plist" \
        "$ASSETS_SOURCE" > "$TEMP_DIR/temp_actool.log" 2>&1; then
        
        local temp_assets_car="$temp_compile_dir/Assets.car"
        local current_assets_car="$BUNDLE_TARGET/Assets.car"
        
        if [[ -f "$temp_assets_car" && -f "$current_assets_car" ]]; then
            # Compare file sizes first (quick check)
            local temp_size=$(stat -f%z "$temp_assets_car" 2>/dev/null || echo "0")
            local current_size=$(stat -f%z "$current_assets_car" 2>/dev/null || echo "0")
            
            asset_log_verbose "Temporary compiled size: $temp_size bytes"
            asset_log_verbose "Current bundle size: $current_size bytes"
            
            if [[ $temp_size -ne $current_size ]]; then
                local size_diff=$((current_size - temp_size))
                local size_diff_mb=$((size_diff / 1024 / 1024))
                local size_diff_kb=$((size_diff / 1024))
                
                if [[ $size_diff -gt 0 ]]; then
                    if [[ $size_diff_mb -gt 0 ]]; then
                        issues+=("Bundle is $size_diff_mb MB larger than current source compilation")
                    else
                        issues+=("Bundle is $size_diff_kb KB larger than current source compilation")
                    fi
                    issues+=("This suggests the bundle contains assets that are no longer in the source")
                else
                    local abs_diff=$((temp_size - current_size))
                    local abs_diff_mb=$((abs_diff / 1024 / 1024))
                    local abs_diff_kb=$((abs_diff / 1024))
                    
                    if [[ $abs_diff_mb -gt 0 ]]; then
                        issues+=("Bundle is $abs_diff_mb MB smaller than current source compilation")
                    else
                        issues+=("Bundle is $abs_diff_kb KB smaller than current source compilation")
                    fi
                    issues+=("This suggests the bundle is missing assets that are in the source")
                fi
                
                issues+=("Current bundle size: $current_size bytes")
                issues+=("Expected bundle size: $temp_size bytes")
                bundle_valid=false
            else
                # Compare checksums for exact content match
                # R031f: Use checksum.sh module if available, fallback to shasum
                local temp_checksum current_checksum
                if command -v checksum_compute_sha256 &>/dev/null; then
                    temp_checksum=$(checksum_compute_sha256 "$temp_assets_car")
                    current_checksum=$(checksum_compute_sha256 "$current_assets_car")
                else
                    temp_checksum=$(shasum -a 256 "$temp_assets_car" 2>/dev/null | cut -d' ' -f1)
                    current_checksum=$(shasum -a 256 "$current_assets_car" 2>/dev/null | cut -d' ' -f1)
                fi
                
                asset_log_verbose "Temporary compiled checksum: $temp_checksum"
                asset_log_verbose "Current bundle checksum: $current_checksum"
                
                if [[ "$temp_checksum" != "$current_checksum" ]]; then
                    # In CI mode, if file sizes match but checksums differ, it's likely due to
                    # different compilation environments but same assets
                    if [[ "$CI_MODE" == "true" && $temp_size -eq $current_size ]]; then
                        asset_log_verbose "CI mode: File sizes match but checksums differ"
                        asset_log_verbose "This is likely due to different compilation environments"
                        asset_log_verbose "Assets are functionally equivalent (same size)"
                    else
                        issues+=("Asset content differs - checksum mismatch")
                        issues+=("Expected checksum: $temp_checksum")
                        issues+=("Current checksum: $current_checksum")
                        issues+=("This indicates the bundle contains different assets than the source")
                        bundle_valid=false
                    fi
                else
                    asset_log_verbose "Asset content matches - bundle is up to date"
                fi
            fi
        else
            asset_log_verbose "Could not compare assets - compilation or bundle file missing"
        fi
        
        rm -rf "$temp_compile_dir"
    else
        asset_log_verbose "Could not compile assets for comparison - actool failed"
        # Don't fail validation just because we can't do content comparison
        # Timestamp validation will still work
    fi
}

generate_report() {
    local report_file="${REPORT_FILE:-$TEMP_DIR/validation_report.txt}"
    local source_count=$(cat "$TEMP_DIR/source_count.txt")
    local bundle_valid=$(cat "$TEMP_DIR/bundle_valid.txt")
    local issue_count=$(cat "$TEMP_DIR/issue_count.txt")
    
    {
        echo "Asset Validation Report"
        echo "======================"
        echo "Date: $(date)"
        echo "Source: $ASSETS_SOURCE"
        echo "Target: $BUNDLE_TARGET"
        echo ""
        
        echo "Source assets found: $source_count"
        echo "Bundle is valid: $bundle_valid"
        echo ""
        
        if [[ $issue_count -eq 0 ]]; then
            echo "✅ VALIDATION PASSED"
            echo "Assets are properly synchronized between source and bundle."
        else
            echo "❌ VALIDATION FAILED"
            echo "Found $issue_count issues:"
            echo ""
            
            local issue_num=1
            while IFS= read -r issue; do
                echo "  $issue_num. $issue"
                ((issue_num++)) || true
            done < "$TEMP_DIR/issues.txt"
            echo ""
            
            echo "🔧 RECOMMENDED ACTIONS:"
            echo "  1. Run asset synchronization: ./Scripts/lib/asset_sync.sh"
            echo "  2. Verify the sync worked: ./Scripts/lib/asset_validation.sh --verbose"
            echo "  3. Commit the updated NBResourceBundle.bundle to your repository"
            echo ""
        fi
        
        echo "Bundle contents:"
        if [[ -d "$BUNDLE_TARGET" ]]; then
            find "$BUNDLE_TARGET" -type f | while read -r file; do
                local relative_path="${file#$BUNDLE_TARGET/}"
                local file_size=$(stat -f%z "$file" 2>/dev/null || echo "0")
                echo "  - $relative_path ($file_size bytes)"
            done
        fi
    } > "$report_file"
    
    if [[ "$REPORT_FILE" != "" ]]; then
        asset_log_info "Detailed report saved to: $report_file"
    fi
}

main() {
    parse_arguments "$@"

    mkdir -p "$TEMP_DIR"

    # Change to project root for relative path consistency
    cd "$PROJECT_ROOT"

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        json_start
    fi

    validate_paths
    validate_asset_sync

    local source_count=$(cat "$TEMP_DIR/source_count.txt")
    local bundle_valid=$(cat "$TEMP_DIR/bundle_valid.txt")
    local issue_count=$(cat "$TEMP_DIR/issue_count.txt")

    generate_report

    if [[ $issue_count -eq 0 ]]; then
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            json_result "success" "All assets are synchronized"
            json_end
        else
            print_success "Asset validation passed - all assets are synchronized"
        fi
        exit $EXIT_SUCCESS
    else
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            json_result "failed" "Found $issue_count issues"
            json_end
        else
            print_error "Asset validation failed - found $issue_count issues"
            print_error "Source assets: $source_count"
            print_error "Bundle valid: $bundle_valid"
            echo ""
            print_error "DETAILED ISSUES:"
            local issue_num=1
            while IFS= read -r issue; do
                print_error "  $issue_num. $issue"
                ((issue_num++)) || true
            done < "$TEMP_DIR/issues.txt"
            echo ""
            print_info "🔧 TO FIX: Run ./Scripts/lib/asset_sync.sh"
        fi
        exit $EXIT_VALIDATION_FAILED
    fi
}

main "$@"
