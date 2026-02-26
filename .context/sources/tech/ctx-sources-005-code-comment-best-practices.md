---
id: ctx-sources-005
title: Code Comment 最佳实践 (AI-First)
layer: tech
domain: sources
tags: [comment, documentation, docc, mark, todo, fixme, inline-comment]
triggers: [comment, 注释, documentation, DocC, "///", MARK, TODO, FIXME, doc comment, 文档注释]
summary: "Swift 代码注释硬规则与软规则，覆盖 DocC 文档注释、内联注释、MARK 组织、TODO/FIXME 规范、AI 过度注释防治"
version: "1.0"
created: 2026-02-23
updated: 2026-02-23
source: manual
status: active
confidence: high
---

# Code Comment 最佳实践 (AI-First)

## 适用场景

本 playbook 在 AI agent 编写或修改 `Sources/` 下 Swift 代码时自动加载。适用于所有 Swift 文件中的注释编写。约束：Swift 5.0 / iOS 15+ / UIKit / CocoaPods。

**核心原则**: 注释的存在是为了解释 **"为什么"**，而不是 **"做了什么"**。代码本身应当自解释 "做了什么"。AI agent 最常犯的错误是过度注释——给每行代码都加注释。

## Hard Rules (HR) — 不可违反

### HR-1: ALWAYS use `///` for documentation comments — 禁止 `/** */`

