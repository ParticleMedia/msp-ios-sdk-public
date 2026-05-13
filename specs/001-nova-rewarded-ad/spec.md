# Feature Specification: Nova Rewarded Ad

**Feature Branch**: `001-nova-rewarded-ad`
**Created**: 2026-03-26
**Status**: Draft
**Input**: Nova Rewarded Video Ad support — H5 rewarded-video creative rendering with JSBridge reward notification, `rewarded_video` Nova request/log placement, and reusable full-screen ad infrastructure.

## Clarifications

### Session 2026-03-26

- Q: Rewarded 广告的 ViewController 策略？复用 interstitial VC / 提取共享基类各自子类化 / 完全独立 VC？ → A: 提取共享基类 `NovaFullScreenAdViewController`，interstitial 和 rewarded 各自子类化（选项 B）。备注：现有 interstitial 的 `willEnterForeground` 自动 dismiss 行为有问题，但本次不改。
- Q: `onAdRewarded` JS 注入范围？仅 rewarded 上下文注入 / 所有 NovaAdHtmlView 统一注入？ → A: 始终注入（选项 A）。`NovaAdHtmlView` 不感知广告类型，H5 不调用则无副作用。
- Q: Reward 默认值策略及是否 optional？ → A: 将 `RewardedAd.reward` 改为 `Reward?`（optional）。从 bid response 解析，缺失则为 nil。现有 adapter 的 hardcoded fallback 一并清理为 optional。原因：Google/Facebook 等 SDK 均不保证返回 reward 元数据，当前各 adapter 用不一致的 fallback 硬编码兜底，本质上就是 optional 语义。

### Session 2026-04-29

- Q: PRD 列了 SKIP / Get Rewards / Close button 事件，谁来 emit、谁来上报？ → A: SDK 只提供容器和 `onAdRewarded` JSBridge；其他事件（skip/skip_type、get-rewards、close、video events）由 H5 自己生成并 beacon 到 Nova event endpoint，SDK 不参与转报。
- Q: 视频播放器位置？ → A: 视频播放器**完全在 H5 内**（HTML5 `<video>`），native 不感知播放进度。所谓"video event same as Nova video ads"指的是 H5 自报到 Nova，不是 SDK 转报。
- Q: PRD 同时出现 `placement = rewarded_video` 和 `ad_format = rewarded_video`，是同一个字段还是两个？ → A: 是 Nova ad request 上的两个独立字段：`placement` 是 publisher 配的 placementId 名（例如 `nova-ios-reward-fullscreen-prod-ob`），`ad_format` 是请求里的 enum 值（值为 `rewarded_video`）。SDK 只负责把 publisher 传入的 placementId 透传到请求，并保证 `ad_format = rewarded_video` 这个 enum 走通。
- Q: PRD 提到 IAB/GDPR/CCPA/COPPA compliance + latency optimization，spec 是否需要新增 user story？ → A: 不需要。Rewarded 复用现有 SDK consent / privacy 链路，无 rewarded 专属 compliance 工作；latency 通过 SC-004（与 interstitial H5 无回退）和 P3 preload（US5）覆盖。

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Publisher Loads and Shows a Nova Rewarded Ad (Priority: P1)

A publisher app requests a rewarded ad from MSP SDK. The SDK marks the request with `ad_format = rewarded_video` (FR-017b) and forwards the publisher-supplied placementId verbatim (FR-017a); Ad Server rewarded routing is keyed off `ctx.placementName == REWARDED_VIDEO`, which is derived server-side from the SSP `ad_unit → REWARDED_VIDEO` mapping (FR-017c). When the request resolves, the SDK loads an eligible Nova H5 rewarded-video creative, presents it full-screen, and notifies the publisher when the user earns the reward (for example, when the H5 countdown reaches the server-supplied `rewardedVideoCountdownSec` ceiling, or when the underlying video finishes early and the template auto-transitions to the end card).

**Why this priority**: This is the core end-to-end flow. Without it, there is no rewarded ad product.

