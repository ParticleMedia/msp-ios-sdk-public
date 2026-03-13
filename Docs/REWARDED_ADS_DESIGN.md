# Rewarded Ads Design

## Background

根据需求文档 `MON-MSP SDK Rewarded Ads-100326-025856.pdf`，本次需求包含三部分：

1. 新增 `Rewarded` 广告格式
2. 在请求侧支持 reward 配置
3. 在展示生命周期中增加 reward callback

文档中给出的目标形态：

- Google: `REWARDED`
- Facebook: `REWARDED_VIDEO`
- MSP: `REWARDED`

MSP 对外期望调用方式：

```swift
let request = AdRequest(
    customParams: [:],
    geo: nil,
    context: nil,
    adaptiveBannerSize: nil,
    adSize: nil,
    placementId: placementId,
    adFormat: .rewarded
)
request.reward = Reward(type: "reward_type", amount: 1)
```

回调侧期望增加：

```swift
public protocol AdListener: AnyObject {
    func onAdRewardReceived(ad: MSPAd)
}
```

## Current State

当前项目已经具备较完整的全屏广告能力，但还没有 Rewarded 的一等公民建模。

现状要点：

- `AdFormat` 只有 `banner/native/multi_format/interstitial`
- `AdRequest` 没有 reward 字段
- `AdListener` 没有 reward callback
- `MSPAdLoader` 不识别 `rewarded`
- `NovaCore` 已有成熟的全屏展示能力，当前统一落在 `Interstitial` 语义
- 多数三方 adapter 已有 `InterstitialAd` 子类和对应的展示/回调桥接模式

这说明 Rewarded 不适合被实现成“仅在现有 Interstitial 上补一个事件”，也不适合第一版完全复制一套新的展示体系。更合适的方向是：

- 在 API 层把 Rewarded 建成独立广告格式
- 在展示实现层最大化复用现有 Interstitial / full-screen 能力
- 在生命周期层单独补 Rewarded 独有的 reward 状态机与回调

## Design Goals

### Functional Goals

- 业务方可以显式请求 `Rewarded` 广告
- 业务方可以在请求时传入 reward 配置
- SDK 能在用户满足奖励条件时触发统一回调
- Google / Facebook / MSP 自有广告都能映射到同一语义

### Non-Goals

- 第一版不追求 Rewarded 与 Interstitial 在 UI 实现层完全分叉
- 第一版不要求所有 adapter 同时支持 Rewarded；允许分阶段接入
- 第一版不在 reward callback 中暴露复杂的多来源 reward payload

## Recommended Architecture

## 1. API Layer

新增独立的 Rewarded 类型，而不是继续复用 `Interstitial`。

建议新增：

```swift
public enum AdFormat: CaseIterable {
    case banner
    case native
    case multi_format
    case interstitial
    case rewarded
}
```

```swift
public struct Reward: Equatable, Codable, Sendable {
    public let type: String
    public let amount: Int

    public init(type: String, amount: Int) {
        self.type = type
        self.amount = amount
    }
}
```

```swift
public final class RewardedRequest: Sendable {
    public let placementId: String
    public let reward: Reward
    public let customParams: [String: AnySendable]
    public let testParams: [String: AnySendable]

    public init(
        placementId: String,
        reward: Reward,
        customParams: [String: AnySendable] = [:],
        testParams: [String: AnySendable] = [:]
    ) {
        self.placementId = placementId
        self.reward = reward
        self.customParams = customParams
        self.testParams = testParams
    }
}
```

对现有体系的兼容建议：

- 保留 `AdRequest`
- 增加 `reward: Reward?`
- 增加 `asRewardedRequest() throws -> RewardedRequest`

这样做的原因：

- 兼容当前以 `AdRequest` 为中心的 loader / auction 链路
- 新的 Rewarded 逻辑可以围绕更窄、更稳定的 `RewardedRequest` 编写
- 单测时不需要构造一大堆与 reward 无关的可选字段

建议新增：

```swift
open class RewardedAd: MSPAd {
    open func show(rootViewController: UIViewController?) {
        fatalError("Subclass must override show(rootViewController:) method")
    }

    open func dismiss(animated: Bool) {
    }

    public let reward: Reward
}
```

