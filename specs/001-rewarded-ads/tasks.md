# Tasks: Rewarded Ads

**Input**: Design documents from `specs/001-rewarded-ads/`
**Branch**: `001-rewarded-ads`
**TDD**: Required — per Constitution Article V, tests must be written and FAIL before implementation

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no shared dependencies)
- **[Story]**: Which user story this task belongs to
- Tests marked `⚠️ WRITE FIRST — must FAIL before implementation`

---

## Phase 1: Setup

**Purpose**: Create directory structure and register new files in XcodeGen templates

- [X] T001 Create `Rewarded/` directory in `Sources/Adapters/MSPGoogleAdapter/MSPGoogleAdapter/`
- [X] T002 [P] Create `Rewarded/` directory in `Sources/Adapters/MSPFacebookAdapter/MSPFacebookAdapter/`
- [X] T003 Add stub entries for all new `.swift` files to relevant `*.yml.template` files (MSPiOSCore, MSPCore, MSPGoogleAdapter, MSPFacebookAdapter modules); run `xcodegen generate` to confirm project compiles with empty stubs; run `./Scripts/target-switching/round-trip-test.sh` to validate all SDK modes compile (per Article II.2 — early validation checkpoint)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core API types and lifecycle infrastructure — MUST complete before any user story

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 [P] Write failing Quick/Nimble tests for `Reward` struct in `Tests/MSPiOSCoreTests/RewardTests.swift` — cover: init, Equatable, Codable round-trip ⚠️ WRITE FIRST
- [X] T005 [P] Write failing Quick/Nimble tests for `RewardedAd` base class in `Tests/MSPiOSCoreTests/RewardedAdTests.swift` — cover: `reward` property set correctly, `show()` triggers fatalError in base class ⚠️ WRITE FIRST
- [X] T006 [P] Write failing Quick/Nimble tests for `RewardedLifecycleController` in `Tests/MSPCoreTests/RewardedLifecycleControllerTests.swift` — cover: (1) `markRewardEarned()` calls listener once; (2) `markRewardEarned()` twice → listener called once only; (3) `markDismissed()` without prior reward → no reward callback; (4) `markDismissed()` twice → dismiss fires once; (5) reward before dismiss ordering; (6) two separate controller instances — reward on controller A does NOT trigger listener on controller B (isolation) ⚠️ WRITE FIRST
- [X] T007 Add `.rewarded` case to `AdFormat` enum in `Sources/Core/MSPiOSCore/MSPiOSCore/api/AdFormat.swift` — confirm compiler emits exhaustiveness warnings in all adapter `switch bidderFormat` statements
- [X] T008 [P] Create `Reward` struct in `Sources/Core/MSPiOSCore/MSPiOSCore/api/Reward.swift` — `public struct Reward: Equatable, Codable, Sendable` with `type: String`, `amount: Int`, full DocC comments
- [X] T009 [P] Add `public var reward: Reward?` to `AdRequest` in `Sources/Core/MSPiOSCore/MSPiOSCore/api/AdRequest.swift` — optional, nil by default, DocC comment noting optional status
- [X] T010 Create `RewardedAd` open class in `Sources/Core/MSPiOSCore/MSPiOSCore/api/RewardedAd.swift` — `open class RewardedAd: MSPAd` with `public let reward: Reward`, `open func show(rootViewController: UIViewController?)` (fatalError if not overridden), `open func dismiss(animated: Bool)` (no-op default), full DocC
- [X] T011 Add `onAdRewardReceived(ad: MSPAd)` to `AdListener` in `Sources/Core/MSPiOSCore/MSPiOSCore/api/Delegates/AdListener.swift` — add to protocol + default empty impl via `public extension AdListener`, DocC noting at-most-once and ordering guarantee
- [X] T012 Create `RewardedLifecycleController` in `Sources/Core/MSPCore/MSPCore/RewardedLifecycleController.swift` — `internal final class` with `hasEarnedReward: Bool`, `hasDismissed: Bool`, weak `AdListener`, unowned `MSPAd`; methods: `markDisplayed()`, `markClicked()`, `markRewardEarned()` (idempotent), `markDismissed()` (idempotent); use `Logger` with category "Rewarded"
- [X] T013 No capability probe API is added to `AdNetworkAdapter`. `MSPAdLoader` keeps `.rewarded` on the existing auction/load path and applies a central rollout policy. v1 uses a client-side whitelist (`google`, `facebook`); future server rollout can replace the policy input without changing adapter routing. Each unsupported adapter explicitly calls `auctionBidListener.onError(error: "xxx rewarded is not supported")` inside its own `loadAdCreative` (Amazon, Inmobi, Liftoff, Mintegral, Mobilefuse, Moloco, Pubmatic, Unity). Nova has no `.rewarded` case but will not be selected by the current rollout gate.
- [X] T014 Run tests T004–T006: confirm `RewardTests`, `RewardedAdTests`, `RewardedLifecycleControllerTests` all pass after implementations T007–T013

