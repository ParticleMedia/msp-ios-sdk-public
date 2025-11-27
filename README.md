# MSP iOS SDK

[![CocoaPods](https://img.shields.io/cocoapods/v/MSPCore.svg)](https://cocoapods.org/pods/MSPCore)
[![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![iOS 15.0+](https://img.shields.io/badge/iOS-15.0+-blue.svg)](https://developer.apple.com/ios/)

Unified ad mediation SDK supporting 10 ad networks via CocoaPods or Swift Package Manager.

---

## 1. Quick Start

### 1.1 App Integration (CocoaPods)

```ruby
# Podfile
pod 'MSPCore', '~> 2.7.1'

# Add adapters you need
pod 'MSPGoogleAdapter'
pod 'MSPFacebookAdapter'
pod 'MSPPrebidAdapter'
pod 'NovaAdapter'
```

```bash
pod install
```

### 1.2 App Integration (SPM)

Add to your project via Xcode: `File → Add Package Dependencies...`

```
https://github.com/ParticleMedia/msp-ios-sdk-public.git
```

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ParticleMedia/msp-ios-sdk-public.git", from: "2.7.1")
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "MSPAds", package: "msp-ios-sdk"),
        .product(name: "MSPGoogleAdapter", package: "msp-ios-sdk"),
    ])
]
```

### 1.3 SDK Developer Workflow

```bash
# Clone and setup
git clone <repo>
cd msp-ios-sdk

# Option A: Work in Pods mode (default)
pod install
open msp-ios-sdk.xcworkspace

# Option B: Work in SPM mode
./Scripts/target-switching/switch-target.sh spm
# Xcode opens automatically
```

### 1.4 Switching Between Pods & SPM

```bash
# Switch to CocoaPods
./Scripts/target-switching/switch-target.sh pods

# Switch to SPM
./Scripts/target-switching/switch-target.sh spm
```

### 1.5 Sync Dependencies

After updating any SDK version in `Podfile`:

```bash
./Scripts/spm-sync/spm_sync_all.sh
```

### 1.6 Round-Trip Testing

```bash
# Single cycle: Pods → SPM → Pods
./Scripts/target-switching/round-trip-test.sh

# Stress test: 3 cycles
./Scripts/target-switching/round-trip-test.sh --stress=3
```

### 1.7 Troubleshooting

| Issue | Solution |
|-------|----------|
| `no such module` in SPM | Run `./Scripts/spm-sync/spm_sync_all.sh` |
| `binary target not found` | Run `./Scripts/target-switching/switch-target.sh spm` (auto-syncs) |
| Version mismatch error | Update `Package.swift` to match `Podfile.lock` versions |
| Build fails after SDK upgrade | Run full sync: `pod install && ./Scripts/spm-sync/spm_sync_all.sh` |

---

## 2. Modules

| Module | Description |
|--------|-------------|
| `MSPAds` | All-in-one bundle (Core + SharedLibraries + iOSCore) |
| `MSPCore` | Core mediation engine |
| `MSPSharedLibraries` | Shared utilities |
| `MSPiOSCore` | iOS platform layer |
| `NovaCore` | Nova ad rendering |
| `MSPOMSDK` | Open Measurement |
| `MSPGoogleAdapter` | Google AdMob / Ad Manager |
| `MSPFacebookAdapter` | Meta Audience Network |
| `MSPPrebidAdapter` | Prebid Server |
| `NovaAdapter` | Nova custom ads |
| `AmazonAdapter` | Amazon Publisher Services |
| `UnityAdapter` | Unity LevelPlay |
| `InmobiAdapter` | InMobi |
| `MintegralAdapter` | Mintegral |
| `MobilefuseAdapter` | MobileFuse |
| `PubmaticAdapter` | PubMatic OpenWrap |

---

## 3. Repository Overview

```
msp-ios-sdk/
├── Build/XCFrameworks/      # Core module binaries (5)
├── ThirdParty/              # Third-party SDK XCFrameworks (8+)
├── Sources/
│   ├── Core/                # Core module sources
│   ├── Adapters/            # Ad network adapters (10)
│   └── Common/              # Shared modules (Wrappers, Types)
├── Scripts/
│   ├── spm-sync/            # Pods → SPM sync scripts
│   ├── target-switching/    # Mode switching scripts
│   └── ci/                  # CI validation
├── Examples/MSPDemoApp/     # Demo application
└── Docs/                    # Developer documentation
```

---

## 4. Architecture Overview

```
Podfile (single source of truth)
    │
    ▼ pod install
Pods/ ──────────────────────────────┐
    │                               │
    ▼ extract_from_pods.sh          │
ThirdParty/*.xcframework            │
    │                               │
    ▼                               ▼
Package.swift ◄──────────── CocoaPods Mode
    │
    ▼
SPM Mode
```

Both modes use identical SDK versions. Podfile controls all dependency versions.

---

## 5. Developer Documentation

For detailed technical documentation:

- **[Migration Guide (中文)](Docs/DEPENDENCY_MIGRATION_GUIDE_ZH.md)** — Complete architecture explanation, script details, upgrade workflows

---

## 6. Requirements

- iOS 15.0+
- Swift 5.9+
- Xcode 15.0+

---

## 7. License & Support

Copyright © 2024 NewsBreak. All rights reserved.

**Contact**: huanzhi.zhang@newsbreak.com
