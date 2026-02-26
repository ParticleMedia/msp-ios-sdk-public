---
id: ctx-sources-003
title: MVVM-Repository 架构指南 (AI-First)
layer: tech
domain: sources
tags: [mvvm, repository, viewmodel, protocol, dependency-injection, architecture]
triggers: [ViewModel, Repository, DataSource, MVVM, dependency injection, protocol, layer, architecture, binding]
summary: "MVVM-Repository 分层架构硬规则与软规则，覆盖层职责、依赖注入、数据流、测试策略"
version: "2.0"
created: 2026-02-22
updated: 2026-02-22
source: manual
status: active
confidence: high
---

# MVVM-Repository 架构指南 (AI-First)

## 架构总览

```
View (UIKit VC)  -->  ViewModel (Foundation/Combine)  -->  Repository (Protocol)  -->  DataSource/Service
     |                        |                                  |                           |
  UI binding            State + logic                   Data coordination            Concrete I/O
  No logic             No UIKit import                  Protocol-based              Network/Cache/DB
  Owns cancellables    @Published state                 Stateless                   URLSession, etc.
```

**项目约束**: Swift 5.0 | iOS 15.0+ | UIKit | CocoaPods | Combine (iOS 13+) | Quick ~> 7.0, Nimble ~> 13.0

---

## 层职责矩阵

| 层 | 允许 import | 拥有 | 禁止 |
|---|---|---|---|
| **View** (UIViewController) | UIKit, Combine, MSPiOSCore | UI 元素, cancellables, 用户交互 | 业务逻辑, 网络调用, 直接访问 Repository |
| **ViewModel** | Foundation, Combine | @Published 状态, PassthroughSubject 信号, 业务逻辑 | UIKit, 直接网络调用, 导航控制 |
| **Repository** (Protocol) | Foundation | 数据源协调 (网络 + 缓存), 缓存策略 | UIKit, 展示逻辑, 业务决策 |
| **DataSource/Service** | Foundation, URLSession | 具体 I/O 操作 | UIKit, 业务逻辑, 跨层引用 |

---

## 硬规则 (Hard Rules)

### HR-1: NEVER import UIKit in ViewModel or Repository layers

**Citation**: Clean Architecture (Robert C. Martin) — 依赖规则要求内层不得引用外层框架; 可测试性原则 — ViewModel 必须在无 UI 环境下可测试。

```swift
// WRONG — ViewModel 耦合 UIKit, 无法独立测试
import UIKit

class AdBiddingViewModel {
    var statusColor: UIColor { .green }       // 展示细节泄漏到 ViewModel
    func present(on vc: UIViewController) {}  // 导航逻辑不属于 ViewModel
}

// CORRECT — ViewModel 纯 Foundation + Combine
import Foundation
import Combine

final class AdBiddingViewModel {
    @Published private(set) var isSuccess: Bool = false  // View 根据 bool 决定颜色
    @Published private(set) var errorMessage: String?

    private let repository: AdBiddingRepositoryProtocol

    init(repository: AdBiddingRepositoryProtocol) {
        self.repository = repository
    }

    func fetchBid(adUnit: String) {
        repository.fetchBid(for: adUnit) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let bid):
                self.isSuccess = true
            case .failure(let error):
                self.isSuccess = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
```

**验证**: `grep -r "import UIKit" Sources/**/ViewModels/` 应返回零结果 (Repository 同理)。

---

### HR-2: ALWAYS inject dependencies via initializer (constructor injection)

**Citation**: Martin Fowler, "Inversion of Control Containers and the Dependency Injection pattern" — 构造器注入使依赖显式可见, 编译期保证完整性。

```swift
// WRONG — 隐式依赖, 无法在测试中替换
class AdBiddingViewModel {
    func load() {
        AdBiddingRepository.shared.fetchBid(for: "unit") { _ in }
    }
}

// CORRECT — 显式注入, 测试可替换为 Mock
final class AdBiddingViewModel {
    private let repository: AdBiddingRepositoryProtocol

    init(repository: AdBiddingRepositoryProtocol) {
        self.repository = repository
    }

    func load(adUnit: String) {
        repository.fetchBid(for: adUnit) { [weak self] result in
            // handle result
        }
    }
}
```

