# Implementation Plan: Rewarded Ads

**Branch**: `001-rewarded-ads` | **Date**: 2026-03-11 | **Spec**: [spec.md](./spec.md)

## Summary

Add Rewarded as an independent first-class ad format to the MSP iOS SDK. The implementation spans five layers: (1) public API in `MSPiOSCore` (new `RewardedAd`, `Reward`, extended `AdFormat`/`AdRequest`/`AdListener`), (2) an internal lifecycle controller for idempotent reward/dismiss sequencing, (3) adapter bridges for Google AdMob and Facebook Audience Network (enabled in v1), (4) **all remaining adapters** (Liftoff, Moloco, Mintegral, MobileFuse, PubMatic, InMobi, Unity/LevelPlay) added on the MSP adapter path but rollout-gated, and (5) MSP full-screen (NovaCore) deferred to a later phase. The initial rollout gate lives on the client and only enables Google + Facebook; when server placement config is ready, the gate's data source can be swapped without changing adapter routing. Importantly, Google Mobile Ads SDK integration does not replace third-party network adapters: if a partner such as Moloco is served through Google mediation, that still requires Moloco's own SDK plus Google's mediation adapter, which is a separate integration path from this repository's standalone `MSPMolocoAdapter`. Amazon APS is deferred pending clearer iOS API evidence.

---

## Technical Context

**Language/Version**: Swift 5.0+
**Primary Dependencies**: MSPiOSCore, MSPCore, MSPGoogleAdapter (GADRewardedAd), MSPFacebookAdapter (FBRewardedVideoAd), LiftoffAdapter (VungleRewarded), MolocoAdapter (MolocoRewardedInterstitial), MintegralAdapter (MTGRewardAdManager), MobilefuseAdapter (MFRewardedAd), PubmaticAdapter (POBRewardedAd), InmobiAdapter (IMInterstitial), UnityAdapter (LPMRewardedAd)
**Storage**: N/A (in-memory `AdCache`, same as Interstitial)
**Testing**: Quick ~> 7.0 + Nimble ~> 13.0 (BDD style, per Article V)
**Target Platform**: iOS 15.0+
**Project Type**: iOS SDK / Framework library
**Performance Goals**: End-to-end load→show latency ≤ 120% of equivalent Interstitial (SC-005)
**Constraints**: No third-party SDK imports in Core modules (Article III.1); all project config via XcodeGen yml.template (Article I.2 / IV.6)
**Scale/Scope**: ~25 new files, ~15 modified files across 11 modules (Core + 9 adapters)

---

## Constitution Check

*GATE: Must pass before Phase 0. Re-checked after Phase 1.*

| Article | Requirement | Status | Notes |
|---------|-------------|--------|-------|
| I.2 | No direct `.xcodeproj` modification — use `*.yml.template` + XcodeGen | ✅ PASS | All new files must be registered in yml.template |
| I.4 | No manual workarounds for build/dependency issues | ✅ PASS | No workarounds planned |
| III.1 | No third-party SDK imports in Core modules | ✅ PASS | `RewardedAd`, `Reward`, `RewardedLifecycleController` in Core; adapter-specific logic stays in adapter modules |
| III.2 | Protocol-oriented design via `AdNetworkAdapter` | ✅ PASS | Rewarded routing stays inside existing `AdNetworkAdapter.loadAdCreative` branches |
| IV.1 | Value-types first — `struct` for data | ✅ PASS | `Reward` is a struct |
| IV.3 | No force-unwrap; DocC on all public APIs | ✅ PASS | Plan mandates DocC on `RewardedAd`, `Reward`, `onAdRewardReceived` |
| IV.4 | Use `Logger` API for all logging | ✅ PASS | `RewardedLifecycleController` uses `Logger` with category "Rewarded" |
| IV.6 | XcodeGen for all project config changes | ✅ PASS | Same as I.2 |
| V / 5.1 | TDD — Red-Green-Refactor; Quick/Nimble | ✅ PASS | Tests written before implementation per phase |
| 5.2 | Quick & Nimble for all new unit tests | ✅ PASS | Specified in testing strategy |

---

## Project Structure

### Documentation (this feature)
```text
specs/001-rewarded-ads/
├── plan.md              ← this file
├── research.md          ← Phase 0 output
├── data-model.md        ← Phase 1 output
├── quickstart.md        ← Phase 1 output
├── contracts/
│   └── public-api.md    ← Phase 1 output
└── tasks.md             ← Phase 2 output (/speckit.tasks)
```

