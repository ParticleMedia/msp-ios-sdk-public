#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

# ============================================================================
# Ensure XCFrameworks for Binary Distribution Adapters
# ============================================================================
# Automatically detects and builds missing XCFrameworks for binary distribution
# adapters to ensure script-level guarantees (no manual intervention required).
#
# Design Principles:
# - DRY: Single source of truth for XCFramework validation
# - SRP: Focused on ensuring XCFrameworks exist, not on publishing
# - Reusable: Can be called from msp-release.sh, generate_podspec.sh, etc.
#
# Applies to: MSPPrebidAdapter, MSPGoogleAdapter, MSPFacebookAdapter, AmazonAdapter
# Does NOT apply to:
# - NovaAdapter: Uses pre-packaged Binary/NovaCore.xcframework
# - Core pods (MSPiOSCore, MSPSharedLibraries, MSPCore): Require pre-built XCFrameworks
# ============================================================================

set -e
set -o pipefail

# ============================================================================
# Environment Setup
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"

if [[ -z "$ROOT_DIR" ]]; then
    echo "[ERROR] Not in a git repository"
    exit 1
fi

export ROOT_DIR

# Load logging utilities
if [[ -f "$ROOT_DIR/Scripts/release/utils/logger.sh" ]]; then
    # shellcheck source=Scripts/release/utils/logger.sh
    source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true
fi

# Ensure all log functions exist (fallback if logger.sh doesn't provide them)
if ! command -v log_info &>/dev/null; then
    log_info() { echo "[INFO] $*"; }
fi
if ! command -v log_error &>/dev/null; then
    log_error() { echo "[ERROR] $*" >&2; }
fi
if ! command -v log_warning &>/dev/null; then
    log_warning() { echo "[WARN] $*"; }
fi
if ! command -v log_success &>/dev/null; then
    log_success() { echo "[SUCCESS] $*"; }
fi
if ! command -v log_debug &>/dev/null; then
    log_debug() { [[ "${VERBOSE:-false}" == "true" ]] && echo "[DEBUG] $*" || true; }
fi

# ============================================================================
# Configuration
# ============================================================================
# Binary distribution adapters that require auto-buildable XCFrameworks
# Must be kept in sync with BINARY_DISTRIBUTION_PODS in generate_podspec.sh
BINARY_ADAPTERS=("MSPPrebidAdapter" "MSPGoogleAdapter" "MSPFacebookAdapter" "AmazonAdapter")

# Build script path
BUILD_SCRIPT="$ROOT_DIR/Scripts/xcframeworks/build_module.sh"

# Build log directory
BUILD_LOG_DIR="/tmp/msp-xcframework-builds"
mkdir -p "$BUILD_LOG_DIR"

# ============================================================================
# Functions
# ============================================================================

# Check if XCFramework exists for a given adapter
check_xcframework_exists() {
    local adapter="$1"
    local xcframework_path="$ROOT_DIR/Build/XCFrameworks/${adapter}.xcframework"

    if [[ -d "$xcframework_path" ]]; then
        return 0  # Exists
    else
        return 1  # Missing
    fi
}

# Build XCFramework for a given adapter
build_xcframework() {
    local adapter="$1"
    local log_file="$BUILD_LOG_DIR/${adapter}-$(date +%Y%m%d-%H%M%S).log"

    log_info "Building XCFramework: $adapter"
    log_info "Build log: $log_file"

    if [[ ! -x "$BUILD_SCRIPT" ]]; then
        log_error "Build script not found or not executable: $BUILD_SCRIPT"
        return 1
    fi

    # Run build with full output
    if "$BUILD_SCRIPT" "$adapter" 2>&1 | tee "$log_file"; then
        # Verify build result
        if check_xcframework_exists "$adapter"; then
            local size
            size=$(du -sh "$ROOT_DIR/Build/XCFrameworks/${adapter}.xcframework" 2>/dev/null | cut -f1)
            log_success "✅ Built XCFramework: $adapter (size: $size)"
            return 0
        else
            log_error "Build reported success but XCFramework not found"
            log_error "Check build log: $log_file"
            return 1
        fi
    else
        log_error "❌ Failed to build XCFramework: $adapter"
        log_error "Check build log: $log_file"
        return 1
    fi
}

