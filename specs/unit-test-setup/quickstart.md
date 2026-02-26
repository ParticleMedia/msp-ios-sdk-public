# Quickstart: Unit Test Infrastructure

**Feature Branch**: `001-unit-test-setup`
**Date**: 2026-01-20

## Prerequisites

- Xcode 15.4+
- CocoaPods installed (`gem install cocoapods`)
- iOS 15.0+ Simulator available

## Setup

### 1. Install Dependencies

```bash
# From repository root
pod install
```

This installs Quick, Nimble, and OHHTTPStubs for all test targets.

### 2. Generate Project (if needed)

```bash
# If project.yml was modified
cd Examples/MSPDemoApp
xcodegen generate
```

### 3. Open Workspace

```bash
open msp-ios-sdk.xcworkspace
```

## Running Tests

### Option A: Command Line (Recommended)

```bash
# Run all tests
./Scripts/tests/run-unit-tests.sh

# Run specific scheme
./Scripts/tests/run-unit-tests.sh --scheme MSPCoreTests

# Run with coverage threshold
./Scripts/tests/run-unit-tests.sh --threshold 0.50
```

### Option B: Xcode

1. Open `msp-ios-sdk.xcworkspace`
2. Select `MSPTests` scheme
3. Press `Cmd+U` to run tests

### Option C: xcodebuild

```bash
xcodebuild test \
  -workspace msp-ios-sdk.xcworkspace \
  -scheme MSPTests \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5'
```

## Writing Tests

### 1. Create a Spec File

Location: `Tests/{Module}Tests/Specs/{ClassName}Spec.swift`

```swift
import Quick
import Nimble
@testable import MSPCore

class BidLoaderSpec: QuickSpec {
    override class func spec() {
        describe("BidLoader") {
            var sut: BidLoader!

            beforeEach {
                sut = BidLoader()
            }

            afterEach {
                sut = nil
            }

            describe("initialization") {
                it("should be created successfully") {
                    expect(sut).notTo(beNil())
                }
            }

            context("when loading a bid") {
                beforeEach {
                    NetworkStub.stubSuccess(
                        path: "/v1/bid",
                        jsonFile: "bid_response_success"
                    )
                }

                it("should return a valid bid") {
                    waitUntil(timeout: .seconds(5)) { done in
                        sut.loadBid(adUnitId: "test") { result in
                            expect(result).to(beSuccess())
                            done()
                        }
                    }
                }
            }
        }
    }
}
```

### 2. Create a Mock

Location: `Tests/{Module}Tests/Mocks/Mock{Protocol}.swift`

```swift
import Foundation
@testable import MSPCore

class MockAdNetworkAdapter: AdNetworkAdapter {
    // MARK: - Spy Properties
    var loadAdCallCount = 0
    var lastAdRequest: MSPAdRequest?

    // MARK: - Stub Properties
    var stubbedLoadResult: Result<MSPAd, MSPError> = .failure(.notReady)

    // MARK: - Protocol Implementation
    func loadAd(request: MSPAdRequest, completion: @escaping (Result<MSPAd, MSPError>) -> Void) {
        loadAdCallCount += 1
        lastAdRequest = request
        completion(stubbedLoadResult)
    }

    // MARK: - Reset
    func reset() {
        loadAdCallCount = 0
        lastAdRequest = nil
        stubbedLoadResult = .failure(.notReady)
    }
}
```

### 3. Add a Fixture

Location: `Tests/Fixtures/{entity}_{scenario}.json`

```json
{
  "bidId": "test-bid-123",
  "adUnitId": "test-unit",
  "price": 2.50,
  "currency": "USD"
}
```

### 4. Use Network Stubs

```swift
import OHHTTPStubs
import OHHTTPStubsSwift

// Success stub
NetworkStub.stubSuccess(path: "/v1/bid", jsonFile: "bid_response_success")

// Error stub
NetworkStub.stubError(path: "/v1/bid", statusCode: 500)

// Timeout stub
NetworkStub.stubTimeout(path: "/v1/bid")
```

## Shared Helpers

### FixtureLoader

```swift
// Load as Decodable
let bid: BidResponse = FixtureLoader.load("bid_response_success", as: BidResponse.self)

// Load as raw Data
let data = FixtureLoader.loadData("bid_response_success")
```

### NetworkStub

```swift
// Stub success response
NetworkStub.stubSuccess(path: "/api/endpoint", jsonFile: "response", statusCode: 200)

// Stub error response
NetworkStub.stubError(path: "/api/endpoint", statusCode: 404)

// Stub timeout
NetworkStub.stubTimeout(path: "/api/endpoint")
```

### Async Testing

```swift
// waitUntil for async operations
waitUntil(timeout: .seconds(5)) { done in
    asyncOperation { result in
        expect(result).to(beSuccess())
        done()
    }
}

// toEventually for polling assertions
expect(viewModel.isLoading).toEventually(beFalse(), timeout: .seconds(3))
```

## Test Structure

```
Tests/
├── MSPCoreTests/
│   ├── Specs/           # Quick spec files
│   ├── Mocks/           # Protocol mocks
│   └── Helpers/         # Module-specific helpers
├── MSPiOSCoreTests/
│   └── ...
├── NovaCoreTests/
│   └── ...
├── AdapterTests/
│   └── ...
├── Shared/              # Common utilities
│   ├── TestHelpers.swift
│   ├── NetworkStubs.swift
│   └── AsyncHelpers.swift
└── Fixtures/            # JSON test data
    └── *.json
```

## CI Integration

Tests run automatically on:
- Push to `main`, `develop`, `feature/**`
- Pull requests to `main`, `develop`

### Coverage Requirements

- **Threshold**: 50% line coverage
- **Report**: Generated in `coverage.json`
- **Failure**: CI fails if coverage < 50%

## Common Issues

### Tests Not Running

1. Check scheme is set to `MSPTests`
2. Verify `pod install` completed successfully
3. Check simulator is available

### Stubs Not Working

1. Ensure `HTTPStubs.removeAllStubs()` in `afterEach`
2. Verify path matches exactly (use `pathEndsWith`)
3. Check fixture file exists in bundle

### Coverage Not Reported

1. Add `-enableCodeCoverage YES` to xcodebuild
2. Verify TestResults.xcresult is generated
3. Run `xcrun xccov view --report TestResults.xcresult`

## Next Steps

1. Run `./Scripts/tests/run-unit-tests.sh` to verify setup
2. Create your first spec file for a module
3. Add fixtures for your test scenarios
4. Write tests following BDD structure
