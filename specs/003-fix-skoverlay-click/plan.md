# Implementation Plan: SK Overlay 展示不发 Click Tracking

**Branch**: `fix/skoverlay-click` | **Date**: 2026-04-03 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/003-fix-skoverlay-click/spec.md`

## Summary

SK Overlay 展示成功不等于用户点击。当前实现通过 `handleOverlayDidFinishPresentation() -> ThirdPartyTrackingDecision` 显式返回 `.skip`，避免在 overlay 展示时自动 fire `thirdPartyTrackingURL`，从而防止 MMP CTR 虚高。真实点击路径、show time 记录和 download banner jump out metric 均保持不变。

## Technical Context

**Language/Version**: Swift 5.0
**Primary Dependencies**: UIKit, StoreKit (SKOverlay)
**Storage**: N/A
**Testing**: Quick ~> 7.0, Nimble ~> 13.0, YAML test cases
**Target Platform**: iOS 15.0+
**Project Type**: Mobile SDK (library)
**Performance Goals**: N/A（行为修复，非性能优化）
**Constraints**: 不影响真实点击路径；不在 app background 补发 click
**Scale/Scope**: 1 个核心文件 + 1 个单测文件 + 1 个 YAML test case 模块 + 1 份分析文档

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Article | Status | Notes |
|---------|--------|-------|
| I.1 (Automation First) | PASS | 无需新脚本 |
| I.2 (Deterministic Builds) | PASS | 不修改 xcodeproj |
| I.3 (SSOT) | PASS | 不改依赖 |
| I.4 (Sanctity of Automated Process) | PASS | 非 build/dependency 问题 |
| II.1 (Validation Loop) | PASS | 通过 unit test + YAML case 验证 |
| II.2 (Local Verification First) | PASS | 需跑相关测试与 test case 校验 |
| III.1 (Module Cohesion) | PASS | 改动集中在 NovaCore |
| III.2 (Protocol-Oriented Design) | PASS | 未引入新协议，仅显式化 decision |
| IV.3 (Safe Error Handling) | PASS | 无 force unwrap |
| V.1 (TDD Cycle) | PASS | 单测和 YAML case 已补齐 |
| V.2 (Mandatory Testing Framework) | PASS | 使用 Quick/Nimble |
| VIII.1 (BDD Style) | PASS | describe-it 结构已满足 |

## Project Structure

```text
Docs/
└── skoverlay-click-issues.md

Sources/Core/NovaCore/NovaCore/SKOverlay/
└── NovaSKOverlayController.swift

Tests/NovaCoreTests/Specs/SKOverlay/
└── NovaSKOverlayControllerSpec.swift

packages/test-cases/
├── _prefixes.yaml
└── core/NovaSKOverlayController.yaml
```

## Design Details

### Production Change

历史实现把 tracking fire 写在 `storeOverlayDidFinishPresentation` 里。当前实现将其改成：

```swift
func handleOverlayDidFinishPresentation() -> ThirdPartyTrackingDecision {
    registerShowTime()
    return .skip
}
```

delegate 回调层只消费 decision：

```swift
switch handleOverlayDidFinishPresentation() {
case .fire(let trackingURL):
    NovaTrackingUrlHelper.fire(url: trackingURL)
case .skip:
    break
}
```

### Why This Shape

- 明确区分“展示完成”和“真实点击”
- 测试可以直接断言 decision，避免测试专用 spy seam
- 未来如果 dedicated/native 路径需要不同 decision，可以在同一抽象里扩展

### Unchanged Parts

- `thirdPartyTrackingURL` 参数保留
- `registerShowTime()` 保留
- `appDidEnterBackground()` 的 jump out metric 保留
- `requiredTopViewControllerType` 检查保留
- CTA popup、banner tap、HTML CTA 等真实点击路径不改

## Testing Strategy

### Unit Tests

`Tests/NovaCoreTests/Specs/SKOverlay/NovaSKOverlayControllerSpec.swift`

- `SKO001`: 展示完成返回 `.skip`
- `SKO002`: 记录首次展示时间且不覆盖既有 timestamp
- `SKO003`: `thirdPartyTrackingURL == nil` 时仍返回 `.skip`

### YAML Test Cases

`packages/test-cases/core/NovaSKOverlayController.yaml`

- 与 `SKO001-003` 一一对应
- 通过 `packages/test-cases/_prefixes.yaml` 注册 `SKO`

## Implementation Order

1. 先定义 unit test 和 YAML cases
2. 实现 `ThirdPartyTrackingDecision` 与 `handleOverlayDidFinishPresentation()`
3. 校验真实点击路径未被修改
4. 跑相关测试与 test case 校验
