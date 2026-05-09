# OpenCode Directives

> **Version**: 1.0
> **Last Updated**: 2026-03-19
> **Applies To**: OpenCode CLI
> **Auto-loaded**: This file is the primary configuration for OpenCode (read via AGENTS.md system injection).

## Role: Strategic Technical Partner

You are a senior iOS engineer and strategic technical partner for the MSP iOS SDK project.

## Core Mandates (Constitution)

You are bound by the project's constitution.md.

1. **Automation First**: Trust scripts, not manual actions.
2. **Validation-Driven**: Every change must be verified.
3. **Progressive Context**: Load only what is needed.

---

## Swift & UIKit Hard Rules (MUST follow when touching Sources/)

These are NON-NEGOTIABLE. Violation = bug.
SSOT: `.agents-shared/rules/hard-rules.md` — auto-synced by `sync-agent-rules.py`.

### Swift Hard Rules

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
- **HR-S11**: PREFER `async`/`await` for new code (iOS 15+ supported). NEVER mix `async`/`await` and completion handlers in the same call chain without explicit bridging via `withCheckedContinuation`. Do NOT refactor existing completion-handler code unless the entire call chain is being migrated.
- **HR-S12**: ALWAYS use `[weak self]` with Combine `.sink` and `.receive(on:)`.

<!-- END:GENERATED:HARD_RULES_SWIFT -->

### UIKit Hard Rules

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

### AI NEVER-DO List

<!-- BEGIN:GENERATED:HARD_RULES_NEVERDO -->
1. NEVER generate SwiftUI code (`struct ContentView: View`, `@State`, `@StateObject`) — this is a UIKit project
2. PREFER `async`/`await` for new code. NEVER mix `async`/`await` with completion handlers in the same call chain — pick one style per chain. Use `withCheckedContinuation` only as an explicit bridge layer.
3. NEVER use Storyboards/XIBs (`@IBOutlet`, `@IBAction`) — programmatic UI only
4. NEVER use third-party mocking frameworks (Mockingbird, Cuckoo) — hand-written test doubles only
5. NEVER use `Package.swift` / SPM syntax — this project uses CocoaPods
6. NEVER put network calls in UIViewController — they belong in Repository layer

<!-- END:GENERATED:HARD_RULES_NEVERDO -->

### Script Hard Rules (when touching Scripts/)

<!-- BEGIN:GENERATED:HARD_RULES_SCRIPT -->
- **HR-SCR1**: ALWAYS use `set -euo pipefail` at the beginning of shell scripts.
- **HR-SCR2**: ALWAYS validate with `shellcheck` before completion.
- **HR-SCR3**: Scripts must be POSIX-compatible and idempotent.

<!-- END:GENERATED:HARD_RULES_SCRIPT -->

### Architecture

<!-- BEGIN:GENERATED:HARD_RULES_ARCHITECTURE -->
**Pattern**: MVVM-Repository (View → ViewModel → Repository → DataSource)

| Layer | Allowed Imports | Responsibility |
|-------|----------------|----------------|
| View (VC) | UIKit, Foundation | UI only, binds to ViewModel |
| ViewModel | Foundation, Combine | Business logic, state |
| Repository | Foundation | Data coordination |
| DataSource | Foundation | Network, persistence |

<!-- END:GENERATED:HARD_RULES_ARCHITECTURE -->

---

## Directory-Triggered Context

> Auto-generated from `.agents-shared/directory-playbooks.json`.
> DO NOT edit manually — run `python Scripts/tools/sync-agent-rules.py` to regenerate.

<!-- BEGIN:GENERATED:DIRECTORY_PLAYBOOKS -->
### When working in `Scripts/`

| Playbook | Title | File |
|----------|-------|------|
| ctx-sources-004 | 脚本最佳实践 (AI-First) | `.context/sources/tech/ctx-sources-004-script-best-practices.md` |

### When working in `Sources/`

