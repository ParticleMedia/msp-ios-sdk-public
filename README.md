# MSP iOS SDK

[![CocoaPods](https://img.shields.io/cocoapods/v/MSPCore.svg)](https://cocoapods.org/pods/MSPCore)
[![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![iOS 15.0+](https://img.shields.io/badge/iOS-15.0+-blue.svg)](https://developer.apple.com/ios/)

Internal SDK repository containing MSPDemoApp, all core modules, adapters, and the Pods ↔ SPM toolchain.

---

## 1. SDK Developer Workflow (Start Here)

### 1.1 Prerequisites

```bash
brew install xcodegen cocoapods
```

### 1.2 Fresh Clone & Setup (CocoaPods Mode)

For a fresh clone, just run these commands:

```bash
git clone <repo-url>
cd msp-ios-sdk
pod install
open msp-ios-sdk.xcworkspace
```

Then select scheme **MSPDemoApp** → Run.

**That's it!** No additional scripts needed for initial setup.

### 1.3 Build from Command Line (CocoaPods Mode)

```bash
xcodebuild \
  -workspace msp-ios-sdk.xcworkspace \
  -scheme MSPDemoApp \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  build
```

> Note: Change `iPhone 16` to any simulator available on your machine.

---

## 2. When Do You Need `switch-target.sh`?

The `switch-target.sh` script is **ONLY needed when switching between modes**, not for initial setup.

| Scenario | What to run |
|----------|-------------|
| Fresh clone (first time) | `pod install` → open workspace |
| Already in Pods mode, want to stay | Nothing needed |
| Switch from Pods → SPM | `./Scripts/target-switching/switch-target.sh spm` |
| Switch from SPM → Pods | `./Scripts/target-switching/switch-target.sh pods` |

### 2.1 Switch to SPM Mode

```bash
./Scripts/target-switching/switch-target.sh spm
```

This will:
- Clean `Pods/` directory
- Auto-sync XCFrameworks if missing
- Generate SPM project via XcodeGen
- Open `Examples/MSPDemoApp/MSPDemoApp.xcodeproj`

After Xcode opens, select scheme **MSPDemoApp-SPM** → Run.

### 2.2 Switch Back to CocoaPods Mode (from SPM)

```bash
./Scripts/target-switching/switch-target.sh pods
```

This will:
- Clean SPM artifacts
- Run `pod install`
- Generate workspace via XcodeGen
- Open `msp-ios-sdk.xcworkspace`

### 2.3 Summary Table

| Mode | Workspace/Project | Scheme |
|------|-------------------|--------|
| **CocoaPods** | `msp-ios-sdk.xcworkspace` | `MSPDemoApp` |
| **SPM** | `Examples/MSPDemoApp/MSPDemoApp.xcodeproj` | `MSPDemoApp-SPM` |

---

## 3. Round-Trip Testing

Test that both modes work correctly:

```bash
./Scripts/target-switching/round-trip-test.sh
```

**Stress test (multiple cycles):**

```bash
./Scripts/target-switching/round-trip-test.sh --stress=3
```

---

## 4. Upgrading Third-Party SDKs

> **Podfile is the only source of truth** for all third-party SDK versions.

### Step-by-Step Process

**1. Update version in Podfile:**

```ruby
pod 'Google-Mobile-Ads-SDK', '~> 12.0'
```

**2. Run these 3 commands:**

```bash
pod install                                     # Update Pods
./Scripts/spm-sync/spm_sync_all.sh              # Extract XCFrameworks to ThirdParty/
./Scripts/target-switching/round-trip-test.sh  # Validate both modes work
```

### Rules

| ✅ Do | ❌ Don't |
|-------|----------|
| Update versions in `Podfile` | Manually edit `ThirdParty/` contents |
| Run `spm_sync_all.sh` after changes | Edit third-party versions in `Package.swift` |

### Special Cases

- **PrebidMobile**: Uses canonical XCFramework at `ThirdParty/PrebidMobile/` (no extraction)
- **GoogleMobileAds**: Uses official SPM package (skip extraction)

---

## 5. Troubleshooting

### Pods build fails

```bash
pod install
rm -rf ~/Library/Developer/Xcode/DerivedData/*
open msp-ios-sdk.xcworkspace
```

### SPM: "binary target does not contain a binary artifact"

```bash
./Scripts/spm-sync/spm_sync_all.sh
./Scripts/target-switching/switch-target.sh spm
```

### SPM: "no such module XXX"

```bash
rm -rf .swiftpm .build
./Scripts/spm-sync/spm_sync_all.sh
./Scripts/target-switching/switch-target.sh spm
```

### Nuclear Option (Full Reset)

```bash
# 1. Clean everything
rm -rf Pods/ .swiftpm .build ~/Library/Developer/Xcode/DerivedData/*

# 2. Reinstall
pod install
./Scripts/spm-sync/spm_sync_all.sh

# 3. Switch to desired mode
./Scripts/target-switching/switch-target.sh pods   # or: spm
```

### Full CI Validation

```bash
./Scripts/ci/ci_validate.sh
```

---

## 6. Repository Layout

```
msp-ios-sdk/
├── Sources/
│   ├── Core/                 # Core modules (5)
│   ├── Adapters/             # Ad network adapters (10)
│   └── Common/               # Shared modules
│
├── Build/XCFrameworks/       # Pre-built core XCFrameworks
├── ThirdParty/               # Third-party XCFrameworks (from Pods)
│
├── Scripts/
│   ├── spm-sync/             # Pods → SPM sync
│   ├── target-switching/     # Mode switching
│   └── ci/                   # CI scripts
│
├── Examples/MSPDemoApp/      # Demo app
├── msp-ios-sdk.xcworkspace   # CocoaPods workspace
├── Package.swift             # SPM manifest
└── Podfile                   # CocoaPods (source of truth)
```

---

## 7. Architecture

```
Podfile  (source of truth)
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

## 8. Internal Documentation

| Document | Description |
|----------|-------------|
| [DEPENDENCY_MIGRATION_GUIDE_ZH.md](Docs/DEPENDENCY_MIGRATION_GUIDE_ZH.md) | Chinese technical reference |

---

## 9. External App Integration

### CocoaPods

```ruby
pod 'MSPCore'
pod 'MSPGoogleAdapter'
pod 'MSPFacebookAdapter'
```

### SPM

```
https://github.com/ParticleMedia/msp-ios-sdk-public.git
```

---

## 10. Requirements

| Requirement | Version |
|-------------|---------|
| iOS | 15.0+ |
| Swift | 5.9+ |
| Xcode | 15.0+ |
| CocoaPods | 1.14.0+ |
| XcodeGen | Latest |

---

## 11. Contact

**Email:** pengyu.gou@newsbreak.com  
**GitHub Issues:** [msp-ios-sdk-public](https://github.com/ParticleMedia/msp-ios-sdk-public/issues)
