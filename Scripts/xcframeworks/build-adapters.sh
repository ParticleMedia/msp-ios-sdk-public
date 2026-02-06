#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# XCFramework Builder for Adapter Modules (OPTIONAL)
# ============================================================================
# Purpose: Build adapter modules into XCFrameworks (for testing only)
#
# IMPORTANT: Adapters are SOURCE-ONLY in all modes (pods-dev, pods-release, spm-release)
#            This script is optional and MUST NOT block any pipeline.
#            All failures are warnings, not errors.
#
# Usage:   ./Scripts/xcframeworks/build-adapters.sh
# ============================================================================

# Note: We use `set -o pipefail` but NOT `set -e` to ensure failures don't exit
set -o pipefail

# Source common functions
XCFRAMEWORKS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$XCFRAMEWORKS_SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/target-switching/common.sh
source "$XCFRAMEWORKS_SCRIPT_DIR/../target-switching/common.sh"

ensure_repo_root

BUILD_MODULE_SCRIPT="$XCFRAMEWORKS_SCRIPT_DIR/build_module.sh"
if [[ ! -f "$BUILD_MODULE_SCRIPT" ]]; then
    log_error "build_module.sh not found: $BUILD_MODULE_SCRIPT"
    exit 1
fi

log_title "Building Adapter Modules"

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
# Generate project.yml from templates (Template Architecture)
# ============================================================================
log_section "Generating project.yml from templates"

if [[ -x "$ROOT_DIR/Scripts/target-switching/generate_project_templates.sh" ]]; then
    "$ROOT_DIR/Scripts/target-switching/generate_project_templates.sh"
else
    log_warn "generate_project_templates.sh not found or not executable"
fi

# All adapter modules (including MSPGoogleAdsTypes which is a Common module)
# Note: These are POD NAMES, not directory names
ADAPTER_MODULES=(
    "MSPGoogleAdsTypes"
    "MSPNovaAdapter"
    "MSPPrebidAdapter"
    "MSPGoogleAdapter"
    "MSPFacebookAdapter"
    "InmobiAdapter"
    "MintegralAdapter"
    "MobilefuseAdapter"
    "PubmaticAdapter"
    "UnityAdapter"
    "MSPAmazonAdapter"
    "MSPLiftoffAdapter"
    "MSPMolocoAdapter"
)

# Core XCFrameworks that adapters depend on
CORE_XCFRAMEWORKS=(
    "MSPiOSCore"
    "NovaCore"
    "MSPSharedLibraries"
)

# Check core XCFrameworks exist (optional - adapters may work without them in source mode)
log_section "Checking core XCFrameworks (optional for adapter builds)"
CORE_MISSING=0
for framework in "${CORE_XCFRAMEWORKS[@]}"; do
    XCFRAMEWORK_PATH="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks/$framework.xcframework"
    if [[ ! -d "$XCFRAMEWORK_PATH" ]]; then
        log_warn "Core XCFramework not found: $XCFRAMEWORK_PATH (adapter builds may fail)"
        ((CORE_MISSING++)) || true
    else
        log_success "Found: $framework.xcframework"
    fi
done

if [[ $CORE_MISSING -gt 0 ]]; then
    log_warn "$CORE_MISSING core XCFramework(s) missing - adapter builds may fail"
    log_info "To build core modules: ./Scripts/xcframeworks/build-core.sh"
fi

# Third-party dependencies (Kingfisher, MSPSnapKit, etc.) are resolved via CocoaPods
# No need to check for XCFrameworks - the workspace build will find them in Pods/
log_info "Third-party dependencies will be resolved via CocoaPods workspace"

SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_MODULES=()

for pod_name in "${ADAPTER_MODULES[@]}"; do
    log_section "Building $pod_name"

    # Map pod name to directory name (for build_module.sh)
    module_dir=$(get_module_dir "$pod_name")

    # XCFramework name now matches pod name (unified naming)
    # For Round 3, force rebuild all adapters to use new build system
    # Remove existing XCFramework to ensure fresh build with new pipeline
    XCFRAMEWORK_OUTPUT="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks/$pod_name.xcframework"
    if [[ -d "$XCFRAMEWORK_OUTPUT" ]]; then
        log_info "Removing existing $pod_name.xcframework for fresh rebuild..."
        rm -rf "$XCFRAMEWORK_OUTPUT"
    fi

    # build_module.sh expects directory name, not pod name
    if "$BUILD_MODULE_SCRIPT" "$module_dir"; then
        ((SUCCESS_COUNT++)) || true
        log_success "$pod_name: BUILD SUCCEEDED"
    else
        ((FAIL_COUNT++)) || true
        FAILED_MODULES+=("$pod_name")
        log_error "$pod_name: BUILD FAILED"
    fi
done

log_title "Adapter Modules Build Complete"

# NOTE: Adapters are SOURCE-ONLY in the final architecture.
# This script is for optional testing/validation only.
# Failures are warnings, not errors.

if [[ $SUCCESS_COUNT -gt 0 ]]; then
    log_success "Successfully built $SUCCESS_COUNT adapter(s)"
fi

if [[ $FAIL_COUNT -gt 0 ]]; then
    log_warn "WARNING: $FAIL_COUNT adapter(s) failed to build: ${FAILED_MODULES[*]}"
    log_warn "This is expected - adapters are source-only and don't require XCFrameworks."
    log_warn "Continuing without blocking the pipeline."
fi

# Copy all adapter XCFrameworks to ReleaseArtifacts/Binary directory
log_section "Copying Adapter XCFrameworks to ReleaseArtifacts/Binary"
# BINARY_DIR is already defined in common.sh as readonly
mkdir -p "$BINARY_DIR"

for pod_name in "${ADAPTER_MODULES[@]}"; do
    # XCFramework name matches pod name (unified naming)
    XCFRAMEWORK_SRC="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks/$pod_name.xcframework"
    XCFRAMEWORK_DST="$BINARY_DIR/$pod_name.xcframework"

    if [[ -d "$XCFRAMEWORK_SRC" ]]; then
        rm -rf "$XCFRAMEWORK_DST"
        cp -R "$XCFRAMEWORK_SRC" "$XCFRAMEWORK_DST"
        log_success "Copied $pod_name.xcframework to ReleaseArtifacts/Binary"
    else
        log_warn "Not found: $XCFRAMEWORK_SRC"
    fi
done

log_section "Final Summary"
log_info "ReleaseArtifacts/Binary contents:"
ls -1 "$BINARY_DIR" 2>/dev/null | while read -r xcf; do
    log_success "  ✓ $xcf"
done || true

log_info ""
log_info "NOTE: Adapter XCFrameworks are OPTIONAL."
log_info "The pods-dev, pods-release, and spm-release modes all use adapters as SOURCE code."
log_info ""

# Always exit 0 - adapter builds are optional
exit 0
