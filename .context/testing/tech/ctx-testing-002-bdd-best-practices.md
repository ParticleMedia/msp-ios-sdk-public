---
id: ctx-testing-002
title: "BDD 最佳实践 — Given/When/Then (AI-First)"
layer: tech
domain: testing
tags: [bdd, given-when-then, quick, describe, context, it, behavior-driven, test-state]
triggers: [BDD, behavior, Given, When, Then, describe, context, it, scenario, acceptance, TestState, beforeEach]
summary: "BDD 行为驱动开发硬规则与软规则，覆盖 describe/context/it 结构、Given-When-Then 模式、命名规范"
version: "2.1"
created: 2026-02-22
updated: 2026-02-23
source: manual
status: active
confidence: high
---

# BDD 最佳实践 — Given/When/Then (AI-First)

---

## 硬规则 (Hard Rules)

### HR-1: 测试结构必须遵循 describe -> context -> it (最多 3 层嵌套)

**Citation**: Dan North "Introducing BDD" (https://dannorth.net/introducing-bdd/), Quick 文档 (https://github.com/Quick/Quick/blob/main/Documentation/en-us/QuickExamplesAndExampleGroups.md)

```
describe("ClassName")            <- Level 1: 被测对象
  context("when condition")      <- Level 2: 场景/前置条件
    it("[ID] should behavior")   <- Level 3: 期望行为
```

```swift
// CORRECT: 3-level structure
describe("DebugAdLoadViewModel") {
    context("when load succeeds") {
        it("[DAL013] should emit ad presentation signal") { ... }
    }
    context("when load fails") {
        it("[DAL014] should emit toast signal with error") { ... }
    }
}

// WRONG: 4+ levels — test is doing too much, refactor
describe("DebugAdLoadViewModel") {
    context("when Nova is selected") {
        context("when interstitial is selected") {
            context("when bid succeeds") {     // Level 4 — TOO DEEP
                it("should show creative type") { ... }
            }
        }
    }
}
```

### HR-2: 每个 it() 块必须遵循 Given-When-Then 结构

**Citation**: Dan North BDD (https://dannorth.net/introducing-bdd/), Cucumber BDD 历史 (https://cucumber.io/docs/bdd/)

```swift
context("when bid succeeds") {
    it("[DAL006] should create sections from repository data") {
        // Given: configure the precondition
        let placements = ["placement_banner", "placement_interstitial"]
        let sections = [FakeDebugSection.minimal()]
        mockPlacementsRepo.placementsToReturn = placements
        mockSectionsRepo.sectionsToReturn = sections

        // When: perform the action
        let sut = DebugAdLoadViewModel(
            debugSectionsRepository: mockSectionsRepo,
            placementsRepository: mockPlacementsRepo,
            loadAdRepository: mockLoadAdRepo
        )

        // Then: verify the outcome
        expect(sut.sections.count).to(equal(sections.count))
    }
}
```

Given 可以放在 `beforeEach` 中（共享前置条件），When/Then 放在 `it()` 中。

### HR-3: context 描述必须以 "when" 或 "with" 开头

**Citation**: Quick 社区约定 (https://github.com/Quick/Quick/blob/main/Documentation/en-us/QuickExamplesAndExampleGroups.md), BDD 命名规范

```swift
// CORRECT: clear conditional prefix
context("when network fails") { ... }
context("when Nova ad network is selected") { ... }
context("with empty placements list") { ... }
context("with production-like sections") { ... }

// WRONG: vague or non-conditional context names
context("network") { ... }           // not a condition
context("test error handling") { ... } // describes the test, not the state
context("success case") { ... }       // not prefixed with when/with
```

**例外**: 生命周期阶段允许使用 `context("initialization")` 或 `context("deallocation")`。

### HR-4: 共享 setup 使用 @TestState + beforeEach，禁止在 it() 中重复

**Citation**: Quick 文档 — beforeEach 共享设置 (https://github.com/Quick/Quick/blob/main/Documentation/en-us/SettingUpSharedExampleContextsWithBeforeEach.md), Quick @TestState (https://github.com/Quick/Quick/blob/main/Sources/Quick/TestState.swift)

```swift
// ✅ CORRECT: @TestState + beforeEach 组合（Quick 7.0+ 推荐模式）
describe("DebugAdLoadViewModel") {
    @TestState var sut: DebugAdLoadViewModel!
    @TestState var mockSectionsRepo: MockDebugSectionsRepository!
    @TestState var mockPlacementsRepo: MockPlacementsRepository!
    @TestState var mockLoadAdRepo: MockLoadAdRepository!
    @TestState var cancellables: Set<AnyCancellable>!

    beforeEach {
        mockSectionsRepo = MockDebugSectionsRepository()
        mockPlacementsRepo = MockPlacementsRepository()
        mockLoadAdRepo = MockLoadAdRepository()
        cancellables = []
    }
    // ↑ 无需 afterEach — @TestState 在每个 it() 结束后自动 nil 化

    context("when all repositories return data") {
        beforeEach {
            mockSectionsRepo.sectionsToReturn = TestDataFactory.createProductionSections()
            mockPlacementsRepo.placementsToReturn = ["placement_1"]
            sut = DebugAdLoadViewModel(
                debugSectionsRepository: mockSectionsRepo,
                placementsRepository: mockPlacementsRepo,
                loadAdRepository: mockLoadAdRepo
            )
        }

        it("[DAL006] should create sections from repository data") {
            expect(sut.sections).toNot(beEmpty())
        }
    }
}
```

```swift
// ❌ WRONG: 旧模式 — 手动 var! + afterEach nil 化
describe("DebugAdLoadViewModel") {
    var sut: DebugAdLoadViewModel!         // 没有 @TestState
    var mockSectionsRepo: MockDebugSectionsRepository!

    beforeEach { mockSectionsRepo = MockDebugSectionsRepository() }
    afterEach { mockSectionsRepo = nil; sut = nil }  // 冗余样板
}

// ❌ WRONG: 在每个 it() 中重复 setup
it("should create sections") {
    let mockSectionsRepo = MockDebugSectionsRepository() // duplicated
    let mockPlacementsRepo = MockPlacementsRepository()   // duplicated
}
```

### HR-5: 每个 it() 块只能有一个逻辑断言

**Citation**: Single Assertion Principle, Kent Beck *TDD by Example* (https://www.oreilly.com/library/view/test-driven-development/0321146530/)

```swift
// CORRECT: one logical assertion per it()
it("[DAL009] should show creative type section when Nova + Interstitial selected") {
    expect(sut.sections[creativeSectionIndex].isVisible).to(beTrue())
}

it("[DAL010] should hide layout section when non-Nova selected") {
    expect(sut.sections[layoutSectionIndex].isVisible).to(beFalse())
}

// WRONG: multiple unrelated assertions in one test
it("should work correctly") {
    expect(sut.sections.count).to(equal(5))
    expect(sut.title).to(equal("Ad Load"))
    expect(mockAnalytics.trackedEvents).to(contain("page_view"))
    expect(sut.isLoading).to(beFalse())
}
```

**注意**: 对同一行为的多个 `expect` 是允许的（如验证一个 struct 的多个字段），但不同行为必须分开。

### HR-6: describe() 必须以被测类名命名

**Citation**: BDD 命名规范, Dan North BDD (https://dannorth.net/introducing-bdd/)

```swift
// CORRECT: class name as describe subject
describe("DebugAdLoadViewModel") { ... }
describe("DebugAdLoadSectionViewModel") { ... }

// WRONG: vague or action-based naming
describe("ad loading tests") { ... }
describe("test the view model") { ... }
```

### HR-7: it() 描述必须是以 "should" 开头的完整行为句

**Citation**: BDD specification 风格, RSpec 社区规范

```swift
// CORRECT: complete behavior sentence with test ID
it("[DAL001] should create view models from section data") { ... }
it("[DAL013] should emit ad presentation signal on successful load") { ... }
it("[DAL014] should emit toast signal on load error") { ... }

// WRONG: incomplete, vague, or action-based
it("[DAL001] creates view models") { ... }      // missing "should"
it("[DAL013] test signal emission") { ... }      // not a behavior sentence
it("works") { ... }                              // no ID, no behavior
```

### HR-8: 禁止在一个 it() 中测试多个行为

**Citation**: Single Responsibility Principle for tests, Kent Beck

```swift
// WRONG: testing load AND error AND analytics in one it()
it("[DAL013] should handle loading") {
    sut.loadAd()
    expect(sut.state).toEventually(equal(.loaded))      // behavior 1
    expect(mockAnalytics.trackedEvents).to(contain("ad_load"))  // behavior 2
    expect(mockLoadAdRepo.loadCallCount).to(equal(1))    // behavior 3
}

// CORRECT: separate it() per behavior
it("[DAL013] should emit ad presentation signal on successful load") {
    sut.loadAd()
    expect(receivedSignal).toEventuallyNot(beNil())
}

it("[DAL013b] should track ad load event on success") {
    sut.loadAd()
    expect(spyAnalytics.trackedEvents).toEventually(contain("ad_load"))
}
```

### HR-9: 必须使用 context() 分离不同初始状态

**Citation**: BDD 状态场景分离, Dan North

```swift
// CORRECT: separate contexts for different states
describe("DebugAdLoadViewModel") {
    context("when Nova + Interstitial are selected") {
        beforeEach { /* configure Nova + Interstitial state */ }
        it("[DAL009] should show creative type section") { ... }
    }

    context("when non-Nova network is selected") {
        beforeEach { /* configure non-Nova state */ }
        it("[DAL010] should hide Nova-specific sections") { ... }
    }
}

// WRONG: using if/else inside one it() to test different states
it("should handle visibility") {
    // scenario 1
    sut.selectNetwork(.nova)
    expect(sut.creativeSectionVisible).to(beTrue())
    // scenario 2
    sut.selectNetwork(.google)
    expect(sut.creativeSectionVisible).to(beFalse())
}
```

### HR-10: Quick/Nimble spec 中禁止使用 XCTAssert — 只用 Nimble 匹配器

**Citation**: 框架一致性, Nimble 匹配器语义 (https://github.com/Quick/Nimble)

```swift
// CORRECT: Nimble matchers
expect(sut.items.count).to(equal(3))
expect(sut.title).toNot(beNil())
expect(sut.isLoading).to(beFalse())
expect(sut.sections).to(beEmpty())

// WRONG: XCTest assertions in Quick specs
XCTAssertEqual(sut.items.count, 3)    // FORBIDDEN in QuickSpec
XCTAssertNotNil(sut.title)            // FORBIDDEN in QuickSpec
XCTAssertFalse(sut.isLoading)         // FORBIDDEN in QuickSpec
```

---

## 软规则 (Advisory Rules)

### AR-1: 应使用 shared examples 处理跨 context 的共同行为

```swift
class LoadStateSharedExamples {
    static func transitionsToLoaded() -> SharedExampleClosure {
        return { context in
            it("should set state to loaded") {
                let sut = context()["sut"] as! AdLoadViewModel
                expect(sut.state).toEventually(equal(.loaded))
            }
        }
    }
}

context("when loading banner") {
    beforeEach { /* setup banner */ }
    itBehavesLike(LoadStateSharedExamples.transitionsToLoaded()) { ["sut": sut as Any] }
}
```

### AR-2: describe/context/it 嵌套应控制在 2 层 (最多 3 层)

2 层是理想状态; 3 层是硬上限。超过说明测试覆盖范围过大，需拆分。

### AR-3: beforeEach 中应使用有意义的变量名

```swift
// Preferred: descriptive names reflecting the role
var viewModel: DebugAdLoadViewModel!
var mockSectionsRepo: MockDebugSectionsRepository!

// Acceptable but less clear
var sut: DebugAdLoadViewModel!
```

### AR-4: 相关 context 应放在一起

按功能分组: 所有 "load" 相关 context 放一起，所有 "visibility" 相关 context 放一起。

### AR-5: 复杂自定义断言应使用 Nimble 的 `satisfy`

```swift
expect(sut.parameters).to(satisfy { params in
    params["network"] == "nova" && params["format"] == "interstitial"
})
```

### AR-6: 计划但未实现的测试应使用 `pending()`

```swift
pending("should handle timeout gracefully") {
    // TODO: implement when timeout feature is added
}
```

---

## 完整 BDD 测试示例

```swift
import Combine
import Nimble
import Quick
import UIKit

@testable import MSPCore
@testable import MSPiOSCore

class DebugAdLoadViewModelSpec: QuickSpec {
    override class func spec() {
        describe("DebugAdLoadViewModel") {
            // Quick 7.0+ @TestState: 自动在每个 it() 结束后 nil 化
            @TestState var sut: DebugAdLoadViewModel!
            @TestState var mockSectionsRepo: MockDebugSectionsRepository!
            @TestState var mockPlacementsRepo: MockPlacementsRepository!
            @TestState var mockLoadAdRepo: MockLoadAdRepository!
            @TestState var cancellables: Set<AnyCancellable>!

            beforeEach {
                mockSectionsRepo = MockDebugSectionsRepository()
                mockPlacementsRepo = MockPlacementsRepository()
                mockLoadAdRepo = MockLoadAdRepository()
                cancellables = []
            }
            // ↑ 无需 afterEach — @TestState 自动清理

            // --- Initialization ---
            context("when repositories provide data") {
                beforeEach {
                    // Given: repositories return production-like data
                    mockSectionsRepo.sectionsToReturn = TestDataFactory.createProductionSections()
                    mockPlacementsRepo.placementsToReturn = ["placement_banner"]
                    sut = DebugAdLoadViewModel(
                        debugSectionsRepository: mockSectionsRepo,
                        placementsRepository: mockPlacementsRepo,
                        loadAdRepository: mockLoadAdRepo
                    )
                }

                it("[DAL006] should create sections from repository data") {
                    // Then: sections are populated
                    expect(sut.sections).toNot(beEmpty())
                }

                it("[DAL007] should set default selection for sections without showCondition") {
                    // Then: default selection is applied
                    let sectionWithoutCondition = sut.sections.first {
                        $0.showCondition == nil
                    }
                    expect(sectionWithoutCondition?.selectedIndex).to(equal(0))
                }
            }

            context("with empty placements and sections") {
                beforeEach {
                    // Given: repositories return empty data
                    mockSectionsRepo.sectionsToReturn = []
                    mockPlacementsRepo.placementsToReturn = []
                    sut = DebugAdLoadViewModel(
                        debugSectionsRepository: mockSectionsRepo,
                        placementsRepository: mockPlacementsRepo,
                        loadAdRepository: mockLoadAdRepo
                    )
                }

                it("[DAL008] should handle empty data gracefully") {
                    // Then: empty but not nil
                    expect(sut.sections).to(beEmpty())
                }
            }

            // --- Ad Loading ---
            context("when load succeeds") {
                beforeEach {
                    mockSectionsRepo.sectionsToReturn = TestDataFactory.createMinimalSections()
                    mockPlacementsRepo.placementsToReturn = ["placement_1"]
                    mockLoadAdRepo.shouldSucceed = true
                    mockLoadAdRepo.mockAd = BannerAd(
                        adView: UIView(),
                        adNetworkAdapter: DummyAdNetworkAdapter()
                    )
                    sut = DebugAdLoadViewModel(
                        debugSectionsRepository: mockSectionsRepo,
                        placementsRepository: mockPlacementsRepo,
                        loadAdRepository: mockLoadAdRepo
                    )
                }

                it("[DAL013] should emit ad presentation signal on successful load") {
                    // When: load is triggered
                    var receivedSignal: Bool?
                    sut.adPresentationPublisher
                        .sink { receivedSignal = true }
                        .store(in: &cancellables)
                    sut.loadAd()

                    // Then: signal is emitted
                    expect(receivedSignal).toEventually(beTrue())
                }
            }
        }
    }
}
```

---

## Nimble 匹配器速查

| 匹配器 | 用途 | 示例 |
|---------|------|------|
| `equal(_)` | 值相等 | `expect(count).to(equal(3))` |
| `beNil()` / `beNonNil()` | Optional 检查 | `expect(error).to(beNil())` |
| `beTrue()` / `beFalse()` | Bool 检查 | `expect(visible).to(beTrue())` |
| `beEmpty()` | 空集合/字符串 | `expect(items).to(beEmpty())` |
| `contain(_)` | 集合包含元素 | `expect(tags).to(contain("smoke"))` |
| `haveCount(_)` | 集合长度 | `expect(items).to(haveCount(3))` |
| `toEventually(_)` | 异步断言 | `expect(state).toEventually(equal(.loaded))` |
| `satisfy(_)` | 自定义谓词 | `expect(val).to(satisfy { $0 > 0 })` |

---

## AI 常犯错误

### 1. 扁平结构 — 所有 it() 直接放在 describe 下，无 context 分组

缺少 context 导致无法区分不同场景的前置条件，阅读困难。

### 2. 测试实现细节而非可观测行为

验证内部方法调用顺序/次数属于实现耦合。应验证外部可观测的状态/输出变化。

### 3. 一个 it() 中混合多个不相关断言

如果测试失败，无法判断是哪个行为出了问题。拆分为独立 `it()` 块。

### 4. 在 Quick spec 中使用 XCTAssert 系列

Quick/Nimble spec 中只使用 Nimble 匹配器。`XCTAssertEqual` 等在 QuickSpec 中输出不一致。

### 5. 未使用 beforeEach 进行共享设置

每个 `it()` 中重复创建 SUT 和替身，增加维护成本和出错概率。

### 6. context 描述不以 "when"/"with" 开头

模糊的 context 名称（如 `context("error")`）无法表达前置条件。应改为 `context("when API returns error")`。

### 7. it() 描述缺少 "should" 前缀或测试 ID

`it("loads data")` 不符合 BDD 规范。正确格式: `it("[DAL006] should load data from repository")`。

---

## Never Do（放在文件末尾）

- **NEVER** use flat structure without `context()` grouping — every state variation needs its own context
- **NEVER** use XCTAssert in Quick/Nimble specs — only Nimble matchers (`expect`, `to`, `toNot`, `toEventually`)
- **NEVER** put multiple unrelated assertions in one `it()` block — one behavior per `it()`
- **NEVER** write `it()` descriptions without "should" and test ID — format: `it("[PREFIX###] should ...")`
- **NEVER** nest deeper than 3 levels (describe → context → it) — refactor into separate describe blocks
- **NEVER** duplicate setup inside `it()` blocks — use `beforeEach` for shared preconditions

---

## 关联 Playbooks

| Playbook | 关系 | 何时参考 |
|----------|------|----------|
| [ctx-testing-001](../ctx-testing-001-unit-test-quick-nimble.md) | **互补 — Quick/Nimble 技术细节** | @TestState 用法(HR-7)、Meszaros 替身分类(HR-2)、异步断言 toEventually(HR-10)、AsyncSpec 选择 |
| [ctx-testing-003](../ctx-testing-003-bugfix-regression.md) | **互补 — 回归测试 BDD 结构** | 回归测试的 context 命名 `context("regression: BUG-XXXX ...")` 遵循本文 HR-3 |
| [ctx-sources-003](../../sources/tech/ctx-sources-003-mvvm-repo.md) | **上游 — 被测架构** | ViewModel/Repository 的 BDD 测试结构参考 MVVM 分层 |