**默认值模式**: 生产代码可使用默认参数简化调用站 (本项目现有模式):

```swift
init(
    debugSectionsRepository: DebugSectionsRepository = TestDebugSectionsService(),
    placementsRepository: PlacementsRepository = AdConfigPlacementsService()
) { ... }
```

---

### HR-3: ALWAYS define protocol before concrete implementation

**Citation**: Apple WWDC 2015 "Protocol-Oriented Programming in Swift"; constitution.md Article III.2。

协议定义 → 具体实现 → 测试替身, 三件套必须成组出现:

```swift
// 1) Protocol 定义
protocol AdBiddingRepositoryProtocol {
    func fetchBid(for adUnit: String,
                  completion: @escaping (Result<BidResponse, AdBiddingError>) -> Void)
    func cancelPendingRequests()
}

// 2) 具体实现
final class AdBiddingRepository: AdBiddingRepositoryProtocol {
    private let networkService: NetworkServiceProtocol
    private let cacheService: CacheServiceProtocol

    init(networkService: NetworkServiceProtocol, cacheService: CacheServiceProtocol) {
        self.networkService = networkService
        self.cacheService = cacheService
    }

    func fetchBid(for adUnit: String,
                  completion: @escaping (Result<BidResponse, AdBiddingError>) -> Void) {
        if let cached = cacheService.getCachedBid(for: adUnit) {
            completion(.success(cached))
            return
        }
        networkService.requestBid(adUnit: adUnit, completion: completion)
    }

    func cancelPendingRequests() { networkService.cancelAll() }
}

// 3) 测试替身 (Stub — Meszaros taxonomy)
final class StubAdBiddingRepository: AdBiddingRepositoryProtocol {
    var stubbedResult: Result<BidResponse, AdBiddingError> = .failure(.unknown)

    func fetchBid(for adUnit: String,
                  completion: @escaping (Result<BidResponse, AdBiddingError>) -> Void) {
        completion(stubbedResult)
    }

    func cancelPendingRequests() {}
}
```

---

### HR-4: NEVER let View layer access Repository or DataSource directly

**Citation**: MVVM-Repository 分层约束 — View 只与 ViewModel 对话, 保持单向依赖链。

```
CORRECT:  View --> ViewModel --> Repository --> DataSource
WRONG:    View --> Repository  (跳过 ViewModel)
WRONG:    View --> DataSource  (跳过两层)
```

```swift
// WRONG — ViewController 直接调用 Repository
class AdListViewController: UIViewController {
    private let repository = AdBiddingRepository(...)  // 违规: View 持有 Repository

    override func viewDidLoad() {
        super.viewDidLoad()
        repository.fetchBid(for: "unit") { result in ... }
    }
}

// CORRECT — ViewController 只与 ViewModel 交互
class AdListViewController: UIViewController {
    private let viewModel: AdBiddingViewModel  // 只持有 ViewModel

    init(viewModel: AdBiddingViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.load(adUnit: "unit")
    }
}
```

---

### HR-5: NEVER put business logic in View layer

**Citation**: Single Responsibility Principle (Robert C. Martin, SOLID) — ViewController 只负责 UI 绑定和用户交互转发。

```swift
// WRONG — 过滤逻辑在 ViewController
class BidListVC: UIViewController {
    func filterBids() {
        let filtered = bids.filter { $0.price > 1.0 && $0.isActive }
        tableView.reloadData()
    }
}

// CORRECT — ViewModel 拥有过滤逻辑
final class BidListViewModel {
    @Published private(set) var filteredBids: [BidResponse] = []

    func applyFilter(minPrice: Double) {
        filteredBids = allBids.filter { $0.price > minPrice && $0.isActive }
    }
}
```

