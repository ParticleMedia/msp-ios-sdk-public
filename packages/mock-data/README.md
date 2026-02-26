# Mock Data (JSON Fixtures)

Centralized JSON fixture data for unit and integration tests.

## Structure

```
packages/mock-data/
├── debug/
│   ├── bid_response_success.json
│   ├── bid_response_error.json
│   └── ad_config.json
└── README.md
```

## Naming Convention

`{module}/{scenario}.json`

- **module**: Feature area (e.g., `debug`, `bidding`)
- **scenario**: Descriptive name using underscores (e.g., `bid_response_success`)

## Usage in Tests

```swift
// Load via FixtureLoader (Tests/Shared/FixtureLoader.swift)
let config: AdConfig = try FixtureLoader.load("ad_config.json")
let data = try FixtureLoader.loadData("bid_response_success.json")
```

## Adding New Fixtures

1. Create JSON file in the appropriate subdirectory
2. Follow naming convention: `{scenario}.json`
3. Use realistic but deterministic test data
4. Reference from Swift tests via `FixtureLoader`
