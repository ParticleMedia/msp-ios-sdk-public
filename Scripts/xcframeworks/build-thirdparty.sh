#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# XCFramework Builder for Third-Party Dependencies
# ============================================================================
# Purpose: Build third-party source pods into XCFrameworks for use in
#          pods-release and spm-release modes.
# Usage:   ./Scripts/xcframeworks/build-thirdparty.sh
# ============================================================================

set -eo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/target-switching/common.sh
source "$SCRIPT_DIR/../target-switching/common.sh"

ensure_repo_root

# Third-party libraries to build
# Format: "SchemeName:OutputName"
# Note: Shimmer is now provided via XCFramework (Shimmer Plan B), not built from Pods source
THIRDPARTY_TARGETS=(
    "SwiftProtobuf:SwiftProtobuf"
    "MSPSnapKit:MSPSnapKit"
    "Lottie:Lottie"
    # "Shimmer:Shimmer" - Removed: Shimmer Plan B (using XCFramework)
    "Kingfisher:Kingfisher"
)

# Project and output directories
THIRDPARTY_PROJECT_DIR="$ROOT_DIR/Examples/ThirdPartyFrameworks"
THIRDPARTY_PROJECT="$THIRDPARTY_PROJECT_DIR/ThirdPartyFrameworks.xcodeproj"
ARCHIVES_DIR="$ROOT_DIR/Build/Archives/ThirdParty"
THIRDPARTY_OUTPUT_DIR="$ROOT_DIR/ThirdParty"
DERIVED_DATA="$ROOT_DIR/.generated/DerivedData/build-thirdparty"

SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_MODULES=()

# ============================================================================
# Generate project.yml from templates (Template Architecture)
# ============================================================================

log_title "Building Third-Party XCFrameworks"

log_section "Generating project.yml from templates"

# Generate all project.yml files from .template files
if [[ -x "$ROOT_DIR/Scripts/target-switching/generate_project_templates.sh" ]]; then
    "$ROOT_DIR/Scripts/target-switching/generate_project_templates.sh"
else
    log_warn "generate_project_templates.sh not found or not executable"
fi

# ============================================================================
# Generate Xcode Project
# ============================================================================

log_section "Generating ThirdPartyFrameworks Xcode project"

if [[ ! -f "$THIRDPARTY_PROJECT_DIR/project.yml" ]]; then
    log_error "project.yml not found at $THIRDPARTY_PROJECT_DIR"
    log_error "Make sure project.yml.template exists and generate_project_templates.sh ran successfully"
    exit 1
fi

# Generate project from project.yml
log_step "Running XcodeGen"
if ! (cd "$THIRDPARTY_PROJECT_DIR" && xcodegen generate --spec project.yml); then
    log_error "Failed to generate Xcode project"
    exit 1
fi

if [[ ! -d "$THIRDPARTY_PROJECT" ]]; then
    log_error "XcodeGen did not create project: $THIRDPARTY_PROJECT"
    exit 1
fi

log_success "ThirdPartyFrameworks.xcodeproj generated"

# ============================================================================
# Build XCFrameworks
# ============================================================================

