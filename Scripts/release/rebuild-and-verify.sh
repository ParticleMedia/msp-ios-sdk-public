#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

set -euo pipefail

# ================================================================
#  One-Click Script: Rebuild Core XCFrameworks + Run Preflight Verify
# ================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_DIR="$ROOT_DIR/Logs/xfcore-verify-$TIMESTAMP"

mkdir -p "$LOG_DIR"

echo "======================================================="
echo " MSP Release System — Core Rebuild + Preflight Verify"
echo " Timestamp: $TIMESTAMP"
echo "======================================================="
echo

# --------------------------------------------------------
# Step 1 — Clean previous builds
# --------------------------------------------------------
echo "[1/4] Cleaning Build/ReleaseArtifacts/XCFrameworks ..."
rm -rf Build/ReleaseArtifacts/XCFrameworks
mkdir -p Build/ReleaseArtifacts/XCFrameworks
echo "Done."
echo

# --------------------------------------------------------
# Step 2 — Rebuild core XCFrameworks
# --------------------------------------------------------
echo "[2/4] Building Core XCFrameworks ..."
bash Scripts/xcframeworks/build-core.sh \
    | tee "$LOG_DIR/build_core.log"

echo
echo "Core XCFrameworks built."
echo

# --------------------------------------------------------
# Step 3 — Run one full preflight verify run
# --------------------------------------------------------
VERSION="0.0.1-corecheck-$TIMESTAMP"

echo "[3/4] Running preflight verify: $VERSION ..."
# Phase B Step 5: Use DRY_RUN instead of MSP_RELEASE_TIER
DRY_RUN=true \
MSP_RELEASE_MODE=cli \
MSP_KEEP_SANDBOX=1 \
bash Scripts/msp-release.sh run "$VERSION" --skip-create-release-branch --skip-remote \
    | tee "$LOG_DIR/preflight_verify.log"

echo
echo "Preflight verify completed."
echo

# --------------------------------------------------------
# Step 4 — Analyze results
# --------------------------------------------------------
STATE_FILE=".msp-release-state.json"

echo "[4/4] Checking final state ..."
if [[ ! -f "$STATE_FILE" ]]; then
    echo "❌ ERROR: State file not found. Verify did not run correctly."
    exit 1
fi

LOCAL_STATUS=$(jq -r '.steps.local_verify.status // "null"' "$STATE_FILE")
DEVICE_STATUS=$(jq -r '.steps.device_verify.status // "null"' "$STATE_FILE")
XCF_STATUS=$(jq -r '.steps.xcframework_verify.status // "null"' "$STATE_FILE")

echo "-------------------------------------------------------"
echo " Final Verify Status"
echo "-------------------------------------------------------"
echo " local_verify:        $LOCAL_STATUS"
echo " device_verify:       $DEVICE_STATUS"
echo " xcframework_verify:  $XCF_STATUS"
echo "-------------------------------------------------------"

echo
echo "Logs saved to: $LOG_DIR"
echo

if [[ "$LOCAL_STATUS" == "success" && "$DEVICE_STATUS" == "success" && "$XCF_STATUS" == "success" ]]; then
    echo "🎉 ALL CHECKS PASSED — Core pipeline is healthy."
    exit 0
else
    echo "⚠️  SOME CHECKS FAILED — Inspect logs in $LOG_DIR"
    exit 2
fi
