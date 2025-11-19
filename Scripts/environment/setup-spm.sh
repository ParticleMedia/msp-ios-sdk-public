#!/usr/bin/env bash
# Setup script for SPM environment
# This script ensures all prerequisites are met for building MSPDemoApp-SPM
# Usage: ./Scripts/environment/setup-spm.sh

set -euo pipefail

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/lib/paths.sh
source "$ROOT_DIR/Scripts/lib/paths.sh"

# Initialize paths
init_paths

LOG_PREFIX="[setup-spm]"

echo "$LOG_PREFIX Setting up SPM environment for MSP iOS SDK"

# Set UTF-8 encoding for CocoaPods compatibility
export LANG=en_US.UTF-8

# Step 1: Install CocoaPods dependencies (required for Shimmer build)
echo "$LOG_PREFIX Step 1: Installing CocoaPods dependencies..."
if [[ -f "$ROOT_DIR/Gemfile" ]]; then
  if command -v bundle >/dev/null 2>&1; then
    bundle exec pod install || {
      echo "$LOG_PREFIX ERROR: pod install failed" >&2
      exit 1
    }
  else
    echo "$LOG_PREFIX WARNING: bundle not found, trying pod directly" >&2
    pod install || {
      echo "$LOG_PREFIX ERROR: pod install failed" >&2
      exit 1
    }
  fi
else
  echo "$LOG_PREFIX WARNING: Gemfile not found, skipping pod install" >&2
fi

# Step 2: Build All XCFrameworks
echo "$LOG_PREFIX Step 2: Building all wrapper xcframeworks..."
if [[ -f "$ROOT_DIR/Scripts/xcframeworks/build-all.sh" ]]; then
  chmod +x "$ROOT_DIR/Scripts/xcframeworks/build-all.sh"
  "$ROOT_DIR/Scripts/xcframeworks/build-all.sh" || {
    echo "$LOG_PREFIX ERROR: xcframework build failed" >&2
    exit 1
  }
else
  echo "$LOG_PREFIX ERROR: build-all.sh not found" >&2
  exit 1
fi
echo "$LOG_PREFIX ✓ All xcframeworks built and verified"

# Step 3: Validate Source Parity
echo "$LOG_PREFIX Step 3: Validating source parity between CocoaPods and SwiftPM..."
if [[ -f "$ROOT_DIR/Scripts/validation/source-parity.sh" ]]; then
  chmod +x "$ROOT_DIR/Scripts/validation/source-parity.sh"
  if ! "$ROOT_DIR/Scripts/validation/source-parity.sh"; then
    echo "$LOG_PREFIX ERROR: Source parity validation failed" >&2
    echo "$LOG_PREFIX This indicates files are missing or orphaned between Pods and SPM builds" >&2
    exit 1
  fi
else
  echo "$LOG_PREFIX WARNING: source-parity.sh not found, skipping validation" >&2
fi
echo "$LOG_PREFIX ✓ Source parity validated"

# Step 4: Regenerate workspace with XcodeGen
echo "$LOG_PREFIX Step 4: Regenerating workspace..."
if [[ -f "$ROOT_DIR/Scripts/workspace/update.sh" ]]; then
  chmod +x "$ROOT_DIR/Scripts/workspace/update.sh"
  if [[ -n "${CI:-}" ]]; then
    CI=1 "$ROOT_DIR/Scripts/workspace/update.sh"
  else
    "$ROOT_DIR/Scripts/workspace/update.sh"
  fi
else
  echo "$LOG_PREFIX ERROR: update.sh not found" >&2
  exit 1
fi

# Step 5: Verify SwiftPM package resolution
echo "$LOG_PREFIX Step 5: Verifying SwiftPM package resolution..."
if command -v swift >/dev/null 2>&1; then
  # Verify ShimmerWrapper resolves
  if (cd "$ROOT_DIR/ShimmerWrapper" && swift package resolve >/dev/null 2>&1); then
    echo "$LOG_PREFIX ✓ ShimmerWrapper package resolves"
  else
    echo "$LOG_PREFIX WARNING: ShimmerWrapper package resolution check failed" >&2
  fi
  
  # Verify NovaCore resolves (depends on ShimmerWrapper)
  if (cd "$ROOT_DIR/NovaCore" && swift package resolve >/dev/null 2>&1); then
    echo "$LOG_PREFIX ✓ NovaCore package resolves"
  else
    echo "$LOG_PREFIX WARNING: NovaCore package resolution check failed" >&2
  fi
else
  echo "$LOG_PREFIX WARNING: swift command not found, skipping package resolution check" >&2
fi

echo "$LOG_PREFIX ✓ SPM environment setup complete"
echo "$LOG_PREFIX You can now build MSPDemoApp-SPM using Xcode or xcodebuild"

