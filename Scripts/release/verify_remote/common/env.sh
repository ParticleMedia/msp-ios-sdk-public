#!/bin/bash
# ============================================================================
# Remote Verification Environment Variables (Template)
# ============================================================================
# Purpose: Common environment variables for remote release verification
#
# Usage:   source "$(dirname "$0")/env.sh"
# ============================================================================

set -euo pipefail

# Source common utilities
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

