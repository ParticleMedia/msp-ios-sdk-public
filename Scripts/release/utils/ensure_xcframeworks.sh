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

# Create aliases for logger.sh functions (namespace style: log::*)
# Fallback to simple echo if logger.sh not loaded
if command -v log::info &>/dev/null; then
    log_info() { log::info "$@"; }
    log_error() { log::error "$@"; }
    log_warning() { log::warn "$@"; }
    log_success() { log::success "$@"; }
    log_debug() { log::debug "$@"; }
else
    # Fallback functions if logger.sh not available
    log_info() { echo "[INFO] $*"; }
    log_error() { echo "[ERROR] $*" >&2; }
    log_warning() { echo "[WARN] $*"; }
    log_success() { echo "[SUCCESS] $*"; }
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

    # =========================================================================
    # CRITICAL FIX: Ensure Foundation Layer XCFrameworks exist first
    # =========================================================================
    # Why: Binary adapters depend on Foundation Layer XCFrameworks. If these
    # are missing, adapter builds will fail with "XCFramework not found" errors.
    #
    # Foundation Layer includes:
    #   - MSPiOSCore.xcframework (required by all adapters)
    #   - MSPGoogleAdsTypes.xcframework (required by MSPGoogleAdapter, AmazonAdapter)
    #   - PrebidMobile.xcframework (third-party, required by most adapters)
    #
    # Note: We only check existence here, not build. Foundation Layer XCFrameworks
    # should be pre-built by the main release flow (publish.sh). This check ensures
    # Preflight doesn't fail due to missing Foundation dependencies.
    # =========================================================================

    log_info "Step 0: Checking Foundation Layer XCFrameworks..."

    local foundation_missing=false
    local foundation_xcframeworks=("MSPiOSCore" "MSPGoogleAdsTypes")

    for foundation_pod in "${foundation_xcframeworks[@]}"; do
        local foundation_path="$ROOT_DIR/Build/XCFrameworks/${foundation_pod}.xcframework"

        if [[ -d "$foundation_path" ]]; then
            log_debug "✓ ${foundation_pod}: XCFramework exists"
        else
            log_warning "✗ ${foundation_pod}: XCFramework missing"
            log_warning "   Path: $foundation_path"
            foundation_missing=true
        fi
    done

    # Check PrebidMobile (third-party, may be pre-packaged)
    local prebid_path="$ROOT_DIR/Build/XCFrameworks/PrebidMobile.xcframework"
    local prebid_alt_path="$ROOT_DIR/ThirdParty/PrebidMobile/PrebidMobile.xcframework"
    if [[ ! -d "$prebid_path" ]]; then
        # Try alternative path (ThirdParty)
        if [[ -d "$prebid_alt_path" ]]; then
            log_debug "✓ PrebidMobile: Found in ThirdParty directory"
        else
            log_warning "✗ PrebidMobile: XCFramework missing"
            log_warning "   Primary path: $prebid_path"
            log_warning "   Alternative path: $prebid_alt_path"
            foundation_missing=true
        fi
    else
        log_debug "✓ PrebidMobile: XCFramework exists"
    fi

    if [[ "$foundation_missing" == "true" ]]; then
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error "❌ CRITICAL: Foundation Layer XCFrameworks missing"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error ""
        log_error "Binary adapters depend on Foundation Layer XCFrameworks."
        log_error "These must be built before adapters can be built."
        log_error ""
        log_error "Missing XCFrameworks:"
        for foundation_pod in "${foundation_xcframeworks[@]}"; do
            local foundation_path="$ROOT_DIR/Build/XCFrameworks/${foundation_pod}.xcframework"
            if [[ ! -d "$foundation_path" ]]; then
                log_error "  - $foundation_pod"
            fi
        done
        if [[ ! -d "$prebid_path" ]] && [[ ! -d "$prebid_alt_path" ]]; then
            log_error "  - PrebidMobile"
        fi
        log_error ""
        log_error "Solution:"
        log_error "  Foundation Layer XCFrameworks are built during the main release flow."
        log_error "  If you're running Preflight standalone, build them first:"
        log_error ""
        log_error "  # Build MSPiOSCore"
        log_error "  ./Scripts/xcframeworks/build_module.sh MSPiOSCore"
        log_error ""
        log_error "  # Build MSPGoogleAdsTypes"
        log_error "  ./Scripts/xcframeworks/build_module.sh MSPGoogleAdsTypes"
        log_error ""
        log_error "  # PrebidMobile (third-party, usually pre-packaged)"
        log_error "  # Check: ThirdParty/PrebidMobile/PrebidMobile.xcframework"
        log_error ""
        log_error "  Then re-run Preflight:"
        log_error "  ./Scripts/msp-release.sh preflight"
        log_error ""
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    fi

    log_success "✅ Foundation Layer XCFrameworks are ready"
    log_info ""

    # =========================================================================
    # Original logic: Check and build Adapters
    # =========================================================================

    log_info "Step 1: Checking Binary Adapters..."

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
