#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# YAML-Only Workspace Generation
# ============================================================================
# Purpose: Generate ONLY YAML spec files (project.yml, workspace.yml) based on
#          current mode (SPM or Pods). NEVER modifies Xcode-generated files.
#
# Usage:   ./Scripts/target-switching/generate_workspace.sh [spm|pods]
# ============================================================================

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/target-switching/common.sh
source "$SCRIPT_DIR/common.sh"

ensure_repo_root

INFO_PLIST_TEMPLATE="$ROOT_DIR/Examples/MSPDemoApp/Info.plist.template"
INFO_PLIST_OUTPUT="$ROOT_DIR/Examples/MSPDemoApp/MSPDemoApp/Info.plist"

generate_info_plist() {
    log_step "Generating Info.plist from template"

    if [[ -f "$INFO_PLIST_TEMPLATE" ]]; then
        cp "$INFO_PLIST_TEMPLATE" "$INFO_PLIST_OUTPUT"
        log_success "Info.plist generated"
    else
        log_warn "Info.plist.template not found - skipping"
    fi
}

TARGET_MODE="${1:-}"
if [[ -z "$TARGET_MODE" ]]; then
    # Auto-detect mode
    TARGET_MODE=$(detect_current_mode)
    if [[ "$TARGET_MODE" == "mixed" ]]; then
        log_error "Cannot auto-detect mode (mixed environment detected)"
        log_info "Please specify: $0 [spm|pods]"
        exit 1
    fi
fi

# Normalize modes: 
#   - pods-dev and pods-release both use "pods" workspace generation
#   - spm-release uses "spm" workspace generation
# The difference is in MSP_RELEASE environment variable (handled by podspecs)
EFFECTIVE_MODE="$TARGET_MODE"
if [[ "$TARGET_MODE" == "pods-dev" ]] || [[ "$TARGET_MODE" == "pods-release" ]]; then
    EFFECTIVE_MODE="pods"
    log_info "Mode '$TARGET_MODE' uses Pods workspace generation (MSP_RELEASE controls source vs binary)"
elif [[ "$TARGET_MODE" == "spm-release" ]]; then
    EFFECTIVE_MODE="spm"
    log_info "Mode '$TARGET_MODE' uses SPM workspace generation"
fi

if [[ "$EFFECTIVE_MODE" != "spm" ]] && [[ "$EFFECTIVE_MODE" != "pods" ]]; then
    log_error "Invalid mode. Must be 'spm', 'pods', 'pods-dev', 'pods-release', or 'spm-release'"
    exit 1
fi

log_title "Generating YAML Specs: $TARGET_MODE mode (effective: $EFFECTIVE_MODE)"

generate_info_plist

# Find all Package.swift files (sorted for determinism)
# NOTE: In Pods mode, Package.swift is renamed to Package.swift.disabled, so this may be empty
PACKAGE_FILES=()
while IFS= read -r pkg_file; do
    [[ -n "$pkg_file" ]] && PACKAGE_FILES+=("$pkg_file")
done < <(find "$ROOT_DIR" -name Package.swift \
    ! -path '*/Pods/*' ! -path '*/DerivedData/*' ! -path '*/.build/*' \
    ! -path '*/Sources/Wrappers/*' \
    -print 2>/dev/null | LC_ALL=C sort || true)