不建议让 `RewardedAd` 继承 `InterstitialAd`。更推荐与 `InterstitialAd` 平级，原因如下：

- Rewarded 依然是全屏展示广告
- 但 Rewarded 的核心语义是“可获得奖励的全屏广告”，不是“可关闭的插屏”
- 如果继承 `InterstitialAd`，测试里很容易把 `dismiss` 与 `reward` 语义搅在一起
- 平级建模后，adapter 内部仍然可以复用插屏展示组件，但 public API 更干净

## 2. Listener Layer

在 `AdListener` 上增加默认空实现的 reward 回调，避免破坏现有接入方。

```swift
public protocol AdListener: AnyObject {
    func onAdRewardReceived(event: RewardedEvent)
}

public extension AdListener {
    func onAdRewardReceived(event: RewardedEvent) {}
}
```

这样做的好处：

- 所有现有实现类无需立刻修改
- Rewarded 接入方可以按需实现
- 回调是值对象，不依赖具体 ad 子类状态
- 单测时可以直接断言 event 内容，不需要 mock 一个完整 ad 对象

建议新增事件值类型：

```swift
public struct RewardedEvent: Equatable, Sendable {
    public let placementId: String
    public let requestId: String
    public let adUnitId: String?
    public let networkName: String?
    public let reward: Reward

    public init(
        placementId: String,
        requestId: String,
        adUnitId: String?,
        networkName: String?,
        reward: Reward
    ) {
        self.placementId = placementId
        self.requestId = requestId
        self.adUnitId = adUnitId
        self.networkName = networkName
        self.reward = reward
    }
}
```

如果一定要兼容需求文档里的 `func onAdRewardReceived(ad: MSPAd)`，建议保留它作为兼容层，内部转发到新事件接口：

```swift
public protocol AdListener: AnyObject {
    func onAdRewardReceived(event: RewardedEvent)
    func onAdRewardReceived(ad: MSPAd)
}
```

默认实现里让旧接口为空，新代码只使用事件接口。

## 3. Testability First Design

Rewarded 的核心逻辑不应该散落在各个 adapter delegate 回调里，而应该集中在一个纯 Swift 协调器中。

建议新增内部组件：

```swift
protocol RewardedLifecycleDriving: AnyObject {
    func markDisplayed()
    func markClicked()
    func markDismissed()
    func markRewardEarned()
}
```

```swift
protocol RewardedEventDispatching: AnyObject {
    func dispatchImpression(for ad: MSPAd)
    func dispatchClick(for ad: MSPAd)
    func dispatchDismiss(for ad: RewardedAd)
    func dispatchReward(_ event: RewardedEvent)
}
```

```swift
final class RewardedLifecycleController {
    private(set) var hasEarnedReward = false
    private(set) var hasDismissed = false
    private let eventDispatcher: RewardedEventDispatching
    private let rewardedEvent: RewardedEvent
    private unowned let ad: RewardedAd

    init(ad: RewardedAd, rewardedEvent: RewardedEvent, eventDispatcher: RewardedEventDispatching) {
        self.ad = ad
        self.rewardedEvent = rewardedEvent
        self.eventDispatcher = eventDispatcher
    }

    func markRewardEarned() {
        guard !hasEarnedReward else { return }
        hasEarnedReward = true
        eventDispatcher.dispatchReward(rewardedEvent)
    }

    func markDismissed() {
        guard !hasDismissed else { return }
        hasDismissed = true
        eventDispatcher.dispatchDismiss(for: ad)
    }
}
```

这个设计的价值：

- adapter delegate 只负责把三方回调翻译成 `mark...()`
- 幂等、顺序控制、回调分发都在一个地方
- 生命周期逻辑不依赖 UIKit，不依赖三方 SDK，单测成本很低
- 未来 Google / Facebook / MSP 自渲染都能复用同一个状态机

## 4. Loader / Auction Layer

`MSPAdLoader`、placement 配置解析、bidder format 映射都要补 `rewarded`。

