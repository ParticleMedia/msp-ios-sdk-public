# Feature Specification: Debug ViewModel Unit Tests

**Feature Branch**: `debug-viewmodel-tests`
**Created**: 2026-01-21
**Status**: Draft
**Input**: User description: "Add unit tests for Debug ViewModels (DebugAdLoadViewModel, DebugAdLoadSectionViewModel, DebugRadioCellViewModel) in MSPCore Debug folder using MVVM-Repository pattern with mocked repositories"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Verify ViewModel Business Logic (Priority: P1)

As a developer, I want unit tests that verify the core business logic in Debug ViewModels so that I can refactor or modify code with confidence that existing functionality remains intact.

**Why this priority**: The ViewModels contain the critical business logic for the Debug Ad Loading feature. Without tests, any modification risks introducing regressions that are difficult to detect.

**Independent Test**: Can be fully tested by running the test suite and verifying all ViewModel logic paths execute correctly with mocked dependencies.

**Acceptance Scenarios**:

1. **Given** a DebugAdLoadViewModel with mocked repositories, **When** sections are loaded, **Then** the correct sections are displayed based on visibility conditions
2. **Given** a DebugAdLoadSectionViewModel with multiple options, **When** a user selects an option, **Then** the selection state updates correctly and the selected option is accessible
3. **Given** a DebugRadioCellViewModel, **When** initialized with a DebugOption, **Then** it correctly exposes the option's display properties

---

### User Story 2 - Validate Conditional Section Visibility (Priority: P1)

As a developer, I want tests that verify section visibility logic so that the Debug UI only shows relevant options based on user selections.

**Why this priority**: The conditional visibility logic (e.g., showing Creative Type only when Nova + Interstitial is selected) is complex and error-prone. Tests prevent incorrect UI states.

**Independent Test**: Can be tested by mocking different selection combinations and verifying which sections become visible or hidden.

**Acceptance Scenarios**:

1. **Given** AdNetwork is set to Nova and AdFormat is Interstitial, **When** visibility is evaluated, **Then** Creative Type and Layout sections become visible
2. **Given** AdNetwork is not Nova, **When** visibility is evaluated, **Then** Nova-specific sections remain hidden
3. **Given** a section with showCondition requirements, **When** those conditions are not met, **Then** the section is not displayed

---

### User Story 3 - Verify Test Parameter Generation (Priority: P2)

As a developer, I want tests that verify test parameter generation so that the Debug tool sends correct parameters to the ad loading system.

**Why this priority**: Incorrect test parameters would cause ads to load with wrong configurations, making the Debug tool unreliable for QA testing.

**Independent Test**: Can be tested by selecting various options and verifying the generated key-value pairs match expected output.

**Acceptance Scenarios**:

1. **Given** selections for AdNetwork, AdFormat, and optional parameters, **When** test parameters are generated, **Then** the output contains all required key-value pairs
2. **Given** Nova-specific options selected, **When** test parameters are generated, **Then** Nova-specific parameters are included

---

### User Story 4 - Validate Ad Callback Handling (Priority: P2)

As a developer, I want tests that verify ad callback handling so that the ViewModel correctly responds to ad loading events.

**Why this priority**: The ViewModel implements AdListener protocol. Incorrect callback handling would break the ad presentation flow.

**Independent Test**: Can be tested by simulating ad callbacks and verifying ViewModel state changes and signal emissions.

**Acceptance Scenarios**:

1. **Given** an ad is loading, **When** onAdLoaded callback fires, **Then** the ViewModel emits the correct ad presentation signal
2. **Given** an ad load fails, **When** onError callback fires, **Then** the ViewModel emits a toast signal with error information
3. **Given** an ad is dismissed, **When** onAdDismissed callback fires, **Then** the ViewModel handles cleanup appropriately

---

### Edge Cases

- What happens when a section has no visible options?
- How does the system handle when required repositories return empty data?
- What happens when selection changes rapidly in succession?
- How does the ViewModel behave when initialized with nil or invalid data?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Test suite MUST cover DebugAdLoadViewModel, DebugAdLoadSectionViewModel, and DebugRadioCellViewModel
- **FR-002**: Tests MUST use mocked repositories to isolate ViewModel logic from external dependencies
- **FR-003**: Tests MUST verify section visibility logic based on showCondition evaluation
- **FR-004**: Tests MUST verify selection state management (select, deselect, retrieve selected)
- **FR-005**: Tests MUST verify test parameter generation produces correct key-value pairs
- **FR-006**: Tests MUST verify AdListener callback handling (onAdLoaded, onError, onAdDismissed)
- **FR-007**: Tests MUST verify toast signal emission for user feedback scenarios
- **FR-008**: Tests MUST cover edge cases including empty data, nil values, and boundary conditions

### Key Entities

- **DebugAdLoadViewModel**: Main coordinator managing sections, selections, and ad loading orchestration
- **DebugAdLoadSectionViewModel**: Represents a single section with radio options and selection state
- **DebugRadioCellViewModel**: Represents a single selectable option within a section
- **Mock Repositories**: Test doubles for LoadAdRepository, PlacementsRepository, DebugSectionsRepository

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All three Debug ViewModels have corresponding test files with passing tests
- **SC-002**: Test coverage includes at least 80% of ViewModel public methods and published properties
- **SC-003**: All acceptance scenarios from User Stories are covered by at least one test case
- **SC-004**: Tests execute successfully in isolation without requiring real network calls or external dependencies
- **SC-005**: Test suite completes execution without failures when run via the project's standard test command

## Assumptions

- ViewModels follow MVVM-Repository pattern and accept repository dependencies via initializer injection
- Repository protocols are already defined, enabling straightforward mock creation
- The existing test infrastructure (test target, dependencies) is already configured in the project
- DebugOption protocol conformances provide testable displayTitle and id properties
