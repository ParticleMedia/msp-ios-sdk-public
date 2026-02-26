# Tasks: AI Infrastructure v2

**Input**: Design documents from `specs/ai-infra-v2/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Test double refactoring requires existing Swift tests to pass after each rename. YAML validation tooling is tested via script execution. No new unit tests are created in this feature.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create directory structure and verify tooling prerequisites

- [x] T001 Create `packages/test-cases/debug/` and `packages/mock-data/debug/` directory structure
- [x] T002 Create `.context/archive/` directory for archived context entries
- [x] T003 [P] Verify `yq` is installed (`brew install yq`) for YAML processing in shell scripts
- [x] T004 [P] Verify `pyyaml` and `jsonschema` Python packages are available (`pip install pyyaml jsonschema`)
- [x] T005 [P] Copy `specs/ai-infra-v2/contracts/test-case-schema.yaml` to `packages/test-cases/_schema.yaml`
- [x] T006 [P] Copy `specs/ai-infra-v2/contracts/context-index-schema.json` to `.context/index.schema.json`

**Checkpoint**: All directories exist, tooling verified, schemas in place.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Context index infrastructure that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T007 Add YAML frontmatter (id, title, domain, layer, tags, triggers, summary, version, status, created, updated) to `.context/release/experience/ctx-release-001.md`
- [x] T008 [P] Add YAML frontmatter to `.context/release/experience/ctx-release-002.md`
- [x] T009 [P] Add YAML frontmatter to `.context/release/experience/ctx-release-003.md`
- [x] T010 [P] Add YAML frontmatter to `.context/ci/experience/ctx-ci-001-artifact-structure-loss.md`
- [x] T011 [P] Add YAML frontmatter to `.context/ci/experience/ctx-ci-002-matrix-artifact-conflict.md`
- [x] T012 [P] Add YAML frontmatter to `.context/ci/experience/ctx-ci-003-duplicate-build-abi-conflict.md`
- [x] T013 [P] Add YAML frontmatter to `.context/ci/experience/ctx-ci-004-preinstall-source-dependency.md`
- [x] T014 [P] Add YAML frontmatter to `.context/integration/experience/ctx-integration-001-novacore-duplicate-symbols.md`
- [x] T015 [P] Add YAML frontmatter to `.context/integration/experience/ctx-integration-002-facebook-adapter-flat-namespace-crash.md`
- [x] T016 [P] Add YAML frontmatter to `.context/testing/tech/ctx-testing-001-test-doubles.md`
- [x] T017 Create `Scripts/tools/generate-context-index.py` — Python script that parses all `.context/{domain}/{layer}/ctx-*.md` YAML frontmatter and generates `.context/index.json` per schema at `.context/index.schema.json`. Must use atomic write (tempfile + mv). Must validate output against schema.
- [x] T018 Run `python Scripts/tools/generate-context-index.py` and verify `.context/index.json` is generated with 10 entries matching all frontmatter-annotated files

**Checkpoint**: Foundation ready — `.context/index.json` exists with all 10 entries. User story implementation can begin.

---

## Phase 3: User Story 1 — Progressive Context Loading (Priority: P1) 🎯 MVP

**Goal**: AI agents load < 60 lines at startup; additional context loads on-demand via keyword matching against `index.json`.

**Independent Test**: Open project with Claude Code, perform a task in `Sources/`, verify only relevant context was loaded (no Scripts/Tests context consumed). Entry point file is < 60 lines.

### Implementation for User Story 1

- [x] T019 [US1] Rewrite `.claude/CLAUDE.md` to < 60 lines — keep only: role definition, constitution import, directory-triggered loading pointers (Sources/ → AGENTS-SOURCES.md, Scripts/ → AGENTS-SCRIPTS.md), on-demand context via `.context/index.json`, skills reference. Remove all deep content, examples, technical context imports. See quickstart.md WS1 Step 3 for target structure.
- [x] T020 [US1] Rewrite `AGENTS.md` to ~60 lines — keep only: project technical context (Swift 5.0, iOS 15+, Quick/Nimble), pre-task checklist, branching/commit conventions, shared resources locations, read-only zones, context system keyword mapping. Remove: all Active Technologies history, recent changes log, deep configuration workflow, domain-specific content (migrated to playbooks).
- [x] T021 [P] [US1] Rewrite `Sources/AGENTS-SOURCES.md` to ~20-line loading guide — list which playbook IDs to load from `.context/index.json` for Sources/ directory (ctx-sources-001, ctx-sources-002, ctx-sources-003, ctx-testing-001, ctx-testing-002). Remove all deep content (MVVM-Repo pattern, testing strategy, API design, performance guidelines — all migrated to playbooks in Phase 6).
- [x] T022 [P] [US1] Rewrite `Scripts/AGENTS-SCRIPTS.md` to ~20-line loading guide — list which playbook IDs to load for Scripts/ directory (ctx-sources-004). Remove all deep content (config-driven dev, error handling, idempotency patterns — all migrated to playbook in Phase 6).
- [x] T023 [P] [US1] Update `.claude/rules/context-system.md` to reference `.context/index.json` instead of `Scripts/context/search-context.sh` for keyword-to-document discovery
- [x] T024 [P] [US1] Update `.codex/CODEX.md` to reference `.context/index.json` for on-demand context discovery and align with new 3-tier loading model (< 60 lines)
- [x] T025 [P] [US1] Update `.cursor/CURSOR.md` to reference `.context/index.json` for on-demand context discovery and align with new 3-tier loading model (< 60 lines)
- [x] T026 [US1] Archive `.context/index.md` → `.context/archive/index.md` (replaced by `.context/index.json` per Article X.2 SSOT). Add redirect note in archived file pointing to `index.json`.
- [x] T026a [US1] Verify all agent entry points: run `wc -l` on CLAUDE.md, CODEX.md, CURSOR.md (all < 60), AGENTS-SOURCES.md (~20), AGENTS-SCRIPTS.md (~20), AGENTS.md (~60). Verify `.context/index.json` is referenced in all three agent configs.

**Checkpoint**: Progressive loading architecture is live. All agent entry points are thin loading guides. `index.json` is the discovery mechanism.

---

## Phase 4: User Story 2 — Centralized Test Case Management via YAML (Priority: P1)

**Goal**: All test cases defined in YAML in `packages/test-cases/`, with validation tooling, YAML-first workflow, and Meszaros test double specifications.

**Independent Test**: Define a new test case in YAML, run validation (should flag "defined but not implemented"), then write Swift test and re-run validation (should pass).

### Implementation for User Story 2 — YAML Migration

- [x] T027 [US2] Create `packages/test-cases/_prefixes.yaml` — migrate from `Tests/TestCases/_prefixes.json`, preserving DAL=DebugAdLoad, DRC=DebugRadioCell registrations in YAML format
- [x] T028 [P] [US2] Create `packages/test-cases/_template.yaml` — YAML template for new test case modules per data-model.md TestCaseDefinition schema, including doubles field template and regression_for field
- [x] T029 [P] [US2] Create `packages/test-cases/README.md` — usage guide documenting YAML-first workflow (define YAML → validate → implement Swift → sync check), ID format, naming conventions, schema reference
- [x] T030 [US2] Create `Scripts/tools/migrate-test-cases.py` — Python script that reads `Tests/TestCases/*.json`, transforms to YAML format per `packages/test-cases/_schema.yaml`, adds comments/doubles/regression_for templates, writes to `packages/test-cases/debug/{Module}.yaml`. Must preserve all IDs and metadata with zero data loss.
- [x] T031 [US2] Run `python Scripts/tools/migrate-test-cases.py` to migrate `Tests/TestCases/DebugAdLoad.json` → `packages/test-cases/debug/DebugAdLoad.yaml` (15 cases, DAL001-DAL015)
- [x] T032 [US2] Run migration for `Tests/TestCases/DebugRadioCell.json` → `packages/test-cases/debug/DebugRadioCell.yaml` and verify all DRC-prefixed cases migrated
- [x] T033 [US2] Update `Scripts/tools/test-cases.py` to support YAML: (a) read `.yaml` files from `packages/test-cases/` instead of JSON from `Tests/TestCases/`, (b) add `pyyaml` import, (c) update `validate` command for YAML schema validation using `jsonschema`, (d) update `sync` command for new paths, (e) add `regression-report` command that lists bugfix branches with/without regression test cases
- [x] T034 [US2] Run `python Scripts/tools/test-cases.py validate` against migrated YAML files and verify zero errors
- [x] T035 [US2] Run `python Scripts/tools/test-cases.py sync` and verify all YAML-defined IDs match Swift test implementations

### Implementation for User Story 2 — Test Doubles Refactoring [NO COMPROMISE]

- [x] T036 [US2] Rename `Tests/MSPCoreTests/Mocks/Debug/MockDebugSection.swift` → `FakeDebugSection.swift` — restructure as proper Fake (value-type conformance with working implementation). Update all references in `Tests/MSPCoreTests/Specs/Debug/DebugAdLoadSectionViewModelSpec.swift` and `DebugAdLoadViewModelSpec.swift`. Run tests to verify passing.
- [x] T037 [US2] Rename `Tests/MSPCoreTests/Mocks/Debug/MockDebugOption.swift` → `FakeDebugOption.swift` — restructure as proper Fake. Update all spec file references. Run tests to verify passing.
- [x] T038 [US2] Add Meszaros taxonomy documentation header comments to `Tests/MSPCoreTests/Mocks/Debug/MockDebugSectionsRepository.swift` — document as Mock (Stub+Spy hybrid): which methods are stubbed (preset returns) and which record calls (spy behavior).
- [x] T039 [P] [US2] Add Meszaros taxonomy documentation header comments to `Tests/MSPCoreTests/Mocks/Debug/MockLoadAdRepository.swift` — document as Mock (Stub+Spy hybrid)
- [x] T040 [P] [US2] Add Meszaros taxonomy documentation header comments to `Tests/MSPCoreTests/Mocks/Debug/MockPlacementsRepository.swift` — document as Mock (Stub+Spy hybrid)
- [x] T041 [US2] Extract inline `MockAdNetworkAdapter` from `Tests/MSPCoreTests/Specs/Debug/DebugAdLoadViewModelSpec.swift` (line 340, private class) and any other spec files with inline test doubles into dedicated `Tests/Shared/DummyAdNetworkAdapter.swift`. Update all spec file references.
- [x] T042 [US2] Update migrated YAML test cases in `packages/test-cases/debug/DebugAdLoad.yaml` to include `doubles` field for each case specifying Meszaros type (dummy/stub/spy/mock/fake) and class name per data-model.md TestDouble specification
- [x] T042a [US2] Update migrated YAML test cases in `packages/test-cases/debug/DebugRadioCell.yaml` to include `doubles` field for each case specifying Meszaros type (dummy/stub/spy/mock/fake) and class name per data-model.md TestDouble specification
- [x] T043 [US2] Run `./Scripts/target-switching/round-trip-test.sh` to verify all tests pass after complete test double refactoring

**Checkpoint**: All test cases in YAML, all test doubles follow Meszaros taxonomy, validation tooling works.

---

## Phase 5: User Story 4 — Packages Directory as Centralized Resource Hub (Priority: P2)

**Goal**: `packages/mock-data/` consolidates all JSON stub/fixture data from scattered test directories.

**Independent Test**: Verify `packages/mock-data/` contains all fixture files, `FixtureLoader.swift` reads from new paths, and all tests pass.

### Implementation for User Story 4

- [x] T044 [US4] Move `Tests/Fixtures/bid_response_success.json` → `packages/mock-data/debug/bid_response_success.json`
- [x] T045 [P] [US4] Move `Tests/Fixtures/bid_response_error.json` → `packages/mock-data/debug/bid_response_error.json`
- [x] T046 [P] [US4] Move `Tests/Fixtures/ad_config.json` → `packages/mock-data/debug/ad_config.json`
- [x] T047 [US4] Update `Tests/Shared/FixtureLoader.swift` to load fixtures from `packages/mock-data/` instead of `Tests/Fixtures/`. Use relative path from project root.
- [x] T049 [P] [US4] Create `packages/mock-data/README.md` — document naming convention `{module}/{scenario}.json`, list all fixture files, explain how to add new fixtures
- [x] T050 [US4] Run all tests to verify fixture loading from new paths works correctly
- [x] T051 [US4] Archive original directories: move `Tests/TestCases/` to `Tests/TestCases/.archive/` (keep JSON originals as reference), verify `Tests/Fixtures/` is empty

**Checkpoint**: `packages/` directory is fully populated. Mock data consolidated. All tests pass.

---

## Phase 6: User Story 3 — AI-First Playbooks (Priority: P2)

**Goal**: 7 AI-first playbooks written in `.context/{domain}/tech/`, each with decision trees, anti-patterns, AI Common Mistakes section (≥3 items), and file-pointer references.

**Independent Test**: Have an AI agent implement a new ViewModel using only playbooks for guidance. Output should follow MVVM-Repo pattern, use correct test doubles, and comply with constitutional articles.

### Implementation for User Story 3

- [x] T052 [US3] Write `.context/sources/tech/ctx-sources-001-swift-best-practices.md` — Swift 5.0, iOS 15+ language rules. Include: value-types, immutability, error handling, Logger API, Combine patterns. AI Common Mistakes: force unwrap outside tests, implicit self capture, using Any instead of generics, missing [weak self] in Combine sinks. Include frontmatter per ContextEntry schema.
- [x] T053 [US3] Write `.context/sources/tech/ctx-sources-002-uikit-best-practices.md` — UIKit views, view controllers, AutoLayout, lifecycle, navigation. AI Common Mistakes: layout in init instead of viewDidLoad, missing translatesAutoresizingMaskIntoConstraints=false, force-casting UITableViewCell, delegate retain cycles. Include frontmatter.
- [x] T054 [US3] Write `.context/testing/tech/ctx-testing-001-unit-test-quick-nimble.md` — Quick/Nimble testing patterns, Meszaros 5-type test double taxonomy with decision tree, assertion patterns, async testing with Combine. AI Common Mistakes: force unwrap in production code "for tests", wrong double type, no Combine subscription cleanup. Include frontmatter. MUST supersede ctx-testing-001 content.
- [x] T055 [US3] Write `.context/testing/tech/ctx-testing-002-bdd-best-practices.md` — describe/context/it nesting, Given-When-Then, shared examples, test naming. AI Common Mistakes: flat test structure, testing implementation details, multiple assertions without purpose. Include frontmatter.
- [x] T056 [US3] Write `.context/sources/tech/ctx-sources-003-mvvm-repo.md` — MVVM-Repository layer responsibilities, dependency injection, protocol-first design, decision trees for code placement. AI Common Mistakes: UIKit in ViewModel, business logic in View, singletons instead of DI, mixed Repository/DataSource. Include frontmatter. Content migrated from AGENTS-SOURCES.md.
- [x] T057 [US3] Write `.context/testing/tech/ctx-testing-003-bugfix-regression.md` — Mandated workflow: reproduce → YAML regression test case → TDD red/green/refactor → commit together. Include regression_for field usage, regression coverage report generation. Include frontmatter.
- [x] T058 [P] [US3] Write `.context/sources/tech/ctx-sources-004-script-best-practices.md` — Config-driven development, Bash vs Python decision tree, POSIX compliance on macOS, macOS vs Linux portability gotchas, Python subprocess management. AI Common Mistakes: disabling set -euo pipefail, parsing YAML with grep/sed, unquoted variables, os.system() instead of subprocess.run(), hardcoded paths, missing trap cleanup. Include frontmatter. Content migrated from AGENTS-SCRIPTS.md.
- [x] T059 [US3] Archive `.context/testing/tech/ctx-testing-001-test-doubles.md` → move to `.context/archive/ctx-testing-001-test-doubles.md`
- [x] T060 [US3] Run `python Scripts/tools/generate-context-index.py` to regenerate `.context/index.json` with all 7 new playbooks + 9 remaining active entries (16 total, excluding archived ctx-testing-001). Verify entry_count matches.

**Checkpoint**: All 7 playbooks exist with frontmatter, required sections, and ≥3 AI Common Mistakes each. Index reflects 16+ active entries.

---

## Phase 7: User Story 5 — Multi-Agent Consistency (Priority: P3)

**Goal**: Claude Code, Codex, and Cursor all reference the same shared playbooks and produce consistent output.

**Independent Test**: Give the same task to all three agents; verify all produce code following the same architectural patterns.

### Implementation for User Story 5

- [x] T061 [US5] Create `Scripts/tools/validate-agent-sync.sh` — POSIX-compliant shell script (set -euo pipefail) that checks: (a) all playbook IDs in AGENTS-SOURCES.md and AGENTS-SCRIPTS.md exist in `.context/index.json`, (b) CLAUDE.md/CODEX.md/CURSOR.md are each < 60 lines, (c) no content duplication between AGENTS files and playbooks (compare by keyword overlap), (d) all three agents reference `.context/index.json`.
- [x] T062 [P] [US5] Update `.codex/instructions.md` to include condensed loading guide referencing `.context/index.json` for playbook discovery, aligned with rewritten CODEX.md
- [x] T063 [P] [US5] Update `.cursor/settings/rules.json` to add glob-based rule triggers that load relevant playbooks when working in specific directories (e.g., `Sources/**/*.swift` triggers sources playbooks)
- [x] T064 [US5] Run `./Scripts/tools/validate-agent-sync.sh` and verify all checks pass
- [x] T065 [US5] Run `python Scripts/tools/generate-context-index.py` for final index generation and verify no diff with committed version

**Checkpoint**: All three agents reference the same shared content. Sync validation passes.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, cleanup, and cross-cutting improvements

- [x] T066 Run `shellcheck` on all new/modified shell scripts: `Scripts/tools/validate-agent-sync.sh`
- [x] T067 [P] Run `python -m black Scripts/tools/migrate-test-cases.py Scripts/tools/test-cases.py` to format Python scripts
- [x] T068 Verify full validation checklist from quickstart.md: `.context/index.json` reflects true state, all 7 playbooks exist, all entry points < 60 lines, YAML migration complete, test doubles renamed, all tests pass, sync validation passes
- [x] T069 [P] Update `Tests/TestCases/README.md` to redirect users to `packages/test-cases/README.md` and mark old location as archived
- [x] T070 [P] Update `.context/templates/entry-template.md` to include `triggers` and `summary` fields in the frontmatter template
- [x] T071 Final run: `python Scripts/tools/test-cases.py validate sync` from `packages/test-cases/` to verify end-to-end YAML workflow

**Checkpoint**: All validation passes. Feature complete.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Foundational (needs `index.json`)
- **US2 (Phase 4)**: Depends on Foundational (needs `index.json` for context). Can parallel with US1.
- **US4 (Phase 5)**: Depends on US2 (needs migrated test cases to verify fixture paths)
- **US3 (Phase 6)**: Depends on US1 (entry points must be rewritten before playbooks fill the loading guides). Content depends on US2 for test double taxonomy reference. **Note**: Between US1 completion and US3 completion, AGENTS loading guides will point to playbook IDs that don't exist yet. This is expected — agents fall back to constitutional principles during this window (per spec Edge Cases). Playbooks should be prioritized immediately after US1.
- **US5 (Phase 7)**: Depends on US1 + US3 (agents must be rewritten and playbooks must exist for sync validation)
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

```
Phase 1: Setup
  ↓