**Checkpoint**: Foundation ready — API types compile, lifecycle controller tested, NovaAdapter filtered

---

## Phase 3: User Story 1 — Request & Show Rewarded Ad (Priority: P1) 🎯 MVP

**Goal**: SDK integrator can request a Rewarded ad via Google AdMob and show it full-screen

**Independent Test**: Create `AdRequest` with `adFormat: .rewarded`, load via `MSPAdLoader`, verify `onAdLoaded` fires; call `show(rootViewController:)` on the returned `RewardedAd`, verify full-screen presentation

### Tests for User Story 1 ⚠️ WRITE FIRST

- [X] T015 [P] [US1] Write failing Quick/Nimble tests for `GoogleRewardedAd` load/show path in `Tests/MSPGoogleAdapterTests/GoogleRewardedAdTests.swift` — cover: (1) `show()` calls `GADRewardedAd.present()`; (2) `adDidRecordImpression` fires the delegate method (lifecycle wiring is verified in US2/T019); (3) `adDidDismissFullScreenContent` fires the delegate method (lifecycle wiring verified in US2/T019); (4) `gadRewardedAd` is non-nil after successful load ⚠️ WRITE FIRST

### Implementation for User Story 1

- [X] T016 [US1] Create `GoogleRewardedAd` skeleton in `Sources/Adapters/MSPGoogleAdapter/MSPGoogleAdapter/Rewarded/GoogleRewardedAd.swift` — `public class GoogleRewardedAd: MSPiOSCore.RewardedAd`; holds `GADRewardedAd?` and weak `rootViewController`; `override show(rootViewController:)` calls `gadRewardedAd.present(from:userDidEarnRewardHandler:)` with empty stub closures; implements `GADFullScreenContentDelegate` with stub method bodies for `adDidRecordImpression`, `adDidRecordClick`, `adDidDismissFullScreenContent` (stubs only — no lifecycle calls yet), `didFailToPresentFullScreenContent` → `adListener?.onError()`; `override func dismiss(animated: Bool)` — no-op (full-screen dismissal is always user-initiated via GAD SDK) — **NOTE**: `RewardedLifecycleController` wiring is intentionally deferred to T020 (US2 boundary)
- [X] T017 [US1] Add `.rewarded` branch to `loadAdCreative` in `Sources/Adapters/MSPGoogleAdapter/MSPGoogleAdapter/GoogleAdapter.swift` — load `GADRewardedAd` with `bidderPlacementId`; on success create `GoogleRewardedAd`, store in `AdCache.shared.saveAd()`, call `auctionBidListener.onBidSuccess()`; on failure call `auctionBidListener.onBidFailed()`
- [X] T018 [US1] Run T015 tests — confirm all `GoogleRewardedAdTests` pass

**Checkpoint**: Rewarded ad can be loaded and shown via Google AdMob; US1 independently testable

---

## Phase 4: User Story 2 — Reward Callback (Priority: P1)

**Goal**: Integrator receives `onAdRewardReceived(ad:)` exactly once when user earns reward; never fires on early close

**Independent Test**: Show Google Rewarded ad → simulate `userDidEarnRewardHandler` → verify `onAdRewardReceived` fires once; simulate early close without reward → verify no reward callback; simulate duplicate reward signals → verify single callback

### Tests for User Story 2 ⚠️ WRITE FIRST

- [X] T019 [US2] Write failing Quick/Nimble tests for reward callback flow in `Tests/MSPGoogleAdapterTests/GoogleRewardedAdRewardTests.swift` — cover: (1) `userDidEarnRewardHandler` fires → `onAdRewardReceived` called on listener; (2) `userDidEarnRewardHandler` fires twice → `onAdRewardReceived` called once only (idempotent); (3) `adDidDismissFullScreenContent` without prior reward → `onAdRewardReceived` NOT called; (4) reward fires before dismiss in sequence ⚠️ WRITE FIRST

### Implementation for User Story 2