### Source Code
```text
Sources/Core/MSPiOSCore/MSPiOSCore/
├── api/
│   ├── AdFormat.swift           [MODIFY] add .rewarded
│   ├── AdRequest.swift          [MODIFY] add reward: Reward?
│   ├── Reward.swift             [NEW]
│   ├── RewardedAd.swift         [NEW]
│   └── Delegates/
│       └── AdListener.swift     [MODIFY] add onAdRewardReceived + default impl

Sources/Core/MSPCore/MSPCore/
├── MSPAdLoader.swift             [MODIFY] route `.rewarded` through the existing auction/load path
└── RewardedLifecycleController.swift  [NEW] internal

Sources/Adapters/MSPGoogleAdapter/MSPGoogleAdapter/
├── GoogleAdapter.swift           [MODIFY] handle .rewarded in loadAdCreative
└── Rewarded/
    └── GoogleRewardedAd.swift    [NEW]

Sources/Adapters/MSPFacebookAdapter/MSPFacebookAdapter/
├── FacebookAdapter.swift         [MODIFY] handle .rewarded in loadAdCreative
└── Rewarded/
    └── FacebookRewardedAd.swift  [NEW]

Sources/Adapters/LiftoffAdapter/LiftoffAdapter/
├── LiftoffAdapter.swift         [MODIFY] add .rewarded branch
└── Rewarded/
    └── LiftoffRewardedAd.swift  [NEW]

Sources/Adapters/MolocoAdapter/MolocoAdapter/
├── MolocoAdapter.swift          [MODIFY] add .rewarded branch
└── Rewarded/
    └── MolocoRewardedAd.swift   [NEW]

Sources/Adapters/MintegralAdapter/MintegralAdapter/
├── MintegralAdapter.swift       [MODIFY] add .rewarded branch
└── Rewarded/
    └── MintegralRewardedAd.swift [NEW]

Sources/Adapters/MobilefuseAdapter/MobilefuseAdapter/
├── MobilefuseAdapter.swift      [MODIFY] add .rewarded branch
└── Rewarded/
    └── MobilefuseRewardedAd.swift [NEW]

Sources/Adapters/PubmaticAdapter/PubmaticAdapter/
├── PubmaticAdapter.swift        [MODIFY] add .rewarded branch
└── Rewarded/
    └── PubmaticRewardedAd.swift [NEW]

Sources/Adapters/InmobiAdapter/InmobiAdapter/
├── InmobiAdapter.swift          [MODIFY] add .rewarded branch
└── Rewarded/
    └── InmobiRewardedAd.swift   [NEW]

Sources/Adapters/UnityAdapter/UnityAdapter/
├── UnityAdapter.swift           [MODIFY] add .rewarded branch
└── Rewarded/
    └── UnityRewardedAd.swift    [NEW]

Sources/Adapters/AmazonAdapter/AmazonAdapter/
└── AmazonAdapter.swift          [MODIFY] keep explicit unsupported `.rewarded` branch (deferred)

Tests/
├── MSPiOSCoreTests/
│   ├── RewardedAdTests.swift     [NEW]
│   └── RewardTests.swift         [NEW]
├── MSPCoreTests/
│   └── RewardedLifecycleControllerTests.swift  [NEW]
├── AdapterTests/
│   ├── GoogleRewardedAdTests.swift      [NEW]
│   ├── FacebookRewardedAdTests.swift    [NEW]
│   ├── LiftoffRewardedAdTests.swift     [NEW]
│   ├── MolocoRewardedAdTests.swift      [NEW]
│   ├── MintegralRewardedAdTests.swift   [NEW]
│   ├── MobilefuseRewardedAdTests.swift  [NEW]
│   ├── PubmaticRewardedAdTests.swift    [NEW]
│   ├── InmobiRewardedAdTests.swift      [NEW]
│   └── UnityRewardedAdTests.swift       [NEW]
```

**Structure Decision**: Follows existing adapter pattern exactly. Each adapter module gets a `Rewarded/` subdirectory parallel to the existing `Interstitial/` and `Native/` directories.

---

## Phase 1: API & Core Modeling

**Goal**: Establish the complete public API and internal lifecycle infrastructure. After this phase, the SDK compiles with `.rewarded` format but no network can fill it yet.

### P1-001 — Add `AdFormat.rewarded`
- File: `Sources/Core/MSPiOSCore/MSPiOSCore/api/AdFormat.swift`
- Add `.rewarded` case to `AdFormat` enum
- **Exhaustiveness impact**: All `switch adFormat` or `switch bidderFormat` statements in adapter code will emit compiler warnings — intentional, forces each adapter to acknowledge the new case

### P1-002 — Create `Reward` struct
- File: `Sources/Core/MSPiOSCore/MSPiOSCore/api/Reward.swift` (new)
- `public struct Reward: Equatable, Codable, Sendable` with `type: String`, `amount: Int`
- Full DocC documentation