build_single_xcframework() {
    local scheme_name="$1"
    local output_name="$2"
    
    local ios_archive="$ARCHIVES_DIR/${output_name}-iOS.xcarchive"
    local sim_archive="$ARCHIVES_DIR/${output_name}-Simulator.xcarchive"
    local output_dir="$THIRDPARTY_OUTPUT_DIR/${output_name}"
    local xcframework_output="$output_dir/${output_name}.xcframework"
    
    log_section "Building $output_name"
    
    # Clean previous archives
    rm -rf "$ios_archive" "$sim_archive"
    mkdir -p "$ARCHIVES_DIR"
    mkdir -p "$output_dir"
    
    # Archive for iOS device
    log_step "Archiving $output_name for iOS device"
    if ! xcodebuild archive \
        -project "$THIRDPARTY_PROJECT" \
        -scheme "$scheme_name" \
        -configuration Release \
        -destination "generic/platform=iOS" \
        -archivePath "$ios_archive" \
        -derivedDataPath "$DERIVED_DATA" \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        SKIP_INSTALL=NO \
        -quiet 2>&1; then
        log_error "iOS archive failed for $output_name"
        return 1
    fi
    
    # Archive for iOS Simulator
    log_step "Archiving $output_name for iOS Simulator"
    if ! xcodebuild archive \
        -project "$THIRDPARTY_PROJECT" \
        -scheme "$scheme_name" \
        -configuration Release \
        -destination "generic/platform=iOS Simulator" \
        -archivePath "$sim_archive" \
        -derivedDataPath "$DERIVED_DATA" \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        SKIP_INSTALL=NO \
        -quiet 2>&1; then
        log_error "Simulator archive failed for $output_name"
        return 1
    fi
    
    # Find frameworks in archives
    local ios_framework="$ios_archive/Products/Library/Frameworks/${output_name}.framework"
    local sim_framework="$sim_archive/Products/Library/Frameworks/${output_name}.framework"
    
    # Fallback search if not in standard location
    if [[ ! -d "$ios_framework" ]]; then
        ios_framework=$(find "$ios_archive" -name "${output_name}.framework" -type d 2>/dev/null | head -1)
    fi
    if [[ ! -d "$sim_framework" ]]; then
        sim_framework=$(find "$sim_archive" -name "${output_name}.framework" -type d 2>/dev/null | head -1)
    fi
    
    if [[ -z "$ios_framework" ]] || [[ ! -d "$ios_framework" ]]; then
        log_error "iOS framework not found in archive for $output_name"
        log_info "Archive contents:"
        find "$ios_archive/Products" -type d -name "*.framework" 2>/dev/null || true
        return 1
    fi
    
    if [[ -z "$sim_framework" ]] || [[ ! -d "$sim_framework" ]]; then
        log_error "Simulator framework not found in archive for $output_name"
        return 1
    fi
    
    log_info "Found iOS framework: $ios_framework"
    log_info "Found Simulator framework: $sim_framework"
    
    # Create XCFramework
    log_step "Creating XCFramework for $output_name"
    rm -rf "$xcframework_output"
    
    if ! xcodebuild -create-xcframework \
        -framework "$ios_framework" \
        -framework "$sim_framework" \
        -output "$xcframework_output" 2>&1; then
        log_error "Failed to create XCFramework for $output_name"
        return 1
    fi
    
    if [[ ! -d "$xcframework_output" ]]; then
        log_error "XCFramework not created: $xcframework_output"
        return 1
    fi
    
    log_success "$output_name.xcframework created successfully"
    return 0
}

# Build each third-party framework
for target_spec in "${THIRDPARTY_TARGETS[@]}"; do
    IFS=':' read -r scheme_name output_name <<< "$target_spec"
    
    if build_single_xcframework "$scheme_name" "$output_name"; then
        ((SUCCESS_COUNT++)) || true
    else
        ((FAIL_COUNT++)) || true
        FAILED_MODULES+=("$output_name")
    fi
done

# ============================================================================
# Create symlinks for adapter builds
# ============================================================================

log_section "Creating symlinks for adapter builds"

mkdir -p "$ROOT_DIR/Sources/Core/ThirdParty"

for target_spec in "${THIRDPARTY_TARGETS[@]}"; do
    IFS=':' read -r scheme_name output_name <<< "$target_spec"
    xcf_path="$THIRDPARTY_OUTPUT_DIR/$output_name/$output_name.xcframework"
    link_dir="$ROOT_DIR/Sources/Core/ThirdParty/$output_name"
    link_path="$link_dir/$output_name.xcframework"
    
    if [[ -d "$xcf_path" ]]; then
        mkdir -p "$link_dir"
        rm -f "$link_path"
        ln -sf "$xcf_path" "$link_path"
        log_info "  Linked: Sources/Core/ThirdParty/$output_name/$output_name.xcframework"
    fi