- [X] T020 [US2] Wire `RewardedLifecycleController` into `GoogleRewardedAd` in `Sources/Adapters/MSPGoogleAdapter/MSPGoogleAdapter/Rewarded/GoogleRewardedAd.swift` — add `private let lifecycleController: RewardedLifecycleController` initialized at init with injected `AdListener` and unowned `self` as `MSPAd`; replace delegate stubs from T016: `adDidRecordImpression` → `lifecycleController.markDisplayed()`, `adDidRecordClick` → `lifecycleController.markClicked()`, `adDidDismissFullScreenContent` → `lifecycleController.markDismissed()`; fill `userDidEarnRewardHandler` closure: call `lifecycleController.markRewardEarned()`
- [X] T021 [US2] Run T006 + T019 tests — confirm `RewardedLifecycleControllerTests` and `GoogleRewardedAdRewardTests` all pass

**Checkpoint**: Reward callback is idempotent, ordered correctly, never fires on early close

---

## Phase 5: User Story 3 — Reward Config (Priority: P2)

**Goal**: Integrator can set optional `Reward(type:amount:)` on `AdRequest`; config is forwarded to the ad network request

**Independent Test**: Set `adRequest.reward = Reward(type: "coins", amount: 10)`, load Google Rewarded ad, verify reward params appear in the outgoing GAD request; omit `reward`, verify request succeeds without reward params

### Tests for User Story 3 ⚠️ WRITE FIRST

- [X] T022 [US3] Write failing Quick/Nimble tests for reward config forwarding in `Tests/MSPGoogleAdapterTests/GoogleRewardedAdConfigTests.swift` — cover: (1) `adRequest.reward = Reward(type: "coins", amount: 10)` → `GADRequest.serverSideVerificationOptions.customRewardString` is set (e.g. `"coins:10"`); (2) `adRequest.reward = nil` → `serverSideVerificationOptions` is not set and request proceeds without reward params ⚠️ WRITE FIRST

### Implementation for User Story 3

- [X] T023 [P] [US3] Forward `adRequest.reward` in Google adapter `loadAdCreative` in `Sources/Adapters/MSPGoogleAdapter/MSPGoogleAdapter/GoogleAdapter.swift` — if `adRequest.reward != nil`: create `GADServerSideVerificationOptions()`, set `customRewardString = "\(reward.type):\(reward.amount)"`, assign to `GADRequest.serverSideVerificationOptions`; if nil: skip (do not set `serverSideVerificationOptions`)
- [X] T024 [P] [US3] Add reward forwarding placeholder comment in `Sources/Adapters/MSPFacebookAdapter/MSPFacebookAdapter/FacebookAdapter.swift` `.rewarded` stub — add `// TODO(US3-FB): forward adRequest.reward via FBRewardedVideoAd load config if API supports it` so T026 implementer knows where to wire it; actual forwarding wired in T026

**Checkpoint**: Reward config flows through to Google ad network when set; nil reward causes no errors

---

## Phase 6: User Story 4 — Multi-Network Rewarded (Priority: P2)

**Goal**: Facebook Audience Network Rewarded Video works end-to-end with correct reward/dismiss ordering; all other adapters handle `.rewarded` without crashing

**Independent Test**: Configure Facebook placement, load Rewarded ad, verify `onAdLoaded` fires; show ad, simulate `rewardedVideoAdVideoComplete` → verify reward fires; simulate `rewardedVideoAdDidClose` → verify dismiss fires after reward

### Tests for User Story 4 ⚠️ WRITE FIRST

- [X] T025 [US4] Write failing Quick/Nimble tests for `FacebookRewardedAd` in `Tests/MSPFacebookAdapterTests/FacebookRewardedAdTests.swift` — cover: (1) `rewardedVideoAdVideoComplete` → `onAdRewardReceived` fires; (2) `rewardedVideoAdDidClose` → dismiss fires; (3) `rewardedVideoAdDidClose` without prior `videoComplete` → no reward callback; (4) `videoComplete` twice → `onAdRewardReceived` fires once ⚠️ WRITE FIRST

### Implementation for User Story 4

