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

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/target-switching/common.sh
source "$SCRIPT_DIR/../target-switching/common.sh"

# Ensure logger functions are available in subprocess
# (Force reload by unsetting the guard variable, as parent may have already sourced)
if [[ -f "$ROOT_DIR/Scripts/release/utils/logger.sh" ]]; then
    unset MSP_LOGGER_LOADED
    # shellcheck source=Scripts/release/utils/logger.sh
    source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true
fi

# R029f: Source xcodegen module for unified generation
if [[ -f "$ROOT_DIR/Scripts/lib/xcodegen.sh" ]]; then
    # shellcheck source=Scripts/lib/xcodegen.sh
    source "$ROOT_DIR/Scripts/lib/xcodegen.sh" 2>/dev/null || true
fi

# R025d: Source shared XCFramework build module
if [[ -f "$ROOT_DIR/Scripts/lib/shared/xcframework_build.sh" ]]; then
    # shellcheck source=Scripts/lib/shared/xcframework_build.sh
    source "$ROOT_DIR/Scripts/lib/shared/xcframework_build.sh" 2>/dev/null || true
fi

ensure_repo_root

# Third-party libraries to build
# Format: "SchemeName:OutputName"
# Note: Shimmer is now provided via XCFramework (Shimmer Plan B), not built from Pods source
# Note: Kingfisher is NOT built here - project uses MSPKingfisher pod (source-based) instead
#       MSPKingfisher/Sources is gitignored and only created during pod install prepare_command
#       Pre-built Kingfisher.xcframework exists in ThirdParty/Kingfisher/ if needed
THIRDPARTY_TARGETS=(
    "SwiftProtobuf:SwiftProtobuf"
    "MSPSnapKit:MSPSnapKit"
    # "Lottie:Lottie" - Removed: NovaCore no longer depends on lottie-ios
    # "Shimmer:Shimmer" - Removed: Shimmer Plan B (using XCFramework)
    # "Kingfisher:Kingfisher" - Removed: MSPKingfisher/Sources doesn't exist during pre_install
    #                          (downloaded via podspec prepare_command during pod install)
)

# Project and output directories
THIRDPARTY_PROJECT_DIR="$ROOT_DIR/Examples/ThirdPartyFrameworks"
THIRDPARTY_PROJECT="$THIRDPARTY_PROJECT_DIR/ThirdPartyFrameworks.xcodeproj"
ARCHIVES_DIR="$ROOT_DIR/Build/ReleaseArtifacts/Archives/ThirdParty"
# Canonical output: ReleaseArtifacts/XCFrameworks
THIRDPARTY_OUTPUT_DIR="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks"
# Vendor SDKs source directory
THIRDPARTY_LINK_DIR="$ROOT_DIR/ThirdParty"
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
    log::warn "XCFW" "generate_project_templates.sh not found or not executable"
fi

# ============================================================================
# Generate Xcode Project
# ============================================================================

log_section "Generating ThirdPartyFrameworks Xcode project"

if [[ ! -f "$THIRDPARTY_PROJECT_DIR/project.yml" ]]; then
    log::error "XCFW" "project.yml not found at $THIRDPARTY_PROJECT_DIR"
    log::error "XCFW" "Make sure project.yml.template exists and generate_project_templates.sh ran successfully"
    exit 1
fi

# Generate project from project.yml
log::step "XCFW" "Running XcodeGen"
# R029f: Use xcodegen.sh module if available, fallback to direct call
thirdparty_xcodegen_success=false
if command -v xcodegen_generate &>/dev/null; then
    if xcodegen_generate "$THIRDPARTY_PROJECT_DIR/project.yml" "$THIRDPARTY_PROJECT_DIR"; then
        thirdparty_xcodegen_success=true
    fi
else
    if (cd "$THIRDPARTY_PROJECT_DIR" && xcodegen generate --spec project.yml); then
        thirdparty_xcodegen_success=true
    fi
fi

if [[ "$thirdparty_xcodegen_success" != "true" ]]; then
    log::error "XCFW" "Failed to generate Xcode project"
    exit 1
