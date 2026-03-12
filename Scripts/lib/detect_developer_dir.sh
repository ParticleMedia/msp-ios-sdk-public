#!/usr/bin/env bash
# Auto-detect DEVELOPER_DIR: prefer Xcode 16.x, then Xcode.app, then any Xcode_*.app, then xcode-select
# Usage: DEVELOPER_DIR="$(Scripts/lib/detect_developer_dir.sh)"
set -euo pipefail

for app in /Applications/Xcode_16*.app /Applications/Xcode.app /Applications/Xcode_*.app; do
    if [ -d "$app/Contents/Developer" ]; then
        printf '%s' "$app/Contents/Developer"
        exit 0
    fi
done

fallback="$(xcode-select -p 2>/dev/null | tr -d '\n')"
if [ -d "$fallback" ]; then
    printf '%s' "$fallback"
else
    echo "ERROR: No valid Xcode installation found" >&2
    exit 1
fi
