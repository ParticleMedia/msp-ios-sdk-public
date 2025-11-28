# Scripts Directory Overview

This directory contains all automation scripts for the MSP iOS SDK repository. The scripts are organized by purpose, with the main mode-switching entrypoint at the root level.

## Directory Structure

```
Scripts/
├── switch-target.sh              # Main entrypoint for mode switching
├── target-switching/             # Internal helpers for mode switching
│   ├── generate_project_templates.sh
│   ├── generate_workspace.sh
│   ├── validate_xcframeworks.sh
│   ├── round-trip-test.sh
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
└── release/                      # Release orchestration (future)
```

---

## Main Entrypoint: `switch-target.sh`

**Location:** `Scripts/switch-target.sh`

The primary script for switching between development and release modes.

### Modes

| Mode | Description |
|------|-------------|
| **pods-dev** | CocoaPods with source files (internal development) |
| **pods-release** | CocoaPods with binary XCFrameworks (pre-release validation) |
| **spm-release** | Swift Package Manager with binary XCFrameworks (SPM release) |

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

---

## Subdirectories

### `target-switching/`

Internal helper scripts used by `switch-target.sh`. These are not typically called directly.

| Script | Purpose |
|--------|---------|
| `generate_project_templates.sh` | Generate `project.yml` files from `.template` files |
| `generate_workspace.sh` | Generate `workspace.yml` and project YAML |
| `validate_xcframeworks.sh` | Validate that required XCFrameworks exist |
| `round-trip-test.sh` | Test switching between all three modes |
| `cleanup_spm.sh` | Remove SwiftPM artifacts and caches |
| `common.sh` | Shared functions and constants |

**Round-Trip Testing:**

```bash
# Test all three modes in sequence
./Scripts/target-switching/round-trip-test.sh

# Run multiple cycles
./Scripts/target-switching/round-trip-test.sh --loops=3

# Skip builds (validation only)
./Scripts/target-switching/round-trip-test.sh --skip-build
```

### `xcframeworks/`

Scripts for building XCFrameworks from source code.

| Script | Purpose |
|--------|---------|
| `build-core.sh` | Build 5 core XCFrameworks (MSPCore, MSPiOSCore, MSPSharedLibraries, MSPOMSDK, NovaCore) |
| `build-thirdparty.sh` | Build third-party XCFrameworks (SwiftProtobuf, SnapKit, Lottie, Shimmer, Kingfisher) |
| `build-adapters.sh` | Build adapter XCFrameworks (optional, non-blocking) |

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

### `spm-sync/`

Scripts for synchronizing third-party SDKs from CocoaPods to SPM.

| Script | Purpose |
|--------|---------|
| `extract_from_pods.sh` | Extract XCFrameworks from Pods to `ThirdParty/` |
| `spm_sync_all.sh` | Full sync: Pods → ThirdParty → Package.swift |
| `generate_package_swift.sh` | Generate `Package.swift` from template |

**Usage:**

```bash
# Sync all third-party SDKs
./Scripts/spm-sync/spm_sync_all.sh
```

**Important:** `Podfile` is the single source of truth for third-party SDK versions. Always update versions in `Podfile`, then run `spm_sync_all.sh`.

### `ci/`

CI validation and testing scripts.

| Script | Purpose |
|--------|---------|
| `ci_validate.sh` | Comprehensive CI validation (all modes, builds, tests) |

**Usage:**

```bash
# Run full CI validation
./Scripts/ci/ci_validate.sh
```

### `release/` (Future)

Release orchestration scripts for publishing to CocoaPods and SPM.

---

## Quick Reference

### Common Workflows

**Daily Development:**
```bash
./Scripts/switch-target.sh pods-dev
# Open msp-ios-sdk.xcworkspace in Xcode
```

**Pre-Release Validation:**
```bash
# Build core XCFrameworks first
./Scripts/xcframeworks/build-core.sh

# Switch to release mode
./Scripts/switch-target.sh pods-release
```

**SPM Testing:**
```bash
# Build core XCFrameworks first
./Scripts/xcframeworks/build-core.sh

# Sync third-party SDKs
./Scripts/spm-sync/spm_sync_all.sh

# Switch to SPM mode
./Scripts/switch-target.sh spm-release
```

**Upgrading Third-Party SDKs:**
```bash
# 1. Update version in Podfile
# 2. Run pod install
pod install

# 3. Sync to SPM
./Scripts/spm-sync/spm_sync_all.sh

# 4. Validate all modes
./Scripts/target-switching/round-trip-test.sh
```

---

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

---

## Requirements

- **XcodeGen:** `brew install xcodegen`
- **CocoaPods:** `gem install cocoapods` or `bundle install`
- **Bash:** macOS default (bash 3.2+) or bash 4+ for advanced features

---

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

For more detailed troubleshooting, see the root `README.md`.
