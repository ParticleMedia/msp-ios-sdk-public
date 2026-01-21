---

description: "Task list for Debug ViewModel unit tests"
---

# Tasks: Debug ViewModel Unit Tests

**Input**: Design documents from `/specs/debug-viewmodel-tests/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, quickstart.md

**Tests**: Tests are REQUIRED for this feature (unit-test-only scope).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create test scaffolding files and folders

- [x] T001 [P] Create QuickSpec skeleton for DebugAdLoadViewModel tests in Tests/MSPCoreTests/Specs/Debug/DebugAdLoadViewModelSpec.swift
- [x] T002 [P] Create QuickSpec skeleton for DebugAdLoadSectionViewModel tests in Tests/MSPCoreTests/Specs/Debug/DebugAdLoadSectionViewModelSpec.swift
- [x] T003 [P] Create QuickSpec skeleton for DebugRadioCellViewModel tests in Tests/MSPCoreTests/Specs/Debug/DebugRadioCellViewModelSpec.swift
- [x] T004 [P] Create mock type scaffold for MockDebugOption in Tests/MSPCoreTests/Mocks/Debug/MockDebugOption.swift
- [x] T005 [P] Create mock type scaffold for MockDebugSection in Tests/MSPCoreTests/Mocks/Debug/MockDebugSection.swift
- [x] T006 [P] Create mock repository scaffold for DebugSectionsRepository in Tests/MSPCoreTests/Mocks/Debug/MockDebugSectionsRepository.swift
- [x] T007 [P] Create mock repository scaffold for PlacementsRepository in Tests/MSPCoreTests/Mocks/Debug/MockPlacementsRepository.swift
- [x] T008 [P] Create mock repository scaffold for LoadAdRepository in Tests/MSPCoreTests/Mocks/Debug/MockLoadAdRepository.swift
- [x] T009 [P] Create test constants scaffold in Tests/MSPCoreTests/Mocks/Debug/TestConstants.swift
- [x] T010 [P] Create test data factory scaffold in Tests/MSPCoreTests/Mocks/Debug/TestDataFactory.swift

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared mocks and test data required by all user stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T011 [P] Implement MockDebugOption (id, displayTitle, isVisible) in Tests/MSPCoreTests/Mocks/Debug/MockDebugOption.swift
- [x] T012 [P] Implement MockDebugSection (id, title, options, showCondition) in Tests/MSPCoreTests/Mocks/Debug/MockDebugSection.swift
- [x] T013 [P] Implement MockDebugSectionsRepository (sectionsToReturn, fetchCallCount, lastFetchedPlacements) in Tests/MSPCoreTests/Mocks/Debug/MockDebugSectionsRepository.swift
- [x] T014 [P] Implement MockPlacementsRepository (placementsToReturn, fetchCallCount) in Tests/MSPCoreTests/Mocks/Debug/MockPlacementsRepository.swift
- [x] T015 [P] Implement MockLoadAdRepository (loadAd hooks, storedAds, success/error callbacks) in Tests/MSPCoreTests/Mocks/Debug/MockLoadAdRepository.swift
- [x] T016 [P] Implement TestConstants enums for placements, section IDs, option IDs, messages in Tests/MSPCoreTests/Mocks/Debug/TestConstants.swift
- [x] T017 [P] Implement TestDataFactory helpers (simple sections, production-like sections, minimal sections) in Tests/MSPCoreTests/Mocks/Debug/TestDataFactory.swift

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Verify ViewModel Business Logic (Priority: P1) 🎯 MVP

**Goal**: Ensure core Debug ViewModel behaviors (initialization, selection state, accessors) are covered by unit tests

**Independent Test**: Run MSPCoreTests and verify US1-related specs pass in isolation

### Tests for User Story 1

- [x] T018 [P] [US1] Add DebugRadioCellViewModel initialization and selection tests in Tests/MSPCoreTests/Specs/Debug/DebugRadioCellViewModelSpec.swift
- [x] T019 [US1] Add DebugAdLoadSectionViewModel initialization and accessors tests in Tests/MSPCoreTests/Specs/Debug/DebugAdLoadSectionViewModelSpec.swift
- [x] T020 [US1] Add DebugAdLoadSectionViewModel selection state and visibility getter/setter tests in Tests/MSPCoreTests/Specs/Debug/DebugAdLoadSectionViewModelSpec.swift
- [x] T021 [US1] Add DebugAdLoadViewModel initialization, section creation, and default selection tests in Tests/MSPCoreTests/Specs/Debug/DebugAdLoadViewModelSpec.swift
- [x] T022 [US1] Add empty data edge-case tests for sections/options in Tests/MSPCoreTests/Specs/Debug/DebugAdLoadSectionViewModelSpec.swift
- [x] T023 [US1] Add empty placements/sections edge-case tests in Tests/MSPCoreTests/Specs/Debug/DebugAdLoadViewModelSpec.swift

**Checkpoint**: User Story 1 fully testable and passing

---

## Phase 4: User Story 2 - Validate Conditional Section Visibility (Priority: P1)

**Goal**: Verify showCondition logic for DebugAdLoadViewModel sections

**Independent Test**: Mock selection combinations and assert visible sections in DebugAdLoadViewModelSpec

### Tests for User Story 2

- [x] T024 [US2] Add visibility tests for Nova + Interstitial showing Creative Type and Layout in Tests/MSPCoreTests/Specs/Debug/DebugAdLoadViewModelSpec.swift
- [x] T025 [US2] Add visibility tests for non-Nova and unmet conditions hiding sections in Tests/MSPCoreTests/Specs/Debug/DebugAdLoadViewModelSpec.swift

**Checkpoint**: User Story 2 visibility logic covered and passing

---

## Phase 5: User Story 3 - Verify Test Parameter Generation (Priority: P2)

**Goal**: Ensure generated test parameters match selected options

**Independent Test**: Select options and assert test parameter dictionary contents

### Tests for User Story 3

- [x] T026 [US3] Add test parameter generation tests for basic selections in Tests/MSPCoreTests/Specs/Debug/DebugAdLoadViewModelSpec.swift
- [x] T027 [US3] Add Nova-specific parameter generation tests in Tests/MSPCoreTests/Specs/Debug/DebugAdLoadViewModelSpec.swift

**Checkpoint**: User Story 3 parameter generation covered and passing

---

## Phase 6: User Story 4 - Validate Ad Callback Handling (Priority: P2)

**Goal**: Verify AdListener callbacks trigger correct signals and state updates

**Independent Test**: Simulate ad callbacks and assert publisher emissions

### Tests for User Story 4

- [x] T028 [US4] Add loadAd success path test for adPresentationPublisher emission in Tests/MSPCoreTests/Specs/Debug/DebugAdLoadViewModelSpec.swift
- [x] T029 [US4] Add loadAd error path test for toastSignalPublisher emission in Tests/MSPCoreTests/Specs/Debug/DebugAdLoadViewModelSpec.swift
- [x] T030 [US4] Add onAdDismissed handling/cleanup test in Tests/MSPCoreTests/Specs/Debug/DebugAdLoadViewModelSpec.swift

**Checkpoint**: User Story 4 callback handling covered and passing

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Small improvements and documentation updates

- [x] T031 [P] Add shared Combine/Quick helper utilities in Tests/MSPCoreTests/Specs/Debug/DebugTestHelpers.swift
- [x] T032 [P] Update completion checklist in specs/debug-viewmodel-tests/checklists/requirements.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: Depend on Foundational phase completion
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - no dependency on other stories
- **User Story 2 (P1)**: Can start after Foundational; edits the same spec file as US1 (sequence to avoid conflicts)
- **User Story 3 (P2)**: Can start after Foundational; edits the same spec file as US1/US2 (sequence to avoid conflicts)
- **User Story 4 (P2)**: Can start after Foundational; edits the same spec file as US1/US2/US3 (sequence to avoid conflicts)

### Within Each User Story

- Write tests to fail first
- Use mocks/test data from Phase 2
- Keep each story independently runnable

---

## Parallel Execution Examples

### User Story 1

```bash
# These are in different files and can run in parallel
Task: "Add DebugRadioCellViewModel initialization and selection tests in Tests/MSPCoreTests/Specs/Debug/DebugRadioCellViewModelSpec.swift"
Task: "Add DebugAdLoadSectionViewModel initialization and accessors tests in Tests/MSPCoreTests/Specs/Debug/DebugAdLoadSectionViewModelSpec.swift"
```

### User Story 2

```bash
# Single-file edits; run sequentially to avoid conflicts
Task: "Add visibility tests for Nova + Interstitial showing Creative Type and Layout in Tests/MSPCoreTests/Specs/Debug/DebugAdLoadViewModelSpec.swift"
```

### User Story 3

```bash
# Single-file edits; run sequentially to avoid conflicts
Task: "Add test parameter generation tests for basic selections in Tests/MSPCoreTests/Specs/Debug/DebugAdLoadViewModelSpec.swift"
```

### User Story 4

```bash
# Single-file edits; run sequentially to avoid conflicts
Task: "Add loadAd success path test for adPresentationPublisher emission in Tests/MSPCoreTests/Specs/Debug/DebugAdLoadViewModelSpec.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Run MSPCoreTests and verify US1 tests pass

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently
3. Add User Story 2 → Test independently
4. Add User Story 3 → Test independently
5. Add User Story 4 → Test independently
6. Polish & documentation updates
