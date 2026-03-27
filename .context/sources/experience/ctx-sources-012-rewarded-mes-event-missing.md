---
id: ctx-sources-012
title: "广告 MES impression/click 上报缺失 — adapter 未调用基类 handleAdImpression/handleAdClicked"
domain: sources
layer: experience
tags: [mes, impression, click, revenue, rewarded, interstitial, native, banner, adapter, ad-metric-reporter, handle-ad-impression, handle-ad-clicked, lifecycle, critical]
triggers:
  - "MES missing"
  - "impression not reported"
  - "click not reported"
  - "logAdImpression not called"
  - "logAdClick not called"
  - "MES event dropped"
  - "revenue missing ad"
  - "handleAdImpression not called"
  - "handleAdClicked not called"
  - "adMetricReporter missing"
  - "rewarded MES missing"
  - "RewardedLifecycleController markDisplayed"
summary: "Calling adListener directly instead of handleAdImpression/handleAdClicked silently drops MES events — P0 revenue risk."
status: active
updated: "2026-03-27"
version: "1.0"
---

## 背景

**严重程度：P0 级别收入事故风险。** MES impression/click 是 SDK 的核心广告事件上报，直接影响广告收入计算。任何导致 MES 事件丢失的改动都属于重大事故，适用于所有 ad format（rewarded、interstitial、native、banner）和所有 adapter。

## 问题描述（复现案例：Rewarded MES 全量丢失）

所有 Rewarded 广告（Google、Facebook、Moloco、Liftoff、Mintegral、Mobilefuse）的 MES impression/click 事件从未被上报。

原因：`RewardedLifecycleController.markDisplayed()` 和 `markClicked()` 直接调用了 `adListener?.onAdImpression/onAdClick`，绕过了基类 `AdNetworkAdapter.handleAdImpression()/handleAdClicked()`。而 MES 上报只在基类方法里执行。

```swift
// ❌ 错误写法 — 只触发 listener，跳过 MES 上报
adListener?.onAdImpression(ad: ad)   // MES 永远不会被调用

// ✅ 正确写法 — 委托给基类，基类内部同时触发 listener + MES
ad.adNetworkAdapter?.handleAdImpression()
```

## 根因

`AdNetworkAdapter.handleAdImpression()` 和 `handleAdClicked()` 是 open func，内部同时调用：
1. `adListener?.onAdImpression(ad: mspAd)` — 通知 app
2. `adMetricReporter?.logAdImpression(...)` — MES 上报（**收入来源**）

任何绕过这两个基类方法、直接调用 adListener 的写法都会导致 MES 丢失。

## 影响范围

**不限于 Rewarded**：任何 ad format、任何 adapter 中，只要 impression/click 回调没有经过 `handleAdImpression()/handleAdClicked()`，MES 就会静默丢失。丢失期间没有任何报错或警告。

## 修复（Rewarded 案例）

PR: `fix/rewarded-mes-reporting` → develop

```swift
// RewardedLifecycleController.swift
public func markDisplayed() {
    guard let ad else { return }
    ad.adNetworkAdapter?.handleAdImpression()  // 基类方法，同时触发 listener + MES
}

public func markClicked() {
    guard let ad else { return }
    ad.adNetworkAdapter?.handleAdClicked()
}
```

## 注意事项

1. **避免双重回调**：在 adapter delegate 里，若 lifecycle controller 已调用 `handleAdImpression()`，不能再单独调用 `handleAdImpression()` 或 `adListener.onAdImpression`，否则 listener 触发两次。
2. **`handleAdImpression()` 是异步的**：内部用 `DispatchQueue.main.async`，unit test 必须用 `toEventually` 而非 `to`。
3. **test 必须设置 `adapter.mspAd`**：`handleAdImpression()` 内部 guard `let mspAd = mspAd`，若 nil 则静默退出，MES 和 listener 均不触发。
4. **test 必须设置 `adapter.adListener`**：`handleAdImpression()` 通过 `adapter.adListener` 调用 listener，不是通过 `sut.adListener`。

## 预防措施（所有 adapter / 所有 format）

新增或修改任何 adapter 的 impression/click 回调时，必须验证：
- impression 触发路径 → 最终调用 `handleAdImpression()`
- click 触发路径 → 最终调用 `handleAdClicked()`
- unit test 必须同时断言 `adListener` 回调 **和** `metricReporter.logAdImpressionCallCount / logAdClickCallCount`
