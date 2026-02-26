#!/usr/bin/env bash
set -euo pipefail

LOG_PREFIX="[prebuild-pod-deps]"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/Scripts/config/ci-pod-schemes.yml"

STAGE=""

usage() {
  echo "Usage: $0 [--stage <stage>]" >&2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --stage)
      STAGE="${2:-}"
      shift 2
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
done

if [ -n "$STAGE" ]; then
  echo "$LOG_PREFIX Stage set to '$STAGE' (schemes are still read from $CONFIG_FILE)"
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

if ! SCHEMES=$(ruby -e '
  require "yaml"
  config_file = ARGV[0]
  data = YAML.load_file(config_file) || {}
  schemes = data["schemes"]
  exit(2) unless schemes.is_a?(Array) && !schemes.empty?
  puts schemes.join(" ")
' "$CONFIG_FILE"); then
  echo "❌ Failed to read schemes from $CONFIG_FILE" >&2
  exit 1
fi

if [ -z "$SCHEMES" ]; then
  echo "❌ No schemes found in $CONFIG_FILE" >&2
  exit 1
fi

WORKSPACE_FILE="msp-ios-sdk.xcworkspace"
if [ ! -d "$WORKSPACE_FILE" ]; then
  echo "❌ Workspace not found: $WORKSPACE_FILE" >&2
  exit 1
fi

SHARED_DERIVED_DATA=".generated/DerivedData/build-shared"
mkdir -p "$SHARED_DERIVED_DATA"

echo "$LOG_PREFIX Pre-building Pod dependencies for: $SCHEMES"

echo "$LOG_PREFIX Listing available schemes in workspace..."
ALL_SCHEMES=$(xcodebuild -workspace "$WORKSPACE_FILE" -list 2>&1 | awk '
  /^[[:space:]]*Schemes:/{in_section=1; next}
  in_section==1 && NF==0 {exit}
  in_section==1 {sub(/^[[:space:]]+/, "", $0); if ($0 != "") print}
')

if [ -z "$ALL_SCHEMES" ]; then
  echo "❌ No schemes found in workspace: $WORKSPACE_FILE" >&2
  exit 1
fi

find_scheme_name() {
  local scheme="$1"
  # Check for exact match first
  if echo "$ALL_SCHEMES" | grep -Fqx "$scheme"; then
    echo "$scheme"
  # Check for partial match (schemes may have suffixes like "MSPSnapKit (MSPSnapKit project)")
  elif MATCHED=$(echo "$ALL_SCHEMES" | grep -E "^${scheme}( |\()" | head -1); then
    echo "$MATCHED"
  else
    echo ""
  fi
}

# shellcheck disable=SC2086 -- intentional word-splitting: SCHEMES is a space-delimited name list
for scheme in $SCHEMES; do
  # Find actual scheme name (may have suffix)
  ACTUAL_SCHEME=$(find_scheme_name "$scheme")
  if [ -z "$ACTUAL_SCHEME" ]; then
    echo "❌ Scheme '$scheme' not found in workspace" >&2
    echo "Available schemes:" >&2
    echo "$ALL_SCHEMES" | sed 's/^/  - /' >&2
    exit 1
  fi
  
  if [ "$ACTUAL_SCHEME" != "$scheme" ]; then
    echo "$LOG_PREFIX Found scheme '$scheme' as '$ACTUAL_SCHEME'"
  fi
  
  scheme_safe=$(printf '%s' "$scheme" | tr '/' '_')
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Pre-building $scheme ($ACTUAL_SCHEME) for iOS..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if xcodebuild -workspace "$WORKSPACE_FILE" \
      -scheme "$ACTUAL_SCHEME" \
      -configuration Release \
      -destination "generic/platform=iOS" \
      -derivedDataPath "$SHARED_DERIVED_DATA" \
      build 2>&1 | tee "/tmp/build_${scheme_safe}.log"; then
    if grep -q "BUILD SUCCEEDED" "/tmp/build_${scheme_safe}.log"; then
      echo "✅ $scheme (iOS) built successfully"
    else
      echo "❌ $scheme (iOS) build failed - checking log..." >&2
      tail -50 "/tmp/build_${scheme_safe}.log" >&2
      exit 1
    fi
  else
    echo "❌ $scheme (iOS) build command failed - checking log..." >&2
    tail -50 "/tmp/build_${scheme_safe}.log" >&2
    exit 1
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Pre-building $scheme ($ACTUAL_SCHEME) for Simulator..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if xcodebuild -workspace "$WORKSPACE_FILE" \
      -scheme "$ACTUAL_SCHEME" \
      -configuration Release \
      -destination "generic/platform=iOS Simulator" \
      -derivedDataPath "$SHARED_DERIVED_DATA" \
      build 2>&1 | tee "/tmp/build_${scheme_safe}_sim.log"; then
    if grep -q "BUILD SUCCEEDED" "/tmp/build_${scheme_safe}_sim.log"; then
      echo "✅ $scheme (Simulator) built successfully"
    else
      echo "⚠️  $scheme (Simulator) build had issues, checking log..." >&2
      tail -30 "/tmp/build_${scheme_safe}_sim.log" >&2
      echo "⚠️  Continuing despite Simulator build issues..." >&2
    fi
  else
    echo "⚠️  $scheme (Simulator) build command failed, checking log..." >&2
    tail -30 "/tmp/build_${scheme_safe}_sim.log" >&2
    echo "⚠️  Continuing despite Simulator build issues..." >&2
  fi
done

echo ""
echo "✅ All Pod dependencies pre-built successfully"
echo "Pod modules available at: $SHARED_DERIVED_DATA/Build/Products/Release-iphoneos/"
ls -la "$SHARED_DERIVED_DATA/Build/Products/Release-iphoneos/" 2>/dev/null || echo "⚠️  Products directory not found"
