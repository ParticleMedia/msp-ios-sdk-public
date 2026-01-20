#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# Generic XCFramework builder for CocoaPods SDKs
# Supports both building from source and copying pre-built xcframeworks
#
# Usage:
#   Build from source:
#     ./Scripts/xcframeworks/builder.sh --scheme <SchemeName> --output <WrapperName> --sdk-name <SDKName> [--pods-project <path>]
#   Copy pre-built:
#     ./Scripts/xcframeworks/builder.sh --copy --source-path <path> --output <WrapperName> --sdk-name <SDKName>

set -euo pipefail

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/lib/paths.sh
source "$ROOT_DIR/Scripts/lib/paths.sh"

# Initialize paths
init_paths

PODS_PROJECT="${PODS_PROJECT:-$ROOT_DIR/Pods/Pods.xcodeproj}"
MODE=""
SCHEME=""
OUTPUT_WRAPPER=""
SDK_NAME=""
SOURCE_XCFRAMEWORK=""
PODS_DIR=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --scheme)
      SCHEME="$2"
      MODE="build"
      shift 2
      ;;
    --copy)
      MODE="copy"
      shift
      ;;
    --source-path)
      SOURCE_XCFRAMEWORK="$2"
      shift 2
      ;;
    --output)
      OUTPUT_WRAPPER="$2"
      shift 2
      ;;
    --sdk-name)
      SDK_NAME="$2"
      shift 2
      ;;
    --pods-project)
      PODS_PROJECT="$2"
      shift 2
      ;;
    --pods-dir)
      PODS_DIR="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      echo "Usage: $0 [--scheme <name> | --copy] --output <WrapperName> --sdk-name <SDKName> [--source-path <path>] [--pods-project <path>] [--pods-dir <path>]" >&2
      exit 1
      ;;
  esac
done

# Validate required parameters
if [[ -z "$OUTPUT_WRAPPER" ]]; then
  echo "ERROR: --output is required" >&2
  exit 1
fi

if [[ -z "$SDK_NAME" ]]; then
  echo "ERROR: --sdk-name is required" >&2
  exit 1
fi

# Set defaults
if [[ -z "$PODS_DIR" ]]; then
  PODS_DIR="$ROOT_DIR/Pods/$SDK_NAME"
fi

# Output to temp directory to avoid git tracking
OUTPUT_TEMP_DIR="$ROOT_DIR/Scripts/xcframeworks/output-temp"
OUTPUT_DIR="$OUTPUT_TEMP_DIR/$OUTPUT_WRAPPER/Frameworks"
XCFRAMEWORK_PATH="$OUTPUT_DIR/$SDK_NAME.xcframework"
# Final destination in wrapper package (for Package.swift reference)
FINAL_DIR="$ROOT_DIR/$OUTPUT_WRAPPER/Frameworks"
FINAL_XCFRAMEWORK_PATH="$FINAL_DIR/$SDK_NAME.xcframework"

echo "== $SDK_NAME XCFramework Builder =="

# Validate mode and parameters
if [[ "$MODE" == "build" ]]; then
  if [[ -z "$SCHEME" ]]; then
    echo "ERROR: --scheme is required for build mode" >&2
    exit 1
  fi
  
  if [[ ! -d "$PODS_DIR" ]]; then
    echo "ERROR: $PODS_DIR not found. Run 'bundle exec pod install' first." >&2
    exit 1
  fi
  
  if [[ ! -d "$PODS_PROJECT" ]]; then
    echo "ERROR: $PODS_PROJECT not found. Ensure CocoaPods has generated Pods.xcodeproj." >&2
    exit 1
  fi
  
elif [[ "$MODE" == "copy" ]]; then
  if [[ -z "$SOURCE_XCFRAMEWORK" ]]; then
    echo "ERROR: --source-path is required for copy mode" >&2
    exit 1
  fi
  
  if [[ ! -d "$PODS_DIR" ]]; then
    echo "ERROR: $PODS_DIR not found. Run 'bundle exec pod install' first." >&2
    exit 1
  fi
  
  if [[ ! -d "$SOURCE_XCFRAMEWORK" ]]; then
    echo "ERROR: $SOURCE_XCFRAMEWORK not found." >&2
    exit 1
  fi
