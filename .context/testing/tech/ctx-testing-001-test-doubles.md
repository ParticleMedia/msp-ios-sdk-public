---
id: ctx-testing-001
title: Test Doubles Strategy - Stub, Mock, Fake
layer: tech
domain: testing
tags: [test-double, mock, stub, fake, unit-test, quick, nimble, stub-factory, test-case, tdd]
created: 2026-02-02
source: manual
status: active
confidence: high
---

# Test Doubles Strategy: Stub, Mock, Fake

## Overview

This project uses a simplified 3-layer Test Double strategy with TDD support:

| Layer | Purpose | Location |
|-------|---------|----------|
| **TestCase** | JSON test case definitions (source of truth) | `Tests/TestCases/` |
| **Stub** | JSON data files (from real API responses) | `Tests/Stubs/` |
| **StubFactory** | Swift code to load Stub data | `Tests/Generated/` (shared) |
| **Mock** | Test doubles for unit tests | `Tests/Mocks/` |
| **Fake** | Test doubles for development (when backend unavailable) | `Sources/Fakes/` |

```
┌─────────────────────────────────────────────────┐
│              Stub Layer (JSON Data)             │
│         Tests/Stubs/{Module}/*.json             │
└─────────────────────────────────────────────────┘
                        │
                        ▼  generate-stub-factory.swift
┌─────────────────────────────────────────────────┐
│           StubFactory (Generated Swift)         │
│      Tests/Generated/{Module}StubFactory.swift  │
└─────────────────────────────────────────────────┘
                        │
          ┌─────────────┴─────────────┐
          ▼                           ▼
┌───────────────────┐       ┌───────────────────┐
│  Mock{Service}    │       │  Fake{Service}    │
│  (Tests target)   │       │  (#if ENABLE_STUB)│
│  Permanent        │       │  Temporary        │
└───────────────────┘       └───────────────────┘
          │                           │
          └───────────┬───────────────┘
                      ▼
        ┌─────────────────────────────┐
        │    {Service}Protocol        │
        └─────────────────────────────┘
```

---

## Directory Structure

```
msp-ios-sdk/
├── Tests/
│   ├── TestCases/                          # Test case definitions (source of truth)
│   │   ├── AdBidding.json
│   │   ├── UserProfile.json
│   │   └── .implemented.json               # Auto-generated implementation status
│   ├── Stubs/                              # JSON stub data
│   │   ├── AdBidding/
│   │   │   ├── success.json
│   │   │   ├── failure_timeout.json
│   │   │   └── failure_no_fill.json
│   │   └── UserProfile/
│   │       └── default.json
│   ├── Generated/                          # Auto-generated StubFactories
│   │   └── AdBiddingStubFactory.swift
│   └── Mocks/                              # Mock classes (permanent)
│       └── MockAdBiddingService.swift
├── Sources/
│   ├── Protocols/
│   │   └── AdBiddingServiceProtocol.swift
│   └── Fakes/                              # Fake classes (temporary, DEBUG only)
│       └── FakeAdBiddingService.swift
└── Scripts/
    └── tools/
        ├── generate-stub-factory.swift     # StubFactory generator
        └── sync-test-cases.swift           # Test case sync checker
```

---

## TDD Workflow: Test Cases as Source of Truth

### Overview

```
┌─────────────────────────────────────────────────────────────┐
│  Tests/TestCases/AdBidding.json  (Source of Truth)         │
│  Define what tests SHOULD exist                             │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ TDD: Write test first
┌─────────────────────────────────────────────────────────────┐
│  Tests/UnitTests/AdBiddingViewModelSpec.swift              │
│  Implement tests with [TC###] IDs                           │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ sync-test-cases.swift
┌─────────────────────────────────────────────────────────────┐
│  Tests/TestCases/.implemented.json  (Auto-generated)       │
│  Track implementation status                                │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ CI Check
┌─────────────────────────────────────────────────────────────┐
│  ✓ TC001 implemented                                       │
│  ✓ TC002 implemented                                       │
│  ✗ TC003 NOT implemented  ← CI fails                       │
└─────────────────────────────────────────────────────────────┘
```

