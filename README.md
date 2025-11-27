# MSP iOS SDK

[![CocoaPods](https://img.shields.io/cocoapods/v/MSPCore.svg)](https://cocoapods.org/pods/MSPCore)
[![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![iOS 15.0+](https://img.shields.io/badge/iOS-15.0+-blue.svg)](https://developer.apple.com/ios/)

Internal SDK repository containing MSPDemoApp, all core modules, adapters, and the Pods ↔ SPM toolchain.

---

## 1. SDK Developer Workflow (Start Here)

This section covers day-to-day development in this repository.

### 1.1 Clone & Bootstrap

```bash
git clone <repo-url>
cd msp-ios-sdk
pod install
open msp-ios-sdk.xcworkspace   # CocoaPods mode (default)
```

**Recommended default mode:** 👉 **CocoaPods** (more stable for development & debugging)

### 1.2 Run MSPDemoApp (CocoaPods Mode — Recommended)

| Item | Value |
|------|-------|
| Open | `msp-ios-sdk.xcworkspace` |
| Scheme | `MSPDemoApp` |
| Target | iOS Simulator (e.g., iPhone 16) |

**Command line:**

```bash
xcodebuild \
  -workspace msp-ios-sdk.xcworkspace \
  -scheme MSPDemoApp \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  build
```

### 1.3 Run MSPDemoApp (SPM Mode)

**Switch to SPM mode:**

```bash
./Scripts/target-switching/switch-target.sh spm
```

This will:
- Clean `Pods/`
- Validate XCFrameworks (auto-sync via `spm_sync_all.sh` if missing)
- Generate SPM project using XcodeGen
- Open Xcode

| Item | Value |
|------|-------|
| Open | `Examples/MSPDemoApp/MSPDemoApp.xcodeproj` |
| Scheme | `MSPDemoApp-SPM` |

**Command line:**

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

The repo supports two modes:

| Mode | Purpose | Workspace/Project |
|------|---------|-------------------|
| **CocoaPods** | Main development mode | `msp-ios-sdk.xcworkspace` |
| **SPM** | Validate Package.swift & distribution | `MSPDemoApp.xcodeproj` |

### 2.1 Switch to CocoaPods Mode

```bash
./Scripts/target-switching/switch-target.sh pods
```

This will:
- Clean SPM artifacts
- Run XcodeGen to regenerate workspace
- Run `pod install`
- Open the workspace

### 2.2 Switch to SPM Mode

```bash
./Scripts/target-switching/switch-target.sh spm
```

This will:
- Remove `Pods/`
- Auto-sync third-party XCFrameworks if missing
- Generate SPM-only project
- Open the SPM project

### 2.3 Round-Trip Test (Pods → SPM → Pods)

```bash
./Scripts/target-switching/round-trip-test.sh
```

**Stress test:**

```bash
./Scripts/target-switching/round-trip-test.sh --stress=3
```

Round-trip tests ensure both modes stay clean and interchangeable.

---

## 3. Dependency Sync (Pods → XCFramework → SPM)

> **Podfile is the only source of truth** for all third-party SDK versions.

When upgrading any third-party SDK (Google, IronSource, InMobi, Mintegral, etc.):

### 3 Steps You Must Run

```bash
pod install                                      # Step 1: Update Pods
./Scripts/spm-sync/spm_sync_all.sh               # Step 2: Extract SDK XCFrameworks
./Scripts/target-switching/round-trip-test.sh   # Step 3: Validate both modes
```

### Important Rules

| ✅ Do | ❌ Don't |
|-------|----------|
| Update versions in `Podfile` | Manually modify `ThirdParty/` |
| Run `spm_sync_all.sh` after changes | Edit third-party versions in `Package.swift` |
| Validate with round-trip test | Skip sync after Podfile changes |

**Special cases:**
- `PrebidMobile` — Uses canonical XCFramework path (no extraction)
- `GoogleMobileAds` — Uses official SPM package (skip extraction)

---

## 4. Troubleshooting (Developer Quick Guide)

### MSPDemoApp (Pods mode) build fails

```bash
pod install
rm -rf ~/Library/Developer/Xcode/DerivedData/*
open msp-ios-sdk.xcworkspace
```

### MSPDemoApp-SPM: "binary target does not contain a binary artifact"

```bash
./Scripts/spm-sync/spm_sync_all.sh
./Scripts/target-switching/switch-target.sh spm
```

### MSPDemoApp-SPM: "no such module XXX"

```bash
./Scripts/spm-sync/spm_sync_all.sh
rm -rf .swiftpm .build
```

### DemoApp crashes after SDK version upgrade

Run full validation:

```bash
./Scripts/ci/ci_validate.sh
```

### General Recovery Order

If you're stuck, run these commands in order:

```bash
# 1. Clean everything
rm -rf Pods/ .swiftpm .build ~/Library/Developer/Xcode/DerivedData/*

# 2. Reinstall and sync
pod install
./Scripts/spm-sync/spm_sync_all.sh

# 3. Switch to your desired mode
./Scripts/target-switching/switch-target.sh pods   # or: spm
```

---

## 5. Repository Layout

```
msp-ios-sdk/
│
├── Sources/
│   ├── Core/                 # Core module sources (5)
│   ├── Adapters/             # Ad network adapters (10)
│   └── Common/               # Shared modules & wrappers
│
├── Build/XCFrameworks/       # Pre-built core binaries
│
├── ThirdParty/               # Extracted third-party frameworks
│
├── Scripts/
│   ├── spm-sync/             # Pods → SPM sync tools
│   ├── target-switching/     # Pods ↔ SPM switching
│   └── ci/                   # CI validation scripts
│
├── Examples/MSPDemoApp/      # Demo application
│
├── Docs/                     # Internal documentation
│
├── Package.swift             # SPM manifest
├── Podfile                   # CocoaPods dependencies
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

---

## 10. Contact

**Email:** pengyu.gou@newsbreak.com  
**GitHub Issues:** [msp-ios-sdk-public](https://github.com/ParticleMedia/msp-ios-sdk-public/issues)
