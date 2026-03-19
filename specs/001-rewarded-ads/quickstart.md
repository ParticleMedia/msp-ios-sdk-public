# Quickstart: Rewarded Ads Integration

**Branch**: `001-rewarded-ads` | **Date**: 2026-03-11
**Audience**: SDK integrators (app developers)

---

## Prerequisites

- MSP iOS SDK initialized
- Rewarded placement ID configured in the MSP dashboard with at least one supported network (currently Google AdMob or Facebook AAN in this repository)
- Your view controller conforms to `AdListener`

---

## Step 1: Request a Rewarded Ad

```swift
let request = AdRequest(
    customParams: [:],
    geo: nil,
    context: nil,
    adaptiveBannerSize: nil,
    adSize: nil,
    placementId: "YOUR_REWARDED_PLACEMENT_ID",
    adFormat: .rewarded
)

// Optional: forward reward config to the ad network's server-side rewarded flow
request.reward = Reward(type: "coins", amount: 10)

adLoader.loadAd(adRequest: request)
```

---

## Step 2: Implement AdListener

```swift
extension YourViewController: AdListener {

    func onAdLoaded(placementId: String, loadInfo: [String: Any]) {
        // Ad is ready — show when user taps your reward button
        showRewardButton()
    }

    func onError(msg: String, loadInfo: [String: Any]) {
        // No fill or network error — hide reward button
        hideRewardButton()
    }

    func onAdRewardReceived(ad: MSPAd) {
        // ✅ User earned the reward — grant it now
        grantRewardToUser()
    }

    func onAdDismissed(ad: InterstitialAd) {
        // Ad closed — preload next if needed
    }

    func getRootViewController() -> UIViewController? { self }
}
```

---

## Step 3: Show the Ad (opt-in only)

```swift
// Called when user deliberately taps "Watch Ad for Reward"
@IBAction func watchAdButtonTapped(_ sender: Any) {
    guard let rewardedAd = adLoader.getAd(placementId: "YOUR_REWARDED_PLACEMENT_ID") as? RewardedAd else {
        return // Ad not ready yet
    }
    rewardedAd.show(rootViewController: self)
}
```

> **Important**: Only call `show()` in direct response to a user action. Rewarded ads must always be opt-in per Google and Facebook policies.

---

## Callback Order Guarantee

For Google (own ads) and Facebook, the callback order is:

```
1. onAdImpression      ← ad displayed
2. onAdRewardReceived  ← user earned reward (if conditions met)
3. onAdDismissed       ← ad closed
```

If the user closes early (before reward condition met):

```
1. onAdImpression
2. onAdDismissed       ← no reward callback
```

---

## Ad Expiry (Google)

Google rewarded ads expire approximately **1 hour** after loading. If your user doesn't trigger the ad within that window, the ad will fail to present. Best practice: preload fresh ads before each session where rewarded ads are offered.

---

## Facebook End Card

Facebook rewarded video ads show an **end card** after the video completes. The reward callback fires before the end card appears; the dismiss callback fires after the end card is dismissed. This means there may be a short delay between `onAdRewardReceived` and `onAdDismissed`.

---

## Current Network Coverage

### v1 Server-Enabled
- Google AdMob
- Facebook Audience Network

### Code-Ready, Server-Gated (not enabled in v1)
- Liftoff / Vungle
- Moloco
- Mintegral
- MobileFuse
- PubMatic OpenWrap
- InMobi
- LevelPlay / IronSource (via Unity adapter)

### Deferred
- Amazon APS (pending API confirmation)

> **Note**: In the current phase, rewarded rollout is controlled by a client-side gate and only Google / Facebook are enabled. Once backend support is ready, the gate can switch to server-driven config without changing adapter routing.
