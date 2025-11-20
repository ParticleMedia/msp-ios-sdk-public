# MSP iOS SDK

Modular advertising SDK for iOS that ships multiple adapters, shared libraries, and a dual‑integration demo app. The demo application uses YAML specs (Xcodegen) to support both CocoaPods and Swift Package Manager integrations without modifying Xcode project files.

---

## 🚀 Quick Start

### Prerequisites

Before you begin, ensure you have the following installed:

| Tool | Version | Installation |
|------|---------|--------------|
| Xcode | 15.2+ | App Store or [developer.apple.com](https://developer.apple.com/xcode/) |
| Xcodegen | 2.38.0+ | `brew install xcodegen` |
| Ruby | 3.0+ | Usually pre-installed on macOS. Verify with `ruby --version` |
| Bundler | Latest | `gem install bundler` (installed via Ruby) |
| CocoaPods | 1.14+ | Installed via `bundle install` (see Setup below) |

### Initial Setup

**Step 1: Clone the repository**
```bash
git clone <repo-url>
cd msp-ios-sdk
```

**Step 2: Install Ruby dependencies**
```bash
# Install Bundler gems (includes CocoaPods)
bundle install
```

**Step 3: Install Xcodegen**
```bash
# Install Xcodegen (required for generating Xcode projects from YAML)
brew install xcodegen

# Verify installation
xcodegen --version  # Should be 2.38.0+
```

**Step 4: Choose your development mode**

This project supports two integration modes. Choose one based on your needs:

- **CocoaPods Mode** (Recommended for most developers)
  - Uses CocoaPods for dependency management
  - Easier setup, no pre-build steps required
  - See "Setup: CocoaPods Mode" below

- **Swift Package Manager (SPM) Mode**
  - Uses Swift Package Manager for dependencies
  - Requires building XCFrameworks first
  - See "Setup: SPM Mode" below

---

### Setup: CocoaPods Mode

**Complete setup workflow:**

```bash
# 1. Switch to CocoaPods mode (installs Pods and generates YAML)
./Scripts/target-switching/switch-target.sh pods

# 2. Generate Xcode project from YAML
xcodegen generate --spec MSPDemoApp/project.yml

# 3. Generate workspace (includes all projects + Pods)
./Scripts/tools/generate-workspace.sh

# 4. Open workspace in Xcode
open msp-ios-sdk.xcworkspace
```

**What this does:**
- Installs CocoaPods dependencies (`Pods/` directory)
- Generates `project.yml` and `workspace.yml` configuration files
- Creates `MSPDemoApp.xcodeproj` from YAML
- Creates `msp-ios-sdk.xcworkspace` with all projects

**Build the demo app:**
- In Xcode, select scheme: `MSPDemoApp`
- Press `⌘B` to build

---

### Setup: Swift Package Manager (SPM) Mode

**Important:** SPM mode requires XCFrameworks to be built first. These are built from CocoaPods dependencies.

**Complete setup workflow:**

```bash
# 1. First-time setup: Build XCFrameworks (requires Pods)
#    Switch to Pods mode temporarily to install dependencies
./Scripts/target-switching/switch-target.sh pods

# 2. Build all wrapper XCFrameworks (this step only needed once)
./Scripts/xcframeworks/build-all.sh

# 3. Switch to SPM mode (removes Pods, generates SPM YAML)
./Scripts/target-switching/switch-target.sh spm

# 4. Generate Xcode project from YAML
xcodegen generate --spec MSPDemoApp/project.yml

# 5. Open project in Xcode
open MSPDemoApp/MSPDemoApp.xcodeproj
```

**What this does:**
- Builds wrapper XCFrameworks for SPM (Shimmer, FBAudienceNetwork, etc.)
- Removes `Pods/` directory
- Generates `project.yml` with SPM target definitions
- Creates `MSPDemoApp.xcodeproj` with SPM dependencies

**Build the demo app:**
- In Xcode, select scheme: `MSPDemoApp-SPM`
- Press `⌘B` to build
- Wait for Xcode to resolve packages (File → Packages → Resolve Package Versions)

**Note:** After the first setup, you can skip steps 1-2. Just run steps 3-5 when switching to SPM mode.

---

### Quick Reference: Switching Between Modes

Once you've completed initial setup, you can switch between modes:

**Switch to CocoaPods Mode:**
```bash
./Scripts/target-switching/switch-target.sh pods
# Everything is automatic - Xcode opens automatically
```

**Switch to SPM Mode:**
```bash
# If XCFrameworks are already built:
./Scripts/target-switching/switch-target.sh spm
# Everything is automatic - Xcode opens automatically

# If XCFrameworks are missing, build them first:
./Scripts/target-switching/switch-target.sh pods  # Temporary switch
./Scripts/xcframeworks/build-all.sh              # Build XCFrameworks
./Scripts/target-switching/switch-target.sh spm   # Switch to SPM
# Everything is automatic - Xcode opens automatically
```

---

## 🎯 Developer Workflow

### Simplified Engineering Workflow

**Switching Targets (Automatic Project Generation):**

```bash
# Switch to SPM mode
./Scripts/target-switching/switch-target.sh spm

# Switch to CocoaPods mode
./Scripts/target-switching/switch-target.sh pods
```

The script **automatically** performs:
- Environment cleanup (Pods or SPM)
- Deterministic YAML generation (`project.yml`, `workspace.yml`)
- **Automatic `xcodegen generate`** (Xcode project regeneration)
- Workspace generation (for Pods mode)
- Environment validation
- Opens Xcode

**No manual steps required.** The workflow is fully automated.

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
│  4. Developer runs: xcodegen generate --spec ...         │
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
2. Xcode opens automatically with `MSPDemoApp.xcodeproj`
3. Select scheme `MSPDemoApp-SPM` and build

**For CocoaPods Development:**
1. Run `./Scripts/target-switching/switch-target.sh pods`
2. Xcode opens automatically with `msp-ios-sdk.xcworkspace`
3. Select scheme `MSPDemoApp` and build

**All steps are automatic** - no manual `xcodegen` or workspace generation required.

---

## 🔄 Working with Pods Mode / SPM Mode

### Pods Mode

**When to use:**
- Developing with CocoaPods dependencies
- Testing CocoaPods integration
- Building for CocoaPods release

**Workflow:**
```bash
# 1. Switch to Pods mode
./Scripts/target-switching/switch-target.sh pods

# 2. Regenerate Xcode project (REQUIRED)
xcodegen generate --spec MSPDemoApp/project.yml

# 3. Generate workspace (REQUIRED)
./Scripts/tools/generate-workspace.sh

# 4. Open workspace
open msp-ios-sdk.xcworkspace

# 5. Build MSPDemoApp scheme
```

**What happens:**
- `Pods/` directory is created/updated
- `msp-ios-sdk.xcworkspace` is created by `generate-workspace.sh` script
- `project.yml` includes Pods xcconfig references
- `workspace.yml` includes Pods project

### SPM Mode

**When to use:**
- Developing with Swift Package Manager
- Testing SPM integration
- Building for SPM release

**Prerequisites:**
- XCFrameworks must be built first (see "Building XCFrameworks" section)

**Workflow:**
```bash
# 1. Build xcframeworks (if not already built)
./Scripts/xcframeworks/build-all.sh

# 2. Switch to SPM mode
./Scripts/target-switching/switch-target.sh spm

# 3. Regenerate Xcode project (REQUIRED)
xcodegen generate --spec MSPDemoApp/project.yml

# 4. Open project
open MSPDemoApp/MSPDemoApp.xcodeproj

# 5. Build MSPDemoApp-SPM scheme
```

**What happens:**
- `Pods/` directory is removed (if exists)
- `project.yml` includes only SPM target definitions
- `workspace.yml` includes only SPM workspace definitions
- Local wrapper packages are referenced via `path:` dependencies

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

## 🧪 Deterministic YAML, Nondeterministic Project Files

### What Changes (Deterministic)

After running `switch-target.sh`, these files change deterministically:
- ✅ `MSPDemoApp/project.yml` (mode-aware target definitions)
- ✅ `workspace.yml` (mode-aware project references)

**YAML files are the single source of truth** and are fully deterministic.

### What Also Changes (Nondeterministic)

After running `switch-target.sh`, these files are **auto-generated** and may change:
- `.pbxproj` files (Xcode project files)
- `.xcscheme` files (Xcode scheme files)
- Workspace contents (xcworkspace/contents.xcworkspacedata)

**Why project files are nondeterministic:**
- Xcode constantly rewrites project files when opening/editing
- SwiftPM rewrites workspace files when resolving packages
- CocoaPods regenerates integration sections on `pod install`
- Build tools update metadata automatically
- These files are inherently nondeterministic

**Therefore:**
- ➡️ **YAML files are the only "source of truth"**
- ➡️ **PBXProj diffs are normal and acceptable**
- ➡️ **Project files are expected to change and can be committed**

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
   - Automatically run by `switch-target.sh` (no manual steps required)

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

✅ **What SHOULD be committed:**
- `project.yml` and `workspace.yml` (source of truth)
- Wrapper source files (Swift + Package.swift)
- Generated `.pbxproj` files (when Xcode project legitimately changes)
- Generated `.xcscheme` files (when schemes legitimately change)
- Workspace files (when workspace structure changes)

❌ **What SHOULD NOT be committed:**
- `DerivedData/` (build artifacts)
- `SourcePackages/` (SwiftPM cache)
- `xcuserdata/` (user-specific settings)
- `build/` directories (build outputs)
- `.swiftpm/` directories (SwiftPM cache)

**Automatic project generation:**
- `switch-target.sh` automatically runs `xcodegen generate`
- No manual steps required
- Project files are regenerated from YAML on every switch

---

## 🛠 Common Mistakes and How to Avoid Them

### ❌ Committing Generated Xcode Files

**Mistake:** Committing `.pbxproj`, `.xcscheme`, or `.xcworkspace` files

**Why it's bad:**
- Causes merge conflicts
- Breaks zero-diff switching guarantee
- Pollutes git history
- Creates inconsistent project states

**How to avoid:**
- Pre-commit hook automatically blocks these files (see below)
- Always check `git status` before committing
- If you see these files, run: `git restore MSPDemoApp/**/*.pbxproj MSPDemoApp/**/*.xcscheme`

**What to commit instead:**
- Only `project.yml` and `workspace.yml`
- Source code files (`.swift`, `.m`, `.h`)
- Configuration files

### ✅ Automatic Project Generation

**Good news:** `xcodegen generate` now runs automatically!

**What happens:**
- `switch-target.sh` automatically runs `xcodegen generate` after YAML generation
- No manual steps required
- Project files are always up-to-date after switching

**If you see build errors:**
- Clean DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/*`
- Rebuild in Xcode
- For SPM: Wait for package resolution (File → Packages → Resolve Package Versions)

### ❌ Building XCFrameworks in Wrong Mode

**Mistake:** Trying to build xcframeworks in SPM mode without Pods

**Symptoms:**
- `build-all.sh` fails with "Pods directory not found"
- Missing xcframework errors in SPM builds

**How to avoid:**
- Always build xcframeworks in Pods mode first
- Workflow: `switch-target.sh pods` → `build-all.sh` → `switch-target.sh spm`

### ❌ Mixed Environment State

**Mistake:** Having both `Pods/` and `.swiftpm/` directories

**Symptoms:**
- Validation errors
- Conflicting dependencies
- Build failures

**How to avoid:**
- Always use `switch-target.sh` to switch modes (never manually mix)
- Run validation: `./Scripts/target-switching/validate_environment.sh [spm|pods]`

---

## 🛠 Troubleshooting

### Build Errors After Switching

**Problem:** Build fails after switching targets

**Solution:**
```bash
# 1. Regenerate Xcode project from YAML
xcodegen generate --spec MSPDemoApp/project.yml

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
# Clean everything and re-switch (automatically regenerates project)
./Scripts/target-switching/cleanup_spm.sh --force
./Scripts/target-switching/cleanup_pods.sh
./Scripts/target-switching/switch-target.sh [spm|pods]
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
        2. Regenerate Xcode projects: `xcodegen generate --spec MSPDemoApp/project.yml`
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
xcodegen generate --spec MSPDemoApp/project.yml
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
