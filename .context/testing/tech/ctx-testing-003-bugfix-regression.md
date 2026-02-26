---
id: ctx-testing-003
title: Bugfix 回归测试策略 (AI-First)
layer: tech
domain: testing
tags: [bugfix, regression, yaml-first, tdd, red-green-refactor, traceability]
triggers: [bugfix, regression, fix, bug, hotfix, regression_for, reproduce, red-green-refactor]
summary: "Bugfix 回归测试硬规则与软规则，覆盖复现→YAML→红→绿→重构→提交的完整工作流"
version: "2.0"
created: 2026-02-22
updated: 2026-02-23
source: manual
status: active
confidence: high
---

# Bugfix 回归测试策略 (AI-First)

## 适用场景

当修复 bug 时加载此 playbook。适用于所有 bugfix 场景——生产环境崩溃、Code Review 发现的逻辑错误、QA 上报的功能缺陷。核心原则：**没有回归测试的 bugfix 不是真正的修复**。

---

## Hard Rules (HR) — 不可违反

### HR-1: NEVER fix a bug without first writing a regression test

> Source: [Kent Beck — Test-Driven Development: By Example](https://www.amazon.com/Test-Driven-Development-Kent-Beck/dp/0321146530), [Martin Fowler — Refactoring: Improving the Design of Existing Code](https://martinfowler.com/books/refactoring.html)

```swift
// ❌ WRONG: 直接修复，没有测试
// 1. 看到 bug report
// 2. 找到有问题的代码行
// 3. 修改代码
// 4. "之后再补测试"（永远不会发生）

// ✅ CORRECT: 先写失败测试，再修复
// 1. 看到 bug report
// 2. 在测试中复现 bug（Red）
// 3. 写最小修复让测试通过（Green）
// 4. 重构（Refactor）
// 5. test + fix 一起提交
```

**Why**: 没有测试保护的修复可能在未来被无意回退。测试是 bug 不再复发的唯一保证。

---

### HR-2: ALWAYS add YAML test case with `regression_for` field BEFORE writing Swift test

> Source: Project YAML-first workflow ([packages/test-cases/README.md](../../packages/test-cases/README.md))

```yaml
# ✅ CORRECT: 在 packages/test-cases/debug/DebugAdLoad.yaml 中添加
- id: DAL016
  type: behavior
  description: "Should not crash when placement list is nil"
  priority: high
  tags: [regression]
  given: "API returns null for placements field"
  when: "ViewModel initializes"
  then: "Sections array is empty; No crash occurs"
  regression_for: "BUG-1234: Crash on nil placements response"
  doubles:
    placementsRepository:
      type: stub
      class: MockPlacementsRepository
      reason: "Control API response to return nil placements"
```

```yaml
# ❌ WRONG: 缺少 regression_for 字段
- id: DAL016
  type: behavior
  description: "Should not crash on nil"
  tags: [unit]
  doubles: {}
```

**Why**: `regression_for` 是可追溯性的关键。没有它，regression 测试和原始 bug 之间的关系断裂。

添加后立即验证：

```bash
python Scripts/tools/test-cases.py validate
```

---

### HR-3: ALWAYS commit test + fix together in ONE atomic commit

> Source: [Git best practices — bisectability](https://git-scm.com/book/en/v2/Git-Tools-Debugging-with-Git), [Conventional Commits](https://www.conventionalcommits.org/)

```bash
# ✅ CORRECT: 测试 + 修复在同一个 commit
git add packages/test-cases/debug/DebugAdLoad.yaml
git add Tests/MSPCoreTests/Specs/Debug/DebugAdLoadViewModelSpec.swift
git add Sources/MSPCore/ViewModels/Debug/DebugAdLoadViewModel.swift
git commit -m "fix(debug): handle nil placements without crash

Regression test [DAL016] for BUG-1234.
Root cause: compactMap missing for nil elements in placements array."
```

```bash
# ❌ WRONG: 分离提交
git commit -m "fix: handle nil placements"        # commit 1
git commit -m "test: add regression test for nil"  # commit 2
# 如果 commit 1 被 revert，commit 2 的测试变成假失败
```

**Why**: 原子提交保证 git bisect 和 revert 的正确性。分离的提交破坏可追溯性。

---

### HR-4: ALWAYS make the test fail first (Red) before implementing the fix (Green)

> Source: [Kent Beck — TDD Red-Green-Refactor](https://www.amazon.com/Test-Driven-Development-Kent-Beck/dp/0321146530)

```swift
// ✅ CORRECT: 先运行测试，确认失败（Red）
context("regression: BUG-1234 nil placements crash") {
    it("[DAL016] should handle nil placements without crashing") {
        // Given
        placementsRepository.placementsToReturn = []
        sectionsRepository.sectionsToReturn = []

        // When
        let sut = DebugAdLoadViewModel(
            debugSectionsRepository: sectionsRepository,
            placementsRepository: placementsRepository,
            loadAdRepository: loadAdRepository
        )

        // Then
        expect(sut.sections).to(beEmpty())
    }
}
// 运行 → 测试失败 ✅（证明 bug 存在）
// 然后写 fix → 测试通过 ✅（证明 fix 有效）
```

```swift
// ❌ WRONG: 先写 fix，再补测试
// 1. 修改 DebugAdLoadViewModel.swift（Green from start）
// 2. 写测试 → 直接通过
// 问题：你无法确认测试真的在检测这个 bug
```

**Why**: 如果测试从未失败过，你不知道它是否真的在保护你想保护的场景。Red 阶段是验证测试有效性的唯一方法。

---

### HR-5: NEVER remove or modify existing passing tests to make a fix work

> Source: [Martin Fowler — Test Pyramid](https://martinfowler.com/bliki/TestPyramid.html), Non-regression principle

```swift
// ❌ WRONG: 弱化已有测试来让 fix 通过
// 原来: expect(sut.items.count).to(equal(5))
// "修复": expect(sut.items.count).to(beGreaterThan(0))  // 被削弱了！

// ✅ CORRECT: 已有测试失败说明你的 fix 有副作用
// 1. 调查 WHY 已有测试失败
// 2. 修复根因，而不是修改测试
// 3. 两个测试都必须通过
```

**Why**: 已有测试代表已验证的行为契约。如果你的修复破坏了这些契约，说明修复不完整或有副作用。

---

### HR-6: ALWAYS link regression test to original bug via regression_for

> Source: Project YAML-first workflow, traceability principle

```yaml
# ✅ CORRECT: regression_for 完整格式
regression_for: "BUG-1234: Crash on nil placements response"

# ❌ WRONG: 缺失或含糊
regression_for: ""
# 或完全没有这个字段
```

`regression_for` 的三个用途：
1. **可追溯性**: 从测试直接关联到原始 bug report
2. **覆盖率报告**: `python Scripts/tools/test-cases.py regression-report` 统计回归覆盖
3. **Revert 安全**: 如果修复被 revert，测试清楚标识哪个 bug 复发了

---

### HR-7: ALWAYS reproduce the bug in a test BEFORE reading production code

> Source: Scientific debugging method, [Debugging: The 9 Indispensable Rules](https://debuggingrules.com/)

```swift
// ✅ CORRECT: 先从 bug report 提取 Given/When/Then，写测试
// Bug report: "When API returns nil placements, app crashes on launch"
// → Given: API returns nil placements
// → When: ViewModel initializes
// → Then: App should not crash (sections should be empty)

// 写测试 → 运行 → 测试失败（确认 bug）
// 然后才去看生产代码找根因

// ❌ WRONG: 先看代码，猜测问题，修改代码，然后补测试
// 风险：你可能修了一个不是真正根因的问题
```

**Why**: 先复现再修复是科学方法。先看代码会产生确认偏误（confirmation bias）。

---

### HR-8: NEVER write an overly broad regression test — test the exact failure scenario

> Source: [Gerard Meszaros — xUnit Test Patterns](https://martinfowler.com/books/meszaros.html), test specificity principle

```swift
// ❌ WRONG: 测试范围过大，什么都测
it("[DAL016] should handle all edge cases") {
    // 测试 nil, empty, single, many, duplicates, unicode...
    // 如果未来失败了，哪个场景出了问题？
    expect(sut.handle(nil)).toNot(throwError())
    expect(sut.handle([])).to(beEmpty())
    expect(sut.handle(["one"])).to(haveCount(1))
    expect(sut.handle(["a","a"])).to(haveCount(2))
}

// ✅ CORRECT: 精准测试原始 bug 场景
it("[DAL016] should handle nil placements without crashing") {
    placementsRepository.placementsToReturn = []
    let sut = makeSUT()
    expect(sut.sections).to(beEmpty())
}
```

**Why**: 宽泛测试给出的失败信号模糊。精确测试 = 精确诊断。

---

### HR-9: ALWAYS use `context("regression: BUG-XXXX ...")` to group regression tests

> Source: BDD naming conventions ([Dan North — Introducing BDD](https://dannorth.net/blog/introducing-bdd/))

```swift
// ✅ CORRECT: 清晰的 regression context 分组
describe("DebugAdLoadViewModel") {
    // ... 正常测试 ...

    context("regression: BUG-1234 nil placements crash") {
        it("[DAL016] should handle nil placements without crashing") {
            // ...
        }
    }

    context("regression: BUG-1235 duplicate sections") {
        it("[DAL017] should deduplicate sections from API") {
            // ...
        }
    }
}

// ❌ WRONG: regression 测试混在普通测试中，无标识
describe("DebugAdLoadViewModel") {
    it("[DAL016] should handle nil placements") { /* ... */ }
    it("[DAL003] should load ads successfully") { /* ... */ }
    // 无法区分哪些是 regression，哪些是常规测试
}
```

**Why**: 显式分组让 regression 测试在代码中一目了然，便于维护和审计。

---

### HR-10: ALWAYS run full test suite after fix, not just the new regression test

> Source: [Martin Fowler — Continuous Integration](https://martinfowler.com/articles/continuousIntegration.html)

```bash
# ✅ CORRECT: 先运行新测试确认通过，再运行全套
python Scripts/tools/test-cases.py validate sync
xcodebuild test -scheme MSPCoreTests

# ❌ WRONG: 只运行新的 regression 测试
xcodebuild test -scheme MSPCoreTests \
    -only-testing "MSPCoreTests/DebugAdLoadViewModelSpec/DAL016"
# 通过了，但其他测试可能因为你的 fix 而失败
```

**Why**: 你的修复可能有意想不到的副作用。全套测试是你唯一的安全网。

---

## Advisory Rules (AR) — 推荐做法

### AR-1: SHOULD add boundary tests around the bugfix area

当修复一个 bug 时，考虑相邻的边界条件是否也脆弱：

```swift
// 原始 bug: nil placements crash
it("[DAL016] should handle nil placements without crashing") { /* ... */ }

// 推荐：相邻边界测试
it("[DAL017] should handle single placement correctly") {
    placementsRepository.placementsToReturn = ["placement_1"]
    sectionsRepository.sectionsToReturn = TestDataFactory.createMinimalSections()
    let sut = makeSUT()
    expect(sut.sections).toNot(beEmpty())
}
```

### AR-2: SHOULD check if similar bugs exist in related modules

如果 Module A 有 nil 处理 bug，Module B 可能有相同问题。搜索类似模式：

```bash
# 查找所有类似的 force unwrap 或缺少 nil check 的位置
grep -rn "\.map {" Sources/ --include="*.swift" | grep -v "compactMap"
```

### AR-3: SHOULD use git blame to understand original intent of buggy code

```bash
git blame Sources/MSPCore/ViewModels/Debug/DebugAdLoadViewModel.swift -L 45,55
# 了解原始代码的意图，避免"修复"实际上是正确行为的代码
```

### AR-4: SHOULD document root cause in commit message body

```bash
git commit -m "fix(debug): handle nil placements without crash

Root cause: fetchSections() used .map instead of .compactMap,
causing nil elements to propagate and crash during UITableView reload.

Regression test [DAL016] for BUG-1234."
```

### AR-5: SHOULD run regression coverage report after adding new regression tests

```bash
python Scripts/tools/test-cases.py regression-report
# 输出: 17 total cases, 3 regression cases, all synced
```

### AR-6: SHOULD consider if the bug reveals a design flaw worth refactoring

如果同一个根因导致了多个 bug，不要逐个修复——重构根本设计。但这是单独的任务，不要在 bugfix commit 中进行大重构。

### AR-7: SHOULD write the regression test in the existing Spec file, not a new file

```
# ✅ 推荐: 加到已有的 DebugAdLoadViewModelSpec.swift 中的 regression context
# ❌ 不推荐: 新建 DebugAdLoadRegressionSpec.swift（碎片化）
```

### AR-8: SHOULD update YAML doubles field to document test doubles used

```yaml
doubles:
  placementsRepository:
    type: stub
    class: MockPlacementsRepository
    reason: "Return empty placements to simulate nil API response"
  sectionsRepository:
    type: stub
    class: MockDebugSectionsRepository
    reason: "Return empty sections"
```

---

## 完整 Bugfix 工作流示例

**场景**: BUG-1234 — 当 API 返回 nil placements 时，app 崩溃

### Step 1: 添加 YAML test case

```yaml
# packages/test-cases/debug/DebugAdLoad.yaml — 添加新 case
- id: DAL016
  type: behavior
  description: "Should not crash when placement list is nil"
  priority: high
  tags: [regression]
  given: "API returns null for placements field"
  when: "ViewModel initializes"
  then: "Sections array is empty; No crash occurs"
  regression_for: "BUG-1234: Crash on nil placements response"
  doubles:
    placementsRepository:
      type: stub
      class: MockPlacementsRepository
      reason: "Return nil placements to reproduce crash"
```

### Step 2: 验证 YAML

```bash
python Scripts/tools/test-cases.py validate
# ✓ Schema valid
# ✗ Sync: DAL016 not implemented  ← 预期的，还没写 Swift 测试
```

### Step 3: 写失败测试 (Red)

```swift
// Tests/MSPCoreTests/Specs/Debug/DebugAdLoadViewModelSpec.swift
context("regression: BUG-1234 nil placements crash") {
    it("[DAL016] should handle nil placements without crashing") {
        // Given
        placementsRepository.placementsToReturn = []
        sectionsRepository.sectionsToReturn = []

        // When
        let sut = DebugAdLoadViewModel(
            debugSectionsRepository: sectionsRepository,
            placementsRepository: placementsRepository,
            loadAdRepository: loadAdRepository
        )

        // Then
        expect(sut.sections).to(beEmpty())
    }
}
```

### Step 4: 确认测试失败

```bash
xcodebuild test -scheme MSPCoreTests \
    -only-testing "MSPCoreTests/DebugAdLoadViewModelSpec"
# ✗ FAILED — 测试确认 bug 存在
```

### Step 5: 写最小修复 (Green)

```swift
// Sources/MSPCore/ViewModels/Debug/DebugAdLoadViewModel.swift
// Before:
self.sections = sections.map { transform($0) }

// After:
self.sections = sections.compactMap { transform($0) }
```

### Step 6: 确认全部通过

```bash
python Scripts/tools/test-cases.py validate sync
xcodebuild test -scheme MSPCoreTests
# ✓ ALL PASSED
```

### Step 7: 原子提交

```bash
git add packages/test-cases/debug/DebugAdLoad.yaml
git add Tests/MSPCoreTests/Specs/Debug/DebugAdLoadViewModelSpec.swift
git add Sources/MSPCore/ViewModels/Debug/DebugAdLoadViewModel.swift
git commit -m "fix(debug): handle nil placements without crash

Root cause: .map did not filter nil elements from API response.
Regression test [DAL016] for BUG-1234."
```

---

## AI 常犯错误（本项目特有）

### 1. 先修 bug 再补测试

**症状**: AI 直接修改生产代码，在最后才添加一个"验证性"测试
**根因**: AI 优先考虑"解决问题"而非"证明问题存在"
**修复**: 强制遵循 Red→Green→Refactor 顺序。测试必须先写、先运行、先失败。

### 2. 删除或弱化已有测试

**症状**: AI 修改了已有的 `expect(...).to(equal(5))` 变为 `expect(...).to(beGreaterThan(0))`
**根因**: AI 认为让所有测试通过 = 任务完成
**修复**: 已有测试是行为契约。失败意味着你的 fix 有副作用，需要调查根因。

### 3. YAML 中遗漏 regression_for 字段

**症状**: 新增 YAML test case 没有 `regression_for` 字段或 `regression` tag
**根因**: AI 使用了普通 test case 模板而非 regression 模板
**修复**: 任何 bugfix 相关的 test case 必须有 `regression_for: "BUG-XXXX: description"` 和 `tags: [regression]`

### 4. 回归测试范围过大

**症状**: 单个 `it()` 块中测试了 5+ 个场景
**根因**: AI 试图"全面覆盖"而非精确复现
**修复**: 一个 `it()` = 一个精确的失败场景。如需覆盖边界，写多个独立的 `it()` 块。

### 5. 测试和修复分开提交

**症状**: 两个 commit — 一个是 fix，一个是 test
**根因**: AI 按逻辑分类（"代码改动"和"测试改动"）而非按原子功能分类
**修复**: test + fix 必须在同一个 commit。这保证 git bisect 和 revert 的正确性。

### 6. 使用 JSON 格式而非 YAML（旧工作流残留）

**症状**: AI 将 test case 写入 `Tests/TestCases/*.json` 而非 `packages/test-cases/*.yaml`
**根因**: AI 参考了旧的代码示例或文档
**修复**: 所有新 test case 必须使用 YAML 格式写入 `packages/test-cases/{subdir}/`。JSON 位置已归档。

### 7. 大重构混入 bugfix commit

**症状**: bugfix commit 中包含 200+ 行的重构改动
**根因**: AI 在修复过程中发现了"可以改进的地方"
**修复**: bugfix commit 只包含最小修复 + 回归测试。重构是独立的后续任务。

---

## 决策树

### 这个 Bug 需要回归测试吗？

```
Bug 来源？
├── 用户报告 / 生产环境 → 必须写回归测试
├── QA 发现 → 必须写回归测试
├── Code Review 发现
│   ├── 修复非显而易见 → 写回归测试
│   └── 简单拼写错误 → 回归测试可选
└── 自己开发中发现
    ├── 涉及边界条件/并发/nil处理 → 写回归测试
    └── 简单逻辑错误（一行修改） → 回归测试可选
```

### Bugfix 工作流检查清单

```
□ YAML test case 已添加（包含 regression_for）?
□ python Scripts/tools/test-cases.py validate 通过?
□ Swift 测试已写且先运行失败 (Red)?
□ 最小修复已写且测试通过 (Green)?
□ 已有测试没有被修改或删除?
□ 全套测试通过 (xcodebuild test)?
□ validate sync 通过?
□ 一个原子 commit（test + fix + YAML）?
□ Commit message 包含 regression_for 引用?
```

---

## Never Do（放在文件末尾）

- **NEVER** fix a bug without writing a regression test first — no exceptions for "simple" fixes
- **NEVER** remove or weaken existing passing tests to make your fix pass
- **NEVER** commit test and fix separately — always ONE atomic commit
- **NEVER** skip the Red phase — the test MUST fail before the fix is applied
- **NEVER** write regression test cases in JSON format — use YAML in `packages/test-cases/`
- **NEVER** mix large refactoring into a bugfix commit — keep fixes minimal and focused

---

## 关联 Playbooks

| Playbook | 关系 | 何时参考 |
|----------|------|----------|
| [ctx-testing-001](../ctx-testing-001-unit-test-quick-nimble.md) | **前置 — 测试技术基础** | Meszaros 替身分类(HR-2)、@TestState(HR-7)、YAML-first 工作流(HR-3) 均为本文前提 |
| [ctx-testing-002](../ctx-testing-002-bdd-best-practices.md) | **前置 — BDD 结构规范** | 回归测试的 describe/context/it 结构和 Given-When-Then 模式来自 BDD playbook |
| [ctx-sources-001](../../sources/tech/ctx-sources-001-swift-best-practices.md) | **上游 — Swift 安全规则** | 修复 bug 时 guard let、Optional 处理等 Swift 规则 |