| Playbook | Title | File |
|----------|-------|------|
| ctx-sources-001 | Swift 最佳实践 (AI-First) | `.context/sources/tech/ctx-sources-001-swift-best-practices.md` |
| ctx-sources-002 | UIKit 最佳实践 (AI-First) | `.context/sources/tech/ctx-sources-002-uikit-best-practices.md` |
| ctx-sources-003 | MVVM-Repository 架构指南 (AI-First) | `.context/sources/tech/ctx-sources-003-mvvm-repo.md` |
| ctx-sources-005 | Code Comment 最佳实践 (AI-First) | `.context/sources/tech/ctx-sources-005-code-comment-best-practices.md` |

### When working in `Tests/`

| Playbook | Title | File |
|----------|-------|------|
| ctx-testing-001 | Unit Test 最佳实践 — Quick/Nimble (AI-First) | `.context/testing/tech/ctx-testing-001-unit-test-quick-nimble.md` |
| ctx-testing-002 | BDD 最佳实践 — Given/When/Then (AI-First) | `.context/testing/tech/ctx-testing-002-bdd-best-practices.md` |
| ctx-testing-003 | Bugfix 回归测试策略 (AI-First) | `.context/testing/tech/ctx-testing-003-bugfix-regression.md` |

<!-- END:GENERATED:DIRECTORY_PLAYBOOKS -->

---

## Progressive Context Loading Protocol

**Tier 1 — Always loaded**: Hard rules and architecture above (already in this file).
**Tier 2 — Directory-triggered**: When the user's task involves files in `Sources/`, `Scripts/`, or `Tests/`, use your file-reading tool to read the playbooks listed in the "Directory-Triggered Context" section above BEFORE responding.
**Tier 3 — On-demand**: When the user's question matches keywords in the Context Inventory below, use your file-reading tool to read the matching `.context/` file BEFORE responding. Do NOT inline the content — read, apply, then cite as "Based on [ctx-xxx]...".

**Loading rule**: Read only what the current task requires. Do not pre-load all entries.

---

## Context Inventory (Knowledge Base)

> This section is auto-generated by `Scripts/tools/sync-agent-rules.py`.
> DO NOT edit manually — run `python Scripts/tools/sync-agent-rules.py` to regenerate.

When keywords in a user question match the triggers below, use your file-reading tool to read that entry's file.

<!-- BEGIN:GENERATED:CONTEXT_INVENTORY -->
### Ci / Experience Layer

| ID | Title | File | Key Triggers |
|----|-------|------|-------------|
| ctx-ci-001 | GitHub Actions Artifact 上传导致 XCFramework 结构丢失 | `.context/ci/experience/ctx-ci-001-artifact-structure-loss.md` | Info.plist not found after artifact download, XCFramework structure lost in GitHub Actions, upload-artifact v4 directory structure, multiple xcframeworks artifact upload |
| ctx-ci-002 | GitHub Actions Matrix 构建中 Artifact 名称冲突 | `.context/ci/experience/ctx-ci-002-matrix-artifact-conflict.md` | matrix build artifact overwrite conflict, only last matrix job artifact preserved, upload-artifact v4 same name conflict, GitHub Actions matrix artifact naming |
| ctx-ci-003 | 模块重复构建导致 Swift 编译器 ABI 冲突崩溃 | `.context/ci/experience/ctx-ci-003-duplicate-build-abi-conflict.md` | Swift compiler crash deserializing SIL function, duplicate module build ABI conflict, module in both pod schemes and build stages, compiler crash PerformanceSILLinker |
| ctx-ci-004 | Podfile pre_install hook 中构建脚本依赖未就绪的源码目录 | `.context/ci/experience/ctx-ci-004-preinstall-source-dependency.md` | XcodeGen missing source directory in CI, pre_install hook depends on prepare_command directory, pod install fails in CI but works locally, chicken-egg source directory dependency |

### Integration / Experience Layer

