# Research: Nova Rewarded Ad

**Date**: 2026-03-26
**Branch**: `001-nova-rewarded-ad`

## R1: NovaInterstitialAdItem Refactoring Scope

**Decision**: Extract shared properties to `NovaFullScreenAdItem` base class; both `NovaInterstitialAdItem` and `NovaRewardedAdItem` inherit from it.

**Rationale**: `NovaInterstitialAdItem` inherits `NovaNativeBaseAd → NovaBaseAd`. Most properties (ad metadata, tracking URLs, creative type, media content) are generic. Only a few are interstitial-specific (`startTimeInMs`, `expirationTimeInMs`, `closeCountDownTimeSeconds`, `clickableComponents`, `layoutStyle`).

**What stays in NovaInterstitialAdItem** (not extracted):
- `startTimeInMs`, `expirationTimeInMs` — interstitial/app-open timing
- `closeCountDownTimeSeconds` — interstitial skip countdown
- `clickableComponents` — interstitial-specific interactive areas
- `layoutStyle: NovaInterstitialAdLayout` — interstitial layout variants (horizontal/vertical/sponsor)

**What goes into NovaFullScreenAdItem** (shared):
- All `NovaNativeBaseAd` inherited properties (ad metadata, creative, tracking, media)
- `shouldPreloadHtml`, `cachedHtmlView` — HTML preloading (both formats use H5)
- `present()` / `dismiss()` — shared presentation logic
- `preloadHtmlView()` — shared preload method

**Alternatives considered**:
- Protocol-only (no base class): Rejected — too much code duplication since `NovaNativeBaseAd` has extensive shared state.
- Refactor `NovaNativeBaseAd` itself: Rejected — too large a blast radius, affects native ads too.

## R2: ViewController Extraction Strategy

**Decision**: Extract `NovaFullScreenAdViewController` base class. Interstitial and rewarded subclass it.

**Rationale**: The current `NovaInterstitialAdViewController` has ~330 lines mixing:
- Generic full-screen logic (view setup, impression logging, ad view lifecycle, status bar)
- iPad H5 orientation locking (3 iOS version branches — iOS 15, 16-25, 26+)
- Interstitial-specific behavior (`handleApplicationWillEnterForeground` auto-dismiss)

**What goes into base VC**:
- `viewDidLoad()` → view setup, background color
- `viewDidAppear()` → impression logging via `NovaAdMetricReporter`
- Ad view lifecycle calls (`willAppear/didAppear/willDisappear/didDisappear`)
- Status bar hiding for HTML creative
- iPad H5 orientation locking (shared — both formats need it)
- `setupSubviews()` using factory pattern

**What stays in interstitial subclass**:
- `handleApplicationWillEnterForeground` → auto-dismiss on background return
- Interstitial-specific delegate callbacks

**What goes in rewarded subclass**:
- NO auto-dismiss on foreground (rewarded preserves progress)
- Reward-earned delegate forwarding
- Future: rewarded-specific dismiss confirmation UX

**Gotcha**: Orientation locking code references `interstitialAd.creativeType`. The base VC needs a generic way to access creative type from the ad item. Solution: `NovaFullScreenAdPresenting` protocol provides `creativeType` property.

## R3: Delegate Protocol Design

**Decision**: Keep `NovaInterstitialAdDelegate` and `NovaRewardedAdDelegate` as independent `: AnyObject` protocols with format-specific method names.

**Rationale**: A shared full-screen delegate would reduce repetition, but it would either rename existing interstitial callbacks or introduce a second callback vocabulary. Keeping independent protocols preserves interstitial compatibility and makes rewarded-specific callbacks explicit.

**Design**:
```
NovaInterstitialAdDelegate
  - interstitialAdDidDisplay(_:)
  - interstitialAdDidDismiss(_:)
  - interstitialAdDidLogClick(_:)
  - interstitialAdDidFailToDisplay(_:)

NovaRewardedAdDelegate
  - rewardedAdDidDisplay(_:)
  - rewardedAdDidDismiss(_:)
  - rewardedAdDidLogClick(_:)
  - rewardedAdDidEarnReward(_:)
```

**Alternatives considered**:
- Shared `NovaFullScreenAdDelegate`: Rejected — it would blur format-specific naming and increase source-compatibility risk for interstitial.
- Single protocol with optional methods: Rejected — Swift protocols don't support optional without `@objc`.
- Skip Nova-layer delegate, route directly through `AdListener`: Rejected — breaks the NovaCore/NovaAdapter layering.

## R4: JSBridge `onAdRewarded` Integration

**Decision**: Always inject `onAdRewarded` function in `NovaAdHtmlView.injectNovaNativeBridge()`. Handle action in existing `novaNativeBridge` message switch.

**Rationale**: `NovaAdHtmlView` already injects `novaNativeBridge` object with `supports()`, `startFeedback()`, `open()`, `sendNativeAction()`. Adding `onAdRewarded()` is one more function in the same JS object.

**Implementation**:
1. Add to JS injection in `injectNovaNativeBridge()`:
   ```javascript
   onAdRewarded: function() {
       window.webkit.messageHandlers.novaNativeBridge.postMessage({ action: 'onAdRewarded' });
   }
   ```