建议改动点：

- `MSPAdLoader.getBidder` 支持 `"rewarded" -> .rewarded`
- `MSPBidder` / 各 network bidder 能接受 `.rewarded`
- `AdCache` 中继续以 `MSPAd` 存储，不必为缓存层额外分叉

如果 placement 配置由服务端下发，配置格式也需要同步支持：

```json
{
  "bidderFormat": "rewarded"
}
```

## 5. MSP Full-Screen Rendering Layer

当前 `NovaCore` 的全屏能力以 `NovaInterstitialAdItem` 为中心，建议 Rewarded 第一版复用这条链路，而不是新建完整的 `NovaRewardedAdViewController`。

推荐方案：

- 新增 `NovaRewardedAdItem`
- 复用现有的 `NovaInterstitialAdViewController`
- 通过 `RewardedLifecycleController` 管理 reward 状态

不建议 `NovaRewardedAdItem: NovaInterstitialAdItem` 直接继承。更推荐组合：

```swift
public final class NovaRewardedAdItem {
    let interstitialAdItem: NovaInterstitialAdItem
    let reward: Reward
    let lifecycleController: RewardedLifecycleController
}
```

组合优于继承的原因：

- 现有 `NovaInterstitialAdItem` 语义已经很重
- Rewarded 与 Interstitial 的差异主要在生命周期，不在素材结构
- 组合更容易 mock `lifecycleController`
- 以后如果 reward 只支持视频类，也不会污染插屏主模型

建议最少增加的能力：

```swift
public protocol NovaRewardedAdDelegate: AnyObject {
    func rewardedAdDidDisplay(_ rewardedAd: NovaRewardedAdItem)
    func rewardedAdDidDismiss(_ rewardedAd: NovaRewardedAdItem)
    func rewardedAdDidLogClick(_ rewardedAd: NovaRewardedAdItem)
    func rewardedAdDidEarnReward(_ event: RewardedEvent)
    func rewardedAdDidFailToDisplay(_ rewardedAd: NovaRewardedAdItem)
}
```

但更推荐 Nova 内部不要直接依赖 delegate 做业务回调，而是调用 `RewardedLifecycleController`。

## 6. Adapter Layer

各 adapter 需要显式支持 Rewarded，而不是强行把 Rewarded 当 Interstitial。

建议每个 adapter 按以下模式扩展：

- 新增 `RewardedAd` 子类
- 新增加载路径 `adFormat == .rewarded`
- 将三方 SDK 回调先桥接到 `RewardedLifecycleController`

adapter 层推荐职责边界：

- adapter delegate: 翻译平台回调
- `RewardedLifecycleController`: 维护顺序和幂等
- `AdListener`: 只接收最终业务事件

不建议 adapter 直接调用多个 listener 方法拼生命周期。那样测试会很碎，也很难保证不同 network 的一致性。

### Google Adapter

建议新增：

- `GoogleRewardedAd.swift`
- 对接 `GADRewardedAd`
- 在 `present` / `show` 时桥接 `userDidEarnRewardHandler`

语义映射：

- impression -> `markDisplayed()`
- click -> `markClicked()`
- dismiss -> `markDismissed()`
- earn reward -> `markRewardEarned()`

### Facebook Adapter

建议新增：

- `FacebookRewardedAd.swift`
- 对接 `FBRewardedVideoAd`

语义映射：

- `onRewardedVideoCompleted` -> `markRewardEarned()`
- `onRewardedVideoClosed` -> `markDismissed()`

注意顺序要求：

- `completed` 和 `closed` 可能是两个独立回调
- reward 必须保证只发一次
- 不要把 `closed` 误当作 reward

### MSP / Nova Adapter

若 MSP 自有全屏广告支持 Rewarded，需要明确奖励条件来源。建议优先约定：

- 视频类：完整播放后触发 reward
- HTML / playable 类：暂不支持 reward，或需要服务端明确条件

如果第一版没有严格的自渲染奖励判定能力，建议：

- Google / Facebook 先支持
- MSP 自渲染 Rewarded 暂挂 feature flag 或后续阶段接入

