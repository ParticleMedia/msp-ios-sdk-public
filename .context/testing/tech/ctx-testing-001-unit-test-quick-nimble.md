---
id: ctx-testing-001
title: "Unit Test 最佳实践 — Quick/Nimble (AI-First)"
layer: tech
domain: testing
tags: [unit-test, quick, nimble, test-doubles, meszaros, tdd, yaml-first, test-state, async-spec]
triggers: [unit test, Quick, Nimble, QuickSpec, AsyncSpec, TestState, expect, mock, stub, spy, fake, dummy, test double, "@testable"]
summary: "Quick/Nimble 单元测试硬规则与软规则，覆盖 @TestState、AsyncSpec、Meszaros 测试替身、YAML-first 工作流、断言模式"
version: "2.1"

created: 2026-02-22
updated: 2026-02-22
source: manual
status: active
confidence: high
---

# Unit Test 最佳实践 — Quick/Nimble (AI-First)

---

## 硬规则 (Hard Rules)

### HR-1: 禁止使用第三方 Mocking 框架 — 只用手写测试替身

**Citation**: Meszaros *xUnit Test Patterns* (http://xunitpatterns.com/), Fowler "Test Double" (https://martinfowler.com/bliki/TestDouble.html)

```swift
// CORRECT: hand-rolled test double implementing protocol
protocol AdRepositoryProtocol {
    func loadAd(parameters: [String: String], completion: @escaping (Result<Ad, Error>) -> Void)
}

final class MockLoadAdRepository: AdRepositoryProtocol {
    // Meszaros Type: Mock — Stub + Spy combined
    private(set) var loadCallCount = 0
    private(set) var lastParameters: [String: String]?
    var shouldSucceed = true
    var mockAd: Ad?

    func loadAd(parameters: [String: String], completion: @escaping (Result<Ad, Error>) -> Void) {
        loadCallCount += 1
        lastParameters = parameters
        if shouldSucceed, let ad = mockAd {
            completion(.success(ad))
        } else {
            completion(.failure(NSError(domain: "Mock", code: -1)))
        }
    }
}

// WRONG: importing third-party mocking framework
// import Cuckoo        // FORBIDDEN
// import Mockolo       // FORBIDDEN
// import SwiftyMocky   // FORBIDDEN
```

### HR-2: 测试替身必须使用 Meszaros 分类法命名 (Dummy/Stub/Spy/Mock/Fake)

**Citation**: Meszaros *xUnit Test Patterns* (https://martinfowler.com/books/meszaros.html), Fowler "Mocks Aren't Stubs" (https://martinfowler.com/articles/mocksArentStubs.html)

每个测试替身的类声明上方必须标注 Meszaros 分类:

```swift
// Meszaros Type: Dummy — satisfies parameter, never called
final class DummyAdNetworkAdapter: AdNetworkAdapterProtocol { ... }

// Meszaros Type: Stub — returns canned data, no call tracking
final class StubPlacementsRepository: PlacementsRepositoryProtocol { ... }

// Meszaros Type: Spy — records calls for verification
final class SpyAnalyticsService: AnalyticsServiceProtocol { ... }

// Meszaros Type: Mock — Stub + Spy combined
final class MockDebugSectionsRepository: DebugSectionsRepositoryProtocol { ... }

// Meszaros Type: Fake — lightweight working implementation
final class FakeDebugSection: DebugSectionProtocol { ... }
```

命名规则: `{MeszarosType}{ClassName}` — 如 `MockLoadAdRepository`, `StubConfig`, `SpyAnalytics`.

### HR-3: 必须遵循 YAML-first 工作流 (YAML 定义 -> 校验 -> 实现 -> 同步)

**Citation**: 项目工作流 (packages/test-cases/_schema.yaml)

```yaml
# Step 1: 在 packages/test-cases/{feature}/{Module}.yaml 定义测试用例
module: DebugAdLoad
prefix: DAL
description: Test cases for Debug Ad Load feature
cases:
  - id: DAL016
    type: behavior
    description: Should not crash when placement list is nil
    priority: high
    tags: [behavior, edge-case]
    given: API returns null for placements field
    when: ViewModel initializes
    then: Sections array is empty and no crash occurs
    doubles:
      placementsRepository:
        type: mock
        class: MockPlacementsRepository
        reason: "Stub empty placements for nil scenario"
```

```bash
# Step 2: 校验 YAML
python Scripts/tools/test-cases.py validate

# Step 3: 实现 Swift 测试 (使用 [PREFIX###] ID)
# Step 4: 检查同步状态
python Scripts/tools/test-cases.py sync
```

### HR-4: 禁止在 setup/teardown 中 force-unwrap — 仅在断言中允许

**Citation**: 项目规则 — AI agent 经常在 beforeEach 中使用 force-unwrap 导致 setup 崩溃

```swift
// WRONG: force-unwrap in beforeEach — crashes mask test failures
beforeEach {
    let data = try! JSONDecoder().decode(Config.self, from: jsonData) // crash = no diagnostics
    sut = ViewModel(config: data)
}

// CORRECT: guard let in beforeEach, fail() on unexpected nil
beforeEach {
    guard let data = try? JSONDecoder().decode(Config.self, from: jsonData) else {
        fail("Failed to decode test config fixture")
        return
    }
    sut = ViewModel(config: data)
}

// EXCEPTION: inside it() blocks, force-unwrap is acceptable — crash = test failure
it("[DAL013] should emit ad presentation signal") {
    let signal = receivedSignals.first!  // crash here = test failure, acceptable
    expect(signal.adType).to(equal(.banner))
}
```

### HR-5: 必须使用 `override class func spec()` (非 `override func spec()`)

**Citation**: Quick 7.0 迁移指南 (https://github.com/Quick/Quick/blob/main/Documentation/en-us/Migration-Guide-Quick-7.md)

```swift
// CORRECT: class func — Quick 7.0+ requirement
class DebugAdLoadViewModelSpec: QuickSpec {
    override class func spec() { // <-- class func
        describe("DebugAdLoadViewModel") { ... }
    }
}

// WRONG: instance func — tests compile but SILENTLY SKIP at runtime
class DebugAdLoadViewModelSpec: QuickSpec {
    override func spec() { // <-- instance func, SILENT SKIP
        describe("DebugAdLoadViewModel") { ... }
    }
}
```

### HR-6: 被测模块必须使用 `@testable import`

**Citation**: Swift 访问控制文档 (https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/)

```swift
import Combine
import Nimble
import Quick
import UIKit

@testable import MSPCore        // access internal symbols
@testable import MSPiOSCore     // access internal symbols

// WRONG: plain import — cannot access internal members
// import MSPCore
```

### HR-7: ALWAYS use `@TestState` for test variables — 禁止手动 afterEach nil 化

**Citation**: Quick 7.0+ `@TestState` property wrapper ([Quick/TestState.swift](https://github.com/Quick/Quick/blob/main/Sources/Quick/TestState.swift)), 自 Quick 6.1 引入, 7.3 完善

`@TestState` 是 Quick 提供的 property wrapper，自动在每个测试结束后将变量 nil 化。消除手动 `afterEach { someVar = nil }` 的样板代码，防止测试间状态泄漏。

```swift
// ✅ CORRECT: @TestState 自动清理，无需 afterEach
describe("DebugAdLoadViewModel") {
    @TestState var sectionsRepository: MockDebugSectionsRepository!
    @TestState var placementsRepository: MockPlacementsRepository!
    @TestState var loadAdRepository: MockLoadAdRepository!
    @TestState var cancellables: Set<AnyCancellable>!

    beforeEach {
        sectionsRepository = MockDebugSectionsRepository()
        placementsRepository = MockPlacementsRepository()
        loadAdRepository = MockLoadAdRepository()
        cancellables = []
    }
    // ↑ 无需 afterEach — @TestState 在每个 it() 结束后自动 nil 化所有变量

    it("[DAL006] creates sections from repository data") {
        let sut = DebugAdLoadViewModel(
            debugSectionsRepository: sectionsRepository,
            placementsRepository: placementsRepository,
            loadAdRepository: loadAdRepository
        )
        expect(sut.sections.count).to(beGreaterThan(0))
    }
}
```

```swift
// ❌ WRONG: 手动 var! + afterEach nil 化（Quick 7 之前的旧模式）
describe("DebugAdLoadViewModel") {
    var sectionsRepository: MockDebugSectionsRepository!
    var placementsRepository: MockPlacementsRepository!

    beforeEach {
        sectionsRepository = MockDebugSectionsRepository()
        placementsRepository = MockPlacementsRepository()
    }

    afterEach {
        sectionsRepository = nil  // 重复样板代码
        placementsRepository = nil
    }
}
```

**Why**: 手动 nil 化容易遗忘，导致测试间状态泄漏。`@TestState` 利用 Quick 的 `addTeardownBlock` 机制，保证在所有 `afterEach` 之后执行清理。

**注意**: `@TestState` 也支持内联默认值:
```swift
@TestState var count: Int! = 0  // 每个测试前设为 0，测试后 nil 化
```

---

### HR-8: Combine 订阅使用 @TestState 自动管理生命周期

**Citation**: Apple Combine 框架 AnyCancellable + Quick @TestState

```swift
// ✅ CORRECT: @TestState 自动管理 cancellables 生命周期
describe("DebugAdLoadViewModel") {
    @TestState var cancellables: Set<AnyCancellable>!
    @TestState var sut: DebugAdLoadViewModel!

    beforeEach {
        cancellables = []
        sut = makeSUT()
    }
    // @TestState 确保每个测试后 cancellables 被 nil 化
    // AnyCancellable 的 deinit 会自动取消订阅

    it("[DAL013] should emit signal") {
        var receivedSignal: DebugAdPresentationSignal?
        sut.adPresentationPublisher
            .sink { receivedSignal = $0 }
            .store(in: &cancellables)
        sut.loadAd()
        expect(receivedSignal).toEventuallyNot(beNil())
    }
}
```

```swift
// ❌ WRONG: 手动 afterEach 清理（冗余且容易遗忘）
afterEach {
    cancellables.removeAll()
    cancellables = nil
}
```

**Why**: `AnyCancellable` 在 deinit 时自动取消订阅。`@TestState` nil 化触发 deinit，无需手动 `removeAll()`。

### HR-9: 测试行为而非实现细节 — 通过公共 API 测试

**Citation**: Fowler "Mocks Aren't Stubs" (https://martinfowler.com/articles/mocksArentStubs.html), Kent Beck *TDD by Example*

```swift
// WRONG: testing internal call sequence (implementation detail)
sut.performAction()
expect(mockService.internalStepACallCount).to(equal(1))
expect(mockService.internalStepBCallCount).to(equal(1))

// CORRECT: testing the observable outcome (behavior)
sut.performAction()
expect(sut.state).toEventually(equal(.completed))
expect(sut.outputItems.count).to(equal(3))
```

### HR-10: 异步断言必须使用 `toEventually` — 禁止 sleep/wait

**Citation**: Nimble 异步匹配器文档 (https://github.com/Quick/Nimble#asynchronous-expectations)

```swift
// CORRECT: Nimble polls until condition is met or timeout
sut.load()
expect(sut.state).toEventually(equal(.loaded), timeout: .seconds(3))

// WRONG: Thread.sleep blocks the run loop, flaky
sut.load()
Thread.sleep(forTimeInterval: 1.0)
expect(sut.state).to(equal(.loaded))

// WRONG: DispatchQueue.asyncAfter, equally fragile
DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    expect(sut.state).to(equal(.loaded))
}
```

### HR-11: 每个 `it()` 描述必须包含测试 ID [PREFIX###]

**Citation**: 项目测试用例同步工作流 (packages/test-cases/_prefixes.yaml)

```swift
// CORRECT: test ID in it() description
it("[DAL001] should create view models from section data") { ... }
it("[DAL013] should emit ad presentation signal on successful load") { ... }

// WRONG: missing test ID
it("should create view models") { ... }
it("emits signal") { ... }
```

### HR-12: 测试质量不妥协 — 需要重命名/重构直接改，不做兼容

**Citation**: 项目指令 — 测试质量优先于向后兼容

```swift
// 发现分类错误时，直接重命名，不保留别名
// WRONG: keeping alias for "compatibility"
typealias MockConfig = StubConfig  // NO — misleading taxonomy

// CORRECT: rename directly, update all references
// Old: MockConfig (was actually a Stub, no spy behavior)
// New: StubConfig — matches Meszaros taxonomy
final class StubConfig: ConfigProtocol {
    var valueToReturn: String = ""
    func get(key: String) -> String { valueToReturn }
}
```

---

## 软规则 (Advisory Rules)

### AR-1: 应使用 shared examples (itBehavesLike) 处理重复行为模式

多个 context 产生相同可观测行为时，提取 shared example 减少重复。

### AR-2: 测试文件应控制在 200 行以内 — 按功能拆分

超过 200 行时考虑拆分为 `{Feature}InitSpec.swift` / `{Feature}LoadSpec.swift` 等。

### AR-3: 应使用 TestDataFactory 创建复杂测试对象

避免在每个测试中手动构建复杂对象，集中到 factory 方法中。

### AR-4: 每个 `it()` 块只测试一个行为

一个 `it()` 中多个不相关断言会模糊失败原因。

### AR-5: 应使用 `context("when ...")` 分离不同初始状态

状态相关的场景用 context 分组，每个 context 有自己的 beforeEach。

### AR-6: 应使用 FixtureLoader 加载 JSON 测试数据

JSON fixture 放在 `packages/mock-data/`，通过 FixtureLoader 加载。

### AR-7: 值比较优先使用 `equal()` 而非 `be()`

`equal()` 使用 `==`，`be()` 使用 `===`（引用比较）。值类型一律用 `equal()`。

### AR-8: `waitUntil` 仅用于无法使用 toEventually 的真正异步操作

```swift
// waitUntil: for completion-handler-based APIs that can't use toEventually
it("[DAL003] should complete multi-step async flow") {
    waitUntil(timeout: .seconds(3)) { done in
        sut.performAsyncWork { result in
            expect(result).to(beSuccess())
            done()
        }
    }
}
```

---

## QuickSpec vs AsyncSpec 选择指南

Quick 7.0 引入了 `AsyncSpec`，专门用于需要 `async/await` 的测试场景。

> Source: [Quick v7.0.0 Release](https://github.com/Quick/Quick/releases/tag/v7.0.0), [AsyncSpec 文档](https://github.com/Quick/Quick/blob/main/Documentation/en-us/AsyncAwait.md)

### 什么时候用哪个？

```
这个测试需要 async/await 吗？
├── 不需要（同步 ViewModel / Repository 测试）
│   └── 用 QuickSpec ← 项目大多数测试应该用这个
├── 需要测试 actor
│   └── 用 AsyncSpec（actor 方法必须 await）
├── 需要测试 async 函数
│   └── 用 AsyncSpec
└── Combine publisher 测试
    ├── 用 .sink + toEventually → QuickSpec（推荐，已有模式）
    └── 用 publisher.values + for await → AsyncSpec（可选）
```

### AsyncSpec 完整示例

```swift
import Quick
import Nimble
@testable import MSPCore

// AsyncSpec 允许在 beforeEach / it 中使用 async/await
final class AsyncExampleSpec: AsyncSpec {
    override class func spec() {
        describe("AsyncDataService") {
            @TestState var service: AsyncDataService!

            beforeEach {
                service = AsyncDataService()
            }

            it("[SVC001] should fetch data asynchronously") {
                let result = await service.fetchData()
                expect(result).toNot(beEmpty())
            }

            context("when network is unavailable") {
                it("[SVC002] should return cached data") {
                    let result = await service.fetchDataOffline()
                    expect(result.isFromCache).to(beTrue())
                }
            }
        }
    }
}
```

### 关键差异

| 特性 | `QuickSpec` | `AsyncSpec` |
|------|-------------|-------------|
| 执行上下文 | 同步，主线程 | 异步，Swift concurrency |
| `async/await` | 不支持 | `beforeEach`/`afterEach`/`it` 均支持 |
| `@TestState` | ✅ 支持 | ✅ 支持 |
| `sharedExamples` | ✅ 支持 | ❌ 不可用 |
| 线程保证 | 主线程 | 无线程保证（需要 `@MainActor` 标注） |
| Combine 测试 | `.sink` + `toEventually` | 可用 `publisher.values` + `for await` |

### 注意事项

- **项目现有测试全部使用 `QuickSpec`** — 新增同步测试继续使用 QuickSpec
- AsyncSpec 中需要主线程操作时，用 `@MainActor in` 标注闭包
- AsyncSpec 不支持 `sharedExamples` — 如果需要共享示例，使用 QuickSpec
- Nimble 的 `toEventually` 在 AsyncSpec 中需要 `await` 前缀: `await expect(...).toEventually(...)`

---

## Meszaros 替身选择决策树

```
需要测试替身?
├── 只需要填充参数? → Dummy（空实现，不被调用）
├── 需要控制返回值? → Stub（返回预设值）
├── 需要验证是否被调用? → Spy（记录调用 + 可返回预设值）
├── 需要验证调用顺序/参数? → Mock（预设期望，自动验证）
└── 需要简化但可工作的实现? → Fake（如内存数据库、值类型数据）
```

### 完整 Swift 示例

```swift
// ─── Dummy: 满足参数需求，永远不应被调用 ───
// Meszaros Type: Dummy — satisfies parameter, never called
final class DummyAdNetworkAdapter: AdNetworkAdapterProtocol {
    func loadAd(parameters: [String: String], completion: @escaping (Result<Ad, Error>) -> Void) {
        fatalError("DummyAdNetworkAdapter should never be called")
    }
}

// ─── Stub: 返回预设数据，不记录调用 ───
// Meszaros Type: Stub — returns canned data, no call tracking
final class StubPlacementsRepository: PlacementsRepositoryProtocol {
    var placementsToReturn: [String] = []
    func fetchPlacements() -> [String] { placementsToReturn }
}

// ─── Spy: 记录调用信息，用于验证 ───
// Meszaros Type: Spy — records calls for verification
final class SpyAnalyticsService: AnalyticsServiceProtocol {
    private(set) var trackedEvents: [(name: String, params: [String: Any])] = []
    func track(event: String, params: [String: Any]) {
        trackedEvents.append((name: event, params: params))
    }
}

// ─── Mock: Stub + Spy 组合（项目中最常见） ───
// Meszaros Type: Mock — Stub + Spy combined
final class MockLoadAdRepository: LoadAdRepositoryProtocol {
    // Spy behavior
    private(set) var loadCallCount = 0
    private(set) var lastParameters: [String: String]?
    // Stub behavior
    var shouldSucceed = true
    var mockAd: Ad?
    var errorMessage = "mock error"

    func loadAd(parameters: [String: String], completion: @escaping (Result<Ad, Error>) -> Void) {
        loadCallCount += 1
        lastParameters = parameters
        if shouldSucceed, let ad = mockAd {
            completion(.success(ad))
        } else {
            completion(.failure(NSError(domain: "Mock", code: -1,
                                        userInfo: [NSLocalizedDescriptionKey: errorMessage])))
        }
    }
}

// ─── Fake: 轻量级可工作实现 ───
// Meszaros Type: Fake — lightweight working implementation (value type)
struct FakeDebugSection: DebugSectionProtocol {
    var title: String
    var options: [DebugOptionProtocol]
    var showCondition: ShowCondition?

    static func minimal() -> FakeDebugSection {
        FakeDebugSection(title: "Test Section", options: [FakeDebugOption.default()], showCondition: nil)
    }
}
```

---

## AI 常犯错误

### 1. 在生产代码中加 force-unwrap "方便测试"

生产代码必须保持安全。force-unwrap 只在 `it()` 断言块中可接受。

### 2. 用错测试替身类型

只需要返回数据时用了 Mock（带 Spy 开销）。先问: "我需要验证调用吗？" 不需要就用 Stub。

### 3. 不使用 @TestState，手动写 afterEach nil 化

Quick 7.0 提供了 `@TestState`，AI 仍然生成旧模式 `var x!` + `afterEach { x = nil }`。应该用 `@TestState var x!` 替代，省去 afterEach。

### 4. 使用 `override func spec()` 而非 `override class func spec()`

Quick 7.0 要求 `class func`。实例方法编译通过但运行时静默跳过所有测试。

### 5. 测试实现细节而非行为

验证内部方法调用顺序属于实现细节。改为验证可观测的输出/状态变化。

### 6. 异步测试使用 Thread.sleep 而非 toEventually

`Thread.sleep` 阻塞线程、引入时序脆弱性。`toEventually` 自动轮询直到条件满足或超时。

### 7. 缺少测试 ID [PREFIX###]

每个 `it()` 都必须包含 YAML 定义中的测试 ID，格式: `[DAL001]`、`[DRC002]`。缺少会导致同步检查失败。

### 8. 同步测试使用 AsyncSpec

大部分 ViewModel/Repository 测试是同步的，应使用 `QuickSpec`。只有测试 actor 或 async 函数时才用 `AsyncSpec`。错用 AsyncSpec 会引入不必要的线程不确定性。

### 9. AsyncSpec 中忘记 `await` 前缀

在 `AsyncSpec` 中使用 Nimble 的 `toEventually` 时，必须加 `await` 前缀: `await expect(...).toEventually(...)`。遗漏会导致编译错误或运行时超时。

---

## Never Do（放在文件末尾）

- **NEVER** use third-party mocking frameworks (Cuckoo, Mockolo, Sourcery) — hand-roll all test doubles using Meszaros taxonomy
- **NEVER** force-unwrap in `beforeEach` / `afterEach` / test setup — use `guard let` + `fail()` instead
- **NEVER** use `override func spec()` — must be `override class func spec()` (Quick 7.0)
- **NEVER** use `Thread.sleep` for async testing — use Nimble `toEventually` or `waitUntil`
- **NEVER** skip YAML definition — define test case in YAML first, then implement in Swift
- **NEVER** compromise on test quality — rename, rewrite, refactor directly; no backward-compatible aliases
- **NEVER** use manual `var x!` + `afterEach { x = nil }` — use `@TestState var x!` instead (Quick 7.0+)
- **NEVER** use `AsyncSpec` for synchronous tests — use `QuickSpec` for ViewModel/Repository tests without async/await

---

## 关联 Playbooks

| Playbook | 关系 | 何时参考 |
|----------|------|----------|
| [ctx-testing-002](../ctx-testing-002-bdd-best-practices.md) | **互补 — BDD 结构规范** | 编写 describe/context/it 结构、命名规范、Given-When-Then 模式时 |
| [ctx-testing-003](../ctx-testing-003-bugfix-regression.md) | **互补 — 回归测试工作流** | 修复 bug 需要写回归测试时（Red→Green→Refactor + YAML-first） |
| [ctx-sources-001](../../sources/tech/ctx-sources-001-swift-best-practices.md) | **上游 — Swift 语言规则** | force-unwrap 在测试中的例外规则（本文 HR-4）源自 Swift playbook |
| [ctx-sources-003](../../sources/tech/ctx-sources-003-mvvm-repo.md) | **上游 — 架构指南** | 设计 Repository/ViewModel 测试替身时参考分层架构 |