- [X] T026 [US4] Create `FacebookRewardedAd` in `Sources/Adapters/MSPFacebookAdapter/MSPFacebookAdapter/Rewarded/FacebookRewardedAd.swift` — `public class FacebookRewardedAd: MSPiOSCore.RewardedAd`; holds `FBRewardedVideoAd?`; `override show(rootViewController:)` checks `isAdValid` then calls `fbAd.show(fromRootViewController:)`; `override func dismiss(animated: Bool)` — no-op (FB ad dismissed by user interaction); wire `private let lifecycleController: RewardedLifecycleController` at init (same pattern as T020); implements `FBRewardedVideoAdDelegate`: `rewardedVideoAdDidLoad` → cache + bid listener (load phase), `rewardedVideoAdWillLogImpression` → `lifecycleController.markDisplayed()`, `rewardedVideoAdDidClick` → `lifecycleController.markClicked()`, `rewardedVideoAdVideoComplete` → `lifecycleController.markRewardEarned()`, `rewardedVideoAdDidClose` → `lifecycleController.markDismissed()`, error → `adListener?.onError()`; wire reward forwarding from T024 TODO if FB API supports it
- [X] T027 [US4] Add `.rewarded` branch to `loadAdCreative` in `Sources/Adapters/MSPFacebookAdapter/MSPFacebookAdapter/FacebookAdapter.swift` — create `FBRewardedVideoAd(placementID:)`, set delegate to `FacebookRewardedAd` instance, call `load()`
- [X] T028 [P] [US4] Add explicit `.rewarded` unsupported error path to all remaining adapters — call `auctionBidListener.onError(error: "xxx rewarded is not supported")` so the auction treats the bid as a loss rather than silently hanging. Files: `Sources/Adapters/AmazonAdapter/AmazonAdapter/AmazonAdapter.swift`, `Sources/Adapters/InmobiAdapter/InmobiAdapter/InmobiAdapter.swift`, `Sources/Adapters/LiftoffAdapter/LiftoffAdapter/LiftoffAdapter.swift`, `Sources/Adapters/MintegralAdapter/MintegralAdapter/MintegralAdapter.swift`, `Sources/Adapters/MobilefuseAdapter/MobilefuseAdapter/MobilefuseAdapter.swift`, `Sources/Adapters/MolocoAdapter/MolocoAdapter/MolocoAdapter.swift`, `Sources/Adapters/MSPPrebidAdapter/MSPPrebidAdapter/PrebidAdapter.swift`, `Sources/Adapters/PubmaticAdapter/PubmaticAdapter/PubmaticAdapter.swift`, `Sources/Adapters/UnityAdapter/UnityAdapter/UnityAdapter.swift`
- [X] T029 [US4] Run T025 tests — confirm all `FacebookRewardedAdTests` pass

**Checkpoint**: Both Google and Facebook Rewarded ads work end-to-end; no other adapter crashes on `.rewarded`

---

## Phase 7: User Story 5 — Debug Tool (Priority: P3)

**Goal**: Debug page shows Rewarded format option; when selected, shows Reward Type and Reward Amount config sections; reward callback appears in toast log

**Independent Test**: Select Rewarded in Debug page → Reward Config sections appear; select coins/10, tap Load Ad → ad loads; show ad → observe "✓ Reward received" toast before close toast

### Implementation for User Story 5

- [X] T030 [US5] Add `.rewarded` to Debug format options in `Sources/Core/MSPCore/MSPCore/Debug/Models/Extensions/AdFormat+DebugOption.swift` — add case `.rewarded` with `id: "rewarded"`, `title: "Rewarded"`
- [X] T031 [P] [US5] Create `RewardConfig.swift` in `Sources/Core/MSPCore/MSPCore/Debug/Models/RewardConfig.swift` — define `RewardTypeOption: DebugOption, TestParamsPresentable` (options: "coins", "lives", "credits"; testParam: `("reward_type", id)`); define `RewardAmountOption: DebugOption, TestParamsPresentable` (options: "1", "5", "10"; testParam: `("reward_amount", id)`)
- [X] T032 [P] [US5] Create extension files `Sources/Core/MSPCore/MSPCore/Debug/Models/Extensions/RewardTypeOption+DebugOption.swift` and `RewardAmountOption+DebugOption.swift` following existing `AdNetwork+DebugOption.swift` pattern
- [X] T033 [US5] Add Reward Type and Reward Amount sections to `Sources/Core/MSPCore/MSPCore/Debug/Repositorys/TestDebugSectionsService.swift` — both with `showCondition: ["rewarded"]`; insert after Ad Format section in section array
- [X] T034 [US5] Wire reward options into `AdRequest` in `Sources/Core/MSPCore/MSPCore/Debug/Repositorys/TestLoadAdService.swift` — when format == `.rewarded` and both reward options selected, build `Reward(type:amount:)` and assign to `adRequest.reward`; implement `onAdRewardReceived(ad:)` in `AdListener` conformance: show green toast "✓ Reward received", record timestamp; in `onAdDismissed`: show toast "Ad closed — reward \(receivedBeforeDismiss ? "before" : "after or missing") dismiss"