**Independent Test**: Load a Nova rewarded ad with an eligible H5 rewarded-video creative, present it, wait for the H5 page to fire `novaNativeBridge.onAdRewarded()`, verify the publisher's `AdListener.onAdRewardReceived(ad:)` callback fires exactly once with the associated optional `Reward` metadata.

**Acceptance Scenarios**:

1. **Given** a valid Nova rewarded-video response for a request with `ad_format = rewarded_video` and an eligible H5 creative, **When** the SDK loads the ad, **Then** a `RewardedAd` instance is returned to the publisher via `onAdLoaded`.
2. **Given** a loaded Nova rewarded ad, **When** the publisher calls `show(rootViewController:)`, **Then** a full-screen view controller presents the H5 content.
3. **Given** the H5 page fires `novaNativeBridge.onAdRewarded()`, **When** the SDK receives this JSBridge message, **Then** `AdListener.onAdRewardReceived(ad:)` is called exactly once with the associated optional `Reward`.
4. **Given** a displayed rewarded ad, **When** the user dismisses the ad after earning the reward, **Then** `AdListener.onAdDismissed(ad:)` fires after the reward callback.

---

### User Story 2 - Full-Screen Ad Abstraction (Priority: P1)

The SDK introduces a shared abstraction layer for full-screen ads (interstitial and rewarded) so that common presentation logic (present, dismiss, orientation handling, H5 rendering) is defined once, while each format retains its own lifecycle and delegate.

**Why this priority**: This is a prerequisite for User Story 1. The rewarded ad must be built on a clean abstraction rather than being shoehorned into the interstitial class hierarchy.

**Independent Test**: After refactoring, existing interstitial ad functionality (load, show, dismiss, delegate callbacks) works identically to before. New `NovaRewardedAdItem` can be instantiated and presented using the same shared protocol.

**Acceptance Scenarios**:

1. **Given** the new `NovaFullScreenAdItem` base class and `NovaFullScreenAdViewController` base VC, **When** `NovaInterstitialAdItem` is refactored to inherit from the base class, **Then** all existing interstitial tests and behavior remain unchanged.
2. **Given** `NovaRewardedAdItem` inherits from `NovaFullScreenAdItem`, **When** it is presented, **Then** it uses the shared full-screen presentation and H5 rendering infrastructure via `NovaRewardedAdViewController`.
3. **Given** `NovaInterstitialAdDelegate` and `NovaRewardedAdDelegate` are independent protocols (`: AnyObject`), **When** interstitial and rewarded ads fire lifecycle events, **Then** each format's delegate methods use format-specific names (e.g., `rewardedAdDidDisplay`, `interstitialAdDidDisplay`).

---

### User Story 3 - H5 JSBridge Reward Notification (Priority: P1)

The H5 page (owned by the H5 team) needs a JavaScript interface to notify the native SDK that the user has completed the reward condition. The SDK must inject the `novaNativeBridge.onAdRewarded()` function into the WebView and handle the resulting message.

**Why this priority**: This is the only new JSBridge interface required. Without it, the SDK cannot know when the user has earned the reward.

**Independent Test**: Load an H5 page that calls `novaNativeBridge.onAdRewarded()`, verify the native `WKScriptMessageHandler` receives the message and forwards it through the delegate chain.

**Acceptance Scenarios**:

1. **Given** a `NovaAdHtmlView` used in rewarded context, **When** the H5 page is loaded, **Then** `window.novaNativeBridge.onAdRewarded` is available as a callable function.
2. **Given** the H5 page calls `novaNativeBridge.onAdRewarded()`, **When** the message reaches native, **Then** `NovaAdHtmlActionDelegate.didEarnReward()` is invoked.
3. **Given** the H5 page calls `novaNativeBridge.onAdRewarded()` multiple times, **When** the SDK processes the messages, **Then** only the first invocation triggers the reward callback (idempotent, enforced by `RewardedLifecycleController`).

---

### User Story 4 - Event Reporting (Priority: P2)

Nova rewarded ads must surface the rewarded-video ad format in the Nova bid request and SDK-side MES events, and fire standard SDK ad events (impression, click, reward, dismiss). PRD-listed H5-side events (`skip_type`, get-rewards, close-button success, in-H5 video events) are NOT in the SDK's scope — they are emitted directly by the H5 page to Nova's event endpoint (per Clarifications session 2026-04-29).

