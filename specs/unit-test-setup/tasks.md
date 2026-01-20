# Tasks: Unit Test Infrastructure Setup

**Input**: Design documents from `/specs/001-unit-test-setup/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, quickstart.md

**Tests**: This is a test infrastructure feature - example test files are part of the implementation, not separate test tasks.

**Organization**: Tasks are grouped by user story to enable independent implementation and verification of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4, US5)
- Include exact file paths in descriptions

## Path Conventions

- **Test infrastructure**: `Tests/` at repository root
- **Configuration**: `Podfile`, `Examples/MSPDemoApp/project.yml`
- **Scripts**: `Scripts/tests/`
- **CI**: `.github/workflows/`

---

## Phase 1: Setup (Project Infrastructure)

**Purpose**: Configure CocoaPods and XcodeGen for test framework integration

- [X] T001 Add testing_pods function with Quick/Nimble/OHHTTPStubs to Podfile
- [X] T002 Add MSPCoreTests target definition to Podfile
- [X] T003 [P] Add MSPiOSCoreTests target definition to Podfile
- [X] T004 [P] Add NovaCoreTests target definition to Podfile
- [X] T005 [P] Add AdapterTests target definition to Podfile
- [X] T006 Create test target template in Configs/xcodegen/test.target_template.yml
- [X] T007 Add MSPCoreTests target to Examples/MSPDemoApp/project.yml
- [X] T008 [P] Add MSPiOSCoreTests target to Examples/MSPDemoApp/project.yml
- [X] T009 [P] Add NovaCoreTests target to Examples/MSPDemoApp/project.yml
- [X] T010 [P] Add AdapterTests target to Examples/MSPDemoApp/project.yml
- [X] T011 Add AllTests scheme to Examples/MSPDemoApp/project.yml
- [X] T012 Run pod install to install test dependencies
- [X] T013 Run xcodegen generate to create test targets in Xcode project

**Checkpoint**: Test targets exist in Xcode project, Quick/Nimble/OHHTTPStubs available for import

---

## Phase 2: Foundational (Test Directory Structure)

**Purpose**: Create test directory structure and placeholders - MUST complete before user stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T014 [P] Create Tests/MSPCoreTests/Info.plist
- [X] T015 [P] Create Tests/MSPCoreTests/Specs/ directory
- [X] T016 [P] Create Tests/MSPCoreTests/Mocks/ directory
- [X] T017 [P] Create Tests/MSPCoreTests/Helpers/ directory
- [X] T018 [P] Create Tests/MSPiOSCoreTests/Info.plist
- [X] T019 [P] Create Tests/MSPiOSCoreTests/Specs/ directory
- [X] T020 [P] Create Tests/MSPiOSCoreTests/Mocks/ directory
- [X] T021 [P] Create Tests/MSPiOSCoreTests/Helpers/ directory
- [X] T022 [P] Create Tests/NovaCoreTests/Info.plist
- [X] T023 [P] Create Tests/NovaCoreTests/Specs/ directory
- [X] T024 [P] Create Tests/NovaCoreTests/Mocks/ directory
- [X] T025 [P] Create Tests/NovaCoreTests/Helpers/ directory
- [X] T026 [P] Create Tests/AdapterTests/Info.plist
- [X] T027 [P] Create Tests/AdapterTests/Specs/ directory
- [X] T028 [P] Create Tests/AdapterTests/Mocks/ directory
- [X] T029 [P] Create Tests/AdapterTests/Helpers/ directory
- [X] T030 [P] Create Tests/Shared/ directory
- [X] T031 [P] Create Tests/Fixtures/ directory

**Checkpoint**: All test directories exist and are ready for implementation files

---

## Phase 3: User Story 1 - Developer Runs Unit Tests Locally (Priority: P1) 🎯 MVP

**Goal**: Enable developers to run unit tests locally with Quick/Nimble using `xcodebuild test -scheme AllTests`

**Independent Test**: Run `xcodebuild test -workspace msp-ios-sdk.xcworkspace -scheme AllTests -destination 'platform=iOS Simulator,name=iPhone 15'` and verify tests execute and report results

### Implementation for User Story 1

- [X] T032 [US1] Create MSPTestConfiguration class in Tests/Shared/TestHelpers.swift with global beforeEach/afterEach hooks
- [X] T033 [US1] Create placeholder spec file Tests/MSPCoreTests/Specs/PlaceholderSpec.swift to verify Quick/Nimble works
- [X] T034 [P] [US1] Create placeholder spec file Tests/MSPiOSCoreTests/Specs/PlaceholderSpec.swift
- [X] T035 [P] [US1] Create placeholder spec file Tests/NovaCoreTests/Specs/PlaceholderSpec.swift
- [X] T036 [P] [US1] Create placeholder spec file Tests/AdapterTests/Specs/PlaceholderSpec.swift
- [X] T037 [US1] Create local test runner script Scripts/tests/run-unit-tests.sh with set -euo pipefail
- [ ] T038 [US1] Verify tests run with xcodebuild test -scheme AllTests and report pass/fail

**Checkpoint**: `./Scripts/tests/run-unit-tests.sh` executes all test targets and reports results

---

## Phase 4: User Story 2 - Developer Stubs Network Requests in Tests (Priority: P1)

**Goal**: Enable network mocking with OHHTTPStubs for deterministic test results

**Independent Test**: Create a test that stubs `/v1/bid` endpoint, make a request, and verify stubbed response is returned

### Implementation for User Story 2

- [X] T039 [US2] Create NetworkStub enum in Tests/Shared/NetworkStubs.swift with stubSuccess, stubError, stubTimeout methods
- [X] T040 [US2] Create FixtureLoader class in Tests/Shared/FixtureLoader.swift with load<T: Decodable> and loadData methods
- [X] T041 [US2] Create bid_response_success.json fixture in Tests/Fixtures/bid_response_success.json
- [X] T042 [P] [US2] Create bid_response_error.json fixture in Tests/Fixtures/bid_response_error.json
- [X] T043 [P] [US2] Create ad_config.json fixture in Tests/Fixtures/ad_config.json
- [X] T044 [US2] Update MSPTestConfiguration in Tests/Shared/TestHelpers.swift to call HTTPStubs.removeAllStubs() in beforeEach/afterEach
- [ ] T045 [US2] Create example NetworkStubSpec.swift in Tests/MSPCoreTests/Specs/NetworkStubSpec.swift demonstrating stub usage
- [ ] T046 [US2] Verify network stubs intercept requests and return fixtures in test

**Checkpoint**: Tests can stub network responses and run offline without real network calls

---

## Phase 5: User Story 3 - Developer Uses Protocol-Based Mocks (Priority: P2)

**Goal**: Enable protocol-based mocking with spy/stub properties for component isolation

**Independent Test**: Create a mock implementing AdNetworkAdapter, inject it, verify method calls and return value control

### Implementation for User Story 3

- [ ] T047 [US3] Create MockAdNetworkAdapter in Tests/MSPCoreTests/Mocks/MockAdNetworkAdapter.swift with spy properties (loadAdCallCount, lastAdRequest, showAdCallCount)
- [ ] T048 [US3] Add stub properties (stubbedLoadResult, stubbedShowResult) to MockAdNetworkAdapter
- [ ] T049 [US3] Add reset() method to MockAdNetworkAdapter for test isolation
- [ ] T050 [P] [US3] Create MockNetworkClient in Tests/MSPCoreTests/Mocks/MockNetworkClient.swift following same spy/stub pattern
- [ ] T051 [US3] Create example mock usage spec Tests/MSPCoreTests/Specs/MockUsageSpec.swift demonstrating spy assertions and stub configuration
- [ ] T052 [US3] Verify mock injection and interaction verification works in tests

**Checkpoint**: Protocol-based mocks enable isolated component testing with call tracking and return value control

---

## Phase 6: User Story 4 - CI Runs Tests Automatically on Push (Priority: P2)

**Goal**: Automated test execution via GitHub Actions with 50% coverage enforcement

**Independent Test**: Push a commit to feature branch and verify GitHub Actions workflow triggers, runs tests, and reports coverage

### Implementation for User Story 4

- [X] T053 [US4] Create GitHub Actions workflow .github/workflows/unit-tests.yml
- [X] T054 [US4] Configure workflow triggers for push to main/develop/feature/** and pull_request to main/develop
- [X] T055 [US4] Add job steps: checkout, setup-xcode, setup-ruby, cache-cocoapods
- [X] T056 [US4] Add pod install and xcodebuild test steps with xcpretty output
- [X] T057 [US4] Add coverage generation step using xcrun xccov view --report --json
- [X] T058 [US4] Add coverage threshold check (50%) with jq parsing in shell script step
- [X] T059 [US4] Add test results artifact upload step
- [ ] T060 [US4] Verify workflow runs on push and reports coverage check status

**Checkpoint**: GitHub Actions automatically runs tests on push/PR and fails if coverage < 50%

---

## Phase 7: User Story 5 - Developer Creates Tests Using Templates (Priority: P3)

**Goal**: Provide templates and shared helpers for consistent test creation

**Independent Test**: Use template/helper to create a new test file and verify it compiles and runs correctly

### Implementation for User Story 5

- [ ] T061 [US5] Update existing Tests/templates/unit_test_spec.swift.template with correct Quick 7.x syntax (override class func spec)
- [ ] T062 [US5] Create AsyncHelpers.swift in Tests/Shared/AsyncHelpers.swift with waitUntil convenience extension
- [ ] T063 [P] [US5] Create example BidLoaderSpec.swift in Tests/MSPCoreTests/Specs/BidLoaderSpec.swift using template pattern
- [ ] T064 [P] [US5] Create example AdRendererSpec.swift in Tests/NovaCoreTests/Specs/AdRendererSpec.swift using template pattern
- [ ] T065 [P] [US5] Create example GoogleAdapterSpec.swift in Tests/AdapterTests/Specs/GoogleAdapterSpec.swift using template pattern
- [ ] T066 [US5] Verify new spec files compile and run with Quick/Nimble

**Checkpoint**: Developers can quickly create consistent tests using templates and shared helpers

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, cleanup, and validation

- [X] T067 [P] Add README.md to Tests/ directory documenting test structure and conventions
- [ ] T068 [P] Remove placeholder spec files (PlaceholderSpec.swift) after real specs exist
- [ ] T069 [P] Add code comments to shared helpers explaining usage
- [ ] T070 Validate quickstart.md instructions match actual setup process
- [ ] T071 Run full test suite with coverage and verify 50% threshold is achievable
- [ ] T072 Run Scripts/target-switching/round-trip-test.sh to verify SDK modes still work

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Phase 2 - Enables local test execution
- **User Story 2 (Phase 4)**: Depends on Phase 2 - Can parallel with US1 if desired
- **User Story 3 (Phase 5)**: Depends on Phase 2 - Can parallel with US1/US2
- **User Story 4 (Phase 6)**: Depends on Phase 3 (needs working tests) - CI automation
- **User Story 5 (Phase 7)**: Depends on Phase 4 (needs network stubs) - Templates use all patterns
- **Polish (Phase 8)**: Depends on all desired user stories being complete

### User Story Dependencies

| Story | Can Start After | Notes |
|-------|-----------------|-------|
| US1 (P1) | Phase 2 (Foundational) | No dependencies on other stories |
| US2 (P1) | Phase 2 (Foundational) | Independent, but shares TestHelpers.swift |
| US3 (P2) | Phase 2 (Foundational) | Independent, creates mock patterns |
| US4 (P2) | US1 complete | CI needs working tests to run |
| US5 (P3) | US2 complete | Templates incorporate all patterns |

### Within Each User Story

- Shared files (TestHelpers.swift) before module-specific files
- Helper implementations before example specs
- Core functionality before validation

### Parallel Opportunities

**Phase 1 (Setup)**:
```text
T003, T004, T005 can run in parallel (Podfile test targets)
T008, T009, T010 can run in parallel (project.yml test targets)
```

**Phase 2 (Foundational)**:
```text
All Info.plist and directory creation tasks (T014-T031) can run in parallel
```

**User Story 1 (Phase 3)**:
```text
T034, T035, T036 can run in parallel (placeholder specs for different modules)
```

**User Story 2 (Phase 4)**:
```text
T042, T043 can run in parallel (fixture files)
```

**User Story 3 (Phase 5)**:
```text
T050 can run in parallel with T047-T049 (different mock files)
```

**User Story 5 (Phase 7)**:
```text
T063, T064, T065 can run in parallel (example specs for different modules)
```

---

## Parallel Example: Phase 2 Directory Creation

```bash
# Launch all directory creation tasks together:
Task: "Create Tests/MSPCoreTests/Info.plist"
Task: "Create Tests/MSPCoreTests/Specs/ directory"
Task: "Create Tests/MSPiOSCoreTests/Info.plist"
Task: "Create Tests/NovaCoreTests/Info.plist"
Task: "Create Tests/AdapterTests/Info.plist"
Task: "Create Tests/Shared/ directory"
Task: "Create Tests/Fixtures/ directory"
```

## Parallel Example: User Story 2 Fixtures

```bash
# Launch fixture creation in parallel:
Task: "Create bid_response_success.json fixture in Tests/Fixtures/bid_response_success.json"
Task: "Create bid_response_error.json fixture in Tests/Fixtures/bid_response_error.json"
Task: "Create ad_config.json fixture in Tests/Fixtures/ad_config.json"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T013)
2. Complete Phase 2: Foundational (T014-T031)
3. Complete Phase 3: User Story 1 (T032-T038)
4. **STOP and VALIDATE**: Run `./Scripts/tests/run-unit-tests.sh` - tests should pass
5. Can now write tests using Quick/Nimble locally

