# XCFramework Build Pipeline

This directory contains scripts for building all MSP iOS SDK modules into XCFrameworks.

## Overview

The XCFramework pipeline builds all business modules (NovaCore, MSPCore, MSPOMSDK, MSPSharedLibraries, and all adapters) into `.xcframework` outputs located at:

```
build/XCFrameworks/<ModuleName>.xcframework
```

These XCFrameworks are used by CocoaPods via `vendored_frameworks` in podspecs.

## Architecture

- **Build System:** XcodeGen (project.yml files only)
- **Dependency Manager:** CocoaPods (3rd-party SDKs only, does NOT build MSP code)
- **Output Format:** XCFramework (iOS + iOS Simulator)
- **Build Flags:** `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`, Swift module interfaces, dSYM

## Scripts

### build_module.sh

Reusable builder for a single module.

**Usage:**
```bash
./Scripts/xcframeworks/build_module.sh <ModuleName>
```

**Example:**
```bash
./Scripts/xcframeworks/build_module.sh NovaCore
```

**What it does:**
1. Generates Xcode project from `<ModuleName>/project.yml`
2. Builds iOS device archive
3. Builds iOS Simulator archive
4. Creates XCFramework from both archives
5. Verifies XCFramework structure

**Output:**
- `build/archives/<ModuleName>-iOS.xcarchive`
- `build/archives/<ModuleName>-Simulator.xcarchive`
- `build/XCFrameworks/<ModuleName>.xcframework`

### build-core.sh

Builds core modules in correct dependency order:
1. NovaCore
2. MSPCore
3. MSPOMSDK
4. MSPSharedLibraries

**Usage:**
```bash
./Scripts/xcframeworks/build-core.sh
```

**Behavior:**
- Builds modules sequentially (respects dependencies)
- Aborts on first failure
- Reports success/failure for each module

### build-adapters.sh

Builds all adapter modules:
- NovaAdapter
- PrebidAdapter
- MSPGoogleAdapter
- MSPFacebookAdapter
- InmobiAdapter
- MintegralAdapter
- MobilefuseAdapter
- PubmaticAdapter
- UnityAdapter
- AmazonAdapter

**Usage:**
```bash
./Scripts/xcframeworks/build-adapters.sh
```

**Behavior:**
- Builds all adapters
- Continues on failure (reports at end)
- Exits with error if any adapter fails

### build-all.sh

One-click build for the entire SDK.

**Usage:**
```bash
./Scripts/xcframeworks/build-all.sh
```

**What it does:**
1. Runs `build-core.sh`
2. If successful, runs `build-adapters.sh`
3. Generates unified build report: `build/XCFrameworks/BuildReport.md`

**Output:**
- All XCFrameworks in `build/XCFrameworks/`
- Build report with status and timing

## Build Order

The pipeline respects the following dependency order:

```
NovaCore
  ↓
MSPCore
  ↓
MSPOMSDK
  ↓
MSPSharedLibraries
  ↓
Adapters (parallel or sequential)
```

## Prerequisites

1. **XcodeGen:** Must be installed and in PATH
   ```bash
   brew install xcodegen
   ```

2. **Xcode Command Line Tools:** Required for `xcodebuild`
   ```bash
   xcode-select --install
   ```

3. **Project.yml Files:** All modules must have `project.yml` files:
   - `NovaCore/project.yml`
   - `MSPCore/project.yml`
   - `MSPOMSDK/project.yml`
   - `MSPSharedLibraries/project.yml`
   - Each adapter must have `project.yml`

## Output Structure

```
build/
├── archives/
│   ├── NovaCore-iOS.xcarchive
│   ├── NovaCore-Simulator.xcarchive
│   ├── MSPCore-iOS.xcarchive
│   └── ...
└── XCFrameworks/
    ├── NovaCore.xcframework
    ├── MSPCore.xcframework
    ├── MSPOMSDK.xcframework
    ├── MSPSharedLibraries.xcframework
    ├── NovaAdapter.xcframework
    └── ...
```

## Verification

After building, verify all XCFrameworks exist:

```bash
ls -la build/XCFrameworks/*.xcframework
```

Check the build report:

```bash
cat build/XCFrameworks/BuildReport.md
```

## Troubleshooting

### Module build fails

1. Check that `project.yml` exists for the module
2. Verify XcodeGen can generate the project:
   ```bash
   xcodegen generate --spec <ModuleName>/project.yml
   ```
3. Check build logs in DerivedData:
   ```bash
   DerivedData/build-<ModuleName>/
   ```

### XCFramework missing slices

- Verify both iOS and Simulator archives were created
- Check that `xcodebuild -create-xcframework` completed successfully
- Ensure framework paths in archives are correct

### Swift module not found

- Some modules may not have Swift code (this is normal)
- Verify framework structure:
  ```bash
  ls -la build/XCFrameworks/<Module>.xcframework/ios-arm64/<Module>.framework/Modules/
  ```

## Integration with CocoaPods

After building XCFrameworks, podspecs reference them via:

```ruby
spec.vendored_frameworks = 'build/XCFrameworks/<ModuleName>.xcframework'
```

CocoaPods will include these XCFrameworks when `pod install` is run.

## Clean Build

To clean all build artifacts:

```bash
rm -rf build/archives build/XCFrameworks DerivedData/build-*
```

## Notes

- Scripts use isolated DerivedData per module: `DerivedData/build-<Module>`
- All scripts fail on error (`set -euo pipefail`)
- Scripts must be run from repository root
- Never references Pods or workspace (XcodeGen project.yml only)

