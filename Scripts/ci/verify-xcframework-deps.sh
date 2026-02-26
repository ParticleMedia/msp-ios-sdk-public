#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/Scripts/config/ci-framework-deps.yml"

usage() {
  echo "Usage: $0 <stage>" >&2
}

if [ $# -ne 1 ]; then
  usage
  exit 2
fi

STAGE="$1"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

if ! REQUIRED_SCHEMES=$(ruby -e '
  require "yaml"
  config_file = ARGV[0]
  stage = ARGV[1]
  data = YAML.load_file(config_file) || {}
  stage_hash = data[stage]
  exit(2) unless stage_hash.is_a?(Hash)
  requires = stage_hash["requires"]
  exit(2) unless requires.is_a?(Array) && !requires.empty?
  puts requires.join(" ")
' "$CONFIG_FILE" "$STAGE"); then
  echo "❌ Failed to read requirements for stage '$STAGE' from $CONFIG_FILE" >&2
  exit 1
fi

if [ -z "$REQUIRED_SCHEMES" ]; then
  echo "❌ No requirements found for stage '$STAGE' in $CONFIG_FILE" >&2
  exit 1
fi

MISSING=0
MISSING_LIST=""

# shellcheck disable=SC2086 -- intentional word-splitting: REQUIRED_SCHEMES is a space-delimited name list
for framework in $REQUIRED_SCHEMES; do
  # Use canonical path per README: Build/ReleaseArtifacts/XCFrameworks/
  path="Build/ReleaseArtifacts/XCFrameworks/${framework}.xcframework"
  if [ -d "$path" ]; then
    echo "✅ Found required XCFramework: $path"
  else
    echo "❌ Missing required XCFramework: $path" >&2
    MISSING=1
    MISSING_LIST="$MISSING_LIST\n  - $framework"
  fi
done

if [ "$MISSING" -ne 0 ]; then
  echo "" >&2
  echo "❌ Missing required XCFrameworks for stage '$STAGE':" >&2
  printf "%b\n" "$MISSING_LIST" >&2
  echo "Check build logs for the missing frameworks." >&2
  exit 1
fi

echo "✅ All required XCFrameworks present for stage '$STAGE'"
