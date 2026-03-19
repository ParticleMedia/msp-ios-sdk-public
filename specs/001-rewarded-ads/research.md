# Research: Rewarded Ads

**Branch**: `001-rewarded-ads` | **Date**: 2026-03-11

## 1. Existing Architecture Findings

### AdFormat (current)
`AdFormat` is a `CaseIterable` enum with four cases: `banner`, `native`, `multi_format`, `interstitial`. Adding `.rewarded` is a one-line change but will affect any `switch adFormat` exhaustive patterns across the codebase.

**Decision**: Add `.rewarded` as a peer case.
**Impact**: All adapters calling `switch bidderFormat` or similar must add a `.rewarded` branch — identified in `GoogleAdapter`, `FacebookAdapter`, `MSPAdLoader`, and all other adapter `loadAdCreative` implementations.

### AdListener (current)
```swift
public protocol AdListener: AnyObject {
    func onError(msg: String, loadInfo: [String: Any])
    func onAdImpression(ad: MSPAd)
    func onAdClick(ad: MSPAd)
    func onAdLoaded(placementId: String, loadInfo: [String: Any])
    func onAdDismissed(ad: InterstitialAd)
    func getRootViewController() -> UIViewController?
}
```
`onAdDismissed` currently takes `InterstitialAd`. `RewardedAd` will be a peer class (not a subclass), so a new `onAdRewardReceived(ad: MSPAd)` can be added with a default empty implementation without breaking existing implementors.

**Decision**: Add `onAdRewardReceived(ad: MSPAd)` via protocol extension default.
**Rationale**: `MSPAd` is the common base; using it keeps the signature stable if `RewardedAd` internals change. Provides default `{}` implementation so existing AdListener adopters need zero changes.

### InterstitialAd → RewardedAd (relationship)
`InterstitialAd` is `open class InterstitialAd: MSPAd` with `show()`, `show(rootViewController:)`, `dismiss(animated:)`. All adapter interstitials extend this.

**Decision**: `RewardedAd` is a **parallel open class** extending `MSPAd` directly, not inheriting from `InterstitialAd`.
**Rationale**: Design doc and spec agree — Rewarded semantic is "full-screen ad with reward", not "interstitial". Separate class keeps public API clean and prevents reward/dismiss semantics mixing in tests.

### Adapter Pattern
All adapters implement `AdNetworkAdapter.loadAdCreative(bidResponse:auctionBidListener:adListener:context:adRequest:bidderPlacementId:bidderFormat:params:)`. The `bidderFormat: AdFormat?` parameter is used to dispatch to banner/native/interstitial handling. Rewarded will add a new branch.

Each adapter also has a network-specific `XxxInterstitialAd: MSPiOSCore.InterstitialAd` subclass. Rewarded follows the same pattern: `GoogleRewardedAd: MSPiOSCore.RewardedAd`.

### MSPAdLoader
Central loader. Uses `MSPAdConfigManager` to resolve bidders, calls `Bidder.requestBid`, runs auction, caches winning `MSPAd` via `AdCache.shared.saveAd()`. The format-specific routing happens inside each adapter's `loadAdCreative`. No changes needed to the Bidder/Auction layer itself — only adapter `loadAdCreative` implementations.

### NovaAdapter / NovaInterstitialAd
Currently `NovaInterstitialAd: MSPiOSCore.InterstitialAd`. Per spec, NovaCore Rewarded remains out of scope for v1. The current implementation does not add a special capability protocol for Rewarded; unsupported adapters fail explicitly inside `loadAdCreative`.

## 2. Third-Party SDK APIs