---

### HR-6: ALWAYS use Result<T, Error> for Repository callback return types

**Citation**: SE-0235 Result Type — 统一成功/失败语义, 消除可选值歧义。

```swift
// WRONG — 散装回调, 调用方必须同时处理两个可选值
protocol BidRepository {
    func fetchBid(for adUnit: String,
                  completion: @escaping (BidResponse?, Error?) -> Void)
}

// CORRECT — Result 类型强制二选一
protocol BidRepositoryProtocol {
    func fetchBid(for adUnit: String,
                  completion: @escaping (Result<BidResponse, BidError>) -> Void)
}
```

**例外**: 返回同步数据的方法 (如 `getAd(placementId:) -> MSPAd?`) 可直接返回可选值。

---

### HR-7: NEVER use singletons for ViewModel or Repository instances

**Citation**: Fowler on DI — 单例隐藏依赖, 阻碍测试替换, 引入全局可变状态。

```swift
// WRONG — 全局共享实例, 测试无法隔离
class AdBiddingRepository {
    static let shared = AdBiddingRepository()
    private init() {}
}

class AdBiddingViewModel {
    func load() {
        AdBiddingRepository.shared.fetchBid(for: "unit") { _ in }
    }
}

// CORRECT — 通过 init 注入, 测试可替换
final class AdBiddingViewModel {
    private let repository: AdBiddingRepositoryProtocol

    init(repository: AdBiddingRepositoryProtocol) {
        self.repository = repository
    }
}
```

**注意**: SDK 级管理器 (如 `MSP.shared`) 是允许的 — 此规则仅约束 ViewModel 和 Repository。

---

### HR-8: ALWAYS keep ViewModel stateful, Repository stateless

**Citation**: MVVM 模式定义 — ViewModel 是 View 的状态持有者; Repository 是无状态的数据网关。

```swift
// ViewModel: 有状态 — 持有 UI 需要的所有状态
final class AdBiddingViewModel {
    @Published private(set) var state: BidState = .idle     // 可观察状态
    @Published private(set) var errorMessage: String?       // 错误状态
    private(set) var lastBid: BidResponse?                  // 缓存最后结果
}

// Repository: 无状态 — 每次调用独立, 不持有请求间状态
final class AdBiddingRepository: AdBiddingRepositoryProtocol {
    private let networkService: NetworkServiceProtocol      // 注入的服务, 非自身状态

    func fetchBid(for adUnit: String,
                  completion: @escaping (Result<BidResponse, BidError>) -> Void) {
        networkService.requestBid(adUnit: adUnit, completion: completion)
    }
}
```

---

### HR-9: ALWAYS use Combine Publisher or callback for ViewModel-to-View binding

**Citation**: Apple Combine 框架; 本项目标准绑定模式 (参见 `DebugAdLoadViewModel`)。

禁止 KVO, 禁止 delegation 用于数据绑定 (delegate 仅用于 UITableView 等系统协议)。

```swift
// ViewModel — 两种发射模式
final class AdLoadViewModel {
    // 1) @Published: 持续状态 (View 总能读取最新值)
    @Published private(set) var sections: [SectionViewModel] = []

    // 2) PassthroughSubject: 一次性事件 (toast, 导航信号)
    private let toastSubject = PassthroughSubject<ToastSignal, Never>()
    var toastPublisher: AnyPublisher<ToastSignal, Never> {
        toastSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
}

// View — 绑定模式
class AdLoadViewController: UIViewController {
    private var cancellables = Set<AnyCancellable>()

    private func bindViewModel() {
        viewModel.$sections
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sections in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        viewModel.toastPublisher
            .sink { [weak self] signal in
                self?.showToast(signal)
            }
            .store(in: &cancellables)
    }
}
```

---

### HR-10: NEVER mix DataSource concerns into Repository

**Citation**: Fowler, "Patterns of Enterprise Application Architecture" — Repository 是数据源的协调者, 不是数据源本身。

