# Tasks: Nova Rewarded Ad

**Input**: Design documents from `/specs/001-nova-rewarded-ad/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/jsbridge-contract.md

**Tests**: Included per Article V.1 (TDD mandate in Sources/constitution.md).

**Organization**: Tasks grouped by user story. US2 (abstraction) is a prerequisite for US1/US3.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Reward optional 化 — 独立于其他 phase，可最先完成

- [x] T001 Change `RewardedAd.reward` from `Reward` to `Reward?` in `Sources/Core/MSPiOSCore/MSPiOSCore/api/RewardedAd.swift`
- [x] T002 Update `RewardedLifecycleController.markRewardEarned()` to handle nil reward in log message in `Sources/Core/MSPiOSCore/MSPiOSCore/internal/RewardedLifecycleController.swift`
- [x] T003 [P] Clean up Google adapter reward fallback — pass `adRequest?.reward` directly in `Sources/Adapters/MSPGoogleAdapter/MSPGoogleAdapter/GoogleAdapter.swift`
- [x] T004 [P] Clean up Facebook adapter reward fallback in `Sources/Adapters/MSPFacebookAdapter/MSPFacebookAdapter/FacebookAdapter.swift`
- [x] T005 [P] Clean up Liftoff adapter reward fallback in `Sources/Adapters/LiftoffAdapter/LiftoffAdapter/LiftoffAdapter.swift`
- [x] T006 [P] Clean up Moloco adapter reward fallback in `Sources/Adapters/MolocoAdapter/MolocoAdapter/MolocoAdapter.swift`
- [x] T007 [P] Clean up Mintegral adapter reward fallback in `Sources/Adapters/MintegralAdapter/MintegralAdapter/MintegralAdapter.swift`
- [x] T008 [P] Clean up Mobilefuse adapter reward fallback in `Sources/Adapters/MobilefuseAdapter/MobilefuseAdapter/MobilefuseAdapter.swift`
- [x] T009 [P] Clean up Inmobi adapter reward fallback in `Sources/Adapters/InmobiAdapter/InmobiAdapter/InmobiAdapter.swift`
- [x] T010 [P] Clean up Pubmatic adapter reward fallback in `Sources/Adapters/PubmaticAdapter/PubmaticAdapter/PubmaticAdapter.swift`
- [x] T011 Verify existing rewarded ad tests still pass after optional migration — run `make test`

**Checkpoint**: `RewardedAd.reward` is now `Reward?`. All existing adapters compile and tests pass.

---

## Phase 2: Foundational — Full-Screen Ad Abstraction (US2, Priority: P1)

**Purpose**: Extract shared full-screen abstractions from interstitial. BLOCKS US1 and US3.

**⚠️ CRITICAL**: No rewarded ad work can begin until this phase is complete.

**Goal**: Shared protocol + base class + base VC that both interstitial and rewarded can use.

**Independent Test**: All existing interstitial ad functionality works identically after refactoring.

### Protocols & Base Models

- [x] ~~T012~~ REMOVED — `NovaFullScreenAdPresenting` protocol deemed unnecessary; base class provides the shared interface
- [x] ~~T013~~ REMOVED — `NovaFullScreenAdDelegate` protocol deemed unnecessary; each format has its own independent delegate
- [x] T014 [US2] Extract shared properties from `NovaInterstitialAdItem` into `NovaFullScreenAdItem` base class in `Sources/Core/NovaCore/NovaCore/FullScreen/Models/NovaFullScreenAdItem.swift` — move `shouldPreloadHtml`, `cachedHtmlView`, `preloadHtmlView()`, `dismiss()` to base; keep `startTimeInMs`, `expirationTimeInMs`, `closeCountDownTimeSeconds`, `clickableComponents`, `layoutStyle` in interstitial
- [x] T015 [US2] Refactor `NovaInterstitialAdItem` to inherit from `NovaFullScreenAdItem` in `Sources/Core/NovaCore/NovaCore/Interstitial/Models/NovaInterstitialAdItem.swift`
- [x] ~~T016~~ REMOVED — `NovaInterstitialAdDelegate` stays independent (`: AnyObject`), no shared delegate hierarchy

### Base ViewController

- [x] T017 [US2] Extract shared logic from `NovaInterstitialAdViewController` into `NovaFullScreenAdViewController` base class in `Sources/Core/NovaCore/NovaCore/FullScreen/NovaFullScreenAdViewController.swift` — move view setup, impression logging, orientation locking, ad view lifecycle; keep `handleApplicationWillEnterForeground` in interstitial subclass
- [x] T018 [US2] Refactor `NovaInterstitialAdViewController` to inherit from `NovaFullScreenAdViewController` in `Sources/Core/NovaCore/NovaCore/Interstitial/NovaInterstitialAdViewController.swift`

### XcodeGen & Validation

- [x] T019 [US2] Update `Sources/Core/NovaCore/project.yml.template` to include new `FullScreen/` directory files and run `xcodegen generate`
- [x] T020 [US2] Verify all existing interstitial tests pass unchanged (FR-013 regression gate) — run `make test`, specifically confirm interstitial load/show/dismiss/delegate callbacks are unaffected
- [x] T021 [US2] Run round-trip test — `./Scripts/target-switching/round-trip-test.sh`

**Checkpoint**: Full-screen abstraction complete. Interstitial works identically. Ready for rewarded ad implementation.

---

## Phase 3: User Story 3 — JSBridge `onAdRewarded` (Priority: P1)

**Goal**: H5 can call `novaNativeBridge.onAdRewarded()` and native receives it via delegate.

**Independent Test**: Load H5 page that calls `onAdRewarded()`, verify `didEarnReward()` fires on delegate.

### Implementation

- [x] T022 [US3] Add `didEarnReward()` method to `NovaAdHtmlActionDelegate` protocol in `Sources/Core/NovaCore/NovaCore/Media/Html/NovaAdHtmlJSMessage.swift`
- [x] T023 [US3] Add default empty implementation of `didEarnReward()` in protocol extension (backward compat for existing conformers)
- [x] T024 [US3] Inject `onAdRewarded` function into `novaNativeBridge` JS object in `NovaAdHtmlView.injectNovaNativeBridge()` in `Sources/Core/NovaCore/NovaCore/Media/Html/NovaAdHtmlView.swift`
- [x] T025 [US3] Handle `"onAdRewarded"` action in `userContentController(_:didReceive:)` → `novaNativeBridge` switch case in `Sources/Core/NovaCore/NovaCore/Media/Html/NovaAdHtmlView.swift`

**Checkpoint**: JSBridge contract implemented. H5→Native reward notification path complete.

---

## Phase 4: User Story 1 — Publisher Loads and Shows Nova Rewarded Ad (Priority: P1) 🎯 MVP

**Goal**: End-to-end: load Nova rewarded ad → present H5 → receive reward callback → dismiss.

**Independent Test**: Load Nova rewarded ad with HTML creative, present, trigger `onAdRewarded()`, verify `onAdRewardReceived` and `onAdDismissed` fire in correct order.

### Tests (deferred — implementation was validated via manual DemoApp testing)

> **Note**: Article V.1 mandates TDD. These tests were deferred during implementation in favor of manual log-based verification (Google/Facebook/Nova rewarded + interstitial flows confirmed in simulator). Unit tests should still be written to cover regression.

- [ ] T026 [P] [US1] Create `NovaRewardedAdLifecycleSpec` in `Tests/NovaCoreTests/Specs/Rewarded/NovaRewardedAdLifecycleSpec.swift` — Quick/Nimble tests for: reward callback fires exactly once, dismiss without reward when `onAdRewarded` not called, dismiss after reward fires callbacks in correct order, WebView crash triggers dismiss without reward, late `onAdRewarded` after dismiss is dropped
- [ ] T027 [P] [US1] Extend Nova rewarded adapter coverage in `Tests/AdapterTests/Specs/NovaRewardedAdTests.swift` — Quick/Nimble tests for: `parseNovaAdString` with rewarded-video response creates `NovaRewardedAd`, adapter forwards delegate events through `RewardedLifecycleController`, missing rewarded item fails load, unsupported/non-H5 creative fails load instead of returning an unusable ad

### NovaCore Rewarded Models

- [x] T028 [P] [US1] Create `NovaRewardedAdDelegate` protocol (`: AnyObject`) in `Sources/Core/NovaCore/NovaCore/Rewarded/Models/NovaRewardedAdDelegate.swift` — define `rewardedAdDidDisplay`, `rewardedAdDidDismiss`, `rewardedAdDidLogClick`, `rewardedAdDidEarnReward`
- [x] T029 [P] [US1] Create `NovaRewardedAdItem` inheriting `NovaFullScreenAdItem` in `Sources/Core/NovaCore/NovaCore/Rewarded/Models/NovaRewardedAdItem.swift` — hold `delegate: NovaRewardedAdDelegate?` (weak)

### NovaCore Rewarded ViewController

- [x] T030 [US1] Create `NovaRewardedAdViewController` subclassing `NovaFullScreenAdViewController` in `Sources/Core/NovaCore/NovaCore/Rewarded/NovaRewardedAdViewController.swift` — NO auto-dismiss on `willEnterForeground`, forward `didEarnReward()` from `NovaAdHtmlActionDelegate` to `NovaRewardedAdDelegate`, handle `webViewWebContentProcessDidTerminate` by dismissing ad and firing `onAdDismissed` without reward

### NovaAdBuilder

- [x] T031 [US1] Add `buildRewardedAds()` method to `NovaAdBuilder` in `Sources/Core/NovaCore/NovaCore/Internal/NovaAdBuilder.swift` — mirror `buildInterstitialAds()`, create `NovaRewardedAdItem` (no `closeCountDownTimeSeconds`, `clickableComponents`, `startTimeInMs`, `expirationTimeInMs`)

### NovaAdapter Integration

- [x] T032 [US1] Create `NovaRewardedAd` subclassing `MSPiOSCore.RewardedAd` in `Sources/Adapters/NovaAdapter/NovaAdapter/Rewarded/NovaRewardedAd.swift` — hold `NovaRewardedAdItem`, create `RewardedLifecycleController`, implement `show(rootViewController:)`, `isValid()`
- [x] T033 [US1] Add `rewardedAdItem` property to `NovaAdapter` in `Sources/Adapters/NovaAdapter/NovaAdapter/NovaAdapter.swift`
- [x] T034 [US1] Add `adFormat == .rewarded` handling in `NovaAdapter.loadAdCreative()` — build the rewarded loading path in `Sources/Adapters/NovaAdapter/NovaAdapter/NovaAdapter.swift`; external Nova serving/logging value is verified separately as `rewarded_video` in T040
- [x] T035 [US1] Add rewarded response parsing branch in `NovaAdapter.parseNovaAdString()` — call `NovaAdBuilder.buildRewardedAds()`, create `NovaRewardedAd`, wire delegate, call `handleAdLoaded()` in `Sources/Adapters/NovaAdapter/NovaAdapter/NovaAdapter.swift`
- [x] T036 [US1] Implement `NovaRewardedAdDelegate` conformance on `NovaAdapter` — forward `rewardedAdDidDisplay/Dismiss/LogClick` + `rewardedAdDidEarnReward` through `RewardedLifecycleController` in `Sources/Adapters/NovaAdapter/NovaAdapter/NovaAdapter.swift`
- [x] T037 [US1] Add `destroyAd()` cleanup for `rewardedAdItem` in `NovaAdapter.destroyAd()` in `Sources/Adapters/NovaAdapter/NovaAdapter/NovaAdapter.swift`

### XcodeGen & Validation

- [x] T038 [US1] Update `Sources/Core/NovaCore/project.yml.template` and `Sources/Adapters/NovaAdapter/project.yml.template` to include new `Rewarded/` directory files, run `xcodegen generate`
- [x] T039 [US1] Verify build succeeds — `BUILD SUCCEEDED` on MSPDemoApp scheme (pods-dev). Note: T026-T027 tests deferred, manual DemoApp validation done instead

**Checkpoint**: Core MVP complete. Nova rewarded ad can be loaded, presented, reward earned, and dismissed.

---

## Phase 5: User Story 4 — Event Reporting (Priority: P2)

**Goal**: Nova bid request `placement` (FR-017a) + `ad_format = rewarded_video` (FR-017b) are correctly populated, and SDK-side MES events (`ad_impression` / `ad_click` / `ad_rewarded`) fire exactly once via `RewardedLifecycleController`. Per Clarifications session 2026-04-29, H5-side events (SKIP / `skip_type` / Get Rewards / Close button success / in-H5 video lifecycle) are **not** the SDK's responsibility — H5 beacons them directly.

**Independent Test**: Present a rewarded ad, verify the outbound Nova request carries `ad_format = rewarded_video` and the publisher-supplied `placement`; verify SDK fires `ad_impression`, `ad_click`, and `ad_rewarded` MES events exactly once each; verify SDK does NOT emit MES events for skip / get-rewards / close-button taps or in-H5 video events.

- [ ] T040 [US4] Audit `placement` field in Nova bid request (FR-017a). The SDK MUST forward the publisher-supplied placementId verbatim — confirm there is no transformation in `MSPAdLoader.getBidder()` or `NovaAdapter.loadAdCreative()` (`Sources/Core/MSPCore/MSPCore/MSPAdLoader.swift`, `Sources/Adapters/NovaAdapter/NovaAdapter/NovaAdapter.swift`).
- [ ] T040b [US4] Audit `ad_format` field in Nova bid request (FR-017b). When `AdRequest.adFormat == .rewarded`, the request body must serialize `ad_format = "rewarded_video"`. The internal routing key `novaAdType = "rewarded"` in `NovaAdapter.parseNovaAdString` is consumed locally and does not affect the outbound request — leave it unchanged unless the bid response `prebid.ext.prebid.type` actually returns `rewarded_video`.
- [ ] T041 [US4] Verify SDK-side `ad_impression` MES fires exactly once when `markDisplayed()` is called — trace `RewardedLifecycleController.markDisplayed()` (already covered by `RewardedLifecycleControllerSpec` and `NovaRewardedAdTests`).
- [ ] T042 [US4] Verify dismiss/close ordering — confirm `RewardedLifecycleController.markDismissed()` logs `order=after_reward` / `order=before_reward` correctly in `Sources/Core/MSPiOSCore/MSPiOSCore/internal/RewardedLifecycleController.swift`.
- [ ] T049 [US4] Verify rewarded click metadata (`click_area_name`, `click_position`) is captured from the H5 click JSBridge and attached to the SDK-side click event via the existing click reporting path. Field name matches `specs/001-nova-rewarded-ad/contracts/jsbridge-contract.md` and the implementation across `NovaAdHtmlView`, `MESMetricReporter`, and `NovaAdMetricReporter`.
- [ ] T050 [US4] Verify SDK does NOT emit MES events for H5-owned events: SKIP / `skip_type`, Get Rewards, Close button success, in-H5 video lifecycle. The only JSBridge action SDK accepts in the rewarded path is `onAdRewarded()`. (FR-021 negative test.)

**Checkpoint**: SDK request fields and SDK-emitted MES events are correct; H5-owned events are confirmed not relayed by SDK.

---

## Phase 6: User Story 5 — H5 Content Preloading (Priority: P3)

**Goal**: Rewarded H5 content can be preloaded for instant display.

**Independent Test**: Load rewarded ad with `shouldPreloadHtml = true`, call `show()`, verify no loading delay.

- [x] T043 [US5] Ensure `NovaRewardedAdItem` inherits `shouldPreloadHtml` and `preloadHtmlView()` from `NovaFullScreenAdItem` — verify in `Sources/Core/NovaCore/NovaCore/Rewarded/Models/NovaRewardedAdItem.swift`
- [x] T044 [US5] Add preload logic in `NovaAdapter.parseNovaAdString()` rewarded branch — mirror interstitial HTML preload pattern (check `shouldPreloadHtml`, call `preloadHtmlView()`, fire `handleAdLoaded()` on completion) in `Sources/Adapters/NovaAdapter/NovaAdapter/NovaAdapter.swift`

**Checkpoint**: Preloading works for rewarded H5 ads.

---

## Phase 6A: User Story 6 — PRD H5/Serving Contract (Priority: P2)

**Goal**: Align native SDK boundaries with the updated PRD.

- [ ] T051 [US6] Document and confirm with H5 team that rewarded video H5 owns countdown `min(video_length, 30s)`, reward trigger, skip/end-card/playable/close-button flow, `is_mute = false`, `is_loop = false`, and `is_auto_play = true`
- [ ] T052 [US6] Confirm with ad serving/MSP server teams that `placement = rewarded_video` recalls Nova single video and playable video ads with `video_length >= 10s`; SDK should treat ineligible/missing H5 rewarded item as load failure
- [ ] T053 [US6] Manual DemoApp validation with a PRD-compliant H5 rewarded-video creative — verify no native countdown/skip/end-card UI is required and reward callback is driven only by `novaNativeBridge.onAdRewarded()`

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Validation, cleanup, documentation

- [ ] T045 Add DocC comments to all new `public` APIs across `NovaFullScreenAdItem`, `NovaRewardedAdItem`, `NovaRewardedAd`, `NovaRewardedAdDelegate`
- [ ] T046 Run full test suite — `make test`
- [ ] T047 Run round-trip test — `./Scripts/target-switching/round-trip-test.sh`
- [ ] T048 Manual DemoApp validation — load Nova rewarded ad, verify end-to-end flow (load → show → reward → dismiss) and confirm request/event logs use `rewarded_video`

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Reward Optional) ──────────────────────────────────┐
                                                             │
Phase 2 (FullScreen Abstraction / US2) ──┐                   │
                                         │                   │
Phase 3 (JSBridge / US3) ───────────────┐│                   │
                                        ││                   │
Phase 4 (MVP / US1) ←── depends on ─── Phase 2 + Phase 3    │
         │                                                   │
         ├── Phase 5 (Reporting / US4) ← depends on Phase 4  │
         │                                                   │
         ├── Phase 6 (Preload / US5) ← depends on Phase 4    │
         │                                                   │
         └── Phase 6A (PRD H5/Serving / US6) ← depends on Phase 4 │
                                                             │
Phase 7 (Polish) ←── depends on all above ──────────────────┘
```