**Citation**: [Google Swift Style Guide](https://google.github.io/swift/) — "Documentation comments are always written with `///`"

```swift
// ✅ CORRECT
/// Returns the bid price formatted as a currency string.
///
/// - Parameter locale: The locale for currency formatting. Defaults to `.current`.
/// - Returns: Formatted price string, or `"N/A"` if price is nil.
func formattedPrice(locale: Locale = .current) -> String
```
```swift
// ❌ WRONG — 禁止使用 block comment 风格
/**
 Returns the bid price formatted as a currency string.
 - Parameter locale: The locale for currency formatting.
 - Returns: Formatted price string.
 */
func formattedPrice(locale: Locale = .current) -> String
```
**Why**: `///` 是 Swift 社区标准，与 DocC 工具链最佳兼容，三大风格指南（Apple、Google、Kodeco）均推荐。`/** */` 是 Objective-C/Java 遗留风格。

### HR-2: ALWAYS document all `public` and `open` declarations

**Citation**: [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) — "Write a documentation comment for every declaration"

```swift
// ✅ CORRECT — public API 必须有文档注释
/// Adapter protocol for third-party ad networks.
///
/// Implementations wrap vendor-specific SDK calls behind a
/// unified interface used by the mediation layer.
public protocol AdNetworkAdapter: AnyObject {
    /// Loads an ad for the given placement.
    ///
    /// - Parameter placement: The placement configuration.
    /// - Throws: `AdError.networkUnavailable` if the network is unreachable.
    func loadAd(for placement: Placement) throws
}
```
```swift
// ❌ WRONG — public API 缺少文档
public protocol AdNetworkAdapter: AnyObject {
    func loadAd(for placement: Placement) throws
}
```
**Why**: Public API 是与外部调用者的契约。缺少文档的 public API 迫使调用者阅读实现来理解用法，违反封装原则。

### HR-3: NEVER add comments that restate what the code does

**Citation**: [Kodeco Style Guide](https://github.com/kodecocodes/swift-style-guide) — "Only comment when explaining **why**" | [Google Swift Style Guide](https://google.github.io/swift/) — "Avoid documentation that merely repeats obvious information"

```swift
// ✅ CORRECT — 只在需要解释 "为什么" 时注释
// Server returns 504 if request exceeds 25s; 30s gives margin for slow networks
request.timeout = 30.0
```
```swift
// ❌ WRONG — 复述代码语义（parroting）
// Set the timeout to 30 seconds
request.timeout = 30.0

// Check if the array is empty
if items.isEmpty { ... }

// Increment counter by one
counter += 1

// Return the result
return result
```
**Why**: 复述型注释是噪音，增加阅读负担，且在代码变更时容易过期变成误导。

### HR-4: NEVER leave commented-out code

**Citation**: [Kodeco Style Guide](https://github.com/kodecocodes/swift-style-guide) — "Dead code should be removed, not commented out"

```swift
// ✅ CORRECT — 删除不用的代码，git 有历史记录
func configure() {
    newConfiguration()
}
```
```swift
// ❌ WRONG — 注释掉的代码
func configure() {
    // self.oldConfiguration()
    // let legacy = LegacyManager.shared
    // legacy.migrate()
    newConfiguration()
}
```
**Why**: 注释掉的代码是技术债务信号。Git 保留完整历史，任何时候都能恢复。注释掉的代码传递错误信号："这段代码可能还有用"，造成维护者困惑。

### HR-5: Summary 使用句子片段（sentence fragment），以句号结尾

**Citation**: [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/#fundamentals) — "Begin with a summary as a sentence fragment"

```swift
// ✅ CORRECT — 函数：动词开头 / 属性：名词短语
/// Returns the winning bid from the auction response.
func winningBid(from response: AuctionResponse) -> Bid?

/// The current ad placement configuration.
var placement: PlacementConfig

/// Creates a new bid loader for the given ad unit.
init(adUnitID: String)
```
```swift
// ❌ WRONG — 完整句子 / "This method" 开头
/// This method returns the winning bid from the auction response.
func winningBid(from response: AuctionResponse) -> Bid?

/// This property stores the current ad placement configuration.
var placement: PlacementConfig
```

**Summary 起始模式**:

| 声明类型 | 起始模式 | 示例 |
|---------|---------|------|
| 函数/方法 | 动词: "Returns...", "Loads...", "Inserts..." | `/// Returns the formatted price.` |
| 属性 | 名词短语: "The...", "A..." | `/// The background color of the view.` |
| init | "Creates..." | `/// Creates an instance with the given ID.` |
| subscript | "Accesses..." | `/// Accesses the element at the given index.` |
| mutating | 动词: "Adds...", "Removes...", "Inserts..." | `/// Inserts the element at the beginning.` |

### HR-6: Documentation tag 顺序 — Parameters → Returns → Throws

**Citation**: [Swift Documentation Comments](https://github.com/apple/swift/blob/main/docs/DocumentationComments.md)

```swift
// ✅ CORRECT — 严格按顺序
/// Loads an ad for the given placement.
///
/// - Parameters:
///   - placement: The placement configuration.
///   - timeout: Maximum wait time in seconds.
/// - Returns: The loaded ad, or `nil` if no fill.
/// - Throws: `AdError.networkUnavailable` if offline.
func loadAd(placement: Placement, timeout: TimeInterval) throws -> Ad?
```
```swift
// ❌ WRONG — 顺序错误
/// - Returns: The loaded ad.
/// - Parameters:
///   - placement: The placement configuration.
/// - Throws: `AdError.networkUnavailable` if offline.
```

### HR-7: 非文档注释使用 `//`，禁止 `/* */`

**Citation**: [Google Swift Style Guide](https://google.github.io/swift/) — "Non-documentation comments are always written with `//`"

```swift
// ✅ CORRECT
// Workaround for UIKit bug where layoutSubviews is called before bounds update
override func layoutSubviews() { ... }
```
```swift
// ❌ WRONG
/* Workaround for UIKit bug where layoutSubviews is called before bounds update */
override func layoutSubviews() { ... }
```

---

## Soft Rules (SR) — 推荐遵循

### SR-1: `// MARK: -` 组织 UIKit 文件结构

**Citation**: [Kodeco Style Guide](https://github.com/kodecocodes/swift-style-guide) — MARK organization | [LinkedIn Swift Style Guide](https://github.com/linkedin/swift-style-guide)

**推荐的 MARK 组织（UIKit ViewController）**:

```swift
class AdViewController: UIViewController {

    // MARK: - Properties

    private let viewModel: AdViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(viewModel: AdViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
    }

    // MARK: - Setup

    private func setupUI() { ... }
    private func bindViewModel() { ... }

    // MARK: - Actions

    @objc private func refreshButtonTapped() { ... }
}

// MARK: - UITableViewDataSource
extension AdViewController: UITableViewDataSource { ... }

// MARK: - UITableViewDelegate
extension AdViewController: UITableViewDelegate { ... }
```

**规则**:
- 使用 `// MARK: -`（带连字符）产生 Xcode 跳转栏分隔线
- 协议遵循放在 extension 中，每个 extension 一个 `// MARK: -`
- 少于 ~30 行的文件不需要 MARK
- MARK 内容为英文（与 Xcode 跳转栏一致）

### SR-2: TODO/FIXME 包含归属和 ticket 引用

```swift
// ✅ CORRECT
// TODO: (pengyu) Add bid floor support - JIRA-4521
// FIXME: (pengyu) Memory leak in ad refresh cycle - JIRA-4530

// ❌ WRONG — 无归属，无 ticket
// TODO: fix this later
// FIXME: doesn't work sometimes
```

**规则**:
- `// TODO:` — 已知的待办事项
- `// FIXME:` — 已知的 bug 或需要修复的问题
- 始终包含负责人和 ticket/issue 引用（如有）
- 不要用 TODO 标记没有时间表的愿望功能

### SR-3: 非显而易见的 `internal` API 也应添加文档注释

**Citation**: [LinkedIn Swift Style Guide](https://github.com/linkedin/swift-style-guide) — "Add doc comments for any function more complicated than O(1)"

```swift
// ✅ CORRECT — internal 但逻辑复杂，需要文档
/// Selects the highest-bidding adapter from concurrent auction results.
///
/// Applies floor price filtering and timeout penalties before ranking.
/// Adapters that timed out receive a 10% bid penalty.
///
/// - Parameter results: Raw auction results from all adapters.
/// - Returns: The winning result, or `nil` if all bids are below floor.
/// - Complexity: O(n) where n is the number of adapters.
func selectWinner(from results: [AuctionResult]) -> AuctionResult?
```

**规则**: `private` 简单函数不需要文档注释；`internal` 复杂逻辑应当添加。

### SR-4: 复杂算法标注 Complexity

**Citation**: [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) — "Document the complexity of any computed property that is not O(1)"

```swift
/// Finds all placements matching the given targeting criteria.
///
/// - Complexity: O(n × m) where n is placements count and m is criteria count.
func matchingPlacements(for criteria: [TargetingCriterion]) -> [Placement]
```

### SR-5: Workaround 和 Hack 必须注释 "为什么"

```swift
// ✅ CORRECT — 解释了原因和上下文
// UIKit ignores safe area for modal presentations on iOS 15.
// Force additionalSafeAreaInsets as workaround until we drop iOS 15 support.
// Ref: https://developer.apple.com/forums/thread/682420
additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 0)
```
```swift
// ❌ WRONG — "什么" 都不解释
// Fix safe area
additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 0)
```

### SR-6: 正则表达式必须注释匹配内容

```swift
// ✅ CORRECT
// Matches ad unit ID format: /<networkCode>/<adUnitPath>
// Examples: "/12345/homepage_banner", "/12345/interstitial/rewarded"
let adUnitPattern = #"^/\d+/[\w/]+$"#
```

---

## Decision Tree: 是否需要注释？

```
需要为这段代码添加注释吗？
│
├── 是 public/open 声明？
│   ├── YES → 必须添加 /// 文档注释 (HR-2)
│   └── NO ↓
│
├── 代码意图从命名和结构就能看懂？
│   ├── YES → 不需要注释 (HR-3)
│   └── NO ↓
│
├── 这是 workaround / hack / 非显而易见的逻辑？
│   ├── YES → 添加 // 注释解释 "为什么" (SR-5)
│   └── NO ↓
│
├── 这是复杂算法（非 O(1)）？
│   ├── YES → 添加 /// 文档注释含 Complexity (SR-4)
│   └── NO ↓
│
├── 这是正则表达式或魔法数字？
│   ├── YES → 添加 // 注释解释匹配内容/含义 (SR-6)
│   └── NO ↓
│
└── 不需要注释。让代码自解释。
```

## Decision Tree: 选择注释类型

```
需要哪种注释？
│
├── 给 API 调用者看的文档？
│   └── YES → /// 文档注释 (DocC)
│       ├── 有参数/返回值/异常 → 加 Parameters/Returns/Throws tags
│       └── 只需概述 → 单行 /// summary 即可
│
├── 给维护者看的实现细节？
│   └── YES → // 内联注释
│       ├── 解释 "为什么" → 放在代码上方
│       └── 简短补充 → 行尾注释（2+ 空格间隔）
│
├── 文件/类的结构组织？
│   └── YES → // MARK: - SectionName
│
└── 待办/已知问题？
    └── YES → // TODO: (owner) description - TICKET
              // FIXME: (owner) description - TICKET
```

---

## AI Common Mistakes (≥3 items)

### 1. 过度注释 — 给每行代码都加注释

**这是 AI 最严重、最普遍的注释错误。** OX Security 报告指出 90-100% 的 AI 生成代码存在此问题。

```swift
// ❌ WRONG — AI 生成的过度注释
func loadAds() {
    // Create the ad request
    let request = AdRequest()
    // Set the ad unit ID
    request.adUnitID = adUnitID
    // Set the timeout interval
    request.timeout = 30.0
    // Load the ad using the loader
    adLoader.load(request)
    // Log that we started loading
    Logger.log("Started loading ad")
}

// ✅ CORRECT — 自解释代码，零注释
func loadAds() {
    let request = AdRequest()
    request.adUnitID = adUnitID
    request.timeout = 30.0
    adLoader.load(request)
    Logger.log("Started loading ad")
}
```

**检测信号**: 如果注释数量接近或超过代码行数，几乎一定是过度注释。

### 2. 文档注释复述声明名称

AI 生成的 `///` 注释经常只是用自然语言重复了属性名或方法名。

```swift
// ❌ WRONG — 复述声明名
/// The ad unit ID.
var adUnitID: String

/// The delegate.
weak var delegate: AdLoaderDelegate?

/// Loads the ad.
func loadAd() { ... }

// ✅ CORRECT — 提供声明名之外的价值
/// Identifier for requesting ads from the mediation server.
/// Format: `"/<networkCode>/<adUnitPath>"`.
var adUnitID: String

/// Receives callbacks for ad lifecycle events including load, display, and error states.
weak var delegate: AdLoaderDelegate?

/// Initiates an asynchronous ad request using the current placement configuration.
///
/// Notifies `delegate` on completion. Only one request per placement is active at a time;
/// calling this while a request is in-flight is a no-op.
func loadAd() { ... }
```

**检测信号**: 如果删掉注释后，信息量没有减少，那注释就是多余的。

### 3. 保留注释掉的代码和 changelog 注释

AI 经常留下"备选方案"代码或者添加变更记录注释。

```swift
// ❌ WRONG — 注释掉的代码 + changelog
// Added: Support for new ad format (v2.1)
// Modified: Changed from sync to async loading
func configure(with ad: Ad) {
    // self.legacySetup(ad)
    // let oldBanner = BannerView(frame: .zero)
    self.modernSetup(ad)
}

// ✅ CORRECT — 干净的实现，历史在 git 中
func configure(with ad: Ad) {
    modernSetup(ad)
}
```

### 4. 使用 `/** */` block comment 或 closing-brace 注释

```swift
// ❌ WRONG — block comment + closing brace 注释
/**
 * Processes the auction response and selects a winner.
 */
func processResponse(_ response: AuctionResponse) {
    if let winner = response.winner {
        for adapter in adapters {
            // ...
        } // end for adapters
    } // end if winner
} // end processResponse

// ✅ CORRECT — /// 风格 + 如果需要 closing brace 注释说明函数太长了
/// Processes the auction response and selects a winner.
func processResponse(_ response: AuctionResponse) {
    guard let winner = response.winner else { return }
    adapters.forEach { processAdapter($0, winner: winner) }
}
```

### 5. 给 `private` 简单属性添加不必要的文档注释

```swift
// ❌ WRONG — 简单 private 属性不需要文档注释
/// The table view for displaying ads.
private let tableView = UITableView()

/// The activity indicator.
private let loadingIndicator = UIActivityIndicatorView(style: .medium)

/// The empty state label.
private let emptyLabel = UILabel()

// ✅ CORRECT — 名称已自解释
private let tableView = UITableView()
private let loadingIndicator = UIActivityIndicatorView(style: .medium)
private let emptyLabel = UILabel()
```

### 6. MARK 滥用 — 给很短的文件添加过多 MARK 分区

```swift
// ❌ WRONG — 20 行的文件用了 4 个 MARK
// MARK: - Properties
private let id: String

// MARK: - Init
init(id: String) { self.id = id }

// MARK: - Methods
func description() -> String { id }

// MARK: - Equatable
static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }

// ✅ CORRECT — 短文件不需要 MARK
private let id: String

init(id: String) { self.id = id }

func description() -> String { id }

static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
```

---

## DocC 支持的标签速查

| 类别 | 标签 |
|------|------|
| **核心** | `Parameter`, `Parameters`, `Returns`, `Throws` |
| **安全性** | `Precondition`, `Postcondition`, `Requires`, `Invariant` |
| **元数据** | `Complexity`, `Author`, `Since`, `Version` |
| **提示** | `Note`, `Important`, `Warning`, `Attention`, `Remark` |
| **其他** | `Bug`, `Experiment`, `SeeAlso`, `Todo` |

**完整文档注释结构**:

```swift
/// Brief summary as a sentence fragment.
///
/// Extended discussion in one or more paragraphs. Supports full
/// CommonMark markdown including **bold**, *italic*, `code`,
/// [links](url), and fenced code blocks.
///
///     // Code example (indented 4 spaces)
///     let result = doSomething()
///
/// - Parameters:
///   - name: Description of the parameter.
///   - count: Description of the parameter.
/// - Returns: Description of the return value.
/// - Throws: `SomeError.case` when condition occurs.
///
/// - Complexity: O(n) where n is the length of `self`.
/// - Note: Additional context the caller should know.
/// - Warning: Critical information about misuse.
/// - SeeAlso: `relatedMethod(_:)`
```

---

## 研究来源

- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- [Swift Documentation Comments Spec](https://github.com/apple/swift/blob/main/docs/DocumentationComments.md)
- [Google Swift Style Guide](https://google.github.io/swift/)
- [Kodeco Swift Style Guide](https://github.com/kodecocodes/swift-style-guide)
- [Microsoft Swift Guide — Comments](https://microsoft.github.io/swift-guide/Comments.html)
- [LinkedIn Swift Style Guide](https://github.com/linkedin/swift-style-guide)
- [NSHipster — Swift Documentation](https://nshipster.com/swift-documentation/)
- [OX Security — AI Code Anti-Patterns](https://www.softwareseni.com/understanding-anti-patterns-and-quality-degradation-in-ai-generated-code/)
- [Addy Osmani — AI Coding Workflow](https://addyosmani.com/blog/ai-coding-workflow/)
- [Hacking with Swift — AI-Generated Swift Code](https://www.hackingwithswift.com/articles/281/what-to-fix-in-ai-generated-swift-code)

---

## 关联 Playbooks

| Playbook | 关系 | 何时参考 |
|----------|------|----------|
| [ctx-sources-001](./ctx-sources-001-swift-best-practices.md) | **上游 — Swift 语言规则** | 访问控制（public/internal/private）决定了哪些声明需要文档注释 (HR-2) |
| [ctx-sources-002](./ctx-sources-002-uikit-best-practices.md) | **互补 — UIKit 规范** | UIKit ViewController 的 `// MARK: -` 组织模式 (SR-1) 来自此 playbook |
| [ctx-testing-002](../../testing/tech/ctx-testing-002-bdd-best-practices.md) | **互补 — BDD 命名** | 测试文件的注释和 describe/context/it 命名规范 |