else
  echo "ERROR: Must specify either --scheme (build mode) or --copy (copy mode)" >&2
  exit 1
fi

# Clean previous artifacts
rm -rf "$XCFRAMEWORK_PATH"
mkdir -p "$OUTPUT_DIR"

if [[ "$MODE" == "copy" ]]; then
  # Copy mode: Simply copy the pre-built xcframework
  echo "-- Copying pre-built xcframework"
  cp -R "$SOURCE_XCFRAMEWORK" "$XCFRAMEWORK_PATH"
  # Copy to final destination (Frameworks/ in wrapper package)
  echo "-- Copying to final destination"
  mkdir -p "$FINAL_DIR"
  rm -rf "$FINAL_XCFRAMEWORK_PATH"
  cp -R "$XCFRAMEWORK_PATH" "$FINAL_XCFRAMEWORK_PATH"
  echo "== Done =="
  echo "Temp output: $XCFRAMEWORK_PATH"
  echo "Final output: $FINAL_XCFRAMEWORK_PATH"
  exit 0
fi

# Build mode: Build from CocoaPods source
# Create temp dir name (lowercase SDK name for directory)
TMP_DIR_NAME=$(echo "$SDK_NAME" | tr '[:upper:]' '[:lower:]')
TMP_DIR="$ROOT_DIR/.build-${TMP_DIR_NAME}-tmp"
BUILD_DIR="$TMP_DIR/build"
DERIVED_DATA="$TMP_DIR/derived"

# Clean temporary directories
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

build_arch() {
  local sdk="$1"
  echo "-- Building for $sdk"
  if command -v xcpretty >/dev/null 2>&1; then
    xcodebuild \
      -project "$PODS_PROJECT" \
      -scheme "$SCHEME" \
      -configuration Release \
      -sdk "$sdk" \
      BUILD_DIR="$BUILD_DIR" \
      DERIVED_DATA_PATH="$DERIVED_DATA" \
      BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
      SKIP_INSTALL=NO \
      ONLY_ACTIVE_ARCH=NO \
      clean build \
      | xcpretty || exit ${PIPESTATUS[0]}
  else
    echo "Warning: xcpretty not found, building without formatted output"
    xcodebuild \
      -project "$PODS_PROJECT" \
      -scheme "$SCHEME" \
      -configuration Release \
      -sdk "$sdk" \
      BUILD_DIR="$BUILD_DIR" \
      DERIVED_DATA_PATH="$DERIVED_DATA" \
      BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
      SKIP_INSTALL=NO \
      ONLY_ACTIVE_ARCH=NO \
      clean build
  fi
}

# Build device and simulator
build_arch iphoneos
build_arch iphonesimulator

# Locate built artifacts
IOS_LIB="$(find "$BUILD_DIR" -path "*Release-iphoneos*${SDK_NAME}*" \( -name "*.a" -o -name "*.framework" -type d \) -maxdepth 5 | head -n1)"
SIM_LIB="$(find "$BUILD_DIR" -path "*Release-iphonesimulator*${SDK_NAME}*" \( -name "*.a" -o -name "*.framework" -type d \) -maxdepth 5 | head -n1)"

# Check if frameworks were built directly
IOS_FRAMEWORK="$(find "$BUILD_DIR" -path "*Release-iphoneos*${SDK_NAME}.framework" -maxdepth 5 -type d | head -n1)"
SIM_FRAMEWORK="$(find "$BUILD_DIR" -path "*Release-iphonesimulator*${SDK_NAME}.framework" -maxdepth 5 -type d | head -n1)"

if [[ -n "$IOS_FRAMEWORK" && -n "$SIM_FRAMEWORK" ]]; then
  # Frameworks were built directly
  echo "-- Using pre-built frameworks"
  IOS_FRAMEWORK_DIR="$IOS_FRAMEWORK"
  SIM_FRAMEWORK_DIR="$SIM_FRAMEWORK"
