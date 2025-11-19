#!/usr/bin/env bash
# [DEPRECATED] This script has moved to Scripts/xcframeworks/builder.sh
# This compatibility shim will be removed in a future version
echo "[DEPRECATED] Scripts/build-xcframework.sh has moved to Scripts/xcframeworks/builder.sh" >&2
exec "$(dirname "$0")/xcframeworks/builder.sh" "$@"