### P1-003 — Extend `AdRequest` with `reward: Reward?`
- File: `Sources/Core/MSPiOSCore/MSPiOSCore/api/AdRequest.swift`
- Add `public var reward: Reward?` — optional, nil by default
- DocC note: optional per spec, pending product confirmation

### P1-004 — Create `RewardedAd` open class
- File: `Sources/Core/MSPiOSCore/MSPiOSCore/api/RewardedAd.swift` (new)
- `open class RewardedAd: MSPAd`
- `public let reward: Reward`
- `open func show(rootViewController: UIViewController?)` — fatalError if not overridden
- `open func dismiss(animated: Bool)` — default no-op

### P1-005 — Add `onAdRewardReceived` to `AdListener`
- File: `Sources/Core/MSPiOSCore/MSPiOSCore/api/Delegates/AdListener.swift`
- Add `func onAdRewardReceived(ad: MSPAd)` to protocol
- Add default empty implementation via `public extension AdListener`
- DocC: note on timing guarantee and idempotency

### P1-006 — Create `RewardedLifecycleController` (internal)
- File: `Sources/Core/MSPCore/MSPCore/RewardedLifecycleController.swift` (new)
- `internal final class RewardedLifecycleController`
- State: `hasEarnedReward: Bool`, `hasDismissed: Bool`
- Methods: `markDisplayed()`, `markClicked()`, `markRewardEarned()`, `markDismissed()`
- Injected `AdListener` (weak ref), injected `MSPAd` (unowned) — no UIKit dependency
- `Logger` category: "Rewarded"

### P1-007 — Update `MSPAdLoader` for `.rewarded`
- File: `Sources/Core/MSPCore/MSPCore/MSPAdLoader.swift`
- Route `.rewarded` through the existing auction/load path without introducing a capability probe API
- Add a central rewarded rollout policy in `MSPAdLoader`; v1 client policy only enables Google + Facebook, future server config can replace the policy input
- Unsupported adapters reject `.rewarded` inside their own `loadAdCreative` implementation
- **No preload API needed**: Google 1-hour expiry is handled by GAD SDK itself — expired ad triggers `didFailToPresentFullScreenContentWithError`, which flows through existing error callback. Auction timeout already managed by `auctionTimeout` in placement config.

### P1-008 — Register new files in yml.template
- Files: relevant `*.yml.template` for MSPiOSCore and MSPCore modules
- Add all new `.swift` files; run XcodeGen to validate
- Run `./Scripts/target-switching/round-trip-test.sh` (Article II.2)

### P1 Tests (write first — TDD)
- `RewardTests.swift`: Reward struct equality, Codable round-trip
- `RewardedAdTests.swift`: instantiation, reward property, show() fatalError in base class
- `RewardedLifecycleControllerTests.swift`:
  - `markRewardEarned()` fires listener once
  - `markRewardEarned()` twice — fires listener once (idempotent)
  - `markDismissed()` without prior reward — does NOT fire reward
  - `markDismissed()` twice — dismiss fires once
  - Correct ordering: reward before dismiss

---

## Phase 2: Adapter Bridge

**Goal**: Google AdMob and Facebook AAN can load and show Rewarded ads, reward callbacks flow through `RewardedLifecycleController` to `AdListener`.

### P2-001 — Google Rewarded Ad
- File: `Sources/Adapters/MSPGoogleAdapter/MSPGoogleAdapter/Rewarded/GoogleRewardedAd.swift` (new)
- `public class GoogleRewardedAd: MSPiOSCore.RewardedAd`
- Holds reference to `GADRewardedAd`, `rootViewController`
- `override show(rootViewController:)` calls `gadRewardedAd.present(from:userDidEarnRewardHandler:)`
- In `userDidEarnRewardHandler`: call `lifecycleController.markRewardEarned()`
- Implements `GADFullScreenContentDelegate`:
  - `adDidRecordImpression` → `markDisplayed()`
  - `adDidRecordClick` → `markClicked()`
  - `adDidDismissFullScreenContent` → `markDismissed()`
  - `didFailToPresentFullScreenContent` → forward error to `adListener.onError`

### P2-002 — Google Adapter routing for `.rewarded`
- File: `Sources/Adapters/MSPGoogleAdapter/MSPGoogleAdapter/GoogleAdapter.swift`
- In `loadAdCreative`: add `.rewarded` branch
- Load `GADRewardedAd` with ad unit ID from `bidderPlacementId`
- On success: create `GoogleRewardedAd`, store in `AdCache`, call `auctionBidListener`
- Forward `adRequest.reward` if present (as `GADServerSideVerificationOptions` custom data or ignore for v1)

