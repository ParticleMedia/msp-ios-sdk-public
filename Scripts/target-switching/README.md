# Target Switching System

This directory contains scripts for switching between **CocoaPods** and **Swift Package Manager (SPM)** build modes for the MSP iOS SDK.

## Overview

The MSP iOS SDK supports two dependency management modes:

| Mode | Use Case | Target | Workspace |
|------|----------|--------|-----------|
| **Pods** | Development, CI/CD | MSPDemoApp | msp-ios-sdk.xcworkspace |
| **SPM** | Distribution, Integration | MSPDemoApp-SPM | MSPDemoApp.xcodeproj |

## Quick Start

### Switch to CocoaPods Mode
```bash
./Scripts/target-switching/switch-target.sh pods
```

### Switch to SPM Mode
```bash
./Scripts/target-switching/switch-target.sh spm
```

### Run Round-Trip Test
```bash
./Scripts/target-switching/round-trip-test.sh
```

## Scripts

| Script | Purpose |
|--------|---------|
| `switch-target.sh` | Main entry point for mode switching |
| `common.sh` | Shared utilities and path definitions |
| `cleanup_pods.sh` | Clean CocoaPods artifacts |
| `cleanup_spm.sh` | Clean SPM artifacts |
| `generate_workspace.sh` | Generate YAML specs for XcodeGen |
| `validate_xcframeworks.sh` | Validate all required XCFrameworks |
| `switch-target-validator.sh` | Comprehensive environment validation |
| `round-trip-test.sh` | Automated round-trip testing |

## Architecture

### XCFramework Layout

```
msp-ios-sdk/
├── Build/XCFrameworks/               # Core XCFrameworks
│   ├── MSPSharedLibraries.xcframework
│   ├── MSPiOSCore.xcframework
│   ├── NovaCore.xcframework
│   ├── MSPCore.xcframework
│   └── MSPOMSDK.xcframework
├── ThirdParty/                       # Third-party XCFrameworks
│   └── PrebidMobile/
│       └── PrebidMobile.xcframework
└── Sources/
    ├── Core/                         # Core module sources
    │   ├── MSPSharedLibraries/
    │   ├── MSPiOSCore/
    │   ├── NovaCore/
    │   ├── MSPCore/
    │   └── MSPOMSDK/
    └── Adapters/                     # Adapter source modules
        ├── MSPPrebidAdapter/
        ├── MSPGoogleAdapter/
        ├── MSPFacebookAdapter/
        ├── NovaAdapter/
        ├── AmazonAdapter/
        ├── UnityAdapter/
        ├── InmobiAdapter/
        ├── MobilefuseAdapter/
        ├── MintegralAdapter/
        └── PubmaticAdapter/
```

### Adapters (10 total)

| Adapter | Module Name | Source Path |
|---------|-------------|-------------|
| Prebid | MSPPrebidAdapter | Sources/Adapters/MSPPrebidAdapter |
| Google | MSPGoogleAdapter | Sources/Adapters/MSPGoogleAdapter |
| Facebook | MSPFacebookAdapter | Sources/Adapters/MSPFacebookAdapter |
| Nova | NovaAdapter | Sources/Adapters/NovaAdapter |
| Amazon | AmazonAdapter | Sources/Adapters/AmazonAdapter |
| Unity | UnityAdapter | Sources/Adapters/UnityAdapter |
| InMobi | InmobiAdapter | Sources/Adapters/InmobiAdapter |
| MobileFuse | MobilefuseAdapter | Sources/Adapters/MobilefuseAdapter |
| Mintegral | MintegralAdapter | Sources/Adapters/MintegralAdapter |
| Pubmatic | PubmaticAdapter | Sources/Adapters/PubmaticAdapter |

## Required XCFrameworks

### For SPM Mode

All of these must exist before switching to SPM mode:

| XCFramework | Path |
|-------------|------|
| MSPSharedLibraries | `Build/XCFrameworks/MSPSharedLibraries.xcframework` |
| MSPiOSCore | `Build/XCFrameworks/MSPiOSCore.xcframework` |
| NovaCore | `Build/XCFrameworks/NovaCore.xcframework` |
| MSPCore | `Build/XCFrameworks/MSPCore.xcframework` |
| MSPOMSDK | `Build/XCFrameworks/MSPOMSDK.xcframework` |
| PrebidMobile | `ThirdParty/PrebidMobile/PrebidMobile.xcframework` |
| OMSDK | `Sources/Core/MSPOMSDK/OMSDK_Newsbreak1.xcframework` |

### Building Missing XCFrameworks

