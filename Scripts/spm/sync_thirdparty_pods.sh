#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

# ============================================================================
# sync_thirdparty_pods.sh - Extract XCFrameworks from CocoaPods Pods directory
# ============================================================================
# Purpose: Automatically extract third-party XCFrameworks from Pods directory
#          and place them in ThirdParty/ for SPM usage
#
# Usage: ./Scripts/spm/sync_thirdparty_pods.sh [--force]
#
# Requirements:
#   - CocoaPods installed and Pods directory populated (run 'pod install' first)
#   - Write access to ThirdParty/ directory
#
# ============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PODS_DIR="$ROOT_DIR/Pods"
THIRDPARTY_DIR="$ROOT_DIR/ThirdParty"

log() { echo "[sync_thirdparty_pods] $*"; }
log::info() { echo "[INFO] $*"; }
log::success() { echo "[✓] $*"; }
log::warn() { echo "[⚠️ ] $*"; }
log::error() { echo "[✗] $*" >&2; }

# Mapping: Pod name → ThirdParty directory name → XCFramework filename
# Format: "PodName:ThirdPartyDir:XCFrameworkName"
THIRDPARTY_MAPPINGS=(
    "AmazonPublisherServicesSDK:AmazonPublisherServicesSDK:AmazonPublisherServicesSDK"
    "FBAudienceNetwork:FBAudienceNetwork:FBAudienceNetwork"
    "InMobiSDK:InMobiSDK:InMobiSDK"
    "IronSourceSDK:IronSourceSDK:IronSourceSDK"
    "MTGSDK:MintegralAdSDK:MTGSDK"
    "MTGSDKBidding:MintegralAdSDK:MTGSDKBidding"
    "MTGSDKBanner:MintegralAdSDK:MTGSDKBanner"
    "MTGSDKNewInterstitial:MintegralAdSDK:MTGSDKNewInterstitial"
    "MTGSDKInterstitialVideo:MintegralAdSDK:MTGSDKInterstitialVideo"
    "MobileFuseSDK:MobileFuseSDK:MobileFuseSDK"
    "MolocoSDKiOS:MolocoSDKiOS:MolocoSDK"
    "OpenWrapSDK:OpenWrapSDK:OpenWrapSDK"
    "VungleAds:VungleAds:VungleAdsSDK"
)

FORCE_SYNC=false
if [[ "${1:-}" == "--force" ]]; then
    FORCE_SYNC=true
    log::info "SPM" "Force sync enabled - will overwrite existing XCFrameworks"
fi

if [[ ! -d "$PODS_DIR" ]]; then
    log::error "SPM" "Pods directory not found: $PODS_DIR"
    log::error "SPM" "Please run 'pod install' first"
    exit 1
fi

log "Syncing third-party XCFrameworks from Pods to ThirdParty"
log::info "SPM" "Pods directory: $PODS_DIR"
log::info "SPM" "ThirdParty directory: $THIRDPARTY_DIR"
echo ""

# Create ThirdParty directory if it doesn't exist
mkdir -p "$THIRDPARTY_DIR"

SYNCED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

for mapping in "${THIRDPARTY_MAPPINGS[@]}"; do
    IFS=':' read -r pod_name thirdparty_dir xcframework_name <<< "$mapping"

    log::info "SPM" "Processing: $pod_name → ThirdParty/$thirdparty_dir/$xcframework_name.xcframework"

    # Check if Pod exists in Pods directory
    POD_PATH="$PODS_DIR/$pod_name"
    if [[ ! -d "$POD_PATH" ]]; then
        log::warn "SPM" "  Pod not found in Pods directory: $pod_name (may not be installed)"
        ((++SKIPPED_COUNT))
        continue
    fi

    # Find XCFramework in Pod directory
    # Try common locations: Pod root, Frameworks subdirectory
    XCFRAMEWORK_SOURCE=""
    if [[ -d "$POD_PATH/$xcframework_name.xcframework" ]]; then
        XCFRAMEWORK_SOURCE="$POD_PATH/$xcframework_name.xcframework"
    elif [[ -d "$POD_PATH/Frameworks/$xcframework_name.xcframework" ]]; then
        XCFRAMEWORK_SOURCE="$POD_PATH/Frameworks/$xcframework_name.xcframework"
    elif [[ -d "$POD_PATH/Framework/$xcframework_name.xcframework" ]]; then
        XCFRAMEWORK_SOURCE="$POD_PATH/Framework/$xcframework_name.xcframework"
    else
        # Search recursively
        XCFRAMEWORK_SOURCE=$(find "$POD_PATH" -name "$xcframework_name.xcframework" -type d -maxdepth 3 2>/dev/null | head -1)
    fi

    if [[ -z "$XCFRAMEWORK_SOURCE" ]]; then
        log::error "SPM" "  XCFramework not found in Pod: $xcframework_name.xcframework"
        ((++FAILED_COUNT))
        continue
    fi

    # Create destination directory
    DEST_DIR="$THIRDPARTY_DIR/$thirdparty_dir"
    mkdir -p "$DEST_DIR"

    DEST_PATH="$DEST_DIR/$xcframework_name.xcframework"

    # Check if destination already exists
    if [[ -d "$DEST_PATH" ]] && [[ "$FORCE_SYNC" != "true" ]]; then
        log::warn "SPM" "  Already exists (use --force to overwrite): $DEST_PATH"
        ((++SKIPPED_COUNT))
        continue
    fi

    # Copy XCFramework
    log::info "SPM" "  Copying: $(basename "$XCFRAMEWORK_SOURCE") → ThirdParty/$thirdparty_dir/"
    rm -rf "$DEST_PATH"
    cp -R "$XCFRAMEWORK_SOURCE" "$DEST_PATH"

    # Verify copy
    if [[ -d "$DEST_PATH" ]]; then
        SIZE=$(du -sh "$DEST_PATH" 2>/dev/null | cut -f1)
        log::success "SPM" "  Synced: $xcframework_name.xcframework ($SIZE)"
        ((++SYNCED_COUNT))
    else
        log::error "SPM" "  Failed to copy: $xcframework_name.xcframework"
        ((++FAILED_COUNT))
    fi
done

echo ""
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "Sync Summary:"
log "  Total:    ${#THIRDPARTY_MAPPINGS[@]}"
log "  Synced:   $SYNCED_COUNT"
log "  Skipped:  $SKIPPED_COUNT"
log "  Failed:   $FAILED_COUNT"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $FAILED_COUNT -gt 0 ]]; then
    log::warn "SPM" "Some XCFrameworks failed to sync"
    log::warn "SPM" "This may cause SPM build failures"
    exit 1
elif [[ $SYNCED_COUNT -gt 0 ]]; then
    log::success "SPM" "✅ ThirdParty XCFrameworks synced successfully"
    exit 0
else
    log::warn "SPM" "No XCFrameworks were synced (all already exist or pods not installed)"
    exit 0
fi