**Why this priority**: Reporting is essential for monetization analytics but does not block the core ad experience.

**Independent Test**: Present a rewarded ad, interact with it, verify that the SDK's outbound Nova bid request carries `ad_format = rewarded_video`, that SDK-emitted MES events (`ad_impression`, `ad_click`) fire exactly once each with the correct ad context, and that the Nova event `AD_EVENT_REWARDED` on the Nova `logAdEvent` endpoint fires exactly once on the JSBridge trigger. Verify the SDK does NOT emit a MES `ad_rewarded` event (the reward signal is Nova-event-only) and does NOT emit MES events for skip / get-rewards / close-button or in-H5 video events.

**Acceptance Scenarios**:

1. **Given** a Nova rewarded ad request, **When** the request is built, **Then** the request `ad_format` field is set to the enum value `rewarded_video`, and the `placement` field carries the publisher-supplied placementId verbatim.
2. **Given** a rewarded ad is displayed, **When** an impression occurs, **Then** the SDK fires `ad_impression` MES via `RewardedLifecycleController.markDisplayed()` exactly once.
3. **Given** the user clicks the ad, **When** the click is reported, **Then** the SDK fires `ad_click` MES via `RewardedLifecycleController.markClicked()` exactly once with click metadata (click area, click position) supplied by the H5 click bridge.
4. **Given** the H5 page fires `novaNativeBridge.onAdRewarded()`, **When** the SDK processes it, **Then** the SDK fires the Nova event `AD_EVENT_REWARDED` via `NovaAdMetricReporter.logAdRewarded(...)` exactly once with `duration_ms` populated, and `RewardedLifecycleController.markRewardEarned()` forwards `AdListener.onAdRewardReceived(ad:)` exactly once. There is no corresponding MES `ad_rewarded` event — the reward signal lives only on the Nova `logAdEvent` channel.
5. **Given** the user closes the ad after earning the reward, **When** dismiss fires, **Then** `AdListener.onAdDismissed(ad:)` is called after `onAdRewardReceived`.
6. **Given** the user closes the ad without earning the reward, **When** dismiss fires, **Then** `AdListener.onAdDismissed(ad:)` is called and `onAdRewardReceived` is never called.
7. **Given** the H5 page fires SKIP / Get Rewards / Close button taps or in-H5 video lifecycle events, **When** these events occur, **Then** the SDK does NOT fire corresponding MES events — the H5 beacons them directly to Nova per the H5 contract.

---

### User Story 6 - PRD Rewarded Video H5 Contract (Priority: P2)

The H5 page owns the rewarded-video playback UX and must be able to run inside the SDK full-screen WebView without native SDK countdown, skip, or end-card UI.

**Why this priority**: The PRD assigns countdown, skip button, end card/playable transition, close button, and playback flags to H5. The SDK must provide the container and reward bridge without duplicating that UI logic natively.

**Independent Test**: Load a PRD-compliant H5 rewarded video creative and verify the SDK renders it full-screen, leaves H5 playback/UI behavior intact, and receives `onAdRewarded()` after the H5 reward condition is met.

**Acceptance Scenarios**:

1. **Given** a rewarded video and the server-supplied `rewardedVideoCountdownSec` (AB key `h5_reward_countdown_second`, default 30, independent of video length), **When** H5 starts playback, **Then** H5 applies that countdown ceiling and calls `onAdRewarded()` once the countdown finishes (or earlier if the template auto-transitions to the end card on video completion).
2. **Given** the video completes before the user closes, **When** completion occurs, **Then** H5 auto-shows the end card/playable and close button without native SDK UI intervention.
3. **Given** the video does not complete, **When** the countdown disappears, **Then** H5 shows the skip button; clicking skip shows the end card/playable and close button.
4. **Given** a rewarded video creative, **When** it is rendered, **Then** H5 uses `is_mute = false`, `is_loop = false`, and `is_auto_play = true`.

---

### User Story 5 - H5 Content Preloading (Priority: P3)

To minimize latency when showing a rewarded ad, the SDK should support preloading the H5 content so it is ready to display immediately when `show()` is called.

