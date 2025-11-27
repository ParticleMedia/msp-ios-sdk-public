# MSP iOS SDK

[![CocoaPods](https://img.shields.io/cocoapods/v/MSPCore.svg)](https://cocoapods.org/pods/MSPCore)
[![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![iOS 15.0+](https://img.shields.io/badge/iOS-15.0+-blue.svg)](https://developer.apple.com/ios/)

Unified ad mediation SDK supporting 10 ad networks via CocoaPods or Swift Package Manager.

---

## 1. Quick Start

### CocoaPods

Add to your `Podfile`:

```ruby
pod 'MSPCore', '~> 2.7.1'

# Add the adapters you need
pod 'MSPGoogleAdapter'       # Google AdMob / Ad Manager
pod 'MSPFacebookAdapter'     # Meta Audience Network
pod 'MSPPrebidAdapter'       # Prebid Server
pod 'NovaAdapter'            # Nova custom ads
pod 'AmazonAdapter'          # Amazon Publisher Services
pod 'UnityAdapter'           # Unity LevelPlay
pod 'InmobiAdapter'          # InMobi
pod 'MintegralAdapter'       # Mintegral
pod 'MobilefuseAdapter'      # MobileFuse
pod 'PubmaticAdapter'        # PubMatic OpenWrap
```

Then install:

```bash
pod install
```

### Swift Package Manager

**Via Xcode UI:**
1. `File` → `Add Package Dependencies...`
2. Enter: `https://github.com/ParticleMedia/msp-ios-sdk-public.git`
3. Select the products you need

**Via Package.swift:**

```swift
dependencies: [
    .package(url: "https://github.com/ParticleMedia/msp-ios-sdk-public.git", from: "2.7.1")
]
```

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "MSPAds", package: "msp-ios-sdk"),           // Core bundle
        .product(name: "MSPGoogleAdapter", package: "msp-ios-sdk"), // Google
        .product(name: "MSPFacebookAdapter", package: "msp-ios-sdk"), // Meta
        // Add other adapters as needed
    ]
)
```

---

## 2. Modules Overview

### Core Modules

| Module | Description |
|--------|-------------|
| `MSPAds` | All-in-one bundle (recommended for most apps) |
| `MSPCore` | Core mediation engine |
| `MSPSharedLibraries` | Shared utilities |
| `MSPiOSCore` | iOS platform layer |

### Ad Network Adapters

| Adapter | Ad Network |
|---------|------------|
| `MSPGoogleAdapter` | Google AdMob / Ad Manager |
| `MSPFacebookAdapter` | Meta Audience Network |
| `MSPPrebidAdapter` | Prebid Server |
| `NovaAdapter` | Nova custom ads |
| `AmazonAdapter` | Amazon Publisher Services |
| `UnityAdapter` | Unity LevelPlay (IronSource) |
| `InmobiAdapter` | InMobi |
| `MintegralAdapter` | Mintegral |
| `MobilefuseAdapter` | MobileFuse |
| `PubmaticAdapter` | PubMatic OpenWrap |

### Internal Modules

| Module | Purpose |
|--------|---------|
| `NovaCore` | Nova ad rendering engine |
| `MSPOMSDK` | Open Measurement SDK |

---

## 3. Repository Overview

```
msp-ios-sdk/
│
├── Sources/
│   ├── Core/                 # Core module source code
│   ├── Adapters/             # 10 ad network adapters
│   └── Common/               # Shared utilities & wrappers
│
├── Build/XCFrameworks/       # Pre-built core binaries
│
├── ThirdParty/               # Third-party SDK frameworks
│
├── Examples/MSPDemoApp/      # Demo application
│
├── Scripts/
│   ├── spm-sync/             # SPM synchronization tools
│   ├── target-switching/     # Pods ↔ SPM switching
│   └── ci/                   # CI validation scripts
│
├── Docs/                     # Technical documentation
│
├── Package.swift             # SPM manifest
├── Podfile                   # CocoaPods dependencies
└── *.podspec                 # Pod specifications (16)
```

---

## 4. Architecture Overview

The SDK maintains version consistency between CocoaPods and SPM through a unified sync pipeline:

```
    ┌──────────────────────────────────────────────────────┐
    │                      Podfile                         │
    │           (Single source of truth for versions)      │
    └──────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
    ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
    │   Pods/     │   │ ThirdParty/ │   │  Package.   │
    │ (CocoaPods) │──▶│ (extracted) │──▶│   swift     │
    └─────────────┘   └─────────────┘   └─────────────┘
              │                                   │
              ▼                                   ▼
    ┌─────────────────────┐         ┌─────────────────────┐
    │    CocoaPods Mode   │         │      SPM Mode       │
    │  (msp-ios-sdk.xc-   │         │  (MSPDemoApp.xc-    │
    │      workspace)     │         │       project)      │
    └─────────────────────┘         └─────────────────────┘
```

---

## 5. Troubleshooting

### Common Errors

**`error: no such module 'XXX'` (SPM mode)**
```bash
./Scripts/spm-sync/spm_sync_all.sh
```

**`binary target does not contain a binary artifact`**
```bash
./Scripts/target-switching/switch-target.sh spm
# Auto-syncs missing XCFrameworks
```

**Version mismatch between Pods and SPM**
```bash
# Check versions
grep SwiftProtobuf Podfile.lock
# Update Package.swift to match, then:
./Scripts/spm-sync/spm_sync_all.sh
```

**Build fails after SDK version upgrade**
```bash
pod install
./Scripts/spm-sync/spm_sync_all.sh
./Scripts/target-switching/round-trip-test.sh
```

**Xcode cannot resolve SPM packages**
```bash
# Clean SPM cache
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf .swiftpm .build
# Re-open project
```

---

## 6. SDK Internal Development Guide

> **For SDK maintainers only.** App developers can skip this section.

### Setup Development Environment

```bash
git clone <repo>
cd msp-ios-sdk
pod install
open msp-ios-sdk.xcworkspace
```

### Switch Between Pods & SPM

```bash
# Work in CocoaPods mode
./Scripts/target-switching/switch-target.sh pods

# Work in SPM mode  
./Scripts/target-switching/switch-target.sh spm
```

### Sync Dependencies After Changes

When you modify `Podfile` or upgrade any SDK:

```bash
./Scripts/spm-sync/spm_sync_all.sh
```

This runs:
1. `pod install` — Update CocoaPods
2. `extract_from_pods.sh` — Extract XCFrameworks to `ThirdParty/`
3. `generate_package_swift.sh` — Update `Package.swift`

### Validate Changes

```bash
# Quick validation: single round-trip
./Scripts/target-switching/round-trip-test.sh

# Full validation: 3 cycles
./Scripts/target-switching/round-trip-test.sh --stress=3

# CI pipeline
./Scripts/ci/ci_validate.sh
```

### Upgrade Third-Party SDK

1. Update version in `Podfile`
2. Run `pod install`
3. Run `./Scripts/spm-sync/spm_sync_all.sh`
4. Run `./Scripts/target-switching/round-trip-test.sh`
5. Commit all changes

---

## 7. Developer Documentation

- **[Dependency Migration Guide (中文)](Docs/DEPENDENCY_MIGRATION_GUIDE_ZH.md)**  
  Complete technical documentation covering architecture design, script internals, and migration workflows.

---

## 8. Requirements

| Requirement | Version |
|-------------|---------|
| iOS | 15.0+ |
| Swift | 5.9+ |
| Xcode | 15.0+ |
| CocoaPods | 1.14.0+ |

---

## 9. License & Support

Copyright © 2024 NewsBreak. All rights reserved.

**Contact:** huanzhi.zhang@newsbreak.com  
**Issues:** [GitHub Issues](https://github.com/ParticleMedia/msp-ios-sdk-public/issues)
