#!/bin/bash
# ============================================================================
# XCFramework Builder for Single Module
# ============================================================================
# Purpose: Build a single module into .xcframework using XcodeGen project.yml
# Usage:   ./Scripts/xcframeworks/build_module.sh <ModuleName>
# ============================================================================

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/target-switching/common.sh
source "$SCRIPT_DIR/../target-switching/common.sh"

ensure_repo_root

MODULE_NAME="${1:-}"
if [[ -z "$MODULE_NAME" ]]; then
    log_error "Module name required"
    log_info "Usage: $0 <ModuleName>"
    exit 1
fi

SCHEME_NAME="$MODULE_NAME"
PROJECT_YML="$ROOT_DIR/$MODULE_NAME/project.yml"

if [[ ! -f "$PROJECT_YML" ]]; then
    log_error "project.yml not found: $PROJECT_YML"
    exit 1
fi

log_title "Building XCFramework: $MODULE_NAME"

# Create output directories
ARCHIVES_DIR="$ROOT_DIR/build/archives"
XCFRAMEWORKS_DIR="$ROOT_DIR/build/XCFrameworks"
mkdir -p "$ARCHIVES_DIR" "$XCFRAMEWORKS_DIR"

# Generate Xcode project from project.yml
log_step "Generating Xcode project from project.yml"
if ! xcodegen generate --spec "$PROJECT_YML"; then
    log_error "Failed to generate Xcode project for $MODULE_NAME"
    exit 1
fi

# Verify project was generated
XCODEPROJ="$ROOT_DIR/$MODULE_NAME/$MODULE_NAME.xcodeproj"
if [[ ! -d "$XCODEPROJ" ]]; then
    log_error "Xcode project not generated: $XCODEPROJ"
    exit 1
fi

# DerivedData path - use shared path if Pods were pre-built, otherwise use module-specific
SHARED_DERIVED_DATA="$ROOT_DIR/DerivedData/build-shared"
if [[ -d "$SHARED_DERIVED_DATA" ]] && [[ -d "$SHARED_DERIVED_DATA/Build/Products/Release-iphoneos" ]]; then
    # Use shared DerivedData so pre-built Pods are available during archive
    DERIVED_DATA="$SHARED_DERIVED_DATA"
    log_info "Using shared DerivedData (Pods pre-built): $DERIVED_DATA"
else
    # Use module-specific DerivedData if Pods weren't pre-built
    DERIVED_DATA="$ROOT_DIR/DerivedData/build-$MODULE_NAME"
    log_info "Using module-specific DerivedData: $DERIVED_DATA"
fi
mkdir -p "$DERIVED_DATA"

# Archive paths
IOS_ARCHIVE="$ARCHIVES_DIR/$MODULE_NAME-iOS.xcarchive"
SIMULATOR_ARCHIVE="$ARCHIVES_DIR/$MODULE_NAME-Simulator.xcarchive"

# Clean previous archives
rm -rf "$IOS_ARCHIVE" "$SIMULATOR_ARCHIVE"

# Use workspace if available (for Pods dependencies), otherwise use project
WORKSPACE="$ROOT_DIR/msp-ios-sdk.xcworkspace"
if [[ -d "$WORKSPACE" ]]; then
    BUILD_ARG="-workspace"
    BUILD_PATH="$WORKSPACE"
    log_info "Using workspace for Pods dependencies: $WORKSPACE"
else
    BUILD_ARG="-project"
    BUILD_PATH="$XCODEPROJ"
    log_warn "Workspace not found, using project (Pods dependencies may not be available)"
fi

# Build iOS device archive
log_step "Building iOS device archive"
# Add verification skip flags for Pods targets (applies to all targets in workspace)
# These settings are overridden by project.yml for MSP modules, so they only affect Pods
xcodebuild archive \
    "$BUILD_ARG" "$BUILD_PATH" \
    -scheme "$SCHEME_NAME" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$IOS_ARCHIVE" \
    -derivedDataPath "$DERIVED_DATA" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    SWIFT_VERIFY_EMITTED_MODULE_INTERFACE=NO \
    OTHER_SWIFT_FLAGS="-no-verify-emitted-module-interface" \
    -allowProvisioningUpdates

if [[ ! -d "$IOS_ARCHIVE" ]]; then
    log_error "iOS archive not created: $IOS_ARCHIVE"
    exit 1
fi

# Build iOS Simulator archive
log_step "Building iOS Simulator archive"
# Add verification skip flags for Pods targets (applies to all targets in workspace)
# These settings are overridden by project.yml for MSP modules, so they only affect Pods
xcodebuild archive \
    "$BUILD_ARG" "$BUILD_PATH" \
    -scheme "$SCHEME_NAME" \
    -configuration Release \
    -destination "generic/platform=iOS Simulator" \
    -archivePath "$SIMULATOR_ARCHIVE" \
    -derivedDataPath "$DERIVED_DATA" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    SWIFT_VERIFY_EMITTED_MODULE_INTERFACE=NO \
    OTHER_SWIFT_FLAGS="-no-verify-emitted-module-interface" \
    -allowProvisioningUpdates

if [[ ! -d "$SIMULATOR_ARCHIVE" ]]; then
    log_error "Simulator archive not created: $SIMULATOR_ARCHIVE"
    exit 1
fi

# Create XCFramework
log_step "Creating XCFramework"
XCFRAMEWORK_OUTPUT="$XCFRAMEWORKS_DIR/$MODULE_NAME.xcframework"
rm -rf "$XCFRAMEWORK_OUTPUT"

xcodebuild -create-xcframework \
    -framework "$IOS_ARCHIVE/Products/Library/Frameworks/$MODULE_NAME.framework" \
    -framework "$SIMULATOR_ARCHIVE/Products/Library/Frameworks/$MODULE_NAME.framework" \
    -output "$XCFRAMEWORK_OUTPUT"

if [[ ! -d "$XCFRAMEWORK_OUTPUT" ]]; then
    log_error "XCFramework not created: $XCFRAMEWORK_OUTPUT"
    exit 1
fi

# Verify XCFramework structure
log_step "Verifying XCFramework structure"
if [[ ! -d "$XCFRAMEWORK_OUTPUT/ios-arm64" ]] && [[ ! -d "$XCFRAMEWORK_OUTPUT/ios-arm64_x86_64-simulator" ]]; then
    log_error "XCFramework missing required slices"
    exit 1
fi

# Verify Swift module exists
SWIFT_MODULE="$XCFRAMEWORK_OUTPUT/ios-arm64/$MODULE_NAME.framework/Modules/$MODULE_NAME.swiftmodule"
if [[ ! -d "$SWIFT_MODULE" ]] && [[ ! -f "$SWIFT_MODULE/arm64.swiftmodule" ]]; then
    log_warn "Swift module directory not found (may be normal for some modules)"
fi

log_success "XCFramework created: $XCFRAMEWORK_OUTPUT"

