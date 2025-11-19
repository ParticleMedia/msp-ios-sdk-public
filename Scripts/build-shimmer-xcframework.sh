#!/usr/bin/env bash
# [DEPRECATED] This script has moved to Scripts/xcframeworks/wrappers/build-shimmer.sh
# This compatibility shim will be removed in a future version
echo "[DEPRECATED] Scripts/build-shimmer-xcframework.sh has moved to Scripts/xcframeworks/wrappers/build-shimmer.sh" >&2
exec "$(dirname "$0")/xcframeworks/wrappers/build-shimmer.sh" "$@"