**Checkpoint**: Full Rewarded ad debug flow verifiable in Debug page with reward callback visibility

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T035 Update all `*.yml.template` files for MSPiOSCore, MSPCore, MSPGoogleAdapter, MSPFacebookAdapter modules to include all new `.swift` files created in phases above; run `xcodegen generate` to regenerate `.xcodeproj`
- [X] T036 Run `./Scripts/target-switching/round-trip-test.sh` to validate all SDK modes compile and pass (per Article II.2)
- [X] T037 [P] Audit DocC comments on all new `public`/`open` symbols — `Reward`, `RewardedAd`, `AdFormat.rewarded`, `AdRequest.reward`, `AdListener.onAdRewardReceived` (per Article IV.3)
- [X] T038 [P] Verify no force-unwrap (`!`) in any new Swift files (per Article IV.3)
- [X] T039 [P] Verify no third-party SDK imports in `MSPiOSCore` or `MSPCore` modules — `RewardedAd.swift`, `RewardedLifecycleController.swift` must not import `GoogleMobileAds` or `FBAudienceNetwork` (per Article III.1)
- [X] T040 Run full test suite — confirm existing Banner/Native/Interstitial tests all pass (SC-004 regression check)

---

## Phase 9: All-Network Rewarded Adapter Expansion

**Purpose**: Implement rewarded ad support in ALL remaining adapters. Code-ready but rollout-gated in v1 (only Facebook + Google enabled).

**Architecture**: `MSPAdLoader` owns the rewarded rollout gate. Today it is a client-side whitelist; later it will switch to server-driven config without changing adapter routing. Unsupported adapters still return explicit errors from their own `.rewarded` branches.

### Prerequisite: Shared Helper

- [ ] T041 Normalize unsupported `.rewarded` handling in adapter `loadAdCreative` implementations — keep `.rewarded` on the existing routing path and ensure each unsupported adapter returns an explicit `auctionBidListener.onError(...)` from its own branch (Amazon, Inmobi, Liftoff, Mintegral, Mobilefuse, Moloco, Pubmatic, Unity). No shared capability probe or rejection helper is introduced.

### Liftoff / Vungle

- [ ] T042 [P] Write failing Quick/Nimble tests for `LiftoffRewardedAd` in `Tests/AdapterTests/Specs/LiftoffRewardedAdTests.swift` — cover: (1) `show()` calls `VungleRewarded.present(with:)`; (2) `rewardedAdDidRewardUser` → `onAdRewardReceived` fires once; (3) `rewardedAdDidClose` without prior reward → no reward callback; (4) reward fires before dismiss ⚠️ WRITE FIRST
- [ ] T043 Create `Rewarded/` directory in `Sources/Adapters/LiftoffAdapter/LiftoffAdapter/`
- [ ] T044 Create `LiftoffRewardedAd` in `Sources/Adapters/LiftoffAdapter/LiftoffAdapter/Rewarded/LiftoffRewardedAd.swift` — `public final class LiftoffRewardedAd: MSPiOSCore.RewardedAd`; holds `VungleRewarded?`; wire `RewardedLifecycleController`; implement `VungleRewardedDelegate`: `rewardedAdDidTrackImpression` → `markDisplayed()`, `rewardedAdDidClick` → `markClicked()`, `rewardedAdDidRewardUser` → `markRewardEarned()`, `rewardedAdDidClose` → `markDismissed()`, `rewardedAdDidFailToPresent` → `onError()`
- [ ] T045 Replace `.rewarded` error branch in `LiftoffAdapter.loadAdCreative` with load logic — create `VungleRewarded(placementId:)`, set delegate, call `load(adm)`; on success create `LiftoffRewardedAd`, store in `AdCache`, call `auctionBidListener.onBidSuccess()`
- [ ] T046 Run T042 tests — confirm all `LiftoffRewardedAdTests` pass

### Moloco

