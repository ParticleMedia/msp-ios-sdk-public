#!/usr/bin/env bash
set -euo pipefail

LOG_PREFIX="[lint-podspecs]"
ALLOW_WARNINGS=0

usage() {
  echo "Usage: $0 [--allow-warnings]" >&2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --allow-warnings)
      ALLOW_WARNINGS=1
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
  echo "❌ CocoaPods command not found. Install CocoaPods or Bundler before linting." >&2
  exit 1
fi

ALLOW_FLAG=""
if [ "$ALLOW_WARNINGS" -eq 1 ]; then
  ALLOW_FLAG="--allow-warnings"
fi

FOUND=0
for spec in ./*.podspec; do
  if [ -f "$spec" ]; then
    FOUND=1
    echo "$LOG_PREFIX Linting $spec..."
    if ! "${POD_CMD[@]}" spec lint "$spec" --quick $ALLOW_FLAG; then
      echo "❌ Podspec lint failed: $spec" >&2
      exit 1
    fi
  fi
done

if [ "$FOUND" -eq 0 ]; then
  echo "$LOG_PREFIX No podspec files found; nothing to lint."
else
  echo "✅ Podspec linting completed."
fi