**Why this priority**: This is a UX optimization. The core flow works without preloading (the H5 page loads on show), but preloading provides a smoother experience.

**Independent Test**: Load a rewarded ad with `shouldPreloadHtml = true`, call `show()`, verify the H5 page renders immediately without a loading delay.

**Acceptance Scenarios**:

1. **Given** a Nova rewarded ad with `shouldPreloadHtml = true`, **When** the ad is loaded, **Then** the H5 WebView content is preloaded before `onAdLoaded` fires.
2. **Given** a preloaded rewarded ad, **When** `show()` is called, **Then** the H5 content appears without visible loading time.

---

### Edge Cases

- What happens when the H5 page never fires `onAdRewarded()` (e.g., user closes early)? The SDK fires `onAdDismissed` without `onAdRewardReceived`. The publisher decides how to handle this.
- What happens when the H5 page fires `onAdRewarded()` after the ad is already dismissed? The callback is dropped (the `RewardedAd` and its lifecycle controller are already released or in dismissed state).
- What happens when the WebView process terminates mid-ad? The SDK dismisses the ad and fires `onAdDismissed` without reward.
- What happens when `show()` is called but the ad has expired or been invalidated? `show()` has no effect; the publisher should check `isValid()` before calling.
- What happens when the H5 preload fails? The SDK still calls `onAdLoaded` (matching current interstitial behavior), and the H5 content loads when `show()` is called.
- What happens when Nova serving returns a rewarded response without an eligible H5 rewarded-video creative? The SDK must fail the load rather than returning a `RewardedAd` that cannot be shown or rewarded.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: SDK MUST support `AdFormat.rewarded` for Nova ads, in addition to existing `native` and `interstitial` formats.
- **FR-002**: ~~REMOVED~~ — `NovaFullScreenAdPresenting` protocol deemed unnecessary; base class `NovaFullScreenAdItem` provides the shared interface directly.
- **FR-003**: SDK MUST introduce a `NovaFullScreenAdItem` base class (extracted from current `NovaInterstitialAdItem` shared logic) that both `NovaInterstitialAdItem` and `NovaRewardedAdItem` inherit from.
- **FR-004**: `NovaInterstitialAdDelegate` and `NovaRewardedAdDelegate` MUST be independent protocols (`: AnyObject`) with format-specific named methods. No shared `NovaFullScreenAdDelegate` hierarchy — each format owns its own delegate naming (e.g., `rewardedAdDidDisplay`, `interstitialAdDidDisplay`).
- **FR-005**: SDK MUST create `NovaRewardedAdItem` (in NovaCore) that inherits from `NovaFullScreenAdItem` and manages reward state.
- **FR-006**: SDK MUST create `NovaRewardedAd` (in NovaAdapter) that inherits from `MSPiOSCore.RewardedAd` and wraps `NovaRewardedAdItem`.
- **FR-007**: SDK MUST inject `novaNativeBridge.onAdRewarded()` JavaScript function into all `NovaAdHtmlView` instances（不区分广告类型，始终注入）。`NovaAdHtmlView` 无需感知是否处于 rewarded 上下文。
- **FR-008**: SDK MUST handle the `onAdRewarded` JSBridge action by invoking `NovaAdHtmlActionDelegate.didEarnReward()`.
- **FR-009**: SDK MUST add a `didEarnReward()` method to `NovaAdHtmlActionDelegate`.
- **FR-010**: SDK MUST route the reward signal through `RewardedLifecycleController.markRewardEarned()` to ensure idempotent, at-most-once delivery to `AdListener.onAdRewardReceived(ad:)`.
- **FR-011**: `NovaAdapter` MUST handle `adFormat == .rewarded` in `loadAdCreative` and `parseNovaAdString`, routing to the new rewarded ad construction path.
- **FR-012**: `NovaAdapter` MUST hold a `rewardedAdItem` property alongside existing `nativeAdItem` and `interstitialAdItem`.
- **FR-013**: SDK MUST ensure existing interstitial ad functionality is unchanged after the refactoring (backward compatible).
- **FR-014**: SDK MUST report ad format as `rewarded_video` in SDK-emitted Nova request metadata and MES events. (Split into FR-017a / FR-017b for clarity.)
- **FR-015**: SDK MUST extract a shared `NovaFullScreenAdViewController` base class from current `NovaInterstitialAdViewController`, with interstitial and rewarded each subclassing it. Each subclass controls its own dismiss policy (e.g., rewarded MUST NOT auto-dismiss on `willEnterForeground`).
- **FR-016**: `RewardedAd.reward` MUST be changed from `Reward` to `Reward?`（optional）。从 bid response 解析，缺失则为 nil。现有各 adapter（Google、Facebook、Liftoff、Moloco 等）的 hardcoded fallback 一并清理为 optional 传递。
- **FR-017a (request placement — SDK passthrough)**: SDK MUST forward the publisher-supplied placementId verbatim to the Nova ad request `placement` field; the SDK does not synthesize, override, or validate the placement string. The PRD's example value `nova-ios-reward-fullscreen-prod-ob` is a publisher configuration, not an SDK constant. This is the only `placement`-adjacent value the SDK controls.
- **FR-017b (request ad_format — SDK enum)**: SDK MUST set the Nova ad request `ad_format` field to the enum string `rewarded_video` whenever `AdRequest.adFormat == .rewarded`. This is a distinct request field from `placement` (FR-017a), independent of the publisher's placementId string. Note: per the MON Tech Design, Phase 1 Ad Server routing keys off `ctx.placementName` (FR-017c) and does NOT read `ad_format`; this field is set for MES log compatibility and for the future H5 Template Engine Redesign that will key off `{placement}_{creative_type}` AB pairs. Removing it would break MES analytics and future-proofing — keep it.
- **FR-017c (Ad Server internal `ctx.placementName` — SDK does not set)**: For visibility only — the Phase 1 Ad Server recall, hard filter (`AD_REWARDED_VIDEO_CREATIVE_FILTER`), and H5 template selection are all keyed off `ctx.placementName == "REWARDED_VIDEO"`. Per the MON Tech Design that value is derived server-side by the SSP config mapping `ad_unit → REWARDED_VIDEO`; it is NOT the publisher's placementId from FR-017a. SDK does not intend to influence `ctx.placementName` via the OpenRTB `imp[].ext.context.data.placement` field (which carries the publisher placementId from FR-017a) — pending request-log verification that no Ad Server fallback path reads that wire field. Publisher integration MUST coordinate with the Nova SSP team to register each rewarded ad unit so the SSP mapping exists — otherwise rewarded requests will not route correctly even if FR-017a/b are satisfied.
- **FR-018**: Nova rewarded load success MUST require an eligible H5 rewarded-video creative. Missing rewarded item, unsupported creative type, or a response that cannot be rendered as H5 rewarded video MUST fail load instead of returning an unusable `RewardedAd`.
- **FR-019**: SDK MUST support the PRD publisher-facing reward API by delivering `AdListener.onAdRewardReceived(ad:)` after H5 calls `novaNativeBridge.onAdRewarded()`; SDK MUST NOT allocate, verify, or persist rewards itself.
- **FR-020**: SDK MUST emit MES events (`ad_impression`, `ad_click`) for rewarded ads via `RewardedLifecycleController`, with the same idempotency / dedup guarantees as the existing rewarded path. SDK click metadata (click area / click position) is captured from the H5 click JSBridge and attached to the SDK-side click event. The reward signal itself is NOT a MES event — it lives only on the Nova `logAdEvent` channel (FR-023).
- **FR-021**: SDK MUST NOT emit native MES events for PRD-listed H5-side events: SKIP button (incl. `skip_type`), Get Rewards button, Close button success, or any in-H5 video lifecycle event (start / quartiles / complete). These are H5-owned and beaconed directly by the H5 page to Nova's event endpoint. The only JSBridge action SDK accepts in the rewarded path is `onAdRewarded()`.
- **FR-022**: SDK MUST reuse existing consent / privacy plumbing (IAB / GDPR / CCPA / COPPA) for rewarded ads — no rewarded-specific compliance work is in scope. PRD's compliance requirements are inherited via the existing SDK framework, not re-implemented per format.
- **FR-023 (Nova event `AD_EVENT_REWARDED`)**: SDK MUST emit the Nova platform event `AD_EVENT_REWARDED` via `NovaAdMetricReporter.logAdRewarded(...)` (Nova `logAdEvent` endpoint) when H5 fires `novaNativeBridge.onAdRewarded()`. This is the **only** server-side event for the reward signal — there is no MES `ad_rewarded` counterpart. Required parameters: `event_type=AD_EVENT_REWARDED`, `ad_unit_id`, `encrypted_ad_token`, `event_time`, `duration_ms` (time from rewarded VC construction to JSBridge callback, matching the click-event convention). System fields (`sdkv`, `os`, `osv`, `make`, `model`, `bundle`, `cv`) are injected by the shared `logNovaAdEvent` helper. Fires at most once per ad — gated by the same JSBridge dedup as FR-019 (the publisher-facing `AdListener.onAdRewardReceived`).