### P2-003 — Facebook Rewarded Ad
- File: `Sources/Adapters/MSPFacebookAdapter/MSPFacebookAdapter/Rewarded/FacebookRewardedAd.swift` (new)
- `public class FacebookRewardedAd: MSPiOSCore.RewardedAd`
- Holds reference to `FBRewardedVideoAd`, `rootViewController`
- `override show(rootViewController:)` calls `fbRewardedAd.show(fromRootViewController:)`
- Implements `FBRewardedVideoAdDelegate`:
  - `rewardedVideoAdDidLoad` → cache + bid listener (load phase)
  - `rewardedVideoAdWillLogImpression` → `markDisplayed()`
  - `rewardedVideoAdDidClick` → `markClicked()`
  - `rewardedVideoAdVideoComplete` → `markRewardEarned()` ← reward fires here, before end card
  - `rewardedVideoAdDidClose` → `markDismissed()` ← fires after end card dismissed
  - `rewardedVideoAd(_:didFailWithError:)` → forward to `adListener.onError`

### P2-004 — Facebook Adapter routing for `.rewarded`
- File: `Sources/Adapters/MSPFacebookAdapter/MSPFacebookAdapter/FacebookAdapter.swift`
- In `loadAdCreative`: add `.rewarded` branch
- Create `FBRewardedVideoAd(placementID:)`, set delegate, call `load()`
### P2-005 — All other adapters: add no-op `.rewarded` branch
- Files: All other `*Adapter.swift` files with `switch bidderFormat`
- Add `.rewarded: break` or return unsupported error
- Ensures compiler exhaustiveness is satisfied
- Adapters: Amazon, Inmobi, Liftoff, Mintegral, Mobilefuse, Moloco, Prebid, Pubmatic, Unity

### Adapter Expansion Matrix (moved to Phase 3)

All adapter rewarded implementations are now detailed in **Phase 3**. Summary:

| Network | Phase 3 Task | SDK Class | Status |
|---------|-------------|-----------|--------|
| Liftoff / Vungle | P3-001 | `VungleRewarded` | Planned |
| Moloco | P3-002 | `MolocoRewardedInterstitial` | Required on MSP adapter path; not replaced by Google SDK |
| Mintegral | P3-003 | `MTGRewardAdManager` | Planned |
| MobileFuse | P3-004 | `MFRewardedAd` | Planned |
| PubMatic OpenWrap | P3-005 | `POBRewardedAd` | Planned |
| InMobi | P3-006 | `IMInterstitial` (shared) | Planned |
| Unity / LevelPlay | P3-007 | `LPMRewardedAd` | Planned |
| Amazon APS | P3-008 | — | Deferred |

`Prebid` is not treated as an ad network capability in this matrix. It remains an upstream bidding dependency rather than a direct rewarded creative adapter.

### P2-006 — Register new files in yml.template
- Add new `.swift` files for GoogleRewardedAd, FacebookRewardedAd
- Run XcodeGen; run round-trip test

### P2 Tests (write first — TDD)
- `GoogleRewardedAdTests.swift`:
  - Mock `GADFullScreenContentDelegate` callbacks → verify lifecycle controller calls
  - `userDidEarnRewardHandler` → `onAdRewardReceived` fires
  - Early dismiss (no reward) → `onAdRewardReceived` does not fire
  - Duplicate reward callbacks → only one `onAdRewardReceived`
- `FacebookRewardedAdTests.swift`:
  - `videoComplete` before `didClose` → reward fires before dismiss
  - `didClose` without `videoComplete` → no reward callback

---

## Phase 3: All-Network Rewarded Adapter Expansion

**Goal**: Implement rewarded ad support in ALL remaining adapters (Liftoff, Moloco, Mintegral, MobileFuse, PubMatic, InMobi, Unity/LevelPlay). Only Facebook and Google are enabled via the client rollout gate in v1; all others are code-ready but rollout-gated.

**Architecture: Server-Gated Rollout**

```
Layer 1 (Primary Gate): MSP Server
 └── Server placement config controls which adapters participate in rewarded auctions
 └── v1: only Facebook + Google enabled
 └── Enabling new adapter: server config change only, zero client code changes

Adapter handling:
 └── Each adapter handles `.rewarded` directly inside its own `loadAdCreative`
 └── Unsupported adapters return an explicit error from that branch
 └── No shared capability probe or rejection helper is introduced
```

### P3-000 — Normalize unsupported `.rewarded` handling
- File: adapter `loadAdCreative` implementations
- Keep `.rewarded` on the existing routing path
- Unsupported adapters return a direct `auctionBidListener?.onError(...)` from their own branch
- **Impact**: No extra capability surface, consistent with other platforms