2. Handle in `userContentController(_:didReceive:)` → `novaNativeBridge` case:
   ```swift
   case "onAdRewarded":
       htmlActionDelegate?.didEarnReward()
   ```
3. Add `didEarnReward()` to `NovaAdHtmlActionDelegate` protocol.

**No new `NovaAdHtmlJSMessage` enum case needed** — it uses the existing `novaNativeBridge` message handler.

## R5: RewardedAd.reward Optional Migration

**Decision**: Change `RewardedAd.reward` from `Reward` to `Reward?`. Clean up adapter fallbacks.

**Rationale**: Research of existing adapters shows inconsistent fallback behavior:
- Google: `Reward(type: "", amount: 0)`
- Facebook: `Reward(type: "", amount: 0)`
- Liftoff: `Reward(type: "reward", amount: 1)`
- Moloco: `Reward(type: "reward", amount: 1)`

None of these SDKs guarantee reward metadata. The current design forces adapters to fabricate dummy values.

**Migration scope**:
- `RewardedAd.swift`: `let reward: Reward` → `let reward: Reward?`, init parameter optional
- `RewardedLifecycleController.markRewardEarned()`: Handle nil reward in log message
- Each adapter's rewarded ad class: Remove hardcoded fallback, pass `adRequest?.reward` directly
- Affected adapters: Google, Facebook, Liftoff, Moloco, Mintegral, Mobilefuse, Inmobi, Pubmatic

**Alternatives considered**:
- Keep non-optional with sentinel value: Rejected — caller cannot distinguish "no reward info" from "reward is 0 coins".
- Only make optional in Nova: Rejected — the problem exists across all adapters.

## R6: NovaAdBuilder Extension

**Decision**: Add `buildRewardedAds()` method to `NovaAdBuilder`, mirroring `buildInterstitialAds()`.

**Rationale**: `AdRequest.reward` already exists as `Reward?`. The builder takes `[AdItem]` from the JSON response and produces ad items. Rewarded ads use HTML creative type, same parsing path as interstitial HTML.

**Key differences from `buildInterstitialAds()`**:
- Does NOT set `closeCountDownTimeSeconds`, `clickableComponents`, `startTimeInMs`, `expirationTimeInMs`
- Sets `shouldPreloadHtml` based on response config
- Creates `NovaRewardedAdItem` instead of `NovaInterstitialAdItem`

**Recall eligibility (Phase 1)**: Per the MON Tech Design, the Ad Server hard-filters to `type == VIDEO && video_length_sec >= 10` (null `video_length_sec` rejected). `PLAYABLE_VIDEO` is explicitly out of scope for Phase 1 and is rejected by the same filter. This eligibility is owned entirely by ad serving/creative selection. The iOS SDK must only treat renderable H5 rewarded-video responses as load success; missing or unsupported rewarded items are load failures.

## R7: PRD Request, Placement, and Event Contract

**Decision**: Treat `placement` and `ad_format` as **two distinct Nova ad request fields** (per Clarifications session 2026-04-29):
- `placement`: publisher-configured placementId, forwarded verbatim by SDK (e.g. `nova-ios-reward-fullscreen-prod-ob`). SDK does not synthesize, validate, or transform it.
- `ad_format`: enum value `rewarded_video`, set by the SDK whenever `AdRequest.adFormat == .rewarded`.

These two fields may share the same string in some publisher configurations but are not interchangeable in the request schema.

**Rationale**: The updated PRD lists both `placement = 'rewarded_video'` and "ad format = rewarded_video" as separate items. Earlier spec wording conflated them as a single "placement/ad format" string, which obscures which field the SDK actually controls.

**SDK responsibility**:
- Forward publisher-supplied placementId verbatim into Nova request `placement` (FR-017a).
- Set Nova request `ad_format = rewarded_video` when `AdRequest.adFormat == .rewarded` (FR-017b).
- Emit SDK-side MES events (`ad_impression`, `ad_click`) via `RewardedLifecycleController` with the same dedup guarantees as other rewarded adapters. The reward signal itself is not a MES event — it lives on the Nova `logAdEvent` channel (`AD_EVENT_REWARDED`), see FR-023.
- Preserve existing click metadata (click area, click position) on the SDK-side click event, sourced from the H5 click JSBridge.

**Non-SDK responsibility (per Clarifications session 2026-04-29)**:
- MSP server experiment setup.
- Serving-side recall eligibility (Phase 1: `type == VIDEO && video_length_sec >= 10`; `PLAYABLE_VIDEO` deferred and hard-filtered).
- H5 countdown, skip/end-card/playable, close-button UI, and playback flags (`is_mute = false`, `is_loop = false`, `is_auto_play = true`).
- **All H5-side event reporting**: SKIP / `skip_type` / Get Rewards / Close button success / in-H5 video lifecycle events. The H5 page beacons these directly to Nova's event endpoint. SDK does not relay, transform, or dedup them.
- **Native video quartile events**: the player runs entirely inside the H5 (HTML5 `<video>`); SDK has no native handle.