```swift
// WRONG — Repository 直接构造 URLRequest, 混合了 DataSource 职责
final class BidRepository: BidRepositoryProtocol {
    func fetchBid(for adUnit: String, completion: @escaping (Result<BidResponse, BidError>) -> Void) {
        var request = URLRequest(url: URL(string: "https://api.example.com/bid")!)
        request.httpMethod = "POST"
        request.httpBody = try? JSONEncoder().encode(["ad_unit": adUnit])
        URLSession.shared.dataTask(with: request) { data, _, error in
            // JSON 解析也混在里面...
        }.resume()
    }
}

// CORRECT — Repository 委托给 NetworkService
final class BidRepository: BidRepositoryProtocol {
    private let networkService: NetworkServiceProtocol
    private let cacheService: CacheServiceProtocol

    init(networkService: NetworkServiceProtocol, cacheService: CacheServiceProtocol) {
        self.networkService = networkService
        self.cacheService = cacheService
    }

    func fetchBid(for adUnit: String, completion: @escaping (Result<BidResponse, BidError>) -> Void) {
        if let cached = cacheService.getCachedBid(for: adUnit) {
            completion(.success(cached))
            return
        }
        networkService.requestBid(adUnit: adUnit) { [weak self] result in
            if case .success(let bid) = result {
                self?.cacheService.cache(bid, for: adUnit)
            }
            completion(result)
        }
    }
}
```

---

### HR-11: ALWAYS make ViewModel testable without any UI framework

**Citation**: XCTest 独立性; Quick/Nimble 测试哲学 — 单元测试应在毫秒级完成, 无需启动 UI。

```swift
import Quick
import Nimble
@testable import MSPCore

final class AdBiddingViewModelSpec: QuickSpec {
    override class func spec() {
        var sut: AdBiddingViewModel!
        var stubRepo: StubAdBiddingRepository!

        beforeEach {
            stubRepo = StubAdBiddingRepository()
            sut = AdBiddingViewModel(repository: stubRepo)
        }

        describe("fetchBid") {
            context("when repository returns success") {
                it("sets state to loaded") {
                    stubRepo.stubbedResult = .success(BidResponse.fixture())
                    sut.fetchBid(adUnit: "test-unit")
                    expect(sut.isSuccess).toEventually(beTrue())
                }
            }

            context("when repository returns failure") {
                it("sets errorMessage") {
                    stubRepo.stubbedResult = .failure(.networkError)
                    sut.fetchBid(adUnit: "test-unit")
                    expect(sut.errorMessage).toEventuallyNot(beNil())
                }
            }
        }
    }
}
```

---

## 建议规则 (Advisory Rules)

### AR-1: SHOULD use factory methods for complex ViewModel creation

当 ViewModel 依赖 3 个以上 Repository 时, 使用工厂方法或 Builder 封装组装逻辑:

```swift
enum ViewModelFactory {
    static func makeAdLoadViewModel() -> DebugAdLoadViewModel {
        DebugAdLoadViewModel(
            debugSectionsRepository: TestDebugSectionsService(),
            placementsRepository: AdConfigPlacementsService(),
            loadAdRepository: TestLoadAdService()
        )
    }
}
```

### AR-2: SHOULD keep Repository methods focused on single data operations

一个方法做一件事 — `fetchBid`, `cancelRequest`, `cacheBid` 而非 `fetchAndCacheAndTransformBid`。

### AR-3: SHOULD use domain-specific error types (not raw Error)

```swift
enum AdBiddingError: Error, Equatable {
    case networkError
    case decodingFailed
    case noFill
    case timeout
    case unknown
}
```

使错误可穷举, 可 `switch`, 可测试 (Equatable)。

### AR-4: SHOULD use typealias for complex completion handler types

```swift
typealias BidCompletion = (Result<BidResponse, AdBiddingError>) -> Void
typealias SectionsCompletion = (Result<[DebugSection], Error>) -> Void
```

