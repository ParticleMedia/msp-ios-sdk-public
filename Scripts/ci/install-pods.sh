#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# R029d: Source xcodegen module for unified generation
if [[ -f "$ROOT_DIR/Scripts/lib/xcodegen.sh" ]]; then
    # shellcheck source=Scripts/lib/xcodegen.sh
    source "$ROOT_DIR/Scripts/lib/xcodegen.sh" 2>/dev/null || true
fi

# R036a: Source cocoapods module for unified pod operations
COCOAPODS_MODULE_AVAILABLE=false
if [[ -f "$ROOT_DIR/Scripts/lib/cocoapods.sh" ]]; then
    # shellcheck source=Scripts/lib/cocoapods.sh
    source "$ROOT_DIR/Scripts/lib/cocoapods.sh" 2>/dev/null || true
    if command -v install_pods &>/dev/null; then
        COCOAPODS_MODULE_AVAILABLE=true
    fi
fi

LOG_PREFIX="[install-pods]"
REPO_UPDATE=0

usage() {
  echo "Usage: $0 [--repo-update]" >&2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --repo-update)
      REPO_UPDATE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "$LOG_PREFIX Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
  shift
done

# R036a: Use cocoapods.sh module if available, fallback to direct commands
if [[ "$COCOAPODS_MODULE_AVAILABLE" != "true" ]]; then
    POD_CMD=()
    if [ -f "Gemfile" ] && command -v bundle >/dev/null 2>&1; then
      POD_CMD=(bundle exec pod)
    else
      POD_CMD=(pod)
    fi

    if ! command -v "${POD_CMD[0]}" >/dev/null 2>&1; then
      echo "❌ CocoaPods command not found. Install CocoaPods or Bundler before running pod install." >&2
      exit 1
    fi
fi

echo "$LOG_PREFIX Installing root-level CocoaPods dependencies..."

ensure_demoapp_xcodeproj() {
  local demoapp_dir=""
  if [ -d "Examples/MSPDemoApp" ]; then
    demoapp_dir="Examples/MSPDemoApp"
  elif [ -d "MSPDemoApp" ]; then
    demoapp_dir="MSPDemoApp"
  fi

  if [ -z "$demoapp_dir" ]; then
    return 0
  fi

  local xcodeproj_path="$demoapp_dir/MSPDemoApp.xcodeproj"
  # Check if project.pbxproj exists (not just the directory)
  # The directory may exist (e.g., xcshareddata) but project.pbxproj may be missing
  if [ -f "$xcodeproj_path/project.pbxproj" ]; then
    return 0
  fi

  local project_spec="$demoapp_dir/project.yml"
  if [ ! -f "$project_spec" ] && [ -f "$demoapp_dir/project.yml.template" ]; then
    if [ -x "Scripts/target-switching/generate_workspace.sh" ]; then
      echo "$LOG_PREFIX Generating project.yml via generate_workspace.sh..."
      ./Scripts/target-switching/generate_workspace.sh pods
    fi
  fi

  if [ ! -f "$project_spec" ]; then
    echo "❌ DemoApp project.yml not found: $project_spec" >&2
    exit 1
  fi

  if ! command -v xcodegen >/dev/null 2>&1; then
    echo "❌ xcodegen not found. Run Scripts/ci/ensure-xcodegen.sh first." >&2
    exit 1
  fi

  echo "$LOG_PREFIX Generating MSPDemoApp.xcodeproj via XcodeGen..."
  # R029d: Use xcodegen.sh module if available
  if command -v xcodegen_generate &>/dev/null; then
    xcodegen_generate "$demoapp_dir/project.yml" "$demoapp_dir"
  else
    (cd "$demoapp_dir" && xcodegen generate --spec project.yml)
  fi

  if [ ! -d "$xcodeproj_path" ]; then
    echo "❌ MSPDemoApp.xcodeproj not found after generation: $xcodeproj_path" >&2
    exit 1
  fi
}

ensure_demoapp_xcodeproj

# R036a: Use cocoapods.sh module's install_pods() if available
if [[ "$COCOAPODS_MODULE_AVAILABLE" == "true" ]]; then
    install_options=()
    if [ "$REPO_UPDATE" -eq 1 ]; then
        install_options+=("--repo-update")
    fi

    if install_pods "${install_options[@]}"; then
        echo "✅ pod install completed (via cocoapods.sh module)"
        exit 0
    else
        echo "❌ pod install failed. Check CocoaPods logs for details." >&2
        exit 1
    fi
else
    # Fallback: Direct pod install (when cocoapods.sh module is not available)
    if [ "$REPO_UPDATE" -eq 1 ]; then
      if "${POD_CMD[@]}" install --repo-update; then
        echo "✅ pod install --repo-update completed"
        exit 0
      fi
      echo "⚠️  pod install --repo-update failed; retrying without --repo-update..."
    fi

    if "${POD_CMD[@]}" install; then
      echo "✅ pod install completed"
      exit 0
    fi

    echo "❌ pod install failed after retry. Check CocoaPods logs for details." >&2
    exit 1
fi
