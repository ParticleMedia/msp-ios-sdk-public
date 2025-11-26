#!/bin/bash
set -euo pipefail

# Extract third-party SDK xcframeworks from Pods/ and normalize them into:
#   ThirdParty/<SDK>/<SDK>.xcframework
#
# This script assumes CocoaPods is already installed (pod install has run).
# It does NOT change versions – it just repackages whatever Pods downloaded.
#
# EXCLUDED SDKs:
#   - PrebidMobile: Uses canonical ThirdParty/PrebidMobile/PrebidMobile.xcframework
#   - GoogleMobileAds: SPM-native, no xcframework extraction needed

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PODS_DIR="$ROOT_DIR/Pods"
DEST_DIR="$ROOT_DIR/ThirdParty"

mkdir -p "$DEST_DIR"

log()  { echo "[$(basename "$0")] $*"; }
err()  { echo "[$(basename "$0") ERROR] $*" >&2; }

# Map logical SDK names -> Pod directory names.
# Adjust POD_DIR if your pod names differ.
#
# NOTE: PrebidMobile is EXCLUDED — we use the canonical ThirdParty/PrebidMobile/PrebidMobile.xcframework
# NOTE: GoogleMobileAds is EXCLUDED — SPM-native, no xcframework extraction needed
declare -A SDK_POD_DIRS=(
  ["FBAudienceNetwork"]="FBAudienceNetwork"
  ["IronSourceSDK"]="IronSourceSDK"
  ["InMobiSDK"]="InMobiSDK"
  ["MobileFuseSDK"]="MobileFuseSDK"
  ["MintegralAdSDK"]="MintegralAdSDK"
  ["OpenWrapSDK"]="OpenWrapSDK"
  ["AmazonPublisherServicesSDK"]="AmazonPublisherServicesSDK"
)

find_xcframework_in_pod() {
  local pod_dir="$1"
  if [[ ! -d "$pod_dir" ]]; then
    return 1
  fi
  # Prefer .xcframework inside the pod directory
  local xc
  xc="$(find "$pod_dir" -maxdepth 5 -type d -name '*.xcframework' | head -n 1 || true)"
  if [[ -z "$xc" ]]; then
    return 1
  fi
  echo "$xc"
}

copy_xcframework() {
  local sdk_name="$1"
  local src_xc="$2"

  local sdk_dest_dir="$DEST_DIR/$sdk_name"
  local dest_xc="$sdk_dest_dir/$sdk_name.xcframework"

  log "Preparing $sdk_name from $src_xc"

  rm -rf "$sdk_dest_dir"
  mkdir -p "$sdk_dest_dir"

  # Copy the xcframework and normalize its name
  cp -R "$src_xc" "$dest_xc"

  log "✔ Installed $sdk_name → $dest_xc"
}

main() {
  if [[ ! -d "$PODS_DIR" ]]; then
    err "Pods directory not found at $PODS_DIR. Run 'pod install' first."
    exit 1
  fi

  # Log skipped SDKs
  log "Skipping PrebidMobile — using canonical ThirdParty/PrebidMobile/PrebidMobile.xcframework"
  log "Skipping GoogleMobileAds — SPM-native, no xcframework extraction needed"

  for sdk_name in "${!SDK_POD_DIRS[@]}"; do
    local pod_name="${SDK_POD_DIRS[$sdk_name]}"
    local pod_dir="$PODS_DIR/$pod_name"

    log "Processing SDK: $sdk_name (Pod: $pod_name)"

    local xc
    xc="$(find_xcframework_in_pod "$pod_dir" || true)"
    if [[ -z "$xc" ]]; then
      err "No .xcframework found under $pod_dir. You may need to adjust SDK_POD_DIRS or investigate this pod."
      continue
    fi

    copy_xcframework "$sdk_name" "$xc"
  done

  log "✅ Finished extracting third-party SDK xcframeworks from Pods."
}

main "$@"
