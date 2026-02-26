# Implementation Plan: AI Infrastructure v2

**Branch**: `ai-infra-v2` | **Date**: 2026-02-22 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/ai-infra-v2/spec.md`

## Summary

Comprehensive refactoring of the AI infrastructure layer to implement true 3-tier progressive context loading, centralize test case management in YAML, create 7 AI-first playbooks, establish a `packages/` resource hub, and ensure multi-agent consistency across Claude Code, Codex, and Cursor. This is a documentation/configuration refactoring — no production Swift code is compiled, but test double Swift files are refactored.

## Technical Context

**Language/Version**: Markdown, YAML, Bash (POSIX-compliant), Python 3.x, Swift 5.0 (test doubles refactoring only)
**Primary Dependencies**: `yq` (YAML processor), `shellcheck` (shell linting), `black` (Python formatting), Quick ~> 7.0, Nimble ~> 13.0
**Storage**: File-based (Markdown, YAML, JSON context entries)
**Testing**: Python validation scripts (test-cases.py), `shellcheck`, `round-trip-test.sh` (for test double refactoring)
**Target Platform**: macOS (development), AI agent runtimes (Claude Code, Codex CLI, Cursor IDE)
**Project Type**: Single iOS SDK project with multi-agent AI infrastructure overlay
**Performance Goals**: Always-loaded context < 60 lines per agent entry point; playbook load-on-demand via keyword matching
**Constraints**: Swift 5.0 (no async/await), iOS 15.0+, UIKit (no SwiftUI), CocoaPods (no SPM)
**Scale/Scope**: 7 playbooks, 2 packages, ~20 test case YAML files, 3 agent entry points, ~10 test double files to refactor

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Design Gate (All Articles)

| Article | Status | Assessment |
|---------|--------|------------|
| **I.1 (Automation First)** | ✅ PASS | All migration (JSON→YAML), index generation, and validation are scripted. No manual steps. |
| **I.2 (Deterministic Builds)** | ✅ N/A | No `.xcodeproj` changes. Test double file renames are source-level only; XcodeGen auto-discovers. |
| **I.3 (SSOT)** | ✅ PASS | Playbooks in `.context/tech/` become SSOT for deep content. AGENTS files become thin loading guides. `packages/test-cases/` becomes SSOT for test definitions. |
| **I.4 (No Manual Workarounds)** | ✅ PASS | No temporary workarounds; all processes are scripted end-to-end. |
| **II.1 (Validation Loop)** | ✅ PASS | YAML validation tool (FR-008), index integrity check (FR-003), shellcheck for new scripts. |
| **II.2 (Local Verification)** | ⚠️ CONDITIONAL | `round-trip-test.sh` required only for test double refactoring phase (Swift changes). Not required for Markdown/YAML changes. |
| **III.1 (Module Cohesion)** | ✅ N/A | No Core module code changes. Test double refactoring stays within `Tests/`. |
| **III.2 (Protocol-Oriented)** | ✅ PASS | Refactored test doubles preserve protocol-based DI patterns. |
| **IV.1-4 (Swift Practices)** | ⚠️ APPLICABLE | Applies only to test double refactoring. No force unwraps, proper error handling, value-type preferences enforced. |
| **IV.6 (XcodeGen)** | ✅ N/A | File renames in `Tests/` are auto-discovered by XcodeGen globs. No template changes needed. |
| **V.1 (TDD Cycle)** | ✅ PASS | Test double refactoring follows red-green-refactor: existing tests must pass throughout. |
| **V.2 (Quick & Nimble)** | ✅ PASS | All test specs continue to use Quick & Nimble. |
| **VI.1 (Error Handling)** | ✅ PASS | All new scripts use `set -euo pipefail`. |
| **VI.2 (Idempotency)** | ✅ PASS | Migration scripts are idempotent (check-before-create pattern). |
| **VI.3 (POSIX)** | ✅ PASS | New shell scripts are POSIX-compliant. |
| **VI.4 (Canonical Artifacts)** | ✅ N/A | No XCFramework or build artifact changes. |
| **VIII.1 (BDD Style)** | ✅ PASS | Refactored tests preserve `describe`/`context`/`it` structure. |
| **VIII.2 (Clear Assertions)** | ✅ PASS | Nimble matchers preserved in refactored tests. |
| **VIII.3 (No Magic Values)** | ✅ PASS | `TestDataFactory` and `TestConstants` preserved/enhanced. |
| **X.1 (Three-Tier Loading)** | ✅ PRIMARY | This feature directly implements the three-tier loading model. |
| **X.2 (Index Integrity)** | ✅ PASS | Auto-generated `index.json` with atomic update on any entry change. |
| **X.3 (Minimal Token Footprint)** | ✅ PASS | Metadata-first design; agents read index before loading full content. |

**Gate Result**: ✅ PASS — No violations. Proceed to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/ai-infra-v2/
├── plan.md              # This file
├── spec.md              # Feature specification (complete)
├── research.md          # Phase 0: Research findings
├── data-model.md        # Phase 1: Entity & schema definitions
├── quickstart.md        # Phase 1: Implementation quickstart guide
├── contracts/           # Phase 1: YAML schemas, index.json schema
│   ├── test-case-schema.yaml
│   └── context-index-schema.json
├── checklists/
│   └── requirements.md  # Quality checklist (complete)
└── tasks.md             # Phase 2: Task breakdown (generated by /speckit.tasks)
```

