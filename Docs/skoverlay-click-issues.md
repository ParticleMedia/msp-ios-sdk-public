# SK Overlay Click Tracking Issue Analysis

> **Date**: 2026-04-03
> **Branch**: `fix/skoverlay-click`
> **Status**: Implemented

## Issue

SK Overlay (download banner) 出现后，SDK 会在展示完成回调里立即 fire `thirdPartyTrackingURL`。在 HTML interstitial/page 链路中，该 URL 实际来自 `thirdPartyClickTrackingUrls`（MMP click tracking URL），会把展示错误记成点击，导致 CTR 接近 100%，提升 fraud rate。

## Root Cause

历史实现把 “overlay 展示成功” 和 “用户真实点击” 混在了一起：

```text
SKOverlay.present(in:)
  -> storeOverlayDidFinishPresentation()
  -> NovaTrackingUrlHelper.fire(url: thirdPartyTrackingURL)
```

但 `storeOverlayDidFinishPresentation()` 的语义只是系统确认 overlay 已展示，并不代表用户点击了 CTA popup、banner 或素材里的真实 CTA。

## Scope

本次修复只处理共享 `NovaSKOverlayController` 中的展示回调行为：

- 展示完成时不发 click
- 不在 `appDidEnterBackground()` 中补发 click
- 保留 `thirdPartyTrackingURL` 参数，暂不清理调用方
- 不改真实点击路径

## Implementation

当前实现把该行为提取为显式 decision：

```swift
func handleOverlayDidFinishPresentation() -> ThirdPartyTrackingDecision {
    registerShowTime()
    return .skip
}
```

`storeOverlayDidFinishPresentation` 只消费 decision：

```swift
switch handleOverlayDidFinishPresentation() {
case .fire(let trackingURL):
    NovaTrackingUrlHelper.fire(url: trackingURL)
case .skip:
    break
}
```

这样单测可以直接断言展示路径返回 `.skip`，不需要引入测试专用 spy seam。

## Tests

- Quick/Nimble: `Tests/NovaCoreTests/Specs/SKOverlay/NovaSKOverlayControllerSpec.swift`
- YAML test cases: `packages/test-cases/core/NovaSKOverlayController.yaml`

覆盖点：

- `SKO001`: 展示完成返回 `.skip`
- `SKO002`: 首次调用记录 show timestamp，重复调用不覆盖
- `SKO003`: `thirdPartyTrackingURL == nil` 时仍返回 `.skip`

## Unchanged Paths

- CTA popup 点击
- playable app install banner 点击
- HTML/MRAID CTA 点击
- download banner jump out metric
