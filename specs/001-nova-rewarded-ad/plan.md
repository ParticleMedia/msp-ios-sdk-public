# Implementation Plan: Nova Rewarded Ad

**Branch**: `001-nova-rewarded-ad` | **Date**: 2026-03-26 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-nova-rewarded-ad/spec.md`

## Summary

Add Nova Rewarded Video Ad support to the MSP iOS SDK. The approach is:
1. Extract shared full-screen ad abstractions (base class + base VC) from existing interstitial infrastructure
2. Build Nova rewarded ad on top of the new abstractions
3. Add `novaNativeBridge.onAdRewarded()` JSBridge interface for H5→Native reward notification
4. Map Nova rewarded request to `placement = <publisher placementId>` (FR-017a, passthrough) and `ad_format = rewarded_video` (FR-017b, enum)
5. Make `RewardedAd.reward` optional and clean up adapter fallbacks

## Technical Context

**Language/Version**: Swift 5.0
**Primary Dependencies**: UIKit, WebKit (WKWebView), PrebidMobile, NovaCore, MSPiOSCore
**Storage**: N/A
**Testing**: Quick ~> 7.0, Nimble ~> 13.0, OHHTTPStubs/Swift ~> 9.1
**Target Platform**: iOS 15.0+
**Project Type**: Mobile SDK (library, distributed via CocoaPods)
**Performance Goals**: H5 content rendering latency on par with existing interstitial H5 ads; preserve PRD rewarded-video playback assumptions (`is_auto_play = true`, no native countdown UI)
**Constraints**: Backward compatible — existing interstitial behavior must not change; rewarded load success requires a renderable H5 rewarded-video creative
**Scale/Scope**: ~15 files modified, ~5 new files created

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Article | Requirement | Status | Notes |
|---------|-------------|--------|-------|
| I.2 (Deterministic Builds) | No direct `.xcodeproj` modifications | PASS | New files added via `*.yml.template` + XcodeGen |
| I.3 (SSOT) | Podfile is sole dependency authority | PASS | No new dependencies |
| II.2 (Local Verification) | Run round-trip test before commit | PASS | Will run `./Scripts/target-switching/round-trip-test.sh` |
| III.1 (Module Cohesion) | No third-party SDK imports in Core modules | PASS | All changes in NovaCore/NovaAdapter stay within module boundaries |
| III.2 (Protocol-Oriented Design) | Use protocols for interactions | PASS | `NovaInterstitialAdDelegate`, `NovaRewardedAdDelegate` — independent protocols per format |
| IV.1 (Value-Types First) | Prefer struct/enum for data | PASS | `Reward` is already a struct |
| IV.3 (Safe Error Handling) | No force-unwraps, DocC on public APIs | PASS | Will add DocC to all new public APIs |
| V.1 (TDD Cycle) | Tests for all new features | DEFERRED | Unit tests (T026-T027) deferred; manual DemoApp + log verification done |

**Post-Design Re-check**: All gates still pass. No new dependencies, no `.xcodeproj` changes, protocol-first design.

## Project Structure

### Documentation (this feature)

```text
specs/001-nova-rewarded-ad/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0: refactoring research
├── data-model.md        # Phase 1: entity model
├── contracts/
│   └── jsbridge-contract.md  # JSBridge interface contract
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
Sources/
├── Core/
│   ├── MSPiOSCore/MSPiOSCore/
│   │   └── api/
│   │       └── RewardedAd.swift              # MODIFY: reward → Reward?
│   │
│   └── NovaCore/NovaCore/
│       ├── FullScreen/                        # NEW: shared full-screen abstractions
│       │   ├── Models/
│       │   │   └── NovaFullScreenAdItem.swift  # Extracted from NovaInterstitialAdItem
│       │   └── NovaFullScreenAdViewController.swift  # Extracted from NovaInterstitialAdViewController
│       │
│       ├── Interstitial/                      # MODIFY: refactor to use FullScreen base
│       │   ├── Models/
│       │   │   ├── NovaInterstitialAdItem.swift      # Now inherits NovaFullScreenAdItem
│       │   │   └── NovaInterstitialAdDelegate.swift   # Independent protocol (: AnyObject)
│       │   └── NovaInterstitialAdViewController.swift # Now inherits NovaFullScreenAdViewController
│       │
│       ├── Rewarded/                          # NEW: rewarded ad module
│       │   ├── Models/
│       │   │   ├── NovaRewardedAdItem.swift
│       │   │   └── NovaRewardedAdDelegate.swift
│       │   └── NovaRewardedAdViewController.swift
│       │
│       ├── Media/Html/
│       │   ├── NovaAdHtmlView.swift           # MODIFY: inject onAdRewarded + handle action
│       │   └── NovaAdHtmlJSMessage.swift      # MODIFY: add didEarnReward() to delegate
│       │
│       └── Internal/
│           └── NovaAdBuilder.swift            # MODIFY: add buildRewardedAds()
│
└── Adapters/
    └── NovaAdapter/NovaAdapter/
        ├── NovaAdapter.swift                  # MODIFY: add rewarded branch
        └── Rewarded/
            └── NovaRewardedAd.swift           # NEW: RewardedAd subclass wrapping NovaRewardedAdItem

Serving/H5 contract (non-native ownership):
- Nova request `ad_format = rewarded_video` (enum, FR-017b); `placement` is publisher-supplied placementId (FR-017a)
- Recall eligibility: Phase 1 is `type == VIDEO && video_length_sec >= 10`; `PLAYABLE_VIDEO` is hard-filtered by the Ad Server and deferred to a future phase (per MON Tech Design)
- H5 UX: countdown ceiling = server-supplied `rewardedVideoCountdownSec` (AB key `h5_reward_countdown_second`, default 30, independent of video length); template auto-transitions to end card when video finishes early; skip/end-card/close-button flow; `is_mute = false`, `is_loop = false`, `is_auto_play = true`

Tests/
└── NovaCoreTests/
    └── Rewarded/                              # NEW: unit tests
        └── NovaRewardedAdSpec.swift
```

**Structure Decision**: Follow existing module layout conventions. New `FullScreen/` directory in NovaCore for shared abstractions. New `Rewarded/` directories mirror the `Interstitial/` pattern in both NovaCore and NovaAdapter.
