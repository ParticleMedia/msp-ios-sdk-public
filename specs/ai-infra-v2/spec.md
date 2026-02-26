# Feature Specification: AI Infrastructure v2

**Feature Branch**: `ai-infra-v2`
**Created**: 2026-02-22
**Status**: Draft
**Input**: User description: "AI Infra refactor with progressive loading, packages system, YAML test cases, playbooks, multi-agent support"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Progressive Context Loading for AI Agents (Priority: P1)

An AI agent (Claude Code, Codex, or Cursor) opens the MSP iOS SDK project and begins working on a task. The agent loads only the minimal constitutional context at startup (under 60 lines of always-loaded content). As the agent navigates into specific directories (e.g., `Sources/`, `Scripts/`, `Tests/`), domain-specific context loads automatically. When the agent encounters a task requiring specialized knowledge (e.g., BDD testing patterns, MVVM-Repo architecture, bugfix regression workflow), it discovers the relevant playbook through a searchable index and loads it on demand — never preloading content that isn't needed for the current task.

**Why this priority**: Progressive loading is the foundation that enables all other improvements. Without it, AI agents waste token budget on irrelevant context, resulting in lower-quality code generation and slower task completion. Every playbook, test case schema, and package definition added in subsequent stories depends on the context being delivered efficiently.

**Independent Test**: Can be tested by having an AI agent open the project, perform a task in `Sources/`, and verifying that only relevant context was loaded (no Scripts or Tests context consumed). The agent should produce correct, constitutionally compliant code without exceeding reasonable token budgets.

**Acceptance Scenarios**:

1. **Given** an AI agent opens the project cold, **When** it reads the entry-point file (CLAUDE.md / CODEX.md / CURSOR.md), **Then** the always-loaded content is under 60 lines and contains only universal rules plus pointers to deeper context.
2. **Given** an AI agent is working in `Sources/Core/`, **When** it needs to understand the MVVM-Repo pattern, **Then** it discovers the relevant playbook via the context index and loads it on demand without loading unrelated playbooks (e.g., scripting, CI).
3. **Given** an AI agent is fixing a bug, **When** it needs to understand the bugfix regression workflow, **Then** it discovers the regression playbook via keyword matching (bugfix, regression) in the context index and loads the complete workflow.
4. **Given** an AI agent is working in Cursor IDE, **When** it opens a Swift file in `Sources/`, **Then** it receives the same contextual guidance as Claude Code or Codex would for the same task.

---

### User Story 2 - Centralized Test Case Management via YAML (Priority: P1)

A developer (human or AI) needs to add a new test case for a feature. They first define the test case in a YAML file within the centralized `packages/test-cases/` directory, following the established schema (BDD-style Given/When/Then for behavior tests, class/method-level for unit tests). Only after the YAML definition is committed do they write the corresponding Quick/Nimble implementation in Swift. A validation tool ensures every YAML-defined test case has a matching Swift implementation, and every Swift test references a valid YAML-defined case ID.

All existing test cases (currently in `Tests/TestCases/` as JSON) are migrated to the new YAML format in `packages/test-cases/`, preserving all existing IDs, metadata, and the dual-type schema (unit + behavior).

**Why this priority**: Test cases are the source of truth for what the system should do. Moving to YAML enables inline comments (critical for documenting why a test exists), supports the bugfix regression tracking field, and centralizes all test definitions in a single discoverable location. The YAML-first workflow prevents "implementation without specification" drift.

**Independent Test**: Can be tested by defining a new test case in YAML, running the validation tool (which should flag it as "defined but not implemented"), then writing the Swift test and re-running validation (which should pass).

**Acceptance Scenarios**:

1. **Given** an existing JSON test case file (e.g., `DebugAdLoad.json` with 15 cases), **When** the migration runs, **Then** all 15 cases exist in the new YAML format with identical IDs, types, and metadata, plus the JSON originals are archived.
2. **Given** a developer wants to add a new behavior test, **When** they add a YAML entry with a new ID following the `[PREFIX###]` convention, **Then** the validation tool flags it as "defined, not implemented" until the corresponding Swift test is written.
3. **Given** a YAML test case has `regression_for: "fix/some-branch"`, **When** a regression coverage report is generated, **Then** the report shows which bugfix branches have regression tests and which do not.
4. **Given** a developer writes a Swift test without a corresponding YAML definition, **When** the sync validation runs, **Then** it flags the orphaned test as "implemented, not defined" and requires a YAML entry to be added.

