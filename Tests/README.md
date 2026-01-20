# MSP iOS SDK - Unit Tests

This directory contains the unit test infrastructure for the MSP iOS SDK, using Quick/Nimble for BDD-style testing.

## Test Structure

```
Tests/
├── MSPCoreTests/          # Tests for MSPCore module
│   ├── Specs/             # Quick spec files
│   ├── Mocks/             # Protocol-based mocks
│   └── Helpers/           # Module-specific test helpers
├── MSPiOSCoreTests/       # Tests for MSPiOSCore module
├── NovaCoreTests/         # Tests for NovaCore module
├── AdapterTests/          # Tests for adapter modules
├── Shared/                # Shared test utilities
│   ├── TestHelpers.swift  # MSPTestConfiguration (global hooks)
│   ├── NetworkStubs.swift # OHHTTPStubs convenience methods
│   ├── FixtureLoader.swift # JSON fixture loading utilities
│   └── AsyncHelpers.swift # Async/await test helpers
├── Fixtures/              # JSON test data files
│   ├── bid_response_success.json
│   ├── bid_response_error.json
│   └── ad_config.json
└── templates/             # Test file templates
    └── unit_test_spec.swift.template
```

## Running Tests

### Command Line

```bash
# Run all tests
./Scripts/tests/run-unit-tests.sh

# Run specific scheme
./Scripts/tests/run-unit-tests.sh MSPCoreTests

# Or use xcodebuild directly
xcodebuild test \
  -workspace msp-ios-sdk.xcworkspace \
  -scheme AllTests \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Xcode

1. Open `msp-ios-sdk.xcworkspace`
2. Select `AllTests` scheme
3. Press `Cmd+U` to run tests

## Writing Tests

### Basic Test Structure

```swift
import Quick
import Nimble

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
                it("should return a valid bid") {
                    // Test implementation
                }
            }
        }
    }
}
```

### Network Stubbing

```swift
// Stub success response
NetworkStub.stubSuccess(
    path: "/v1/bid",
    jsonFile: "bid_response_success"
)

// Stub error response
NetworkStub.stubError(
    path: "/v1/bid",
    statusCode: 500
)

// Stub timeout
NetworkStub.stubTimeout(path: "/v1/bid")
```

### Using Fixtures

```swift
// Load JSON fixture
let data = try! FixtureLoader.loadData("bid_response_success.json")

// Or decode directly
struct BidResponse: Decodable { ... }
let response: BidResponse = try! FixtureLoader.load("bid_response_success.json")
```

### Async Testing

```swift
// Using waitUntil
waitUntil(timeout: .seconds(5)) { done in
    asyncOperation { result in
        expect(result).to(beSuccess())
        done()
    }
}

// Using toEventually
expect(viewModel.isLoading).toEventually(beFalse(), timeout: .seconds(3))
```

## Dependencies

- **Quick** ~> 7.0 - BDD testing framework
- **Nimble** ~> 13.0 - Matcher framework
- **OHHTTPStubs** ~> 9.1 - Network stubbing

## CI Integration

Tests run automatically on:
- Push to `main`, `develop`, `feature/**` branches
- Pull requests to `main`, `develop` branches

**Coverage Requirement**: 50% line coverage

## Best Practices

1. **Test Structure**: Use `describe`-`context`-`it` hierarchy
2. **Setup/Teardown**: Always clean up in `afterEach`
3. **Network Stubs**: Reset stubs in global `beforeEach` (automatic via MSPTestConfiguration)
4. **Fixtures**: Use JSON fixtures for test data, no magic values
5. **Mocks**: Follow protocol-based mock pattern with spy/stub properties
6. **Naming**: Spec files end with `Spec.swift`, mock files start with `Mock`

## Troubleshooting

### Tests Not Running

1. Check scheme is set to `AllTests`
2. Run `pod install` if dependencies are missing
3. Verify simulator is available

### Network Stubs Not Working

1. Ensure `HTTPStubs.removeAllStubs()` in `afterEach`
2. Verify path matches exactly (use `pathEndsWith`)
3. Check fixture file exists in bundle

### Module Import Errors

1. Run `pod install` to install test frameworks
2. Clean build folder (`Cmd+Shift+K` in Xcode)
3. Verify test target dependencies in `project.yml`

## Contributing

When adding tests:
1. Place spec files in appropriate module's `Specs/` directory
2. Add mocks to module's `Mocks/` directory
3. Share fixtures in `Tests/Fixtures/`
4. Update this README if adding new patterns or utilities
