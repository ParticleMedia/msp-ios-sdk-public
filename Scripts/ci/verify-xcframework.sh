#!/usr/bin/env bash
set -euo pipefail

# R027c: Source shared XCFramework validation module
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
if [[ -f "$ROOT_DIR/Scripts/lib/shared/xcframework_validate.sh" ]]; then
    # shellcheck source=Scripts/lib/shared/xcframework_validate.sh
    source "$ROOT_DIR/Scripts/lib/shared/xcframework_validate.sh" 2>/dev/null || true
fi

usage() {
  echo "Usage: $0 <framework-name>" >&2
}

if [ $# -ne 1 ]; then
  usage
  exit 2
fi

FRAMEWORK_NAME="$1"
# Use canonical path per README: Build/ReleaseArtifacts/XCFrameworks/
XCFRAMEWORK_PATH="Build/ReleaseArtifacts/XCFrameworks/${FRAMEWORK_NAME}.xcframework"

if [ ! -d "$XCFRAMEWORK_PATH" ]; then
  echo "❌ XCFramework not found: $XCFRAMEWORK_PATH" >&2
  echo "Check build logs for ${FRAMEWORK_NAME} and ensure the build step ran." >&2
  if [ -d "Build/ReleaseArtifacts/XCFrameworks" ]; then
    echo "Contents of Build/ReleaseArtifacts/XCFrameworks:" >&2
    ls -la "Build/ReleaseArtifacts/XCFrameworks" >&2 || true
  else
    echo "Build/ReleaseArtifacts/XCFrameworks directory does not exist." >&2
  fi
  exit 1
fi

echo "✅ XCFramework exists: $XCFRAMEWORK_PATH"
if command -v du >/dev/null 2>&1; then
  du -sh "$XCFRAMEWORK_PATH" || true
fi