- [ ] T047 [P] Write failing Quick/Nimble tests for `MolocoRewardedAd` in `Tests/AdapterTests/Specs/MolocoRewardedAdTests.swift` ⚠️ WRITE FIRST
- [ ] T048 Create `Rewarded/` directory in `Sources/Adapters/MolocoAdapter/MolocoAdapter/`
- [ ] T049 Create `MolocoRewardedAd` in `Sources/Adapters/MolocoAdapter/MolocoAdapter/Rewarded/MolocoRewardedAd.swift` — `public final class MolocoRewardedAd: MSPiOSCore.RewardedAd`; holds `MolocoRewardedInterstitial?`; wire `RewardedLifecycleController`; implement `MolocoRewardedInterstitialDelegate`: `didShowRewardedInterstitialAd` → `markDisplayed()`, `didClickRewardedInterstitialAd` → `markClicked()`, `userDidEarnReward` → `markRewardEarned()`, `didCloseRewardedInterstitialAd` → `markDismissed()`
- [ ] T050 Replace `.rewarded` error branch in `MolocoAdapter.loadAdCreative` with load logic — `Moloco.shared.createRewardedInterstitial(params:)`, set delegate, `load(bidResponse: adm)`
- [ ] T051 Run T047 tests — confirm pass

### Mintegral

- [ ] T052 [P] Write failing Quick/Nimble tests for `MintegralRewardedAd` in `Tests/AdapterTests/Specs/MintegralRewardedAdTests.swift` ⚠️ WRITE FIRST
- [ ] T053 Create `Rewarded/` directory in `Sources/Adapters/MintegralAdapter/MintegralAdapter/`
- [ ] T054 Create `MintegralRewardedAd` in `Sources/Adapters/MintegralAdapter/MintegralAdapter/Rewarded/MintegralRewardedAd.swift` — `public final class MintegralRewardedAd: MSPiOSCore.RewardedAd`; holds `MTGRewardAdManager?`; wire `RewardedLifecycleController`; implement `MTGRewardAdShowDelegate`: `onVideoAdShowSuccess` → `markDisplayed()`, `onVideoAdClicked` → `markClicked()`, `onVideoAdDismissed(_:converted:rewardInfo:)` → if `converted` { `markRewardEarned()` } then `markDismissed()`, `onVideoAdShowFailed` → `onError()`
- [ ] T055 Replace `.rewarded` error branch in `MintegralAdapter.loadAdCreative` with load logic — create `MTGRewardAdManager(placementId:unitId:)`, set delegates, `loadAd(withBidToken:)`
- [ ] T056 Run T052 tests — confirm pass

### MobileFuse

- [ ] T057 [P] Write failing Quick/Nimble tests for `MobilefuseRewardedAd` in `Tests/AdapterTests/Specs/MobilefuseRewardedAdTests.swift` ⚠️ WRITE FIRST
- [ ] T058 Create `Rewarded/` directory in `Sources/Adapters/MobilefuseAdapter/MobilefuseAdapter/`
- [ ] T059 Create `MobilefuseRewardedAd` in `Sources/Adapters/MobilefuseAdapter/MobilefuseAdapter/Rewarded/MobilefuseRewardedAd.swift` — `public final class MobilefuseRewardedAd: MSPiOSCore.RewardedAd`; holds `MFRewardedAd?`; wire `RewardedLifecycleController`; implement `IMFAdCallbackReceiver`: `onAdRendered` → `markDisplayed()`, `onAdClicked` → `markClicked()`, `onUserEarnedReward` → `markRewardEarned()`, `onAdClosed` → `markDismissed()`, `onAdError` → `onError()`
- [ ] T060 Replace `.rewarded` error branch in `MobilefuseAdapter.loadAdCreative` with load logic — create `MFRewardedAd(placementId:)`, register callback, `load()`
- [ ] T061 Run T057 tests — confirm pass

### PubMatic OpenWrap

- [ ] T062 [P] Write failing Quick/Nimble tests for `PubmaticRewardedAd` in `Tests/AdapterTests/Specs/PubmaticRewardedAdTests.swift` ⚠️ WRITE FIRST
- [ ] T063 Create `Rewarded/` directory in `Sources/Adapters/PubmaticAdapter/PubmaticAdapter/`
- [ ] T064 Create `PubmaticRewardedAd` in `Sources/Adapters/PubmaticAdapter/PubmaticAdapter/Rewarded/PubmaticRewardedAd.swift` — `public final class PubmaticRewardedAd: MSPiOSCore.RewardedAd`; holds `POBRewardedAd?`; wire `RewardedLifecycleController`; implement `POBRewardedAdDelegate`: `rewardedAdDidRecordImpression` → `markDisplayed()`, `rewardedAdDidClick` → `markClicked()`, `rewardedAd(_:didReward:)` → `markRewardEarned()`, `rewardedAdDidDismiss` → `markDismissed()`, `rewardedAdDidFailToShow` → `onError()`
- [ ] T065 Replace `.rewarded` error branch in `PubmaticAdapter.loadAdCreative` with load logic — `POBRewardedAd(publisherId:profileId:adUnitId:)`, set delegate, `loadAd()`
- [ ] T066 Run T062 tests — confirm pass

