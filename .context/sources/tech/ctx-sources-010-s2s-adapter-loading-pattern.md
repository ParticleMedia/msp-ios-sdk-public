---
id: ctx-sources-010
title: "S2S Adapter 广告加载模式 — 两阶段流程与 mspAd 弱引用陷阱"
domain: sources
layer: tech
tags: [adapter, s2s, server-to-server, bidding, msp-ad, weak-reference, arc, handle-ad-loaded, rewarded, interstitial, native, banner]
triggers: [S2S adapter, server-to-server, loadAdCreative, handleAdLoaded, mspAd weak, ad load callback, 新增 adapter, adapter 加载流程]
summary: "S2S adapter 广告加载的两阶段流程说明，以及 mspAd 是弱引用、必须在回调中通过 handleAdLoaded 设置的关键约束"
version: "1.0"
status: active
created: 2026-03-24
updated: 2026-03-24
---

# S2S Adapter 广告加载模式

## 两阶段流程

S2S（Server-to-Server）Adapter 加载广告分为两个独立阶段：

```
阶段 1: Prebid Auction
  MSP Core → Prebid SDK → Ad Server
                              ↓
                         BidResponse (含 adm、price 等)

阶段 2: 第三方 SDK 加载
  Adapter.loadAdCreative(bidResponse:) 被调用
    → 构造第三方 Ad 对象（e.g. MolocoInterstitial）
    → 设置 delegate（接收回调）
    → 调用 Ad.load(adm)
    → [SDK 异步加载广告素材]
    → didLoad / didReceive 回调触发
    → 在回调中构造 MSP Ad 包装对象
    → 调用 handleAdLoaded(mspAd:)
```

## 阶段 2 的标准实现模式

```swift
// 在 loadAdCreative 中（@MainActor 保证主线程）
@MainActor
public override func loadAdCreative(...) {
    super.loadAdCreative(...)           // 设置 self.bidResponse 等公共属性
    guard let mBidResponse = self.bidResponse else { ... }

    // 1. 构造第三方 SDK Ad 对象
    let interstitialAdItem = ThirdPartyInterstitial(adUnitId: adUnitId)
    self.interstitialAdItem = interstitialAdItem  // 持有 strong reference

    // 2. 设置 delegate
    interstitialAdItem.delegate = self

    // 3. 发起加载（异步，立即返回）
    interstitialAdItem.load(bidResponse: adm)
}

// 在 SDK 加载成功回调中
public func didLoad(_ ad: ThirdPartyInterstitial) {
    DispatchQueue.main.async { [weak self] in
        guard let self else { return }

        // 4. 构造 MSP 包装对象
        let interstitialAd = MSPInterstitialAd(adNetworkAdapter: self)
        interstitialAd.interstitialAdItem = ad
        interstitialAd.rootViewController = adListener?.getRootViewController()

        // 5. 通过 handleAdLoaded 设置 mspAd 并通知 auction
        handleAdLoaded(mspAd: interstitialAd)
    }
}
```

## 关键约束：mspAd 是弱引用

`AdNetworkAdapter` 基类中：

```swift
public weak var mspAd: MSPAd?
```

**`mspAd` 是 `weak var`**，不持有对象的所有权。

### ❌ 错误做法：在 loadAdCreative 中提前设置 mspAd

```swift
// loadAdCreative 中
let rewardedAd = MyRewardedAd(adNetworkAdapter: self)
self.mspAd = rewardedAd    // ← 仅 weak 引用，无 strong holder
thirdPartyAd.load()        // 异步返回

// loadAdCreative 方法返回 → rewardedAd 局部变量离开作用域
// ARC 释放 MyRewardedAd（因为只有 weak mspAd 持有它）

// SDK 异步回调时：
guard let rewardedAd = self.mspAd  // nil！对象已被释放
else { return }  // 静默失败，广告无法展示
```

此问题在 Rewarded 广告中最易触发，因为 Rewarded SDK 通常需要第二次网络请求（下载视频素材），回调延迟远超 Banner/Native/Interstitial。

### ✅ 正确做法：在成功回调中创建并传入 handleAdLoaded

```swift
// SDK 成功回调
public func rewardedAdDidLoad(_ rewarded: ThirdPartyRewarded) {
    DispatchQueue.main.async { [weak self] in
        guard let self else { return }

        // 在 handleAdLoaded 调用时，局部变量 rewardedAd 仍在作用域内
        // handleAdLoaded 内部会将其传给 auctionBidListener.onSuccess
        // auction 层面会 hold strong reference
        let rewardedAd = MyRewardedAd(
            adNetworkAdapter: self,
            reward: adRequest?.reward ?? Reward(type: "reward", amount: 1)
        )
        handleAdLoaded(mspAd: rewardedAd)
    }
}
```

`handleAdLoaded` 内部流程：
1. `self.mspAd = mspAd`（weak 赋值）
2. `auctionBidListener.onSuccess(bid:)` — auction 层面获得 strong reference，对象得以存活

## 回调中的线程安全

所有 SDK 加载成功回调必须包裹 `DispatchQueue.main.async { [weak self] in ... }`，原因：

1. **HR-U1**：UIKit 操作（`getRootViewController()`、创建 UIView 子类）必须在主线程
2. **SDK 线程不确定性**：大多数第三方 SDK 不保证在主线程回调

标准包裹模式：

```swift
public func interstitialAdDidLoad(_ ad: ThirdPartyAd) {
    DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        // ... 构造 MSP Ad 对象、调用 handleAdLoaded
    }
}
```

## 新增 Adapter 检查清单

- [ ] `loadAdCreative` 中只构造第三方 Ad 对象，**不**设置 `mspAd`
- [ ] 第三方 Ad 对象用 `strong` 属性持有（`private var thirdPartyAd: ThirdPartyAd?`）
- [ ] SDK 成功回调中构造 MSP 包装对象，通过 `handleAdLoaded(mspAd:)` 设置
- [ ] SDK 回调用 `DispatchQueue.main.async { [weak self] in ... }` 包裹
- [ ] Rewarded 回调特别检查：是否有 strong reference 在 load 和回调之间持有对象

## 相关条目

- `ctx-sources-007`：Facebook Rewarded weak var 提前释放的具体案例
- `ctx-sources-001`：Swift 最佳实践（weak/strong reference 原则）