### P3-001 — Liftoff / Vungle Rewarded Ad

**SDK**: `VungleAdsSDK` — `VungleRewarded` class, `VungleRewardedDelegate` protocol
**Pattern**: Mirrors existing `LiftoffInterstitialAd` pattern

- **New file**: `Sources/Adapters/LiftoffAdapter/LiftoffAdapter/Rewarded/LiftoffRewardedAd.swift`
  - `public final class LiftoffRewardedAd: MSPiOSCore.RewardedAd`
  - Holds `VungleRewarded?`, weak `rootViewController`
  - `private lazy var lifecycleController = RewardedLifecycleController(adListener: adListener, ad: self)`
  - `override show(rootViewController:)` → `vungleRewarded.present(with: viewController)`
  - Delegate methods:
    - `rewardedAdDidLoad(_:)` → load success (handled in adapter)
    - `rewardedAdDidTrackImpression(_:)` → `lifecycleController.markDisplayed()`
    - `rewardedAdDidClick(_:)` → `lifecycleController.markClicked()`
    - `rewardedAdDidRewardUser(_:)` → `lifecycleController.markRewardEarned()`
    - `rewardedAdDidClose(_:)` → `lifecycleController.markDismissed()`
    - `rewardedAdDidFailToPresent(_:error:)` → `adListener?.onError()`
    - `rewardedAdDidFailToLoad(_:error:)` → `auctionBidListener.onBidFailed()`

- **Modified file**: `Sources/Adapters/LiftoffAdapter/LiftoffAdapter/LiftoffAdapter.swift`
  - Replace `.rewarded` error branch with:
    ```swift
    case .rewarded:
        self.loadRewardedAd(bidderPlacementId, winningBid, rootViewController, auctionBidListener)
    ```
  - Add `loadRewardedAd()` method (parallel to existing `loadInterstitialAd()`):
    - Create `VungleRewarded(placementId: placementReferenceId)`
    - Set delegate, call `load(adm)` from winning bid
  - Add `VungleRewardedDelegate` conformance

- **Tests**: `Tests/AdapterTests/Specs/LiftoffRewardedAdTests.swift`
  - show() calls `VungleRewarded.present()`
  - `rewardedAdDidRewardUser` → `onAdRewardReceived` fires once
  - `rewardedAdDidClose` without prior reward → no reward callback
  - reward fires before dismiss in sequence

### P3-002 — Moloco Rewarded Ad

**SDK**: `MolocoSDK` — `MolocoRewardedInterstitial` class, `MolocoRewardedInterstitialDelegate` protocol
**Pattern**: Mirrors existing `MolocoInterstitialAd` pattern

- **New file**: `Sources/Adapters/MolocoAdapter/MolocoAdapter/Rewarded/MolocoRewardedAd.swift`
  - `public final class MolocoRewardedAd: MSPiOSCore.RewardedAd`
  - Holds `MolocoRewardedInterstitial?`, weak `rootViewController`
  - `private lazy var lifecycleController = RewardedLifecycleController(adListener: adListener, ad: self)`
  - `override show(rootViewController:)` → `molocoRewarded.show(from: viewController)`
  - Delegate methods:
    - `didLoadRewardedInterstitialAd(_:)` → load success (handled in adapter)
    - `didShowRewardedInterstitialAd(_:)` → `lifecycleController.markDisplayed()`
    - `didClickRewardedInterstitialAd(_:)` → `lifecycleController.markClicked()`
    - `userDidEarnReward(ad:reward:)` → `lifecycleController.markRewardEarned()`
    - `didCloseRewardedInterstitialAd(_:)` → `lifecycleController.markDismissed()`
    - `didFailToShowRewardedInterstitialAd(_:error:)` → `adListener?.onError()`
    - `didFailToLoadRewardedInterstitialAd(_:error:)` → `auctionBidListener.onBidFailed()`

- **Modified file**: `Sources/Adapters/MolocoAdapter/MolocoAdapter/MolocoAdapter.swift`
  - Replace `.rewarded` error branch with load logic
  - Add `MolocoRewardedInterstitialDelegate` conformance
  - Create `MolocoRewardedInterstitial` via `Moloco.shared.createRewardedInterstitial(params:)`
  - Load with `bidResponse: adm`

- **Tests**: `Tests/AdapterTests/Specs/MolocoRewardedAdTests.swift`

### P3-003 — Mintegral Rewarded Ad

**SDK**: `MTGSDK` + `MTGSDKRewardVideo` — `MTGRewardAdManager` class, `MTGRewardAdLoadDelegate` + `MTGRewardAdShowDelegate`
**Pattern**: Uses manager-based API like existing `MTGNewInterstitialBidAdManager`

