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
# Try new structure first (Sources/Core/ or Sources/Adapters/), fallback to old
if [[ -f "$ROOT_DIR/Sources/Core/$MODULE_NAME/project.yml" ]]; then
    PROJECT_YML="$ROOT_DIR/Sources/Core/$MODULE_NAME/project.yml"
elif [[ -f "$ROOT_DIR/Sources/Adapters/$MODULE_NAME/project.yml" ]]; then
    PROJECT_YML="$ROOT_DIR/Sources/Adapters/$MODULE_NAME/project.yml"
elif [[ -f "$ROOT_DIR/Sources/SharedLibraries/$MODULE_NAME/project.yml" ]]; then
    PROJECT_YML="$ROOT_DIR/Sources/SharedLibraries/$MODULE_NAME/project.yml"
elif [[ -f "$ROOT_DIR/$MODULE_NAME/project.yml" ]]; then
    PROJECT_YML="$ROOT_DIR/$MODULE_NAME/project.yml"
else
    log_error "project.yml not found for $MODULE_NAME"
    exit 1
fi

if [[ ! -f "$PROJECT_YML" ]]; then
    log_error "project.yml not found: $PROJECT_YML"
    exit 1
fi

log_title "Building XCFramework: $MODULE_NAME"

# Create output directories
ARCHIVES_DIR="$ROOT_DIR/Build/Archives"
XCFRAMEWORKS_DIR="$ROOT_DIR/Build/XCFrameworks"
mkdir -p "$ARCHIVES_DIR" "$XCFRAMEWORKS_DIR"

# Generate Xcode project from project.yml
# Run xcodegen from the project directory to ensure relative paths resolve correctly
log_step "Generating Xcode project from project.yml"
PROJECT_DIR=$(dirname "$PROJECT_YML")
if ! (cd "$PROJECT_DIR" && xcodegen generate --spec "$(basename "$PROJECT_YML")"); then
    log_error "Failed to generate Xcode project for $MODULE_NAME"
    exit 1
fi

# Verify project was generated
# Determine project location based on module location
if [[ -f "$ROOT_DIR/Sources/Core/$MODULE_NAME/project.yml" ]]; then
    XCODEPROJ="$ROOT_DIR/Sources/Core/$MODULE_NAME/$MODULE_NAME.xcodeproj"
elif [[ -f "$ROOT_DIR/Sources/Adapters/$MODULE_NAME/project.yml" ]]; then
    XCODEPROJ="$ROOT_DIR/Sources/Adapters/$MODULE_NAME/$MODULE_NAME.xcodeproj"
elif [[ -f "$ROOT_DIR/Sources/SharedLibraries/$MODULE_NAME/project.yml" ]]; then
    XCODEPROJ="$ROOT_DIR/Sources/SharedLibraries/$MODULE_NAME/$MODULE_NAME.xcodeproj"
else
    XCODEPROJ="$ROOT_DIR/$MODULE_NAME/$MODULE_NAME.xcodeproj"
fi
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
    DERIVED_DATA="$ROOT_DIR/.generated/DerivedData/build-$MODULE_NAME"
    log_info "Using module-specific DerivedData: $DERIVED_DATA"
fi
mkdir -p "$DERIVED_DATA"

# Archive paths
IOS_ARCHIVE="$ARCHIVES_DIR/$MODULE_NAME-iOS.xcarchive"
SIMULATOR_ARCHIVE="$ARCHIVES_DIR/$MODULE_NAME-Simulator.xcarchive"

# Clean previous archives
rm -rf "$IOS_ARCHIVE" "$SIMULATOR_ARCHIVE"

# Use workspace if available and scheme exists, otherwise use project
WORKSPACE="$ROOT_DIR/.generated/msp-ios-sdk.xcworkspace"
if [[ ! -d "$WORKSPACE" ]]; then
    WORKSPACE="$ROOT_DIR/msp-ios-sdk.xcworkspace"
fi

# Check if scheme exists in workspace
SCHEME_IN_WORKSPACE=false
if [[ -d "$WORKSPACE" ]]; then
    if xcodebuild -workspace "$WORKSPACE" -list 2>/dev/null | grep -qE "^\s*$SCHEME_NAME\s*$"; then
        SCHEME_IN_WORKSPACE=true
    fi
fi

if [[ "$SCHEME_IN_WORKSPACE" == "true" ]]; then
    BUILD_ARG="-workspace"
    BUILD_PATH="$WORKSPACE"
    log_info "Using workspace for Pods dependencies: $WORKSPACE"
else
    BUILD_ARG="-project"
    BUILD_PATH="$XCODEPROJ"
    log_warn "Scheme not in workspace, using project directly (Pods dependencies may not be available)"
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