### Key Entities

- **NovaFullScreenAdItem**: Base class for full-screen Nova ad items. Extracted shared logic from `NovaInterstitialAdItem` (HTML preloading, WebView caching, dismiss lifecycle).
- **NovaFullScreenAdViewController**: Shared base VC extracted from current `NovaInterstitialAdViewController`. Handles common full-screen presentation (orientation lock, impression logging, status bar). Subclassed by interstitial and rewarded VCs, each controlling its own dismiss policy.
- **NovaRewardedAdDelegate**: Independent protocol (`: AnyObject`) with format-specific named methods: `rewardedAdDidDisplay`, `rewardedAdDidDismiss`, `rewardedAdDidLogClick`, `rewardedAdDidEarnReward`.
- **NovaRewardedAdItem**: NovaCore model for a rewarded ad. Inherits `NovaFullScreenAdItem`, holds `delegate: NovaRewardedAdDelegate?`.
- **NovaRewardedAd**: NovaAdapter wrapper. Inherits `MSPiOSCore.RewardedAd`, holds `NovaRewardedAdItem`, bridges to `RewardedLifecycleController`.
- **Rewarded Video Creative**: PRD-eligible Nova H5 creative. The SDK identifies the request as rewarded via `ad_format = rewarded_video` (FR-017b) and forwards the publisher-supplied `placement` (FR-017a). The Ad Server then routes the request as rewarded by reading its own `ctx.placementName = REWARDED_VIDEO`, derived from the SSP-side ad-unit mapping (FR-017c). Phase 1 serving eligibility is `VIDEO` only with `video_length_sec >= 10`; `PLAYABLE_VIDEO` is explicitly out of scope for Phase 1 and the Ad Server hard-filters it out (per the MON Tech Design). H5 owns countdown, skip, end card, close button, and playback flags. H5 also owns reporting of SKIP / `skip_type` / Get Rewards / Close button success / in-H5 video lifecycle events directly to Nova's event endpoint (FR-021).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A Nova rewarded ad can be loaded and presented end-to-end, with the publisher receiving reward and dismiss callbacks in the correct order.
- **SC-002**: The `onAdRewardReceived` callback fires exactly once per ad instance, regardless of how many times the H5 page triggers `onAdRewarded()`.
- **SC-003**: All existing interstitial ad tests pass without modification after the full-screen abstraction refactoring.
- **SC-004**: The rewarded ad H5 content displays within the same latency tolerance as existing interstitial H5 ads (no regression).
- **SC-005**: Nova ad request/event logs correctly identify rewarded ads by their format identifier.