PACKAGE_NAMES=()
PACKAGE_REL_PATHS=()
if [[ ${#PACKAGE_FILES[@]} -gt 0 ]]; then
    for pkg in "${PACKAGE_FILES[@]}"; do
        pkg_dir="${pkg%/Package.swift}"
        pkg_name="$(basename "$pkg_dir")"
        # Handle root Package.swift specially
        if [[ "$pkg_dir" == "$ROOT_DIR" ]]; then
            rel_path=""
        else
            rel_path="${pkg_dir#$ROOT_DIR/}"
        fi
        PACKAGE_NAMES+=("$pkg_name")
        PACKAGE_REL_PATHS+=("$rel_path")
    done
fi

# SPM app products (updated for new SDK architecture - Round 26)
# These match the 16 products defined in Package.swift
declare -a SPM_APP_PRODUCTS=(
    # Top-level product
    "MSPAds"
    # Core modules (XCFrameworks)
    "MSPSharedLibraries"
    "MSPiOSCore"
    "NovaCore"
    "MSPCore"
    "MSPOMSDK"
    # Adapter modules (Source)
    "MSPPrebidAdapter"
    "MSPGoogleAdapter"
    "MSPFacebookAdapter"
    "MSPNovaAdapter"
    "MSPAmazonAdapter"
    "UnityAdapter"
    "InmobiAdapter"
    "MobilefuseAdapter"
    "MintegralAdapter"
    "PubmaticAdapter"
)

package_exists() {
    local name="$1"
    if [[ ${#PACKAGE_NAMES[@]} -eq 0 ]]; then
        return 1
    fi
    for candidate in "${PACKAGE_NAMES[@]}"; do
        if [[ "$candidate" == "$name" ]]; then
            return 0
        fi
    done
    return 1
}

# Generate project.yml from template
log_section "Generating project.yml"
log_step "Generating project.yml"
mkdir -p "$(dirname "$PROJECT_SPEC")"

PROJECT_TEMPLATE="$ROOT_DIR/Examples/MSPDemoApp/project.yml.template"
TEMP_PROJECT_SPEC="${PROJECT_SPEC}.tmp"

if [[ ! -f "$PROJECT_TEMPLATE" ]]; then
    log_error "project.yml.template not found at: $PROJECT_TEMPLATE"
    exit 1
fi

PACKAGES_BLOCK_FILE="$(mktemp)"
PODS_SETTINGS_FILE="$(mktemp)"
MODE_TARGETS_FILE="$(mktemp)"
MODE_SCHEMES_FILE="$(mktemp)"

if [[ "$EFFECTIVE_MODE" == "pods" ]]; then
    echo "packages: {}" > "$PACKAGES_BLOCK_FILE"
elif [[ ${#PACKAGE_NAMES[@]} -eq 0 ]]; then
    echo "packages: {}" > "$PACKAGES_BLOCK_FILE"
else
    cat <<'YAML' > "$PACKAGES_BLOCK_FILE"
packages:
  msp-ios-sdk:
    path: ../..
YAML
fi

if [[ "$EFFECTIVE_MODE" == "pods" ]]; then
    cat <<'YAML' > "$PODS_SETTINGS_FILE"
        PODS_ROOT: "$(SRCROOT)/../../Pods"
        PODS_PODFILE_DIR_PATH: "$(SRCROOT)/../.."
YAML
fi

if [[ "$EFFECTIVE_MODE" == "pods" ]]; then
    XCCONFIG_DEBUG="../../Pods/Target Support Files/Pods-MSPDemoApp/Pods-MSPDemoApp.debug.xcconfig"
    XCCONFIG_RELEASE="../../Pods/Target Support Files/Pods-MSPDemoApp/Pods-MSPDemoApp.release.xcconfig"

    cat <<'YAML' > "$MODE_TARGETS_FILE"
  MSPDemoApp:
    templates:
      - BaseAppTarget
YAML
    PROJECT_DIR="$(dirname "$PROJECT_SPEC")"
    if [[ -f "$PROJECT_DIR/$XCCONFIG_DEBUG" ]] && [[ -f "$PROJECT_DIR/$XCCONFIG_RELEASE" ]]; then
        cat <<YAML >> "$MODE_TARGETS_FILE"
    configFiles:
      Debug: $XCCONFIG_DEBUG
      Release: $XCCONFIG_RELEASE
YAML
    fi

    if [[ "$TARGET_MODE" == "pods-release" ]]; then
        echo "pods-release: Adding [CP] Copy XCFrameworks and [CP] Embed Pods Frameworks phases" >&2
        cat <<'YAML' >> "$MODE_TARGETS_FILE"
    prebuildScripts:
      - name: "[CP] Copy XCFrameworks"
        script: |
          # Auto-run all xcframework staging scripts generated by CocoaPods
          # This copies xcframeworks to PODS_XCFRAMEWORKS_BUILD_DIR so Swift can find modules
          
          # Set up required environment variables that CocoaPods scripts expect
          export PODS_ROOT="${PODS_ROOT:-${SRCROOT}/../../Pods}"
          
          # Use BUILT_PRODUCTS_DIR which is reliably set by Xcode in all build phases
          # This is the most reliable way to determine where build products go
          if [ -n "${BUILT_PRODUCTS_DIR}" ]; then
            export PODS_CONFIGURATION_BUILD_DIR="${BUILT_PRODUCTS_DIR}"
          elif [ -n "${CONFIGURATION_BUILD_DIR}" ]; then
            export PODS_CONFIGURATION_BUILD_DIR="${CONFIGURATION_BUILD_DIR}"
          elif [ -n "${TARGET_BUILD_DIR}" ]; then
            export PODS_CONFIGURATION_BUILD_DIR="${TARGET_BUILD_DIR}"
          elif [ -n "${OBJROOT}" ]; then
            # OBJROOT is set early; derive the products path from it
            export PODS_CONFIGURATION_BUILD_DIR="$(dirname "${OBJROOT}")/Products/${CONFIGURATION}${EFFECTIVE_PLATFORM_NAME}"
          else
            echo "warning: [CP] Copy XCFrameworks: Cannot determine build directory"
            echo "warning: Available env: BUILT_PRODUCTS_DIR=${BUILT_PRODUCTS_DIR:-unset}, CONFIGURATION_BUILD_DIR=${CONFIGURATION_BUILD_DIR:-unset}"
            exit 0
          fi
          
          export PODS_XCFRAMEWORKS_BUILD_DIR="${PODS_CONFIGURATION_BUILD_DIR}/XCFrameworkIntermediates"
          
          # Ensure ARCHS and PLATFORM_NAME are available
          export ARCHS="${ARCHS:-arm64}"
          export PLATFORM_NAME="${PLATFORM_NAME:-iphonesimulator}"
          
          SCRIPTS_DIR="${PODS_ROOT}/Target Support Files"
          
          if [ ! -d "$SCRIPTS_DIR" ]; then
            echo "warning: [CP] Copy XCFrameworks: Scripts directory not found: $SCRIPTS_DIR"
            exit 0
          fi
          
          # Create destination directory
          mkdir -p "${PODS_XCFRAMEWORKS_BUILD_DIR}"
          
          echo "[MSP] Copying XCFrameworks to ${PODS_XCFRAMEWORKS_BUILD_DIR}..."
          echo "[MSP] ARCHS=${ARCHS}, PLATFORM_NAME=${PLATFORM_NAME}"
          
          SCRIPT_COUNT=0
          FAILED_SCRIPTS=0
          
          # Use find with -exec to avoid word-splitting issues with paths containing spaces
          # The {} is replaced by each found file, and \; ends the -exec command
          find "$SCRIPTS_DIR" -name "*-xcframeworks.sh" -type f 2>/dev/null | sort | while IFS= read -r script; do
            [ -z "$script" ] && continue
            echo "[MSP] Executing: $(basename "$script")"
            if /bin/sh "$script" 2>&1; then
              SCRIPT_COUNT=$((SCRIPT_COUNT + 1))
            else
              echo "warning: [MSP] Script failed: $(basename "$script")"
              FAILED_SCRIPTS=$((FAILED_SCRIPTS + 1))
            fi
          done
          
          # Note: SCRIPT_COUNT/FAILED_SCRIPTS are in a subshell due to pipe, so check directory
          ACTUAL_COUNT=$(find "$SCRIPTS_DIR" -name "*-xcframeworks.sh" -type f 2>/dev/null | wc -l | tr -d ' ')
          if [ "$ACTUAL_COUNT" -eq 0 ]; then
            echo "[MSP] No xcframework scripts found (this may be OK for source-only pods)"
          else
            echo "[MSP] Executed $ACTUAL_COUNT xcframework staging script(s)"
          fi
        shell: /bin/sh
        inputFiles: []
        outputFiles: []
      - name: "[CP] Check Pods Manifest.lock"
        script: |
          if [ -z "${PODS_PODFILE_DIR_PATH}" ] || [ -z "${PODS_ROOT}" ]; then
            echo "error: CocoaPods environment variables are not set." >&2
            exit 1
          fi
          if [ ! -e "${PODS_ROOT}/Manifest.lock" ] || [ ! -e "${PODS_PODFILE_DIR_PATH}/Podfile.lock" ]; then
            echo "error: Run 'pod install' to generate Pods/Manifest.lock." >&2
            exit 1
          fi
          if ! diff "${PODS_PODFILE_DIR_PATH}/Podfile.lock" "${PODS_ROOT}/Manifest.lock" >/dev/null; then
            echo "error: Podfile.lock and Manifest.lock are out of sync. Run 'pod install'." >&2
            exit 1
          fi
        shell: /bin/sh
    postbuildScripts:
      - name: "[CP] Copy Pods Resources"
        script: "\"${PODS_ROOT}/Target Support Files/Pods-MSPDemoApp/Pods-MSPDemoApp-resources.sh\""
        shell: /bin/sh
      - name: "[CP] Embed Pods Frameworks"
        script: "\"${PODS_ROOT}/Target Support Files/Pods-MSPDemoApp/Pods-MSPDemoApp-frameworks.sh\""
        shell: /bin/sh
YAML
    else
        echo "pods-dev: Including all CocoaPods phases (third-party XCFrameworks still need embedding)" >&2
        cat <<'YAML' >> "$MODE_TARGETS_FILE"
    prebuildScripts:
      - name: "[CP] Check Pods Manifest.lock"
        script: |
          if [ -z "${PODS_PODFILE_DIR_PATH}" ] || [ -z "${PODS_ROOT}" ]; then
            echo "error: CocoaPods environment variables are not set." >&2
            exit 1
          fi
          if [ ! -e "${PODS_ROOT}/Manifest.lock" ] || [ ! -e "${PODS_PODFILE_DIR_PATH}/Podfile.lock" ]; then
            echo "error: Run 'pod install' to generate Pods/Manifest.lock." >&2
            exit 1
          fi
          if ! diff "${PODS_PODFILE_DIR_PATH}/Podfile.lock" "${PODS_ROOT}/Manifest.lock" >/dev/null; then
            echo "error: Podfile.lock and Manifest.lock are out of sync. Run 'pod install'." >&2
            exit 1
          fi
        shell: /bin/sh
    postbuildScripts:
      - name: "[CP] Copy Pods Resources"
        script: "\"${PODS_ROOT}/Target Support Files/Pods-MSPDemoApp/Pods-MSPDemoApp-resources.sh\""
        shell: /bin/sh
      - name: "[CP] Embed Pods Frameworks"
        script: "\"${PODS_ROOT}/Target Support Files/Pods-MSPDemoApp/Pods-MSPDemoApp-frameworks.sh\""
        shell: /bin/sh
YAML
    fi

    cat <<'YAML' >> "$MODE_TARGETS_FILE"
  MSPDemoAppTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: MSPDemoAppTests
    settings:
      base:
        ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES: YES
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/MSPDemoApp.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/MSPDemoApp"
YAML
    if [[ -f "$PROJECT_DIR/$XCCONFIG_DEBUG" ]] && [[ -f "$PROJECT_DIR/$XCCONFIG_RELEASE" ]]; then
        cat <<YAML >> "$MODE_TARGETS_FILE"
    configFiles:
      Debug: $XCCONFIG_DEBUG
      Release: $XCCONFIG_RELEASE
YAML
    fi
    cat <<'YAML' >> "$MODE_TARGETS_FILE"
    dependencies:
      - target: MSPDemoApp
  MSPDemoAppUITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - path: MSPDemoAppUITests
    settings:
      base:
        ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES: YES
YAML
    if [[ -f "$PROJECT_DIR/$XCCONFIG_DEBUG" ]] && [[ -f "$PROJECT_DIR/$XCCONFIG_RELEASE" ]]; then
        cat <<YAML >> "$MODE_TARGETS_FILE"
    configFiles:
      Debug: $XCCONFIG_DEBUG
      Release: $XCCONFIG_RELEASE
YAML
    fi
    cat <<'YAML' >> "$MODE_TARGETS_FILE"
    dependencies:
      - target: MSPDemoApp
YAML

    cat <<'YAML' >> "$MODE_TARGETS_FILE"
  MSPCoreTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: ../../Tests/MSPCoreTests
        excludes:
          - "**/.DS_Store"
YAML
    if [[ -f "$PROJECT_DIR/../../Pods/Target Support Files/Pods-MSPCoreTests/Pods-MSPCoreTests.debug.xcconfig" ]] && \
       [[ -f "$PROJECT_DIR/../../Pods/Target Support Files/Pods-MSPCoreTests/Pods-MSPCoreTests.release.xcconfig" ]]; then
        cat <<'YAML' >> "$MODE_TARGETS_FILE"
    configFiles:
      Debug: ../../Pods/Target Support Files/Pods-MSPCoreTests/Pods-MSPCoreTests.debug.xcconfig
      Release: ../../Pods/Target Support Files/Pods-MSPCoreTests/Pods-MSPCoreTests.release.xcconfig
YAML
    fi
    cat <<'YAML' >> "$MODE_TARGETS_FILE"
    settings:
      base:
        ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES: "YES"
        SWIFT_VERSION: "5.0"
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/MSPDemoApp.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/MSPDemoApp"
        PODS_ROOT: "$(SRCROOT)/../../Pods"
        PODS_PODFILE_DIR_PATH: "$(SRCROOT)/../.."
    dependencies:
      - target: MSPDemoApp
YAML

    cat <<'YAML' >> "$MODE_TARGETS_FILE"
  MSPiOSCoreTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: ../../Tests/MSPiOSCoreTests
        excludes:
          - "**/.DS_Store"
YAML
    if [[ -f "$PROJECT_DIR/../../Pods/Target Support Files/Pods-MSPiOSCoreTests/Pods-MSPiOSCoreTests.debug.xcconfig" ]] && \
       [[ -f "$PROJECT_DIR/../../Pods/Target Support Files/Pods-MSPiOSCoreTests/Pods-MSPiOSCoreTests.release.xcconfig" ]]; then
        cat <<'YAML' >> "$MODE_TARGETS_FILE"
    configFiles:
      Debug: ../../Pods/Target Support Files/Pods-MSPiOSCoreTests/Pods-MSPiOSCoreTests.debug.xcconfig
      Release: ../../Pods/Target Support Files/Pods-MSPiOSCoreTests/Pods-MSPiOSCoreTests.release.xcconfig
YAML
    fi
    cat <<'YAML' >> "$MODE_TARGETS_FILE"
    settings:
      base:
        ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES: "YES"
        SWIFT_VERSION: "5.0"
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/MSPDemoApp.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/MSPDemoApp"
        PODS_ROOT: "$(SRCROOT)/../../Pods"
        PODS_PODFILE_DIR_PATH: "$(SRCROOT)/../.."
    dependencies:
      - target: MSPDemoApp
YAML

    cat <<'YAML' >> "$MODE_TARGETS_FILE"
  NovaCoreTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: ../../Tests/NovaCoreTests
        excludes:
          - "**/.DS_Store"
YAML
    if [[ -f "$PROJECT_DIR/../../Pods/Target Support Files/Pods-NovaCoreTests/Pods-NovaCoreTests.debug.xcconfig" ]] && \
       [[ -f "$PROJECT_DIR/../../Pods/Target Support Files/Pods-NovaCoreTests/Pods-NovaCoreTests.release.xcconfig" ]]; then
        cat <<'YAML' >> "$MODE_TARGETS_FILE"
    configFiles:
      Debug: ../../Pods/Target Support Files/Pods-NovaCoreTests/Pods-NovaCoreTests.debug.xcconfig
      Release: ../../Pods/Target Support Files/Pods-NovaCoreTests/Pods-NovaCoreTests.release.xcconfig
YAML
    fi
    cat <<'YAML' >> "$MODE_TARGETS_FILE"
    settings:
      base:
        ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES: "YES"
        SWIFT_VERSION: "5.0"
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/MSPDemoApp.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/MSPDemoApp"
        PODS_ROOT: "$(SRCROOT)/../../Pods"
        PODS_PODFILE_DIR_PATH: "$(SRCROOT)/../.."
    dependencies:
      - target: MSPDemoApp
YAML

    cat <<'YAML' >> "$MODE_TARGETS_FILE"
  AdapterTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: ../../Tests/AdapterTests
        excludes:
          - "**/.DS_Store"
YAML
    if [[ -f "$PROJECT_DIR/../../Pods/Target Support Files/Pods-AdapterTests/Pods-AdapterTests.debug.xcconfig" ]] && \
       [[ -f "$PROJECT_DIR/../../Pods/Target Support Files/Pods-AdapterTests/Pods-AdapterTests.release.xcconfig" ]]; then
        cat <<'YAML' >> "$MODE_TARGETS_FILE"
    configFiles:
      Debug: ../../Pods/Target Support Files/Pods-AdapterTests/Pods-AdapterTests.debug.xcconfig
      Release: ../../Pods/Target Support Files/Pods-AdapterTests/Pods-AdapterTests.release.xcconfig
YAML
    fi
    cat <<'YAML' >> "$MODE_TARGETS_FILE"
    settings:
      base:
        ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES: "YES"
        SWIFT_VERSION: "5.0"
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/MSPDemoApp.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/MSPDemoApp"
        PODS_ROOT: "$(SRCROOT)/../../Pods"
        PODS_PODFILE_DIR_PATH: "$(SRCROOT)/../.."
    dependencies:
      - target: MSPDemoApp
YAML
else
    cat <<'YAML' > "$MODE_TARGETS_FILE"
  MSPDemoApp-SPM:
    templates:
      - BaseAppTarget
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: MSPDemoApp.MSPDemoAppSPM
    configFiles:
      Debug: ../Configs/MSPDemoApp-Debug-SPM.xcconfig
      Release: ../Configs/MSPDemoApp-Release-SPM.xcconfig
    dependencies:
YAML
    for product in "${SPM_APP_PRODUCTS[@]}"; do
        cat <<YAML >> "$MODE_TARGETS_FILE"
      - package: msp-ios-sdk
        product: ${product}
YAML
    done
fi

if [[ "$EFFECTIVE_MODE" == "pods" ]]; then
    cat <<'YAML' > "$MODE_SCHEMES_FILE"
  MSPDemoApp:
    build:
      targets:
        MSPDemoApp: all
        MSPDemoAppTests: test
        MSPDemoAppUITests: test
    test:
      config: Debug
      gatherCoverageData: false
      targets:
        - target: MSPDemoAppTests
        - target: MSPDemoAppUITests
    run:
      config: Debug
    profile:
      config: Release
    analyze:
      config: Debug
    archive:
      config: Release
  AllTests:
    build:
      targets:
        MSPDemoApp: all
        MSPCoreTests: test
        MSPiOSCoreTests: test
        NovaCoreTests: test
        AdapterTests: test
    test:
      config: Debug
      gatherCoverageData: true
      targets:
        - MSPCoreTests
        - MSPiOSCoreTests
        - NovaCoreTests
        - AdapterTests
YAML
else
    cat <<'YAML' > "$MODE_SCHEMES_FILE"
  MSPDemoApp-SPM:
    build:
      targets:
        MSPDemoApp-SPM: all
    test:
      config: Debug
      targets: []
    run:
      config: Debug
    profile:
      config: Release
    analyze:
      config: Debug
    archive:
      config: Release
YAML
fi

{
    while IFS= read -r line; do
        if [[ "$line" == "{{ PACKAGES_BLOCK }}" ]]; then
            cat "$PACKAGES_BLOCK_FILE"
        elif [[ "$line" == "{{ PODS_SETTINGS }}" ]]; then
            cat "$PODS_SETTINGS_FILE"
        elif [[ "$line" == "{{ MODE_TARGETS }}" ]]; then
            cat "$MODE_TARGETS_FILE"
        elif [[ "$line" == "{{ MODE_SCHEMES }}" ]]; then
            cat "$MODE_SCHEMES_FILE"
        else
            echo "$line"
        fi
    done < "$PROJECT_TEMPLATE"
} > "$TEMP_PROJECT_SPEC"

rm -f "$PACKAGES_BLOCK_FILE" "$PODS_SETTINGS_FILE" "$MODE_TARGETS_FILE" "$MODE_SCHEMES_FILE"

# Compare with existing file and only write if different
if [[ -f "$PROJECT_SPEC" ]] && cmp -s "$PROJECT_SPEC" "$TEMP_PROJECT_SPEC"; then
    rm -f "$TEMP_PROJECT_SPEC"
    log_success "project.yml unchanged (already up-to-date)"
else
    mv "$TEMP_PROJECT_SPEC" "$PROJECT_SPEC"
    log_success "project.yml generated"
fi

# Generate workspace.yml from template
log_section "Generating workspace.yml"
log_step "Generating workspace.yml"

# ============================================================================
# Generate workspace.yml from template (Template Architecture)
# ============================================================================
# workspace.yml.template is the developer-maintained source
# workspace.yml is generated and must NEVER be committed

WORKSPACE_TEMPLATE="$ROOT_DIR/workspace.yml.template"
TEMP_WORKSPACE_SPEC="${WORKSPACE_SPEC}.tmp"

if [[ ! -f "$WORKSPACE_TEMPLATE" ]]; then
    log_error "workspace.yml.template not found! Cannot generate workspace.yml"
    log_info "This is a developer-maintained file that must exist in the repository."
    exit 1
fi

# Generate workspace.yml directly (template approach simplified)
{
    cat <<'YAML'
# This file is auto-generated from workspace.yml.template by generate_workspace.sh
# DO NOT EDIT MANUALLY - edit workspace.yml.template instead!
workspace:
  name: msp-ios-sdk
  projects:
    - name: MSPDemoApp
      path: Examples/MSPDemoApp/project.yml
      type: file
YAML
    
    # Add mode-specific projects
    if [[ "$EFFECTIVE_MODE" == "pods" ]]; then
        # Pods mode: include ALL Pod .xcodeproj files
        # With :generate_multiple_pod_projects => true in Podfile, each Pod gets its own .xcodeproj
        # We need to include all of them for Xcode to properly build dependencies
        
        # Find all .xcodeproj in Pods/ and add them to workspace
        pod_projects=()
        while IFS= read -r proj; do
            [[ -n "$proj" ]] && pod_projects+=("$proj")
        done < <(find "$PODS_DIR" -maxdepth 1 -name "*.xcodeproj" -type d 2>/dev/null | LC_ALL=C sort || true)
        
        if [[ ${#pod_projects[@]} -gt 0 ]]; then
            for proj in "${pod_projects[@]}"; do
                proj_name=$(basename "$proj" .xcodeproj)
                proj_rel_path="${proj#$ROOT_DIR/}"
                echo "    - name: $proj_name"
                echo "      path: $proj_rel_path"
                echo "      type: file"
            done
        fi
    fi
    # SPM mode: no additional projects needed (MSPDemoApp handles SPM dependencies)
} > "$TEMP_WORKSPACE_SPEC"

# Compare with existing file and only write if different
if [[ -f "$WORKSPACE_SPEC" ]] && cmp -s "$WORKSPACE_SPEC" "$TEMP_WORKSPACE_SPEC"; then
    rm -f "$TEMP_WORKSPACE_SPEC"
    log_success "workspace.yml unchanged (already up-to-date)"
else
    mv "$TEMP_WORKSPACE_SPEC" "$WORKSPACE_SPEC"
    log_success "workspace.yml generated"
fi

log_info "[generate_workspace] workspace.yml generation complete"

log_info "[xcodegen] Generating .xcworkspace via XcodeGen..."

# Ensure workspace.yml exists
if [[ ! -f "workspace.yml" ]]; then
    log_error "[xcodegen] workspace.yml not found — cannot generate workspace"
    exit 1
fi

# Step 1: Generate all project.yml files referenced in workspace.yml
log_step "Generating project files from project.yml specs"

# CRITICAL: Unset CocoaPods environment variables before running XcodeGen
# If these are set (e.g., from previous builds or tests), XcodeGen will expand
# them in shell scripts, resulting in hardcoded paths instead of dynamic variables.
# This prevents the "no such module 'MSPCore'" issue in Pods mode.
unset PODS_ROOT PODS_CONFIGURATION_BUILD_DIR PODS_XCFRAMEWORKS_BUILD_DIR SCRIPTS_DIR 2>/dev/null || true
PROJECT_YML_FILES=()
while IFS= read -r line; do
    # Match lines like "path: Examples/MSPDemoApp/project.yml" or "path: NovaCore/project.yml"
    if [[ "$line" =~ ^[[:space:]]*path:[[:space:]]*(.+\.yml)$ ]]; then
        project_path="${BASH_REMATCH[1]}"
        if [[ -f "$ROOT_DIR/$project_path" ]]; then
            PROJECT_YML_FILES+=("$project_path")
        fi
    fi
done < <(grep -E "^[[:space:]]*path:" "$WORKSPACE_SPEC" || true)

# Generate each project.yml file
# Note: Some projects may fail if Pods aren't installed yet - that's OK, they'll be generated after pod install
FAILED_PROJECTS=()
# Initialize PROJECTS array
for project_yml in "${PROJECT_YML_FILES[@]}"; do
    log_info "[xcodegen] Generating project from $project_yml"
    if ! xcodegen generate --spec "$project_yml" 2>&1; then
        log_warn "[xcodegen] Failed to generate project from $project_yml (may need pod install first)"
        FAILED_PROJECTS+=("$project_yml")
    fi
done

# Step 2: Generate MSPDemoApp project.yml (if in Pods mode)
if [[ "$EFFECTIVE_MODE" == "pods" ]] && [[ -f "$PROJECT_SPEC" ]]; then
    log_info "[xcodegen] Generating MSPDemoApp project"
    if ! xcodegen generate --spec "$PROJECT_SPEC" 2>&1; then
        log_warn "[xcodegen] Failed to generate MSPDemoApp project (may need pod install first)"
        FAILED_PROJECTS+=("$PROJECT_SPEC")
    fi
fi

if [[ ${#FAILED_PROJECTS[@]} -gt 0 ]]; then
    log_warn "[xcodegen] ${#FAILED_PROJECTS[@]} project(s) failed to generate (will be generated after pod install)"
fi

# Step 3: Create the .xcworkspace file manually from workspace.yml
log_step "Creating .xcworkspace file"
WORKSPACE_PATH="$ROOT_DIR/.generated/msp-ios-sdk.xcworkspace"
WORKSPACE_DATA="$WORKSPACE_PATH/contents.xcworkspacedata"
mkdir -p "$WORKSPACE_PATH"

# Extract project paths from workspace.yml
PROJECT_PATHS=()
while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*path:[[:space:]]*(.+)$ ]]; then
        project_path="${BASH_REMATCH[1]}"
        PROJECT_PATHS+=("$project_path")
    fi
done < <(grep -E "^[[:space:]]*path:" "$WORKSPACE_SPEC" || true)

# Generate workspace XML
{
    cat <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
XML
    
    for project_path in "${PROJECT_PATHS[@]}"; do
        if [[ "$project_path" == *.xcodeproj ]]; then
            # Direct .xcodeproj reference - add ../ prefix since workspace is in .generated/
            cat <<XML
   <FileRef
      location = "group:../${project_path}">
   </FileRef>
XML
        elif [[ "$project_path" == *.yml ]]; then
            # YAML spec - reference the generated .xcodeproj - add ../ prefix since workspace is in .generated/
            project_dir="$(dirname "$project_path")"
            project_name="$(basename "$project_dir")"
            xcodeproj_path="${project_dir}/${project_name}.xcodeproj"
            cat <<XML
   <FileRef
      location = "group:../${xcodeproj_path}">
   </FileRef>
XML
        fi
    done
    
    echo "</Workspace>"
} > "$WORKSPACE_DATA"

log_success "[xcodegen] Successfully generated .xcworkspace"

log_title "YAML Generation Complete"
log_success "YAML specs generated for $TARGET_MODE mode"