### Naming Convention (CRITICAL)

**Rule**: JSON filename (`module` field) must be a substring of the Swift test file name.

The sync script searches for test files by matching the module name against file names:

```
{Module}.json  →  *{Module}*Spec.swift, *{Module}*Tests.swift
```

| JSON File | Module | Matches |
|-----------|--------|---------|
| `DebugAdLoad.json` | DebugAdLoad | `DebugAdLoadViewModelSpec.swift`, `DebugAdLoadSectionViewModelSpec.swift` |
| `DebugRadioCell.json` | DebugRadioCell | `DebugRadioCellViewModelSpec.swift` |
| `UserProfile.json` | UserProfile | `UserProfileViewModelSpec.swift`, `UserProfileServiceTests.swift` |

**Anti-patterns**:
- Do NOT group unrelated ViewModels in one file just because they're in the same feature
- Do NOT use generic names like `Debug.json` - be specific to match file names
- If a ViewModel has its own Spec file, it needs its own TestCase JSON file

### Test Case JSON Structure

Test cases support two types: **behavior** (BDD style) and **unit** (method-level).

```json
// Tests/TestCases/AdBidding.json
{
  "module": "AdBidding",
  "description": "Test cases for Ad Bidding feature",
  "cases": [
    {
      "id": "TC001",
      "type": "behavior",
      "feature": "Ad Bidding",
      "scenario": "Successfully load an ad",
      "given": [
        "Network is available",
        "Valid ad unit ID"
      ],
      "when": "User requests ad",
      "then": [
        "Ad is loaded",
        "State changes to loaded",
        "Analytics event is tracked"
      ],
      "priority": "high",
      "tags": ["smoke", "happy-path"]
    },
    {
      "id": "TC002",
      "type": "unit",
      "class": "AdBiddingViewModel",
      "method": "requestBid",
      "description": "Should call repository exactly once",
      "given": { "scenario": "success" },
      "when": "requestBid()",
      "then": { "repositoryCallCount": 1 },
      "priority": "medium",
      "tags": ["unit"]
    }
  ]
}
```

### Linking Tests to Test Cases

Use `[TC###]` pattern in Quick spec `it()` descriptions:

```swift
class AdBiddingViewModelSpec: QuickSpec {
    override class func spec() {
        describe("AdBiddingViewModel") {
            context("when bid succeeds") {
                it("[TC001] should update state to loaded and track analytics") {
                    // Test implementation
                }
            }

            it("[TC002] should call repository exactly once") {
                // Test implementation
            }
        }
    }
}
```

### Test Case Management

```bash
# Validate JSON files (check duplicates, prefix conflicts)
python Scripts/tools/test-cases.py validate

# Check if Swift tests implement all defined cases
python Scripts/tools/test-cases.py sync

# CI: run both (fails if any issues)
python Scripts/tools/test-cases.py validate sync
```

**Example output:**
```
Syncing test cases...

✓ AdBidding: 3/4 implemented
  Missing:
    - TC003

Summary: 3/4 test cases implemented
         1 test case(s) missing
```

### CI Integration

Add to your CI workflow:

```yaml
- name: Validate and Sync Test Cases
  run: python Scripts/tools/test-cases.py validate sync
```

---

## Layer 1: Stub (JSON Data)

### File Naming Convention

```
Tests/Stubs/{ModuleName}/{scenario}.json
```

| Pattern | Example | Use Case |
|---------|---------|----------|
| `success.json` | `AdBidding/success.json` | Happy path response |
| `failure_{reason}.json` | `AdBidding/failure_timeout.json` | Error scenarios |
| `{variant}.json` | `AdBidding/high_bid.json` | Edge cases |

### JSON Structure