elif [[ -n "$IOS_LIB" && -n "$SIM_LIB" ]]; then
  # Need to create frameworks from libraries
  echo "-- Creating frameworks from libraries"
  
  # Helper function to create a framework from a library
  create_framework() {
    local sdk="$1"
    local lib_path="$2"
    local framework_dir="$3"
    
    echo "-- Creating framework for $sdk"
    mkdir -p "$framework_dir/Headers"
    mkdir -p "$framework_dir/Modules"
    
    # Check if lib_path is a framework or static library
    if [[ -d "$lib_path" && "$lib_path" == *.framework ]]; then
      # It's already a framework, copy it
      cp -R "$lib_path"/* "$framework_dir/"
    else
      # It's a static library, create framework structure
      cp "$lib_path" "$framework_dir/$SDK_NAME"
      
      # Copy headers from Pods
      if [[ -d "$PODS_DIR" ]]; then
        find "$PODS_DIR" -name "*.h" -exec cp {} "$framework_dir/Headers/" \;
      fi
      
      # Create Info.plist
      BUNDLE_ID=$(echo "$SDK_NAME" | tr '[:upper:]' '[:lower:]')
      cat > "$framework_dir/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$SDK_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>com.${BUNDLE_ID}.${SDK_NAME}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$SDK_NAME</string>
  <key>CFBundlePackageType</key>
  <string>FMWK</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>MinimumOSVersion</key>
  <string>12.0</string>
</dict>
</plist>
PLIST
      
      # Find umbrella header
      UMBRELLA_HEADER=$(find "$framework_dir/Headers" -name "*.h" -type f | head -n1 | xargs basename)
      if [[ -z "$UMBRELLA_HEADER" ]]; then
        UMBRELLA_HEADER="${SDK_NAME}.h"
      fi
      
      # Create module.modulemap
      cat > "$framework_dir/Modules/module.modulemap" <<MODULEMAP
framework module $SDK_NAME {
  umbrella header "${UMBRELLA_HEADER}"
  
  export *
  module * { export * }
}
MODULEMAP
      
      # Create umbrella header if it doesn't exist
      if [[ ! -f "$framework_dir/Headers/${UMBRELLA_HEADER}" ]]; then
        cat > "$framework_dir/Headers/${UMBRELLA_HEADER}" <<UMBRELLA
#import <Foundation/Foundation.h>
UMBRELLA
        # Add all headers
        find "$framework_dir/Headers" -name "*.h" ! -name "${UMBRELLA_HEADER}" -type f | while read header; do
          echo "#import \"$(basename "$header")\"" >> "$framework_dir/Headers/${UMBRELLA_HEADER}"
        done
      fi
    fi
  }
  
  IOS_FRAMEWORK_DIR="$TMP_DIR/ios-framework/${SDK_NAME}.framework"
  SIM_FRAMEWORK_DIR="$TMP_DIR/sim-framework/${SDK_NAME}.framework"
  
  create_framework "iphoneos" "$IOS_LIB" "$IOS_FRAMEWORK_DIR"
  create_framework "iphonesimulator" "$SIM_LIB" "$SIM_FRAMEWORK_DIR"
else
  echo "ERROR: Could not locate built $SDK_NAME for both platforms." >&2
  echo "Device: $IOS_LIB" >&2
  echo "Simulator: $SIM_LIB" >&2
  exit 1
fi

echo "-- Creating xcframework"
xcodebuild -create-xcframework \
  -framework "$IOS_FRAMEWORK_DIR" \
  -framework "$SIM_FRAMEWORK_DIR" \
  -output "$XCFRAMEWORK_PATH"

# Copy to final destination (Frameworks/ in wrapper package)
# This location is referenced by Package.swift but is gitignored
echo "-- Copying to final destination"
mkdir -p "$FINAL_DIR"
rm -rf "$FINAL_XCFRAMEWORK_PATH"
cp -R "$XCFRAMEWORK_PATH" "$FINAL_XCFRAMEWORK_PATH"

# Clean up temporary build artifacts
echo "-- Cleaning up temporary files"
rm -rf "$TMP_DIR"

echo "== Done =="
echo "Temp output: $XCFRAMEWORK_PATH"
echo "Final output: $FINAL_XCFRAMEWORK_PATH"

