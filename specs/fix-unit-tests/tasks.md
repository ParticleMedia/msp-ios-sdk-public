---

description: "Task list for Fix Unit Test Builds"
---

# Tasks: Fix Unit Test Builds

**Input**: Design documents from `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/specs/fix-unit-tests/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: No new test cases requested; focus on build/test configuration and validation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 Review current test target definitions and pod setup in `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/Podfile`
- [x] T002 Review workspace generation inputs in `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/workspace.yml.template`
- [x] T003 [P] Review CI test workflow baseline in `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/.github/workflows/unit-tests.yml`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Align test pod platform and Swift settings in `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/Podfile`
- [x] T005 Ensure test target build settings are generated consistently in `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/Examples/MSPDemoApp/project.yml.template`
- [x] T006 Ensure workspace generation script applies test target settings deterministically in `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/Scripts/target-switching/generate_workspace.sh`
- [x] T007 [P] Verify test helper wiring and stubs cleanup remain valid in `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/Tests/Shared/TestHelpers.swift`

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Run unit tests without blockers (Priority: P1) 🎯 MVP

**Goal**: All unit test targets compile and run without dependency-related errors.

**Independent Test**: Run the AllTests scheme and confirm all test targets build and execute.

### Implementation for User Story 1

- [x] T008 [US1] Apply target-specific pod integration fixes for test targets in `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/Podfile`
- [x] T009 [US1] Update test target configuration inputs for XcodeGen in `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/Examples/MSPDemoApp/project.yml.template`
- [x] T010 [US1] Regenerate the workspace using `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/Scripts/target-switching/generate_workspace.sh`
- [x] T011 [US1] Validate unit test execution via AllTests scheme using `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/msp-ios-sdk.xcworkspace`

**Checkpoint**: User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - Build the demo app without test regressions (Priority: P2)

**Goal**: Demo app builds successfully without test-only dependencies.

**Independent Test**: Build the demo app target using the default build action.

### Implementation for User Story 2

- [ ] T012 [US2] Verify demo app target does not inherit test-only pods in `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/Podfile`
- [ ] T013 [US2] Confirm demo app build settings remain unchanged in `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/workspace.yml.template`
- [x] T014 [US2] Build the demo app via `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/msp-ios-sdk.xcworkspace` to confirm success

**Checkpoint**: User Story 2 should be independently functional

---

## Phase 5: User Story 3 - Run unit tests in CI reliably (Priority: P3)

**Goal**: CI unit test workflow completes reliably with coverage reporting.

**Independent Test**: Trigger the workflow and verify completion status and artifacts.

### Implementation for User Story 3

- [ ] T015 [US3] Update CI workflow to ensure deterministic dependency install and test run in `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/.github/workflows/unit-tests.yml`
- [ ] T016 [US3] Validate CI configuration uses expected schemes and build actions in `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/.github/workflows/unit-tests.yml`

**Checkpoint**: User Story 3 should be independently functional

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T017 [P] Update test documentation with final run instructions in `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/Tests/README.md`
- [ ] T018 Run round-trip validation script `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/Scripts/target-switching/round-trip-test.sh`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2)
- **User Story 3 (P3)**: Can start after Foundational (Phase 2)

### Parallel Opportunities

- T003 and T007 and T017 can run in parallel with other tasks
- After Phase 2 completes, US1, US2, and US3 tasks can proceed in parallel if needed

---

## Parallel Example: User Story 1

```bash
Task: "Apply target-specific pod integration fixes for test targets in /Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/Podfile"
Task: "Update test target configuration inputs for XcodeGen in /Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/workspace.yml.template"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Run AllTests scheme successfully

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Validate → Merge
3. Add User Story 2 → Validate → Merge
4. Add User Story 3 → Validate → Merge
5. Finish with Polish phase