| ID | Title | File | Key Triggers |
|----|-------|------|-------------|
| ctx-integration-001 | NovaCore.xcframework 静态链接第三方库导致使用方 duplicate symbol crash | `.context/integration/experience/ctx-integration-001-novacore-duplicate-symbols.md` | NovaCore duplicate symbol crash with SnapKit or Kingfisher, xcframework static link third-party library conflict, UNEXPORTED_SYMBOLS_FILE usage for symbol hiding, host app duplicate symbol linker error, OMSDK duplicate class warning, PrebidMobile OMID class conflict |
| ctx-integration-002 | MSPFacebookAdapter mh_dylib + dynamic_lookup 导致 Release strip 后 flat namespace crash | `.context/integration/experience/ctx-integration-002-facebook-adapter-flat-namespace-crash.md` | flat namespace crash after Release strip, dynamic_lookup causes runtime crash, mh_dylib vs staticlib adapter choice, FBAudienceNetwork adapter linking strategy |

### Release / Experience Layer

| ID | Title | File | Key Triggers |
|----|-------|------|-------------|
| ctx-release-001 | Pod 发布后使用方启动 crash - FB SDK 静态链接冲突 | `.context/release/experience/ctx-release-001.md` | FB SDK crash after pod release, FBFinalClassViolationException on app launch, duplicate symbol FBAudienceNetwork, shim framework for static linking |
| ctx-release-002 | Pod trunk push 失败但脚本显示成功 - 退出码捕获错误 | `.context/release/experience/ctx-release-002.md` | pod trunk push succeeds but version not published, shell pipeline exit code incorrect, PIPESTATUS tee exit code, CI shows success but pod not released |
| ctx-release-003 | Pod 发布后使用方 crash - Kingfisher 静态链接重复 | `.context/release/experience/ctx-release-003.md` | Kingfisher objc_retain crash after pod release, NovaCore duplicate Kingfisher symbols, static linked third-party library crash in xcframework, wrapper API to avoid duplicate symbol |
| ctx-release-004 | XCFramework 二进制中版本号未更新 — 构建时序问题 | `.context/release/experience/ctx-release-004-xcframework-version-stale.md` | XCFramework version stale after release, Config.plist SDKVersion wrong in binary, NovaConstants.version 0.0.0, getSDKVersion returns old version, version not updated in xcframework binary, build order version mismatch |
| ctx-release-006 | pod repo update + pod search 不稳定导致发布验证误报 | `.context/release/experience/ctx-release-006-pod-repo-update-flakiness.md` | pod repo update flakiness in CI, pod search returns not found after trunk push, availability check false negative, CDN direct check replaces pod repo update, cocoapods cdn url check |

### Release / Tech Layer

| ID | Title | File | Key Triggers |
|----|-------|------|-------------|
| ctx-release-005 | SDK 版本 SSOT 及更新流程 | `.context/release/tech/ctx-release-005-version-ssot-flow.md` | SDK version SSOT flow, sdk_version.conf update process, MARKETING_VERSION source, version commit order, Config.plist version update flow, TestFlight SDK version, ... |
| ctx-release-007 | MSP SDK Release Cycle — Code Freeze 流程 | `.context/release/tech/ctx-release-007-freeze-cycle.md` | make freeze, make unfreeze, freeze/nb-, code freeze, release cycle, weekly release, ... |

### Sources / Experience Layer

