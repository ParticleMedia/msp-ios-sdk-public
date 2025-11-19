#!/usr/bin/env bash
# Wrapper script for copying MintegralAdSDK.xcframework
# Note: This copies MTGSDK.xcframework, but MintegralAdSDKWrapper uses multiple xcframeworks
# This script only handles the base MTGSDK.xcframework

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

"$SCRIPT_DIR/../builder.sh" \
  --copy \
  --source-path "$ROOT_DIR/Pods/MintegralAdSDK/Fmk/MTGSDK.xcframework" \
  --output MintegralAdSDKWrapper \
  --sdk-name MintegralAdSDK \
  --pods-dir "$ROOT_DIR/Pods/MintegralAdSDK"
