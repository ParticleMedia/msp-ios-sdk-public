#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch M, shared) ---
# shellcheck source=/dev/null
_msp_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$_msp_root" ] && [ -f "$_msp_root/Scripts/lib/worktree_guard.sh" ]; then
  . "$_msp_root/Scripts/lib/worktree_guard.sh"
  msp_enforce_main_repo_or_exit
fi
unset _msp_root
# --- End MSP Worktree Safety Guard (Patch M, shared) ---
# ============================================================================
# Remote Verification Environment Variables (Template)
# ============================================================================
# Purpose: Common environment variables for remote release verification
#
# Usage:   source "$(dirname "$0")/env.sh"
# ============================================================================

set -euo pipefail

source "$(dirname "$0")/utils.sh"

# ============================================================================
# Environment Variables
# ============================================================================

# Remote repository URL (for SPM)
export REMOTE_REPO_URL="${REMOTE_REPO_URL:-https://github.com/ParticleMedia/msp-ios-sdk-public.git}"

# Remote tag/version to verify
export REMOTE_VERSION="${REMOTE_VERSION:-}"

# CocoaPods source URL (if using private spec repo)
export COCOAPODS_SOURCE_URL="${COCOAPODS_SOURCE_URL:-}"

# Sandbox base directory
export SANDBOX_BASE="${SANDBOX_BASE:-/tmp/msp-verify-remote}"

# DemoApp source path (relative to repo root)
export DEMOAPP_SOURCE="${DEMOAPP_SOURCE:-Examples/MSPDemoApp}"

# Build configuration
export BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-Debug}"

# iOS Simulator destination
export SIMULATOR_DESTINATION="${SIMULATOR_DESTINATION:-platform=iOS Simulator,name=iPhone 16}"

