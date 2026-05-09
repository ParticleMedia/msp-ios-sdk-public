# Quickstart: Nova Rewarded Ad Implementation

**Date**: 2026-03-26
**Branch**: `001-nova-rewarded-ad`

## Prerequisites

- Development mode: `make open` or `./Scripts/switch-target.sh pods-dev`
- Clean working directory on `001-nova-rewarded-ad` branch

## Implementation Order

The implementation has a strict dependency chain:

```
Phase 1: RewardedAd.reward optional化
    ↓ (no downstream dependency on this, can be parallel)
Phase 2: Extract FullScreen abstractions from Interstitial
    ↓
Phase 3: Build NovaRewardedAdItem + NovaRewardedAdViewController
    ↓
Phase 4: JSBridge onAdRewarded injection + handling
    ↓
Phase 5: NovaAdapter rewarded branch + NovaRewardedAd
    ↓
Phase 6: Event reporting (`rewarded_video` request/event placement)
    ↓
Phase 7: PRD H5/serving contract validation
    ↓
Phase 8: Tests + validation
```

## Key Files to Read First

Before starting implementation, read these files to understand the existing patterns:

| File | Why |
|------|-----|
| `Sources/Core/NovaCore/NovaCore/Interstitial/Models/NovaInterstitialAdItem.swift` | Understand what to extract into base class |
| `Sources/Core/NovaCore/NovaCore/Interstitial/NovaInterstitialAdViewController.swift` | Understand VC extraction scope |
| `Sources/Core/NovaCore/NovaCore/Media/Html/NovaAdHtmlView.swift` | JSBridge injection point |
| `Sources/Adapters/NovaAdapter/NovaAdapter/NovaAdapter.swift` | Adapter routing pattern |
| `Sources/Adapters/LiftoffAdapter/LiftoffAdapter/Rewarded/LiftoffRewardedAd.swift` | Reference: how other adapters build RewardedAd |
| `Sources/Core/MSPiOSCore/MSPiOSCore/internal/RewardedLifecycleController.swift` | Reward state machine |

## PRD Contract Checks

- Nova rewarded request `ad_format` must be `rewarded_video` (FR-017b enum). `placement` is whatever the publisher passes via AdRequest (FR-017a passthrough).
- Ad serving owns recall eligibility: Nova single video and playable video, `video_length >= 10s`.
- H5 owns countdown `min(video_length, 30s)`, reward trigger, skip/end-card/playable/close-button flow, `is_mute = false`, `is_loop = false`, `is_auto_play = true`.
- SDK load success requires a renderable H5 rewarded-video creative; missing or unsupported rewarded items should fail load.

## Validation Steps

After implementation, run in order:

1. `make test` — unit tests pass
2. `./Scripts/target-switching/round-trip-test.sh` — target switching compatibility (Article II.2)
3. Manual: Load a PRD-compliant Nova rewarded-video ad in DemoApp, verify callbacks fire correctly and request/event logs use `rewarded_video`