---

### User Story 3 - AI-First Playbooks for Development Workflows (Priority: P2)

An AI agent is tasked with implementing a new feature using the MVVM-Repo pattern with UIKit. Before writing code, it loads the MVVM-Repo playbook which provides: layer responsibilities, decision trees for "where does this code belong?", concrete anti-patterns with examples, and file-pointer references to real implementations in the codebase. The agent produces code that follows the established patterns without violating constitutional articles.

The project maintains 8 core playbooks, all written **AI-first** (optimized for AI agent consumption, not human onboarding). Each playbook includes a dedicated "AI Common Mistakes" section listing the specific anti-patterns that AI agents frequently produce, with concrete wrong→right code examples:

1. **Swift Best Practices** — Language-level rules for Swift 5.0, iOS 15+ (no async/await assumed, no `@Observable`, Combine-based patterns). AI anti-patterns: force unwrap (`!`) outside unit tests, implicit `self` capture in closures, using `Any` instead of generics, missing `[weak self]` in Combine sinks.
2. **UIKit Best Practices** — UIKit-specific patterns for Views, ViewControllers, AutoLayout, lifecycle management, navigation. AI anti-patterns: layout in `init` instead of `viewDidLoad`, missing `translatesAutoresizingMaskIntoConstraints = false`, force-casting `UITableViewCell`, creating retain cycles with delegates.
3. **Unit Test (Quick/Nimble)** — Test structure, assertion patterns, async testing with Combine, test double usage with industry-standard definitions (Meszaros taxonomy: Dummy, Stub, Spy, Mock, Fake). AI anti-patterns: using force unwrap in production code "because the test needs it", creating test doubles with wrong type (Mock when Stub suffices), not cleaning up Combine subscriptions in `afterEach`.
4. **BDD Best Practices** — `describe`/`context`/`it` nesting conventions, Given-When-Then scenario design, shared examples, test naming. AI anti-patterns: flat test structure (no context nesting), testing implementation details instead of behavior, multiple assertions in one `it` block without clear purpose.
5. **Bugfix Regression Workflow** — Mandated workflow: reproduce → define YAML regression test case → TDD red/green/refactor → commit together.
6. **MVVM-Repo Best Practices** — Layer responsibilities, dependency injection, protocol-first design, decision trees for code placement. AI anti-patterns: importing UIKit in ViewModel, putting business logic in View, using singletons instead of DI, mixing Repository and DataSource responsibilities.
7. **Script Best Practices** — Config-driven development, Bash vs Python language selection criteria, POSIX compliance on macOS. AI anti-patterns: disabling `set -euo pipefail` globally, parsing YAML with grep/sed, unquoted variables, `os.system()` instead of `subprocess.run()`, hardcoded paths, missing `trap` cleanup.
8. **Code Comment Best Practices** — When to comment and when not to, Swift DocC (`///`) documentation comments, inline comment style, `// MARK:` section organization, TODO/FIXME conventions, comment maintenance rules. AI anti-patterns: commenting every line (noise comments), restating code in English, leaving stale comments after refactoring, missing DocC on public APIs, using `//` where `///` is needed for documentation generation.

**Why this priority**: Playbooks are the "operating manuals" that make AI agents consistently productive. Without them, each agent session starts from scratch, potentially generating code that violates architectural patterns or testing conventions. Playbooks are the bridge between constitutional principles (abstract rules) and concrete coding actions.

**Independent Test**: Can be tested by having an AI agent implement a new ViewModel class using only the playbooks for guidance, then reviewing whether the output matches the expected MVVM-Repo pattern, follows Quick/Nimble BDD conventions for tests, and complies with constitutional articles.

**Acceptance Scenarios**:

1. **Given** an AI agent is implementing a new feature in `Sources/`, **When** it loads the MVVM-Repo playbook, **Then** it produces code with correct layer separation (View → ViewModel → Repository → DataSource), uses protocol-based dependency injection, and keeps UIKit imports out of ViewModel classes.
2. **Given** an AI agent is writing tests, **When** it loads the Unit Test playbook, **Then** it produces Quick/Nimble specs using the correct test double type per the Meszaros decision tree (Dummy for unused parameters, Stub for canned data, Spy for call recording, Mock for behavior verification, Fake for working implementations).
3. **Given** an AI agent is writing BDD specs, **When** it loads the BDD playbook, **Then** it produces specs with proper `describe`/`context`/`it` nesting, Given-When-Then comments, and shared examples where appropriate.
4. **Given** an AI agent is fixing a bug, **When** it loads the bugfix regression playbook, **Then** it follows the mandated workflow: add YAML regression test case first → write failing Swift test → fix the code → verify test passes → commit test + fix together.
5. **Given** an AI agent needs to decide where new code belongs, **When** it consults the MVVM-Repo playbook's decision tree, **Then** it correctly places third-party SDK code in `Adapters/`, pure business logic in `Core/MSPCore/`, and iOS-specific code in `Core/MSPiOSCore/`.
6. **Given** an AI agent is writing a Bash script, **When** it loads the Script Best Practices playbook, **Then** it produces scripts with `set -euo pipefail`, quoted variables, `trap` cleanup for temp files, and uses `yq`/Python for YAML parsing instead of grep/sed.
7. **Given** an AI agent generates Swift code with `force unwrap (!`)  outside of a unit test file, **When** the playbook's "AI Common Mistakes" section is loaded, **Then** the agent recognizes this as a banned pattern and replaces it with `guard let` or `if let` with proper error handling.

---

### User Story 4 - Packages Directory as Centralized Resource Hub (Priority: P2)

The project has a `packages/` directory that serves as the single source of truth for centralized, cross-concern resources. This contains two packages:

1. **`packages/test-cases/`** — YAML-based test case definitions (migrated from `Tests/TestCases/`). Organized by domain, with schema validation and sync tooling.
2. **`packages/mock-data/`** — Consolidated test fixture data (migrated from `Tests/Fixtures/`). JSON response snapshots organized by module/scenario, with a StubFactory generator.

The directory structure is designed to be extensible — future packages can be added following the same pattern without restructuring.

**Why this priority**: Centralizing shared resources prevents fragmentation and duplication. Currently, test data is scattered across `Tests/Fixtures/` and `Tests/TestCases/` — making it hard to discover, validate, and maintain. A dedicated `packages/` directory provides a clear, conventional location that all AI agents and developers know to check.

**Independent Test**: Can be tested by verifying that the `packages/` directory exists with both packages, that the validation tooling works against the new locations, and that all AI agent entry-point files reference the packages correctly.

**Acceptance Scenarios**:

1. **Given** the project has no `packages/` directory, **When** the migration is complete, **Then** `packages/test-cases/` contains all test case YAML files with a schema definition and auto-generated index, and `packages/mock-data/` contains all JSON fixture files organized by module.
2. **Given** a developer needs to find test case definitions, **When** they navigate to `packages/test-cases/`, **Then** they find all test cases organized by domain (e.g., `debug/`, `core/`, `adapters/`), each with clear YAML files following the established schema.
3. **Given** a developer needs fixture data for a new test, **When** they navigate to `packages/mock-data/`, **Then** they find JSON response files organized by `{Module}/{scenario}.json` with a clear naming convention (success, failure_timeout, failure_no_fill, etc.).
4. **Given** a new package type is needed in the future, **When** a developer creates `packages/<new-package>/`, **Then** it follows the same structural conventions (schema, index, domain subdirectories) as the existing packages.

---

### User Story 5 - Multi-Agent Consistency (Priority: P3)

A team uses different AI agents for different workflows: Claude Code for strategic planning and deep review, Codex for batch operations and quick fixes, Cursor for interactive development. All three agents receive the same constitutional rules, the same playbook content, and the same test case schema — adapted to each agent's configuration format but semantically identical. When a playbook is updated, the change propagates to all three agent configurations.

