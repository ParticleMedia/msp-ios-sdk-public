---
id: ctx-sources-002
title: UIKit 最佳实践 (AI-First)
layer: tech
domain: sources
tags: [uikit, viewcontroller, autolayout, tableview, collectionview, delegate, memory]
triggers: [UIKit, UIViewController, UITableView, UICollectionView, AutoLayout, constraint, delegate, viewDidLoad, main thread, DispatchQueue]
summary: "UIKit 开发硬规则与软规则，覆盖生命周期、AutoLayout、TableView/CollectionView、delegate 模式、主线程安全"
version: "2.0"
created: 2026-02-22
updated: 2026-02-22
source: manual
status: active
confidence: high
---

# UIKit 最佳实践 (AI-First)

> **Stack**: Swift 5.0, iOS 15.0+, UIKit (programmatic), MVVM-Repository
> **Testing**: Quick ~> 7.0, Nimble ~> 13.0

---

## Hard Rules (HR) — 违反即 Bug

### HR-1: ALWAYS update UI on the main thread

**Citation**: [Apple — DispatchQueue.main](https://developer.apple.com/documentation/dispatch/dispatchqueue/1781006-main)

UIKit is NOT thread-safe. Background-thread UI updates cause glitches, crashes, or undefined behavior.

```swift
// WRONG
repository.fetchBids { [weak self] result in
    self?.tableView.reloadData()       // may execute on background queue
}
// CORRECT
repository.fetchBids { [weak self] result in
    DispatchQueue.main.async { self?.tableView.reloadData() }
}
```

Enable Thread Sanitizer for detection (Edit Scheme > Diagnostics).

### HR-2: ALWAYS set translatesAutoresizingMaskIntoConstraints = false

**Citation**: [Apple — Auto Layout Guide](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/AutolayoutPG/)

Without this, system autoresizing constraints conflict with your manual constraints.

```swift
// WRONG — "Unable to simultaneously satisfy constraints"
let label = UILabel()
view.addSubview(label)
NSLayoutConstraint.activate([
    label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
])
// CORRECT
let label = UILabel()
label.translatesAutoresizingMaskIntoConstraints = false
view.addSubview(label)
NSLayoutConstraint.activate([
    label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
])
```

### HR-3: ALWAYS use weak for delegate properties

**Citation**: [Apple — ARC](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/)

Strong delegate = retain cycle: Parent -> Child -> Parent. Neither deallocates.

```swift
// WRONG — retain cycle
class ChildVC: UIViewController {
    var delegate: SelectionDelegate?       // strong — LEAK
}
// CORRECT
class ChildVC: UIViewController {
    weak var delegate: SelectionDelegate?  // weak — safe
}
```

### HR-4: NEVER put business logic in UIViewController

**Citation**: MVVM-Repository pattern (see ctx-sources-003)

VCs handle UI only. Logic belongs in ViewModel.

```swift
// WRONG
class BidListVC: UIViewController {
    func filterBids() {
        let filtered = bids.filter { $0.price > 1.0 && $0.isActive }
        tableView.reloadData()
    }
}
// CORRECT
class BidListViewModel {
    @Published private(set) var filteredBids: [BidResponse] = []
    func applyFilter() {
        filteredBids = allBids.filter { $0.price > 1.0 && $0.isActive }
    }
}
```

### HR-5: ALWAYS dequeue reusable cells with registered identifiers

**Citation**: [Apple — UITableView.register](https://developer.apple.com/documentation/uikit/uitableview/1614888-register)

Unregistered identifier = `NSInternalInconsistencyException` crash. Always pair `register` + `dequeue`.

```swift
// viewDidLoad
tableView.register(BidCell.self, forCellReuseIdentifier: BidCell.reuseIdentifier)

// cellForRowAt
guard let cell = tableView.dequeueReusableCell(
    withIdentifier: BidCell.reuseIdentifier, for: indexPath
) as? BidCell else { return UITableViewCell() }
cell.configure(with: viewModel.items[indexPath.row])
return cell

// Reuse identifier convention
final class BidCell: UITableViewCell {
    static let reuseIdentifier = String(describing: BidCell.self)
}
```

### HR-6: NEVER force-cast cells in cellForRowAt

**Citation**: [Apple — UITableViewCell](https://developer.apple.com/documentation/uikit/uitableviewcell)

`as!` crashes when registration is missing or identifier is wrong. Always `guard let` + `as?`.

```swift
// WRONG — runtime crash
let cell = tableView.dequeueReusableCell(withIdentifier: "BidCell", for: indexPath) as! BidCell
// CORRECT — safe downcast
guard let cell = tableView.dequeueReusableCell(
    withIdentifier: BidCell.reuseIdentifier, for: indexPath
) as? BidCell else { return UITableViewCell() }
```

### HR-7: ALWAYS remove observers/notifications in deinit

**Citation**: [Apple — NotificationCenter](https://developer.apple.com/documentation/foundation/notificationcenter)

Observers outliving their owner = dangling pointer crash or memory leak.

```swift
final class BidStatusVC: UIViewController {
    private var token: NSObjectProtocol?
    override func viewDidLoad() {
        super.viewDidLoad()
        token = NotificationCenter.default.addObserver(
            forName: .bidStatusChanged, object: nil, queue: .main
        ) { [weak self] note in self?.handleStatusChange(note) }
    }

    deinit {
        if let token = token { NotificationCenter.default.removeObserver(token) }
    }
}
```

### HR-8: ALWAYS configure views in viewDidLoad, NOT in init

**Citation**: [Apple — UIViewController](https://developer.apple.com/documentation/uikit/uiviewcontroller)

`init` runs before the view hierarchy exists. Setup goes in `viewDidLoad`.

```
init → loadView → viewDidLoad → viewWillAppear → viewDidAppear
                   ^^^ setup here
```

```swift
// WRONG — view hierarchy not ready
init(viewModel: BidViewModel) {
    super.init(nibName: nil, bundle: nil)
    view.addSubview(statusLabel)        // too early
}
// CORRECT
override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(statusLabel)
    NSLayoutConstraint.activate([...])
}
```

### HR-9: NEVER access view property from init

**Citation**: [Apple — UIViewController.view](https://developer.apple.com/documentation/uikit/uiviewcontroller/1621460-view)

`self.view` in `init` triggers premature `loadView()` -- wrong trait collection, missing nav controller.

```swift
// WRONG
init(viewModel: BidViewModel) {
    super.init(nibName: nil, bundle: nil)
    self.view.backgroundColor = .white  // loadView() fires here!
    self.title = viewModel.title        // fine — title is on VC, not view
}
```

### HR-10: ALWAYS use NSLayoutAnchor API for programmatic constraints

**Citation**: [Apple — NSLayoutAnchor](https://developer.apple.com/documentation/uikit/nslayoutanchor)

Anchor API is type-safe and readable. `NSLayoutConstraint(item:attribute:...)` is error-prone.

```swift
// WRONG
NSLayoutConstraint(item: label, attribute: .leading, relatedBy: .equal,
    toItem: view, attribute: .leading, multiplier: 1.0, constant: 16).isActive = true
// CORRECT
NSLayoutConstraint.activate([
    label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
    label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
    label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
])
```

### HR-11: NEVER block the main thread with synchronous network calls

**Citation**: [Apple — URLSession](https://developer.apple.com/documentation/foundation/urlsession)

Synchronous main-thread I/O freezes UI. Watchdog kills app after ~10s (`0x8badf00d`).

```swift
// WRONG
let data = try! Data(contentsOf: apiURL)  // blocks main thread
// CORRECT
URLSession.shared.dataTask(with: apiURL) { [weak self] data, _, error in
    DispatchQueue.main.async { self?.handleResponse(data, error) }
}.resume()
```

### HR-12: ALWAYS use prepareForReuse() to reset cell state

**Citation**: [Apple — prepareForReuse()](https://developer.apple.com/documentation/uikit/uitableviewcell/1623223-prepareforreuse)

Cells are recycled. Without reset, scrolled-in cells show stale data from previous rows.

```swift
final class BidCell: UITableViewCell {
    static let reuseIdentifier = String(describing: BidCell.self)
    private let priceLabel = UILabel()
    private let statusIcon = UIImageView()
    override func prepareForReuse() {
        super.prepareForReuse()
        priceLabel.text = nil
        statusIcon.image = nil
        contentView.backgroundColor = nil
    }

    func configure(with bid: BidResponse) {
        priceLabel.text = String(format: "$%.2f", bid.price)
        statusIcon.image = bid.isActive ? UIImage(systemName: "checkmark.circle") : nil
    }
}
```

---

## Advisory Rules (AR) — 推荐遵循

### AR-1: SHOULD use UICollectionViewCompositionalLayout for complex layouts

`UICollectionViewCompositionalLayout` (iOS 13+) replaces custom FlowLayout subclasses for multi-section, multi-size layouts.

### AR-2: SHOULD use programmatic UI consistently (not mixed with XIB)

This project uses programmatic UI exclusively. Do not introduce XIB or storyboard files.

### AR-3: SHOULD use UIStackView for linear arrangements

Stack views reduce constraint boilerplate for vertical/horizontal lists with uniform spacing.

### AR-4: SHOULD handle traitCollectionDidChange for adaptive layout

Update constraints in `traitCollectionDidChange(_:)` for different size classes (iPad, split view).

### AR-5: SHOULD use UITableViewDiffableDataSource for dynamic data

`UITableViewDiffableDataSource` (iOS 13+) eliminates manual `beginUpdates`/`endUpdates` and index path math.

### AR-6: SHOULD extract reusable UI into custom UIView subclasses

When the same layout appears in multiple screens, extract into a `UIView` subclass.

### AR-7: SHOULD set content hugging and compression resistance priorities

When Auto Layout has ambiguity, set `contentHuggingPriority` and `contentCompressionResistancePriority` explicitly.

### AR-8: SHOULD use layoutMargins for consistent spacing

Constrain subviews to `layoutMarginsGuide` instead of manual constants on leading/trailing anchors.

---

## AI 常犯错误（本项目特有）

### 1. AI 生成 SwiftUI 代码而非 UIKit

This project uses **UIKit only**. Reject `struct ContentView: View`, `@State`, `@StateObject` entirely.

```swift
// WRONG — SwiftUI
struct BidListView: View {
    @StateObject var viewModel = BidListViewModel()
    var body: some View { List { ... } }
}
// CORRECT — UIKit
class BidListVC: UIViewController, UITableViewDataSource { ... }
```

### 2. AI 引用 Storyboard/Interface Builder

No `.storyboard`/`.xib` for VCs. Reject `@IBOutlet`, `@IBAction`, `instantiateViewController(withIdentifier:)` references.

### 3. AI 遗漏 translatesAutoresizingMaskIntoConstraints = false

Most common AI layout bug. Every programmatic view needs this set to `false`. See HR-2.

### 4. AI 在 ViewController 中直接发起网络请求

Network calls belong in Repository layer. Reject `URLSession.shared.dataTask` inside VC. See HR-4.

### 5. AI 使用 async/await + @MainActor 而非 DispatchQueue.main

This project uses **completion handlers**, not `async/await`. Reject `@MainActor`, `Task { }`, `await`.

```swift
// WRONG
@MainActor class BidViewModel {
    func load() async throws { ... }
}
// CORRECT
class BidViewModel {
    func load() {
        repository.fetchBid(for: adUnit) { [weak self] result in
            DispatchQueue.main.async { self?.handleResult(result) }
        }
    }
}
```

### 6. AI 创建 strong delegate 引用

AI frequently omits `weak` on delegate properties, causing retain cycles. See HR-3.

---

## 决策树

### Programmatic Layout 选择

1. Single-axis uniform spacing? --> `UIStackView` (AR-3)
2. Simple parent-child constraints? --> `NSLayoutAnchor` API (HR-10)
3. Multi-section varying sizes? --> `UICollectionViewCompositionalLayout` (AR-1)
4. Scrollable dynamic content? --> `UIScrollView` + `contentLayoutGuide`

### Cell 注册方式

1. Fully programmatic cell? --> `register(CellClass.self, forCellReuseIdentifier:)`
2. XIB-based cell (legacy)? --> `register(UINib(nibName:bundle:), forCellReuseIdentifier:)`
3. New code in this project? --> Always option 1 (programmatic)

---

## Never Do（硬性禁止）

- **NEVER** use SwiftUI in this project
- **NEVER** use storyboards or xibs for ViewControllers
- **NEVER** force-cast cells (`as!` in `cellForRowAt`)
- **NEVER** block the main thread with synchronous I/O
- **NEVER** put business logic in ViewControllers
- **NEVER** use `async/await` as primary async pattern

---

## 关联 Playbooks

| Playbook | 关系 | 何时参考 |
|----------|------|----------|
| [ctx-sources-001](./ctx-sources-001-swift-best-practices.md) | **上游 — Swift 语言规则** | Optional 安全、闭包 [weak self]、访问控制等基础规则适用于 UIKit 代码 |
| [ctx-sources-003](./ctx-sources-003-mvvm-repo.md) | **互补 — 架构指南** | HR-4 禁止 VC 中放业务逻辑，具体的 MVVM-Repository 分层规则在此 |
| [ctx-sources-005](./ctx-sources-005-code-comment-best-practices.md) | **互补 — 注释规范** | UIKit 文件的 `// MARK: -` 组织、文档注释规范 |
| [ctx-testing-001](../../testing/tech/ctx-testing-001-unit-test-quick-nimble.md) | **下游 — 测试实践** | UIKit 组件（ViewModel、Repository）的单元测试方法 |
