#!/usr/bin/env bash
set -euo pipefail

LOG_PREFIX="[ensure-xcodegen]"

if command -v xcodegen >/dev/null 2>&1; then
  echo "✅ XcodeGen already installed: $(xcodegen --version)"
  exit 0
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "❌ Homebrew not found. Install Homebrew to install XcodeGen." >&2
  exit 1
fi

echo "$LOG_PREFIX Installing XcodeGen via Homebrew..."
if brew install xcodegen; then
  echo "✅ XcodeGen installed: $(xcodegen --version)"
else
  echo "❌ Failed to install XcodeGen via Homebrew." >&2
  exit 1
fi