**Why this priority**: Agent divergence creates inconsistency — one agent might follow the MVVM-Repo pattern correctly while another violates it because its configuration wasn't updated. Multi-agent consistency ensures that regardless of which tool a developer uses, the output quality and architectural compliance remain uniform.

**Independent Test**: Can be tested by giving the same coding task to all three agents (e.g., "add a new ViewModel for feature X") and verifying that all three produce code following the same architectural patterns.

**Acceptance Scenarios**:

1. **Given** a playbook is updated in the shared location, **When** each agent loads context, **Then** Claude Code, Codex, and Cursor all receive the updated guidance without manual per-agent synchronization.
2. **Given** a developer uses Cursor to implement a feature, **When** they switch to Claude Code for review, **Then** both agents reference the same architectural standards and test conventions.
3. **Given** Codex is running a batch operation to generate test stubs, **When** it needs the BDD testing playbook, **Then** it can access and apply the same playbook content as Claude Code and Cursor.

---

### Edge Cases

- What happens when an AI agent cannot find the context index or it is corrupted? The agent should fall back to constitutional principles and warn the user that the index needs regeneration.
- What happens when a test case YAML file has a duplicate ID? The validation tool must detect and reject duplicate IDs across all YAML files before any commit proceeds.
- What happens when the existing JSON test cases contain IDs that conflict with the new YAML schema? The migration must preserve all existing IDs exactly and report any schema validation failures.
- What happens when a new playbook is added but the context index is not updated? The index auto-generation script must run as part of any playbook addition, per Article X.2 (Index Integrity).
- What happens when Codex or Cursor does not support progressive loading natively? The agent configuration must simulate progressive loading through condensed instruction files that reference the same shared content.
- What happens when renaming test doubles (MockXxx → FakeXxx) breaks existing imports or references? All references across spec files, factory files, and test helpers must be updated atomically as part of the rename.
- What happens when a test double is a genuine hybrid (Stub+Spy) and doesn't fit cleanly into one category? The project convention allows `MockXxx` for hybrids, but the Unit Test playbook must document this exception explicitly with examples.

## Requirements *(mandatory)*

### Functional Requirements

**Progressive Loading**

- **FR-001**: The always-loaded entry-point file for each agent (CLAUDE.md, CODEX.md, CURSOR.md) MUST be under 60 lines and contain only universal rules plus discovery pointers.
- **FR-002**: A machine-readable context index (`.context/index.json`) MUST exist and be auto-generated from all context entries, listing each entry's path, title, domain, tags, and one-line summary.
- **FR-003**: The context index MUST be updated atomically whenever a context entry is created, modified, or deleted (per Article X.2).
- **FR-004**: Domain-triggered context (directory-specific AGENTS files, state constitutions) MUST load only when the agent operates within that directory scope.
- **FR-004a**: Existing `Sources/AGENTS-SOURCES.md` and `Scripts/AGENTS-SCRIPTS.md` MUST be slimmed down to ~20-line loading guides that specify which `.context/tech/` playbooks to load for each directory scope. All deep content (patterns, examples, anti-patterns) MUST be migrated to the corresponding playbooks in `.context/tech/`. No content duplication between AGENTS files and playbooks.

**Packages & Test Cases**

- **FR-005**: A `packages/test-cases/` directory MUST exist containing all test case definitions in YAML format.
- **FR-006**: The YAML test case schema MUST support both `unit` type (class/method-level) and `behavior` type (BDD Given/When/Then scenario-level), preserving the existing dual-type capability.
- **FR-007**: Each YAML test case MUST support an optional `regression_for` field linking the test to the bugfix branch or ticket that motivated it.
- **FR-008**: A validation tool MUST verify: (a) no duplicate IDs across all YAML files, (b) all prefix registrations are unique, (c) every YAML-defined case has a matching Swift implementation, (d) every Swift test references a valid YAML-defined ID.
- **FR-009**: YAML test case files MUST support inline comments to document why a test case exists, what bug it protects against, or what business rule it validates.
- **FR-010**: All existing test cases (currently in `Tests/TestCases/*.json`) MUST be migrated to `packages/test-cases/` in YAML format with zero data loss.
- **FR-011**: A `packages/mock-data/` directory MUST exist containing all JSON stub/fixture data, consolidated from `Tests/Fixtures/`, organized by `{Module}/{scenario}.json`.