### AR-5: SHOULD separate read and write repository protocols (CQRS-lite)

```swift
protocol BidReadRepository {
    func fetchBid(for adUnit: String, completion: @escaping BidCompletion)
    func getCachedBid(for adUnit: String) -> BidResponse?
}

protocol BidWriteRepository {
    func saveBid(_ bid: BidResponse, for adUnit: String)
    func clearCache()
}
```

### AR-6: SHOULD use ViewModel for input validation before passing to Repository

ViewModel 验证 → Repository 只接收合法输入。不要让 Repository 做入参校验。

### AR-7: SHOULD cache in Repository layer, not in ViewModel

缓存是数据策略, 属于 Repository 职责。ViewModel 只持有当前展示所需的状态。

### AR-8: SHOULD use Coordinator pattern for navigation (not ViewModel)

ViewModel 发出导航信号 (PassthroughSubject), View/Coordinator 订阅后执行导航:

```swift
// ViewModel 只发信号
private let navigationSubject = PassthroughSubject<NavigationDestination, Never>()

// View/Coordinator 订阅并执行
viewModel.navigationPublisher
    .sink { [weak self] destination in
        switch destination {
        case .adDetail(let ad):
            let detailVC = AdDetailViewController(ad: ad)
            self?.navigationController?.pushViewController(detailVC, animated: true)
        }
    }
    .store(in: &cancellables)
```

---

## AI 常犯错误 (本项目特有)

### 1. AI 把导航逻辑放在 ViewModel

**错误**: `viewModel.navigationController?.pushViewController(...)`
**正确**: ViewModel 通过 `PassthroughSubject` 发出信号, View/Coordinator 订阅执行导航。ViewModel 不得持有 UIViewController 强引用。

### 2. AI 创建 "God ViewModel" (500+ 行)

**错误**: 一个 ViewModel 处理列表加载 + 筛选 + 详情 + 编辑 + 删除。
**正确**: 按功能拆分 — `AdListViewModel`, `AdFilterViewModel`, `AdDetailViewModel`。每个 ViewModel 职责单一。

### 3. AI 在 ViewModel 中直接访问 UserDefaults/Network

**错误**: `UserDefaults.standard.string(forKey:)` 出现在 ViewModel 中。
**正确**: 通过 Repository/Service 协议抽象, ViewModel 只调用 `repository.getUserPreference()`。

### 4. AI 使用 @MainActor 代替 DispatchQueue.main

**错误**: `@MainActor class AdViewModel { ... }` — 这是 Swift 5.5+ 特性。
**正确**: 本项目 Swift 5.0, 使用 `DispatchQueue.main.async` 或 Combine 的 `.receive(on: DispatchQueue.main)`。

### 5. AI 创建双向绑定 (View ↔ ViewModel)

**错误**: View 修改 ViewModel 属性, ViewModel 也修改 View 属性, 形成循环。
**正确**: 单向数据流 — View 调用 ViewModel 方法 (输入), View 订阅 ViewModel 的 Publisher (输出)。

### 6. AI 引入 RxSwift 代替 Combine

**错误**: `import RxSwift` / `Observable<T>` / `BehaviorRelay`。
**正确**: 本项目统一使用 Combine — `@Published`, `PassthroughSubject`, `AnyPublisher`。

### 7. AI 生成 SwiftUI ObservableObject 代替 UIKit 兼容 ViewModel

**错误**: `class AdViewModel: ObservableObject { @Published var ... }` + `@StateObject`。
**正确**: 本项目纯 UIKit, ViewModel 是普通 class + `@Published` (Combine 属性包装器), View 通过 `sink` 绑定。

---

## 完整架构示例

端到端示例: 加载广告竞价数据, 覆盖全部四层。