### Google AdMob — GADRewardedAd (iOS)
- **Load**: `RewardedAd.load(with:request:)` (async/await or completion)
- **Show**: `present(from:userDidEarnRewardHandler:)` — reward closure passed at show time
- **Reward object**: `rewardedAd.adReward` → `GADAdReward` with `.type: String` and `.amount: NSDecimalNumber`
- **Lifecycle delegate**: `GADFullScreenContentDelegate` — `adWillPresent`, `adDidRecord Impression/Click`, `adWillDismiss`, `adDidDismiss`, `didFailToPresent`
- **Reward timing**: For Google's own ads, `userDidEarnRewardHandler` fires before `adDidDismissFullScreenContent`. For mediation, order not guaranteed by Google.
- **Expiry**: Ads expire ~1 hour after load.

### Facebook Audience Network — FBRewardedVideoAd (iOS)
- **Load**: `FBRewardedVideoAd(placementID:)` + `delegate = self` + `load()`; recommend 30s before show
- **Show**: `show(fromRootViewController:)` after checking `isAdValid`
- **Reward trigger**: `rewardedVideoAdVideoComplete()` — fires when full video completes, **before** end card appears
- **Dismiss trigger**: `rewardedVideoAdDidClose()` — fires after end card is dismissed
- **Reward ordering guarantee**: `videoComplete` (reward) → end card → `didClose` (dismiss)
- **No client-side reward payload**: The `videoComplete` callback has no type/amount; payload is server-side only (SSV).

## 3. Lifecycle State Machine

**Decision**: Implement `RewardedLifecycleController` (internal, pure Swift struct/class) to centralize:
- Idempotency: `hasEarnedReward: Bool`, `hasDismissed: Bool`
- Ordering: reward fires before dismiss
- Isolation: each `RewardedAd` instance owns one controller

**States**: `idle → loaded → displaying → (rewardEarned?) → dismissed`

```
markDisplayed()      → displaying
markRewardEarned()   → rewardEarned (idempotent, calls listener once)
markDismissed()      → dismissed (idempotent, only fires if hasDismissed == false)
```

Adapter delegates translate platform callbacks into `mark*()` calls — never call `AdListener` directly from delegates.

## 4. Bidder Format Routing

**Decision**: Keep Rewarded routing aligned with other platforms: no `supportsRewardedAd()` capability API is introduced. The loader continues to use the existing auction/load path, and each adapter handles `.rewarded` directly.

**Rationale**: This keeps the iOS design consistent with the rest of the SDK family and avoids introducing a one-off protocol hook solely for Rewarded.

### Rollout Gate (current vs future)

**Decision**: Add a central rewarded rollout policy in `MSPAdLoader`.

- **Current source**: client-side whitelist, only `google` and `facebook`
- **Future source**: server placement config once backend support is ready
- **Invariant**: adapter routing stays unchanged; only bidder participation is filtered at the loader boundary

**Rationale**: This gives the product a safe staged rollout now without scattering conditional logic across adapters. When server-side rollout is available, the policy input can be swapped without rewriting adapter implementations.

## 5. Rewarded Capability Survey

Official documentation plus local SDK/header inspection shows that rewarded capability exists beyond the v1 implementation scope:

| Network | Evidence type | Notes |
|---------|---------------|-------|
| Google AdMob | Official docs + implemented adapter | In scope for v1 |
| Facebook Audience Network | Official docs + implemented adapter | In scope for v1 |
| Liftoff / Vungle | Official docs | Rewarded supported, not yet integrated here |
| Moloco | Official docs + current branch code | Rewarded video supported. Google Mobile Ads integration does not subsume this path: Google mediation to Moloco would still require Moloco SDK + mediation adapter, so `MSPMolocoAdapter` remains a separate MSP bidder integration. |
| Mintegral | Local SDK headers + official product docs | Rewarded supported, not yet integrated here |
| MobileFuse | Local SDK headers + official docs | Rewarded supported, not yet integrated here |
| PubMatic OpenWrap | Local SDK headers + official mediation docs | Rewarded supported, not yet integrated here |
| InMobi | Official docs | Rewarded supported, not yet integrated here |
| LevelPlay / IronSource | Local SDK headers + official docs | Rewarded supported; this repository's `UnityAdapter` is built on LevelPlay APIs |
| Amazon APS | Official partner-side evidence + local APS SDK presence | Likely supported, but local headers expose weaker direct rewarded evidence than the networks above |

