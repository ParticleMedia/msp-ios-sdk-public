# Data Model: Nova Rewarded Ad

**Date**: 2026-03-26
**Branch**: `001-nova-rewarded-ad`

## Entity Hierarchy

```
NovaNativeBaseAd (existing, unchanged)
  └── NovaFullScreenAdItem (NEW — extracted from NovaInterstitialAdItem)
        ├── NovaInterstitialAdItem (MODIFIED — now inherits NovaFullScreenAdItem)
        └── NovaRewardedAdItem (NEW)

MSPAd (existing, unchanged)
  └── RewardedAd (MODIFIED — reward becomes optional)
        └── NovaRewardedAd (NEW — adapter-layer wrapper)
```

## New Entities

### NovaFullScreenAdItem (Base Class)

Extracted from `NovaInterstitialAdItem`. Inherits `NovaNativeBaseAd`.

| Property | Type | Source |
|----------|------|--------|
| `shouldPreloadHtml` | `Bool` | Extracted from `NovaInterstitialAdItem` |
| `cachedHtmlView` | `NovaAdHtmlView?` | Extracted from `NovaInterstitialAdItem` |
| `viewController` | `UIViewController?` (weak) | Stored presenting VC for dismiss |

All inherited from `NovaNativeBaseAd` (unchanged):
- `adUnitId`, `requestId`, `adId`, `adSetId`, `encryptedAdToken`
- `headline`, `body`, `callToAction`, `advertiser`, `iconURL`
- `creativeType`, `mediaContent`, `adCtrType`, `ctaStyle`
- Tracking URL arrays, `priceInDollar`

### NovaRewardedAdItem (New Class)

Inherits `NovaFullScreenAdItem`. Minimal — rewards are tracked at the adapter layer.

| Property | Type | Description |
|----------|------|-------------|
| `delegate` | `NovaRewardedAdDelegate?` (weak) | Rewarded-specific delegate |

### NovaRewardedAdDelegate (Protocol, : AnyObject)

Independent delegate protocol for rewarded ad lifecycle. Mirrors `NovaInterstitialAdDelegate` naming pattern.

| Method | Description |
|--------|-------------|
| `rewardedAdDidDisplay(_:)` | Ad appeared on screen, impression logged |
| `rewardedAdDidDismiss(_:)` | Ad was dismissed |
| `rewardedAdDidLogClick(_:)` | User tapped ad CTA |
| `rewardedAdDidEarnReward(_:)` | H5 signaled reward earned via JSBridge |

### NovaFullScreenAdViewController (Base Class)

Extracted from `NovaInterstitialAdViewController`.

| Property/Method | Description |
|-----------------|-------------|
| `adItem: NovaFullScreenAdItem` | The ad being displayed |
| `viewDidLoad()` | Common view setup |
| `viewDidAppear()` | Impression logging |
| Orientation locking | iPad H5 orientation management (iOS 15/16-25/26+) |
| Ad view lifecycle | `willAppear/didAppear/willDisappear/didDisappear` forwarding |

### NovaRewardedAd (Adapter Layer)

Inherits `MSPiOSCore.RewardedAd`. Wraps `NovaRewardedAdItem`.

| Property | Type | Description |
|----------|------|-------------|
| `rewardedAdItem` | `NovaRewardedAdItem?` | The Nova ad item |
| `rootViewController` | `UIViewController?` (weak) | Presenting VC |
| `lifecycleController` | `RewardedLifecycleController` (lazy) | Manages reward state |

### Rewarded Video Creative (Serving/H5 Contract)

Represents the PRD-eligible Nova creative rendered by `NovaRewardedAdItem`.

| Field/Rule | Source of Truth | Description |
|------------|-----------------|-------------|
| `placement` | Nova bid request | publisher-supplied placementId; SDK forwards verbatim (FR-017a) |
| `ad_format` | Nova bid request | enum value `rewarded_video` when `AdRequest.adFormat == .rewarded` (FR-017b); distinct field from `placement` |
| SDK-emitted MES events | `RewardedLifecycleController` | `ad_impression` / `ad_click` / `ad_rewarded`, exactly once each (FR-020) |
| H5-side events (SKIP / `skip_type` / Get Rewards / Close success / in-H5 video lifecycle) | H5 → Nova event endpoint | beaconed by H5 directly; SDK does NOT relay (FR-021) |
| Creative family | Ad serving | Nova single video ads and Nova playable video ads are eligible |
| `video_length >= 10s` | Ad serving | Minimum recall eligibility from PRD |
| Countdown | H5 | `min(video_length, 30s)` |
| Playback flags | H5 | `is_mute = false`, `is_loop = false`, `is_auto_play = true` |
| End card/playable + close button | H5 | Shown after video completion or after skip from countdown-finished state |
| Reward earned signal | H5 → SDK | `novaNativeBridge.onAdRewarded()` |

SDK load success requires a renderable H5 rewarded-video creative. If the rewarded item is missing or unsupported, the adapter reports load failure instead of returning a `RewardedAd`.

## Modified Entities

### RewardedAd (MSPiOSCore)

| Change | Before | After |
|--------|--------|-------|
| `reward` | `let reward: Reward` | `let reward: Reward?` |
| `init` | `init(adNetworkAdapter:reward:)` | `init(adNetworkAdapter:reward:)` where reward is `Reward?` |

### NovaAdHtmlActionDelegate (NovaCore)

| Change | Description |
|--------|-------------|
| `didEarnReward()` | NEW method — called when H5 fires `onAdRewarded` |

## State Transitions

### Rewarded Ad Lifecycle

```
[Loaded] → show() → [Displaying]
[Displaying] → H5 fires onAdRewarded → [Reward Earned] → user closes → [Dismissed]
[Displaying] → user closes early → [Dismissed Without Reward]
[Displaying] → WebView crash → [Dismissed Without Reward]
```

State is tracked by `RewardedLifecycleController` (existing, unchanged):
- `hasEarnedReward: Bool`
- `hasDismissed: Bool`

Callback order guaranteed:
1. `onAdImpression` (on display)
2. `onAdRewardReceived` (if H5 calls `onAdRewarded`, exactly once)
3. `onAdDismissed` (always, after reward if earned)