# Extract PRODUCT_NAME from project.yml (fallback to MODULE_NAME if not found)
# First try global settings
PRODUCT_NAME=$(grep -E "^\s+PRODUCT_NAME:" "$PROJECT_YML" | head -1 | sed -E 's/.*PRODUCT_NAME:\s*["'\'']?([^"'\'']+)["'\'']?.*/\1/' | xargs || echo "")
# If not found, try target-specific settings
if [[ -z "$PRODUCT_NAME" ]]; then
    PRODUCT_NAME=$(grep -A 30 "targets:" "$PROJECT_YML" | grep -E "^\s+PRODUCT_NAME:" | head -1 | sed -E 's/.*PRODUCT_NAME:\s*["'\'']?([^"'\'']+)["'\'']?.*/\1/' | xargs || echo "")
fi
# Fallback to MODULE_NAME if still not found
PRODUCT_NAME="${PRODUCT_NAME:-$MODULE_NAME}"
log_info "Using PRODUCT_NAME: $PRODUCT_NAME (module: $MODULE_NAME)"

# Create XCFramework
log_step "Creating XCFramework"
# Use PRODUCT_NAME for XCFramework output name (matches framework name)
XCFRAMEWORK_OUTPUT="$XCFRAMEWORKS_DIR/$PRODUCT_NAME.xcframework"
rm -rf "$XCFRAMEWORK_OUTPUT"

xcodebuild -create-xcframework \
    -framework "$IOS_ARCHIVE/Products/Library/Frameworks/$PRODUCT_NAME.framework" \
    -framework "$SIMULATOR_ARCHIVE/Products/Library/Frameworks/$PRODUCT_NAME.framework" \
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
# Extract PRODUCT_MODULE_NAME from project.yml (fallback to PRODUCT_NAME)
PRODUCT_MODULE_NAME=$(grep -E "^\s*PRODUCT_MODULE_NAME:" "$PROJECT_YML" | head -1 | sed -E 's/.*PRODUCT_MODULE_NAME:\s*["'\'']?([^"'\'']+)["'\'']?.*/\1/' || echo "$PRODUCT_NAME")
if [[ -z "$PRODUCT_MODULE_NAME" ]] || [[ "$PRODUCT_MODULE_NAME" == "$MODULE_NAME" ]]; then
    # Try to get from target settings
    PRODUCT_MODULE_NAME=$(grep -A 20 "targets:" "$PROJECT_YML" | grep -E "^\s*PRODUCT_MODULE_NAME:" | head -1 | sed -E 's/.*PRODUCT_MODULE_NAME:\s*["'\'']?([^"'\'']+)["'\'']?.*/\1/' || echo "$PRODUCT_NAME")
fi
# Fallback to PRODUCT_NAME if still not found
PRODUCT_MODULE_NAME="${PRODUCT_MODULE_NAME:-$PRODUCT_NAME}"

SWIFT_MODULE="$XCFRAMEWORK_OUTPUT/ios-arm64/$PRODUCT_NAME.framework/Modules/$PRODUCT_MODULE_NAME.swiftmodule"
if [[ ! -d "$SWIFT_MODULE" ]] && [[ ! -f "$SWIFT_MODULE/arm64.swiftmodule" ]]; then
    log_warn "Swift module directory not found (may be normal for some modules)"
fi

log_success "XCFramework created: $XCFRAMEWORK_OUTPUT"

# Special handling for NovaCore: Copy to NovaAdapter/ folder (legacy compatibility)
# This ensures compatibility with scripts that expect NovaCore.xcframework in NovaAdapter/
if [[ "$MODULE_NAME" == "NovaCore" ]]; then
    log_step "Deploying NovaCore.xcframework to NovaAdapter (legacy compatibility)"
    NOVA_ADAPTER_DEST="$ROOT_DIR/NovaAdapter/NovaCore.xcframework"
    TEMP_DEST="$ROOT_DIR/NovaAdapter/NovaCore.xcframework.tmp"
    
    # Backup existing if present
    if [[ -d "$NOVA_ADAPTER_DEST" ]]; then
        mv "$NOVA_ADAPTER_DEST" "${NOVA_ADAPTER_DEST}.backup" 2>/dev/null || true
    fi
    
    # Atomic copy: copy to temp, then move
    if cp -R "$XCFRAMEWORK_OUTPUT" "$TEMP_DEST"; then
        mv "$TEMP_DEST" "$NOVA_ADAPTER_DEST"
        rm -rf "${NOVA_ADAPTER_DEST}.backup" 2>/dev/null || true
        log_success "NovaCore.xcframework deployed to NovaAdapter/"
    else
        log_warn "Failed to copy NovaCore.xcframework to NovaAdapter (continuing anyway)"
        # Restore backup if copy failed
        mv "${NOVA_ADAPTER_DEST}.backup" "$NOVA_ADAPTER_DEST" 2>/dev/null || true
    fi
fi