- **New file**: `Sources/Adapters/MintegralAdapter/MintegralAdapter/Rewarded/MintegralRewardedAd.swift`
  - `public final class MintegralRewardedAd: MSPiOSCore.RewardedAd`
  - Holds `MTGRewardAdManager?`, weak `rootViewController`
  - `private lazy var lifecycleController = RewardedLifecycleController(adListener: adListener, ad: self)`
  - `override show(rootViewController:)` → `rewardAdManager.show(with: viewController)`
  - Show delegate methods (`MTGRewardAdShowDelegate`):
    - `onVideoAdShowSuccess(_:)` → `lifecycleController.markDisplayed()`
    - `onVideoAdClicked(_:)` → `lifecycleController.markClicked()`
    - `onVideoAdDismissed(_:converted:rewardInfo:)` → if `converted`: `lifecycleController.markRewardEarned()` then `lifecycleController.markDismissed()`; else: just `markDismissed()`
    - `onVideoAdShowFailed(_:error:)` → `adListener?.onError()`

- **Modified file**: `Sources/Adapters/MintegralAdapter/MintegralAdapter/MintegralAdapter.swift`
  - Replace `.rewarded` error branch with load logic
  - Create `MTGRewardAdManager(placementId:unitId:)` with bid token, set load/show delegates
  - Add `MTGRewardAdLoadDelegate` + `MTGRewardAdShowDelegate` conformance

- **Tests**: `Tests/AdapterTests/Specs/MintegralRewardedAdTests.swift`

### P3-004 — MobileFuse Rewarded Ad

**SDK**: `MobileFuseSDK` — `MFRewardedAd` class, `IMFAdCallbackReceiver` protocol (shared with all ad types)
**Pattern**: Uses same unified callback as existing `MobilefuseInterstitialAd`

- **New file**: `Sources/Adapters/MobilefuseAdapter/MobilefuseAdapter/Rewarded/MobilefuseRewardedAd.swift`
  - `public final class MobilefuseRewardedAd: MSPiOSCore.RewardedAd`
  - Holds `MFRewardedAd?`, weak `rootViewController`
  - `private lazy var lifecycleController = RewardedLifecycleController(adListener: adListener, ad: self)`
  - `override show(rootViewController:)` → add to view hierarchy + `mfRewardedAd.show()`
  - Unified callback handling via `IMFAdCallbackReceiver`:
    - `onAdLoaded(_:)` → load success (handled in adapter)
    - `onAdRendered(_:)` → `lifecycleController.markDisplayed()`
    - `onAdClicked(_:)` → `lifecycleController.markClicked()`
    - `onUserEarnedReward(_:)` → `lifecycleController.markRewardEarned()`
    - `onAdClosed(_:)` → `lifecycleController.markDismissed()`
    - `onAdError(_:reason:)` → `adListener?.onError()`

- **Modified file**: `Sources/Adapters/MobilefuseAdapter/MobilefuseAdapter/MobilefuseAdapter.swift`
  - Replace `.rewarded` error branch with load logic
  - Create `MFRewardedAd(placementId:)`, register callback, load

- **Tests**: `Tests/AdapterTests/Specs/MobilefuseRewardedAdTests.swift`

### P3-005 — PubMatic OpenWrap Rewarded Ad

**SDK**: `OpenWrapSDK` — `POBRewardedAd` class, `POBRewardedAdDelegate` protocol
**Pattern**: Similar to existing `POBInterstitial` pattern

- **New file**: `Sources/Adapters/PubmaticAdapter/PubmaticAdapter/Rewarded/PubmaticRewardedAd.swift`
  - `public final class PubmaticRewardedAd: MSPiOSCore.RewardedAd`
  - Holds `POBRewardedAd?`, weak `rootViewController`
  - `private lazy var lifecycleController = RewardedLifecycleController(adListener: adListener, ad: self)`
  - `override show(rootViewController:)` → `pobRewardedAd.show(from: viewController)`
  - Delegate methods (`POBRewardedAdDelegate`):
    - `rewardedAdDidReceive(_:)` → load success (handled in adapter)
    - `rewardedAdDidRecordImpression(_:)` → `lifecycleController.markDisplayed()`
    - `rewardedAdDidClick(_:)` → `lifecycleController.markClicked()`
    - `rewardedAd(_:didReward:)` → `lifecycleController.markRewardEarned()`
    - `rewardedAdDidDismiss(_:)` → `lifecycleController.markDismissed()`
    - `rewardedAdDidFailToShow(_:error:)` → `adListener?.onError()`
    - `rewardedAdDidFailToReceive(_:error:)` → `auctionBidListener.onBidFailed()`

