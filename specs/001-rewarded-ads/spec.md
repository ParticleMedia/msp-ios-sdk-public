# Feature Specification: Rewarded Ads

**Feature Branch**: `001-rewarded-ads`
**Created**: 2026-03-11
**Status**: Draft
**Input**: User description: "新增 Rewarded 广告类型支持，包括广告格式定义、奖励配置、奖励回调，覆盖 Google/Facebook/MSP 三端适配"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - SDK 接入方请求并展示 Rewarded 广告 (Priority: P1)

作为 SDK 接入方（宿主 App 开发者），我需要能够通过 MSP SDK 请求一条 Rewarded 广告并展示给用户，这样用户可以通过观看广告获得应用内奖励。

**Why this priority**: Rewarded 广告的核心价值链——请求、加载、展示——是所有后续功能的基础。没有这条链路，奖励回调和多网络适配都无从谈起。

**Independent Test**: 可以通过创建一个 Rewarded 广告请求、成功加载、全屏展示来独立验证，交付最小可用的 Rewarded 广告能力。

**Acceptance Scenarios**:

1. **Given** 接入方已正确初始化 MSP SDK，**When** 接入方使用 Rewarded 广告格式创建请求并发起加载，**Then** SDK 成功从至少一个广告网络加载 Rewarded 广告并通知加载完成。
2. **Given** Rewarded 广告已成功加载，**When** 接入方调用展示方法，**Then** 广告以全屏形式展示给用户。
3. **Given** Rewarded 广告正在展示，**When** 用户关闭广告，**Then** 广告正常关闭并通知接入方。
4. **Given** 接入方发起 Rewarded 广告请求，**When** 没有可用的广告填充，**Then** SDK 返回明确的加载失败回调，包含失败原因。

---

### User Story 2 - 用户完成观看后获得奖励回调 (Priority: P1)

作为 SDK 接入方，我需要在用户满足奖励条件（如完整观看视频）后，收到一个统一的奖励回调，这样我可以在应用内发放对应的奖励。

**Why this priority**: 奖励回调是 Rewarded 广告区别于普通 Interstitial 的核心差异，是该广告类型的本质特征。

**Independent Test**: 可以通过展示 Rewarded 广告、用户完整观看后验证回调是否触发来独立测试。

**Acceptance Scenarios**:

1. **Given** Rewarded 广告正在展示，**When** 用户满足奖励条件（如完整观看视频），**Then** SDK 触发奖励回调通知接入方。
2. **Given** Rewarded 广告正在展示，**When** 用户提前关闭广告未满足奖励条件，**Then** SDK 不触发奖励回调，仅触发关闭回调。
3. **Given** 平台重复发送奖励信号，**When** SDK 收到多次奖励回调，**Then** SDK 只向接入方触发一次奖励回调（幂等保护）。
4. **Given** 用户满足奖励条件后关闭广告，**When** SDK 处理回调顺序，**Then** 奖励回调在关闭回调之前触发。

---

### User Story 3 - 接入方配置奖励参数 (Priority: P2)

作为 SDK 接入方，我需要在请求 Rewarded 广告时传入奖励配置（奖励类型和数量），这样广告网络可以根据配置进行奖励校验。

**Why this priority**: 奖励配置是标准化接入的一部分，但即使没有自定义配置，Rewarded 广告仍然可以使用服务端默认配置运行。

**Independent Test**: 可以通过请求时设置不同的奖励类型和数量，验证这些参数被正确传递到广告网络。

**Acceptance Scenarios**:

1. **Given** 接入方创建 Rewarded 广告请求，**When** 设置奖励类型为 "coins" 且数量为 10，**Then** 奖励配置随请求正确传递到对应广告网络。
2. **Given** 接入方创建 Rewarded 广告请求，**When** 未设置任何奖励配置，**Then** SDK 使用合理的默认值正常发起请求。

---

### User Story 4 - 多广告网络 Rewarded 适配 (Priority: P2)

作为 SDK 接入方，我需要 Rewarded 广告能够在 Google AdMob、Facebook Audience Network 和后续可扩展的其他三方网络之间进行竞价和回退，这样可以最大化广告填充率和收益。

