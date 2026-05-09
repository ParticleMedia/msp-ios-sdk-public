# JSBridge Contract: Nova Rewarded Ad

**Date**: 2026-03-26
**Owner**: SDK team (native side) + H5 team (@Tingchao Xu)

## Overview

The H5 page communicates with the native SDK via `window.novaNativeBridge`, a JavaScript object injected by the SDK into the WKWebView at document start.

## Existing Interface (unchanged)

```javascript
window.novaNativeBridge = {
    // Feature detection
    supports: function(feature) → Boolean,

    // Report/feedback flow
    startFeedback: function() → void,

    // Open URL / CTA click
    open: function(payload: string) → void,
    // payload JSON: { "url": "https://...", "click_area_name": "cta_button" }

    // Generic native action dispatch
    sendNativeAction: function(paramsString: string) → void,

    // Get ad context (Promise-based)
    getAdContext: function() → Promise<string>
}
```

## New Interface

### `novaNativeBridge.onAdRewarded()`

**Direction**: H5 → Native

**Purpose**: Notify the native SDK that the user has completed the PRD reward condition.

**Signature**:
```javascript
window.novaNativeBridge.onAdRewarded() → void
```

**Parameters**: None.

**Behavior**:
- H5 calls this when the reward condition is met. Per the PRD, the baseline reward condition is countdown completion where `countdown = min(video_length, 30s)`.
- Native receives the message via `WKScriptMessageHandler` on the `novaNativeBridge` message handler.
- Native parses `action: "onAdRewarded"` from the message body.
- Native invokes `NovaAdHtmlActionDelegate.didEarnReward()`.
- The call is **idempotent**: multiple invocations result in the reward callback firing only once (enforced by `RewardedLifecycleController`).

**When to call**:
- After the rewarded-video countdown completes: `min(video_length, 30s)`.
- If H5 defines a stricter reward-earned condition, only after that condition is satisfied.

**When NOT to call**:
- Before the reward condition is met.
- After the ad is already closed/dismissed.

## PRD H5 Playback/UI Ownership

The SDK only provides the full-screen WebView container and reward bridge. H5 owns the PRD rewarded-video behavior:

- `is_mute = false`
- `is_loop = false`
- `is_auto_play = true`
- If the video completes, automatically show the end card/playable and close button.
- If the video does not complete, show the skip button after the countdown disappears.
- When the skip button is clicked, show the end card/playable and close button.
- Emit existing Nova video/click/skip/get-reward/close events through the established H5 event/reporting path.

## Message Wire Format

All `novaNativeBridge` messages use the same wire format:

```javascript
window.webkit.messageHandlers.novaNativeBridge.postMessage({
    action: 'onAdRewarded'
    // No payload needed
});
```

Native handler receives `WKScriptMessage` with:
- `message.name` = `"novaNativeBridge"`
- `message.body` = `{ "action": "onAdRewarded" }` (Dictionary<String, Any>)

## Injection

The `onAdRewarded` function is injected into **all** `NovaAdHtmlView` instances, regardless of ad format. If the H5 page does not call it, there is no side effect. This simplifies `NovaAdHtmlView` by removing the need to know its ad format context.

## Error Handling

| Scenario | Behavior |
|----------|----------|
| H5 calls `onAdRewarded()` once | Reward callback fires once |
| H5 calls `onAdRewarded()` multiple times | Only first call triggers reward; subsequent calls are no-ops |
| H5 calls `onAdRewarded()` after ad dismissed | Call is silently dropped |
| `onAdRewarded` function not available (older SDK) | JavaScript error; H5 should guard with `typeof` check |

## H5 Integration Example

```javascript
// After countdown completes
if (window.novaNativeBridge && typeof window.novaNativeBridge.onAdRewarded === 'function') {
    window.novaNativeBridge.onAdRewarded();
}
```
