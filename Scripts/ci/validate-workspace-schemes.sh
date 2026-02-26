#!/usr/bin/env bash
set -euo pipefail

LOG_PREFIX="[validate-workspace-schemes]"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/Scripts/config/ci-pod-schemes.yml"

usage() {
  echo "Usage: $0 <workspace>" >&2
}

if [ $# -ne 1 ]; then
  usage
  exit 2
fi

WORKSPACE_FILE="$1"

if [ ! -d "$WORKSPACE_FILE" ]; then
  echo "❌ Workspace not found: $WORKSPACE_FILE" >&2
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

if ! REQUIRED_SCHEMES=$(ruby -e '
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

if [ -z "$REQUIRED_SCHEMES" ]; then
  echo "❌ No schemes found in $CONFIG_FILE" >&2
  exit 1
fi

echo "$LOG_PREFIX Listing schemes in $WORKSPACE_FILE..."

XCODEBUILD_OUTPUT=$(xcodebuild -workspace "$WORKSPACE_FILE" -list 2>&1)
XCODEBUILD_EXIT_CODE=$?

if [ "$XCODEBUILD_EXIT_CODE" -ne 0 ]; then
  echo "❌ Failed to list schemes from workspace: $WORKSPACE_FILE" >&2
  echo "xcodebuild output:" >&2
  echo "$XCODEBUILD_OUTPUT" >&2
  exit 1
fi

# Match "Schemes:" at beginning of line (with optional leading whitespace)
ALL_SCHEMES=$(echo "$XCODEBUILD_OUTPUT" | awk '
  /^[[:space:]]*Schemes:/{in_section=1; next}
  in_section==1 && NF==0 {exit}
  in_section==1 {sub(/^[[:space:]]+/, "", $0); if ($0 != "") print}
')

if [ -z "$ALL_SCHEMES" ]; then
  echo "❌ No schemes found in workspace: $WORKSPACE_FILE" >&2
  echo "xcodebuild -list output:" >&2
  echo "$XCODEBUILD_OUTPUT" >&2
  echo "" >&2
  echo "Debugging workspace structure..." >&2
  if [ -d "$WORKSPACE_FILE" ]; then
    echo "Workspace contents:" >&2
    ls -la "$WORKSPACE_FILE" >&2 || true
    if [ -f "$WORKSPACE_FILE/contents.xcworkspacedata" ]; then
      echo "" >&2
      echo "Workspace contents.xcworkspacedata:" >&2
      cat "$WORKSPACE_FILE/contents.xcworkspacedata" >&2 || true
    fi
  fi
  exit 1
fi

echo "$ALL_SCHEMES"

MISSING=0
MISSING_LIST=""

echo ""
echo "$LOG_PREFIX Checking required Pod schemes from $CONFIG_FILE..."
# shellcheck disable=SC2086 -- intentional word-splitting: REQUIRED_SCHEMES is a space-delimited name list
for scheme in $REQUIRED_SCHEMES; do
  # Check for exact match first
  if printf '%s\n' "$ALL_SCHEMES" | grep -Fqx "$scheme"; then
    echo "  ✅ Found: $scheme"
  # Check for partial match (schemes may have suffixes like "MSPSnapKit (MSPSnapKit project)")
  # Match scheme name at start of line, optionally followed by space and parentheses
  elif MATCHED_SCHEME=$(printf '%s\n' "$ALL_SCHEMES" | grep -E "^${scheme}( |\()" | head -1); then
    echo "  ✅ Found: $scheme (matched: $MATCHED_SCHEME)"
  else
    echo "  ❌ Missing: $scheme"
    MISSING=1
    MISSING_LIST="$MISSING_LIST\n  - $scheme"
  fi
done

if [ "$MISSING" -ne 0 ]; then
  echo "" >&2
  echo "❌ Missing required schemes (see $CONFIG_FILE):" >&2
  printf "%b\n" "$MISSING_LIST" >&2
  exit 1
fi

echo "✅ All required schemes found"
