#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch M, shared) ---
# shellcheck source=/dev/null
_msp_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$_msp_root" ] && [ -f "$_msp_root/Scripts/lib/worktree_guard.sh" ]; then
  . "$_msp_root/Scripts/lib/worktree_guard.sh"
  msp_enforce_main_repo_or_exit
fi
unset _msp_root
# --- End MSP Worktree Safety Guard (Patch M, shared) ---
# Wrapper script for building Shimmer.xcframework
# Shimmer requires special umbrella header handling

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Call generic build script
"$SCRIPT_DIR/../builder.sh" \
  --scheme Shimmer \
  --output ShimmerWrapper \
  --sdk-name Shimmer \
  --pods-dir "$ROOT_DIR/ThirdParty/Shimmer/Shimmer"

# Apply Shimmer-specific umbrella header fix
# Note: xcframework is now in temp directory, but we fix it in final destination
XCFRAMEWORK_PATH="$ROOT_DIR/ShimmerWrapper/Frameworks/Shimmer.xcframework"

# Fix umbrella header for all platform variants in the xcframework
if [[ -d "$XCFRAMEWORK_PATH" ]]; then
  find "$XCFRAMEWORK_PATH" -path "*/Headers/FBShimmering.h" -type f | while read header_file; do
    header_dir="$(dirname "$header_file")"
    if [[ -f "$header_file" ]]; then
      # Check if FBShimmeringView.h and FBShimmeringLayer.h are already imported
      if ! grep -q "FBShimmeringView.h" "$header_file"; then
        # Make file writable and append imports to the umbrella header
        chmod +w "$header_file"
        cat >> "$header_file" <<UMBRELLA

#import "FBShimmeringLayer.h"
#import "FBShimmeringView.h"
UMBRELLA
      fi
    fi
  done
  echo "✓ Shimmer umbrella header fixed"
fi
