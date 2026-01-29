# Tasks: AI 上下文系统

**Input**: Design documents from `/specs/001-ai-context-system/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, quickstart.md ✅

**Tests**: Not explicitly requested - skipping test tasks per specification guidelines.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Based on plan.md structure:
- Context storage: `.context/`
- Scripts: `Scripts/context/`
- Skills: `.agents-shared/skills/`
- Templates: `.context/templates/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create directory structure and templates

- [x] T001 Create `.context/` directory structure with subdirectories: `release/`, `ci/`, `integration/`, `compatibility/`, `templates/`
- [x] T002 [P] Create context entry template in `.context/templates/entry-template.md` per data-model.md schema
- [x] T003 [P] Create `Scripts/context/` directory for management scripts
- [x] T004 [P] Add `.context/` to `.gitignore` exceptions (ensure it's tracked)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 Create domain config file `.context/release/_domain.md` with keywords per data-model.md
- [x] T006 [P] Create domain config file `.context/ci/_domain.md` with keywords per data-model.md
- [x] T007 [P] Create domain config file `.context/integration/_domain.md` with keywords per data-model.md
- [x] T008 [P] Create domain config file `.context/compatibility/_domain.md` with keywords per data-model.md
- [x] T009 Create initial empty index file `.context/index.md` with "By Layer" and "By Domain" sections per data-model.md
- [x] T010 Create common shell functions in `Scripts/context/common.sh` (ID generation, layer validation via `validate_layer()`, date formatting, index update with layer counting)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - 初始化发布系统上下文 (Priority: P1) 🎯 MVP

**Goal**: 从 commit 历史提取发布相关经验，生成结构化上下文文件

**Independent Test**: 运行 `./Scripts/context/init-context.sh`，验证 `.context/release/` 下生成了上下文文件

### Implementation for User Story 1

- [x] T011 [US1] Create `Scripts/context/init-context.sh` with POSIX-compliant header (`set -euo pipefail`)
- [x] T012 [US1] Implement git log parsing in `Scripts/context/init-context.sh` to extract `fix(release|ci|integration)` commits
- [x] T013 [US1] Implement candidate commit filtering logic in `Scripts/context/init-context.sh` (by type and keywords)
- [x] T014 [US1] Implement interactive confirmation flow in `Scripts/context/init-context.sh` (show commit, ask AI to analyze, user confirms, AI suggests layer: business/experience/tech)
- [x] T015 [US1] Implement context file generation in `Scripts/context/init-context.sh` using entry-template.md (include layer field validation via common.sh)
- [x] T016 [US1] Implement index.md auto-update in `Scripts/context/init-context.sh` after each context creation (update both "By Layer" and "By Domain" sections)
- [x] T017 [US1] Add error handling for edge cases in `Scripts/context/init-context.sh` (no commits found, invalid format, invalid layer value)
- [x] T018 [US1] Run shellcheck validation on `Scripts/context/init-context.sh`

**Checkpoint**: At this point, User Story 1 should be fully functional - can initialize context from commit history

---

## Phase 4: User Story 2 - AI 自动提示沉淀上下文 (Priority: P1)

**Goal**: 修改 AGENTS.md 添加触发规则，让 AI 在适当时机提示用户沉淀

**Independent Test**: 模拟解决发布问题的对话，验证 AI 给出沉淀提示

### Implementation for User Story 2

- [x] T019 [US2] Draft AGENTS.md modification: add "Section 7: Context System Rules" with trigger conditions per data-model.md
- [x] T020 [US2] Add "7.1 自动加载触发" subsection in AGENTS.md with keyword-to-domain mapping
- [x] T021 [US2] Add "7.2 沉淀提示触发" subsection in AGENTS.md with 4 trigger conditions (调试完成、根因发现、领域匹配、非重复)
- [x] T022 [US2] Add prompt template in AGENTS.md for context precipitation suggestion
- [x] T023 [US2] **[REQUIRES HUMAN APPROVAL]** Submit AGENTS.md changes for review (Read-Only Zone per AGENTS.md Section 5)

**Checkpoint**: At this point, AI will automatically suggest context precipitation when conditions are met

---

## Phase 5: User Story 3 - 手动记录上下文 (Priority: P2)

**Goal**: 提供 `/context.add` 命令供用户手动添加上下文

**Independent Test**: 运行 `/context.add` 并输入测试数据，验证上下文文件正确生成

### Implementation for User Story 3

- [x] T024 [US3] Create `Scripts/context/add-context.sh` with POSIX-compliant header
- [x] T025 [US3] Implement interactive input collection in `Scripts/context/add-context.sh` (title, domain, layer [business/experience/tech], problem, root cause, solution, tags)
- [x] T026 [US3] Implement ID auto-generation in `Scripts/context/add-context.sh` using `common.sh` functions and layer validation via `validate_layer()`
- [x] T027 [US3] Implement context file creation in `Scripts/context/add-context.sh` from template (populate layer field)
- [x] T028 [US3] Implement duplicate detection in `Scripts/context/add-context.sh` (search existing contexts for similar titles)
- [x] T029 [US3] Implement index.md update in `Scripts/context/add-context.sh` (update both "By Layer" and "By Domain" sections)
- [x] T030 [US3] Create skill file `.agents-shared/skills/context-add.skill.md` per skill template format
- [x] T031 [US3] Define skill objective, when-to-use, and procedure in `.agents-shared/skills/context-add.skill.md` (include layer selection guidance)
- [x] T032 [US3] Run shellcheck validation on `Scripts/context/add-context.sh`

**Checkpoint**: At this point, users can manually add context via `/context.add` command

---

## Phase 6: User Story 4 - 自动加载相关上下文 (Priority: P2)

**Goal**: AI 能根据用户问题自动检索并引用相关上下文

**Independent Test**: 询问发布相关问题，验证 AI 在回答中引用了相关上下文

### Implementation for User Story 4

- [x] T033 [US4] Create `Scripts/context/search-context.sh` for keyword-based context search
- [x] T034 [US4] Implement domain matching in `Scripts/context/search-context.sh` (map keywords to domains per _domain.md)
- [x] T035 [US4] Implement grep-based content search in `Scripts/context/search-context.sh`
- [x] T036 [US4] Implement relevance sorting in `Scripts/context/search-context.sh` (by keyword match count)
- [x] T037 [US4] Add context search instructions in AGENTS.md Section 7.1 (how AI should use search-context.sh)
- [x] T038 [US4] Run shellcheck validation on `Scripts/context/search-context.sh`

**Checkpoint**: At this point, AI can automatically load and reference relevant context

---

## Phase 7: User Story 5 - 查看和管理上下文 (Priority: P3)

**Goal**: 提供 `/context.list` 命令供用户查看、搜索和管理上下文

**Independent Test**: 运行 `/context.list` 验证能列出所有上下文并支持筛选

### Implementation for User Story 5

- [x] T039 [US5] Create `Scripts/context/list-context.sh` with POSIX-compliant header
- [x] T040 [US5] Implement list all contexts in `Scripts/context/list-context.sh` (read from index.md, show both "By Layer" and "By Domain" views)
- [x] T041 [US5] Implement `--domain` filter in `Scripts/context/list-context.sh`
- [x] T042 [US5] Implement `--layer` filter in `Scripts/context/list-context.sh` (business/experience/tech)
- [x] T043 [US5] Implement `--tag` filter in `Scripts/context/list-context.sh`
- [x] T044 [US5] Implement `--search` keyword search in `Scripts/context/list-context.sh`
- [x] T045 [US5] Implement `--rebuild` index regeneration in `Scripts/context/list-context.sh` (regenerate "By Layer" statistics)
- [x] T046 [US5] Create skill file `.agents-shared/skills/context-list.skill.md` per skill template format
- [x] T047 [US5] Define skill objective, when-to-use, and procedure in `.agents-shared/skills/context-list.skill.md` (document --layer filter)
- [x] T048 [US5] Create `Scripts/context/archive-context.sh` for soft-delete (status → archived)
- [x] T049 [US5] Run shellcheck validation on `Scripts/context/list-context.sh` and `Scripts/context/archive-context.sh`

**Checkpoint**: At this point, all user stories should be independently functional

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T050 [P] Create `Scripts/context/validate-context.sh` for file integrity validation (per Federal II.2) including layer field validation via `validate_layer()`
- [x] T051 [P] Update `.agents-shared/skills/README.md` to include new context skills in the table
- [x] T052 [P] Create skill file `.agents-shared/skills/context-init.skill.md` for initialization command
- [x] T053 Update quickstart.md with actual command examples after implementation (document layer field usage)
- [x] T054 Run full validation: execute all scripts and verify expected outputs (including layer field handling)
- [x] T055 [P] Add Phase 2+ domain placeholder directories: `.context/sources/`, `.context/architecture/`, `.context/testing/` with empty `_domain.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-7)**: All depend on Foundational phase completion
  - US1 (init) can start first as it creates initial content
  - US2-5 can proceed in parallel after US1 creates some test data
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

```
Phase 2 (Foundational)
        │
        ▼
    ┌───┴───┐
    ▼       ▼
  US1     US2  ─────────────────────┐
(init)  (AGENTS.md rules)           │
    │                               │
    ▼                               ▼
   US3 ◄─────────────────────► US4
(add)                        (auto-load)
    │                               │
    └───────────┬───────────────────┘
                ▼
              US5
        (list & manage)
```

- **User Story 1 (P1)**: Can start after Foundational - Creates initial context data
- **User Story 2 (P1)**: Can start after Foundational - Independent (AGENTS.md rules)
- **User Story 3 (P2)**: Benefits from US1 test data, but independently testable
- **User Story 4 (P2)**: Benefits from US1 test data, but independently testable
- **User Story 5 (P3)**: Benefits from US1/US3 data, but independently testable

### Parallel Opportunities

Within each user story, tasks marked [P] can run in parallel:
- Phase 1: T002, T003, T004 can run in parallel
- Phase 2: T006, T007, T008 can run in parallel after T005
- Phase 8: T049, T050, T051, T054 can run in parallel

---

## Parallel Example: Phase 2 (Foundational)

```bash
# Launch domain configs in parallel:
Task: "Create domain config file .context/release/_domain.md"
Task: "Create domain config file .context/ci/_domain.md" [P]
Task: "Create domain config file .context/integration/_domain.md" [P]
Task: "Create domain config file .context/compatibility/_domain.md" [P]

# Then sequentially:
Task: "Create initial empty index file .context/index.md"
Task: "Create common shell functions in Scripts/context/common.sh"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (init-context.sh)
4. **STOP and VALIDATE**: Run init-context.sh on real commit history
5. Deploy/demo if ready - can already extract and store context

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add User Story 1 → Test init → **MVP Ready** (can extract context from commits)
3. Add User Story 2 → Test triggers → AI now suggests precipitation
4. Add User Story 3 → Test /context.add → Users can manually add
5. Add User Story 4 → Test auto-load → AI references context in answers
6. Add User Story 5 → Test /context.list → Full management capability
7. Polish phase → Production ready

### Human Approval Required

- **T023**: AGENTS.md modification requires human approval (Read-Only Zone)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- All shell scripts MUST use `set -euo pipefail` per Scripts/constitution.md Article VI.1
- All shell scripts MUST pass shellcheck validation per Scripts/.claude/CLAUDE.md
- AGENTS.md changes require human approval per AGENTS.md Section 5 (Read-Only Zone)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently

---

## Summary

| Phase | Tasks | Parallel Tasks | Key Deliverables |
|-------|-------|----------------|------------------|
| Setup | 4 | 3 | Directory structure, templates with layer field |
| Foundational | 6 | 3 | Domain configs, index with "By Layer" section, common functions with validate_layer() |
| US1 (P1) | 8 | 0 | init-context.sh with layer field generation |
| US2 (P1) | 5 | 0 | AGENTS.md trigger rules |
| US3 (P2) | 9 | 0 | add-context.sh with layer input, context-add.skill.md |
| US4 (P2) | 6 | 0 | search-context.sh |
| US5 (P3) | 11 | 0 | list-context.sh with --layer filter, context-list.skill.md |
| Polish | 6 | 4 | validate-context.sh with layer validation, skill updates |
| **Total** | **55** | **10** | Complete AI context system with dual-dimension classification |
