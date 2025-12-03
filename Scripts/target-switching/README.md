# MSP iOS SDK Target Switching System

This directory contains the target switching system that manages the three-mode architecture (pods-dev, pods-release, spm-release) for the MSP iOS SDK.

## Table of Contents

- [Overview](#overview)
- [Three-Mode Architecture](#three-mode-architecture)
- [Main Entrypoint](#main-entrypoint)
- [Internal Scripts](#internal-scripts)
- [Round-Trip Testing](#round-trip-testing)
- [XcodeGen Integration](#xcodegen-integration)
- [Configuration](#configuration)
- [Quick Reference](#quick-reference)
- [Troubleshooting](#troubleshooting)

## Overview

The target switching system enables seamless transitions between three distinct development and release modes:

- **pods-dev:** CocoaPods with source files (internal development)
- **pods-release:** CocoaPods with binary XCFrameworks (pre-release validation)
- **spm-release:** Swift Package Manager with binary XCFrameworks (SPM release)

All modes generate a unified workspace symlink at the project root: `msp-ios-sdk.xcworkspace`

## Three-Mode Architecture

| Mode | Description | Core Modules | Adapters | Workspace |
|------|-------------|--------------|----------|-----------|
| **pods-dev** | CocoaPods with source files (internal development) | Source files | Source files | `msp-ios-sdk.xcworkspace` |
| **pods-release** | CocoaPods with binary XCFrameworks (pre-release validation) | Binary XCFrameworks | Source files | `msp-ios-sdk.xcworkspace` |
| **spm-release** | Swift Package Manager with binary XCFrameworks (SPM release) | Binary XCFrameworks | Source files | `msp-ios-sdk.xcworkspace` |

### Key Principles

1. **Adapters Are Source-Only:** Adapter modules never require XCFrameworks in any mode
2. **Template-Based Generation:** All generated files (`project.yml`, `workspace.yml`, `Package.swift`) are created from `.template` files
3. **Podfile Is Source of Truth:** All third-party SDK versions are managed in `Podfile`. Never manually edit `ThirdParty/` or `Package.swift` for version changes
4. **Workspace Symlink:** All modes create a symlink at the project root:
   ```
   msp-ios-sdk.xcworkspace → .generated/msp-ios-sdk.xcworkspace
   ```
   Always use `open msp-ios-sdk.xcworkspace` regardless of mode

## Main Entrypoint

**Location:** `Scripts/switch-target.sh`

The primary script for switching between development and release modes.

### Usage

```bash
# Switch to development mode (default for SDK engineers)
./Scripts/switch-target.sh pods-dev

# Switch to release validation mode
./Scripts/switch-target.sh pods-release

# Switch to SPM release mode
./Scripts/switch-target.sh spm-release
```

### What Each Mode Does

**pods-dev:**
- All modules compile from source files
- Third-party SDKs come from official CocoaPods
- Generates `msp-ios-sdk.xcworkspace`
- Builds and runs DemoApp locally

**pods-release:**
- Core modules use binary XCFrameworks (5 required)
- Adapters remain source-only
- Validates XCFrameworks exist before switching
- Used for pre-release validation

**spm-release:**
- Core modules use binary XCFrameworks via SPM
- Adapters remain source-only
- Generates `Package.swift` from template
- Used for SPM distribution testing

## Internal Scripts

**Location:** `Scripts/target-switching/`

Internal helper scripts used by `switch-target.sh`. These are not typically called directly.

| Script | Purpose |
|--------|---------|
| `generate_project_templates.sh` | Generate `project.yml` files from `.template` files |
| `generate_workspace.sh` | Generate `workspace.yml` and project YAML |
| `validate_xcframeworks.sh` | Validate that required XCFrameworks exist |
| `round-trip-test.sh` | Test switching between all three modes |
| `cleanup_spm.sh` | Remove SwiftPM artifacts and caches |
| `common.sh` | Shared functions and constants |
| `switch-target.sh` | Main mode switching logic |

## Round-Trip Testing

**Location:** `Scripts/target-switching/round-trip-test.sh`

The Round-Trip Test (RTT) verifies engineering mode consistency by cycling through all three modes without touching release or notification code.

### Purpose

RTT verifies that:
- Mode switching is fully reversible
- Generated files are correct for each mode
- DemoApp can build in pods-dev mode
- Git remains clean after each switch

### Usage

```bash
# Test all three modes in sequence
./Scripts/target-switching/round-trip-test.sh

# Run multiple cycles
./Scripts/target-switching/round-trip-test.sh --loops=3

# Skip builds (validation only)
./Scripts/target-switching/round-trip-test.sh --skip-build
```

### Test Phases

1. **pods-dev (entry):** Switch to pods-dev, build DemoApp, verify git clean
2. **pods-release:** Switch to pods-release, verify generated files, verify git clean
3. **spm-release:** Switch to spm-release, verify Package.swift, verify git clean
4. **pods-dev (exit):** Switch back to pods-dev, build DemoApp again, verify git clean

### Features

- **Git Clean Gates:** Fails if git is dirty after any switch
- **Structured Logging:** Clear step-by-step progress output
- **Mode Verification:** Validates project.yml markers and generated files
- **Auto-Repair Option:** `--fix` flag to automatically retry failed steps
- **Final Summary:** Comprehensive pass/fail report

### Exit Criteria

**pods-dev:**
- DemoApp must build successfully
- Git clean

**pods-release:**
- Generated files match template
- Git clean
- No XCFramework requirement (validation only)

**spm-release:**
- Package.swift, generated XC configs correct
- Git clean

**Final pods-dev:**
- Build DemoApp again
- Git clean
- "RTT fully reversible" message

## XcodeGen Integration

The target switching system uses XcodeGen to generate Xcode projects and workspaces from YAML specifications.

### Template Files

All generated files are created from `.template` files:
- `project.yml.template` → `project.yml` (generated, git-ignored)
- `workspace.yml.template` → `workspace.yml` (generated, git-ignored)
- `Package.swift.template` → `Package.swift` (generated, git-ignored)

### Mode Markers

Each mode sets specific markers in `project.yml`:
- `pods-dev`: `TARGET_MODE = pods-dev`
- `pods-release`: `TARGET_MODE = pods-release`
- `spm-release`: `TARGET_MODE = spm-release`

### Generation Process

1. Load appropriate `.template` file
2. Replace mode-specific placeholders
3. Generate `project.yml` / `workspace.yml` / `Package.swift`
4. Run `xcodegen generate` to create Xcode project
5. Create workspace symlink at root

## Configuration

### Environment Variables

- `ROOT_DIR` - Repository root directory (auto-detected)
- `TARGET_MODE` - Current mode (pods-dev, pods-release, spm-release)

### Required Tools

- **XcodeGen:** `brew install xcodegen`
- **CocoaPods:** `gem install cocoapods` or `bundle install`
- **Bash:** macOS default (bash 3.2+) or bash 4+ for advanced features

## Quick Reference

### Daily Development

```bash
./Scripts/switch-target.sh pods-dev
# Open msp-ios-sdk.xcworkspace in Xcode
```

### Pre-Release Validation

```bash
# Build core XCFrameworks first
./Scripts/xcframeworks/build-core.sh

# Switch to release mode
./Scripts/switch-target.sh pods-release
```

### SPM Testing

```bash
# Build core XCFrameworks first
./Scripts/xcframeworks/build-core.sh

# Sync third-party SDKs
./Scripts/spm-sync/spm_sync_all.sh

# Switch to SPM mode
./Scripts/switch-target.sh spm-release
```

### Upgrading Third-Party SDKs

```bash
# 1. Update version in Podfile
# 2. Run pod install
pod install

# 3. Sync to SPM
./Scripts/spm-sync/spm_sync_all.sh

# 4. Validate all modes
./Scripts/target-switching/round-trip-test.sh
```

## Troubleshooting

**Script not found:**
- Ensure you're running from the repository root
- Check that the script has execute permissions: `chmod +x Scripts/switch-target.sh`

**XCFramework validation fails:**
- Build missing XCFrameworks: `./Scripts/xcframeworks/build-core.sh`
- Verify XCFrameworks exist in `Binary/` or `Build/XCFrameworks/`

**Mode switch fails:**
- Check git status is clean (no uncommitted changes)
- Run cleanup scripts: `./Scripts/target-switching/cleanup_spm.sh --force`
- Re-run `pod install` if in Pods mode

**RTT failures:**
- Check git status: `git status --porcelain`
- Verify XcodeGen is installed: `xcodegen --version`
- Check Podfile exists and is valid
- Run with `--fix` flag to auto-repair: `./Scripts/target-switching/round-trip-test.sh --fix`

**Generated files incorrect:**
- Delete `.generated/` directory and re-run switch
- Verify template files are not corrupted
- Check XcodeGen version compatibility

---

## Related Documentation

- [Scripts/README.md](../README.md) - Main scripts overview and directory structure
- [Scripts/release/README.md](../release/README.md) - Release system and verification