**Why this priority**: 多网络支持是 MSP SDK 的核心竞争力，但第一版可以分阶段接入各网络。

**Independent Test**: 可以通过分别配置 Google 和 Facebook 的 Rewarded 广告，验证各网络独立加载和展示成功。

**Acceptance Scenarios**:

1. **Given** SDK 配置了 Google AdMob Rewarded 广告位，**When** 发起 Rewarded 请求，**Then** Google 适配器正确加载和展示 Rewarded 广告，奖励回调正常触发。
2. **Given** SDK 配置了 Facebook Audience Network Rewarded 广告位，**When** 发起 Rewarded 请求，**Then** Facebook 适配器正确加载和展示 Rewarded 视频广告，奖励回调正常触发。
3. **Given** SDK 配置了多个网络的 Rewarded 广告位，**When** 发起 Rewarded 请求，**Then** SDK 按照竞价/瀑布流逻辑选择最优网络进行加载。

---

### User Story 5 - Debug 工具支持 Rewarded 广告 (Priority: P3)

作为 SDK 开发者或接入方，我需要在 Debug 页面中测试 Rewarded 广告的完整流程（包括配置奖励参数），这样可以在开发阶段快速验证集成是否正确。

**Why this priority**: Debug 工具提升开发效率，但不影响生产功能。

**Independent Test**: 可以通过 Debug 页面选择 Rewarded 广告格式，配置 reward type 和 amount，触发加载和展示，查看奖励回调日志。

**Acceptance Scenarios**:

1. **Given** 开发者打开 SDK Debug 页面，**When** 在 Ad Format 列表中选择 Rewarded，**Then** 页面新增显示 Reward 配置区域（reward type 和 reward amount 选项），其他格式选中时该区域不显示。
2. **Given** 开发者选择了 Rewarded 格式并配置了奖励参数，**When** 点击 Load Ad，**Then** reward type 和 amount 被正确透传到广告请求，调试日志可以验证参数是否生效。
3. **Given** Rewarded 广告展示完成，**When** 用户完整观看视频，**Then** Debug 页面显示 "onAdRewardReceived" 回调日志，并标记奖励回调是否早于关闭回调。
4. **Given** 用户提前关闭广告，**When** 广告关闭，**Then** Debug 页面显示关闭回调日志，且无奖励回调日志。

---

### Edge Cases

- 广告加载成功但从未展示时，不应触发任何奖励或展示回调
- 用户在广告展示过程中 App 进入后台，恢复后广告和奖励状态是否保持一致
- 广告网络返回空的奖励信息时，SDK 如何处理
- 同时存在多个 Rewarded 广告请求时，各自的奖励回调是否隔离
- 广告展示过程中网络断开，对奖励判定的影响
- 关闭回调和奖励回调几乎同时到达（竞态条件）时，SDK 是否保证正确顺序
- 广告加载成功后超过 1 小时未展示（Google 广告失效），调用展示时应返回明确错误
- Facebook Rewarded：用户在 end card 阶段（视频结束后）关闭广告，reward 已触发，SDK 不应重复触发 dismiss 相关的错误处理

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: SDK MUST 支持 Rewarded 作为独立的广告格式，与 Banner、Native、Interstitial 平级
- **FR-002**: SDK MUST 允许接入方在请求时指定奖励配置（奖励类型和奖励数量），该字段为**可选**；不传时 SDK 正常发起请求，不附带奖励参数。
- **FR-003**: SDK MUST 在用户满足广告网络定义的奖励条件时，通过 `AdListener.onAdRewardReceived(ad: MSPAd)` 向接入方触发奖励回调，并提供默认空实现
- **FR-004**: SDK MUST 保证奖励回调的幂等性——同一次广告展示最多触发一次奖励回调
- **FR-005**: SDK MUST 保证奖励回调在关闭回调之前触发（当用户确实获得奖励时）；注意 Google 仅对自身广告保证此顺序，Mediation 网络不保证，Facebook 通过 `videoComplete` 在 end card 前触发来保证顺序
- **FR-006**: SDK MUST 在用户未满足奖励条件时，不触发奖励回调（不以关闭兜底触发奖励）
- **FR-007**: SDK MUST 支持 Google AdMob 的 Rewarded 广告加载和展示
- **FR-008**: SDK MUST 支持 Facebook Audience Network 的 Rewarded Video 广告加载和展示
- **FR-009**: SDK MUST 将 Rewarded 广告纳入现有的竞价/瀑布流加载机制，并沿用现有 adapter 级格式分发方式；不为 Rewarded 单独引入 capability probe API
- **FR-010**: SDK MUST 为 Rewarded 广告提供独立的生命周期事件（加载、展示、点击、奖励、关闭、失败）
- **FR-011**: SDK MUST 保持对现有广告格式（Banner、Native、Interstitial）的向后兼容，新增 Rewarded 不影响已有功能
- **FR-012**: SDK MUST 为已有的回调接口提供默认实现，使未使用 Rewarded 的接入方无需修改代码

