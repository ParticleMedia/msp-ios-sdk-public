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
# Applies to: MSPPrebidAdapter, MSPGoogleAdapter, MSPFacebookAdapter, MSPAmazonAdapter, MSPMolocoAdapter, MSPLiftoffAdapter, NovaAdapter
# Note: NovaAdapter also includes pre-packaged NovaCore.xcframework (third-party dependency)
# Does NOT apply to:
# - Core pods (MSPiOSCore, MSPSharedLibraries, MSPCore): Require pre-built XCFrameworks
# ============================================================================

set -euo pipefail

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
# Force reload by unsetting the guard variable (ensures functions are available in this subprocess)
unset MSP_LOGGER_LOADED
if [[ -f "$ROOT_DIR/Scripts/release/utils/logger.sh" ]]; then
    # shellcheck source=Scripts/release/utils/logger.sh
    source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true
fi

# R027d: Source shared XCFramework validation module
if [[ -f "$ROOT_DIR/Scripts/lib/shared/xcframework_validate.sh" ]]; then
    # shellcheck source=Scripts/lib/shared/xcframework_validate.sh
    source "$ROOT_DIR/Scripts/lib/shared/xcframework_validate.sh" 2>/dev/null || true
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
BINARY_ADAPTERS=("MSPPrebidAdapter" "MSPGoogleAdapter" "MSPFacebookAdapter" "MSPAmazonAdapter" "MSPMolocoAdapter" "MSPLiftoffAdapter" "MSPNovaAdapter")

# Build script path
BUILD_SCRIPT="$ROOT_DIR/Scripts/xcframeworks/build_module.sh"

# Build log directory
BUILD_LOG_DIR="/tmp/msp-xcframework-builds"
mkdir -p "$BUILD_LOG_DIR"

# ============================================================================
# Mapping Functions: Pod Name → Directory Name
# ============================================================================
# Some adapters have different pod names vs directory names
# Example: MSPAmazonAdapter (pod) → AmazonAdapter (directory)
# Note: XCFramework name now matches pod name (MSPAmazonAdapter.xcframework)

get_module_dir() {
    local pod_name="$1"
    case "$pod_name" in
        "MSPAmazonAdapter") echo "AmazonAdapter" ;;
        "MSPMolocoAdapter") echo "MolocoAdapter" ;;
        "MSPLiftoffAdapter") echo "LiftoffAdapter" ;;
        "MSPNovaAdapter") echo "NovaAdapter" ;;
        *) echo "$pod_name" ;;
    esac
}

# ============================================================================
# Functions
# ============================================================================

check_xcframework_exists() {
    local adapter="$1"
    # XCFramework name matches pod name (unified naming)
    local xcframework_path="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks/${adapter}.xcframework"

    if [[ -d "$xcframework_path" ]]; then
        return 0  # Exists
    else
        return 1  # Missing
    fi
}

build_xcframework() {
    local adapter="$1"
    local log_file="$BUILD_LOG_DIR/${adapter}-$(date +%Y%m%d-%H%M%S).log"

    local module_dir=$(get_module_dir "$adapter")

    log::info "XCFW" "Building XCFramework: $adapter (module directory: $module_dir)"
    log::info "XCFW" "Build log: $log_file"

    if [[ ! -x "$BUILD_SCRIPT" ]]; then
        log::error "XCFW" "Build script not found or not executable: $BUILD_SCRIPT"
        return 1
    fi

    if "$BUILD_SCRIPT" "$module_dir" 2>&1 | tee "$log_file"; then
        if check_xcframework_exists "$adapter"; then
            local size
            size=$(du -sh "$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks/${adapter}.xcframework" 2>/dev/null | cut -f1)
            log::success "XCFW" "✅ Built XCFramework: $adapter (${adapter}.xcframework, size: $size)"
            return 0
        else
            log::error "XCFW" "Build reported success but XCFramework not found"
            log::error "XCFW" "Check build log: $log_file"
            return 1
        fi
    else
        log::error "XCFW" "❌ Failed to build XCFramework: $adapter"
        log::error "XCFW" "Check build log: $log_file"
        return 1
    fi
}

