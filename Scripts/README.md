# Scripts Directory Overview

This directory contains all automation scripts for the MSP iOS SDK repository. The scripts are organized by purpose, with the main mode-switching entrypoint at the root level.

## Table of Contents

- [Directory Structure](#directory-structure)
- [Main Entrypoints](#main-entrypoints)
- [Subdirectories](#subdirectories)
- [Key Principles](#key-principles)
- [Requirements](#requirements)
- [Quick Reference](#quick-reference)
- [Related Documentation](#related-documentation)

## Directory Structure

```
Scripts/
├── switch-target.sh              # Main entrypoint for mode switching
├── msp-release.sh                # Main entrypoint for release orchestration
├── target-switching/             # Target switching and mode management
│   ├── round-trip-test.sh
│   ├── generate_project_templates.sh
│   ├── generate_workspace.sh
│   ├── validate_xcframeworks.sh
│   ├── cleanup_spm.sh
│   └── common.sh
├── xcframeworks/                 # XCFramework build scripts
│   ├── build-core.sh
│   ├── build-thirdparty.sh
│   └── build-adapters.sh
├── spm-sync/                     # Pods → SPM synchronization
│   ├── extract_from_pods.sh
│   ├── spm_sync_all.sh
│   └── generate_package_swift.sh
├── ci/                           # CI validation scripts
│   └── ci_validate.sh
├── release/                      # Release orchestration
│   ├── orchestrator/
│   ├── verify_remote/
│   ├── verify_local/
│   ├── verify_local_device/
│   ├── verify_xcframework/
│   ├── verify-matrix/
│   ├── notify/
│   └── config/
└── config/                       # Configuration files
    ├── notify_mapping.yaml
    ├── email_mapping.yaml
    └── release.yaml
```

## Main Entrypoints

### `switch-target.sh`

**Location:** `Scripts/switch-target.sh`

The primary script for switching between development and release modes.

**Usage:**
```bash
# Switch to development mode (default for SDK engineers)
./Scripts/switch-target.sh pods-dev

# Switch to release validation mode
./Scripts/switch-target.sh pods-release

# Switch to SPM release mode
./Scripts/switch-target.sh spm-release
```

**Modes:**
- **pods-dev:** CocoaPods with source files (internal development)
- **pods-release:** CocoaPods with binary XCFrameworks (pre-release validation)
- **spm-release:** Swift Package Manager with binary XCFrameworks (SPM release)

For detailed documentation, see [Scripts/target-switching/README.md](target-switching/README.md).

---

### `msp-release.sh`

**Location:** `Scripts/msp-release.sh`

The main entrypoint for release orchestration, including publishing, verification, and notifications.

**Usage:**
```bash
# Run a full release
./Scripts/msp-release.sh run <version>

# Dry-run mode
./Scripts/msp-release.sh run <version> --dry-run

# Resume from state file
./Scripts/msp-release.sh resume

# Rollback on failure
./Scripts/msp-release.sh rollback

# Run verification only
./Scripts/msp-release.sh verify <version>
```

For detailed documentation, see [Scripts/release/README.md](release/README.md).

## Subdirectories

### `target-switching/`

Internal helper scripts used by `switch-target.sh` for mode switching and validation.

**Key Scripts:**
- `round-trip-test.sh` - Test switching between all three modes
- `generate_project_templates.sh` - Generate `project.yml` files from templates
- `generate_workspace.sh` - Generate `workspace.yml` and project YAML
- `validate_xcframeworks.sh` - Validate that required XCFrameworks exist
- `cleanup_spm.sh` - Remove SwiftPM artifacts and caches

**Documentation:** [Scripts/target-switching/README.md](target-switching/README.md)

---

### `xcframeworks/`

Scripts for building XCFrameworks from source code.

**Key Scripts:**
- `build-core.sh` - Build 5 core XCFrameworks (MSPCore, MSPiOSCore, MSPSharedLibraries, MSPOMSDK, NovaCore)
- `build-thirdparty.sh` - Build third-party XCFrameworks (SwiftProtobuf, SnapKit, Lottie, Shimmer, Kingfisher)
- `build-adapters.sh` - Build adapter XCFrameworks (optional, non-blocking)

**Usage:**
```bash
# Build all core XCFrameworks (required for pods-release/spm-release)
./Scripts/xcframeworks/build-core.sh

# Build third-party XCFrameworks
./Scripts/xcframeworks/build-thirdparty.sh

# Build adapter XCFrameworks (optional)
./Scripts/xcframeworks/build-adapters.sh
```

**Note:** Adapter XCFrameworks are optional. Adapters are always source-only in all modes.

---

### `spm-sync/`

Scripts for synchronizing third-party SDKs from CocoaPods to SPM.

**Key Scripts:**
- `extract_from_pods.sh` - Extract XCFrameworks from Pods to `ThirdParty/`
- `spm_sync_all.sh` - Full sync: Pods → ThirdParty → Package.swift
- `generate_package_swift.sh` - Generate `Package.swift` from template

**Usage:**
```bash
# Sync all third-party SDKs
./Scripts/spm-sync/spm_sync_all.sh
```

**Important:** `Podfile` is the single source of truth for third-party SDK versions. Always update versions in `Podfile`, then run `spm_sync_all.sh`.

---

### `ci/`

CI validation and testing scripts.

**Key Scripts:**
- `ci_validate.sh` - Comprehensive CI validation (all modes, builds, tests)

**Usage:**
```bash
# Run full CI validation
./Scripts/ci/ci_validate.sh
```

---

### `release/`

Release orchestration scripts for publishing to CocoaPods and SPM, including multi-layer verification and notification systems.

**Subdirectories:**
- `orchestrator/` - Main release orchestration logic
- `verify_remote/` - Remote SPM and CocoaPods verification
- `verify_local/` - Local build verification
- `verify_local_device/` - Device archive and IPA verification
- `verify_xcframework/` - XCFramework binary quality verification
- `verify-matrix/` - Automated test matrix (15 scenarios)
- `notify/` - Slack and Email notification system
- `config/` - Release configuration files

**Documentation:** [Scripts/release/README.md](release/README.md)

---

### `config/`

Configuration files for the release and notification systems.

**Files:**
- `notify_mapping.yaml` - Slack and Email message templates
- `email_mapping.yaml` - Email service configuration
- `release.yaml` - Release system configuration

## Key Principles

1. **Template-Based Generation:** All generated files (`project.yml`, `workspace.yml`, `Package.swift`) are created from `.template` files. Generated files are ignored by git.

2. **Three-Mode Architecture:** The SDK supports three distinct modes:
   - `pods-dev`: Full source development
   - `pods-release`: Binary core, source adapters (CocoaPods)
   - `spm-release`: Binary core, source adapters (SPM)

3. **Adapters Are Source-Only:** Adapter modules never require XCFrameworks in any mode.

4. **Podfile Is Source of Truth:** All third-party SDK versions are managed in `Podfile`. Never manually edit `ThirdParty/` or `Package.swift` for version changes.

5. **Workspace Symlink:** All modes create a symlink at the project root:
   ```
   msp-ios-sdk.xcworkspace → .generated/msp-ios-sdk.xcworkspace
   ```
   Always use `open msp-ios-sdk.xcworkspace` regardless of mode.

6. **Sandboxed Verification:** All verification systems operate in isolated sandbox directories and never modify the main repository.

7. **Soft-Fail Semantics:** Most operations use soft-fail behavior (log warnings but don't halt execution) unless explicitly configured otherwise.

## Requirements

- **XcodeGen:** `brew install xcodegen`
- **CocoaPods:** `gem install cocoapods` or `bundle install`
- **Bash:** macOS default (bash 3.2+) or bash 4+ for advanced features
- **jq:** For JSON parsing (usually pre-installed on macOS)
- **Python 3:** For YAML parsing in notification system

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

### Running a Release

```bash
# Full release
./Scripts/msp-release.sh run 1.9.0

# Dry-run
./Scripts/msp-release.sh run 1.9.0 --dry-run

# Verification only
./Scripts/msp-release.sh verify 1.9.0
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

**Release failures:**
- Check `.msp-release-state.json` for current state
- Use `./Scripts/msp-release.sh resume` to continue from last checkpoint
- Use `./Scripts/msp-release.sh rollback` to undo last attempt

For more detailed troubleshooting, see the specific README files for each subsystem.

## Related Documentation

- [Scripts/target-switching/README.md](target-switching/README.md) - Target switching and mode management
- [Scripts/release/README.md](release/README.md) - Release system, verification, and notifications