**Test Doubles Refactoring (Industry-Standard Taxonomy)**

- **FR-012**: All test doubles MUST follow the Meszaros/Fowler canonical taxonomy with 5 types: Dummy (fills parameter lists, never called), Stub (returns preset data, no call verification), Spy (records calls for post-execution assertion), Mock (pre-programmed expectations with behavior verification), Fake (working implementation with shortcuts, not suitable for production).
- **FR-013**: [NO COMPROMISE] All existing test doubles MUST be fully refactored — not just renamed, but rewritten where necessary to match industry-standard patterns. Specifically: (a) value-type conformances (`MockDebugSection`, `MockDebugOption`) MUST be renamed to `FakeXxx` and restructured as proper Fake implementations; (b) inline unused-parameter doubles (`MockAdNetworkAdapter` in spec files) MUST be extracted to dedicated `DummyXxx` files; (c) Stub+Spy hybrids (`MockDebugSectionsRepository`, `MockLoadAdRepository`) MUST be renamed to `MockXxx` (retained as project convention for hybrids) with clear documentation of the Stub and Spy properties; (d) all test specs that reference renamed doubles MUST be updated; (e) test file organization MUST be reviewed and improved where needed (e.g., extracting inline helpers to `Tests/Shared/`). All existing tests MUST continue to pass after refactoring.
- **FR-014**: The Unit Test playbook MUST include a test double decision tree that guides AI agents to select the correct type based on: "Is the dependency called?" → "Do I need return values?" → "Do I need call recording?" → "Do I need behavior verification?" → "Do I need working logic?"
- **FR-015**: Each YAML test case definition MUST specify which test double type is used for each dependency, using the canonical names (dummy, stub, spy, mock, fake), enabling AI agents to generate correctly-typed test code from the YAML definition.
- **FR-015a**: The existing `ctx-testing-001-test-doubles.md` MUST be superseded by the new Unit Test playbook. Useful content (StubFactory generation patterns, directory structure conventions) MUST be merged into the new playbook. The old document MUST be archived (moved to `.context/archive/`) to prevent AI agents from loading conflicting 3-layer vs 5-type definitions.

**Playbooks**

- **FR-016**: AI-readable playbooks MUST exist for 8 domains: (a) Swift best practices (Swift 5.0, iOS 15+), (b) UIKit best practices (views, view controllers, navigation, lifecycle), (c) Unit Test with Quick/Nimble (test doubles, assertions, async patterns), (d) BDD best practices (describe/context/it, Given-When-Then, shared examples), (e) Bugfix regression workflow, (f) MVVM-Repo pattern with UIKit, (g) Script best practices (config-driven development, Bash vs Python language selection, POSIX compliance on macOS), (h) Code comment best practices (Swift DocC `///`, inline comments, MARK organization, TODO/FIXME conventions).
- **FR-017**: Each playbook MUST include decision trees for common ambiguous choices (e.g., "where does this code belong?", "which test double type to use?", "when to use describe vs context?").
- **FR-018**: Playbooks MUST use concrete anti-pattern examples ("Do X, not Y") with code snippets showing both correct and incorrect approaches.
- **FR-019**: Playbooks MUST reference real file paths in the codebase (e.g., `Sources/Core/MSPCore/BidLoader.swift:42`) rather than embedding inline code snippets that can go stale.
- **FR-019a**: Every playbook MUST include a dedicated "AI Common Mistakes" section listing at least 3 specific anti-patterns that AI agents frequently produce in that domain, each with a concrete wrong→right code example. These anti-patterns MUST be validated against real AI agent output patterns from industry research.
- **FR-019b**: The Script Best Practices playbook MUST include: (a) a Bash vs Python decision tree (when to use which language), (b) config-driven development patterns (YAML config → script logic → deterministic output), (c) macOS vs Linux portability gotchas (BSD vs GNU sed/grep/date), (d) POSIX compliance guidelines, (e) Python subprocess management patterns.

**Multi-Agent Support**

