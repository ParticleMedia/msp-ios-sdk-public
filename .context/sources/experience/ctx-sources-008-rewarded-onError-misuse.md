---
id: ctx-sources-008
title: "Rewarded Ad adapter 在 show 阶段错误调用 adListener.onError — 语义混淆"
domain: sources
layer: experience
tags: [rewarded, ad-listener, on-error, show-phase, auction, adapter, lifecycle, callback-semantics]
triggers:
  - "adListener?.onError in show()"
  - "rewarded ad onError called incorrectly"
  - "show failure triggers auction error callback"
  - "onError semantics rewarded"
  - "adListener onError show phase"
  - "rewarded ad present error callback"
summary: "Rewarded adapters incorrectly called adListener.onError in show phase; should only fire on auction/load failure."
version: "1.0"
status: active
created: "2026-03-24"
updated: "2026-03-24"
---

# Rewarded Ad adapter 在 show 阶段错误调用 adListener.onError

## 问题描述

所有 Rewarded ad adapter（Google, Liftoff, Unity, InMobi, Moloco, Mintegral, MobileFuse, PubMatic, Facebook）在 `show()` 阶段的错误场景中调用了 `adListener?.onError(msg:loadInfo:)`。

`AdListener.onError` 的正确语义是 **auction/load 失败**，由以下调用链触发：
```
MSPAuction.onError → MSPAdLoader.onError → adListener?.onError
```

但 Rewarded adapter 在两种 show 阶段场景中也误调了它：

### 场景 1: show() 前置检查失败
```swift
// show(rootViewController:) 中
guard let viewController = rootViewController else {
    adListener?.onError(msg: "Root view controller is required", loadInfo: [:])  // 错误!
    return
}
```

### 场景 2: 第三方 SDK show 回调失败
```swift
// SDK 的 didFailToPresent / failToShow 回调中
func handlePresentError(_ error: Error) {
    adListener?.onError(msg: error.localizedDescription, loadInfo: [:])  // 错误!
}
```

## 影响

- 宿主 app 在 show 阶段收到 `onError` 回调，误以为是 auction 失败
- 可能触发错误的重试逻辑或错误统计

## 根因

`AdListener` 协议的 `onError` 方法没有区分 load 错误和 show 错误，adapter 开发者在 show 阶段缺少合适的错误回调，于是复用了 `onError`。

## 修复方案

将 show 阶段的 `adListener?.onError(...)` 替换为 `MSPLogger.shared.error(...)`，仅记录日志，不回调给上层。

## 涉及文件

| Adapter | 文件 | 错误类型 |
|---------|------|----------|
| Google | `GoogleRewardedAd.swift` | 前置检查 + SDK 回调 |
| Google | `GoogleAdapter.swift` | Interstitial show 失败 |
| Liftoff | `LiftoffRewardedAd.swift` | 前置检查 + SDK 回调 |
| Unity | `UnityRewardedAd.swift` | 前置检查 + SDK 回调 |
| InMobi | `InmobiRewardedAd.swift` | 前置检查 + SDK 回调 |
| Moloco | `MolocoRewardedAd.swift` | 前置检查 + SDK 回调 |
| Mintegral | `MintegralRewardedAd.swift` | 前置检查 + SDK 回调 |
| MobileFuse | `MobilefuseRewardedAd.swift` | 前置检查 + SDK 回调 |
| PubMatic | `PubmaticRewardedAd.swift` | 前置检查 + SDK 回调 |
| Facebook | `FacebookRewardedAd.swift` | 前置检查 |

## 预防措施

新增 Rewarded adapter 时，`show()` 方法中的错误只用 `MSPLogger.shared.error` 记录，**不要调用 `adListener?.onError`**。如果未来需要 show 错误回调，应在 `AdListener` 协议中新增专用方法（如 `onShowError`）。

## 相关 PR

- #560: fix(rewarded): remove incorrect adListener.onError calls in show phase
- #561: fix(google): remove incorrect adListener.onError in interstitial show failure
