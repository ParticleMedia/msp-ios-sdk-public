# Hard Rules — Swift, UIKit, Scripts

These are NON-NEGOTIABLE coding standards. Violation = bug.
SSOT: `.agents-shared/rules/hard-rules.md` — auto-synced by `sync-agent-rules.py`.

## Swift Hard Rules

<!-- BEGIN:GENERATED:HARD_RULES_SWIFT -->
- **HR-S1**: NEVER force-unwrap (`!`) in production code. Use `guard let` / `if let` / `??`.
- **HR-S2**: ALWAYS use `[weak self]` in escaping closures.
- **HR-S3**: ALWAYS use `Result<T, Error>` for async callbacks (not `(T?, Error?)`).
- **HR-S4**: NEVER `import UIKit` in ViewModel or Repository layers. Only `Foundation`/`Combine`.
- **HR-S5**: ALWAYS use `let` over `var` unless mutation is required.
- **HR-S6**: NEVER use `Any`/`AnyObject` when protocol or generic works.
- **HR-S7**: ALWAYS define protocol before implementation (Protocol-First Design).
- **HR-S8**: NEVER use singletons in ViewModel/Repository. Use dependency injection.
- **HR-S9**: ALWAYS handle all `Result`/`Optional` cases explicitly. No silent failures.
- **HR-S10**: ALWAYS use `private` by default, promote access only as needed.
- **HR-S11**: NEVER introduce `async`/`await`. Project uses completion handlers only.
- **HR-S12**: ALWAYS use `[weak self]` with Combine `.sink` and `.receive(on:)`.

<!-- END:GENERATED:HARD_RULES_SWIFT -->

## UIKit Hard Rules

<!-- BEGIN:GENERATED:HARD_RULES_UIKIT -->
- **HR-U1**: ALWAYS update UI on the main thread (`DispatchQueue.main.async`).
- **HR-U2**: ALWAYS set `translatesAutoresizingMaskIntoConstraints = false` for programmatic views.
- **HR-U3**: ALWAYS use `weak` for delegate properties.
- **HR-U4**: NEVER put business logic in UIViewController. Logic belongs in ViewModel.
- **HR-U5**: ALWAYS pair `register` + `dequeue` for reusable cells.
- **HR-U6**: NEVER force-cast cells (`as!` in `cellForRowAt`). Use `guard let` + `as?`.
- **HR-U7**: ALWAYS remove observers/notifications in `deinit`.
- **HR-U8**: ALWAYS configure views in `viewDidLoad`, NOT in `init`.
- **HR-U9**: NEVER access `self.view` from `init` (triggers premature `loadView()`).
- **HR-U10**: ALWAYS use `NSLayoutAnchor` API for programmatic constraints.
- **HR-U11**: NEVER block the main thread with synchronous network/I/O calls.
- **HR-U12**: ALWAYS implement `prepareForReuse()` to reset cell state.

<!-- END:GENERATED:HARD_RULES_UIKIT -->

## AI NEVER-DO List

<!-- BEGIN:GENERATED:HARD_RULES_NEVERDO -->
1. NEVER generate SwiftUI code (`struct ContentView: View`, `@State`, `@StateObject`) — this is a UIKit project
2. NEVER use `async`/`await` / `@MainActor` / `Task { }` — use completion handlers
3. NEVER use Storyboards/XIBs (`@IBOutlet`, `@IBAction`) — programmatic UI only
4. NEVER use third-party mocking frameworks (Mockingbird, Cuckoo) — hand-written test doubles only
5. NEVER use `Package.swift` / SPM syntax — this project uses CocoaPods
6. NEVER put network calls in UIViewController — they belong in Repository layer

<!-- END:GENERATED:HARD_RULES_NEVERDO -->

## Script Hard Rules

<!-- BEGIN:GENERATED:HARD_RULES_SCRIPT -->
- **HR-SCR1**: ALWAYS use `set -euo pipefail` at the beginning of shell scripts.
- **HR-SCR2**: ALWAYS validate with `shellcheck` before completion.
- **HR-SCR3**: Scripts must be POSIX-compatible and idempotent.

<!-- END:GENERATED:HARD_RULES_SCRIPT -->

## Architecture

<!-- BEGIN:GENERATED:HARD_RULES_ARCHITECTURE -->
**Pattern**: MVVM-Repository (View → ViewModel → Repository → DataSource)

| Layer | Allowed Imports | Responsibility |
|-------|----------------|----------------|
| View (VC) | UIKit, Foundation | UI only, binds to ViewModel |
| ViewModel | Foundation, Combine | Business logic, state |
| Repository | Foundation | Data coordination |
| DataSource | Foundation | Network, persistence |

<!-- END:GENERATED:HARD_RULES_ARCHITECTURE -->
