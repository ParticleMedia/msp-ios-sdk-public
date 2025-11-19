# MSP iOS SDK

Modular advertising SDK for iOS that ships multiple adapters, shared libraries, and a dual‑integration demo app. The demo application uses YAML specs (Xcodegen) to support both CocoaPods and Swift Package Manager integrations without modifying Xcode project files.

---

## 🚀 Quick Start

### Prerequisites

| Tool | Version | Installation |
|------|---------|--------------|
| Xcode | 15.2+ | App Store or developer.apple.com |
| Xcodegen | 2.38.0+ | `brew install xcodegen` |
| Ruby | 3.0+ with Bundler | `bundle install` |
| CocoaPods | 1.14+ | Required for CocoaPods target |

### Setup

```bash
git clone <repo-url>
cd msp-ios-sdk
bundle install
brew install xcodegen
```

### Switch to Swift Package Manager (SPM)

```bash
# 1. Switch to SPM mode (generates YAML only)
./Scripts/target-switching/switch-target.sh spm

# 2. Regenerate Xcode project from YAML
xcodegen generate

# 3. Open Xcode and build
open MSPDemoApp/MSPDemoApp.xcodeproj
```

**Build the SPM target:**
- Select scheme: `MSPDemoApp-SPM`
- Press `⌘B` to build

### Switch to CocoaPods

```bash
# 1. Switch to CocoaPods mode (generates YAML + installs Pods)
./Scripts/target-switching/switch-target.sh pods

# 2. Regenerate Xcode project from YAML
xcodegen generate

# 3. Open workspace and build
open msp-ios-sdk.xcworkspace
```

**Build the CocoaPods target:**
- Select scheme: `MSPDemoApp`
- Press `⌘B` to build

---

## 🎯 Developer Workflow

### Target Switching Flow

```
┌─────────────────────────────────────────────────────────┐
│  Developer runs: switch-target.sh [spm|pods]           │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│  1. Cleanup Environment                                 │
│     - Remove conflicting artifacts                      │
│     - Clean DerivedData                                 │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│  2. Generate YAML Specs                                │
│     - project.yml (mode-aware)                         │
│     - workspace.yml (mode-aware)                        │
│     - Deterministic, sorted, consistent                 │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│  3. Validate Environment                                │
│     - Check YAML matches target mode                    │
│     - Verify no mixed state                             │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│  4. Developer runs: xcodegen generate                    │
│     (Manual step - not automatic)                       │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│  5. Open Xcode & Build                                  │
│     - SPM: MSPDemoApp.xcodeproj                         │
│     - Pods: msp-ios-sdk.xcworkspace                     │
└─────────────────────────────────────────────────────────┘
```

### Step-by-Step Workflow

**For SPM Development:**
1. Run `./Scripts/target-switching/switch-target.sh spm`
2. Run `xcodegen generate` (regenerates Xcode project from YAML)
3. Open `MSPDemoApp/MSPDemoApp.xcodeproj` in Xcode
4. Select scheme `MSPDemoApp-SPM` and build

**For CocoaPods Development:**
1. Run `./Scripts/target-switching/switch-target.sh pods`
2. Run `xcodegen generate` (regenerates Xcode project from YAML)
3. Open `msp-ios-sdk.xcworkspace` in Xcode
4. Select scheme `MSPDemoApp` and build

---

## 🔄 Target Switching System

The Target Switching Framework provides **zero-diff switching** between CocoaPods and Swift Package Manager environments. Switching **only modifies YAML files**—Xcode project files are never touched.

### Architecture

```
Scripts/target-switching/
├── switch-target.sh          # Main entry point
├── common.sh                  # Shared utilities & safety functions
├── generate_workspace.sh      # YAML-only generation (no xcodegen)
├── cleanup_spm.sh            # SwiftPM environment cleanup
├── cleanup_pods.sh            # CocoaPods environment cleanup
└── validate_environment.sh    # Environment validation
```

### Core Components

#### `switch-target.sh`
**Purpose:** Main orchestrator for target switching

**Behavior:**
- Cleans conflicting environment artifacts
- Generates YAML specs (project.yml, workspace.yml)
- Validates environment matches target mode
- Opens Xcode (project or workspace)

**Does NOT:**
- Run xcodegen (manual step)
- Modify .pbxproj files
- Modify .xcscheme files
- Generate workspace files