Each JSON file should contain the raw API response:

```json
// Tests/Stubs/AdBidding/success.json
{
  "bid_id": "abc123",
  "price": 2.50,
  "ad_markup": "<html>...</html>",
  "expires_at": "2026-02-02T12:00:00Z"
}
```

### How to Capture Stub Data

**Method 1: Manual (Charles/Proxyman)**
1. Run the app with proxy enabled
2. Capture the API response
3. Copy JSON to `Tests/Stubs/{Module}/{scenario}.json`

**Method 2: Script Recording (TODO)**
```bash
# Future: Auto-record API responses
./Scripts/tools/record-stub.sh --endpoint "/api/v1/bid" --output "Tests/Stubs/AdBidding/success.json"
```

---

## Layer 2: StubFactory (Generated Code)

### Generated Output

Running the generator script produces:

```swift
// Tests/Generated/AdBiddingStubFactory.swift
// AUTO-GENERATED - DO NOT EDIT
// Generated by: Scripts/tools/generate-stub-factory.swift

import Foundation

enum AdBiddingStubFactory {

    enum Scenario: String, CaseIterable {
        case success = "success"
        case failureTimeout = "failure_timeout"
        case failureNoFill = "failure_no_fill"
    }

    /// Load stub data for the given scenario
    /// - Parameter scenario: The test scenario to load
    /// - Returns: Decoded BidResponse object
    static func bidResponse(scenario: Scenario) -> BidResponse {
        let data = loadJSON(scenario.rawValue)
        return try! JSONDecoder().decode(BidResponse.self, from: data)
    }

    /// Load raw JSON data for the given scenario
    /// - Parameter scenario: The test scenario to load
    /// - Returns: Raw Data from JSON file
    static func rawData(scenario: Scenario) -> Data {
        return loadJSON(scenario.rawValue)
    }

    // MARK: - Private

    private static func loadJSON(_ name: String) -> Data {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Stubs/AdBidding"),
              let data = try? Data(contentsOf: url) else {
            fatalError("Missing stub file: Stubs/AdBidding/\(name).json")
        }
        return data
    }
}

private final class BundleToken {}
```

### Usage

```swift
// In unit tests
let response = AdBiddingStubFactory.bidResponse(scenario: .success)
let errorResponse = AdBiddingStubFactory.bidResponse(scenario: .failureTimeout)

// Raw data (for URLProtocol stubbing)
let data = AdBiddingStubFactory.rawData(scenario: .success)
```

---

## Layer 3: Mock (Unit Tests)

### Purpose
- Permanent test doubles for unit tests
- Live in Tests target only
- Use StubFactory for data

### Implementation

```swift
// Tests/Mocks/MockAdBiddingService.swift

import Foundation
@testable import MSPCore

final class MockAdBiddingService: AdBiddingServiceProtocol {

    // MARK: - Configuration

    var scenario: AdBiddingStubFactory.Scenario = .success
    var shouldFail: Bool = false
    var customError: Error?

    // MARK: - Call Tracking (Spy behavior)

    private(set) var fetchBidCallCount = 0
    private(set) var lastRequest: BidRequest?

    // MARK: - Protocol Implementation

    func fetchBid(request: BidRequest, completion: @escaping (Result<BidResponse, Error>) -> Void) {
        fetchBidCallCount += 1
        lastRequest = request

        if shouldFail {
            completion(.failure(customError ?? NSError(domain: "Mock", code: -1)))
            return
        }

        let response = AdBiddingStubFactory.bidResponse(scenario: scenario)
        completion(.success(response))
    }
}
```

### Usage in Tests