### Key Entities

- **Reward（奖励配置）**: 描述一次奖励的类型（如 "coins"、"lives"）和数量（如 10、1），由接入方在请求时设置
- **RewardedAd（Rewarded 广告对象）**: 代表一条已加载的 Rewarded 广告，具备展示和关闭能力，携带奖励配置信息
- **RewardedEvent（奖励事件）**: 代表一次奖励达成事件，包含广告位、请求标识、广告网络来源和奖励配置，供内部生命周期控制器使用（不作为公开回调参数）

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 接入方可以在 5 行代码内完成 Rewarded 广告的请求和展示集成
- **SC-002**: Google 和 Facebook 两个主要广告网络的 Rewarded 广告填充率与各自原生 SDK 直接集成时持平（差异不超过 5%）
- **SC-003**: 奖励回调准确率达到 100%——满足条件时必定触发，未满足时绝不触发
- **SC-004**: 新增 Rewarded 功能后，现有 Banner/Native/Interstitial 广告的所有自动化测试全部通过，无回归
- **SC-005**: Rewarded 广告从请求到展示的端到端延迟不超过同场景下 Interstitial 广告的 120%
- **SC-006**: Debug 工具可以完整展示 Rewarded 广告的生命周期事件链，开发者可在 1 分钟内验证集成正确性

## Clarifications

### Session 2026-03-11

- Q: 奖励回调的公开 API 签名应该是哪种形式？ → A: 仅 `onAdRewardReceived(ad: MSPAd)`，提供默认空实现。由于这是新增方法，现有接入方不存在兼容问题，单一签名更简洁。
- Q: MSP 自渲染广告赢得 Rewarded 竞价时如何处理？ → A: 过滤掉该竞价结果，使用次高出价的外部网络；同时预留扩展点，使后续阶段可以在不重构竞价逻辑的前提下启用 MSP 自渲染 Rewarded 支持。
- Q: 奖励配置（reward type/amount）是否必填？ → A: **暂定可选**，不传时 SDK 正常发请求不附带奖励参数。⚠️ 待确认：需与产品对齐 MSP 服务端是否要求必传，PDF 中未明确约束。
- Q: SDK 是否校验 Rewarded 广告的展示时机（opt-in 约束）？ → A: SDK 不做行为校验，由接入方自行保证用户主动触发，合规责任在接入方侧。记录为使用约束。
- Q: 广告预加载策略？ → A: 不新增预加载 API。Google 1 小时广告过期由 GAD SDK 自身处理（调用展示时若过期触发 `didFailToPresent` 错误回调），现有错误流程已覆盖，无需额外处理。竞价阶段超时由现有 `auctionTimeout` 机制统一管理。

## Assumptions

