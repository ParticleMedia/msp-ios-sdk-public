# Architecture

## Module Structure

### Core Modules

Core modules are distributed as binary XCFrameworks in release mode.

| Module | Responsibility | Dependencies |
|--------|---------------|--------------|
| `MSPSharedLibraries` | Foundation utilities, common types | None |
| `MSPOMSDK` | Open Measurement SDK integration | MSPSharedLibraries |
| `MSPCore` | Core SDK logic, ad request handling | MSPSharedLibraries, SwiftProtobuf |
| `MSPiOSCore` | iOS-specific implementations | MSPCore, MSPSharedLibraries |
| `NovaCore` | Nova ad format rendering | MSPiOSCore, MSPOMSDK, MSPKingfisher, lottie-ios, SnapKit, Shimmer |

### Adapter Modules

Adapters are always distributed as source code.

| Adapter | Ad Network |
|---------|------------|
| `NovaAdapter` | Nova native ads |
| `MSPGoogleAdapter` | Google Mobile Ads |
| `MSPFacebookAdapter` | Meta Audience Network |
| `MSPPrebidAdapter` | Prebid header bidding |
| `MSPAmazonAdapter` | Amazon Publisher Services |
| `MSPMolocoAdapter` | Moloco |
| `MSPLiftoffAdapter` | Liftoff/Vungle |
| `UnityAdapter` | Unity Ads |
| `InmobiAdapter` | InMobi |
| `MobilefuseAdapter` | MobileFuse |
| `MintegralAdapter` | Mintegral |
| `PubmaticAdapter` | PubMatic OpenWrap |

### Common Modules

| Module | Purpose |
|--------|---------|
| `MSPGoogleAdsTypes` | Google Mobile Ads SDK type abstractions |

## Distribution Model

### CocoaPods (Dual-Mode)

Podspecs support two modes controlled by `MSP_RELEASE` environment variable:

- `MSP_RELEASE=0` (pods-dev): Source files via `source_files`
- `MSP_RELEASE=1` (pods-release): Binary XCFrameworks via `vendored_frameworks`

### Swift Package Manager

Package.swift is generated from `Package.swift.template`:

- Core modules: `binaryTarget` with remote URLs and checksums
- Adapters: `target` with source files
- Third-party: `binaryTarget` from ThirdParty/ or remote URLs

## Directory Responsibilities

| Directory | Purpose |
|-----------|---------|
| `Sources/Core/` | Core module source code |
| `Sources/Adapters/` | Adapter module source code |
| `Sources/Common/` | Shared code (MSPGoogleAdsTypes) |
| `ThirdParty/` | Pre-built third-party XCFrameworks |
| `Binary/` | Built XCFrameworks for distribution |
| `Build/XCFrameworks/` | XCFramework build output |
| `Examples/` | MSPDemoApp |
| `Pods/` | CocoaPods dependencies (generated) |

## Build Outputs

### XCFramework Build

Core modules are built to `Build/XCFrameworks/`:

```
Build/XCFrameworks/
├── MSPSharedLibraries.xcframework
├── MSPOMSDK.xcframework
├── MSPCore.xcframework
├── MSPiOSCore.xcframework
└── NovaCore.xcframework
```

### Binary Distribution

For release, XCFrameworks are copied to `Binary/`:

```
Binary/
├── MSPCore.xcframework
├── MSPiOSCore.xcframework
├── MSPSharedLibraries.xcframework
├── MSPOMSDK.xcframework
├── NovaCore.xcframework
├── MSPAmazonAdapter.xcframework
├── MSPMolocoAdapter.xcframework
└── MSPLiftoffAdapter.xcframework
```

## Naming Conventions

### Pod Names

- Core modules: `MSPCore`, `MSPiOSCore`, `MSPSharedLibraries`, `NovaCore`
- Adapters with collision risk: `MSPAmazonAdapter`, `MSPMolocoAdapter`, `MSPLiftoffAdapter`
- Other adapters: `NovaAdapter`, `InmobiAdapter`, etc.

### XCFramework Names

XCFramework names match pod names:
- `MSPCore.xcframework`
- `MSPAmazonAdapter.xcframework`

### Module/Class Names

To avoid Swift module/class name collisions, adapters with MSP prefix use:
- Pod name: `MSPAmazonAdapter`
- Module name: `MSPAmazonAdapter`
- Class name: `AmazonAdapter` (no prefix)