### InMobi

- [ ] T067 [P] Write failing Quick/Nimble tests for `InmobiRewardedAd` in `Tests/AdapterTests/Specs/InmobiRewardedAdTests.swift` ⚠️ WRITE FIRST
- [ ] T068 Create `Rewarded/` directory in `Sources/Adapters/InmobiAdapter/InmobiAdapter/`
- [ ] T069 Create `InmobiRewardedAd` in `Sources/Adapters/InmobiAdapter/InmobiAdapter/Rewarded/InmobiRewardedAd.swift` — `public final class InmobiRewardedAd: MSPiOSCore.RewardedAd`; holds `IMInterstitial?`; wire `RewardedLifecycleController`; implement `IMInterstitialDelegate`: `interstitialDidPresent` → `markDisplayed()`, `interstitial(_:rewardActionCompletedWithRewards:)` → `markRewardEarned()`, `interstitialDidDismiss` → `markDismissed()`, `interstitial(_:didFailToPresentWithError:)` → `onError()`. **Note**: InMobi uses same `IMInterstitial` class for interstitial and rewarded — the server placement type determines reward eligibility.
- [ ] T070 Replace `.rewarded` error branch in `InmobiAdapter.loadAdCreative` with load logic — `IMInterstitial(placementId:delegate:)`, `load()`
- [ ] T071 Run T067 tests — confirm pass

### Unity / LevelPlay (IronSource)

- [ ] T072 [P] Write failing Quick/Nimble tests for `UnityRewardedAd` in `Tests/AdapterTests/Specs/UnityRewardedAdTests.swift` ⚠️ WRITE FIRST
- [ ] T073 Create `Rewarded/` directory in `Sources/Adapters/UnityAdapter/UnityAdapter/`
- [ ] T074 Create `UnityRewardedAd` in `Sources/Adapters/UnityAdapter/UnityAdapter/Rewarded/UnityRewardedAd.swift` — `public final class UnityRewardedAd: MSPiOSCore.RewardedAd`; holds `LPMRewardedAd?`; wire `RewardedLifecycleController`; implement `LPMRewardedAdDelegate`: `didDisplayAd` → `markDisplayed()`, `didClickAd` → `markClicked()`, `didRewardAd(_:reward:)` → `markRewardEarned()`, `didCloseAd` → `markDismissed()`, `didFailToDisplayAd` → `onError()`
- [ ] T075 Replace `.rewarded` error branch in `UnityAdapter.loadAdCreative` with load logic — `LPMRewardedAd(adUnitId:)`, `setDelegate(self)`, `loadAd()`
- [ ] T076 Run T072 tests — confirm pass

### Amazon APS — DEFERRED

- [ ] T077 ⏸️ Amazon APS Rewarded — deferred pending iOS API confirmation. Keep an explicit unsupported `.rewarded` branch in `AmazonAdapter`.

### Phase 9 Polish

- [ ] T078 Update all `*.yml.template` files for all 7 adapter modules to include new `Rewarded/XxxRewardedAd.swift` files; run `xcodegen generate`
- [ ] T079 Run `./Scripts/target-switching/round-trip-test.sh` to validate all SDK modes compile
- [ ] T080 Run full test suite — confirm existing tests pass + all new adapter rewarded tests pass

**Checkpoint**: All adapters (except Amazon) have rewarded support code-ready. Enabling any adapter = server config change only.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundation)**: Depends on Phase 1 — BLOCKS all user stories
- **Phase 3 (US1)**: Depends on Phase 2 — first user story, uses Google adapter
- **Phase 4 (US2)**: Depends on Phase 3 — reward callback wired into Google adapter
- **Phase 5 (US3)**: Depends on Phase 2 — can start in parallel with Phase 3/4
- **Phase 6 (US4)**: Depends on Phase 4 — adds Facebook + other adapters
- **Phase 7 (US5)**: Depends on Phase 2 — Debug UI independent of adapter layer
- **Phase 8 (Polish)**: Depends on all phases complete (for v1 scope)
- **Phase 9 (All-Network Expansion)**: Depends on Phase 2 (Foundation) — each adapter is independent; can run in parallel with Phase 3-8 or after them

### User Story Dependencies

