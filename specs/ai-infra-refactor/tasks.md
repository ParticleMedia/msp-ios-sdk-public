# Tasks: AI Infrastructure Refactoring

**Input**: Design documents from `/specs/002-ai-infra-refactor/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md

**Tests**: N/A - this is a configuration refactoring task, verification via grep searches

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4, US5)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Preparation)

**Purpose**: Ensure clean state before refactoring

- [x] T001 Verify clean git working directory with `git status`
- [x] T002 Create backup branch for reference with `git branch backup-before-ai-infra-refactor`

---

## Phase 2: Foundational (Skills Migration)

**Purpose**: Move all skills to shared location before modifying agent files

**⚠️ CRITICAL**: Complete this phase before any agent file modifications

### Move Skills to Shared Location

- [x] T003 [P] Move `.claude/skills/planner.skill.md` to `.agents-shared/skills/planner.skill.md`
- [x] T004 [P] Move `.claude/skills/architect.skill.md` to `.agents-shared/skills/architect.skill.md`
- [x] T005 [P] Move `.claude/skills/deep-reviewer.skill.md` to `.agents-shared/skills/deep-reviewer.skill.md`
- [x] T006 [P] Move `.claude/skills/document-writer.skill.md` to `.agents-shared/skills/document-writer.skill.md`

### Delete Duplicate Skills from .claude/skills/

- [x] T007 [P] Delete `.claude/skills/constitutional-auditor.skill.md` (duplicate of shared)
- [x] T008 [P] Delete `.claude/skills/scripts-failure-analyst.skill.md` (duplicate of shared)
- [x] T009 [P] Delete `.claude/skills/sources-bug-analyst.skill.md` (duplicate of shared)
- [x] T010 [P] Delete `.claude/skills/unit-test-generator.skill.md` (duplicate of shared)

### Update Moved Skills Frontmatter

- [x] T011 [P] Update `.agents-shared/skills/planner.skill.md`: change `shared: false` to `shared: true`, `applicable_agents` to `[claude-code, codex, cursor]`, `required_model` to `recommended_model`
- [x] T012 [P] Update `.agents-shared/skills/architect.skill.md`: same changes as T011
- [x] T013 [P] Update `.agents-shared/skills/deep-reviewer.skill.md`: same changes as T011
- [x] T014 [P] Update `.agents-shared/skills/document-writer.skill.md`: same changes as T011

**Checkpoint**: All skills now in `.agents-shared/skills/` with unified frontmatter

---

## Phase 3: User Story 1 - Clear Configuration File Responsibilities (Priority: P1)

**Goal**: Establish clear, non-overlapping responsibilities for each configuration file

**Independent Test**: Read each file header and confirm single responsibility is immediately clear

### Implementation for User Story 1

- [x] T015 [US1] Rewrite `AGENTS.md` to simplified structure (~130 lines) per data-model.md template
- [x] T016 [US1] Rewrite `.claude/CLAUDE.md` to self-contained structure per data-model.md template
- [x] T017 [US1] Update `.agents-shared/skills/README.md` to list all skills (including newly moved ones)
- [x] T018 [US1] Verify `constitution.md` contains no agent-specific content (read-only verification)

### Verification for User Story 1

- [x] T019 [US1] Verify AGENTS.md line count is ~130 lines with `wc -l AGENTS.md`
- [x] T020 [US1] Verify no duplicate content between AGENTS.md and .claude/CLAUDE.md with manual review

**Checkpoint**: US1 complete - configuration file responsibilities are clear

---

## Phase 4: User Story 2 - Unified Agent Capabilities (Priority: P1)

**Goal**: All agents have access to the same skills

**Independent Test**: Verify `.agents-shared/skills/` contains all skills and no skill is marked exclusive

### Implementation for User Story 2

- [x] T021 [US2] Update all remaining skills in `.agents-shared/skills/` to have `shared: true` and `applicable_agents: [claude-code, codex, cursor]`
- [x] T022 [US2] Update `.agents-shared/protocols/task-tier.protocol.md` to remove model requirements, add model recommendations

### Verification for User Story 2

- [x] T023 [US2] Verify no files in `.claude/skills/` directory (should be empty or deleted)
- [x] T024 [US2] Verify grep for `shared: false` returns 0 results in `.agents-shared/skills/`
- [x] T025 [US2] Verify grep for `applicable_agents: \[claude-code\]` (exclusive) returns 0 results

**Checkpoint**: US2 complete - all skills unified and accessible to all agents

---

## Phase 5: User Story 3 - Remove Obsolete Protocols (Priority: P2)

**Goal**: Delete escalation and handoff protocols, remove all references

**Independent Test**: Grep for "escalation" and "handoff" returns 0 results in active config files

### Implementation for User Story 3

- [x] T026 [P] [US3] Delete `.agents-shared/protocols/escalation.protocol.md`
- [x] T027 [P] [US3] Delete `.agents-shared/protocols/handoff.protocol.md`
- [x] T028 [US3] Remove escalation/handoff references from `AGENTS.md` (Sections 9, 10 if any remain)
- [x] T029 [US3] Remove escalation/handoff references from `.claude/CLAUDE.md`
- [x] T030 [US3] Remove escalation/handoff references from `.codex/CODEX.md`
- [x] T031 [US3] Remove escalation/handoff references from `.cursor/CURSOR.md`
- [x] T032 [US3] Update `.agents-shared/protocols/README.md` to remove references to deleted protocols

### Verification for User Story 3

- [x] T033 [US3] Verify `grep -r "escalation" .agents-shared/ AGENTS.md .claude/` returns 0 results (codex/cursor will be fixed in US5)
- [x] T034 [US3] Verify `grep -r "handoff" .agents-shared/ AGENTS.md .claude/` returns 0 results (codex/cursor will be fixed in US5)

**Checkpoint**: US3 complete - no escalation/handoff references exist

---

## Phase 6: User Story 4 - Convert Model Restrictions to Recommendations (Priority: P2)

**Goal**: Change model requirements to soft recommendations

**Independent Test**: Grep for "required_model" returns 0 results; "recommended_model" exists with comment

### Implementation for User Story 4

- [x] T035 [P] [US4] Delete `.agents-shared/protocols/model-selection.protocol.md`
- [x] T036 [US4] Update all skills in `.agents-shared/skills/` to use `recommended_model` instead of `required_model`
- [x] T037 [US4] Remove model restriction references from `.claude/CLAUDE.md` (if any remain after T016)
- [x] T038 [US4] Remove model restriction references from `.codex/CODEX.md`

### Verification for User Story 4

- [x] T039 [US4] Verify `grep -r "required_model" .agents-shared/` returns 0 results
- [x] T040 [US4] Verify `grep -r "recommended_model" .agents-shared/skills/` returns results with comments

**Checkpoint**: US4 complete - model restrictions converted to recommendations

---

## Phase 7: User Story 5 - Cursor Configuration Alignment (Priority: P3)

**Goal**: Align Cursor configuration with Claude and Codex structure

**Independent Test**: Compare `.cursor/CURSOR.md` structure with `.claude/CLAUDE.md` and `.codex/CODEX.md`

### Implementation for User Story 5

- [x] T041 [US5] Rewrite `.cursor/CURSOR.md` to aligned structure per data-model.md template
- [x] T042 [US5] Rewrite `.codex/CODEX.md` to aligned structure per data-model.md template (if not done in US1)
- [x] T043 [US5] Verify `.cursor/` references `.agents-shared/skills/` correctly

### Verification for User Story 5

- [x] T044 [US5] Verify `.cursor/CURSOR.md` has same section structure as `.claude/CLAUDE.md` (Role Definition, Core Imports, Available Skills, Best Practices, Output Format)

**Checkpoint**: US5 complete - all agent configs aligned

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup and documentation updates

- [x] T045 [P] Update `docs/AI_Agents.md` to reflect new architecture (remove escalation/handoff sections, update diagram) - Manual review needed
- [x] T046 [P] Delete empty `.claude/skills/` directory if all files removed
- [x] T047 Run final grep verification for all removed content
- [x] T048 Update spec.md status from "Draft" to "Implemented"

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies - start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 - BLOCKS all user stories
- **Phase 3-7 (User Stories)**: All depend on Phase 2 completion
- **Phase 8 (Polish)**: Depends on all user stories complete

### User Story Dependencies

- **US1 (Clear Responsibilities)**: Can start after Phase 2 - foundational for others
- **US2 (Unified Skills)**: Can start after Phase 2 - can run parallel with US1
- **US3 (Remove Protocols)**: Can start after Phase 2 - can run parallel with US1/US2
- **US4 (Model Recommendations)**: Can start after Phase 2 - can run parallel
- **US5 (Cursor Alignment)**: Can start after Phase 2 - can run parallel

### Parallel Opportunities

**Phase 2 (all [P] tasks can run in parallel)**:
- T003, T004, T005, T006 (move skills)
- T007, T008, T009, T010 (delete duplicates)
- T011, T012, T013, T014 (update frontmatter)

**User Stories (can run in parallel after Phase 2)**:
- US1, US2, US3, US4, US5 can all start simultaneously

**Phase 8 (some [P] tasks)**:
- T045, T046 can run in parallel

---

## Parallel Example: Phase 2

```bash
# Launch all skill moves together:
Task: "Move .claude/skills/planner.skill.md to .agents-shared/skills/planner.skill.md"
Task: "Move .claude/skills/architect.skill.md to .agents-shared/skills/architect.skill.md"
Task: "Move .claude/skills/deep-reviewer.skill.md to .agents-shared/skills/deep-reviewer.skill.md"
Task: "Move .claude/skills/document-writer.skill.md to .agents-shared/skills/document-writer.skill.md"

# Then launch all deletions together:
Task: "Delete .claude/skills/constitutional-auditor.skill.md"
Task: "Delete .claude/skills/scripts-failure-analyst.skill.md"
Task: "Delete .claude/skills/sources-bug-analyst.skill.md"
Task: "Delete .claude/skills/unit-test-generator.skill.md"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (skills migration)
3. Complete Phase 3: User Story 1 (clear responsibilities)
4. **STOP and VALIDATE**: Verify AGENTS.md simplified, CLAUDE.md self-contained
5. Commit as MVP

### Incremental Delivery

1. Complete Setup + Foundational → Skills unified
2. Add US1 (Clear Responsibilities) → Verify independently → Commit
3. Add US2 (Unified Skills) → Verify independently → Commit
4. Add US3 (Remove Protocols) → Verify independently → Commit
5. Add US4 (Model Recommendations) → Verify independently → Commit
6. Add US5 (Cursor Alignment) → Verify independently → Commit
7. Polish phase → Final commit

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- All verification tasks use grep searches for automated validation
- Commit after each user story checkpoint
- All file paths are relative to repository root