## 7. Reward Semantics

Rewarded 最大风险不在展示，而在语义统一。

建议统一定义：

`onAdRewardReceived(event:)` 表示“用户已经满足获得奖励的条件”。

不表示：

- 广告已关闭
- 广告已曝光
- 广告播放完成但未通过平台确认

### Reward Payload Source

需求文档显示 MSP 请求侧会传：

```swift
setReward("reward_type", 1)
```

因此建议第一版采用以下策略：

- reward 配置由 `AdRequest.reward` 提供
- callback 只表达“奖励已达成”
- 业务方需要奖励明细时，从 `ad.adInfo` 或原始 request 读取

如果后续确实需要把 reward detail 一并带回，第二版再考虑：

```swift
func onAdRewardReceived(ad: MSPAd, reward: Reward)
```

第一版不建议这样做，原因是：

- Google / Facebook / MSP 自有广告的 payload 结构不统一
- 会迫使 listener 接口一次性升级更多调用方
- 当前需求文档并未要求 callback 必须带 reward payload

## 8. State Machine

Rewarded 广告建议引入显式状态控制，至少保证 reward 幂等。

建议状态：

- `idle`
- `loaded`
- `displaying`
- `rewardEarned`
- `dismissed`

核心约束：

- `onAdRewardReceived` 最多触发一次
- `onAdRewardReceived` 不应由 `dismiss` 兜底触发
- `dismiss` 发生时如果未满足奖励条件，不发 reward

建议内部辅助字段：

```swift
var hasEarnedReward = false
var hasSentDismiss = false
```

建议把状态机限制在一个纯 Swift 类型里，不依赖 UIViewController、SDK delegate、timer 或缓存层。这样 Quick/Nimble 单测可以覆盖大部分行为。

## 9. Metrics and Logging

Rewarded 需要增加独立打点，否则后续无法区分“全屏展示成功”和“奖励发放成功”。

建议新增指标：

- rewarded load request
- rewarded load success / fail
- rewarded impression
- rewarded click
- rewarded earn reward
- rewarded dismiss

建议日志里至少带：

- placementId
- adFormat
- ad network
- requestId
- rewardType
- rewardAmount

## 10. Debug Tooling

当前 Debug 页面只覆盖了 `InterstitialAd` 等现有形态。Rewarded 接入后建议同步补齐：

- AdFormat 选择项新增 `rewarded`
- 测试参数支持 reward type / amount
- 展示路径支持 `RewardedAd`
- 增加 reward callback 的调试日志

建议在 debug 页面明确展示：

- 是否收到 `onAdRewardReceived`
- reward callback 是否早于 dismiss

## 11. Backward Compatibility

本方案可以做到对现有业务方低风险兼容。

兼容策略：

- `AdListener` 新增方法提供默认实现
- `InterstitialAd` 现有语义不变
- 原有 banner/native/interstitial 加载和展示路径不变
- 仅新增 `rewarded` 分支

需要注意的兼容点：

- 如果有 `switch adFormat` 的穷举代码，需要补 `rewarded`
- 如果有调试 UI 或测试用例依赖 `AdFormat.allCases`，会新增一个 case

## 12. Implementation Plan

### Phase 1: API and Core Modeling

- 新增 `AdFormat.rewarded`
- 新增 `Reward`
- `RewardedEvent`
- `AdRequest` 增加 `reward`
- `RewardedRequest`
- `AdListener` 增加 `onAdRewardReceived(event:)`
- 新增 `RewardedAd`
- 新增 `RewardedLifecycleController`
- `MSPAdLoader` 支持 `rewarded`

### Phase 2: Adapter Bridge

- Google Adapter 支持 Rewarded
- Facebook Adapter 支持 Rewarded
- 统一回调桥接到 `onAdRewardReceived`
- 增加幂等保护

### Phase 3: MSP Full-Screen Support

- 明确 MSP 自渲染 Rewarded 的奖励判定条件
- 为 `NovaCore` 增加 Rewarded 状态机
- 视需要新增 `NovaRewardedAdItem`

### Phase 4: Tooling and Tests