- **Modified file**: `Sources/Adapters/PubmaticAdapter/PubmaticAdapter/PubmaticAdapter.swift`
  - Replace `.rewarded` error branch with load logic
  - Create `POBRewardedAd(publisherId:profileId:adUnitId:)`, set delegate, load

- **Tests**: `Tests/AdapterTests/Specs/PubmaticRewardedAdTests.swift`

### P3-006 — InMobi Rewarded Ad

**SDK**: `InMobiSDK` — `IMInterstitial` class (InMobi uses same class for interstitial + rewarded, reward detected via delegate callback)
**Pattern**: Uses same `IMInterstitial` as interstitial, but with `IMInterstitialDelegate.interstitial(_:rewardActionCompletedWithRewards:)` callback

- **New file**: `Sources/Adapters/InmobiAdapter/InmobiAdapter/Rewarded/InmobiRewardedAd.swift`
  - `public final class InmobiRewardedAd: MSPiOSCore.RewardedAd`
  - Holds `IMInterstitial?`, weak `rootViewController`
  - `private lazy var lifecycleController = RewardedLifecycleController(adListener: adListener, ad: self)`
  - `override show(rootViewController:)` → `imInterstitial.show(from: viewController)`
  - Delegate methods (`IMInterstitialDelegate`):
    - `interstitialDidFinishLoading(_:)` → load success (handled in adapter)
    - `interstitialDidPresent(_:)` → `lifecycleController.markDisplayed()`
    - `interstitial(_:didReceiveWith:)` → click tracking
    - `interstitial(_:rewardActionCompletedWithRewards:)` → `lifecycleController.markRewardEarned()`
    - `interstitialDidDismiss(_:)` → `lifecycleController.markDismissed()`
    - `interstitial(_:didFailToPresentWithError:)` → `adListener?.onError()`

- **Modified file**: `Sources/Adapters/InmobiAdapter/InmobiAdapter/InmobiAdapter.swift`
  - Replace `.rewarded` error branch with load logic
  - Create `IMInterstitial(placementId:)` (same class as interstitial)
  - Note: InMobi uses the same `IMInterstitial` for rewarded; the server determines if the placement is a rewarded placement

- **Tests**: `Tests/AdapterTests/Specs/InmobiRewardedAdTests.swift`

### P3-007 — Unity / LevelPlay (IronSource) Rewarded Ad

**SDK**: `IronSource` — `LPMRewardedAd` class, `LPMRewardedAdDelegate` protocol
**Pattern**: Mirrors existing `LPMInterstitialAd` pattern

- **New file**: `Sources/Adapters/UnityAdapter/UnityAdapter/Rewarded/UnityRewardedAd.swift`
  - `public final class UnityRewardedAd: MSPiOSCore.RewardedAd`
  - Holds `LPMRewardedAd?`, weak `rootViewController`
  - `private lazy var lifecycleController = RewardedLifecycleController(adListener: adListener, ad: self)`
  - `override show(rootViewController:)` → `lpmRewardedAd.showAd(from: viewController)`
  - Delegate methods (`LPMRewardedAdDelegate`):
    - `didLoadAd(with:)` → load success (handled in adapter)
    - `didDisplayAd(with:)` → `lifecycleController.markDisplayed()`
    - `didClickAd(with:)` → `lifecycleController.markClicked()`
    - `didRewardAd(with:reward:)` → `lifecycleController.markRewardEarned()`
    - `didCloseAd(with:)` → `lifecycleController.markDismissed()`
    - `didFailToDisplayAd(with:error:)` → `adListener?.onError()`
    - `didFailToLoadAd(with:error:)` → `auctionBidListener.onBidFailed()`

- **Modified file**: `Sources/Adapters/UnityAdapter/UnityAdapter/UnityAdapter.swift`
  - Replace `.rewarded` error branch with load logic
  - Create `LPMRewardedAd(adUnitId:)`, set delegate, loadAd()

- **Tests**: `Tests/AdapterTests/Specs/UnityRewardedAdTests.swift`

### P3-008 — Amazon APS Rewarded Ad — DEFERRED

**Status**: Amazon APS has weaker evidence for direct rewarded iOS support compared to above networks. APS primarily acts as a demand source that feeds into Google Ad Manager, not a standalone rewarded creative renderer.

**Recommendation**: Defer until Amazon confirms direct rewarded API availability. Keep an explicit unsupported `.rewarded` branch in `AmazonAdapter`.

### P3-009 — Register new adapter files in yml.template
- Add all new `Rewarded/XxxRewardedAd.swift` files to respective `*.yml.template`
- Run XcodeGen; run round-trip test