#### `generate_workspace.sh`
**Purpose:** Generate deterministic YAML specs

**Behavior:**
- Generates `project.yml` (mode-aware: SPM or Pods)
- Generates `workspace.yml` (mode-aware: includes/excludes Pods)
- Sorts packages and products alphabetically
- Compares with existing files (only writes if changed)
- **Never runs xcodegen**

**Output:**
- `MSPDemoApp/project.yml` - Xcodegen project spec
- `workspace.yml` - Xcodegen workspace spec

#### `common.sh`
**Purpose:** Shared utilities and safety functions

**Key Functions:**
- `safe_remove_workspace()` - Prevents deletion of internal .xcodeproj workspaces
- `safe_remove_directory()` - Only removes within repo root
- `validate_environment()` - Checks YAML matches target mode
- `log_success()`, `log_error()`, `log_warning()` - Consistent logging

#### `cleanup_spm.sh`
**Purpose:** Clean SwiftPM environment

**Removes:**
- `.swiftpm/` directories (with .xcodeproj protection)
- `SourcePackages/` directories (with .xcodeproj protection)
- `.build/` directories (with .xcodeproj protection)
- SPM workspace (using safe_remove_workspace)
- DerivedData cache

**Safety:**
- Never deletes files outside repo root
- Never deletes internal .xcodeproj/project.xcworkspace folders
- All paths verified before deletion

#### `cleanup_pods.sh`
**Purpose:** Clean and reinstall CocoaPods environment

**Steps:**
1. `pod deintegrate` (removes CocoaPods integration)
2. Remove `Pods/` directory (using safe_remove_directory)
3. Remove CocoaPods workspace (using safe_remove_workspace)
4. Clean DerivedData cache
5. `pod install` (reinstalls Pods with UTF-8 encoding)

**Safety:**
- Never deletes files outside repo root
- Never deletes internal .xcodeproj/project.xcworkspace folders
- All paths verified before deletion

#### `validate_environment.sh`
**Purpose:** Validate environment matches target mode

**Checks:**
- YAML files exist (project.yml, workspace.yml)
- YAML content matches target mode:
  - SPM mode: MSPDemoApp-SPM target, no Pods references
  - Pods mode: MSPDemoApp target, Pods xcconfig present
- No mixed state (Pods/ exists in SPM mode, etc.)

---

## 🧹 Cleanup Logic

### SPM Mode Cleanup

When switching **to** SPM:
1. Remove `Pods/` directory (if exists)
2. Remove CocoaPods workspace (if exists)
3. Run `cleanup_spm.sh --force`:
   - Remove `.swiftpm/` directories
   - Remove `SourcePackages/` directories
   - Remove `.build/` directories
   - Remove SPM workspace
   - Clean DerivedData

### Pods Mode Cleanup

When switching **to** Pods:
1. Run `cleanup_spm.sh --force`:
   - Remove all SwiftPM artifacts
   - Remove SPM workspace
   - Clean DerivedData
2. Run `cleanup_pods.sh`:
   - `pod deintegrate`
   - Remove `Pods/` directory
   - Remove CocoaPods workspace
   - Clean DerivedData
   - `pod install`

### Safety Guarantees

✅ **All cleanup operations are safe:**
- Never deletes files outside repository root
- Never deletes internal `.xcodeproj/project.xcworkspace` folders
- Uses `safe_remove_workspace()` and `safe_remove_directory()` functions
- All paths verified before deletion

---

## 🧪 Zero-Diff Guarantee

### What Changes

After running `switch-target.sh`, **only** these files change:
- ✅ `MSPDemoApp/project.yml` (mode-aware target definitions)
- ✅ `workspace.yml` (mode-aware project references)

### What Never Changes

After running `switch-target.sh`, these files **never** change:
- ❌ `.pbxproj` files (Xcode project files)
- ❌ `.xcscheme` files (Xcode scheme files)
- ❌ Workspace contents (xcworkspace/contents.xcworkspacedata)
- ❌ Any files inside `.xcodeproj` bundles

### Round-Trip Determinism

Switching between modes produces **identical YAML files**:

```bash
# Round-trip test
./Scripts/target-switching/switch-target.sh spm
./Scripts/target-switching/switch-target.sh pods
./Scripts/target-switching/switch-target.sh spm

# Result: project.yml and workspace.yml are identical to initial state
git diff  # Shows zero changes (or only expected YAML changes)
```

### CI Integration

**Recommended CI workflow:**

```yaml
# .github/workflows/target-switching-test.yml
- name: Test SPM → Pods → SPM round-trip
  run: |
    ./Scripts/target-switching/switch-target.sh spm
    git add MSPDemoApp/project.yml workspace.yml
    git diff --cached --exit-code || exit 1  # Should have changes
    
    ./Scripts/target-switching/switch-target.sh pods
    git add MSPDemoApp/project.yml workspace.yml
    git diff --cached --exit-code || exit 1  # Should have changes
    
    ./Scripts/target-switching/switch-target.sh spm
    git add MSPDemoApp/project.yml workspace.yml
    git diff --cached --exit-code || exit 1  # Should match initial state
```

---

## ❗ Known Requirements

### Required Tools

1. **Xcodegen** (2.38.0+)
   ```bash
   brew install xcodegen
   ```
   - Used to generate Xcode projects from YAML specs
   - Must be run manually after switching targets

2. **Ruby + Bundler**
   ```bash
   bundle install
   ```
   - Required for CocoaPods target
   - Ensures consistent CocoaPods version

3. **CocoaPods** (1.14+)
   - Required for CocoaPods target
   - Installed via `bundle exec pod install`

### Directory Requirements

- All scripts must be run from repository root
- Scripts use `ROOT_DIR` to ensure safe operations
- Never run scripts from subdirectories

### Important Notes

⚠️ **Never commit Xcode project files:**
- `.pbxproj` files are generated from YAML
- `.xcscheme` files are generated from YAML
- Workspace files are generated by Xcode or CocoaPods
- Only commit `project.yml` and `workspace.yml`

⚠️ **Always run xcodegen after switching:**
- Target switching only modifies YAML files
- Xcode projects must be regenerated manually
- Run `xcodegen generate` after each switch

---

## 🛠 Troubleshooting

### Build Errors After Switching

**Problem:** Build fails after switching targets

**Solution:**
```bash
# 1. Regenerate Xcode project from YAML
xcodegen generate

# 2. Clean DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 3. For CocoaPods target, ensure Pods are installed
bundle exec pod install

# 4. Rebuild in Xcode
```

### YAML Files Not Updating

**Problem:** YAML files don't change after switching

**Solution:**
```bash
# Check if files are already in correct state
./Scripts/target-switching/validate_environment.sh [spm|pods]

# Force regeneration by deleting YAML files
rm MSPDemoApp/project.yml workspace.yml
./Scripts/target-switching/switch-target.sh [spm|pods]
```

### Mixed Environment Detected

**Problem:** Validation fails with "mixed environment" error

**Solution:**
```bash
# Clean everything and re-switch
./Scripts/target-switching/cleanup_spm.sh --force
./Scripts/target-switching/cleanup_pods.sh
./Scripts/target-switching/switch-target.sh [spm|pods]
xcodegen generate
```

### Xcodegen Not Found

**Problem:** `xcodegen: command not found`

**Solution:**
```bash
# Install xcodegen
brew install xcodegen

# Verify installation
xcodegen --version  # Should be 2.38.0+
```

### CocoaPods Installation Fails

**Problem:** `pod install` fails with encoding errors

**Solution:**
```bash
# Set UTF-8 encoding
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Re-run pod install
bundle exec pod install
```

### Workspace Not Found

**Problem:** Xcode can't find workspace after switching

**Solution:**
```bash
# For SPM mode: Open project directly
open MSPDemoApp/MSPDemoApp.xcodeproj

# For Pods mode: Ensure pod install completed
bundle exec pod install
open msp-ios-sdk.xcworkspace
```

---

## 📦 Building & Releasing the SDK

### Building XCFrameworks

Wrapper XCFrameworks are required for SPM builds:

```bash
# Build all wrapper xcframeworks
./Scripts/xcframeworks/build-all.sh
```

This script:
- Cleans temporary build directories
- Builds all wrapper xcframeworks (Shimmer, FBAudienceNetwork, IronSource, etc.)
- Verifies all xcframeworks exist and are valid

### Pre-Release Checklist

Before releasing a new version:

1. **Test both targets:**
   ```bash
   # Test SPM target
   ./Scripts/target-switching/switch-target.sh spm
   xcodegen generate
   # Build in Xcode: Product → Build (⌘B)
   
   # Test CocoaPods target
   ./Scripts/target-switching/switch-target.sh pods
   xcodegen generate
   # Build in Xcode: Product → Build (⌘B)
   ```

2. **Run validation scripts:**
   ```bash
   ./Scripts/validation/script-path-lint.sh
   ./Scripts/xcframeworks/validate-wrappers.sh
   ./Scripts/validation/sdk-package-size.sh
   ```

3. **Verify zero-diff switching:**
   ```bash
   # Round-trip test
   ./Scripts/target-switching/switch-target.sh spm
   ./Scripts/target-switching/switch-target.sh pods
   ./Scripts/target-switching/switch-target.sh spm
   git diff  # Should show only expected YAML changes
   ```

### Releasing via CI

**GitHub Actions:**
- `.github/workflows/demoapp-dual.yml` – Builds both targets on every PR
- `.github/workflows/release.yml` – Handles releases and publishing

**Jenkins Pipelines:**
- `Jenkinsfile.cocoapods` – CocoaPods release pipeline
- `Jenkinsfile.spm` – SPM validation and release pipeline

---

## 📚 Additional Resources

### Scripts Reference

| Script | Purpose |
|--------|---------|
| `Scripts/target-switching/switch-target.sh` | Switch between CocoaPods and SPM |
| `Scripts/target-switching/generate_workspace.sh` | Generate YAML specs (YAML-only) |
| `Scripts/target-switching/cleanup_spm.sh` | Clean SwiftPM environment |
| `Scripts/target-switching/cleanup_pods.sh` | Clean and reinstall CocoaPods |
| `Scripts/target-switching/validate_environment.sh` | Validate environment matches target |
| `Scripts/xcframeworks/build-all.sh` | Build all wrapper xcframeworks |
| `Scripts/xcframeworks/validate-wrappers.sh` | Validate all wrapper packages |
| `Scripts/validation/script-path-lint.sh` | Validate script paths and ROOT_DIR usage |
| `Scripts/validation/sdk-package-size.sh` | Check SDK package size against baseline |
| `Scripts/cleanup-swiftpm-caches.sh` | Clean SwiftPM caches and DerivedData |

### Documentation

- `Docs/DemoAppIntegration.md` – Dual-target integration details
- `fastlane/README.md` – Fastlane lanes for CI/release automation
- `Scripts/README.md` – Detailed script documentation

### Contribution Guidelines

1. Switch to your target: `./Scripts/target-switching/switch-target.sh [spm|pods]`
2. Regenerate Xcode projects: `xcodegen generate`
3. For CocoaPods target: `bundle exec pod install`
4. Build/test both demo app schemes (`MSPDemoApp` and `MSPDemoApp-SPM`)
5. Commit only source/spec files—**never commit** `.pbxproj`, `.xcscheme`, or generated workspace files
6. Verify zero-diff switching: run round-trip test and confirm only YAML files change
7. Submit pull requests with build logs for both schemes

---

## 🔍 How It Works (Technical Details)

### YAML Generation

The `generate_workspace.sh` script generates deterministic YAML files:

**project.yml:**
- Contains target definitions (MSPDemoApp or MSPDemoApp-SPM)
- Mode-aware: Includes Pods xcconfig only in Pods mode
- Sorted packages and products for consistency
- Compared with existing file (only writes if changed)

**workspace.yml:**
- Contains project references
- Mode-aware: Includes/excludes Pods project based on mode
- Sorted project list for consistency
- Compared with existing file (only writes if changed)

### Xcode Project Generation

Xcode projects are generated **manually** using:

```bash
xcodegen generate
```

This command:
- Reads `MSPDemoApp/project.yml`
- Reads `workspace.yml`
- Generates `.xcodeproj` and `.xcscheme` files
- **Never** run automatically by target switching

### Workspace Creation

**SPM Mode:**
- Workspace created by Xcode when opening project
- Or manually created by developer

**Pods Mode:**
- Workspace created by `pod install`
- Located at `msp-ios-sdk.xcworkspace`

---

**Last Updated:** November 2025  
**Target Switching Version:** Zero-Diff Architecture
