# Feature Specification: SK Overlay 展示不发 Click Tracking

**Feature Branch**: `fix/skoverlay-click`
**Created**: 2026-04-03
**Status**: Draft
**Input**: SK Overlay 展示时移除自动 click tracking fire，防止 MMP CTR 虚高
**Reference**: `Docs/skoverlay-click-issues.md`

## Background

当前 SK Overlay（download banner）展示完成时，SDK 会自动 fire `thirdPartyTrackingURL`。在 HTML interstitial/page 链路中，该 URL 实际来自 `thirdPartyClickTrackingUrls`（MMP 点击追踪 URL）。由于 SK Overlay 是广告展示时自动弹出的，MMP 侧会将每次展示记录为一次"点击"，导致 CTR 接近 100%，提高 fraud rate。

### 三条链路的 tracking URL 语义差异

| 使用场景 | tracking URL 来源 | 实际语义 |
|----------|-------------------|----------|
| HTML interstitial/page | `interstitialAd.thirdPartyClickTrackingUrls.first` | **MMP click URL** — 展示即 fire 导致 CTR 虚高 |
| Dedicated SK Overlay interstitial | `appInstallModel.fallbackWebModel.url` | fallback URL，非 MMP click |
| Native ad | `appInstallModel.fallbackWebModel.url` | fallback URL，非 MMP click |

本次只处理共享控制器中展示时自动 fire 的行为。Native / dedicated skOverlay 路径的 `fallbackWebModel.url` 语义待后续确认。

## User Scenarios & Testing

### User Story 1 — SK Overlay 展示不触发 MMP click (Priority: P1)

作为广告 SDK 的运营方，我希望 SK Overlay download banner 展示时不再自动向 3P MMP 发送 click 事件，以避免 CTR 虚高和 fraud rate 上升。

**Why this priority**: 直接影响 MMP 端的 fraud rate 评估，是本需求的核心目标。

**Independent Test**: 在广告展示流程中触发 SK Overlay 展示，验证展示完成回调时不 fire 任何 tracking URL。

**Acceptance Scenarios**:

1. **Given** 一个配置了 SK Overlay 的广告已加载，且 tracking URL 不为 nil，**When** SK Overlay 展示完成，**Then** 不 fire tracking URL
2. **Given** 一个配置了 SK Overlay 的广告已加载，且 tracking URL 为 nil，**When** SK Overlay 展示完成，**Then** 无任何 tracking 行为（与改动前一致）
3. **Given** SK Overlay 展示完成，**When** 检查展示时间记录逻辑，**Then** show time 仍正常记录，不受 tracking 移除影响

---

### User Story 2 — CTA popup 真实点击路径不受影响 (Priority: P1)

作为广告 SDK 的运营方，我希望用户通过 CTA popup 等真实交互产生的 click 事件仍然正常发送给 MMP，确保真实点击数据不丢失。

**Why this priority**: 与 Story 1 同等重要——移除虚假 click 的同时必须保证真实 click 不丢。

**Independent Test**: 触发 CTA popup 点击、app install banner 点击、广告素材内 CTA 点击，验证 MMP click 仍正常发送。

**Acceptance Scenarios**:

1. **Given** 用户在广告中点击 CTA popup，**When** 点击事件触发，**Then** click 上报正常执行，MMP click URL 被 fire
2. **Given** 用户在 playable 广告中点击 app install banner，**When** 点击事件触发，**Then** click 上报正常执行
3. **Given** 用户在 MRAID/HTML 广告素材内点击 CTA，**When** 点击事件触发，**Then** HTML click handler 正常上报 click

---

### User Story 3 — HTML bridge `OPEN_IOS_STORE_OVERLAY` 路径行为变更 (Priority: P2)

作为广告 SDK 的开发者，我需要理解 HTML creative 通过 JS bridge 直接触发 SK Overlay 时的行为变更：本次改动后，这条路径也不会再自动 fire tracking URL。这是有意取舍——SK Overlay 只负责展示，不再承担 click tracking。

**Why this priority**: 属于边界影响，非核心需求但需要明确预期行为和后续方向。

**Independent Test**: 通过 HTML bridge 触发 SK Overlay 展示，验证 overlay 展示但不 fire tracking URL。

**Acceptance Scenarios**:

1. **Given** HTML creative 通过 JS bridge 调用展示 SK Overlay，**When** SK Overlay 展示完成，**Then** 不 fire tracking URL（与 Story 1 行为一致）

---

### Edge Cases

- SK Overlay 展示失败时：原本也不会 fire tracking，改动后行为不变
- SK Overlay 被 dismiss 后 restore 时：restore 触发的展示完成回调也不会 fire tracking
- `thirdPartyTrackingURL` 参数保留：所有调用方传参不变，仅内部不再 fire

## Requirements

### Functional Requirements

- **FR-001**: SK Overlay 展示完成时，不得自动 fire `thirdPartyTrackingURL`
- **FR-002**: SK Overlay 展示完成时，必须继续记录展示时间（show time）
- **FR-003**: `thirdPartyTrackingURL` 初始化参数保留，本版不做删除或重命名
- **FR-004**: 不得在 App 进入后台回调中补发 click tracking（该回调在锁屏、切 App 等非点击场景也会触发）
- **FR-005**: CTA popup、app install banner、MRAID/HTML CTA 等真实用户点击路径的 click 上报不受影响

### Scope Boundary — 不做的事

- 不删除或重命名共享参数
- 不在 App 进后台回调里补发 click
- 不改动真实点击路径
- 不处理 Native / dedicated skOverlay 路径的 fallback URL 语义（后续确认）

## Success Criteria

### Measurable Outcomes

- **SC-001**: SK Overlay 展示完成后，MMP 侧不再收到自动 click 事件（可通过抓包或 MMP dashboard 验证 CTR 回落到正常水平）
- **SC-002**: 真实用户点击（CTA popup、banner tap、素材内 CTA）的 click 上报数量与改动前保持一致
- **SC-003**: 内部 metric（展示时长记录、download banner jump out）不受影响
- **SC-004**: 所有现有 unit test 通过，新增 test case 覆盖"展示不 fire"行为
