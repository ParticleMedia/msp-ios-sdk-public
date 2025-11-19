#!/usr/bin/env bash
# Build All XCFrameworks
# Builds all wrapper xcframeworks and ensures they're fresh
# Usage: ./Scripts/xcframeworks/build-all.sh

set -euo pipefail

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/lib/paths.sh
source "$ROOT_DIR/Scripts/lib/paths.sh"
# shellcheck source=Scripts/lib/colors.sh
source "$ROOT_DIR/Scripts/lib/colors.sh"
# shellcheck source=Scripts/lib/ui.sh
source "$ROOT_DIR/Scripts/lib/ui.sh"

# Initialize paths
init_paths

log_title "Building All XCFrameworks"

# Clean all temporary build directories
log_section "Cleaning Temporary Build Directories"
log_step "Cleaning temporary build directories"
find "$ROOT_DIR" -type d -name ".build-*-tmp" -exec rm -rf {} + 2>/dev/null || true
log_success "Cleaned temporary directories"

# Build all wrappers using generate-wrappers.sh
log_section "Building Wrapper XCFrameworks"
log_step "Building all wrapper xcframeworks"
"$SCRIPT_DIR/generate-wrappers.sh" --all

# Verify all xcframeworks exist
log_section "Verifying XCFrameworks"
declare -a WRAPPER_NAMES=(
    "ShimmerWrapper"
    "FBAudienceNetworkWrapper"
    "IronSourceSDKWrapper"
    "OpenWrapSDKWrapper"
    "MintegralAdSDKWrapper"
    "MobileFuseSDKWrapper"
    "InMobiSDKWrapper"
)

ERRORS=0
for wrapper in "${WRAPPER_NAMES[@]}"; do
    # Check both temp and final locations
    temp_path="$ROOT_DIR/Scripts/xcframeworks/output-temp/$wrapper/Frameworks"
    final_path="$ROOT_DIR/$wrapper/Frameworks"
    if [[ -d "$temp_path" ]] && [[ -n "$(find "$temp_path" -name "*.xcframework" -type d 2>/dev/null)" ]]; then
        log_success "$wrapper: xcframework found (temp)"
    elif [[ -d "$final_path" ]] && [[ -n "$(find "$final_path" -name "*.xcframework" -type d 2>/dev/null)" ]]; then
        log_success "$wrapper: xcframework found (final)"
    else
        log_error "$wrapper: xcframework missing"
        ((ERRORS++))
    fi
done

if [[ $ERRORS -gt 0 ]]; then
    log_error "$ERRORS xcframeworks are missing"
    exit 1
fi

log_title "Build Complete"
log_success "All xcframeworks built successfully"