done

# ============================================================================
# Summary Report
# ============================================================================

log_title "Third-Party XCFramework Build Summary"

printf "\n"
printf "┌─────────────────────────────────────────────────────────────────┐\n"
printf "│                   BUILD RESULTS                                 │\n"
printf "├─────────────────────────────────────────────────────────────────┤\n"

for target_spec in "${THIRDPARTY_TARGETS[@]}"; do
    IFS=':' read -r scheme_name output_name <<< "$target_spec"
    xcf_path="$THIRDPARTY_OUTPUT_DIR/$output_name/$output_name.xcframework"
    
    if [[ -d "$xcf_path" ]]; then
        printf "│ %-25s │ %-10s │ ThirdParty/%-15s │\n" "$output_name" "✅ OK" "$output_name/"
    else
        printf "│ %-25s │ %-10s │ %-27s │\n" "$output_name" "❌ MISSING" "-"
    fi
done

printf "├─────────────────────────────────────────────────────────────────┤\n"
printf "│ Success: %-3d                    Failed: %-3d                   │\n" "$SUCCESS_COUNT" "$FAIL_COUNT"
printf "└─────────────────────────────────────────────────────────────────┘\n"

if [[ $FAIL_COUNT -gt 0 ]]; then
    log_error "Failed to build $FAIL_COUNT third-party XCFramework(s): ${FAILED_MODULES[*]}"
    exit 1
fi

log_success "All third-party XCFrameworks built successfully!"
log_info "Output directory: $THIRDPARTY_OUTPUT_DIR"

# ============================================================================
# Copy third-party XCFrameworks to Build/XCFrameworks for core module builds
# ============================================================================

log_section "Copying third-party XCFrameworks to Build/XCFrameworks"

XCFRAMEWORKS_BUILD_DIR="$ROOT_DIR/Build/XCFrameworks"
mkdir -p "$XCFRAMEWORKS_BUILD_DIR"

for target_spec in "${THIRDPARTY_TARGETS[@]}"; do
    IFS=':' read -r scheme_name output_name <<< "$target_spec"
    source_xcf="$THIRDPARTY_OUTPUT_DIR/$output_name/$output_name.xcframework"
    target_xcf="$XCFRAMEWORKS_BUILD_DIR/$output_name.xcframework"
    
    if [[ -d "$source_xcf" ]]; then
        # Remove existing symlink or directory
        rm -rf "$target_xcf"
        # Create symlink (more efficient than copy)
        ln -sf "$(realpath "$source_xcf" 2>/dev/null || echo "$source_xcf")" "$target_xcf"
        log_info "  Linked: Build/XCFrameworks/$output_name.xcframework -> ThirdParty/$output_name/$output_name.xcframework"
    else
        log_warn "  Skipping: $output_name.xcframework not found in ThirdParty/"
    fi
done

# Link PrebidMobile.xcframework (exists in ThirdParty, not built by this script)
PREBID_SOURCE="$THIRDPARTY_OUTPUT_DIR/PrebidMobile/PrebidMobile.xcframework"
PREBID_TARGET="$XCFRAMEWORKS_BUILD_DIR/PrebidMobile.xcframework"
if [[ -d "$PREBID_SOURCE" ]]; then
    rm -rf "$PREBID_TARGET"
    ln -sf "$(realpath "$PREBID_SOURCE" 2>/dev/null || echo "$PREBID_SOURCE")" "$PREBID_TARGET"
    log_info "  Linked: Build/XCFrameworks/PrebidMobile.xcframework -> ThirdParty/PrebidMobile/PrebidMobile.xcframework"
else
    log_warn "  Skipping: PrebidMobile.xcframework not found in ThirdParty/PrebidMobile/"
fi

log_success "Third-party XCFrameworks linked to Build/XCFrameworks"