- **FR-020**: Playbooks MUST be stored in `.context/tech/` as context entries, indexed by `.context/index.json`, accessible to all three agents (Claude Code, Codex, Cursor) via the existing progressive loading discovery mechanism.
- **FR-021**: Agent-specific configuration files MUST reference the shared content rather than duplicating it.
- **FR-022**: A sync validation MUST detect when agent configurations reference stale or missing shared content.

**Bugfix Regression**

- **FR-023**: The bugfix workflow MUST mandate: (1) reproduce the bug, (2) add a YAML regression test case with `regression_for` field, (3) write the failing Swift test (red), (4) fix the code (green), (5) commit YAML test case + Swift test + fix together.
- **FR-024**: A regression coverage report MUST be generatable showing which bugfix branches have corresponding regression test cases and which do not.

### Key Entities

- **Context Entry**: A single knowledge document stored in `.context/`. Has: path, title, domain (release, ci, integration, testing, etc.), layer (business, experience, tech), tags, summary, and full content.
- **Context Index**: An auto-generated machine-readable catalog of all context entries. Has: version, generation timestamp, list of entry metadata (path, title, domain, tags, summary).
- **Test Case Definition**: A YAML-defined specification of what should be tested. Has: unique ID (`[PREFIX###]`), type (unit or behavior), Given/When/Then structure, priority, tags, optional `regression_for` field, test double specifications per dependency, and implementation tracking (file path, test name, status).
- **Test Double**: A test-time substitute for a production dependency. Classified per Meszaros taxonomy into exactly 5 types: Dummy (unused filler), Stub (preset returns), Spy (call recorder), Mock (behavior verifier), Fake (working shortcut). Each test double file is named with its type prefix (`DummyXxx`, `StubXxx`, `SpyXxx`, `MockXxx`, `FakeXxx`).
- **Mock Data**: JSON response snapshots from real API responses, organized by module and scenario. Stored in `packages/mock-data/{Module}/{scenario}.json`. Used by StubFactory generators to provide typed test data.
- **Playbook**: An AI-readable operating manual for a specific development workflow. Has: title, domain, triggers (keywords that cause an agent to load it), decision trees, anti-pattern examples, file-pointer references. The project maintains 8 core playbooks.
- **Package**: A centralized resource directory within `packages/`. Has: schema definition, auto-generated index, domain-organized content files, validation tooling.

## Clarifications

### Session 2026-02-22

- Q: Should playbooks include AI-specific anti-patterns? → A: Yes — all playbooks are AI-first and MUST include a dedicated "AI Common Mistakes" section with concrete wrong→right examples (e.g., force unwrap outside unit tests, missing `[weak self]`, `os.system()` in Python).
- Q: What is the scope of unit test refactoring? → A: No compromise — rename, rewrite, and refactor everything that needs it. Not just naming changes but full restructuring where necessary. All existing tests must pass after refactoring.
- Q: Should there be a Script Best Practices playbook? → A: Yes — 7th playbook covering config-driven development, Bash vs Python language selection criteria, POSIX compliance, macOS portability. Researched against industry best practices (Google Shell Style Guide, GitLab Scripting Standards, etc.).
- Q: Where should playbooks physically live? → A: In `.context/tech/` (e.g., `.context/tech/swift-best-practices.md`), reusing the existing `.context/index.json` indexing and keyword discovery mechanism. This aligns with the Level 1 progressive loading architecture.
- Q: How do new playbooks relate to existing AGENTS-SOURCES.md / AGENTS-SCRIPTS.md? → A: AGENTS files slim down to ~20-line loading guides (which playbooks to load for this directory), deep content migrates to `.context/tech/` playbooks. Single Source of Truth principle — no duplication.
- Q: What happens to existing `ctx-testing-001-test-doubles.md`? → A: Replace — merge useful content (StubFactory patterns, directory structure) into the new Unit Test playbook with Meszaros 5-type definitions. Archive the old document to prevent AI from loading conflicting definitions.

### Session 2026-02-23

- Q: "Comment best practices" playbook 的范围是什么？ → A: Code comments only — Swift 代码中的内联注释、文档注释（DocC `///`）、MARK 标记、TODO/FIXME 规范。不包括 commit messages、PR descriptions、code review comments。

