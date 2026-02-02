#!/usr/bin/env bash
set -euo pipefail

LOG_PREFIX="[validate-shell-syntax]"
TARGET_DIR="${1:-Scripts}"

if [ ! -d "$TARGET_DIR" ]; then
  echo "❌ Directory not found: $TARGET_DIR" >&2
  exit 1
fi

echo "$LOG_PREFIX Checking shell script syntax in $TARGET_DIR..."

find "$TARGET_DIR" -name "*.sh" -type f | while IFS= read -r script; do
  echo "  Checking $script"
  if ! bash -n "$script"; then
    echo "❌ Shell syntax check failed: $script" >&2
    exit 1
  fi
done

echo "✅ All scripts pass syntax check"
