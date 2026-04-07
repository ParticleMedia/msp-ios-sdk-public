# Two-Part Playable Banner Spacing Analysis

> **Date**: 2026-04-03
> **Branch**: `fix/rewarded-lifecycle-and-playable-spacing`
> **Status**: Implemented

## Issue

在 two-part playable interstitial 的第二段 playable 页面里，底部 app install banner 下方存在明显空白。当前布局把底部 safe area 和额外 22pt padding 叠加在一起，导致 banner 下方视觉上过厚。

## Root Cause

历史实现直接写死：

```swift
make.height.equalTo(UIApplication.novaSafeAreaInsets.bottom + 22)
```

这让 `bottomBar` 同时承担了两层语义：

- 有 Home Indicator 的设备上，safe area 与 22pt 叠加
- 无 Home Indicator 的设备上，22pt 又是唯一底部间距来源

正确的语义不是 “永远 safeArea + 22”，而是 “保留 safe area，且至少给一个最小底边距”。

## Implementation

当前实现将该规则提取为纯函数：

```swift
enum NovaTwoPartPlayableLayoutMetrics {
    static let minimumBottomBannerInset: CGFloat = 12

    static func bottomBannerInset(for safeAreaBottom: CGFloat) -> CGFloat {
        max(safeAreaBottom, minimumBottomBannerInset)
    }
}
```

布局层只消费这个结果：

```swift
make.height.equalTo(
    NovaTwoPartPlayableLayoutMetrics.bottomBannerInset(for: UIApplication.novaSafeAreaInsets.bottom)
)
```

这样可以把布局规则和 view hierarchy 分离出来，单测只验证纯函数行为。

## Tests

- Quick/Nimble: `Tests/NovaCoreTests/Specs/Interstitial/NovaTwoPartPlayableLayoutMetricsSpec.swift`
- YAML test cases: `packages/test-cases/interstitial/TwoPartPlayableBanner.yaml`

覆盖点：

- `TPB001`: safe area 为 34 时返回 34
- `TPB002`: safe area 为 0 时返回 12
- `TPB003`: safe area 为 8 时返回 12

## Scope

- 仅影响 two-part playable interstitial 第二段的 banner 底部 inset
- 无 banner 场景不受影响
- rewarded lifecycle 优化与本问题解耦，但同处当前优化分支