### Incremental Delivery

1. MVP: Setup + Foundational + US1 → Local test execution works
2. Add US2 → Network mocking works → Tests can run offline
3. Add US3 → Protocol mocking works → Component isolation possible
4. Add US4 → CI automation works → Automated quality gates
5. Add US5 → Templates complete → Consistent test creation

### Recommended Order

For single developer:
1. **Phase 1-2**: Setup and Foundational (foundation)
2. **US1 + US2**: Local testing with network mocks (core capability)
3. **US4**: CI automation (quality gates)
4. **US3 + US5**: Mocking and templates (developer productivity)

---

## Summary

| Phase | Tasks | Parallel Tasks | Description |
|-------|-------|----------------|-------------|
| 1 (Setup) | T001-T013 | 6 | CocoaPods/XcodeGen configuration |
| 2 (Foundational) | T014-T031 | 18 | Directory structure creation |
| 3 (US1) | T032-T038 | 3 | Local test execution |
| 4 (US2) | T039-T046 | 2 | Network mocking |
| 5 (US3) | T047-T052 | 1 | Protocol-based mocking |
| 6 (US4) | T053-T060 | 0 | CI automation |
| 7 (US5) | T061-T066 | 3 | Templates and helpers |
| 8 (Polish) | T067-T072 | 3 | Documentation and cleanup |
| **Total** | **72 tasks** | **36 parallel** | |

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Constitution compliance: All changes via Podfile/project.yml (Art. I.2), scripts use set -euo pipefail (Art. VI.1)
- Commit after each task or logical group
- Stop at any checkpoint to validate independently
