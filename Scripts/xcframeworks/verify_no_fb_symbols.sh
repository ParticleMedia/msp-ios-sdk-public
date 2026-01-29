#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
XCFRAMEWORK="${ROOT_DIR}/Build/ReleaseArtifacts/XCFrameworks/MSPFacebookAdapter.xcframework"
IOS_BIN="${XCFRAMEWORK}/ios-arm64/MSPFacebookAdapter.framework/MSPFacebookAdapter"
SIM_BIN="${XCFRAMEWORK}/ios-arm64_x86_64-simulator/MSPFacebookAdapter.framework/MSPFacebookAdapter"

if [[ ! -f "$IOS_BIN" ]]; then
  echo "Missing iOS binary: $IOS_BIN" >&2
  exit 1
fi
if [[ ! -f "$SIM_BIN" ]]; then
  echo "Missing Simulator binary: $SIM_BIN" >&2
  exit 1
fi

check_binary() {
  local bin=$1
  local label=$2
  echo "=== $label: undefined FB symbols check ==="
  if nm -gU "$bin" 2>/dev/null | grep -q 'OBJC_CLASS_$_FBAdSettings'; then
    echo "ERROR: $label contains FBAdSettings definition (should be undefined)" >&2
    nm -gU "$bin" 2>/dev/null | grep 'OBJC_CLASS_$_FBAdSettings' || true
    exit 1
  fi
  if nm -u "$bin" 2>/dev/null | grep -q "FBAdSettings"; then
    echo "OK: $label has undefined FBAdSettings reference"
  else
    echo "WARN: $label has no undefined FBAdSettings reference"
  fi

  echo "=== $label: undefined FB references ==="
  nm -u "$bin" 2>/dev/null | grep -E "FBAdSettings|FBNativeAd|FBInterstitialAd" | head -10 || echo "No FB undefined refs found"
  echo
}

check_binary "$IOS_BIN" "iOS"
check_binary "$SIM_BIN" "Simulator"
