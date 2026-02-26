# Feature Specification: Unit Test Infrastructure Setup

**Feature Branch**: `unit-test-setup``
**Created**: 2026-01-20
**Status**: Draft
**Input**: Setup unit test infrastructure with Quick 7.x/Nimble 13.x framework, OHHTTPStubs network mocking, protocol-based internal mocking, and GitHub Actions CI integration with 50% coverage target

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Developer Runs Unit Tests Locally (Priority: P1)

As a developer, I want to run unit tests locally against the SDK modules so that I can verify my code changes don't break existing functionality before pushing to the repository.

**Why this priority**: This is the foundational capability that enables all other testing workflows. Without the ability to run tests locally, developers cannot validate their work.

**Independent Test**: Can be fully tested by running `xcodebuild test` command against a test scheme and verifying tests execute and report results. Delivers immediate feedback on code quality.

**Acceptance Scenarios**:

1. **Given** the test infrastructure is set up and dependencies are installed, **When** a developer runs `xcodebuild test -scheme MSPTests`, **Then** all configured test targets execute and report pass/fail results
2. **Given** a test file exists with Quick/Nimble syntax, **When** the test suite runs, **Then** the BDD-style tests (describe/it/expect) execute correctly
3. **Given** Quick 7.x and Nimble 13.x pods are configured, **When** `pod install` completes, **Then** the testing frameworks are available for import in test files

---

### User Story 2 - Developer Stubs Network Requests in Tests (Priority: P1)

As a developer, I want to mock network responses in my tests so that I can test SDK behavior without making actual network calls and ensure deterministic test results.

**Why this priority**: Network mocking is essential for testing the SDK's core functionality (bid loading, ad requests, configuration fetching) in isolation.

**Independent Test**: Can be tested by creating a test that stubs a network endpoint, making a network request through the SDK, and verifying the stubbed response is returned.

**Acceptance Scenarios**:

1. **Given** OHHTTPStubs is configured, **When** a test stubs a successful response for `/v1/bid`, **Then** the SDK receives the stubbed JSON response instead of making a real network call
2. **Given** a test stubs an error response (500 status), **When** the SDK makes a request, **Then** the SDK's error handling logic processes the stubbed error
3. **Given** a test stubs a timeout condition, **When** the SDK makes a request, **Then** the SDK's timeout handling logic is exercised

---

### User Story 3 - Developer Uses Protocol-Based Mocks (Priority: P2)

As a developer, I want to create mock implementations of internal protocols so that I can test components in isolation without their real dependencies.

**Why this priority**: Protocol-based mocking enables unit testing of individual components by replacing dependencies with controllable test doubles.

**Independent Test**: Can be tested by creating a mock that conforms to a protocol, injecting it into a component under test, and verifying the component interacts correctly with the mock.

**Acceptance Scenarios**:

1. **Given** a mock adapter conforming to `AdNetworkAdapter` protocol, **When** the mock is injected into a component, **Then** test code can verify method calls and control return values
2. **Given** a mock with spy properties (call counts), **When** a component interacts with the mock, **Then** tests can assert the expected number of interactions occurred
3. **Given** a mock with stub properties, **When** test code sets a stubbed result, **Then** the component receives the configured response

---

### User Story 4 - CI Runs Tests Automatically on Push (Priority: P2)

As a development team, we want unit tests to run automatically when code is pushed to feature branches or pull requests so that we catch regressions early.

**Why this priority**: Automated CI testing prevents broken code from being merged and ensures consistent quality across the team.

**Independent Test**: Can be tested by pushing a commit to a feature branch and verifying the GitHub Actions workflow triggers, runs tests, and reports results.

**Acceptance Scenarios**:

1. **Given** a GitHub Actions workflow is configured, **When** code is pushed to `main`, `develop`, or `feature/**` branches, **Then** the unit test workflow triggers automatically
2. **Given** a pull request is opened against `main` or `develop`, **When** the workflow runs, **Then** test results are reported as a check on the PR
3. **Given** tests complete, **When** coverage is below 50%, **Then** the CI job fails with a clear error message about insufficient coverage

---

### User Story 5 - Developer Creates Tests Using Templates (Priority: P3)

As a developer, I want to use test templates and shared helpers so that I can quickly create new tests following established patterns.

**Why this priority**: Templates and helpers reduce boilerplate and ensure consistency across test files.

**Independent Test**: Can be tested by using a template/helper to create a new test file and verifying it compiles and runs correctly.

**Acceptance Scenarios**:

1. **Given** shared test helpers exist, **When** a developer imports them, **Then** common operations (fixture loading, network stubbing) are available
2. **Given** JSON fixture files exist, **When** a test loads a fixture, **Then** the data is available for stubbing responses or creating test objects
3. **Given** test directory structure follows conventions, **When** a developer adds new test files, **Then** they are automatically included in the appropriate test target

---

### Edge Cases

- What happens when a network stub is not configured for a URL the code tries to access?
- How does the system handle tests that timeout waiting for async operations?
- What happens when multiple tests run in parallel with shared stubs?
- How are tests isolated when they modify shared state (singletons, global configuration)?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Test system MUST support Quick 7.x BDD-style test syntax (describe, context, it, beforeEach, afterEach)
- **FR-002**: Test system MUST support Nimble 13.x assertion matchers (expect, to, toEventually)
- **FR-003**: Test system MUST stub HTTP responses using OHHTTPStubs 9.1 for network mocking
- **FR-004**: Test system MUST support loading JSON fixtures from bundle resources
- **FR-005**: Test system MUST reset all HTTP stubs before and after each test to ensure isolation
- **FR-006**: Test system MUST support async testing with configurable timeouts
- **FR-007**: Test targets MUST be configured as independent bundles per module (MSPCoreTests, MSPiOSCoreTests, NovaCoreTests, AdapterTests)
- **FR-008**: Test targets MUST use MSPDemoApp as the test host application
- **FR-009**: CI workflow MUST run on pushes to main, develop, and feature/** branches
- **FR-010**: CI workflow MUST run on pull requests to main and develop
- **FR-011**: CI workflow MUST generate code coverage reports
- **FR-012**: CI workflow MUST fail if code coverage falls below 50%
- **FR-013**: Protocol-based mocks MUST support spy functionality (tracking call counts, captured arguments)
- **FR-014**: Protocol-based mocks MUST support stub functionality (configuring return values)
- **FR-015**: Shared test helpers MUST be accessible to all test targets

### Key Entities

- **Test Target**: A unit test bundle that tests a specific module (MSPCore, MSPiOSCore, NovaCore, Adapters). Contains Specs/, Mocks/, and Helpers/ directories.
- **Spec File**: A Quick test file containing BDD-style test descriptions. Named `*Spec.swift`.
- **Mock**: A test double implementing a protocol for testing purposes. Contains spy properties (call tracking) and stub properties (return value configuration).
- **Fixture**: JSON data files used to provide consistent test data. Loaded via FixtureLoader helper.
- **Network Stub**: An OHHTTPStubs configuration that intercepts HTTP requests and returns configured responses.
- **Test Helper**: Shared utility code providing common test operations (fixture loading, stub configuration, async waiting).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can run all unit tests locally with a single command within 5 minutes
- **SC-002**: Test coverage reports show at least 50% line coverage for core modules
- **SC-003**: 100% of network-dependent tests run successfully offline using stubs
- **SC-004**: CI pipeline completes test runs within 30 minutes for the full test suite
- **SC-005**: New test files using Quick/Nimble syntax compile and execute without manual configuration
- **SC-006**: Test failures provide clear, actionable error messages identifying the failing expectation
- **SC-007**: Protocol-based mocks can be created for any existing adapter protocol within the SDK

## Assumptions

- The MSPDemoApp project exists and can serve as a test host
- CocoaPods is the dependency manager for integrating test frameworks
- XcodeGen is used for project generation and will include test target definitions
- The GitHub Actions runner has macOS 14 with Xcode 15.4 available
- The team uses xcpretty for formatting test output
- All developers have access to run pod install locally