## Assumptions

- The H5 team (@Tingchao Xu) will implement the countdown timer, close button UX, and reward condition logic within the H5 page. The SDK's only responsibility is providing the `novaNativeBridge.onAdRewarded()` interface and reacting to it.
- The H5 team owns PRD rewarded-video UX: countdown ceiling is the server-supplied `rewardedVideoCountdownSec` template variable (driven by AB key `h5_reward_countdown_second`, default 30, independent of `video_length_sec`); the template auto-transitions to the end card when the underlying video finishes early; reward triggers after countdown; close button display; `is_mute = false`, `is_loop = false`, and `is_auto_play = true`.
- The H5 team owns event reporting for SKIP / `skip_type` / Get Rewards / Close button success / in-H5 video lifecycle events. H5 beacons these directly to Nova's event endpoint. SDK does not transform, dedup, or relay these events.
- The video player runs entirely inside the H5 (HTML5 `<video>`); the iOS SDK has no native player handle for the rewarded creative and therefore cannot emit native video quartile events for rewarded ads.
- The Reward System (publisher-defined reward allocation, reward types, secure/fraud-preventive validation) is [Hold] per the PRD and is out of scope. `Reward` metadata is optional and may come from request/bid context; SDK must not fabricate a default reward.
- The ad serving backend (@Songyan Hou) routes rewarded requests via its own `ctx.placementName == "REWARDED_VIDEO"` value, which is derived from the SSP config mapping `ad_unit → REWARDED_VIDEO` (FR-017c). The SDK-set request fields `placement` (publisher-supplied placementId, FR-017a) and `ad_format = rewarded_video` (FR-017b) are independent of `ctx.placementName`; Phase 1 Ad Server routing does not read `ad_format`. Publisher onboarding for rewarded ad units MUST coordinate with the Nova SSP team to register the ad-unit→REWARDED_VIDEO mapping.
- Ad serving owns PRD recall eligibility: Phase 1 recalls Nova single-video creatives only (`type == VIDEO && video_length_sec >= 10`). `PLAYABLE_VIDEO` is deferred to a future phase per the MON Tech Design and is hard-filtered by the Ad Server in Phase 1.
- Compliance & ad quality (IAB / GDPR / CCPA / COPPA, brand safety, IVT detection): inherited from the existing SDK framework. No rewarded-specific compliance work is in scope.
- The creative rendered by the iOS SDK will be H5/HTML. Non-H5 or otherwise unsupported rewarded responses are load failures.
- `NovaRewardedAdItem` shares the same HTML rendering path as interstitial (via `NovaAdHtmlView`), and no new WebView component is needed.
- The existing `RewardedLifecycleController` in MSPiOSCore is sufficient for managing reward state — no behavioral changes needed (log message updated to handle optional `Reward?`).
- No new third-party adapter rewarded support is in scope — this is Nova-only.

