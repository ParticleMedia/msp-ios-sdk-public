#!/usr/bin/env bash
set -euo pipefail

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
  (cd "$demoapp_dir" && xcodegen generate --spec project.yml)

  if [ ! -d "$xcodeproj_path" ]; then
    echo "❌ MSPDemoApp.xcodeproj not found after generation: $xcodeproj_path" >&2
    exit 1
  fi
}

ensure_demoapp_xcodeproj

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