### Source Code (repository root)

```text
# === TIER 0: ALWAYS-LOADED (< 60 lines each) ===
.claude/CLAUDE.md                    # REWRITE: slim to <60 lines, pointers only
.codex/CODEX.md                      # UPDATE: align with new loading model
.cursor/CURSOR.md                    # UPDATE: align with new loading model
constitution.md                      # UNCHANGED (Federal Constitution)

# === TIER 1: DIRECTORY-TRIGGERED (loaded per-directory) ===
Sources/constitution.md              # UNCHANGED (State Constitution)
Scripts/constitution.md              # UNCHANGED (State Constitution)
Tests/constitution.md                # UNCHANGED (State Constitution)
AGENTS.md                            # REWRITE: slim to ~60 lines, remove deep content
Sources/AGENTS-SOURCES.md            # REWRITE: slim to ~20 lines loading guide
Scripts/AGENTS-SCRIPTS.md            # REWRITE: slim to ~20 lines loading guide

# === TIER 2: ON-DEMAND (loaded via index keyword matching) ===
.context/index.json                  # NEW: machine-readable context index (replaces index.md)
.context/index.md                    # ARCHIVE: replaced by index.json
.context/testing/tech/ctx-testing-001-test-doubles.md  # ARCHIVE → .context/archive/

# --- New Playbooks (7) ---
.context/sources/tech/ctx-sources-001-swift-best-practices.md
.context/sources/tech/ctx-sources-002-uikit-best-practices.md
.context/testing/tech/ctx-testing-001-unit-test-quick-nimble.md
.context/testing/tech/ctx-testing-002-bdd-best-practices.md
.context/testing/tech/ctx-testing-003-bugfix-regression.md
.context/sources/tech/ctx-sources-003-mvvm-repo.md
.context/sources/tech/ctx-sources-004-script-best-practices.md

# === PACKAGES ===
packages/
├── test-cases/                      # NEW: YAML test case definitions
│   ├── _schema.yaml                 # YAML schema definition
│   ├── _prefixes.yaml               # Prefix registry (migrated from JSON)
│   ├── _template.yaml               # Template for new modules
│   ├── debug/
│   │   ├── DebugAdLoad.yaml         # Migrated from Tests/TestCases/DebugAdLoad.json
│   │   └── DebugRadioCell.yaml      # Migrated from Tests/TestCases/DebugRadioCell.json
│   └── README.md                    # Usage guide
│
└── mock-data/                       # NEW: Consolidated test fixtures
    ├── README.md                    # Usage guide with naming conventions
    ├── debug/
    │   ├── bid_response_success.json
    │   ├── bid_response_error.json
    │   └── ad_config.json
    └── _schema.md                   # Naming conventions doc

# === TEST DOUBLES REFACTORING ===
Tests/MSPCoreTests/Mocks/Debug/
├── FakeDebugSection.swift           # RENAME from MockDebugSection (value-type Fake)
├── FakeDebugOption.swift            # RENAME from MockDebugOption (value-type Fake)
├── MockDebugSectionsRepository.swift # KEEP name (Stub+Spy hybrid, documented)
├── MockLoadAdRepository.swift       # KEEP name (Stub+Spy hybrid, documented)
├── MockPlacementsRepository.swift   # KEEP name (Stub+Spy hybrid, documented)
├── TestDataFactory.swift            # UNCHANGED (factory, not a test double)
└── TestConstants.swift              # UNCHANGED

Tests/Shared/                        # EXISTING: shared test helpers
├── TestHelpers.swift                # UNCHANGED
├── NetworkStubs.swift               # REVIEW: verify Meszaros naming
├── FixtureLoader.swift              # UNCHANGED
└── AsyncHelpers.swift               # UNCHANGED

# === VALIDATION TOOLING ===
Scripts/tools/
├── test-cases.py                    # UPDATE: support YAML, new packages/ paths
├── generate-context-index.py        # NEW: auto-generate .context/index.json
└── validate-agent-sync.sh           # NEW: verify agent configs reference valid content

# === ARCHIVE ===
Tests/TestCases/.archive/            # ARCHIVE: JSON originals kept as reference
Tests/Fixtures/                      # ARCHIVE: moved to packages/mock-data/
.context/archive/
├── ctx-testing-001-test-doubles.md  # ARCHIVED: superseded by ctx-testing-001
└── index.md                         # ARCHIVED: replaced by .context/index.json
```

