# Data Model: Rewarded Ads

**Branch**: `001-rewarded-ads` | **Date**: 2026-03-11

## Entity Definitions

### Reward
```
Reward (value type / struct)
├── type: String          — reward category label (e.g. "coins", "lives")
└── amount: Int           — quantity of reward units
```
- Equatable, Codable, Sendable
- Owned by `AdRequest` (optional) and `RewardedAd` (set at load time from request or network response)
- Source of truth for reward metadata when not using network-native payload

---

### AdRequest (extended)
```
AdRequest (existing class, extended)
├── ... existing fields ...
└── reward: Reward?       — optional reward config; nil = no reward param forwarded to network
```
- `reward` is written once at request construction; not mutated after
- Adapter's `loadAdCreative` reads `adRequest.reward` to forward to network SDK

---

### RewardedAd
```
RewardedAd (open class, extends MSPAd)
├── reward: Reward           — the reward config associated with this ad
├── show(rootViewController:) — presents full-screen; fatalError if not overridden
└── dismiss(animated:)        — dismisses; default no-op, override in subclass
```
- Parallel to `InterstitialAd`; does NOT inherit from it
- Each instance owns a `RewardedLifecycleController` (internal)
- `adListener` (inherited from MSPAd) receives `onAdRewardReceived(ad:)` at most once per instance

---

### RewardedLifecycleController (internal)
```
RewardedLifecycleController (internal final class)
├── hasEarnedReward: Bool      — set to true on first markRewardEarned()
├── hasDismissed: Bool         — set to true on first markDismissed()
├── markDisplayed()            — fires impression via dispatcher
├── markClicked()              — fires click via dispatcher
├── markRewardEarned()         — idempotent; fires reward callback once
└── markDismissed()            — idempotent; fires dismiss callback once
```
- Pure Swift; no UIKit or third-party SDK dependency
- Injected with `AdListener` at construction (or via dispatcher wrapper)
- State invariant: `markDismissed()` never triggers reward; `markRewardEarned()` must precede `markDismissed()` for reward to be delivered

---

### AdListener (extended)
```
AdListener (existing protocol, extended)
├── ... existing methods ...
└── onAdRewardReceived(ad: MSPAd)   — default empty implementation via extension
```
- Default empty implementation ensures zero breaking changes for existing adopters
- Adopters implementing Rewarded override this method

---

### AdFormat (extended)
```
AdFormat (existing CaseIterable enum, extended)
├── banner
├── native
├── multi_format
├── interstitial
└── rewarded              — NEW
```
- Adding `.rewarded` requires exhaustive `switch` statements in all adapters to be updated
- Affected: `GoogleAdapter`, `FacebookAdapter`, `NovaAdapter`, and all other `AdNetworkAdapter` implementations that switch on `bidderFormat`

---

## State Transitions

```
RewardedAd Lifecycle:

  [idle]
    │  load() called
    ▼
  [loaded]
    │  show(rootViewController:) called
    ▼
  [displaying]
    │  user satisfies reward condition (platform callback)
    ├──► markRewardEarned()
    │      └── onAdRewardReceived(ad:) fired (once only)
    │  user closes ad (platform dismiss callback)
    ▼
  [dismissed]
         └── onAdDismissed fired (once only)

Invariants:
  - markRewardEarned() is idempotent (no-op on second call)
  - markDismissed() is idempotent (no-op on second call)
  - Dismiss without prior reward = no reward callback (never backfill)
  - Reward without subsequent dismiss = valid state (end card still showing)
```

---

## Network-Specific Mapping

### v1 (Implemented + Enabled)

| Event | Google AdMob | Facebook AAN |
|-------|-------------|--------------|
| Load | `GADRewardedAd.load()` | `FBRewardedVideoAd.load()` |
| Show | `present(from:userDidEarnRewardHandler:)` | `show(fromRootViewController:)` |
| Impression | `adDidRecordImpression` | `rewardedVideoAdWillLogImpression` |
| Click | `adDidRecordClick` | `rewardedVideoAdDidClick` |
| Reward | `userDidEarnRewardHandler` closure | `rewardedVideoAdVideoComplete()` |
| Dismiss | `adDidDismissFullScreenContent` | `rewardedVideoAdDidClose()` |
| Load Fail | `load` error | `rewardedVideoAd(_:didFailWithError:)` |
| Show Fail | `didFailToPresentFullScreenContentWithError` | check `isAdValid` |

### All-Network Expansion (Implemented, Server-Gated)

| Event | Liftoff/Vungle | Moloco | Mintegral |
|-------|---------------|--------|-----------|
| SDK Class | `VungleRewarded` | `MolocoRewardedInterstitial` | `MTGRewardAdManager` |
| Load | `load(adm)` | `load(bidResponse:)` | `loadAd(withBidToken:)` |
| Show | `present(with:)` | `show(from:)` | `show(with:)` |
| Impression | `rewardedAdDidTrackImpression` | `didShowRewardedInterstitialAd` | `onVideoAdShowSuccess` |
| Click | `rewardedAdDidClick` | `didClickRewardedInterstitialAd` | `onVideoAdClicked` |
| Reward | `rewardedAdDidRewardUser` | `userDidEarnReward` | `onVideoAdDismissed(converted: true)` |
| Dismiss | `rewardedAdDidClose` | `didCloseRewardedInterstitialAd` | `onVideoAdDismissed` |
| Delegate | `VungleRewardedDelegate` | `MolocoRewardedInterstitialDelegate` | `MTGRewardAdShowDelegate` |

