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

# CocoaPods does not run prepare_command for local pods (:path =>).
# In CI (fresh checkout), MSPKingfisher/Sources/ won't exist because it's
# gitignored.  Mirror the podspec's prepare_command here so the pod compiles.
ensure_mspkingfisher_sources() {
  local podspec="ThirdParty/MSPKingfisher/MSPKingfisher.podspec"
  local sources_dir="ThirdParty/MSPKingfisher/Sources"

  if [ -d "$sources_dir" ]; then
    return 0
  fi

  if [ ! -f "$podspec" ]; then
    echo "$LOG_PREFIX ⚠️  MSPKingfisher.podspec not found, skipping source download"
    return 0
  fi

  # Extract the :tag value from the podspec (e.g. "7.12.0")
  local version
  version=$(grep -m1 ':tag' "$podspec" | sed 's/.*"\(.*\)".*/\1/')

  if [ -z "$version" ]; then
    echo "$LOG_PREFIX ❌ Could not determine Kingfisher version from $podspec" >&2
    return 1
  fi

  echo "$LOG_PREFIX Downloading Kingfisher $version sources (prepare_command doesn't run for local pods)..."
  local temp_dir
  temp_dir=$(mktemp -d)
  # shellcheck disable=SC2064  # intentional: expand $temp_dir now
  trap "rm -rf '$temp_dir'" RETURN

  if git clone --depth 1 --branch "$version" https://github.com/onevcat/Kingfisher.git "$temp_dir/kingfisher"; then
    cp -R "$temp_dir/kingfisher/Sources" "$sources_dir"
    echo "$LOG_PREFIX ✅ Kingfisher $version sources downloaded to $sources_dir"
  else
    echo "$LOG_PREFIX ❌ Failed to clone Kingfisher $version" >&2
    return 1
  fi
}

ensure_mspkingfisher_sources

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