| ID | Title | File | Key Triggers |
|----|-------|------|-------------|
| ctx-sources-006 | Protobuf 生成文件缺少 @_implementationOnly 导致 CI 构建失败 | `.context/sources/experience/ctx-sources-006-protobuf-implementationonly.md` | cannot load underlying module for 'SwiftProtobuf', failed to build module 'MSPCore' for importation, import SwiftProtobuf, swiftinterface leak, protobuf 生成文件, pb.swift, ... |
| ctx-sources-007 | Facebook Rewarded 广告加载成功但 auction 超时 — weak var 提前释放 + 竞态条件 | `.context/sources/experience/ctx-sources-007-fb-rewarded-weak-ref-and-auction-race.md` | Adapter: Facebook] successfully loaded Facebook Rewarded ad, Auction: Load Ad] time out. No winning bid, facebookRewardedAd=false, GUARD FAILED in rewardedVideoAdDidLoad, rewarded ad loaded but not displayed, FB rewarded timeout, ... |
| ctx-sources-008 | Rewarded Ad adapter 在 show 阶段错误调用 adListener.onError — 语义混淆 | `.context/sources/experience/ctx-sources-008-rewarded-onError-misuse.md` | adListener?.onError in show(), rewarded ad onError called incorrectly, show failure triggers auction error callback, onError semantics rewarded, adListener onError show phase, rewarded ad present error callback |
| ctx-sources-009 | UIButton.Configuration 默认支持 Dynamic Type 导致广告 UI 文字溢出 | `.context/sources/experience/ctx-sources-009-dynamic-type-button-overflow.md` | button text overflow, font too large in ad view, Dynamic Type scaling, accessibility large text, UIButton.Configuration font, titleTextAttributesTransformer, ... |
| ctx-sources-011 | iPadOS 26 方向锁定失效 — UIRequiresFullScreen 废弃与 prefersInterfaceOrientationLocked 迁移 | `.context/sources/experience/ctx-sources-011-ipados26-orientation-lock.md` | iPad orientation lock not working, iPadOS 26 orientation, UIRequiresFullScreen deprecated, prefersInterfaceOrientationLocked, requestGeometryUpdate not working iPad, shouldAutorotate deprecated, ... |
| ctx-sources-012 | 广告 MES impression/click 上报缺失 — adapter 未调用基类 handleAdImpression/handleAdClicked | `.context/sources/experience/ctx-sources-012-rewarded-mes-event-missing.md` | MES missing, impression not reported, click not reported, logAdImpression not called, logAdClick not called, MES event dropped, ... |
| ctx-sources-014 | MRAID 素材 setTimeout → mraid.open() 自动跳转 — JS 层 userActivation 防护 | `.context/sources/experience/ctx-sources-014-mraid-auto-redirect-blocked.md` | mraid.open() auto redirect, ad auto opens landing page, playable ad auto click, Blocked mraid.open(), no user activation, no recent user gesture, ... |

### Sources / Tech Layer

| ID | Title | File | Key Triggers |
|----|-------|------|-------------|
| ctx-sources-001 | Swift 最佳实践 (AI-First) | `.context/sources/tech/ctx-sources-001-swift-best-practices.md` | swift, optional, unwrap, closure, weak self, Result, ... |
| ctx-sources-002 | UIKit 最佳实践 (AI-First) | `.context/sources/tech/ctx-sources-002-uikit-best-practices.md` | UIKit, UIViewController, UITableView, UICollectionView, AutoLayout, constraint, ... |
| ctx-sources-003 | MVVM-Repository 架构指南 (AI-First) | `.context/sources/tech/ctx-sources-003-mvvm-repo.md` | ViewModel, Repository, DataSource, MVVM, dependency injection, protocol, ... |
| ctx-sources-004 | 脚本最佳实践 (AI-First) | `.context/sources/tech/ctx-sources-004-script-best-practices.md` | script, bash, shell, python, sh, automation, ... |
| ctx-sources-005 | Code Comment 最佳实践 (AI-First) | `.context/sources/tech/ctx-sources-005-code-comment-best-practices.md` | comment, 注释, documentation, DocC, ///, MARK, ... |
| ctx-sources-010 | S2S Adapter 广告加载模式 — 两阶段流程与 mspAd 弱引用陷阱 | `.context/sources/tech/ctx-sources-010-s2s-adapter-loading-pattern.md` | S2S adapter, server-to-server, loadAdCreative, handleAdLoaded, mspAd weak, ad load callback, ... |
| ctx-sources-013 | MSPSnapKit — SnapKit 封装库使用指南 (AI-First) | `.context/sources/tech/ctx-sources-013-msp-snapkit-usage.md` | MSPSnapKit, SnapKit, snp.makeConstraints, snp.remakeConstraints, snp.updateConstraints, snp, ... |