```swift
class AdBiddingViewModelSpec: QuickSpec {
    override class func spec() {
        describe("AdBiddingViewModel") {
            var sut: AdBiddingViewModel!
            var mockService: MockAdBiddingService!

            beforeEach {
                mockService = MockAdBiddingService()
                sut = AdBiddingViewModel(service: mockService)
            }

            context("when bid succeeds") {
                beforeEach {
                    mockService.scenario = .success
                }

                it("should update state to loaded") {
                    sut.requestBid()
                    expect(sut.state).toEventually(equal(.loaded))
                }

                it("should call service once") {
                    sut.requestBid()
                    expect(mockService.fetchBidCallCount).toEventually(equal(1))
                }
            }

            context("when bid fails with timeout") {
                beforeEach {
                    mockService.scenario = .failureTimeout
                    mockService.shouldFail = true
                }

                it("should show error state") {
                    sut.requestBid()
                    expect(sut.state).toEventually(equal(.error))
                }
            }
        }
    }
}
```

---

## Layer 4: Fake (Development)

### Purpose
- Temporary test doubles when backend is unavailable
- Lives in Sources but only compiled with `ENABLE_STUB_SERVICES` flag
- Can be deleted once backend is ready

### Compiler Flag Setup

In `project.yml.template`:

```yaml
settings:
  base:
    # ... other settings
  configs:
    Debug:
      SWIFT_ACTIVE_COMPILATION_CONDITIONS: DEBUG ENABLE_STUB_SERVICES
    Release:
      SWIFT_ACTIVE_COMPILATION_CONDITIONS: ""
```

### Implementation

```swift
// Sources/Fakes/FakeAdBiddingService.swift

#if ENABLE_STUB_SERVICES

import Foundation

final class FakeAdBiddingService: AdBiddingServiceProtocol {

    var scenario: AdBiddingStubFactory.Scenario = .success
    var artificialDelay: TimeInterval = 0.5  // Simulate network latency

    func fetchBid(request: BidRequest, completion: @escaping (Result<BidResponse, Error>) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + artificialDelay) {
            let response = AdBiddingStubFactory.bidResponse(scenario: self.scenario)
            DispatchQueue.main.async {
                completion(.success(response))
            }
        }
    }
}

#endif
```

### Usage in App (Development Only)

```swift
// Sources/DI/ServiceContainer.swift

final class ServiceContainer {

    static func makeAdBiddingService() -> AdBiddingServiceProtocol {
        #if ENABLE_STUB_SERVICES
        // Use Fake during development when backend unavailable
        return FakeAdBiddingService()
        #else
        // Use real service in production
        return AdBiddingService()
        #endif
    }
}
```

### Cleanup Checklist

When backend is ready:
- [ ] Remove `ENABLE_STUB_SERVICES` from build settings
- [ ] Delete `Sources/Fakes/FakeAdBiddingService.swift`
- [ ] Update `ServiceContainer` to remove `#if` block
- [ ] Keep Mock and StubFactory (permanent for tests)

---

## Generator Script Usage

```bash
# Generate StubFactory for a module
swift Scripts/tools/generate-stub-factory.swift \
    --module AdBidding \
    --model BidResponse \
    --input Tests/Stubs/AdBidding \
    --output Tests/Generated

# Generate for all modules
swift Scripts/tools/generate-stub-factory.swift --all
```

---

## Comparison with Industry Standard

| Concept | Industry Definition | Our Definition |
|---------|---------------------|----------------|
| **Stub** | Object returning preset data | JSON data files |
| **Mock** | Object verifying interactions | Test double using Stub data |
| **Fake** | Simplified working implementation | Dev-time double using Stub data |
| **Spy** | Object recording calls | Built into Mock (call tracking) |
| **Dummy** | Placeholder object | Not used (too simple to formalize) |

Our approach simplifies the 5 industry concepts into 3 layers, with clear separation by **use case** rather than **technical implementation**.

---

## Related Resources

- Test case definitions: `Tests/TestCases/`
- Protocol definition: `Sources/Protocols/`
- Test examples: `Tests/UnitTests/`
- StubFactory generator: `Scripts/tools/generate-stub-factory.swift`
- Test case tool: `Scripts/tools/test-cases.py`