Phase 2: Foundational (BLOCKS ALL)
  ↓
Phase 3: US1 ──────────────────┐
  ↓                             ↓
Phase 4: US2 (can parallel)   Phase 6: US3 (needs US1 done)
  ↓                             ↓
Phase 5: US4 (needs US2)      Phase 7: US5 (needs US1 + US3)
  ↓                             ↓
Phase 8: Polish (needs all)  ──┘
```

### Within Each User Story

- Sequential tasks must complete in order (no [P] marker)
- File renames in US2 must be one-at-a-time with test verification after each
- Playbooks in US3 follow dependency order (Swift → UIKit → Unit Test → BDD → MVVM → Regression → Script)
- Index regeneration must follow any `.context/` file changes

### Parallel Opportunities

**Phase 2** (Foundational): T008-T016 can all run in parallel (each adds frontmatter to different files)

**Phase 3** (US1): T021, T022, T023, T024, T025 can run in parallel (different agent config files)

**Phase 4** (US2): T028+T029 parallel; T039+T040 parallel (different Mock files)

**Phase 5** (US4): T045+T046 parallel (different fixture files); T049 parallel with moves

**Phase 6** (US3): T058 (Script playbook) can parallel with T052-T057 (independent content)

---

## Parallel Example: Phase 2 (Foundational)

```bash
# Launch all frontmatter additions in parallel (each touches a different file):
Task: "Add frontmatter to ctx-release-001.md"
Task: "Add frontmatter to ctx-release-002.md"
Task: "Add frontmatter to ctx-release-003.md"
Task: "Add frontmatter to ctx-ci-001.md"
Task: "Add frontmatter to ctx-ci-002.md"
Task: "Add frontmatter to ctx-ci-003.md"
Task: "Add frontmatter to ctx-ci-004.md"
Task: "Add frontmatter to ctx-integration-001.md"
Task: "Add frontmatter to ctx-integration-002.md"
Task: "Add frontmatter to ctx-testing-001.md"
# Then sequentially:
Task: "Create generate-context-index.py"
Task: "Run and verify index generation"
```

## Parallel Example: Phase 3 (US1)

```bash
# After T019 (CLAUDE.md) and T020 (AGENTS.md), launch agent rewrites in parallel:
Task: "Rewrite AGENTS-SOURCES.md to ~20-line guide"
Task: "Rewrite AGENTS-SCRIPTS.md to ~20-line guide"
Task: "Update .claude/rules/context-system.md"
Task: "Update .codex/CODEX.md"
Task: "Update .cursor/CURSOR.md"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (index.json infrastructure)
3. Complete Phase 3: US1 (Progressive Loading)
4. **STOP and VALIDATE**: Verify < 60 line entry points, index.json works, keyword discovery functions
5. This alone delivers the core architectural improvement