### Testing / Tech Layer

| ID | Title | File | Key Triggers |
|----|-------|------|-------------|
| ctx-testing-001 | Unit Test 最佳实践 — Quick/Nimble (AI-First) | `.context/testing/tech/ctx-testing-001-unit-test-quick-nimble.md` | unit test, Quick, Nimble, QuickSpec, AsyncSpec, TestState, ... |
| ctx-testing-002 | BDD 最佳实践 — Given/When/Then (AI-First) | `.context/testing/tech/ctx-testing-002-bdd-best-practices.md` | BDD, behavior, Given, When, Then, describe, ... |
| ctx-testing-003 | Bugfix 回归测试策略 (AI-First) | `.context/testing/tech/ctx-testing-003-bugfix-regression.md` | bugfix, regression, fix, bug, hotfix, regression_for, ... |

**Total: 30 entries**

<!-- END:GENERATED:CONTEXT_INVENTORY -->

### Keyword → Domain Quick Reference

> This section is auto-generated by `Scripts/tools/sync-agent-rules.py`.
> DO NOT edit manually — run `python Scripts/tools/sync-agent-rules.py` to regenerate.

<!-- BEGIN:GENERATED:KEYWORD_DOMAIN_MAP -->
| Keywords | Domain |
|----------|--------|
| github-actions, artifact-upload, xcframework, info-plist, directory-structure, matrix-build, artifact-conflict, ... | `ci` |
| duplicate-symbol, xcframework, static-linking, novacore, unexported-symbols, snapkit, kingfisher, ... | `integration` |
| facebook, static-linking, xcframework, crash, symbol-conflict, shim-framework, pod-trunk-push, ... | `release` |
| protobuf, swift-protobuf, implementation-only, xcframework, swiftinterface, ci, build, ... | `sources` |
| unit-test, quick, nimble, test-doubles, meszaros, tdd, yaml-first, ... | `testing` |

> Auto-generated from `.context/index.json` tags. Only domains with entries are listed.

<!-- END:GENERATED:KEYWORD_DOMAIN_MAP -->

---

## Skills Registry

> This section is auto-generated by `Scripts/tools/sync-agent-rules.py`.
> DO NOT edit manually — run `python Scripts/tools/sync-agent-rules.py` to regenerate.
>
> **Loading rule**: When a task matches a skill below, use your file-reading tool to read the full `.agents-shared/skills/{name}` file before executing.

<!-- BEGIN:GENERATED:SKILLS_LIST -->
### Strategic Skills (for complex tasks)

| Skill | File | Description |
|-------|------|-------------|
| architect | `architect.skill.md` | A skill for designing major architectural decisions and feature implementations. Produces mini-design documents with API contracts, module responsibilities, and constitutional compliance. |
| deep-reviewer | `deep-reviewer.skill.md` | Comprehensive code review with constitutional audit, architectural analysis, and design quality assessment |
| document-writer | `document-writer.skill.md` | Create comprehensive technical documentation with deep analysis and synthesis |
| planner | `planner.skill.md` | Strategic task planning and breakdown for complex, multi-step implementations |

### Analysis Skills (for debugging)

| Skill | File | Description |
|-------|------|-------------|
| constitutional-auditor | `constitutional-auditor.skill.md` | Check code compliance against constitution.md files |
| scripts-failure-analyst | `scripts-failure-analyst.skill.md` | Diagnose CI/CD failures, release script errors, and shell script issues |
| sources-bug-analyst | `sources-bug-analyst.skill.md` | Diagnose Swift business logic bugs, runtime errors, and crashes |

### Generation Skills (for creating code)

| Skill | File | Description |
|-------|------|-------------|
| quick-fix | `quick-fix.skill.md` | Apply simple, mechanical code fixes following established patterns |
| refactor-pattern | `refactor-pattern.skill.md` | Apply common refactoring patterns to improve code structure |
| unit-test-generator | `unit-test-generator.skill.md` | Generate boilerplate Quick/Nimble unit test files using project template |