- Google AdMob 和 Facebook Audience Network 的 Rewarded 广告能力已在各自 SDK 中可用且稳定
- 其他网络 Liftoff/Vungle、Moloco、Mintegral、MobileFuse、PubMatic OpenWrap、InMobi、LevelPlay/IronSource 具备 Rewarded 能力，已纳入实现范围（v1 仍仅通过服务端门控启用 Google + Facebook）
- Google Mobile Ads SDK 的接入不替代 Moloco 等第三方网络的独立接入；若走 Google mediation，仍需额外集成该网络自身 SDK 与 mediation adapter。因此当前仓库中的 `MSPMolocoAdapter` 仍属于独立需求接入路径，不应因已接入 Google SDK 而回滚
- MSP 自有渲染（NovaCore）第一版不支持 Rewarded
- 奖励条件的判定依赖各广告网络自身的回调，MSP SDK 不自行判定奖励是否达成：Google 通过 `userDidEarnRewardHandler` 确认，Facebook 通过 `rewardedVideoAdVideoComplete()` 确认（视频完整播放）
- Google 广告有效期约 1 小时，建议接入方在加载后 1 小时内展示，否则需重新加载
- Facebook Rewarded 广告在视频结束后会展示 end card，`dismiss` 回调在 end card 关闭后才触发，reward 回调在 end card 出现前已触发
- 服务端 placement 配置已支持或即将支持 "rewarded" 格式字段下发
- 奖励回调只表示"用户已满足奖励条件"，实际奖励发放由宿主 App 自行处理
- 第一版回调不携带复杂的多来源奖励 payload，仅通知奖励达成
- Rewarded 广告必须是用户主动选择（opt-in）的体验，SDK 不校验展示时机，合规责任由接入方承担

## Dependencies

- Google Mobile Ads SDK（GADRewardedAd）
- Facebook Audience Network SDK（FBRewardedVideoAd）
- MSP 服务端 placement 配置需同步支持 "rewarded" 格式

## Adapter Expansion Plan

经过对当前仓库、Pods 和官方文档的复核，以下网络已确认具备 Rewarded 能力并已纳入实现计划：

| 网络 | SDK 类型 | 状态 | v1 服务端启用 |
|------|---------|------|-------------|
| Google AdMob | `GADRewardedAd` | ✅ 已实现 | ✅ 是 |
| Facebook AAN | `FBRewardedVideoAd` | ✅ 已实现 | ✅ 是 |
| Liftoff / Vungle | `VungleRewarded` | 📋 待实现 | ❌ 否 |
| Moloco | `MolocoRewardedInterstitial` | ✅ 已纳入当前分支实现 | ❌ 否 |
| Mintegral | `MTGRewardAdManager` | 📋 待实现 | ❌ 否 |
| MobileFuse | `MFRewardedAd` | 📋 待实现 | ❌ 否 |
| PubMatic OpenWrap | `POBRewardedAd` | 📋 待实现 | ❌ 否 |
| InMobi | `IMInterstitial` (共用) | 📋 待实现 | ❌ 否 |
| LevelPlay / IronSource | `LPMRewardedAd` | 📋 待实现 | ❌ 否 |
| Amazon APS | — | ⏸️ 延后 | ❌ 否 |

**架构**：当前 Rewarded rollout 先由客户端门控控制，默认仅放开 Google 与 Facebook；服务端 placement 配置就绪后，门控数据源将切换到服务端而不改变 adapter 路由。Google SDK 仅承载 Google demand；像 Moloco 这类第三方网络若要参与 MSP 自己的 server-side bidding，仍需保持独立 adapter 实现。若未来改走 Google mediation，那是另一条产品/接入方案，不等同于删除 `MSPMolocoAdapter`。

## Scope Boundaries

**In Scope**:
- Rewarded 广告格式定义和 API 设计
- 奖励配置的请求传递
- 统一的奖励回调机制
- Google AdMob Rewarded 适配（v1 服务端启用）
- Facebook Audience Network Rewarded 适配（v1 服务端启用）
- **全部剩余 adapter Rewarded 实现**：Liftoff/Vungle、Moloco、Mintegral、MobileFuse、PubMatic OpenWrap、InMobi、Unity/LevelPlay（代码就绪，服务端门控）
- Rewarded 广告生命周期管理（幂等、顺序保证）
- Debug 工具 Rewarded 支持
- 向后兼容保证
- Rewarded 仅面向 MSP server-side bidding flows
- Rewarded rollout 当前由客户端门控控制，仅启用 Google / Facebook；各 adapter 直接处理 `.rewarded` 分支

**Out of Scope**:
- MSP 自有渲染（NovaCore）的 Rewarded 支持（后续阶段）
- Amazon APS Rewarded 适配（iOS API 证据不充分，待确认）
- 服务端奖励验证（S2S reward verification）之外的 client-side reward contract
- 回调中携带详细的多来源奖励 payload
- Rewarded Interstitial（带跳过按钮的 Rewarded 广告）