# Ensure all binary distribution adapters have XCFrameworks
ensure_all_xcframeworks() {
    local missing_count=0
    local built_count=0
    local failed_count=0
    local missing_adapters=()

    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "🔧 Ensuring XCFrameworks for Binary Adapters"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Step 1: Detect missing XCFrameworks
    for adapter in "${BINARY_ADAPTERS[@]}"; do
        if check_xcframework_exists "$adapter"; then
            log_debug "✓ $adapter: XCFramework exists"
        else
            log_warning "✗ $adapter: XCFramework missing"
            missing_adapters+=("$adapter")
            missing_count=$((missing_count + 1))
        fi
    done

    # Step 2: Build missing XCFrameworks
    if [[ $missing_count -eq 0 ]]; then
        log_success "✅ All XCFrameworks exist (${#BINARY_ADAPTERS[@]}/${#BINARY_ADAPTERS[@]})"
        return 0
    fi

    log_info "Found $missing_count missing XCFramework(s), building..."
    echo ""

    for adapter in "${missing_adapters[@]}"; do
        if build_xcframework "$adapter"; then
            built_count=$((built_count + 1))
        else
            failed_count=$((failed_count + 1))
        fi
        echo ""
    done

    # Step 3: Report results
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "📊 Build Summary"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Total adapters:   ${#BINARY_ADAPTERS[@]}"
    log_info "Already existed:  $((${#BINARY_ADAPTERS[@]} - missing_count))"
    log_info "Missing:          $missing_count"
    log_info "Built:            $built_count"
    log_info "Failed:           $failed_count"

    if [[ $failed_count -gt 0 ]]; then
        log_error "❌ Failed to build $failed_count XCFramework(s)"
        log_error "Check build logs in: $BUILD_LOG_DIR"
        return 1
    else
        log_success "✅ All XCFrameworks ready (${#BINARY_ADAPTERS[@]}/${#BINARY_ADAPTERS[@]})"
        return 0
    fi
}

# ============================================================================
# Main
# ============================================================================
main() {
    # Parse arguments
    local mode="${1:-ensure}"  # Default mode: ensure

    case "$mode" in
        ensure|--ensure)
            ensure_all_xcframeworks
            ;;
        check|--check)
            # Check-only mode (no build)
            log_info "Checking XCFrameworks (check-only mode)..."
            local missing_count=0
            for adapter in "${BINARY_ADAPTERS[@]}"; do
                if check_xcframework_exists "$adapter"; then
                    log_debug "✓ $adapter: XCFramework exists"
                else
                    log_warning "✗ $adapter: XCFramework missing"
                    missing_count=$((missing_count + 1))
                fi
            done

            if [[ $missing_count -gt 0 ]]; then
                log_error "❌ $missing_count XCFramework(s) missing"
                exit 1
            else
                log_success "✅ All XCFrameworks exist"
                exit 0
            fi
            ;;
        help|--help|-h)
            cat <<EOF
Usage: $0 [MODE]

Ensure XCFrameworks for binary distribution adapters.

Modes:
  ensure    Auto-detect and build missing XCFrameworks (default)
  check     Check-only mode (no build, exit 1 if missing)
  help      Show this help message

Examples:
  $0                 # Ensure all XCFrameworks (auto-build if missing)
  $0 ensure          # Same as above
  $0 check           # Check only (fail if missing)

Applies to:
  - MSPPrebidAdapter
  - MSPGoogleAdapter
  - MSPFacebookAdapter
  - AmazonAdapter

Does NOT apply to:
  - NovaAdapter: Uses pre-packaged Binary/
  - Core pods: Require pre-built XCFrameworks

Build logs:
  $BUILD_LOG_DIR/

Design:
  - DRY: Single source of truth for XCFramework validation
  - SRP: Focused on ensuring XCFrameworks, not on publishing
  - Reusable: Can be called from any script
EOF
            exit 0
            ;;
        *)
            log_error "Unknown mode: $mode"
            log_error "Use --help for usage information"
            exit 1
            ;;
    esac
}

# Run main if script is executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