```swift
// ═══════════════════════════════════════════════════
// LAYER 1: Protocol 定义
// ═══════════════════════════════════════════════════
import Foundation

enum BidError: Error, Equatable {
    case noFill
    case networkError
}

struct BidResponse: Equatable {
    let adUnit: String
    let price: Double
}

protocol BidRepositoryProtocol {
    func fetchBid(for adUnit: String,
                  completion: @escaping (Result<BidResponse, BidError>) -> Void)
}

// ═══════════════════════════════════════════════════
// LAYER 2: Repository 实现
// ═══════════════════════════════════════════════════
final class BidRepository: BidRepositoryProtocol {
    private let networkService: NetworkServiceProtocol

    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
    }

    func fetchBid(for adUnit: String,
                  completion: @escaping (Result<BidResponse, BidError>) -> Void) {
        networkService.requestBid(adUnit: adUnit, completion: completion)
    }
}

// ═══════════════════════════════════════════════════
// LAYER 3: ViewModel 实现
// ═══════════════════════════════════════════════════
import Combine

final class BidViewModel {
    enum State: Equatable {
        case idle, loading, loaded(BidResponse), error(String)
    }

    @Published private(set) var state: State = .idle
    private let repository: BidRepositoryProtocol

    init(repository: BidRepositoryProtocol) {
        self.repository = repository
    }

    func loadBid(adUnit: String) {
        state = .loading
        repository.fetchBid(for: adUnit) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let bid):
                self.state = .loaded(bid)
            case .failure(let error):
                self.state = .error(error.localizedDescription)
            }
        }
    }
}

// ═══════════════════════════════════════════════════
// LAYER 4: View (UIViewController) 绑定
// ═══════════════════════════════════════════════════
import UIKit
import Combine

final class BidViewController: UIViewController {
    private let viewModel: BidViewModel
    private let statusLabel = UILabel()
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: BidViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(statusLabel)
        bindViewModel()
        viewModel.loadBid(adUnit: "banner-001")
    }

    private func bindViewModel() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .idle:       self?.statusLabel.text = "Ready"
                case .loading:    self?.statusLabel.text = "Loading..."
                case .loaded(let bid):
                    self?.statusLabel.text = "Bid: $\(bid.price)"
                case .error(let msg):
                    self?.statusLabel.text = "Error: \(msg)"
                }
            }
            .store(in: &cancellables)
    }
}

// ═══════════════════════════════════════════════════
// 单元测试 (Quick + Nimble)
// ═══════════════════════════════════════════════════
import Quick
import Nimble
@testable import MSPCore

// Stub (Meszaros taxonomy): 返回预设结果, 不验证交互
final class StubBidRepository: BidRepositoryProtocol {
    var stubbedResult: Result<BidResponse, BidError> = .failure(.noFill)

    func fetchBid(for adUnit: String,
                  completion: @escaping (Result<BidResponse, BidError>) -> Void) {
        completion(stubbedResult)
    }
}

final class BidViewModelSpec: QuickSpec {
    override class func spec() {
        var sut: BidViewModel!
        var stubRepo: StubBidRepository!

        beforeEach {
            stubRepo = StubBidRepository()
            sut = BidViewModel(repository: stubRepo)
        }

        describe("loadBid") {
            it("transitions to loaded on success") {
                let bid = BidResponse(adUnit: "test", price: 2.5)
                stubRepo.stubbedResult = .success(bid)
                sut.loadBid(adUnit: "test")
                expect(sut.state).toEventually(equal(.loaded(bid)))
            }

            it("transitions to error on failure") {
                stubRepo.stubbedResult = .failure(.networkError)
                sut.loadBid(adUnit: "test")
                expect(sut.state).toEventually(equal(.error(BidError.networkError.localizedDescription)))
            }
        }
    }
}
```

---

## 决策树

### "这个逻辑放在哪一层?"

```
                    这段代码做什么?
                         |
          ┌──────────────┼──────────────┐──────────────┐
          v              v              v              v
     触摸 UIView?    转换/格式化数据?  选择数据源?      发 HTTP 请求?
     显示 UI?        过滤/排序?       缓存策略?       读写数据库?
          |              |              |              |
          v              v              v              v
       View层        ViewModel层     Repository层   DataSource层
   (UIViewController) (Foundation)    (Protocol)    (URLSession)
```