### P3 Tests (per-adapter, write first — TDD)
Each adapter test follows the same pattern established by Google/Facebook:
1. `show()` delegates to SDK present method
2. Reward callback → `onAdRewardReceived` fires once
3. Dismiss without reward → no reward callback
4. Duplicate reward signals → single callback
5. Reward fires before dismiss in sequence

### P3 Execution Order
Adapters are fully independent — all can be developed in parallel:
```
P3-000: normalize unsupported `.rewarded` handling (do first)
Then in parallel:
  P3-001: Liftoff
  P3-002: Moloco
  P3-003: Mintegral
  P3-004: MobileFuse
  P3-005: PubMatic
  P3-006: InMobi
  P3-007: Unity/LevelPlay
P3-008: Amazon (deferred)
P3-009: yml.template + XcodeGen (after all adapters)
```

### Server-Side Enablement Checklist
When ready to enable a new adapter for rewarded:
1. Verify adapter rewarded code is merged and released
2. Update MSP server placement config to include the adapter in rewarded auctions
3. Test via Debug page with rewarded format
4. No client-side code changes needed

---

## Phase 4: MSP Full-Screen (NovaCore) — DEFERRED

**Condition**: NovaCore self-rendered ads currently lack a reliable reward completion signal.
**Trigger**: Re-open this phase when NovaCore team confirms reward condition definition.
**Preparation done in Phase 1**: Rewarded already flows through the normal adapter dispatch path, so Nova enablement mainly requires reward signal wiring and adapter implementation.

---

## Phase 5: Tooling & Integration Tests

### P5-001 — Debug UI: add Rewarded format to AdFormat selector
- File: `Sources/Core/MSPCore/MSPCore/Debug/Models/Extensions/AdFormat+DebugOption.swift`
- Add `.rewarded` → `id: "rewarded"`, `title: "Rewarded"` following existing pattern

### P5-002 — Debug UI: new Reward Config section
- New file: `Sources/Core/MSPCore/MSPCore/Debug/Models/RewardConfig.swift`
  - `RewardTypeOption: DebugOption, TestParamsPresentable` — options: "coins", "lives", "credits" → `("reward_type", <value>)`
  - `RewardAmountOption: DebugOption, TestParamsPresentable` — options: 1, 5, 10 → `("reward_amount", "<value>")`
- New files: `RewardTypeOption+DebugOption.swift`, `RewardAmountOption+DebugOption.swift` in `Models/Extensions/`
- File: `Sources/Core/MSPCore/MSPCore/Debug/Repositorys/TestDebugSectionsService.swift`
  - Add two new sections: **Reward Type** and **Reward Amount**
  - Both with `showCondition: ["rewarded"]` — only visible when Rewarded format selected
  - Insert after Ad Format section in section order

### P5-003 — Debug UI: wire reward params into AdRequest
- File: `Sources/Core/MSPCore/MSPCore/Debug/Repositorys/TestLoadAdService.swift`
  - Read selected `RewardTypeOption` and `RewardAmountOption` from current selections
  - If format is `.rewarded` and both options selected: set `adRequest.reward = Reward(type:amount:)`
  - This ensures the reward config is sent with the test request

### P5-004 — Debug UI: show reward callback in toast/log
- File: `Sources/Core/MSPCore/MSPCore/Debug/Repositorys/TestLoadAdService.swift` (AdListener impl)
  - Implement `onAdRewardReceived(ad:)` — show green toast: "✓ Reward received"
  - Record timestamp of reward callback; on `onAdDismissed`: show toast indicating whether reward arrived before dismiss

### P5-002 — Integration test scenarios
- Load success → no show → no callbacks
- Load → show → user closes early → dismiss only, no reward
- Load → show → full watch → reward then dismiss
- Platform sends duplicate reward signals → single `onAdRewardReceived`
- Google ad loaded > 1 hour ago → show fails with clear error

---

## Open Items ⚠️

| Item | Status | Notes |
|------|--------|-------|
| Amazon APS rewarded API surface | ⚠️ Deferred | Local iOS headers lack clear rewarded API evidence; keep an explicit unsupported `.rewarded` branch in AmazonAdapter until confirmed |
| FR-002 reward optional vs required | ⚠️ Pending | Awaiting product/server confirmation |
| Mintegral reward ordering | ⚠️ Verify | `onVideoAdDismissed` carries `converted: Bool` — confirm this flag reliably indicates reward earned before dismiss |
| MobileFuse `onUserEarnedReward` | ⚠️ Verify | Confirm callback name and parameters in MobileFuseSDK headers |
| InMobi shared class model | ⚠️ Verify | InMobi uses same `IMInterstitial` class for both interstitial and rewarded — confirm server-side placement type drives reward callback |
