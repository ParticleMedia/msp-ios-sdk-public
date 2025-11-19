#!/usr/bin/env bash
# [DEPRECATED] This script has moved to Scripts/xcframeworks/build-all.sh
# This compatibility shim will be removed in a future version
echo "[DEPRECATED] Scripts/build-all-xcframeworks.sh has moved to Scripts/xcframeworks/build-all.sh" >&2
exec "$(dirname "$0")/xcframeworks/build-all.sh" "$@"
