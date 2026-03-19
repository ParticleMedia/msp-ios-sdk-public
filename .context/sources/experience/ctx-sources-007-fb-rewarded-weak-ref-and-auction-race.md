---
id: ctx-sources-007
title: "Facebook Rewarded 广告加载成功但 auction 超时 — weak var 提前释放 + 竞态条件"
domain: sources
layer: experience
tags: [facebook, rewarded, weak-reference, arc, race-condition, concurrent-queue, auction, timeout, facebook-rewarded-ad, msp-auction]
triggers:
  - "Adapter: Facebook] successfully loaded Facebook Rewarded ad"
  - "Auction: Load Ad] time out. No winning bid"
  - "facebookRewardedAd=false"
  - "GUARD FAILED in rewardedVideoAdDidLoad"
  - "rewarded ad loaded but not displayed"
  - "FB rewarded timeout"
  - "auction timeout rewarded"
summary: "FB Rewarded loaded but auction timeout: weak var released by ARC + concurrent queue race on completionCalled"
version: "1.0"
status: active
created: "2026-03-19"
updated: "2026-03-19"
---

# Facebook Rewarded 广告加载成功但 auction 超时 — weak var 提前释放 + 竞态条件

## 问题描述

DemoApp 加载 Facebook Rewarded 广告时，日志显示：
1. `[Adapter: Facebook] successfully loaded Facebook Rewarded ad` — FB SDK 加载成功
2. 紧接着 `[Auction: Load Ad] time out. No winning bid` — auction 报超时失败

广告加载成功了但无法展示。即使将 auction timeout 从 8s 增大到 30s，问题仍然存在。

### 关键症状

- FB SDK `rewardedVideoAdDidLoad` 正常回调
- 但 `auctionBidListener.onSuccess(bid:)` 从未被调用
- `dispatchGroup.leave()` 从未触发，auction 一直等到超时
- 诊断日志显示：`GUARD FAILED — facebookRewardedAd=false, adRequest=true, auctionBidListener=true`

## 根因分析

### Bug 1: weak var 提前释放（主因）

`FacebookAdapter.swift` 中：

```swift
// L98
private weak var facebookRewardedAd: FacebookRewardedAd?
```

在 `loadAdCreative` 的 `.rewarded` 分支中：

```swift
let facebookRewardedAd = FacebookRewardedAd(...)  // 创建对象
self.facebookRewardedAd = facebookRewardedAd       // 赋给 weak var
rewardedVideoAdItem.load(withBidPayload: adString) // 异步加载，立即返回
```

问题链：
1. `FacebookRewardedAd` 被创建，唯一的引用是 `self.facebookRewardedAd`（weak）
2. `loadAdCreative` 方法返回 → 局部变量 `facebookRewardedAd` 释放
3. 没有其他 strong reference → ARC 释放 `FacebookRewardedAd`
4. FB SDK 异步回调 `rewardedVideoAdDidLoad` 触发时：
   ```swift
   guard let facebookRewardedAd = self.facebookRewardedAd  // nil!
   else { return }  // 静默返回，bid 永远不报给 auction
   ```

### 为什么 Native/Interstitial 没有这个问题

`facebookNativeAd` 和 `facebookInterstitialAd` 也是 `weak var`，但它们能工作是因为：
- Native/Interstitial 的 FB SDK 回调在同一次 run loop 迭代内返回（不需要额外网络请求）
- 在 `loadAdCreative` 的调用栈还没返回时，delegate callback 就已经执行了
- 局部变量还在 scope 内，对象没被释放

Rewarded 不同：FB SDK 需要向 `ep1.facebook.com` 发起**第二次网络请求**下载视频素材。这是异步的，回调在 `loadAdCreative` 返回之后才触发 → weak var 已经是 nil。

### Bug 2: MSPAuction 竞态条件（次因，独立问题）

`MSPAuction.finishOnceOnBiddingQueue` 在 concurrent queue 上没有锁保护：

```swift
// biddingDispatchQueue 是 .concurrent
private func finishOnceOnBiddingQueue(_ block: () -> Void) {
    if completionCalled { return }  // 无锁读
    completionCalled = true         // 无锁写
    block()
}
```

当 timeout 的 block 和 `dispatchGroup.notify` 的 block 同时在 concurrent queue 上执行时：
1. 两个 block 都读到 `completionCalled = false`
2. 两个 block 都设为 `true`
3. 两个 block 都调用各自的回调（`onError` + `onSuccess`）
4. `onError` 先被 DemoApp 消费 → 标记失败

此竞态条件在 Banner/Native/Interstitial 上几乎不会触发（因为 adapter load 很快，远在 timeout 之前完成）。只有 Rewarded 的两段网络请求让时序逼近 timeout 边界时才会暴露。

## 解决方案

### 修复 Bug 1: 移除 weak

`Sources/Adapters/MSPFacebookAdapter/MSPFacebookAdapter/FacebookAdapter.swift`:

```diff
- private weak var facebookRewardedAd: FacebookRewardedAd?
+ private var facebookRewardedAd: FacebookRewardedAd?
```

注意 retain cycle 风险：`FacebookRewardedAd` 初始化时接收 `adNetworkAdapter: self`（FacebookAdapter）。如果 `FacebookRewardedAd` 内部对 `adNetworkAdapter` 是 strong reference，则会产生 retain cycle。需确认 `FacebookRewardedAd` 内部使用 `weak var adNetworkAdapter`。

### 修复 Bug 2: 加锁保护 completionCalled

`Sources/Core/MSPCore/MSPCore/MSPAuction.swift`:

```diff
  private func finishOnceOnBiddingQueue(_ block: () -> Void) {
      dispatchPrecondition(condition: .onQueue(biddingDispatchQueue))
-     if completionCalled {
-         return
-     }
-     completionCalled = true
-     block()
+     taskLock.lock()
+     let alreadyCalled = completionCalled
+     if !alreadyCalled {
+         completionCalled = true
+     }
+     taskLock.unlock()
+     guard !alreadyCalled else { return }
+     block()
  }
```

### 验证

1. Clean build (Cmd+Shift+K → Cmd+B)
2. 在 DemoApp 中加载 Facebook Rewarded 广告
3. 确认日志中 `[Adapter: Facebook] successfully loaded` 后出现 `[Auction: Load Ad] completed. winner: audienceNetwork`
4. 确认可以成功展示广告（点击 Show 按钮）

## 适用场景

- Facebook Rewarded 广告加载成功但无法展示
- 任何 adapter 使用 `weak var` 持有异步创建的广告对象
- Auction timeout 即使增大仍然失败
- 新增 adapter 类型时需要检查引用关系

## 防范措施

1. **adapter 中持有异步广告对象必须用 strong reference**：如果广告对象需要在异步回调中使用，不能用 weak var。通过让广告对象内部用 `weak var` 引用 adapter 来避免 retain cycle。
2. **concurrent queue 上的共享状态必须加锁**：`completionCalled` 类型的 flag 在 concurrent queue 上必须用 NSLock 或其他同步原语保护。
3. **guard-else 必须有诊断日志**：`guard let ... else { return }` 的 else 分支应该打印错误日志，不能静默 return。否则调试时无法定位问题。

## 相关资源

- 分支: `feature/reward-ads`
- 文件: `FacebookAdapter.swift` (L98, L509-537), `MSPAuction.swift` (L80-87)
- 关联: `MSPBidder.swift` (adapter 创建流程), `MSPAdLoader.swift` (auction timeout 配置)

## 关联 Playbooks

- `ctx-sources-001`: Swift 最佳实践 — weak/strong reference 使用原则
