# MSP iOS SDK

[![CocoaPods](https://img.shields.io/cocoapods/v/MSPCore.svg)](https://cocoapods.org/pods/MSPCore)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![Platform](https://img.shields.io/cocoapods/p/MSPCore.svg)](https://github.com/ParticleMedia/msp-ios-sdk-public)
[![iOS 15.0+](https://img.shields.io/badge/iOS-15.0+-blue.svg)](https://developer.apple.com/ios/)

MSP (Mediation Service Platform) iOS SDK provides a unified ad mediation solution supporting multiple ad networks through a single integration.

---

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
  - [CocoaPods](#cocoapods)
  - [Swift Package Manager](#swift-package-manager)
- [Repository Structure](#repository-structure)
- [Dependency Sync Pipeline](#dependency-sync-pipeline)
- [Switching Between Pods & SPM](#switching-between-pods--spm)
- [Round-Trip Testing](#round-trip-testing)
- [CI Integration](#ci-integration)
- [Upgrading Third-Party SDKs](#upgrading-third-party-sdks)
- [Known Limitations](#known-limitations)
- [Documentation](#documentation)

---

## Overview

MSP iOS SDK supports **dual integration** via both CocoaPods and Swift Package Manager (SPM).

### Unified Dependency System

The SDK uses a **Pods → XCFramework → SPM** pipeline to ensure consistency:

```
┌─────────────────────────────────────────────────────────────┐
│  Podfile (Single Source of Truth for all SDK versions)     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ pod install
┌─────────────────────────────────────────────────────────────┐
│  Pods/ (Downloaded frameworks and sources)                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ extract_from_pods.sh
┌─────────────────────────────────────────────────────────────┐
│  ThirdParty/*.xcframework (Normalized for SPM)             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ Package.swift references
┌─────────────────────────────────────────────────────────────┐
│  SPM Mode (Ready to build with Xcode)                      │
└─────────────────────────────────────────────────────────────┘
```

### Supported Ad Networks

| Network | Adapter Module | SDK |
|---------|---------------|-----|
| Google AdMob/Ad Manager | `MSPGoogleAdapter` | Google-Mobile-Ads-SDK |
| Meta Audience Network | `MSPFacebookAdapter` | FBAudienceNetwork |
| Prebid Mobile | `MSPPrebidAdapter` | PrebidMobile |
| Amazon Publisher Services | `AmazonAdapter` | AmazonPublisherServicesSDK |
| Unity LevelPlay | `UnityAdapter` | IronSourceSDK |
| InMobi | `InmobiAdapter` | InMobiSDK |
| Mintegral | `MintegralAdapter` | MintegralAdSDK |
| MobileFuse | `MobilefuseAdapter` | MobileFuseSDK |
| PubMatic OpenWrap | `PubmaticAdapter` | OpenWrapSDK |
| Nova (Custom) | `NovaAdapter` | NovaCore |

---

## Installation

### CocoaPods

Add the following to your `Podfile`:

```ruby
# Core SDK (required)
pod 'MSPCore', '~> 2.7.1'

# Choose the adapters you need
pod 'MSPGoogleAdapter'       # Google AdMob/Ad Manager
pod 'MSPFacebookAdapter'     # Meta Audience Network
pod 'MSPPrebidAdapter'       # Prebid Server
pod 'AmazonAdapter'          # Amazon Publisher Services
pod 'UnityAdapter'           # Unity LevelPlay (IronSource)
pod 'InmobiAdapter'          # InMobi
pod 'MintegralAdapter'       # Mintegral
pod 'MobilefuseAdapter'      # MobileFuse
pod 'PubmaticAdapter'        # PubMatic OpenWrap
pod 'NovaAdapter'            # Nova custom ads
```

Then run:

```bash
pod install
```

### Swift Package Manager

Add the package to your `Package.swift` or via Xcode:

```swift
dependencies: [
    .package(
        url: "https://github.com/ParticleMedia/msp-ios-sdk-public.git",
        from: "2.7.1"
    )
]
```

Then add the products you need:

```swift
.target(
    name: "YourApp",
    dependencies: [
        // Core SDK
        .product(name: "MSPAds", package: "msp-ios-sdk"),
        
        // Or individual adapters
        .product(name: "MSPGoogleAdapter", package: "msp-ios-sdk"),
        .product(name: "MSPFacebookAdapter", package: "msp-ios-sdk"),
        .product(name: "MSPPrebidAdapter", package: "msp-ios-sdk"),
        .product(name: "AmazonAdapter", package: "msp-ios-sdk"),
        .product(name: "UnityAdapter", package: "msp-ios-sdk"),
        .product(name: "InmobiAdapter", package: "msp-ios-sdk"),
        .product(name: "MintegralAdapter", package: "msp-ios-sdk"),
        .product(name: "MobilefuseAdapter", package: "msp-ios-sdk"),
        .product(name: "PubmaticAdapter", package: "msp-ios-sdk"),
        .product(name: "NovaAdapter", package: "msp-ios-sdk"),
    ]
)
```

**Available Products (16):**

| Product | Description |
|---------|-------------|
| `MSPAds` | All-in-one SDK bundle (MSPCore + MSPSharedLibraries + MSPiOSCore) |
| `MSPCore` | Core mediation logic |
| `MSPSharedLibraries` | Shared utilities |
| `MSPiOSCore` | iOS-specific core |
| `NovaCore` | Nova ad rendering engine |
| `MSPOMSDK` | Open Measurement SDK |
| `MSPGoogleAdapter` | Google AdMob/Ad Manager |
| `MSPFacebookAdapter` | Meta Audience Network |
| `MSPPrebidAdapter` | Prebid Server |
| `NovaAdapter` | Nova custom ads |
| `AmazonAdapter` | Amazon Publisher Services |
| `UnityAdapter` | Unity LevelPlay |
| `InmobiAdapter` | InMobi |
| `MobilefuseAdapter` | MobileFuse |
| `MintegralAdapter` | Mintegral |
| `PubmaticAdapter` | PubMatic OpenWrap |

---

## Repository Structure

```
msp-ios-sdk/
│
├── Build/
│   └── XCFrameworks/                    # Core module XCFrameworks
│       ├── MSPSharedLibraries.xcframework/
│       ├── MSPiOSCore.xcframework/
│       ├── NovaCore.xcframework/
│       ├── MSPCore.xcframework/
│       └── MSPOMSDK.xcframework/
│
├── ThirdParty/                          # Third-party SDK XCFrameworks
│   ├── PrebidMobile/
│   │   └── PrebidMobile.xcframework/
│   ├── FBAudienceNetwork/
│   │   └── FBAudienceNetwork.xcframework/
│   ├── IronSourceSDK/
│   │   └── IronSourceSDK.xcframework/
│   ├── InMobiSDK/
│   │   └── InMobiSDK.xcframework/
│   ├── MobileFuseSDK/
│   │   └── MobileFuseSDK.xcframework/
│   ├── MintegralAdSDK/                  # Multi-module SDK
│   │   ├── MTGSDK.xcframework/
│   │   ├── MTGSDKBidding.xcframework/
│   │   ├── MTGSDKBanner.xcframework/
│   │   ├── MTGSDKNewInterstitial.xcframework/
│   │   └── MTGSDKInterstitialVideo.xcframework/
│   ├── OpenWrapSDK/
│   │   └── OpenWrapSDK.xcframework/
│   ├── AmazonPublisherServicesSDK/
│   │   └── AmazonPublisherServicesSDK.xcframework/
│   └── Shimmer/                         # Objective-C source (not XCFramework)
│       └── Shimmer/
│           ├── include/
│           └── *.m
│
├── Scripts/
│   ├── spm-sync/                        # SPM synchronization scripts
│   │   ├── spm_sync_all.sh              # One-command sync
│   │   ├── extract_from_pods.sh         # Extract XCFrameworks from Pods
│   │   └── generate_package_swift.sh    # Generate Package.swift
│   ├── target-switching/                # Mode switching scripts
│   │   ├── switch-target.sh             # Main switching script
│   │   ├── round-trip-test.sh           # Round-trip validation
│   │   ├── validate_xcframeworks.sh     # XCFramework validation
│   │   ├── cleanup_pods.sh              # Clean Pods environment
│   │   └── cleanup_spm.sh               # Clean SPM environment
│   ├── ci/                              # CI scripts
│   │   └── ci_validate.sh               # Full CI validation
│   └── xcframeworks/                    # XCFramework build scripts
│       └── build-core.sh                # Build core modules
│
├── Sources/
│   ├── Core/                            # Core module sources
│   │   ├── MSPSharedLibraries/
│   │   ├── MSPiOSCore/
│   │   ├── NovaCore/
│   │   ├── MSPCore/
│   │   └── MSPOMSDK/
│   ├── Adapters/                        # Adapter sources (10)
│   │   ├── MSPPrebidAdapter/
│   │   ├── MSPGoogleAdapter/
│   │   ├── MSPFacebookAdapter/
│   │   ├── NovaAdapter/
│   │   ├── AmazonAdapter/
│   │   ├── UnityAdapter/
│   │   ├── InmobiAdapter/
│   │   ├── MobilefuseAdapter/
│   │   ├── MintegralAdapter/
│   │   └── PubmaticAdapter/
│   └── Common/                          # Shared modules
│       ├── MSPCoreWrapper/              # SwiftProtobuf linker wrapper
│       ├── NovaCoreWrapper/             # Lottie/Shimmer linker wrapper
│       └── MSPGoogleAdsTypes/           # Google Ads type abstraction
│
├── Examples/
│   └── MSPDemoApp/                      # Demo application
│
├── Docs/
│   └── DEPENDENCY_MIGRATION_GUIDE_ZH.md # Chinese migration guide
│
├── Package.swift                        # SPM manifest
├── Podfile                              # CocoaPods dependencies
└── *.podspec                            # 16 podspec files
```

---

## Dependency Sync Pipeline

The SDK maintains a **single source of truth** (Podfile) for all dependency versions.

### Automatic Sync

Run the all-in-one sync command:

```bash
./Scripts/spm-sync/spm_sync_all.sh
```

This executes:

1. **`pod install`** - Download/update all CocoaPods dependencies
2. **`extract_from_pods.sh`** - Extract XCFrameworks from `Pods/` to `ThirdParty/`
3. **`generate_package_swift.sh`** - Update `Package.swift` with correct paths

### Manual Steps (if needed)

```bash
# Step 1: Install pods
pod install

# Step 2: Extract third-party XCFrameworks
./Scripts/spm-sync/extract_from_pods.sh

# Step 3: Generate Package.swift (optional - for local development)
./Scripts/spm-sync/generate_package_swift.sh
```

### Extracted SDKs

The following SDKs are extracted from CocoaPods:

| SDK | Source Pod | Target Directory |
|-----|-----------|------------------|
| FBAudienceNetwork | `FBAudienceNetwork` | `ThirdParty/FBAudienceNetwork/` |
| IronSourceSDK | `IronSourceSDK` | `ThirdParty/IronSourceSDK/` |
| InMobiSDK | `InMobiSDK` | `ThirdParty/InMobiSDK/` |
| MobileFuseSDK | `MobileFuseSDK` | `ThirdParty/MobileFuseSDK/` |
| MintegralAdSDK | `MintegralAdSDK` | `ThirdParty/MintegralAdSDK/` |
| OpenWrapSDK | `OpenWrapSDK` | `ThirdParty/OpenWrapSDK/` |
| AmazonPublisherServicesSDK | `AmazonPublisherServicesSDK` | `ThirdParty/AmazonPublisherServicesSDK/` |

**Not extracted:**
- `PrebidMobile` - Uses canonical path in `ThirdParty/PrebidMobile/`
- `GoogleMobileAds` - Uses official SPM package directly

---

## Switching Between Pods & SPM

### Switch to CocoaPods Mode

```bash
./Scripts/target-switching/switch-target.sh pods
```

This will:
1. Clean SPM artifacts
2. Run `pod install`
3. Generate Xcode workspace with Pods
4. Open Xcode

### Switch to SPM Mode

```bash
./Scripts/target-switching/switch-target.sh spm
```

This will:
1. Clean Pods artifacts
2. Validate XCFrameworks (auto-runs `spm_sync_all.sh` if missing)
3. Generate Xcode project for SPM
4. Open Xcode

### Automatic XCFramework Sync

When switching to SPM mode, the script automatically checks for required XCFrameworks:

```
[switch-target] Running XCFramework validation
⚠ XCFramework validation failed - some required XCFrameworks are missing
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Auto-syncing XCFrameworks from CocoaPods...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[spm_sync_all] Step 1/3: Running pod install...
[spm_sync_all] Step 2/3: Extracting third-party SDK xcframeworks...
[spm_sync_all] Step 3/3: Generating local-development Package.swift...
✓ XCFramework sync completed
```

---

## Round-Trip Testing

Validate that switching between Pods and SPM works correctly.

### Basic Test

```bash
./Scripts/target-switching/round-trip-test.sh
```

Executes: `Pods → SPM → Pods`

### Stress Test

```bash
./Scripts/target-switching/round-trip-test.sh --stress=3
```

Executes: `Pods → SPM → Pods → SPM → Pods → SPM` (3 full cycles)

### Test Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Round-Trip Test: Pods → SPM → Pods (Stress Test: 3 cycles)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Cycle 1.1 Switch to Pods: PASS (12s)
✓ Cycle 1.2 Validate Pods Mode: PASS (1s)
✓ Cycle 1.3 Build Pods App: PASS (45s)
✓ Cycle 1.4 Switch to SPM: PASS (8s)
✓ Cycle 1.5 Validate SPM Mode: PASS (1s)
✓ Cycle 1.6 Build SPM App: PASS (38s)
...

✓ Round-trip test PASSED! (3 cycle(s))
```

---

## CI Integration

### Full CI Validation

```bash
./Scripts/ci/ci_validate.sh
```

This runs the complete validation pipeline:

```bash
# Step 1: Clean environment
./Scripts/target-switching/cleanup_pods.sh --force
./Scripts/target-switching/cleanup_spm.sh --force

# Step 2: Sync from Pods
pod install
./Scripts/spm-sync/spm_sync_all.sh

# Step 3: Validate XCFrameworks and versions
./Scripts/target-switching/validate_xcframeworks.sh

# Step 4: Build Pods mode
./Scripts/target-switching/switch-target.sh pods
xcodebuild -workspace msp-ios-sdk.xcworkspace -scheme MSPDemoApp build

# Step 5: Build SPM mode
./Scripts/target-switching/switch-target.sh spm
xcodebuild -project Examples/MSPDemoApp/MSPDemoApp.xcodeproj -scheme MSPDemoApp-SPM build

# Step 6: Round-trip stress test
./Scripts/target-switching/round-trip-test.sh --stress=2
```

### Custom Stress Level

```bash
./Scripts/ci/ci_validate.sh --stress=3
```

### Version Validation

The CI checks that Pods and SPM use identical versions:

```
━━━ Dependency Version Verification ━━━
✓ SwiftProtobuf: Pods=1.28.2, SPM=1.28.2 (match)
✓ Lottie: Pods=4.5.2, SPM=4.5.2 (match)
```

---

## Upgrading Third-Party SDKs

### Correct Workflow

> ⚠️ **Important**: Only upgrade SDKs via Podfile. Never modify `ThirdParty/` directly.

```bash
# 1. Update version in Podfile
vim Podfile
# Change: pod 'IronSourceSDK', '~> 8.6.0'
# To:     pod 'IronSourceSDK', '~> 8.7.0'

# 2. Run pod install
pod install

# 3. Sync to SPM
./Scripts/spm-sync/spm_sync_all.sh

# 4. Validate Pods mode
./Scripts/target-switching/switch-target.sh pods
xcodebuild -scheme MSPDemoApp build

# 5. Validate SPM mode
./Scripts/target-switching/switch-target.sh spm
xcodebuild -scheme MSPDemoApp-SPM build

# 6. Run round-trip test
./Scripts/target-switching/round-trip-test.sh --stress=2

# 7. Run CI validation
./Scripts/ci/ci_validate.sh

# 8. Commit changes
git add Podfile Podfile.lock ThirdParty/ Package.swift
git commit -m "chore: Upgrade IronSourceSDK to 8.7.0"
```

### Special Cases

#### Upgrading SwiftProtobuf or Lottie

These libraries are used in both Pods and SPM and must be updated in **both places**:

```ruby
# Podfile
pod 'SwiftProtobuf', '~> 1.29.0'
pod 'lottie-ios', '4.6.0'
```

```swift
// Package.swift
.package(url: "https://github.com/apple/swift-protobuf.git", exact: "1.29.0"),
.package(url: "https://github.com/airbnb/lottie-ios.git", exact: "4.6.0"),
```

---

## Known Limitations

### 1. Shimmer Uses Source Code

Facebook Shimmer is included as Objective-C source files (not XCFramework) because:
- The official repo is archived with no SPM support
- It's only 4 files, making source inclusion simpler
- Easier to debug and maintain

Location: `ThirdParty/Shimmer/Shimmer/`

### 2. GoogleMobileAds Uses Official SPM

Google Mobile Ads SDK is **not extracted** from Pods because:
- Google provides official SPM support
- The XCFramework structure from Pods is non-standard
- Version updates are frequent

SPM dependency:
```swift
.package(
    url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
    from: "11.0.0"
)
```

### 3. Binary Targets Cannot Express Dependencies

SPM's `binaryTarget` doesn't support the `dependencies` parameter:

```swift
// ❌ Invalid - binaryTarget cannot have dependencies
.binaryTarget(
    name: "MSPCore",
    dependencies: ["SwiftProtobuf"],  // ERROR!
    path: "Build/XCFrameworks/MSPCore.xcframework"
)
```

**Solution**: Wrapper modules (`MSPCoreLinker`, `NovaCoreLinker`) force-link required dependencies.

### 4. SPM Requires ThirdParty/ to Exist

Before building with SPM, all XCFrameworks in `ThirdParty/` must exist:

```bash
# If you see "binary target does not contain a binary artifact":
./Scripts/spm-sync/spm_sync_all.sh
```

The `switch-target.sh spm` command handles this automatically.

### 5. Version Pinning Required

SwiftProtobuf and Lottie must use **exact** version constraints to match CocoaPods:

```swift
// ✅ Correct - exact version matching Pods
.package(url: "...", exact: "1.28.2")

// ❌ Wrong - allows version drift
.package(url: "...", from: "1.25.0")
```

---

## Documentation

- [Chinese Migration Guide](Docs/DEPENDENCY_MIGRATION_GUIDE_ZH.md) - 详细的中文迁移文档
- [Integration Guide](https://github.com/ParticleMedia/msp-ios-sdk-public/wiki) - Wiki documentation

---

## Requirements

- **iOS**: 15.0+
- **Swift**: 5.9+
- **Xcode**: 15.0+
- **CocoaPods**: 1.14.0+ (for Pods mode)

---

## License

Copyright © 2024 NewsBreak. All rights reserved.

---

## Support

For issues and feature requests, please contact:
- Email: huanzhi.zhang@newsbreak.com
- GitHub Issues: [msp-ios-sdk-public](https://github.com/ParticleMedia/msp-ios-sdk-public/issues)