```bash
# Build all Core XCFrameworks
./Scripts/xcframeworks/build-core.sh

# Verify XCFrameworks
./Scripts/target-switching/validate_xcframeworks.sh
```

## Mode Switching Details

### Pods → SPM

1. Delete `Pods/`, `Podfile.lock`
2. Delete `msp-ios-sdk.xcworkspace`
3. Clean DerivedData
4. Validate required XCFrameworks exist
5. Generate SPM-mode `project.yml` (with `MSPDemoApp-SPM` target)
6. Run `xcodegen` to generate `.xcodeproj`
7. Open `MSPDemoApp.xcodeproj`

### SPM → Pods

1. Remove `.swiftpm/`, `SourcePackages/`, `.build/`
2. Delete `Package.resolved`
3. Clean DerivedData
4. Generate Pods-mode `project.yml` (with `MSPDemoApp` target, `packages: {}`)
5. Run `xcodegen`
6. Run `pod install`
7. Open `msp-ios-sdk.xcworkspace`

## Round-Trip Testing

The round-trip test validates that switching modes works correctly:

```
┌──────────────────────────────────────────────────────┐
│                 ROUND-TRIP TEST                      │
├──────────────────────────────────────────────────────┤
│ 1. Switch to Pods mode                               │
│ 2. Validate Pods environment                         │
│ 3. Build MSPDemoApp (Pods)                           │
│ 4. Switch to SPM mode                                │
│ 5. Validate SPM environment                          │
│ 6. Build MSPDemoApp-SPM                              │
│ 7. Switch back to Pods mode                          │
│ 8. Validate Pods environment (final)                 │
│ 9. Build MSPDemoApp (final)                          │
└──────────────────────────────────────────────────────┘
```

### Run with Build Skipped (Mode Switching Only)
```bash
./Scripts/target-switching/round-trip-test.sh --skip-build
```

## Troubleshooting

### "XCFramework validation failed"

**Cause:** One or more Core XCFrameworks are missing from `Build/XCFrameworks/`

**Fix:**
```bash
# Build Core XCFrameworks
./Scripts/xcframeworks/build-core.sh

# Then retry
./Scripts/target-switching/switch-target.sh spm
```

### "PrebidMobile.xcframework missing"

**Cause:** The canonical PrebidMobile XCFramework is not at `ThirdParty/PrebidMobile/`

**Fix:**
1. Ensure `ThirdParty/PrebidMobile/PrebidMobile.xcframework` exists
2. Verify it's not in `.gitignore`

### "Mixed environment detected"

**Cause:** Both SPM and Pods artifacts exist simultaneously

**Fix:**
```bash
# Clean SPM artifacts
./Scripts/target-switching/cleanup_spm.sh --force

# Or clean Pods artifacts
rm -rf Pods Podfile.lock msp-ios-sdk.xcworkspace
```

### "Pods/ directory exists in SPM mode"

**Cause:** `cleanup_pods.sh` didn't fully clean the Pods directory

**Fix:**
```bash
rm -rf Pods Podfile.lock
./Scripts/target-switching/switch-target.sh spm
```

### "Build fails with missing module"

**Cause:** XCFrameworks or adapters not properly linked

**Fix:**
1. Verify XCFrameworks: `./Scripts/target-switching/validate_xcframeworks.sh`
2. Clean DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/*`
3. Re-run mode switch

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `SKIP_CODE_SIGN` | Skip code signing during XCFramework builds | `1` |
| `MSP_SKIP_CP_XCFRAMEWORKS` | Skip CocoaPods XCFramework copy phase | Not set |

## Files Generated

### Pods Mode

- `project.yml` → `MSPDemoApp` target with Pods xcconfig
- `workspace.yml` → Includes `Pods/Pods.xcodeproj`
- `msp-ios-sdk.xcworkspace` → Contains MSPDemoApp + Pods

### SPM Mode

- `project.yml` → `MSPDemoApp-SPM` target with SPM dependencies
- `workspace.yml` → Excludes Pods
- `MSPDemoApp.xcodeproj` → Standalone project

## Safety Features

The scripts include safety checks to prevent accidental deletion of:

- `Build/XCFrameworks/` (Core XCFrameworks)
- `ThirdParty/` (Third-party XCFrameworks)
- `Sources/` (Source code)

## Version History

| Version | Date | Changes |
|---------|------|---------|
| Round 26 | Nov 2025 | Updated for new SDK architecture |
| - | - | New XCFramework paths (Build/XCFrameworks/) |
| - | - | Canonical ThirdParty/PrebidMobile/ path |
| - | - | 10 adapter source modules |
| - | - | 16-product Package.swift |