This matrix now drives Phase 3 (all-network adapter expansion) in `plan.md`.

## 5.1 Per-Adapter SDK API Details (Expansion Phase)

### Liftoff / Vungle
- **SDK**: `VungleAdsSDK` (already imported in `LiftoffAdapter`)
- **Rewarded class**: `VungleRewarded(placementId:)`
- **Delegate**: `VungleRewardedDelegate`
- **Load**: `vungleRewarded.load(adm)` — uses ADM string from winning bid
- **Show**: `vungleRewarded.present(with: viewController)`
- **Reward callback**: `rewardedAdDidRewardUser(_:)` — fires when user earns reward
- **Dismiss callback**: `rewardedAdDidClose(_:)` — fires after ad closed
- **Ordering**: `rewardedAdDidRewardUser` → `rewardedAdDidClose` (reward before dismiss)
- **Pattern parallel**: Mirrors `VungleInterstitial` → `VungleRewarded`

### Moloco
- **SDK**: `MolocoSDK` (already imported in `MolocoAdapter`)
- **Rewarded class**: `MolocoRewardedInterstitial` via `Moloco.shared.createRewardedInterstitial(params:)`
- **Delegate**: `MolocoRewardedInterstitialDelegate`
- **Load**: `molocoRewarded.load(bidResponse: adm)`
- **Show**: `molocoRewarded.show(from: viewController)`
- **Reward callback**: `userDidEarnReward(ad:reward:)`
- **Dismiss callback**: `didCloseRewardedInterstitialAd(_:)`
- **Pattern parallel**: Mirrors `MolocoInterstitial` → `MolocoRewardedInterstitial`
- **Integration boundary**: This is a standalone MSP adapter path. Even if the app also integrates Google Mobile Ads SDK, Moloco demand only arrives through Google when the app additionally wires Google's Moloco mediation adapter. That mediation path is distinct from, and does not replace, `MSPMolocoAdapter`.

### Mintegral
- **SDK**: `MTGSDK` + `MTGSDKRewardVideo` (need to import `MTGSDKRewardVideo`)
- **Rewarded class**: `MTGRewardAdManager(placementId:unitId:)`
- **Delegates**: `MTGRewardAdLoadDelegate` (load) + `MTGRewardAdShowDelegate` (show)
- **Load**: `rewardAdManager.loadAd(withBidToken: bidToken)`
- **Show**: `rewardAdManager.show(with: viewController)`
- **Reward callback**: `onVideoAdDismissed(_:converted:rewardInfo:)` — `converted == true` indicates reward earned
- **Dismiss callback**: Same `onVideoAdDismissed` — fires with `converted` flag
- **Note**: Mintegral combines reward + dismiss into a single callback; `converted: Bool` differentiates. Implementation should call `markRewardEarned()` before `markDismissed()` when `converted == true`.
- **Pattern parallel**: Mirrors `MTGNewInterstitialBidAdManager` → `MTGRewardAdManager`

### MobileFuse
- **SDK**: `MobileFuseSDK` (already imported in `MobilefuseAdapter`)
- **Rewarded class**: `MFRewardedAd(placementId:)`
- **Delegate**: `IMFAdCallbackReceiver` (unified protocol for all MobileFuse ad types)
- **Load**: `mfRewardedAd.register(self)` + `mfRewardedAd.load()`
- **Show**: Add to view hierarchy + `mfRewardedAd.show()`
- **Reward callback**: `onUserEarnedReward(_:)` — to verify in SDK headers
- **Dismiss callback**: `onAdClosed(_:)`
- **Pattern parallel**: Mirrors `MFInterstitialAd` → `MFRewardedAd`