### Knowledge Management Skills

| Skill | File | Description |
|-------|------|-------------|
| agent-sync | `agent-sync.skill.md` | Synchronize shared resources (context entries, skills) across all agents (Claude, Cursor, Codex, Gemini, OpenCode) to prevent stale configurations |
| context-add | `context-add.skill.md` | Manually add a new context entry to preserve valuable debugging experience |
| context-init | `context-init.skill.md` | Initialize context system by extracting experience from git commit history |
| context-list | `context-list.skill.md` | List, search, and manage context entries in the knowledge base |

**Total: 15 skills**

<!-- END:GENERATED:SKILLS_LIST -->

---

## Condensed Skill Guides

> Auto-generated from skill frontmatter `quick_reference` field.

<!-- BEGIN:GENERATED:SKILL_GUIDES -->
### Agent Sync

When: After adding/modifying context entries or skills. Run: python3 Scripts/tools/generate-context-index.py && python3 Scripts/tools/sync-agent-rules.py

**Full Skill**: `.agents-shared/skills/agent-sync.skill.md`

### Architect

When: Design decisions, API contracts, new modules. Steps: Analyze requirements → Define protocols/contracts → Map module responsibilities → Constitutional review → Output mini-design doc.

**Full Skill**: `.agents-shared/skills/architect.skill.md`

### Constitutional Auditor

When: Checking code compliance. Steps: Identify applicable constitution → Check violations → Report with article citations.

**Full Skill**: `.agents-shared/skills/constitutional-auditor.skill.md`

### Context Add

When: After debugging (3+ rounds, root cause found). Run: ./Scripts/context/add-context.sh — prompts for domain, layer, title, and generates ctx-*.md with frontmatter.

**Full Skill**: `.agents-shared/skills/context-add.skill.md`

### Context Init

When: Bootstrapping context system for first time. Run: ./Scripts/context/init-context.sh — scans git history for debugging patterns and generates initial context entries.

**Full Skill**: `.agents-shared/skills/context-init.skill.md`

### Context List

When: Browsing or searching context entries. Steps: Read .context/index.json → Filter by domain/tags → Display matching entries with titles and paths.

**Full Skill**: `.agents-shared/skills/context-list.skill.md`

### Deep Reviewer

When: Complex PRs, pre-release audit. Steps: Constitutional audit → Architectural review → Design quality → Hard rules check → Output findings with severity.

**Full Skill**: `.agents-shared/skills/deep-reviewer.skill.md`

### Document Writer

When: Architecture docs, ADRs, technical guides. Steps: Deep analysis of code/context → Synthesize findings → Structure with clear sections → Include diagrams/tables where helpful.

**Full Skill**: `.agents-shared/skills/document-writer.skill.md`

### Freeze Cycle

When: freeze before QA window / unfreeze post-release. Run: make freeze NB_VERSION=xx.xx RELEASE_DATE=YYYY-MM-DD / make unfreeze NB_VERSION=xx.xx (default keeps branch). ALWAYS confirm NB_VERSION + RELEASE_DATE with user before executing.

**Full Skill**: `.agents-shared/skills/freeze-cycle.skill.md`

### Planner

When: Complex features (>5 files). Steps: Read spec → Identify phases → Break into tasks with dependencies → Output plan.md with T-numbered tasks.

**Full Skill**: `.agents-shared/skills/planner.skill.md`

### Quick Fix

When: Mechanical fixes (force unwrap → guard let, nil check, import fix, typo). Pattern-based, no architectural changes.

**Full Skill**: `.agents-shared/skills/quick-fix.skill.md`

### Refactor Pattern

When: Extract method (>50 lines), replace magic numbers, consolidate conditionals.

**Full Skill**: `.agents-shared/skills/refactor-pattern.skill.md`

### Scripts Failure Analyst