- Debug 页面支持 Rewarded
- 单元测试补齐
- 集成测试校验 callback 顺序

## 13. Suggested File-Level Changes

建议优先涉及的文件：

- `Sources/Core/MSPiOSCore/MSPiOSCore/api/AdFormat.swift`
- `Sources/Core/MSPiOSCore/MSPiOSCore/api/AdRequest.swift`
- `Sources/Core/MSPiOSCore/MSPiOSCore/api/Reward.swift` 新增
- `Sources/Core/MSPiOSCore/MSPiOSCore/api/RewardedEvent.swift` 新增
- `Sources/Core/MSPiOSCore/MSPiOSCore/api/Delegates/AdListener.swift`
- `Sources/Core/MSPiOSCore/MSPiOSCore/api/RewardedAd.swift` 新增
- `Sources/Core/MSPiOSCore/MSPiOSCore/internal/RewardedLifecycleController.swift` 新增
- `Sources/Core/MSPCore/MSPCore/MSPAdLoader.swift`
- `Sources/Core/MSPCore/MSPCore/Debug/...` 若需要同步调试入口
- `Sources/Adapters/MSPGoogleAdapter/...` Rewarded 相关新文件
- `Sources/Adapters/MSPFacebookAdapter/...` Rewarded 相关新文件
- `Sources/Adapters/NovaAdapter/...` 若 MSP 自渲染第一版也要支持

## 14. Testing Strategy

最低需要覆盖以下测试：

1. `AdFormat.rewarded` 可以正常进入 load path
2. `AdRequest.reward` 可以透传到 adapter
3. `RewardedLifecycleController.markRewardEarned()` 只触发一次 reward event
4. `RewardedLifecycleController.markDismissed()` 不会错误触发 reward
5. Google/Facebook 平台回调顺序被正确映射到生命周期控制器
6. 旧 listener 实现不受新增方法影响

建议增加一层纯单元测试，不依赖任意三方 SDK：

1. 奖励先到、关闭后到
2. 关闭先到、奖励永不到
3. 奖励回调重复到达
4. dismiss 回调重复到达
5. impression / click / reward / dismiss 顺序符合预期

再增加一层 adapter bridge 测试：

1. Google delegate -> lifecycle controller
2. Facebook delegate -> lifecycle controller
3. Nova self-rendered callback -> lifecycle controller

这样分层之后，大部分测试不需要起 view controller，也不需要真实广告对象。

建议补充的集成场景：

1. 加载成功但未展示，不触发 reward
2. 展示后提前关闭，不触发 reward
3. 完整播放后关闭，先 reward 再 dismiss
4. 多次平台回调，仅上抛一次 reward

## 15. Risks

### 1. Semantic Drift

不同平台对 reward 的定义不同，最容易出现“完成播放”和“获得奖励”混淆。

缓解方式：

- 统一以平台确认回调为准
- 不用 dismiss 兜底发 reward

### 2. MSP Self-Rendered Reward Logic

如果 MSP 自渲染广告缺少明确的奖励完成信号，第一版直接接入会导致语义不可靠。

缓解方式：

- 优先支持 Google / Facebook
- MSP 自渲染单独评估后再启用

### 3. API Surface Expansion

新增 `RewardedAd`、`Reward`、listener 方法后，业务接入文档和 demo 也需要更新。

缓解方式：

- 保持 listener 默认实现
- 第一版最小化 public API 变更

## 16. Final Recommendation

推荐采用“独立 Rewarded API + 纯 Swift 生命周期控制器 + 复用现有全屏展示基础设施”的方案。

具体结论：

- 不建议把 Rewarded 继续当作 Interstitial 的别名
- 不建议让 `RewardedAd` 继承 `InterstitialAd`
- 不建议把 reward 幂等和顺序判断散落在各 adapter delegate 中
- 最优路径是 API 层独立、事件值对象化、生命周期逻辑集中、展示层复用、adapter 层逐个落地

如果后续确认要开始实施，下一步建议直接输出一份可执行任务拆分文档，按 `Phase 1 ~ Phase 4` 切成具体 PR 范围。