### PubMatic OpenWrap
- **SDK**: `OpenWrapSDK` (already imported in `PubmaticAdapter`)
- **Rewarded class**: `POBRewardedAd(publisherId:profileId:adUnitId:)`
- **Delegate**: `POBRewardedAdDelegate`
- **Load**: `pobRewardedAd.loadAd()`
- **Show**: `pobRewardedAd.show(from: viewController)`
- **Reward callback**: `rewardedAd(_:didReward:)` — fires with reward object
- **Dismiss callback**: `rewardedAdDidDismiss(_:)`
- **Pattern parallel**: Mirrors `POBInterstitial` → `POBRewardedAd`

### InMobi
- **SDK**: `InMobiSDK` (already imported in `InmobiAdapter`)
- **Rewarded class**: `IMInterstitial(placementId:delegate:)` — **same class as interstitial**
- **Delegate**: `IMInterstitialDelegate` (same protocol)
- **Load**: `imInterstitial.load()`
- **Show**: `imInterstitial.show(from: viewController)`
- **Reward callback**: `interstitial(_:rewardActionCompletedWithRewards:)` — fires with reward dictionary
- **Dismiss callback**: `interstitialDidDismiss(_:)`
- **Key note**: InMobi does not have a separate rewarded class. The server-side placement configuration determines whether it's an interstitial or rewarded placement. The `rewardActionCompletedWithRewards` callback fires ONLY for rewarded placements.
- **Pattern parallel**: Same `IMInterstitial` class, separate wrapper `InmobiRewardedAd` for type safety

### Unity / LevelPlay (IronSource)
- **SDK**: `IronSource` (already imported in `UnityAdapter`)
- **Rewarded class**: `LPMRewardedAd(adUnitId:)`
- **Delegate**: `LPMRewardedAdDelegate`
- **Load**: `lpmRewardedAd.loadAd()`
- **Show**: `lpmRewardedAd.showAd(from: viewController)`
- **Reward callback**: `didRewardAd(with:reward:)` — fires with ad info + reward
- **Dismiss callback**: `didCloseAd(with:)`
- **Pattern parallel**: Mirrors `LPMInterstitialAd` → `LPMRewardedAd`

### Amazon APS — DEFERRED
- **SDK**: `DTBiOSSDK` (already imported in `AmazonAdapter`)
- **Status**: APS primarily acts as a header bidding demand source. Local iOS headers do not expose a clear rewarded ad class equivalent to other SDKs. APS may feed into Google Ad Manager for rewarded delivery, but direct standalone rewarded rendering is not confirmed.
- **Recommendation**: Keep `rejectUnsupportedRewardedAd()` until Amazon confirms or until partner documentation provides a clear API surface.

## 6. XcodeGen / Project Config Impact

All new `.swift` files must be listed in the relevant `*.yml.template` files (per Article I.2 / IV.6). New files span:
- `MSPiOSCore` module: `RewardedAd.swift`, `Reward.swift`, updated `AdFormat.swift`, `AdListener.swift`, `AdRequest.swift`
- `MSPCore` module: `RewardedLifecycleController.swift`
- `MSPGoogleAdapter` module: `GoogleRewardedAd.swift`
- `MSPFacebookAdapter` module: `FacebookRewardedAd.swift`

Each module's `yml.template` must include these new files.

## 7. Open Items (⚠️ Pending External Confirmation)

| Item | Current Assumption | Confirm With |
|------|-------------------|--------------|
| Reward type/amount required vs optional | Optional (FR-002) | Product / MSP server team |
| Amazon APS direct iOS rewarded API surface | Likely supported, but local headers are not explicit | APS / monetization team |
| Mintegral `converted` flag reliability | `onVideoAdDismissed(converted: true)` = reward earned | Mintegral docs / integration team |
| MobileFuse `onUserEarnedReward` callback | Exists in MobileFuseSDK headers for rewarded | MobileFuseSDK header inspection |
| InMobi shared class: reward callback fires only for rewarded placements | Yes, server placement type determines | InMobi integration team |