- **US1 (P1)**: Requires Foundation complete + Google adapter
- **US2 (P1)**: Requires US1 complete (lifecycle controller wired into Google)
- **US3 (P2)**: Requires Foundation complete; can run in parallel with US1/US2
- **US4 (P2)**: Requires US2 complete (pattern established via Google)
- **US5 (P3)**: Requires Foundation complete (`AdFormat.rewarded` exists); independent of adapters

### Parallel Opportunities

- T004, T005, T006 (write tests) — all in parallel
- T008, T009 (Reward struct, AdRequest extension) — parallel within Foundation
- T022 (write US3 test first), then T023, T024 parallel
- T028 (no-op adapters) — all files independent, fully parallel
- T030, T031, T032 (Debug models) — parallel
- T035–T040 (Polish) — T037, T038, T039, T040 parallel after T035+T036
- **Phase 9 all adapters (T042-T076) — fully parallel per adapter after T041**:
  - T042-T046 (Liftoff), T047-T051 (Moloco), T052-T056 (Mintegral), T057-T061 (MobileFuse), T062-T066 (PubMatic), T067-T071 (InMobi), T072-T076 (Unity) — all 7 adapter groups run in parallel

---

## Parallel Example: Foundation Phase (Phase 2)

```
# Write all tests in parallel first:
Task T004: RewardTests.swift
Task T005: RewardedAdTests.swift
Task T006: RewardedLifecycleControllerTests.swift

# Then implement (T007 first — triggers exhaustiveness warnings as checklist):
Task T007: AdFormat.swift — add .rewarded
Task T008: Reward.swift (parallel with T009)
Task T009: AdRequest.swift (parallel with T008)
Task T010: RewardedAd.swift (after T008)
Task T011: AdListener.swift
Task T012: RewardedLifecycleController.swift (after T006 tests fail)
Task T013: MSPAdLoader.swift — `.rewarded` routing unchanged; unsupported adapters self-reject
```

---

## Implementation Strategy

### MVP (US1 + US2 only — Google Rewarded working end-to-end)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundation (with TDD — tests first)
3. Complete Phase 3: US1 (Google load + show)
4. Complete Phase 4: US2 (reward callback)
5. **STOP and VALIDATE**: Google Rewarded ad loads, shows, delivers reward callback exactly once, no false triggers
6. Demo to stakeholders — this is the shippable MVP

### Incremental Delivery

1. MVP (Phases 1–4) → Google Rewarded working
2. Add Phases 5 + 6 → Facebook + reward config + all adapters no-crash
3. Add Phase 7 → Debug tooling
4. Phase 8 → Polish + full regression
5. **Phase 9 → All-network adapter expansion (code-ready, server-gated)**

### Team Split (if parallel)

- **Dev A**: Phases 2–4 (Foundation + Google adapter)
- **Dev B**: Phase 6 US4 Facebook (can start after Phase 2 done)
- **Dev C**: Phase 7 US5 Debug (can start after Phase 2 done, fully independent)
- **Dev D-J** (or Codex agents): Phase 9 adapters — one per adapter, all in parallel after T041

---

## Notes

- T007 (`AdFormat.rewarded`) intentionally triggers compiler warnings in all adapters — use warning list as exhaustive checklist for T028
- Constitution Article V: tests T004–T006, T015, T019, T022, T025 MUST be written before their corresponding implementations
- Constitution Article I.2: never edit `.xcodeproj` directly — always `*.yml.template` + XcodeGen (T035)
- Constitution Article III.1: `RewardedAd` and `RewardedLifecycleController` live in Core — zero third-party imports
- ⚠️ FR-002 (reward optional) pending product confirmation — T023/T024 implement as optional; revisit if server requires mandatory
- T016 creates `GoogleRewardedAd` skeleton (load/show path only); T020 wires `RewardedLifecycleController` (reward/dismiss callbacks) — intentional US1/US2 story boundary
- Design decision: no `supportsRewardedAd()` capability probe API. Unsupported adapters return explicit errors from their own `.rewarded` branches; `MSPAdLoader` routing is unchanged.
- **Server-gated rollout**: Server placement config controls which adapters bid. Adapter implementations stay on the existing routing path and either load rewarded or return an explicit unsupported error.
- Phase 9 adapters follow the exact same pattern as Google/Facebook: create `XxxRewardedAd` subclass, wire `RewardedLifecycleController`, replace error branch in `loadAdCreative`
- Each Phase 9 adapter is fully independent — can be assigned to different developers or Codex agents in parallel
- Amazon APS deferred (T077) — keep an explicit unsupported `.rewarded` branch until iOS API is confirmed
