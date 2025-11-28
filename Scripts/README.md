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

## 📦 Verification System (verify + verify-matrix)

The MSP Release System provides a complete multi-layer verification framework that ensures both local and remote environments can successfully resolve, install, and build MSP SDK products across all distribution methods:

- **CocoaPods binary distribution**
- **SwiftPM binaryTarget distribution**
- **Local SPM (path dependency) integration**
- **Full environment matrix testing (15 scenarios)**

This section documents how the verification system works and how to use it.

---

### 1. `verify` — Release Product Verification

```bash
./Scripts/msp-release.sh verify <version>
```

Runs the full verification pipeline:

#### ✔ 1. Pods Remote Verification

Ensures the released CocoaPods artifacts can be fetched and integrated in a clean environment.

**Steps:**
- Creates an isolated temp directory
- Generates a minimal SwiftUI TestApp
- Creates a Podfile pointing to **PODS_REMOTE_URL**
- Installs Pods
- Builds the TestApp via xcodebuild
- Reports success/failure

**Config keys used:**

| YAML Key | Shell Var | Description |
|---------|------------|-------------|
| `pods.remote_url` | `PODS_REMOTE_URL` | CocoaPods source repo URL |
| `pods.remote_primary_product` | `PODS_REMOTE_PRIMARY_PRODUCT` | The main pod to import |

---

#### ✔ 2. SPM Remote Verification

Ensures the Swift Package Manager artifacts are valid on GitHub (or other host).

**Steps:**
- Creates isolated temp directory
- Generates a minimal SwiftPM executable
- Adds package dependency pointing to **SPM_REMOTE_URL**
- Runs `swift package resolve` and `swift build`

**Config keys:**

| YAML Key | Shell Var | Description |
|---------|------------|-------------|
| `spm.remote_url` | `SPM_REMOTE_URL` | URL of the remote SPM package |
| `spm.remote_product_name` | `SPM_REMOTE_PRODUCT_NAME` | Product name to import |

**Strict mode:**

| YAML Key | Shell Var | Description |
|---------|------------|-------------|
| `verify.spm_strict` | `VERIFY_SPM_STRICT` | If true (default), failure stops release |

---

#### ✔ 3. Local SPM Build Validation

Ensures that the local Package.swift (binaryTarget + source adapters) is internally consistent.

**Steps:**
- Creates a clean SPM test package
- Adds a **path** dependency to local repo
- Imports `SPM_REMOTE_PRODUCT_NAME` (default: `MSPAds`)
- Resolves and builds locally

Failures **always block release**.

---

### 2. `verify-matrix` — Patch-Level Verification Matrix

```bash
./Scripts/msp-release.sh verify-matrix
```

Runs **15 automated test scenarios**, covering all combinations of:

- `DRY_RUN` = on/off
- `VERIFY_SPM_STRICT` = on/off
- `SPM_REMOTE_URL` = unset / valid / invalid
- pods-only / spm-only modes

#### Directory Structure

```
Scripts/release/verify-matrix/
│
├── generate_cases.sh # Generates 15 cases automatically
├── matrix.sh # Runs all cases and produces results
├── cases/ # Auto-generated test scripts
└── README.md # Local documentation
```

#### Output Directory (ignored by git)

```
verification_matrix/
└── run-<timestamp>/
    ├── case-A1/output.log
    ├── case-A2/output.log
    ...
    └── summary.json
```

#### Summary Report Format

Each run produces a machine-readable summary:

```json
{
  "timestamp": "2025-01-03T15:23:11Z",
  "total_cases": 15,
  "passed": 13,
  "failed": 2,
  "cases": {
    "A1": "passed",
    "A2": "failed",
    ...
  }
}
```

---

### 3. Configuration Keys Used by the Verification System

Add these to `Scripts/release/config/release.yaml`:

```yaml
pods:
  remote_url: ""
  remote_primary_product: "MSPCore"

spm:
  remote_url: ""
  remote_product_name: "MSPAds"

verify:
  spm_strict: true
  matrix_default_version: "0.0.0-test"
```

---

### 4. Recommended Workflow

#### During Development / Refactoring

```bash
./Scripts/msp-release.sh verify-matrix
```

- Ensures all environments behave consistently
- Useful after major changes to release/publish scripts

#### Before Official Release

```bash
./Scripts/msp-release.sh verify <version>
```

#### CI Integration (Optional)

Add a small subset of matrix cases:

- E1 — baseline default
- B2 — strict + valid SPM URL
- E2 — pods-only
- E3 — spm-only

---

### 5. Notes

- The verification system never touches the main repository — all tests run in isolated temp directories.
- Pods verification is hard-fail (always blocks release).
- SPM remote verification is configurable via strict mode.
- Local SPM validation is always blocking.

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
