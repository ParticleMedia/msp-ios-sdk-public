# Third-Party Dependency Management

## Source of Truth

**Podfile is the single source of truth for all third-party SDK versions.**

Do not manually edit:
- `ThirdParty/` XCFrameworks
- `Package.swift` dependency versions

## Upgrade Workflow

### Step 1: Update Podfile

Edit `Podfile` with new version:

```ruby
pod 'FBAudienceNetwork', '~> 6.15.0'
```

### Step 2: Install Pods

```bash
pod install
```

### Step 3: Sync to SPM

```bash
./Scripts/spm-sync/spm_sync_all.sh
```

### Step 4: Validate

```bash
./Scripts/target-switching/round-trip-test.sh
```

## Required XCFrameworks

### Core XCFrameworks (Build Required)

Built from source via `build-core.sh`:

- MSPSharedLibraries.xcframework
- MSPOMSDK.xcframework
- MSPCore.xcframework
- MSPiOSCore.xcframework
- NovaCore.xcframework

### ThirdParty XCFrameworks (Pre-built)

Always present in `ThirdParty/`:

- PrebidMobile.xcframework
- Shimmer.xcframework
- Lottie.xcframework
- SnapKit.xcframework
- SwiftProtobuf.xcframework
- Kingfisher.xcframework

### ThirdParty XCFrameworks (From Pods)

Extracted from Pods directory by `sync_thirdparty_pods.sh`:

- AmazonPublisherServicesSDK.xcframework
- FBAudienceNetwork.xcframework
- InMobiSDK.xcframework
- IronSourceSDK.xcframework
- MTGSDK.xcframework (Mintegral)
- MobileFuseSDK.xcframework
- MolocoSDK.xcframework
- OpenWrapSDK.xcframework
- VungleAdsSDK.xcframework

## Special Cases

### MSPKingfisher

Uses a local wrapper pod (`ThirdParty/MSPKingfisher/`) instead of official Kingfisher to avoid SwiftVerifyEmittedModuleInterface errors.

### Prebid

PrebidMobile is included as a pre-built XCFramework in `ThirdParty/PrebidMobile/` and referenced via `vendored_frameworks` in MSPSharedLibraries.podspec.

### Google Mobile Ads

Google-specific types are abstracted in MSPGoogleAdsTypes to avoid direct SDK dependency in core modules.

## Sync Scripts

### spm_sync_all.sh

Syncs all third-party dependencies from Pods to SPM-compatible format:

```bash
./Scripts/spm-sync/spm_sync_all.sh
```

### sync_thirdparty_pods.sh

Extracts third-party XCFrameworks from Pods directory to ThirdParty/:

```bash
./Scripts/spm/sync_thirdparty_pods.sh
./Scripts/spm/sync_thirdparty_pods.sh --force  # Overwrite existing
```

## Verification

After upgrading dependencies:

1. Build DemoApp in pods-dev mode
2. Run round-trip test
3. Verify all adapters compile
4. Test integration with ad networks