## Scope Boundaries

**In scope**:
- `NovaFullScreenAdItem` base class + `NovaFullScreenAdViewController` base VC extraction
- `NovaRewardedAdDelegate` protocol (independent, `: AnyObject`)
- `NovaRewardedAdItem` + `NovaRewardedAd`
- `novaNativeBridge.onAdRewarded()` JSBridge injection and handling
- `NovaAdapter` rewarded format support
- Outbound Nova request `ad_format = rewarded_video` enum mapping (FR-017b) and `placement` passthrough (FR-017a)
- SDK-emitted MES events (`ad_impression`, `ad_click`) via `RewardedLifecycleController` (FR-020). No MES `ad_rewarded` event.
- SDK-emitted Nova event `AD_EVENT_REWARDED` via `NovaAdMetricReporter.logAdRewarded(...)` on the Nova `logAdEvent` endpoint (FR-023) — the sole server-side event for the reward signal

**Out of scope**:
- Reward System (types, amounts, verification URLs) — [Hold] per PRD
- H5 page UI implementation (countdown, skip button, close button, end card/playable, reward confirmation, playback flags) — H5 team
- H5-side event reporting (SKIP / `skip_type` / Get Rewards / Close button success / in-H5 video lifecycle events) — H5 beacons directly to Nova; SDK does not relay
- Native video quartile events for rewarded — the player lives in H5, not native
- Server-side experiment setup and rewarded-video recall filtering (Phase 1: `type == VIDEO && video_length_sec >= 10`; `PLAYABLE_VIDEO` deferred) — MSP server/ad serving teams
- Compliance & ad quality (IAB / GDPR / CCPA / COPPA, brand safety, IVT) — inherited from existing SDK framework, no rewarded-specific work
- New third-party adapter rewarded support
- Changes to `RewardedLifecycleController` or `AdListener`（`RewardedAd.reward` optional 化除外）
- Android or web platform support