### "需要新建 Repository 吗?"

```
    新功能需要什么数据?
           |
     ┌─────┴─────┐
     v            v
  现有 Repository   无合适 Repository
  已有此方法?          |
     |            创建新 Protocol
   YES → 复用     + 实现 + Stub
   NO → 给现有    (三件套: HR-3)
   Protocol 加方法
```

---

## 数据流图

```
User Tap
  |
  v
View.buttonTapped()          <-- View 只转发用户意图
  |
  v
ViewModel.loadBid(adUnit:)   <-- state = .loading (@Published)
  |
  v
Repository.fetchBid(for:)    <-- 无状态, 协调数据源
  |
  ├──> CacheService.get()
  |       |
  |   (cache hit?) ──yes──> completion(.success(cached))
  |       |
  |      no
  |       v
  └──> NetworkService.request()
            |
            v
       completion(.success(bid)) / completion(.failure(error))
            |
            v
ViewModel receives Result     <-- state = .loaded / .error (@Published)
  |
  v
View.$state.sink { ... }     <-- UI 自动更新 (Combine)
```

---

## 测试替身分类 (Meszaros Taxonomy)

本项目手工编写测试替身, 不使用 mock 框架:

| 类型 | 用途 | 示例 |
|---|---|---|
| **Dummy** | 填充参数, 不被调用 | `DummyLogger()` — 满足 init 签名 |
| **Stub** | 返回预设值, 不验证交互 | `StubBidRepository` — `stubbedResult` |
| **Spy** | 记录调用, 用于验证交互 | `SpyAnalytics` — `capturedEvents: [Event]` |
| **Mock** | 预设期望 + 验证 | `MockAdListener` — `expect(onAdLoaded).toBeCalled()` |
| **Fake** | 简化但可工作的实现 | `FakeCacheService` — 内存字典代替磁盘 |

---

## Never Do (速查)

- **NEVER** import UIKit in ViewModel/Repository (HR-1)
- **NEVER** use singletons for ViewModel/Repository DI (HR-7)
- **NEVER** access Repository from View (HR-4)
- **NEVER** use RxSwift — use Combine (AR, 项目标准)
- **NEVER** use SwiftUI ObservableObject — use plain class + @Published (项目标准)
- **NEVER** use @MainActor — use DispatchQueue.main (Swift 5.0 约束)
- **NEVER** use async/await — use completion handler + Combine (Swift 5.0 约束)
- **NEVER** put navigation logic in ViewModel (AR-8)
- **NEVER** put business logic in View (HR-5)
- **NEVER** make Repository stateful (HR-8)

---

## 关联 Playbooks

| Playbook | 关系 | 何时参考 |
|----------|------|----------|
| [ctx-testing-001](../../testing/tech/ctx-testing-001-unit-test-quick-nimble.md) | **下游 — 测试替身设计** | Repository 的 Mock/Stub 设计遵循 Meszaros 分类(HR-2)；@TestState 管理(HR-7) |
| [ctx-testing-002](../../testing/tech/ctx-testing-002-bdd-best-practices.md) | **下游 — BDD 结构** | ViewModel 测试的 describe/context/it 结构和 Given-When-Then |
| [ctx-testing-003](../../testing/tech/ctx-testing-003-bugfix-regression.md) | **下游 — 回归测试** | ViewModel/Repository bug 修复时的 Red→Green→Refactor 工作流 |
| [ctx-sources-001](./ctx-sources-001-swift-best-practices.md) | **上游 — Swift 语言规则** | 值类型/引用类型选择、Optional 处理、闭包捕获 |
| [ctx-sources-002](./ctx-sources-002-uikit-best-practices.md) | **互补 — View 层规则** | View 层如何绑定 ViewModel（UIKit delegate/Combine） |