**Structure Decision**: This is a documentation/configuration refactoring layered over an existing iOS SDK project. No new directories are created at the top level except `packages/`. The context system (`.context/`) is expanded with 7 new playbooks. Agent entry points are rewritten to be thin loading guides. Test infrastructure is reorganized under `packages/` with YAML-first workflow.

## Complexity Tracking

No constitutional violations requiring justification. All changes align with existing articles, particularly Article X (Progressive Loading) which this feature directly implements.

---

## Phase 0: Research

### Research Tasks

Research was conducted in parallel on the following topics. Findings are consolidated in [research.md](./research.md).

| # | Topic | Status | Decision |
|---|-------|--------|----------|
| R1 | YAML test case schema design | ✅ Complete | YAML with JSON Schema validation via `jsonschema` (Python); support dual-type (unit+behavior) |
| R2 | JSON→YAML migration strategy | ✅ Complete | Python script with `json`→`yaml` conversion, preserving all IDs and metadata |
| R3 | Machine-readable context index format | ✅ Complete | `index.json` with entry metadata; auto-generated from Markdown frontmatter |
| R4 | Progressive loading patterns for AI agents | ✅ Complete | Keyword-matching against index tags; Claude rules/, Codex instructions.md, Cursor rules.json |
| R5 | Meszaros test doubles taxonomy (Swift/Quick/Nimble) | ✅ Complete (prior session) | 5 types: Dummy, Stub, Spy, Mock, Fake; hand-rolled preferred over frameworks |
| R6 | Script best practices (Bash vs Python, config-driven) | ✅ Complete (prior session) | Google Shell Style Guide ~100 line threshold; `yq` for YAML in Bash, `subprocess.run()` in Python |
| R7 | AI-first playbook design patterns | ✅ Complete (prior session) | Decision trees, wrong→right examples, file-pointer references, anti-pattern sections |

---

## Phase 1: Design & Contracts

### 1.1 Data Model

See [data-model.md](./data-model.md) for full entity definitions.

**Core Entities**:

1. **ContextEntry** — A single knowledge document in `.context/`
   - Fields: path, title, domain, layer, tags[], summary, triggers[], version, status
   - Relationships: indexed by ContextIndex, referenced by playbook pointers

2. **ContextIndex** — Machine-readable catalog at `.context/index.json`
   - Fields: version, generated_at, entries[] (ContextEntry metadata)
   - Invariant: Must always reflect true filesystem state (Article X.2)

3. **TestCaseDefinition** — YAML test specification in `packages/test-cases/`
   - Fields: id, type (unit|behavior), description, given/when/then (behavior), class/method (unit), priority, tags[], regression_for?, doubles{}
   - Relationships: maps 1:1 to Swift test implementation via ID marker

4. **TestDouble** — Test-time dependency substitute
   - Types: Dummy, Stub, Spy, Mock, Fake (Meszaros taxonomy)
   - Naming: `{Type}{DependencyName}` (e.g., `FakeDebugSection`, `MockLoadAdRepository`)

5. **MockDataFixture** — JSON response snapshot in `packages/mock-data/`
   - Fields: path, module, scenario, format (JSON)
   - Naming: `{module}/{scenario}.json`

6. **Playbook** — AI-readable operating manual in `.context/{domain}/tech/`
   - Fields: title, domain, triggers[], sections (decision-trees, anti-patterns, examples, file-refs)
   - 7 instances defined in spec

### 1.2 Contracts

See [contracts/](./contracts/) directory.

**Contract 1: Test Case YAML Schema** (`contracts/test-case-schema.yaml`)
- Defines the YAML structure for test case definition files
- Supports both `unit` and `behavior` types
- Validates `regression_for`, `doubles`, `priority`, `tags` fields

**Contract 2: Context Index JSON Schema** (`contracts/context-index-schema.json`)
- Defines the structure of `.context/index.json`
- Validates entry metadata fields: path, title, domain, layer, tags, summary, triggers

### 1.3 Quickstart

See [quickstart.md](./quickstart.md) for implementation quickstart guide.

---

## Post-Design Constitution Re-Check

| Article | Re-Check | Notes |
|---------|----------|-------|
| X.1 (Three-Tier) | ✅ CONFIRMED | Design implements exactly 3 tiers with clear boundaries |
| X.2 (Index Integrity) | ✅ CONFIRMED | `generate-context-index.py` auto-generates index.json from frontmatter |
| X.3 (Minimal Token) | ✅ CONFIRMED | index.json exposes metadata only; agents load full content on demand |
| I.3 (SSOT) | ✅ CONFIRMED | No content duplication: AGENTS → loading guides, playbooks → SSOT |
| V.1 (TDD) | ✅ CONFIRMED | Test double refactoring maintains all existing tests passing |
| VIII (Test Readability) | ✅ CONFIRMED | BDD structure preserved in all refactored tests |

**Final Gate Result**: ✅ PASS — Design is constitutionally compliant. Ready for Phase 2 task generation.
