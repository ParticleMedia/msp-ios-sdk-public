#!/usr/bin/env bash
# Wrapper script for copying MobileFuseSDK.xcframework

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

"$SCRIPT_DIR/../builder.sh" \
  --copy \
  --source-path "$ROOT_DIR/Pods/MobileFuseSDK/MobileFuseSDK.xcframework" \
  --output MobileFuseSDKWrapper \
  --sdk-name MobileFuseSDK