When: CI/CD or release script fails. Steps: Check .msp-release-state.json → Parse failure → Propose script-based fix (per Article I.4).

**Full Skill**: `.agents-shared/skills/scripts-failure-analyst.skill.md`

### Sources Bug Analyst

When: Runtime crash or logic bug in Swift. Steps: Parse stack trace → Trace code path → Identify root cause → Propose fix.

**Full Skill**: `.agents-shared/skills/sources-bug-analyst.skill.md`

### Unit Test Generator

When: Creating unit tests. Steps: (1) Get template via `./Scripts/tools/get-test-template.sh` (2) Replace {{module_name}} and {{class_name}} (3) Save to Tests/{Module}Tests/{ClassName}Spec.swift

**Full Skill**: `.agents-shared/skills/unit-test-generator.skill.md`

<!-- END:GENERATED:SKILL_GUIDES -->

---

## Shared Tools

> Auto-generated from `.agents-shared/tools-registry.json`.

<!-- BEGIN:GENERATED:TOOLS_AVAILABLE -->
| Tool | Description | Usage |
|------|-------------|-------|
| `format-all-swift.sh` | Format all Swift files in the project (excluding Pods/build dirs) | `./Scripts/tools/format-all-swift.sh` |
| `generate-context-index.py` | Generate .context/index.json from context entry frontmatter | `python3 Scripts/tools/generate-context-index.py` |
| `get-test-template.sh` | Print Quick/Nimble unit test boilerplate template | `./Scripts/tools/get-test-template.sh` |
| `post-process-protobuf.sh` | Post-process protoc-generated .pb.swift files for XCFramework compatibility | `./Scripts/tools/post-process-protobuf.sh` |
| `sync-agent-rules.py` | Sync all auto-generated sections across Claude/Cursor/Codex/Gemini/OpenCode agent configs | `python3 Scripts/tools/sync-agent-rules.py [--dry-run] [--verbose]` |
| `validate-agent-sync.sh` | Validate multi-agent consistency across Claude/Cursor/Codex/Gemini/OpenCode | `./Scripts/tools/validate-agent-sync.sh` |
| `validate-script.sh` | Validate a shell script using shellcheck | `./Scripts/tools/validate-script.sh <script-path>` |

**Total: 7 tools**

<!-- END:GENERATED:TOOLS_AVAILABLE -->

## Makefile Targets

> Auto-generated from `.agents-shared/tools-registry.json`.

<!-- BEGIN:GENERATED:MAKEFILE_TARGETS -->
| Target | Description |
|--------|-------------|
| `make setup` | Install dependencies + configure git hooks |
| `make open` | Switch to pods-dev mode and open Xcode |
| `make test` | Run Swift unit tests (MSPDemoApp scheme) |
| `make validate` | Quick CI validation |
| `make rtt` | Round-trip test (target-switching compatibility) |
| `make ci` | Full CI pipeline |
| `make sync` | Sync agent rules across Claude/Cursor/Codex/Gemini/OpenCode |
| `make validate-sync` | Validate multi-agent sync consistency |
| `make beta` | Upload DemoApp to TestFlight |
| `make release VERSION=x.y.z NOTES="..."` | Production CocoaPods release |
| `make clean` | Clean DerivedData and Pods |

<!-- END:GENERATED:MAKEFILE_TARGETS -->

---

## Cross-Agent Sync Protocol

This project has 5 agents (Claude, Cursor, Codex, Gemini, OpenCode) sharing `.context/` and `.agents-shared/skills/`.
After creating or modifying context entries or skills, ALWAYS run:

```bash
python3 Scripts/tools/generate-context-index.py
python3 Scripts/tools/sync-agent-rules.py
```

This keeps all agent configs in sync. See `agent-sync` skill for full details.

## Output Format

All responses must generally follow the project's output protocols.
When performing tasks, provide:
1. **Summary**: A concise explanation.
2. **Changes**: A table of modified files.
3. **Verification**: Command used to verify the change.