## Assumptions

- **Swift 5.0 and iOS 15+**: All playbooks and patterns are written for Swift 5.0 with UIKit (not SwiftUI), targeting iOS 15.0+. This differs from the echo-of-family reference project which uses Swift 5.9+ and iOS 16+. Playbooks must explicitly call out patterns that are unavailable in our target versions (e.g., no `@Observable` macro, no SwiftUI native navigation).
- **iOS-only scope**: Unlike the tri-platform echo-of-family project, MSP iOS SDK is a single-platform project. Test case YAML files do not need tri-platform implementation tracking — they track only Swift/iOS implementations.
- **CocoaPods**: The project uses CocoaPods (not SPM) for dependency management. The `packages/` directory is for shared configuration/definition resources, not Swift Package Manager packages.
- **Existing test framework**: Quick ~> 7.0 and Nimble ~> 13.0 are the established test frameworks. Playbooks assume these specific versions.
- **YAML over JSON for test cases**: YAML is chosen over JSON for test case definitions based on industry best practices — inline comments are critical for documenting regression history and business rule context. The existing JSON schema is preserved semantically; only the file format changes.
- **Packages scope**: Two packages are created: `packages/test-cases/` (YAML test definitions) and `packages/mock-data/` (JSON stub/fixture data consolidated from `Tests/Fixtures/`). Additional packages are deferred to future iterations.
- **Test doubles taxonomy**: The project adopts the Meszaros/Fowler canonical taxonomy (Dummy, Stub, Spy, Mock, Fake) as the industry standard. The current `MockXxx` naming for Stub+Spy hybrids is retained as a project convention but explicitly documented. Value-type conformances (`MockDebugSection`, `MockDebugOption`) are renamed to `FakeXxx`. Hand-rolled test doubles are preferred over mocking frameworks (no OCMock, Mockingbird, Cuckoo) — Swift's protocol-oriented design makes hand-rolled doubles type-safe, refactoring-friendly, and more readable.
- **Agent-specific progressive loading capabilities**: Claude Code supports native progressive loading via rules, skills, and directory-triggered imports. Codex simulates this through condensed instruction files. Cursor supports it through `.cursor/rules/` with glob-based file matching. Each agent's mechanism differs but the content delivered is semantically identical.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: AI agents load under 60 lines of always-loaded context at project open, with additional context loaded only when the task requires it — verified by token audit of agent startup.
- **SC-002**: 100% of existing test cases (all IDs from DebugAdLoad and DebugRadioCell) are present in the new YAML format with zero data loss after migration.
- **SC-003**: The validation tool catches 100% of test case definition-implementation mismatches (orphaned tests, unimplemented definitions, duplicate IDs) within a single validation run.
- **SC-004**: An AI agent given a "implement new ViewModel" task produces code that passes constitutional review (Article III.1: no third-party imports in Core, Article IV: protocol-oriented design) on the first attempt when playbooks are available.
- **SC-005**: All three AI agents (Claude Code, Codex, Cursor) produce architecturally consistent code when given the same task, as verified by peer review of outputs.
- **SC-006**: New bugfix branches include a YAML regression test case definition in 100% of cases where the bugfix workflow is followed.
- **SC-007**: Context index reflects the true state of all context entries at all times — verified by running the index generation script and confirming no diff with the committed index.
- **SC-008**: 100% of existing test doubles are renamed to match their actual Meszaros type (FakeDebugSection, FakeDebugOption, DummyAdNetworkAdapter, etc.), and all existing tests pass after renaming.
- **SC-009**: An AI agent writing a new test selects the correct test double type (per the decision tree in the Unit Test playbook) in 90%+ of cases, as verified by human review of generated test code.
- **SC-010**: All JSON fixture data from `Tests/Fixtures/` is consolidated into `packages/mock-data/` with zero data loss and all existing tests continue to pass.
- **SC-011**: An AI agent writing a Bash script produces code that passes ShellCheck validation with zero warnings on the first attempt when the Script playbook is loaded.
- **SC-012**: Every playbook contains at least 3 documented AI anti-patterns with wrong→right code examples, validated against real AI agent output patterns.