| Event | MobileFuse | PubMatic | InMobi |
|-------|-----------|----------|--------|
| SDK Class | `MFRewardedAd` | `POBRewardedAd` | `IMInterstitial` (shared) |
| Load | `load()` | `loadAd()` | `load()` |
| Show | `show()` | `show(from:)` | `show(from:)` |
| Impression | `onAdRendered` | `rewardedAdDidRecordImpression` | `interstitialDidPresent` |
| Click | `onAdClicked` | `rewardedAdDidClick` | `interstitial(_:didReceiveWith:)` |
| Reward | `onUserEarnedReward` | `rewardedAd(_:didReward:)` | `interstitial(_:rewardActionCompletedWithRewards:)` |
| Dismiss | `onAdClosed` | `rewardedAdDidDismiss` | `interstitialDidDismiss` |
| Delegate | `IMFAdCallbackReceiver` | `POBRewardedAdDelegate` | `IMInterstitialDelegate` |

| Event | Unity / LevelPlay |
|-------|------------------|
| SDK Class | `LPMRewardedAd` |
| Load | `loadAd()` |
| Show | `showAd(from:)` |
| Impression | `didDisplayAd` |
| Click | `didClickAd` |
| Reward | `didRewardAd(_:reward:)` |
| Dismiss | `didCloseAd` |
| Delegate | `LPMRewardedAdDelegate` |

---

## Debug-Specific Models (US5)

Following the existing `XxxOption: DebugOption, TestParamsPresentable` pattern:

```
RewardTypeOption
├── id: "coins" | "lives" | "credits"
├── title: display string
└── testParams: [("reward_type", id)]

RewardAmountOption
├── id: "1" | "5" | "10"
├── title: display string
└── testParams: [("reward_amount", id)]
```

Two new debug sections (both `showCondition = ["rewarded"]`):
- **Reward Type** section — single-select RewardTypeOption
- **Reward Amount** section — single-select RewardAmountOption

`TestLoadAdService` reads these selections and builds `Reward(type:amount:)` when format == `.rewarded`.

---

## New Files

| File | Module | Type |
|------|--------|------|
| `api/Reward.swift` | MSPiOSCore | New struct |
| `Debug/Models/Extensions/AdFormat+DebugOption.swift` | MSPCore | Modified — add `.rewarded` |
| `Debug/Models/RewardConfig.swift` | MSPCore | New debug option types |
| `Debug/Models/Extensions/RewardTypeOption+DebugOption.swift` | MSPCore | New |
| `Debug/Models/Extensions/RewardAmountOption+DebugOption.swift` | MSPCore | New |
| `api/RewardedAd.swift` | MSPiOSCore | New open class |
| `internal/RewardedLifecycleController.swift` | MSPiOSCore | New public final class |
| `Rewarded/GoogleRewardedAd.swift` | MSPGoogleAdapter | New class |
| `Rewarded/FacebookRewardedAd.swift` | MSPFacebookAdapter | New class |
| `Rewarded/LiftoffRewardedAd.swift` | LiftoffAdapter | New class (Phase 9) |
| `Rewarded/MolocoRewardedAd.swift` | MolocoAdapter | New class (Phase 9) |
| `Rewarded/MintegralRewardedAd.swift` | MintegralAdapter | New class (Phase 9) |
| `Rewarded/MobilefuseRewardedAd.swift` | MobilefuseAdapter | New class (Phase 9) |
| `Rewarded/PubmaticRewardedAd.swift` | PubmaticAdapter | New class (Phase 9) |
| `Rewarded/InmobiRewardedAd.swift` | InmobiAdapter | New class (Phase 9) |
| `Rewarded/UnityRewardedAd.swift` | UnityAdapter | New class (Phase 9) |

## Modified Files

| File | Module | Change |
|------|--------|--------|
| `api/AdFormat.swift` | MSPiOSCore | Add `.rewarded` case |
| `api/AdRequest.swift` | MSPiOSCore | Add `reward: Reward?` property |
| `api/Delegates/AdListener.swift` | MSPiOSCore | Add `onAdRewardReceived(ad:)` with default impl |
| `adapter/AdNetworkAdapter.swift` | MSPiOSCore | Add `rejectUnsupportedRewardedAd()` extension (Phase 9) |
| `GoogleAdapter.swift` | MSPGoogleAdapter | Handle `.rewarded` in `loadAdCreative` |
| `FacebookAdapter.swift` | MSPFacebookAdapter | Handle `.rewarded` in `loadAdCreative` |
| `LiftoffAdapter.swift` | LiftoffAdapter | Replace error → load logic (Phase 9) |
| `MolocoAdapter.swift` | MolocoAdapter | Replace error → load logic (Phase 9) |
| `MintegralAdapter.swift` | MintegralAdapter | Replace error → load logic (Phase 9) |
| `MobilefuseAdapter.swift` | MobilefuseAdapter | Replace error → load logic (Phase 9) |
| `PubmaticAdapter.swift` | PubmaticAdapter | Replace error → load logic (Phase 9) |
| `InmobiAdapter.swift` | InmobiAdapter | Replace error → load logic (Phase 9) |
| `UnityAdapter.swift` | UnityAdapter | Replace error → load logic (Phase 9) |
| `AmazonAdapter.swift` | AmazonAdapter | Use `rejectUnsupportedRewardedAd()` helper (deferred) |
| `NovaAdapter.swift` | NovaAdapter | Keep `.rewarded` unsupported in v1 |
| `MSPAdLoader.swift` | MSPCore | Route `.rewarded` through the existing load path |
| `Debug/Repositorys/TestDebugSectionsService.swift` | MSPCore | Add Reward Type + Reward Amount sections |
| `Debug/Repositorys/TestLoadAdService.swift` | MSPCore | Wire reward params + implement onAdRewardReceived |
| All `*.yml.template` files | Build | Register new `.swift` files |
