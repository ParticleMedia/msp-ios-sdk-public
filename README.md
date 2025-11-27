# MSP iOS SDK

[![CocoaPods](https://img.shields.io/cocoapods/v/MSPCore.svg)](https://cocoapods.org/pods/MSPCore)
[![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![iOS 15.0+](https://img.shields.io/badge/iOS-15.0+-blue.svg)](https://developer.apple.com/ios/)

Internal SDK repository containing MSPDemoApp, all core modules, adapters, and the Pods ↔ SPM toolchain.

---

## 1. SDK Developer Workflow (Start Here)

This section covers day-to-day development in this repository.

### 1.1 Prerequisites

```bash
# Required tools
brew install xcodegen cocoapods
```

### 1.2 Clone & Bootstrap

```bash
git clone <repo-url>
cd msp-ios-sdk
pod install
```

**Recommended default mode:** 👉 **CocoaPods** (more stable for development & debugging)

### 1.3 Run MSPDemoApp (CocoaPods Mode — Recommended)

**Option A: Open in Xcode**

```bash
open msp-ios-sdk.xcworkspace
```

Then select scheme **MSPDemoApp** and run.

**Option B: Command line build**

```bash
xcodebuild \
  -workspace msp-ios-sdk.xcworkspace \
  -scheme MSPDemoApp \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  build
```

> Note: Change `iPhone 16` to any simulator available on your machine.

### 1.4 Run MSPDemoApp (SPM Mode)

**Step 1: Switch to SPM mode**

```bash
./Scripts/target-switching/switch-target.sh spm
```

This script will:
- Clean `Pods/` directory
- Auto-sync XCFrameworks if missing (runs `spm_sync_all.sh`)
- Generate SPM project via XcodeGen
- Open Xcode automatically

**Step 2: Build**

After Xcode opens, select scheme **MSPDemoApp-SPM** and run.

Or build from command line:

```bash
xcodebuild \
  -project Examples/MSPDemoApp/MSPDemoApp.xcodeproj \
  -scheme MSPDemoApp-SPM \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  build
```

---

## 2. Switching Between CocoaPods & SPM

| Mode | Purpose | What to Open |
|------|---------|--------------|
| **CocoaPods** | Main development mode | `msp-ios-sdk.xcworkspace` |
| **SPM** | Validate Package.swift & distribution | `Examples/MSPDemoApp/MSPDemoApp.xcodeproj` |

### 2.1 Switch to CocoaPods Mode

```bash
./Scripts/target-switching/switch-target.sh pods
```

This will:
- Clean SPM artifacts
- Run `pod install`
- Generate workspace via XcodeGen
- Open `msp-ios-sdk.xcworkspace`

### 2.2 Switch to SPM Mode

```bash
./Scripts/target-switching/switch-target.sh spm
```

This will:
- Remove `Pods/` directory
- Auto-sync third-party XCFrameworks if missing
- Generate SPM project via XcodeGen
- Open `Examples/MSPDemoApp/MSPDemoApp.xcodeproj`

### 2.3 Round-Trip Test (Pods → SPM → Pods)

```bash
./Scripts/target-switching/round-trip-test.sh
```

**Stress test (multiple cycles):**

```bash
./Scripts/target-switching/round-trip-test.sh --stress=3
```

Round-trip tests ensure both modes stay clean and interchangeable.

---

## 3. Dependency Sync (Pods → XCFramework → SPM)

> **Podfile is the only source of truth** for all third-party SDK versions.

### When Upgrading Third-Party SDKs

When you need to update Google, IronSource, InMobi, Mintegral, or any other third-party SDK:

**Step 1: Update version in Podfile**

```ruby
# Example: Update Google Mobile Ads
pod 'Google-Mobile-Ads-SDK', '~> 12.0'
```

**Step 2: Run these 3 commands in order**

```bash
pod install                                     # Update Pods
./Scripts/spm-sync/spm_sync_all.sh              # Extract XCFrameworks to ThirdParty/
./Scripts/target-switching/round-trip-test.sh  # Validate both modes work
```

### Important Rules

| ✅ Do | ❌ Don't |
|-------|----------|
| Update versions in `Podfile` | Manually edit `ThirdParty/` contents |
| Run `spm_sync_all.sh` after Podfile changes | Edit third-party versions in `Package.swift` |
| Validate with round-trip test | Skip sync after upgrading SDKs |

### Special Cases

- **PrebidMobile**: Uses canonical XCFramework at `ThirdParty/PrebidMobile/` (no extraction needed)
- **GoogleMobileAds**: Uses official SPM package from Google (skip extraction)

---

## 4. Troubleshooting

### MSPDemoApp (Pods mode) build fails

```bash
# Clean and reinstall
pod install
rm -rf ~/Library/Developer/Xcode/DerivedData/*
open msp-ios-sdk.xcworkspace
```

### MSPDemoApp-SPM: "binary target does not contain a binary artifact"

```bash
# Re-sync XCFrameworks from Pods
./Scripts/spm-sync/spm_sync_all.sh
./Scripts/target-switching/switch-target.sh spm
```

### MSPDemoApp-SPM: "no such module XXX"

```bash
# Clean SPM cache and re-sync
rm -rf .swiftpm .build
./Scripts/spm-sync/spm_sync_all.sh
./Scripts/target-switching/switch-target.sh spm
```

### General Recovery (Nuclear Option)

If nothing works, run these commands in order:

```bash
# 1. Clean everything
rm -rf Pods/ .swiftpm .build ~/Library/Developer/Xcode/DerivedData/*

# 2. Reinstall and sync
pod install
./Scripts/spm-sync/spm_sync_all.sh

# 3. Switch to your desired mode
./Scripts/target-switching/switch-target.sh pods   # or: spm
```

### Full CI Validation

Run the complete validation pipeline:

```bash
./Scripts/ci/ci_validate.sh
```

This runs: cleanup → pod install → sync → Pods build → SPM build → round-trip test.

---

## 5. Repository Layout

```
msp-ios-sdk/
├── Sources/
│   ├── Core/                 # Core modules (5): MSPSharedLibraries, MSPiOSCore, NovaCore, MSPCore, MSPOMSDK
│   ├── Adapters/             # Ad network adapters (10)
│   └── Common/               # Shared modules (MSPGoogleAdsTypes, wrappers)
│
├── Build/XCFrameworks/       # Pre-built core XCFrameworks (5)
│
├── ThirdParty/               # Third-party XCFrameworks (extracted from Pods)
│
├── Scripts/
│   ├── spm-sync/             # Pods → SPM sync tools
│   │   ├── extract_from_pods.sh
│   │   ├── generate_package_swift.sh
│   │   └── spm_sync_all.sh
│   ├── target-switching/     # Pods ↔ SPM mode switching
│   │   ├── switch-target.sh
│   │   ├── round-trip-test.sh
│   │   └── validate_xcframeworks.sh
│   └── ci/
│       └── ci_validate.sh
│
├── Examples/MSPDemoApp/      # Demo application
│   ├── MSPDemoApp.xcodeproj  # SPM mode project
│   └── project.yml           # XcodeGen spec
│
├── msp-ios-sdk.xcworkspace   # CocoaPods workspace
├── Package.swift             # SPM manifest
├── Podfile                   # CocoaPods dependencies (source of truth)
└── *.podspec                 # Pod specifications (16)
```

---

## 6. Architecture Overview

```
Podfile  (single version source of truth)
    │
    ▼ pod install
Pods/                  → ThirdParty/*.xcframework
    │                              │
    └──► spm_sync_all.sh ──────────┘
                              │
                              ▼
                        Package.swift
                              │
             ┌───────────────┼───────────────┐
             ▼                               ▼
      Pods mode                         SPM mode
 (msp-ios-sdk.xcworkspace)     (MSPDemoApp.xcodeproj)
      Scheme: MSPDemoApp         Scheme: MSPDemoApp-SPM
```

---

## 7. Internal Developer Documentation

| Document | Description |
|----------|-------------|
| [DEPENDENCY_MIGRATION_GUIDE_ZH.md](Docs/DEPENDENCY_MIGRATION_GUIDE_ZH.md) | Full Chinese technical reference for architecture, scripts, and migration workflows |

> These documents are for **SDK maintainers** within the team. External app developers typically do not need them.

---

## 8. External App Integration

> For app developers integrating MSP SDK into their apps.

### CocoaPods

```ruby
pod 'MSPCore'
pod 'MSPGoogleAdapter'
pod 'MSPFacebookAdapter'
# ... add other adapters as needed
```

### SPM

```
https://github.com/ParticleMedia/msp-ios-sdk-public.git
```

Full integration documentation is available in the [public SDK docs](https://github.com/ParticleMedia/msp-ios-sdk-public).

---

## 9. Requirements

| Requirement | Version |
|-------------|---------|
| iOS | 15.0+ |
| Swift | 5.9+ |
| Xcode | 15.0+ |
| CocoaPods | 1.14.0+ |
| XcodeGen | Latest |

---

## 10. Contact

**Email:** pengyu.gou@newsbreak.com  
**GitHub Issues:** [msp-ios-sdk-public](https://github.com/ParticleMedia/msp-ios-sdk-public/issues)