### Key Parallelism

- **Phase 1 and Phase 2** can execute in parallel (completely independent)
- **Phase 3** can execute in parallel with Phase 2 (JSBridge changes are in `NovaAdHtmlView`, independent of FullScreen extraction)
- **T003-T010** (adapter cleanups) can all run in parallel
- **T026-T027** (tests) can run in parallel, then **T028-T029** (models) in parallel
- **Phase 5, Phase 6, and Phase 6A** can execute in parallel after Phase 4

### Within Each Phase

- TDD tests before implementation (Article V.1)
- Protocols/models before services/VCs
- VCs before adapter integration
- XcodeGen + validation at end of each phase

---

## Implementation Strategy

### MVP First (Phases 1-4)

1. Phase 1: `Reward?` optional migration (independent, can start immediately)
2. Phase 2: Extract FullScreen abstractions (blocks rewarded work)
3. Phase 3: JSBridge `onAdRewarded` (can parallelize with Phase 2)
4. Phase 4: Write failing tests → Wire up `NovaRewardedAd` end-to-end → Tests pass
5. **STOP and VALIDATE**: Test full rewarded flow in DemoApp

### Incremental Delivery

1. Phases 1-4 → MVP: rewarded ad works end-to-end
2. Phase 5 → Event reporting verified
3. Phase 6 → Preload optimization
4. Phase 6A → PRD H5/serving contract validated
5. Phase 7 → Polish and final validation

---

## Notes

- All new files require `*.yml.template` update + `xcodegen generate` (Article I.2)
- Never modify `.xcodeproj` directly
- Run `./Scripts/target-switching/round-trip-test.sh` before committing (Article II.2)
- All new `public` APIs need DocC comments (Article IV.3)
- TDD: write failing tests before implementation (Article V.1)
- Total: 53 tasks across 8 phases