### Incremental Delivery

1. Setup + Foundational → index.json exists
2. Add US1 → Progressive loading live → **MVP!**
3. Add US2 → YAML test cases + test doubles refactored → Test infrastructure modernized
4. Add US4 → Mock data consolidated → Package system complete
5. Add US3 → All 7 playbooks → AI agents have full operating manuals
6. Add US5 → Multi-agent sync validated → All agents consistent
7. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple agents/developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Agent A: US1 (Progressive Loading) — fastest, enables others
   - Agent B: US2 (YAML Migration) — can start in parallel
3. After US1 completes:
   - Agent A: US3 (Playbooks) — needs US1's entry point rewrites
   - Agent B: US4 (Mock Data) — needs US2's migration
4. After US1 + US3 complete:
   - US5 (Multi-Agent Sync) — needs both for validation

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Test doubles refactoring (T036-T043) MUST be one file at a time with tests passing after each rename
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- All new shell scripts MUST use `set -euo pipefail` (Constitution Article VI.1)
- All new Python scripts MUST be formatted with `black` (Scripts/.claude/CLAUDE.md)
- After any `.context/` file change, regenerate index: `python Scripts/tools/generate-context-index.py`
- Success criteria SC-004, SC-005, SC-009, SC-011 are qualitative and require manual verification (human review of AI agent output). No automated tasks are created for these — verify during acceptance testing.
