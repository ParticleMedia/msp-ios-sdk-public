# Tasks: SK Overlay 展示不发 Click Tracking

**Input**: Design documents from `/specs/003-fix-skoverlay-click/`
**Prerequisites**: plan.md (required), spec.md (required), research.md

**Tests**: Included — 按 constitution 要求补齐 Quick/Nimble unit test 与 YAML test case。

## Phase 1: Setup

- [x] T001 确认当前分支为 `fix/skoverlay-click` 且工作目录干净

## Phase 2: User Story 1 — SK Overlay 展示不触发 MMP click

**Goal**: 展示完成时返回 `.skip`，不自动 fire `thirdPartyTrackingURL`

**Independent Test**: 调用 `handleOverlayDidFinishPresentation()`，验证返回 `.skip` 且 show time 正常记录

- [x] T002 [US1] 新增 Quick/Nimble 测试文件 `Tests/NovaCoreTests/Specs/SKOverlay/NovaSKOverlayControllerSpec.swift`，覆盖 `SKO001-SKO003`
- [x] T003 [US1] 新增 `packages/test-cases/core/NovaSKOverlayController.yaml` 并在 `packages/test-cases/_prefixes.yaml` 注册 `SKO`
- [x] T004 [US1] 在 `Sources/Core/NovaCore/NovaCore/SKOverlay/NovaSKOverlayController.swift` 中提取 `handleOverlayDidFinishPresentation() -> ThirdPartyTrackingDecision`，展示路径返回 `.skip`

## Phase 3: User Story 2 — 真实点击路径不受影响

- [x] T005 [US2] 审查 CTA popup、app install banner、HTML CTA 等真实点击链路未被本次改动修改

## Phase 4: User Story 3 — HTML bridge 路径行为一致

- [x] T006 [US3] 审查 `OPEN_IOS_STORE_OVERLAY` 最终仍走 `NovaSKOverlayController`，展示完成行为与 US1 一致

## Phase 5: Validation

- [x] T007 运行相关 unit test，确认 `NovaSKOverlayControllerSpec` 通过
- [x] T008 运行 `python Scripts/tools/test-cases.py validate`，确认 YAML registry 合法
- [x] T009 代码审查：确认无测试专用 spy seam 泄漏到生产实现

## Notes

- 本 feature 的核心是行为修复，不是 click 链路重构
- `SKO001-003` 在 unit tests 和 YAML 中保持同编号
- dedicated/native 路径对 `thirdPartyTrackingURL` 的业务语义保留待后续确认
