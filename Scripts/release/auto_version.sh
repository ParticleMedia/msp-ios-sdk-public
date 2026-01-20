#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Auto Version Management for MSP Release CI
# ============================================================================
# Purpose: Calculate next version based on latest git tag or return explicit version
#
# Usage:
#   bash Scripts/release/auto_version.sh auto          # Bump patch (default)
#   bash Scripts/release/auto_version.sh auto:patch     # Bump patch
#   bash Scripts/release/auto_version.sh auto:minor     # Bump minor, reset patch
#   bash Scripts/release/auto_version.sh auto:major     # Bump major, reset minor/patch
#   bash Scripts/release/auto_version.sh 1.9.0          # Return explicit version
#
# Output: Only the version string (e.g., "1.9.1") to stdout
#         Error messages go to stderr
# ============================================================================

set -euo pipefail

# ============================================================================
# Parse Arguments
# ============================================================================

VERSION_ARG="${1:-}"

if [[ -z "$VERSION_ARG" ]]; then
    echo "Error: Version argument required" >&2
    echo "Usage: $0 <auto|auto:patch|auto:minor|auto:major|X.Y.Z>" >&2
    exit 1
fi

# ============================================================================
# Handle Explicit Version (passthrough)
# ============================================================================

# If argument is not "auto" or starts with "auto:", treat as explicit version
if [[ ! "$VERSION_ARG" =~ ^auto ]]; then
    # Just echo the explicit version and exit
    echo "$VERSION_ARG"
    exit 0
fi

# ============================================================================
# Parse Auto Mode
# ============================================================================

AUTO_MODE="patch"  # Default to patch

if [[ "$VERSION_ARG" == "auto" ]] || [[ "$VERSION_ARG" == "auto:patch" ]]; then
    AUTO_MODE="patch"
elif [[ "$VERSION_ARG" == "auto:minor" ]]; then
    AUTO_MODE="minor"
elif [[ "$VERSION_ARG" == "auto:major" ]]; then
    AUTO_MODE="major"
else
    echo "Error: Invalid auto mode: $VERSION_ARG" >&2
    echo "Valid modes: auto, auto:patch, auto:minor, auto:major" >&2
    exit 1
fi

# ============================================================================
# Get Latest SemVer Tag
# ============================================================================

# Find latest tag matching SemVer pattern (X.Y.Z)
# Use grep to filter only numeric version tags, sort with version sort, get last one
LAST_TAG="$(git tag 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -1 || echo "")"

# If no tag exists, start from 0.0.0
if [[ -z "$LAST_TAG" ]]; then
    LAST_TAG="0.0.0"
fi

# ============================================================================
# Parse Version Parts
# ============================================================================

# Split version into major.minor.patch
IFS='.' read -r -a VERSION_PARTS <<< "$LAST_TAG"

MAJOR="${VERSION_PARTS[0]:-0}"
MINOR="${VERSION_PARTS[1]:-0}"
PATCH="${VERSION_PARTS[2]:-0}"

# Ensure numeric values (handle edge cases)
MAJOR="${MAJOR:-0}"
MINOR="${MINOR:-0}"
PATCH="${PATCH:-0}"

# ============================================================================
# Bump Version According to Mode
# ============================================================================

case "$AUTO_MODE" in
    major)
        # Bump major, reset minor and patch to 0
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        # Bump minor, reset patch to 0
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        # Bump patch only
        PATCH=$((PATCH + 1))
        ;;
    *)
        echo "Error: Invalid auto mode: $AUTO_MODE" >&2
        exit 1
        ;;
esac

# ============================================================================
# Output New Version
# ============================================================================

# Output ONLY the version string to stdout (no extra logs)
echo "${MAJOR}.${MINOR}.${PATCH}"

exit 0

