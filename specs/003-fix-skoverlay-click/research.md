# Research: SK Overlay 展示不发 Click Tracking

**Date**: 2026-04-03

## Summary

本 feature 无 NEEDS CLARIFICATION 项。所有技术决策已在 spec review 讨论中确认。

## Decisions

### D1: 展示完成路径只返回 tracking decision，不直接 fire

- **Decision**: 将展示完成后的 tracking 判定提取为 `handleOverlayDidFinishPresentation() -> ThirdPartyTrackingDecision`，当前展示路径始终返回 `.skip`
- **Rationale**: SK Overlay 展示完成 ≠ 用户点击。自动 fire MMP click URL 导致 CTR 虚高
- **Alternatives considered**:
  - 在 `appDidEnterBackground` 中补发 click → 否决：锁屏/切 App 也触发该回调
  - 只对 HTML interstitial/page 链路禁用 → 否决：三条链路共享同一个 `NovaSKOverlayController`，无法区分调用方

### D2: 参数保留策略

- **Decision**: 保留 `thirdPartyTrackingURL` init 参数，不在本版继续清理调用方传参
- **Rationale**: Native / dedicated skOverlay 路径传入的是 `fallbackWebModel.url`，语义不同于 MMP click。清理参数需先确认这些路径的业务意图
- **Alternatives considered**:
  - 立即移除参数 → 否决：可能影响 Native / dedicated skOverlay 路径的未知业务需求

### D3: 测试方案

- **Decision**: 新增 Quick/Nimble 单元测试 + YAML test case，并直接断言 `ThirdPartyTrackingDecision`
- **Rationale**: 符合 Article V.1 TDD 要求和 Article VIII.1 BDD 风格
- **Alternatives considered**:
  - 注入 `trackingFireHandler` 做 spy 测试 → 否决：测试专用 seam 会把生产实现耦合到测试手段，显式 decision return type 更干净
