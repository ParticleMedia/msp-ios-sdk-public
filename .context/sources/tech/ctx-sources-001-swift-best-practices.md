---
id: ctx-sources-001
title: Swift 最佳实践 (AI-First)
layer: tech
domain: sources
tags: [swift, optionals, error-handling, memory, closures, value-types]
triggers: [swift, optional, unwrap, closure, weak self, Result, enum, struct, class, let, var, access control]
summary: "Swift 5.0 / iOS 15+ 硬规则与软规则，覆盖 optionals、闭包捕获、值类型/引用类型、错误处理、访问控制"
version: "2.0"
created: 2026-02-22
updated: 2026-03-17
source: manual
status: active
confidence: high
---

# Swift 最佳实践 (AI-First)

## 适用场景

本 playbook 在 AI agent 编写或修改 `Sources/` 下 Swift 代码时自动加载。适用于 ViewModel、Repository、Service、Model 层。约束：Swift 5.0 / iOS 15+ / UIKit / CocoaPods / Quick+Nimble 手写 test doubles。

## Hard Rules (HR) — 不可违反

### HR-1: NEVER force-unwrap optionals in production code
> Source: [Optional Chaining](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/optionalchaining/) + [Google Swift Style Guide](https://google.github.io/swift/#force-unwrapping-and-force-casts)
```swift
// ✅ Correct
guard let bid = response.bid else {
    completion(.failure(BidError.noFill)); return
}
let price = bid.price ?? 0.0
let formatted = bid.price.map { String(format: "%.2f", $0) }
if let cell = tableView.dequeueReusableCell(withIdentifier: "BidCell") as? BidCell {
    cell.configure(with: bid)
}
```
```swift
// ❌ Wrong
let bid = response.bid!  // crash if nil
let cell = tableView.dequeueReusableCell(withIdentifier: "BidCell") as! BidCell
```
**Why**: Force-unwrap 在 nil 时直接 crash，线上无恢复机会。仅允许在单元测试断言中使用。

### HR-2: ALWAYS use [weak self] in escaping closures
> Source: [Swift ARC — Strong Reference Cycles for Closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/#Resolving-Strong-Reference-Cycles-for-Closures)
```swift
// ✅ Correct
repository.fetchBid { [weak self] result in
    guard let self else { return }
    switch result {
    case .success(let bid): self.currentBid = bid
    case .failure(let error): self.errorMessage = error.localizedDescription
    }
}
```
```swift
// ❌ Wrong — retain cycle: self -> repository -> closure -> self
repository.fetchBid { result in
    self.currentBid = try? result.get()  // strong capture
}
```
**Why**: 闭包强捕获 self 导致 retain cycle，对象永不释放。例外：非逃逸闭包（`map`、`filter`）不需要。

### HR-3: ALWAYS use Result<T, Error> for async callbacks
> Source: [SE-0235 — Add Result to the Standard Library](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0235-add-result.md)
```swift
// ✅ Correct
protocol BidServiceProtocol {
    func fetchBid(adUnitID: String, completion: @escaping (Result<BidResponse, Error>) -> Void)
}
```
```swift
// ❌ Wrong — 4 possible states, 2 are invalid
func fetchBid(adUnitID: String, completion: @escaping (BidResponse?, Error?) -> Void)
```
**Why**: `Result` 编译器强制 success/failure 二选一，消除 (nil, nil) 和 (value, error) 非法状态。

### HR-4: NEVER import UIKit in ViewModel or Repository layers
> Source: [objc.io MVVM](https://www.objc.io/issues/13-architecture/mvvm/)
```swift
// ✅ Correct — pure Swift ViewModel
import Foundation
import Combine
final class AdBiddingViewModel {
    @Published private(set) var bidStatus: BidStatus = .idle
    private let repository: AdBiddingRepositoryProtocol
    init(repository: AdBiddingRepositoryProtocol) { self.repository = repository }
}
```
```swift
// ❌ Wrong — UIKit makes testing require simulator
import UIKit
final class AdBiddingViewModel {
    var label: UILabel?
    func updateUI(with bid: Bid) { label?.text = bid.formattedPrice }
}
```
**Why**: UIKit 依赖使 ViewModel 无法在纯逻辑测试运行，测试速度降 10x。

### HR-5: ALWAYS use `let` over `var` unless mutation is required
> Source: [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/#conventions)
```swift
// ✅ Correct
let maxRetries = 3
private(set) var currentRetryCount = 0
let sorted = items.sorted { $0.price > $1.price }
```
```swift
// ❌ Wrong
var maxRetries = 3       // never reassigned
var endpoint = "/api/bid" // never reassigned
```
**Why**: `var` 暗示值会变，若实际不变则增加理解成本并可能引入意外修改。

### HR-6: NEVER use `Any` or `AnyObject` when a protocol or generic will work
> Source: [Swift Generics](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/)
```swift
// ✅ Correct
func decode<T: Decodable>(data: Data, as type: T.Type) -> Result<T, Error> {
    do { return .success(try JSONDecoder().decode(T.self, from: data)) }
    catch { return .failure(error) }
}
```
```swift
// ❌ Wrong — type safety lost
func decode(data: Data, as type: Any.Type) -> Any? { return nil }
func process(items: [Any]) { /* must cast every element */ }
```
**Why**: `Any` 把类型检查推迟到运行时，编译器无法帮助发现类型错误。

### HR-7: ALWAYS define protocol before implementation (Protocol-First Design)
> Source: [Swift Protocols](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/)
```swift
// ✅ Correct
protocol AdBiddingRepositoryProtocol {
    func fetchBid(completion: @escaping (Result<Bid, Error>) -> Void)
}
final class AdBiddingRepository: AdBiddingRepositoryProtocol {
    private let networkService: NetworkServiceProtocol
    init(networkService: NetworkServiceProtocol) { self.networkService = networkService }
    func fetchBid(completion: @escaping (Result<Bid, Error>) -> Void) { /* ... */ }
}
```
```swift
// ❌ Wrong — no protocol, cannot mock in tests
final class AdBiddingRepository {
    func fetchBid(completion: @escaping (Result<Bid, Error>) -> Void) { /* ... */ }
}
final class AdBiddingViewModel {
    private let repository = AdBiddingRepository()  // hard-wired
}
```
**Why**: 没有 protocol 无法注入 mock/stub，测试必须依赖真实网络层。

### HR-8: NEVER use singletons in ViewModel or Repository (use DI instead)
> Source: [Fowler — Dependency Injection](https://martinfowler.com/articles/injection.html)
```swift
// ✅ Correct — initializer injection
final class AdBiddingViewModel {
    private let repository: AdBiddingRepositoryProtocol
    init(repository: AdBiddingRepositoryProtocol) { self.repository = repository }
}
// Test: let vm = AdBiddingViewModel(repository: MockBidRepository())
```
```swift
// ❌ Wrong — singleton: hidden dependency, tests pollute each other
final class AdBiddingViewModel {
    private let repository = AdBiddingRepository.shared
}
```
**Why**: Singleton 是隐式全局状态，测试间相互污染且无法注入 test double。

### HR-9: ALWAYS handle all Result/Optional cases explicitly
> Source: [Swift Error Handling](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/)
```swift
// ✅ Correct
switch result {
case .success(let bid): self.currentBid = bid
case .failure(let error):
    logger.error("Bid failed: \(error.localizedDescription, privacy: .public)")
    self.bidStatus = .failed(error)
}
```
```swift
// ❌ Wrong — silent failure
if case .success(let bid) = result { self?.currentBid = bid }  // failure ignored
let bid = try? decoder.decode(Bid.self, from: data)  // error discarded
```
**Why**: 静默失败让 bug 隐藏在 nil 中，调试时无法追踪错误来源。

### HR-10: ALWAYS use `private` by default, promote access only as needed
> Source: [SE-0117](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0117-non-public-subclassable-by-default.md) + [Access Control](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/)
```swift
// ✅ Correct
final class BidManager {
    private let repository: AdBiddingRepositoryProtocol
    private var currentBid: Bid?
    func requestBid(completion: @escaping (Result<Bid, Error>) -> Void) { /* ... */ }
    private func validateBid(_ bid: Bid) -> Bool { bid.price > 0 }
}
```
```swift
// ❌ Wrong — all internals exposed
class BidManager {
    var repository: AdBiddingRepositoryProtocol  // externally mutable
    var currentBid: Bid?                         // anyone can overwrite
    func validateBid(_ bid: Bid) -> Bool { /* ... */ }
}
```
**Why**: 暴露内部实现增加耦合面，外部代码依赖本应隐藏的细节，重构困难。

### HR-11: PREFER async/await for new code; NEVER mix paradigms in the same call chain
> Source: SE-0300, SE-0314, WWDC21 Session 10132/10133 — iOS 15+ 支持 async/await（Swift 5.5+），存量代码渐进迁移

**基本原则**：新代码用 async/await；存量 completion handler 不强制改；同一调用链不允许两种范式混用。跨范式必须用显式 bridge 层隔离。

#### 规则 A：单次回调 → withCheckedThrowingContinuation

```swift
// ✅ 标准桥接写法
func loadBid(adUnitID: String) async throws -> Bid {
    try await withCheckedThrowingContinuation { continuation in
        legacyLoadBid(adUnitID: adUnitID) { result in
            continuation.resume(with: result)  // resume with Result<T,E> 最简洁
        }
    }
}
```

```swift
// ❌ 同一调用链混用 — async 埋在 callback 里，线程/错误传播不可控
func loadBid(adUnitID: String, completion: @escaping (Result<Bid, Error>) -> Void) {
    Task {
        let bid = try await networkService.fetchBid(adUnitID)
        completion(.success(bid))
    }
}
```

**覆盖所有代码路径**：每条分支都必须调用 resume，否则 Task 永久挂起泄漏（只有 runtime warning，无 crash）：
```swift
// ❌ (nil, nil) 时 continuation 永远挂起
if let error { continuation.resume(throwing: error) }
else if let data { continuation.resume(returning: data) }

// ✅
continuation.resume(returning: data ?? Data())
```

#### 规则 B：Delegate 单次完成 → 存为 Optional property，resume 后立即 nil

```swift
class BidSyncController: NSObject {
    private var activeContinuation: CheckedContinuation<[Bid], Error>?

    func fetchBids() async throws -> [Bid] {
        try await withCheckedThrowingContinuation { continuation in
            self.activeContinuation = continuation
            self.bidManager.startSync()
        }
    }
}

extension BidSyncController: BidManagerDelegate {
    func bidManager(_ manager: BidManager, didReceive bids: [Bid]) {
        activeContinuation?.resume(returning: bids)
        activeContinuation = nil  // 必须立即 nil，防止二次 resume → fatal trap
    }
    func bidManager(_ manager: BidManager, didFailWith error: Error) {
        activeContinuation?.resume(throwing: error)
        activeContinuation = nil
    }
}
```

#### 规则 C：多值持续回调（delegate 持续触发）→ AsyncStream，不要用 continuation

`withCheckedContinuation` 只包装**单次** suspension point，多次 resume 会 fatal trap。持续事件流用 `AsyncStream`：

```swift
// ✅ 位置更新、传感器、广告事件等持续流
static var adEvents: AsyncStream<AdEvent> {
    AsyncStream { continuation in
        let monitor = AdEventMonitor()
        monitor.onEvent = { event in continuation.yield(event) }
        continuation.onTermination = { _ in monitor.stop() }  // 取消/完成时清理资源
        monitor.start()
    }
}

// 消费侧
for await event in AdEventMonitor.adEvents {
    handle(event)
}
```

#### 规则 D：需要传播 Task 取消 → withTaskCancellationHandler 包裹 continuation

plain `withCheckedContinuation` 不响应 Task 取消，必须显式桥接：

```swift
func fetchBid(adUnitID: String) async throws -> Bid {
    var sessionTask: URLSessionDataTask?
    return try await withTaskCancellationHandler {
        sessionTask?.cancel()                     // Task 取消时同步触发
    } operation: {
        try await withCheckedThrowingContinuation { continuation in
            sessionTask = URLSession.shared.dataTask(with: bidURL) { data, _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: try! parseBid(data!)) }
            }
            sessionTask?.resume()
        }
    }
}
```

#### 规则 E：resume() 线程安全，不需要手动 hop 到主线程

runtime 自动把 task 调度回其原始 executor（包括 `@MainActor`）：
```swift
// ❌ 多余的 hop，反而增加一次调度
DispatchQueue.main.async { continuation.resume(returning: image) }

// ✅ 直接 resume，@MainActor 调用方自动在主线程恢复
continuation.resume(returning: image)
```

**Why**: iOS 15+ 完全支持 async/await。混用范式会隐藏线程切换和错误传播问题，double-resume 直接 fatal trap，never-resume 导致 Task 泄漏。`withCheckedContinuation`（Checked 变体）在开发期提供 runtime 检查，性能敏感且正确性验证后才考虑 `withUnsafeContinuation`。

### HR-12: ALWAYS use [weak self] with Combine `.sink` and `.receive(on:)`
> Source: [Apple Combine](https://developer.apple.com/documentation/combine) + [Swift ARC](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/)
```swift
// ✅ Correct
repository.adStatusPublisher
    .receive(on: DispatchQueue.main)
    .sink { [weak self] completion in
        guard let self else { return }
        if case .failure(let error) = completion { self.adStatus = .error(error) }
    } receiveValue: { [weak self] status in
        guard let self else { return }
        self.adStatus = status
    }
    .store(in: &cancellables)
```
```swift
// ❌ Wrong — retains self forever
publisher.sink { completion in
    self.handleCompletion(completion)
} receiveValue: { status in
    self.adStatus = status
}.store(in: &cancellables)
```
**Why**: `.sink` 返回的 `AnyCancellable` 持有闭包，闭包强引用 self 导致 retain cycle。

## Advisory Rules (AR) — 推荐做法

### AR-1: SHOULD use struct over class by default
值类型是 Swift 默认选择。仅在需要引用语义（identity、共享可变状态）时用 class。
```swift
struct Bid: Equatable { let id: String; let price: Double; let adNetworkName: String }
struct BidConfig { let timeout: TimeInterval; let maxRetries: Int }
```

### AR-2: SHOULD use guard for early returns
```swift
func processBid(response: BidResponse?) {
    guard let response = response else { return }
    guard response.statusCode == 200 else { return }
    guard let bid = response.bid, bid.price > 0 else { return }
    handleValidBid(bid)  // happy path, no nesting
}
```

### AR-3: SHOULD use extension to organize protocol conformances
```swift
final class AdViewController: UIViewController { /* lifecycle only */ }
extension AdViewController: UITableViewDataSource { /* data source methods */ }
extension AdViewController: UITableViewDelegate { /* delegate methods */ }
```

### AR-4: SHOULD use Logger API (iOS 14+) instead of print()
```swift
import os
private let logger = Logger(subsystem: "com.newsbreak.msp", category: "BidLoader")
logger.info("Bid started: \(adUnitID, privacy: .public)")
logger.error("Failed: \(error.localizedDescription, privacy: .public)")
```

### AR-5: SHOULD use typealias for complex closure types
```swift
typealias BidCompletion = (Result<Bid, Error>) -> Void
protocol BidServiceProtocol {
    func fetchBid(adUnitID: String, completion: @escaping BidCompletion)
}
```

### AR-6: SHOULD use enum for constants/namespace instead of struct
```swift
enum BidConstants {
    static let defaultTimeout: TimeInterval = 30
    static let maxRetryCount = 3
    static let minBidPrice: Double = 0.01
}
```
Caseless enum 无法被实例化，比 struct 更适合做纯命名空间。

### AR-7: SHOULD use map/flatMap/compactMap over manual loops for transforms
```swift
let validBids = responses.compactMap { $0.bid }
let prices = validBids.map { $0.price }
let topBids = validBids.filter { $0.price > threshold }.sorted { $0.price > $1.price }
```
Acceptable: 循环体含副作用（日志、状态修改）时用 `for-in`。

### AR-8: SHOULD document public APIs with /// comments
```swift
/// Fetches a bid for the given ad unit.
/// - Parameters:
///   - adUnitID: The unique identifier of the ad unit.
///   - completion: Called on the main queue with the bid result.
func fetchBid(adUnitID: String, completion: @escaping BidCompletion) { /* ... */ }
```

## AI 常犯错误（本项目特有）

| # | Symptom | Root Cause | Fix |
|---|---------|------------|-----|
| 1 | AI 在 callback 内嵌套 `Task { await ... }` | 混用两种并发范式 | 同一调用链选一种：新链用 async/await，存量链保持 completion handler，跨范式用 `withCheckedThrowingContinuation` + 可选 `withTaskCancellationHandler` (HR-11) |
| 1b | AI 对多值 delegate 用 `withCheckedContinuation` | 误以为可多次 resume | 多值流用 `AsyncStream`；continuation 只包装单次 suspend，二次 resume → fatal trap (HR-11-C) |
| 2 | AI 用 `!` 强制解包 | 为"简洁"跳过 nil 检查 | `guard let` / `if let` / `??` (HR-1) |
| 3 | AI 遗漏 Combine `.sink` 中 `[weak self]` | 未考虑订阅生命周期 | 所有 `.sink` 加 `[weak self]` + `guard let self` (HR-12) |
| 4 | AI 在 ViewModel 中 `import UIKit` | UI/业务逻辑混合 | 只导入 `Foundation` / `Combine` (HR-4) |
| 5 | AI 用 Mockingbird / Cuckoo 等框架 | 训练数据中第三方框架频率高 | 手写 test double：实现 protocol 的 stub/spy class |
| 6 | AI 生成 SwiftUI 代码 | 默认推荐 SwiftUI | 本项目 UIKit，用 `UIViewController` 子类 |
| 7 | AI 用 `Package.swift` / SPM 语法 | 默认推荐 SPM | 本项目 CocoaPods，依赖在 `Podfile` 管理 |

## 决策树

### Optional 如何处理？
```
值为 nil 时是否应中止流程？
├── 是 → guard let value = optional else { return / throw }
└── 否 → 有合理默认值？
    ├── 是 → let value = optional ?? defaultValue
    └── 否 → 需要转换？
        ├── 是 → optional.map { transform($0) }
        └── 否 → if let value = optional { /* 使用 */ }
```

### struct vs class?
```
需要引用语义（共享可变状态）？
├── 是 → 需要继承？
│   ├── 是 → class
│   └── 否 → final class
└── 否 → 有限枚举集？
    ├── 是 → enum
    └── 否 → struct（默认）
```

### 错误处理选择？
```
同步还是异步？
├── 异步 → Result<T, Error> + completion handler (HR-3)
└── 同步 → 失败是正常业务？
    ├── 是 → Optional (nil = 未找到)
    └── 否 → throws + do/catch
```

## Never Do（放在文件末尾）

1. **NEVER** force-unwrap (`!`) outside unit tests — 线上 crash 零容忍
2. **PREFER** async/await for new code — 不在同一调用链混用两种范式，跨范式用 `withCheckedContinuation` 显式桥接
3. **NEVER** import UIKit in ViewModel or Repository — 破坏可测试性
4. **NEVER** use third-party mocking frameworks — 手写 test doubles only
5. **NEVER** use SwiftUI — 本项目是 UIKit 项目

---

## 关联 Playbooks

| Playbook | 关系 | 何时参考 |
|----------|------|----------|
| [ctx-testing-001](../../testing/tech/ctx-testing-001-unit-test-quick-nimble.md) | **下游 — 测试中的例外** | force-unwrap 在 `it()` 断言块中可接受(HR-4)；手写测试替身规则(HR-1) |
| [ctx-testing-002](../../testing/tech/ctx-testing-002-bdd-best-practices.md) | **下游 — BDD 结构** | 编写测试时的 Given-When-Then 模式和命名规范 |
| [ctx-sources-002](./ctx-sources-002-uikit-best-practices.md) | **互补 — UIKit 规则** | View 层的 Swift 实践（主线程、生命周期） |
| [ctx-sources-003](./ctx-sources-003-mvvm-repo.md) | **互补 — 架构指南** | Swift 类型选择（struct vs class）在 MVVM 各层的应用 |
