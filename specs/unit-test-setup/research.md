# Research: Unit Test Infrastructure Setup

**Feature Branch**: `001-unit-test-setup`
**Date**: 2026-01-20

## Research Tasks

This document consolidates research findings for setting up the unit test infrastructure.

---

## 1. Quick 7.x / Nimble 13.x Integration

### Decision
Use Quick 7.x with Nimble 13.x via CocoaPods for BDD-style testing.

### Rationale
- **Constitution Compliance**: Article V.2 mandates Quick & Nimble for all unit tests
- **Existing Template**: `Tests/templates/unit_test_spec.swift.template` already uses Quick/Nimble syntax
- **Version Selection**: Quick 7.x and Nimble 13.x are current stable versions with Swift 5.9+ support
- **iOS 15+ Compatibility**: Both frameworks support iOS 15.0 deployment target

### Alternatives Considered
| Alternative | Why Rejected |
|-------------|--------------|
| XCTest only | Constitution Article V.2 mandates Quick/Nimble for BDD |
| Swift Testing (iOS 18+) | Does not meet iOS 15.0 deployment target |
| Quick 6.x | Older version, 7.x has better async support |

### Key Findings
- Quick 7.x uses `override class func spec()` syntax (class method, not instance)
- Nimble 13.x supports `toEventually` for async assertions
- Both integrate seamlessly with XCTest runner

---

## 2. OHHTTPStubs Integration

### Decision
Use OHHTTPStubs/Swift ~> 9.1 for network request stubbing.

### Rationale
- Industry standard for iOS network mocking
- Works at URLSession/URLProtocol level - intercepts all network calls
- Supports JSON fixtures, error simulation, timeout simulation
- Compatible with iOS 15.0+

### Alternatives Considered
| Alternative | Why Rejected |
|-------------|--------------|
| Mocker | Less mature, smaller community |
| Custom URLProtocol | More maintenance, less features |
| Mockingjay | Not actively maintained |

### Key Findings
- Must call `HTTPStubs.removeAllStubs()` in `beforeEach`/`afterEach` for test isolation
- Use `stub(condition:)` with `pathEndsWith()` for flexible matching
- `HTTPStubsResponse(error:)` for timeout simulation
- Fixtures loaded via `Bundle(for:).path(forResource:ofType:)`

---

## 3. Test Target Configuration

### Decision
Create 4 independent test bundles: MSPCoreTests, MSPiOSCoreTests, NovaCoreTests, AdapterTests.

### Rationale
- Matches existing module structure
- Enables parallel CI execution
- Isolated dependencies per module
- MSPDemoApp as test host provides full runtime environment

### Alternatives Considered
| Alternative | Why Rejected |
|-------------|--------------|
| Single test target | Slower CI, harder to isolate failures |
| Per-adapter test targets | Too many targets (12+), excessive overhead |
| Framework test targets | More complex setup, XCTest host issues |

### Key Findings
- Test targets must use `inherit! :search_paths` in Podfile to access app dependencies
- `TEST_HOST` and `BUNDLE_LOADER` required for hosted unit tests
- MSPTests scheme aggregates all test targets for single-command execution

---

## 4. Protocol-Based Mocking Strategy

### Decision
Use manual protocol-based mocks with spy/stub properties.

### Rationale
- Constitution Article III.2 requires protocol-oriented design
- Existing adapters follow `AdNetworkAdapter` protocol pattern
- No external mocking framework needed
- Full control over mock behavior

### Alternatives Considered
| Alternative | Why Rejected |
|-------------|--------------|
| Cuckoo | Codegen complexity, build time impact |
| Mockingbird | Similar codegen issues |
| Sourcery | Overkill for this use case |

### Key Findings
- Mock structure: spy properties (callCount, capturedArgs) + stub properties (returnValue)
- Reset method for test isolation
- Async stubbing via `DispatchQueue.main.asyncAfter` if needed

### Mock Template Pattern
```swift
class MockProtocol: SomeProtocol {
    // Spy
    var methodCallCount = 0
    var lastArgument: ArgType?

    // Stub
    var stubbedResult: ResultType = .default

    // Implementation
    func method(arg: ArgType) -> ResultType {
        methodCallCount += 1
        lastArgument = arg
        return stubbedResult
    }

    // Reset
    func reset() {
        methodCallCount = 0
        lastArgument = nil
        stubbedResult = .default
    }
}
```

---

## 5. CI Integration (GitHub Actions)

### Decision
Create new `unit-tests.yml` workflow, separate from existing `ci-pull-request.yml`.

### Rationale
- Unit tests are fast and should run on every push
- Existing CI focuses on XCFramework builds (heavy)
- Separate workflow allows independent failure tracking
- Coverage reporting requires dedicated steps

### Alternatives Considered
| Alternative | Why Rejected |
|-------------|--------------|
| Add to ci-pull-request.yml | Conflates build validation with test coverage |
| Single job with all tests | No parallelism, longer runtime |

### Key Findings
- Use `macos-14` runner with Xcode 15.4 for iOS 17.5 simulator
- `xcpretty` for readable output
- `xccov` for coverage JSON generation
- Coverage threshold check via shell script (jq for JSON parsing)

### Workflow Triggers
- Push to: main, develop, feature/**
- Pull request to: main, develop

---

## 6. Shared Test Helpers Architecture

### Decision
Create `Tests/Shared/` directory with common utilities accessible to all test targets.

### Rationale
- DRY principle - avoid duplicating fixture loading, stub setup
- Consistent patterns across all tests
- Single place to update common test utilities

### Key Components
| Component | Purpose |
|-----------|---------|
| `MSPTestConfiguration` | Quick configuration for global before/after hooks |
| `NetworkStub` | Wrapper for OHHTTPStubs with common patterns |
| `FixtureLoader` | JSON fixture loading from bundle |
| `AsyncHelpers` | waitUntil convenience extensions |

### Key Findings
- Shared code must be included in each test target's sources
- Use `Bundle(for: FixtureLoader.self)` for fixture bundle resolution
- Quick configuration class auto-discovered by Quick framework

---

## 7. XcodeGen Test Target Template

### Decision
Create `Configs/xcodegen/test.target_template.yml` for consistent test target generation.

### Rationale
- Constitution Article I.2 requires XcodeGen for all project changes
- Template ensures consistency across test targets
- Reduces copy-paste errors

### Key Settings
```yaml
type: bundle.unit-test
platform: iOS
settings:
  ENABLE_TESTABILITY: YES
  CODE_SIGN_IDENTITY: ""
  CODE_SIGNING_REQUIRED: NO
  GENERATE_INFOPLIST_FILE: YES
```

---

## 8. Fixture Management

### Decision
Store fixtures in `Tests/Fixtures/` with descriptive JSON filenames.

### Rationale
- Centralized location for all test data
- JSON format matches API response structure
- Easy to add new fixtures for new test cases

### Naming Convention
- `{entity}_{scenario}.json` (e.g., `bid_response_success.json`)
- Descriptive names indicating test scenario

### Key Fixtures Needed
| Fixture | Purpose |
|---------|---------|
| `bid_response_success.json` | Successful bid response |
| `bid_response_error.json` | Error response (no bids) |
| `ad_config.json` | Ad configuration response |
| `adapter_config.json` | Adapter initialization config |

---

## Summary

All technical decisions are aligned with:
- Project constitution (Articles I-VIII)
- Existing project patterns (XcodeGen, CocoaPods, protocol-oriented design)
- Feature spec requirements (Quick/Nimble, OHHTTPStubs, 50% coverage)

No NEEDS CLARIFICATION items remain. Ready to proceed to Phase 1 design.