ensure_all_xcframeworks() {
    local missing_count=0
    local built_count=0
    local failed_count=0
    local missing_adapters=()

    log::info "XCFW" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "XCFW" "🔧 Ensuring XCFrameworks for Binary Adapters"
    log::info "XCFW" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # =========================================================================
    # CRITICAL FIX: Ensure Foundation Layer XCFrameworks exist first
    # =========================================================================
    # Why: Binary adapters depend on Foundation Layer XCFrameworks. If these
    # are missing, adapter builds will fail with "XCFramework not found" errors.
    #
    # Foundation Layer includes:
    #   - MSPiOSCore.xcframework (required by all adapters)
    #   - MSPGoogleAdsTypes.xcframework (required by MSPGoogleAdapter, MSPAmazonAdapter)
    #   - PrebidMobile.xcframework (third-party, required by most adapters)
    #
    # Note: We only check existence here, not build. Foundation Layer XCFrameworks
    # should be pre-built by the main release flow (pre_release_setup in modular.sh).
    #
    # IMPORTANT: In release tier, Foundation Layer is built AFTER Preflight runs.
    # Execution order:
    #   1. Preflight (this function) - checks Foundation Layer
    #   2. pre_release_setup() in modular.sh - builds Foundation Layer
    #   3. Adapters build - uses Foundation Layer
    #
    # Therefore, in release tier, we allow Foundation Layer to be missing during
    # Preflight (it will be built in pre_release_setup). In preflight tier, we
    # strictly require Foundation Layer to exist (standalone preflight mode).
    # =========================================================================

    log::info "XCFW" "Step 0: Checking Foundation Layer XCFrameworks..."

    local foundation_missing=false
    local foundation_xcframeworks=("MSPiOSCore" "MSPGoogleAdsTypes" "MSPSharedLibraries")
    # Phase B Step 5: Use DRY_RUN instead of MSP_RELEASE_TIER
    local dry_run="${DRY_RUN:-true}"

    for foundation_pod in "${foundation_xcframeworks[@]}"; do
        local foundation_path="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks/${foundation_pod}.xcframework"

        if [[ -d "$foundation_path" ]]; then
            log::debug "XCFW" "✓ ${foundation_pod}: XCFramework exists"
        else
            log::warn "XCFW" "✗ ${foundation_pod}: XCFramework missing"
            log::warn "XCFW" "   Path: $foundation_path"
            foundation_missing=true
        fi
    done

    # Check PrebidMobile (third-party, may be pre-packaged)
    local prebid_path="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks/PrebidMobile.xcframework"
    if [[ -d "$prebid_path" ]]; then
        log::debug "XCFW" "✓ PrebidMobile: XCFramework exists"
    else
        log::warn "XCFW" "✗ PrebidMobile: XCFramework missing"
        log::warn "XCFW" "   Expected path: $prebid_path"
        foundation_missing=true
    fi

    if [[ "$foundation_missing" == "true" ]]; then
        # Phase B Step 5: In production mode, Foundation Layer will be built in pre_release_setup()
        # Allow missing Foundation Layer during Preflight in production mode
        if [[ "$dry_run" == "false" ]]; then
            log::info "XCFW" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log::info "XCFW" "ℹ️  Foundation Layer XCFrameworks missing (expected in release tier)"
            log::info "XCFW" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log::info "XCFW" ""
            log::info "XCFW" "Production mode detected: Foundation Layer will be built in pre_release_setup()"
            log::info "XCFW" "This is expected behavior - Preflight runs before pre_release_setup()."
            log::info "XCFW" ""
            log::info "XCFW" "Missing XCFrameworks (will be built shortly):"
            for foundation_pod in "${foundation_xcframeworks[@]}"; do
                local foundation_path="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks/${foundation_pod}.xcframework"
                if [[ ! -d "$foundation_path" ]]; then
                    log::info "XCFW" "  - $foundation_pod"
                fi
            done
            if [[ ! -d "$prebid_path" ]]; then
                log::info "XCFW" "  - PrebidMobile"
            fi
            log::info "XCFW" ""
            log::info "XCFW" "Continuing Preflight - Foundation Layer will be built in next step"
            log::info "XCFW" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log::info "XCFW" ""
        else
            # Preflight tier: Strictly require Foundation Layer
            log::error "XCFW" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log::error "XCFW" "❌ CRITICAL: Foundation Layer XCFrameworks missing"
            log::error "XCFW" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log::error "XCFW" ""
            log::error "XCFW" "Binary adapters depend on Foundation Layer XCFrameworks."
            log::error "XCFW" "These must be built before adapters can be built."
            log::error "XCFW" ""
            log::error "XCFW" "Missing XCFrameworks:"
            for foundation_pod in "${foundation_xcframeworks[@]}"; do
                local foundation_path="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks/${foundation_pod}.xcframework"
                if [[ ! -d "$foundation_path" ]]; then
                    log::error "XCFW" "  - $foundation_pod"
                fi
            done
            if [[ ! -d "$prebid_path" ]]; then
                log::error "XCFW" "  - PrebidMobile"
            fi
            log::error "XCFW" ""
            log::error "XCFW" "Solution:"
            log::error "XCFW" "  Foundation Layer XCFrameworks must be built before Preflight."
            log::error "XCFW" "  Build them first:"
            log::error "XCFW" ""
            log::error "XCFW" "  # Build MSPiOSCore"
            log::error "XCFW" "  ./Scripts/xcframeworks/build_module.sh MSPiOSCore"
            log::error "XCFW" ""
            log::error "XCFW" "  # Build MSPGoogleAdsTypes"
            log::error "XCFW" "  ./Scripts/xcframeworks/build_module.sh MSPGoogleAdsTypes"
            log::error "XCFW" ""
            log::error "XCFW" "  # PrebidMobile (third-party)"
            log::error "XCFW" "  ./Scripts/xcframeworks/build-thirdparty.sh"
            log::error "XCFW" ""
            log::error "XCFW" "  Then re-run Preflight:"
            log::error "XCFW" "  ./Scripts/msp-release.sh preflight"
            log::error "XCFW" ""
            log::error "XCFW" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            return 1
        fi
    else
        log::success "XCFW" "✅ Foundation Layer XCFrameworks are ready"
        log::info "XCFW" ""
    fi

    # =========================================================================
    # Original logic: Check and build Adapters
    # =========================================================================

    # Phase B Step 5: CRITICAL: In production mode, if Foundation Layer is missing, skip Adapters
    # building. Foundation Layer will be built in pre_release_setup(), and
    # Adapters will be built later in the release flow.
    if [[ "$foundation_missing" == "true" ]] && [[ "$dry_run" == "false" ]]; then
        log::info "XCFW" "Step 1: Skipping Binary Adapters check (Foundation Layer will be built first)"
        log::info "XCFW" ""
        log::info "XCFW" "In production mode, Foundation Layer is built in pre_release_setup()."
        log::info "XCFW" "Adapters will be built after Foundation Layer is ready."
        log::info "XCFW" ""
        log::success "XCFW" "✅ Preflight check passed (Foundation Layer will be built in next step)"
        return 0
    fi

    log::info "XCFW" "Step 1: Checking Binary Adapters..."

    # Step 1: Detect missing XCFrameworks
    for adapter in "${BINARY_ADAPTERS[@]}"; do
        if check_xcframework_exists "$adapter"; then
            log::debug "XCFW" "✓ $adapter: XCFramework exists"
        else
            log::warn "XCFW" "✗ $adapter: XCFramework missing"
            missing_adapters+=("$adapter")
            missing_count=$((missing_count + 1))
        fi
    done

    # Step 2: Build missing XCFrameworks
    if [[ $missing_count -eq 0 ]]; then
        log::success "XCFW" "✅ All XCFrameworks exist (${#BINARY_ADAPTERS[@]}/${#BINARY_ADAPTERS[@]})"
        return 0
    fi

    log::info "XCFW" "Found $missing_count missing XCFramework(s), building..."
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
    log::info "XCFW" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "XCFW" "📊 Build Summary"
    log::info "XCFW" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::info "XCFW" "Total adapters:   ${#BINARY_ADAPTERS[@]}"
    log::info "XCFW" "Already existed:  $((${#BINARY_ADAPTERS[@]} - missing_count))"
    log::info "XCFW" "Missing:          $missing_count"
    log::info "XCFW" "Built:            $built_count"
    log::info "XCFW" "Failed:           $failed_count"

    if [[ $failed_count -gt 0 ]]; then
        log::error "XCFW" "❌ Failed to build $failed_count XCFramework(s)"
        log::error "XCFW" "Check build logs in: $BUILD_LOG_DIR"
        return 1
    else
        log::success "XCFW" "✅ All XCFrameworks ready (${#BINARY_ADAPTERS[@]}/${#BINARY_ADAPTERS[@]})"
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
            log::info "XCFW" "Checking XCFrameworks (check-only mode)..."
            local missing_count=0
            for adapter in "${BINARY_ADAPTERS[@]}"; do
                if check_xcframework_exists "$adapter"; then
                    log::debug "XCFW" "✓ $adapter: XCFramework exists"
                else
                    log::warn "XCFW" "✗ $adapter: XCFramework missing"
                    missing_count=$((missing_count + 1))
                fi
            done

            if [[ $missing_count -gt 0 ]]; then
                log::error "XCFW" "❌ $missing_count XCFramework(s) missing"
                exit 1
            else
                log::success "XCFW" "✅ All XCFrameworks exist"
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
  - MSPAmazonAdapter
  - MSPMolocoAdapter
  - MSPLiftoffAdapter
  - MSPNovaAdapter

Does NOT apply to:
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
            log::error "XCFW" "Unknown mode: $mode"
            log::error "XCFW" "Use --help for usage information"
            exit 1
            ;;
    esac
}

# Run main if script is executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