fi

if [[ ! -d "$THIRDPARTY_PROJECT" ]]; then
    log::error "XCFW" "XcodeGen did not create project: $THIRDPARTY_PROJECT"
    exit 1
fi

log::success "XCFW" "ThirdPartyFrameworks.xcodeproj generated"

# ============================================================================
# Build XCFrameworks
# ============================================================================

build_single_xcframework() {
    local scheme_name="$1"
    local output_name="$2"

    local ios_archive="$ARCHIVES_DIR/${output_name}-iOS.xcarchive"
    local sim_archive="$ARCHIVES_DIR/${output_name}-Simulator.xcarchive"
    local output_dir="$THIRDPARTY_OUTPUT_DIR"
    local xcframework_output="$output_dir/${output_name}.xcframework"

    log_section "Building $output_name"

    rm -rf "$ios_archive" "$sim_archive"
    mkdir -p "$ARCHIVES_DIR"
    mkdir -p "$output_dir"

    # Disable autolink for UIUtilities (private Apple framework that causes pod lint failures)
    # This prevents LC_LINKER_OPTION commands for UIUtilities from being embedded in the binary
    local AUTOLINK_DISABLE_FLAGS="-Xfrontend -disable-autolink-framework -Xfrontend UIUtilities"

    # Archive for iOS device
    log::step "XCFW" "Archiving $output_name for iOS device"
    if ! xcodebuild archive \
        -project "$THIRDPARTY_PROJECT" \
        -scheme "$scheme_name" \
        -configuration Release \
        -destination "generic/platform=iOS" \
        -archivePath "$ios_archive" \
        -derivedDataPath "$DERIVED_DATA" \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        SKIP_INSTALL=NO \
        OTHER_SWIFT_FLAGS="\$(inherited) $AUTOLINK_DISABLE_FLAGS" \
        -quiet 2>&1; then
        log::error "XCFW" "iOS archive failed for $output_name"
        return 1
    fi

    # Archive for iOS Simulator
    log::step "XCFW" "Archiving $output_name for iOS Simulator"
    if ! xcodebuild archive \
        -project "$THIRDPARTY_PROJECT" \
        -scheme "$scheme_name" \
        -configuration Release \
        -destination "generic/platform=iOS Simulator" \
        -archivePath "$sim_archive" \
        -derivedDataPath "$DERIVED_DATA" \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        SKIP_INSTALL=NO \
        OTHER_SWIFT_FLAGS="\$(inherited) $AUTOLINK_DISABLE_FLAGS" \
        -quiet 2>&1; then
        log::error "XCFW" "Simulator archive failed for $output_name"
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
        log::error "XCFW" "iOS framework not found in archive for $output_name"
        log::info "XCFW" "Archive contents:"
        find "$ios_archive/Products" -type d -name "*.framework" 2>/dev/null || true
        return 1
    fi
    
    if [[ -z "$sim_framework" ]] || [[ ! -d "$sim_framework" ]]; then
        log::error "XCFW" "Simulator framework not found in archive for $output_name"
        return 1
    fi
    
    log::info "XCFW" "Found iOS framework: $ios_framework"
    log::info "XCFW" "Found Simulator framework: $sim_framework"
    
    log::step "XCFW" "Creating XCFramework for $output_name"
    rm -rf "$xcframework_output"
    
    if ! xcodebuild -create-xcframework \
        -framework "$ios_framework" \
        -framework "$sim_framework" \
        -output "$xcframework_output" 2>&1; then
        log::error "XCFW" "Failed to create XCFramework for $output_name"
        return 1
    fi
    
    if [[ ! -d "$xcframework_output" ]]; then
        log::error "XCFW" "XCFramework not created: $xcframework_output"
        return 1
    fi
    
    log::success "XCFW" "$output_name.xcframework created successfully"
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
# Summary Report
# ============================================================================

log_title "Third-Party XCFramework Build Summary"

printf "\n"
printf "┌─────────────────────────────────────────────────────────────────┐\n"
printf "│                   BUILD RESULTS                                 │\n"
printf "├─────────────────────────────────────────────────────────────────┤\n"

for target_spec in "${THIRDPARTY_TARGETS[@]}"; do
    IFS=':' read -r scheme_name output_name <<< "$target_spec"
    xcf_path="$THIRDPARTY_OUTPUT_DIR/$output_name.xcframework"
    
    if [[ -d "$xcf_path" ]]; then
        printf "│ %-25s │ %-10s │ ReleaseArtifacts/%-10s │\n" "$output_name" "✅ OK" "XCFrameworks"
    else
        printf "│ %-25s │ %-10s │ %-27s │\n" "$output_name" "❌ MISSING" "-"
    fi
done

printf "├─────────────────────────────────────────────────────────────────┤\n"
printf "│ Success: %-3d                    Failed: %-3d                   │\n" "$SUCCESS_COUNT" "$FAIL_COUNT"
printf "└─────────────────────────────────────────────────────────────────┘\n"

if [[ $FAIL_COUNT -gt 0 ]]; then
    log::error "XCFW" "Failed to build $FAIL_COUNT third-party XCFramework(s): ${FAILED_MODULES[*]}"
    exit 1
fi

log::success "XCFW" "All third-party XCFrameworks built successfully!"
log::info "XCFW" "Output directory: $THIRDPARTY_OUTPUT_DIR"

# ============================================================================
# Copy built XCFrameworks back to ThirdParty/ for Podfile pre_install check
# ============================================================================
# The Podfile pre_install hook expects XCFrameworks at ThirdParty/{name}/{name}.xcframework
# This ensures pod install works correctly after build-thirdparty.sh runs

log_section "Copying built XCFrameworks to ThirdParty/ (for Podfile compatibility)"

for target_spec in "${THIRDPARTY_TARGETS[@]}"; do
    IFS=':' read -r scheme_name output_name <<< "$target_spec"
    source_xcf="$THIRDPARTY_OUTPUT_DIR/$output_name.xcframework"
    target_dir="$THIRDPARTY_LINK_DIR/$output_name"
    target_xcf="$target_dir/$output_name.xcframework"
    
    if [[ -d "$source_xcf" ]]; then
        mkdir -p "$target_dir"
        rm -rf "$target_xcf"
        if ditto "$source_xcf" "$target_xcf"; then
            log::info "XCFW" "  Copied: ThirdParty/$output_name/$output_name.xcframework <- ReleaseArtifacts"
        else
            log::warn "XCFW" "  Failed to copy: $output_name.xcframework to ThirdParty/$output_name/"
        fi
    fi
done

log::success "XCFW" "Built XCFrameworks synced to ThirdParty/"

# ============================================================================
# Ensure vendor-provided XCFrameworks are available in ReleaseArtifacts
# ============================================================================

log_section "Copying vendor XCFrameworks into ReleaseArtifacts/XCFrameworks"

# Note: Kingfisher is not built from source (MSPKingfisher/Sources not available during pre_install)
# but the pre-built XCFramework in ThirdParty/Kingfisher/ needs to be copied for NovaAdapter builds
VENDOR_XCFS=("PrebidMobile" "Shimmer" "Kingfisher")
for name in "${VENDOR_XCFS[@]}"; do
    source_xcf="$THIRDPARTY_LINK_DIR/$name/$name.xcframework"
    target_xcf="$THIRDPARTY_OUTPUT_DIR/$name.xcframework"
    if [[ -d "$source_xcf" ]]; then
        rm -rf "$target_xcf"
        if ditto "$source_xcf" "$target_xcf"; then
            log::info "XCFW" "  Copied: Build/ReleaseArtifacts/XCFrameworks/$name.xcframework <- ThirdParty/$name/$name.xcframework"
        else
            log::warn "XCFW" "  Failed to copy: $name.xcframework from ThirdParty/$name/"
        fi
    else
        log::warn "XCFW" "  Skipping: $name.xcframework not found in ThirdParty/$name/"
    fi
done

log::success "XCFW" "Third-party XCFrameworks ready in ReleaseArtifacts/XCFrameworks"
