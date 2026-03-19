# Public API Contract: Rewarded Ads

**Branch**: `001-rewarded-ads` | **Date**: 2026-03-11
**Stability**: Proposed (pre-implementation)

This document defines the complete public Swift API surface added or modified by this feature. All symbols marked `public` or `open` constitute a versioned contract.

---

## New Symbols

### `Reward`
```swift
/// Describes the reward associated with a server-side rewarded ad placement.
/// Set by the integrator on `AdRequest` to forward reward metadata to the ad network.
public struct Reward: Equatable, Codable, Sendable {
    /// The reward category label (e.g. "coins", "lives").
    public let type: String
    /// The quantity of reward units.
    public let amount: Int

    public init(type: String, amount: Int)
}
```

---

### `RewardedAd`
```swift
/// Represents a loaded rewarded ad, ready to be presented full-screen.
///
/// Create via `MSPAdLoader` using `AdFormat.rewarded`. Do not instantiate directly.
/// Each instance may be shown at most once. Showing the same instance twice is undefined behavior.
open class RewardedAd: MSPAd {

    /// The reward associated with this ad, as provided by the request or ad network.
    public let reward: Reward

    /// Presents the rewarded ad full-screen.
    /// - Parameter rootViewController: The view controller from which to present.
    ///   Pass `nil` to use the key window's root view controller.
    /// - Important: Must be called from the main thread.
    /// - Important: Must only be called in response to a deliberate user action (opt-in).
    open func show(rootViewController: UIViewController?)

    /// Dismisses the ad programmatically.
    /// - Parameter animated: Whether to animate the dismissal.
    open func dismiss(animated: Bool)
}
```

---

### `AdFormat.rewarded` (extension to existing enum)
```swift
public enum AdFormat: CaseIterable {
    case banner
    case native
    case multi_format
    case interstitial
    case rewarded      // NEW
}
```

---

## Modified Symbols

### `AdRequest` — new optional property
```swift
public final class AdRequest {
    // ... existing properties ...

    /// Optional reward configuration forwarded to the ad network at request time.
    /// When `nil`, no reward parameters are sent; the network uses its server-side defaults.
    /// Rewarded in this feature is scoped to MSP server-side bidding flows.
    public var reward: Reward?
}
```

---

### `AdListener` — new method with default implementation
```swift
public protocol AdListener: AnyObject {
    // ... existing methods (unchanged) ...

    /// Called when the user has satisfied the reward condition for a rewarded ad.
    /// Guaranteed to be called at most once per ad presentation.
    /// Guaranteed to be called before `onAdDismissed` when the reward is earned.
    ///
    /// - Parameter ad: The rewarded ad for which the reward was earned.
    ///   Cast to `RewardedAd` if reward-specific properties are needed.
    func onAdRewardReceived(ad: MSPAd)
}

public extension AdListener {
    /// Default empty implementation — existing adopters require no changes.
    func onAdRewardReceived(ad: MSPAd) {}
}
```

---

## Usage Example

```swift
// 1. Build request
let request = AdRequest(
    customParams: [:],
    geo: nil,
    context: nil,
    adaptiveBannerSize: nil,
    adSize: nil,
    placementId: "my-rewarded-placement",
    adFormat: .rewarded
)
request.reward = Reward(type: "coins", amount: 10) // optional

// 2. Load
adLoader.loadAd(adRequest: request)

// 3. Implement AdListener
func onAdLoaded(placementId: String, loadInfo: [String: Any]) {
    if let rewardedAd = adLoader.getAd(placementId: placementId) as? RewardedAd {
        rewardedAd.show(rootViewController: self)
    }
}

func onAdRewardReceived(ad: MSPAd) {
    // Grant in-app reward to user
    grantReward()
}
```

---

## Constraints & Guarantees

| Guarantee | Scope |
|-----------|-------|
| `onAdRewardReceived` fires at most once per `RewardedAd` instance | Always |
| `onAdRewardReceived` fires before `onAdDismissed` | Google + Facebook rewarded S2S flows |
| Dismiss without reward = no `onAdRewardReceived` | Always |
| Existing `AdListener` adopters compile without changes | Always |
| `AdFormat.allCases` gains `.rewarded` | Always — update any code iterating `allCases` |

---

## Breaking Change Assessment

| Symbol | Change Type | Breaking? |
|--------|-------------|-----------|
| `AdFormat.rewarded` | New enum case | ⚠️ Yes for exhaustive `switch` without `default` |
| `AdRequest.reward` | New optional property | No |
| `AdListener.onAdRewardReceived` | New method + default impl | No |
| `RewardedAd` | New class | No |
| `Reward` | New struct | No |

**Migration note**: Any `switch adFormat` statement without a `default:` clause must add a `.rewarded` branch. Use Xcode's exhaustiveness warning to find all affected sites.

## Delivery Mode

Rewarded ads are currently supported through MSP server-side bidding flows only.
No client-side bidding contract is defined for rewarded ads in this API surface.

## Network Support Scope

### v1 Server-Enabled (code + server config)
- Google AdMob
- Facebook Audience Network

### Code-Ready, Rollout-Gated (implemented but not enabled in v1)
- Liftoff / Vungle (`VungleRewarded`)
- Moloco (`MolocoRewardedInterstitial`)
- Mintegral (`MTGRewardAdManager`)
- MobileFuse (`MFRewardedAd`)
- PubMatic OpenWrap (`POBRewardedAd`)
- InMobi (`IMInterstitial` — shared class, server determines reward eligibility)
- LevelPlay / IronSource (`LPMRewardedAd`)

### Deferred
- Amazon APS — direct iOS rewarded API evidence is weaker; keep an explicit unsupported `.rewarded` branch until confirmed

### Gating Architecture
Rewarded rollout is currently gated by a client-side policy in `MSPAdLoader`, while adapter routing stays on the existing `loadAdCreative` path:
1. **Current gate**: client-side rollout policy — only `google` and `facebook` participate in rewarded auctions
2. **Future gate**: MSP server placement config can replace the policy input without changing adapter routing
3. **Adapter handling**: each adapter handles `.rewarded` inside its own `loadAdCreative`; unsupported adapters return an explicit error from that branch

Enabling a new adapter for rewarded currently = client rollout policy change. After backend support lands, the same gate will be driven by server config instead.

### Google SDK vs Moloco Adapter

Integrating `MSPGoogleAdapter` only enables the Google Mobile Ads path. It does **not** automatically enable Moloco demand.

If a product chooses Google mediation for Moloco inventory, that requires a separate Google mediation integration plus Moloco's own SDK/adapter. That path is distinct from this repository's standalone `MSPMolocoAdapter`, which remains the direct MSP bidder integration for Moloco placements.
