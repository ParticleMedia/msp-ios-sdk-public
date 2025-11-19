#!/usr/bin/env bash
# Wrapper script for copying InMobiSDK.xcframework

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

"$SCRIPT_DIR/../builder.sh" \
  --copy \
  --source-path "$ROOT_DIR/Pods/InMobiSDK/InMobiSDK.xcframework" \
  --output InMobiSDKWrapper \
  --sdk-name InMobiSDK
