# Tasks: AI 基础设施重组

**Input**: Design documents from `/specs/003-ai-infra-reorg/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Not requested - this is a configuration/documentation refactoring task.

**Organization**: Tasks grouped by user story for independent implementation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1-US6 maps to user stories from spec.md

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare environment and create shared foundational files

- [x] T001 Create backup of existing configurations in /tmp/ai-infra-backup/
- [x] T002 [P] Create Sources/AGENTS-SOURCES.md with MVVM-Repo architecture guide
- [x] T003 [P] Create Scripts/AGENTS-SCRIPTS.md with config-driven development guide

**Checkpoint**: Shared domain files created - user story implementation can begin

---

## Phase 2: User Story 1 - 改用语义化 Spec 命名 (Priority: P1) 🎯 MVP

**Goal**: 将 spec 命名从数字前缀改为纯语义化名称

**Independent Test**: 运行 `create-new-feature.sh "test feature"` 验证生成 `specs/test-feature/` 而非 `specs/001-test-feature/`

### Implementation for User Story 1

- [x] T004 [US1] Modify .specify/scripts/bash/create-new-feature.sh - remove number prefix logic (lines 249-251)
- [x] T005 [US1] Add duplicate name check to create-new-feature.sh - error if spec/branch exists
- [x] T006 [US1] Create migration script .specify/scripts/bash/migrate-spec-names.sh
- [x] T007 [US1] Run migration: rename specs/001-unit-test-setup → specs/unit-test-setup
- [x] T008 [US1] Run migration: rename specs/002-ai-infra-refactor → specs/ai-infra-refactor
- [x] T009 [US1] Run migration: rename specs/003-ai-infra-reorg → specs/ai-infra-reorg
- [x] T010 [US1] Update Feature Branch field in all migrated spec.md files
- [x] T011 [US1] Rename git branches: 001-unit-test-setup → unit-test-setup (if exists)
- [x] T012 [US1] Rename git branches: 002-ai-infra-refactor → ai-infra-refactor (if exists)
- [x] T013 [US1] Rename git branches: 003-ai-infra-reorg → ai-infra-reorg

**Checkpoint**: US1 complete - specs use semantic naming, old numbered specs migrated

---

## Phase 3: User Story 2 - 架构模式分域配置 (Priority: P1)

**Goal**: 将 MVVM-Repo 移至 Sources/，config-driven 移至 Scripts/，AGENTS.md 只保留通用内容

**Independent Test**: 检查 AGENTS.md 不含 "MVVM"，Sources/AGENTS-SOURCES.md 含 "MVVM"

### Implementation for User Story 2

- [x] T014 [US2] Add MVVM-Repo architecture section to Sources/AGENTS-SOURCES.md (View→ViewModel→Repository→DataSource)
- [x] T015 [US2] Add testing strategy section to Sources/AGENTS-SOURCES.md (mock repositories, verify business logic)
- [x] T016 [US2] Add config-driven development section to Scripts/AGENTS-SCRIPTS.md
- [x] T017 [US2] Add POSIX compliance requirements to Scripts/AGENTS-SCRIPTS.md
- [x] T018 [US2] Add error handling requirements (set -euo pipefail) to Scripts/AGENTS-SCRIPTS.md
- [x] T019 [US2] Remove MVVM-Repo/Architecture section from AGENTS.md

**Checkpoint**: US2 complete - architecture patterns separated by domain

---

## Phase 4: User Story 3 - 统一分层配置结构 (Priority: P1)

**Goal**: 让所有 AI 工具通过 @import 引用共享规则文件

**Independent Test**: 检查 .claude/CLAUDE.md、.codex/CODEX.md、.cursor/CURSOR.md 都含 "@../Sources/AGENTS-SOURCES.md"

### Implementation for User Story 3

- [x] T020 [P] [US3] Add @import for Sources/AGENTS-SOURCES.md to .claude/CLAUDE.md
- [x] T021 [P] [US3] Add @import for Scripts/AGENTS-SCRIPTS.md to .claude/CLAUDE.md
- [x] T022 [P] [US3] Add @import for Sources/AGENTS-SOURCES.md to .codex/CODEX.md
- [x] T023 [P] [US3] Add @import for Scripts/AGENTS-SCRIPTS.md to .codex/CODEX.md
- [x] T024 [P] [US3] Add @import for Sources/AGENTS-SOURCES.md to .cursor/CURSOR.md
- [x] T025 [P] [US3] Add @import for Scripts/AGENTS-SCRIPTS.md to .cursor/CURSOR.md

**Checkpoint**: US3 complete - all AI tools reference same shared rules

---

## Phase 5: User Story 4 - 消除 CLAUDE.md 歧义 (Priority: P2)

**Goal**: 删除根目录 CLAUDE.md，将 Recent Changes 移至 AGENTS.md

**Independent Test**: 验证 `[ ! -f "CLAUDE.md" ]` 且 AGENTS.md 含 "Recent Changes"

### Implementation for User Story 4

- [x] T026 [US4] Copy Active Technologies/Recent Changes from CLAUDE.md to AGENTS.md
- [x] T027 [US4] Delete root CLAUDE.md file
- [x] T028 [US4] Modify .specify/scripts/bash/update-agent-context.sh to update AGENTS.md instead of CLAUDE.md
- [x] T029 [US4] Update template reference in update-agent-context.sh if needed

**Checkpoint**: US4 complete - only .claude/CLAUDE.md exists, no root CLAUDE.md

---

## Phase 6: User Story 5 - 补充 Constitution 最佳实践 (Priority: P2)

**Goal**: 在 Sources/constitution.md 添加 Logging 和 Error Handling 规范

**Independent Test**: 检查 Sources/constitution.md 含 "Article IV.4" (Logging) 和 "Article IV.5" (Error Handling)

### Implementation for User Story 5

- [x] T030 [P] [US5] Add Article IV.4 (Logging Standards) to Sources/constitution.md - Logger API, subsystem, category, log levels
- [x] T031 [P] [US5] Add Article IV.5 (Error Handling Standards) to Sources/constitution.md - Result, throws, Error enums
- [x] T032 [US5] Verify Article V (TDD) exists and is clear in Sources/constitution.md

**Checkpoint**: US5 complete - Constitution has logging and error handling standards

---

## Phase 7: User Story 6 - 明确 XCodeGen 限制并修复分层 Constitution 检查 (Priority: P2)

**Goal**: 添加 XCodeGen 工作流规则，修改 speckit 检查所有 constitution 文件

**Independent Test**: 检查 Sources/constitution.md 含 "XCodeGen"，speckit prompts 含 "find.*constitution.md"

### Implementation for User Story 6

- [x] T033 [P] [US6] Add Article IV.6 (XCodeGen Workflow - precision) to Sources/constitution.md
- [x] T033.1 [P] [US6] Add "Project Configuration Workflow" section (detailed guidance) to AGENTS.md
- [x] T034 [US6] Update .codex/prompts/speckit-plan.md to find and check all constitution.md files
- [x] T035 [US6] Update speckit plan skill/prompt to list all checked constitution files in output
- [x] T036 [US6] Verify Tests/constitution.md exists (for completeness)

**Checkpoint**: US6 complete - XCodeGen rules documented, speckit checks all constitutions

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Validation, cleanup, and final verification

- [x] T037 Run shellcheck on modified .specify/scripts/bash/create-new-feature.sh
- [x] T038 Run shellcheck on modified .specify/scripts/bash/update-agent-context.sh
- [x] T039 [P] Run shellcheck on new .specify/scripts/bash/migrate-spec-names.sh
- [x] T040 Verify AGENTS.md line count reduced by ~30% (remove MVVM-Repo content)
- [x] T041 Run validation checklist from quickstart.md
- [x] T042 Run ./Scripts/target-switching/round-trip-test.sh for full system validation
- [x] T043 Update plan.md status to "Implemented"

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies - can start immediately
- **Phase 2 (US1)**: Depends on Setup - creates migration script
- **Phase 3 (US2)**: Depends on Setup (T002, T003) - populates shared files
- **Phase 4 (US3)**: Depends on Setup (T002, T003) - references shared files
- **Phase 5 (US4)**: No dependencies on other user stories
- **Phase 6 (US5)**: No dependencies on other user stories
- **Phase 7 (US6)**: No dependencies on other user stories
- **Phase 8 (Polish)**: Depends on all user stories complete

### User Story Independence

All user stories can be implemented independently after Phase 1 (Setup):

| Story | Dependencies | Can Parallelize With |
|-------|--------------|---------------------|
| US1 (Semantic Naming) | T002, T003 | US4, US5, US6 |
| US2 (Architecture Domain) | T002, T003 | US1, US4, US5, US6 |
| US3 (Unified Config) | T002, T003, US2 | US4, US5, US6 |
| US4 (CLAUDE.md Cleanup) | None | US1, US2, US5, US6 |
| US5 (Constitution Practices) | None | US1, US2, US4, US6 |
| US6 (XCodeGen & Multi-Check) | None | US1, US2, US4, US5 |

### Parallel Opportunities

**Phase 1 (Setup)**:
```bash
# T002 and T003 can run in parallel
Task: "Create Sources/AGENTS-SOURCES.md"
Task: "Create Scripts/AGENTS-SCRIPTS.md"
```

**Phase 4 (US3)**:
```bash
# All @import tasks can run in parallel (different files)
Task: "Add @import to .claude/CLAUDE.md"
Task: "Add @import to .codex/CODEX.md"
Task: "Add @import to .cursor/CURSOR.md"
```

**Phase 6 (US5)**:
```bash
# Constitution additions can run in parallel
Task: "Add Article IV.4 (Logging)"
Task: "Add Article IV.5 (Error Handling)"
```

---

## Implementation Strategy

### MVP First (User Story 1 + 2 + 3)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: US1 - Semantic Naming (T004-T013)
3. Complete Phase 3: US2 - Architecture Domain (T014-T019)
4. Complete Phase 4: US3 - Unified Config (T020-T025)
5. **STOP and VALIDATE**: Test that semantic naming works, configs load correctly
6. Deploy/demo if ready

### Incremental Delivery

1. Setup + US1 → Semantic naming works
2. + US2 + US3 → Architecture patterns domain-separated, configs unified
3. + US4 → CLAUDE.md ambiguity resolved
4. + US5 → Constitution has logging/error handling
5. + US6 → XCodeGen documented, speckit checks all constitutions
6. Polish → Full validation

### Recommended Sequence

Given P1 stories share dependencies on shared files:
1. Phase 1 (Setup) - create shared files
2. Phase 2 (US1) - fix naming first (affects branch names)
3. Phase 3 (US2) - populate shared files with content
4. Phase 4 (US3) - wire up @imports
5. Phase 5-7 (US4-US6) - can proceed in any order
6. Phase 8 (Polish) - final validation

---

## Summary

| Phase | Story | Tasks | Parallelizable |
|-------|-------|-------|----------------|
| 1 Setup | - | 3 | T002, T003 |
| 2 US1 | P1 | 10 | - |
| 3 US2 | P1 | 6 | - |
| 4 US3 | P1 | 6 | T020-T025 |
| 5 US4 | P2 | 4 | - |
| 6 US5 | P2 | 3 | T030, T031 |
| 7 US6 | P2 | 5 | T033, T033.1 |
| 8 Polish | - | 7 | T037-T039 |
| **Total** | | **44** | |

---

## Notes

- All script modifications must maintain `set -euo pipefail` (Constitution VI.1)
- All scripts must pass shellcheck (Constitution VI.3)
- Spec migration must be idempotent (run multiple times safely)
- Commit after each user story phase for atomic rollback capability
- Run round-trip-test.sh after major changes
