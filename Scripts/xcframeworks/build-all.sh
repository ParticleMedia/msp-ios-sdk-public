#!/bin/bash
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
# ============================================================================
# XCFramework Builder for All Modules
# ============================================================================
# Purpose: One-click build for entire SDK
# Usage:   ./Scripts/xcframeworks/build-all.sh
# ============================================================================

set -euo pipefail

# Source common functions
XCFRAMEWORKS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$XCFRAMEWORKS_SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/target-switching/common.sh
source "$XCFRAMEWORKS_SCRIPT_DIR/../target-switching/common.sh"

ensure_repo_root

BUILD_CORE_SCRIPT="$XCFRAMEWORKS_SCRIPT_DIR/build-core.sh"
BUILD_ADAPTERS_SCRIPT="$XCFRAMEWORKS_SCRIPT_DIR/build-adapters.sh"
REPORT_FILE="$ROOT_DIR/build/XCFrameworks/BuildReport.md"

log_title "Building All XCFrameworks"

# Create output directories
mkdir -p "$ROOT_DIR/build/archives"
mkdir -p "$ROOT_DIR/build/XCFrameworks"

START_TIME=$(date +%s)

# Build core modules
log_section "Building Core Modules"
if ! "$BUILD_CORE_SCRIPT"; then
    log_error "Core modules build failed - aborting pipeline"
    exit 1
fi

# Build adapter modules
log_section "Building Adapter Modules"
if ! "$BUILD_ADAPTERS_SCRIPT"; then
    log_error "Adapter modules build failed"
    exit 1
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Generate build report
log_step "Generating build report"
{
    cat <<EOF
# XCFramework Build Report

**Date:** $(date)
**Duration:** ${DURATION} seconds
**Status:** ✅ SUCCESS

---

## Build Summary

### Core Modules
- NovaCore: ✅
- MSPCore: ✅
- MSPOMSDK: ✅
- MSPSharedLibraries: ✅

### Adapter Modules
- NovaAdapter: ✅
- MSPPrebidAdapter: ✅
- MSPGoogleAdapter: ✅
- MSPFacebookAdapter: ✅
- InmobiAdapter: ✅
- MintegralAdapter: ✅
- MobilefuseAdapter: ✅
- PubmaticAdapter: ✅
- UnityAdapter: ✅
- AmazonAdapter: ✅

---

## Output Location

All XCFrameworks are located at:

\`\`\`
build/XCFrameworks/
├── NovaCore.xcframework
├── MSPCore.xcframework
├── MSPOMSDK.xcframework
├── MSPSharedLibraries.xcframework
├── NovaAdapter.xcframework
├── MSPPrebidAdapter.xcframework
├── MSPGoogleAdapter.xcframework
├── MSPFacebookAdapter.xcframework
├── InmobiAdapter.xcframework
├── MintegralAdapter.xcframework
├── MobilefuseAdapter.xcframework
├── PubmaticAdapter.xcframework
├── UnityAdapter.xcframework
└── AmazonAdapter.xcframework
\`\`\`

---

## Verification

Run the following to verify all XCFrameworks exist:

\`\`\`bash
ls -la build/XCFrameworks/*.xcframework
\`\`\`

---

**Build completed successfully**
EOF
} > "$REPORT_FILE"

log_success "Build report generated: $REPORT_FILE"
log_title "All XCFrameworks Build Complete"
log_success "Total build time: ${DURATION} seconds"
