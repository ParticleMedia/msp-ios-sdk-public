# Data Model: Unit Test Infrastructure

**Feature Branch**: `001-unit-test-setup`
**Date**: 2026-01-20

## Overview

This document defines the key entities, relationships, and structures for the unit test infrastructure. Since this is a test infrastructure feature, the "data model" describes test artifacts rather than runtime data.

---

## Core Entities

### 1. TestTarget

Represents a unit test bundle that tests a specific SDK module.

| Property | Type | Description |
|----------|------|-------------|
| name | String | Target name (e.g., "MSPCoreTests") |
| moduleName | String | Module being tested (e.g., "MSPCore") |
| testHost | String | Host application ("MSPDemoApp") |
| sources | [Path] | Paths to test source files |
| dependencies | [String] | Pod/framework dependencies |

**Instances**:
- MSPCoreTests → tests MSPCore
- MSPiOSCoreTests → tests MSPiOSCore
- NovaCoreTests → tests NovaCore
- AdapterTests → tests all adapters

**Relationships**:
- TestTarget **depends on** TestHost (MSPDemoApp)
- TestTarget **contains** SpecFiles, Mocks, Helpers
- TestTarget **uses** SharedHelpers

---

### 2. SpecFile

A Quick test specification file following BDD structure.

| Property | Type | Description |
|----------|------|-------------|
| className | String | Spec class name (e.g., "BidLoaderSpec") |
| moduleName | String | Module under test |
| describes | [String] | describe blocks (components) |
| contexts | [Context] | context blocks (scenarios) |
| examples | [Example] | it blocks (individual tests) |

**Structure**:
```
SpecFile
├── describe("ComponentName")
│   ├── beforeEach { setup }
│   ├── afterEach { teardown }
│   ├── describe("initialization")
│   │   └── it("should ...") { assertion }
│   └── context("when condition")
│       ├── beforeEach { condition setup }
│       └── it("should ...") { assertion }
```

**Naming Convention**: `{ClassName}Spec.swift`

---

### 3. Mock

A test double implementing a protocol for testing purposes.

| Property | Type | Description |
|----------|------|-------------|
| name | String | Mock class name (e.g., "MockAdNetworkAdapter") |
| protocol | String | Protocol being mocked |
| spyProperties | [SpyProperty] | Call tracking properties |
| stubProperties | [StubProperty] | Return value configuration |

**SpyProperty Structure**:
| Property | Type | Description |
|----------|------|-------------|
| name | String | e.g., "loadAdCallCount" |
| type | String | e.g., "Int" |
| defaultValue | Any | e.g., 0 |

**StubProperty Structure**:
| Property | Type | Description |
|----------|------|-------------|
| name | String | e.g., "stubbedLoadResult" |
| type | String | e.g., "Result<MSPAd, MSPError>" |
| defaultValue | Any | e.g., ".failure(.notReady)" |

**Naming Convention**: `Mock{ProtocolName}.swift`

---

### 4. Fixture

JSON data files used for test data.

| Property | Type | Description |
|----------|------|-------------|
| filename | String | e.g., "bid_response_success" |
| extension | String | "json" |
| schema | String | Expected data structure |
| usage | String | Test scenario description |

**Fixtures Catalog**:

| Filename | Schema | Usage |
|----------|--------|-------|
| `bid_response_success.json` | BidResponse | Successful bid loading |
| `bid_response_error.json` | ErrorResponse | Error handling |
| `ad_config.json` | AdConfiguration | Config initialization |
| `adapter_init_success.json` | AdapterConfig | Adapter setup |
| `timeout_response.json` | N/A | Timeout scenario (empty) |

**Naming Convention**: `{entity}_{scenario}.json`

---

### 5. NetworkStub

OHHTTPStubs configuration for intercepting network requests.

| Property | Type | Description |
|----------|------|-------------|
| condition | Matcher | URL matching condition |
| response | StubResponse | Response to return |
| statusCode | Int32 | HTTP status code |
| headers | [String: String] | Response headers |

**Response Types**:
| Type | Description |
|------|-------------|
| Success | JSON fixture with 200 status |
| Error | Error status (4xx, 5xx) |
| Timeout | Network timeout error |

---

### 6. TestHelper

Shared utility code for common test operations.

| Component | Purpose |
|-----------|---------|
| MSPTestConfiguration | Quick global hooks (stub reset) |
| NetworkStub | OHHTTPStubs convenience methods |
| FixtureLoader | JSON fixture loading |
| AsyncHelpers | waitUntil extensions |

---

## Entity Relationships

```
┌─────────────────────────────────────────────────────────────────┐
│                        TestTarget                                │
│  (MSPCoreTests, MSPiOSCoreTests, NovaCoreTests, AdapterTests)   │
└─────────────────────────────────────────────────────────────────┘
         │                    │                    │
         │ contains           │ contains           │ contains
         ▼                    ▼                    ▼
    ┌─────────┐         ┌─────────┐         ┌─────────┐
    │SpecFile │         │  Mock   │         │ Helper  │
    │ (Specs/)│         │(Mocks/) │         │(Helpers)│
    └─────────┘         └─────────┘         └─────────┘
         │                    │
         │ uses               │ uses
         ▼                    ▼
    ┌─────────────────────────────────────────┐
    │           Shared (Tests/Shared/)         │
    │  TestHelpers, NetworkStubs, Fixtures     │
    └─────────────────────────────────────────┘
         │                    │
         │ uses               │ loads
         ▼                    ▼
    ┌────────────┐       ┌────────────┐
    │NetworkStub │       │  Fixture   │
    │(OHHTTPStub)│       │ (JSON)     │
    └────────────┘       └────────────┘
```

---

## State Transitions

### Test Execution State

```
┌──────────┐    beforeSuite    ┌─────────────┐
│   IDLE   │ ───────────────▶  │   SETUP     │
└──────────┘                   └─────────────┘
                                     │
                               beforeEach
                                     ▼
                               ┌─────────────┐
                               │  RUNNING    │
                               │  (it block) │
                               └─────────────┘
                                     │
                                afterEach
                                     ▼
                               ┌─────────────┐
                               │   CLEANUP   │
                               └─────────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    ▼                                 ▼
            ┌─────────────┐                   ┌─────────────┐
            │   PASSED    │                   │   FAILED    │
            └─────────────┘                   └─────────────┘
```

### Network Stub Lifecycle

```
┌────────────┐    stub()     ┌────────────┐    request    ┌────────────┐
│  NO_STUB   │ ───────────▶  │  STUBBED   │ ───────────▶  │ INTERCEPTED│
└────────────┘               └────────────┘               └────────────┘
                                   │                            │
                             removeAllStubs              return response
                                   ▼                            ▼
                             ┌────────────┐              ┌────────────┐
                             │  CLEARED   │              │  RETURNED  │
                             └────────────┘              └────────────┘
```

---

## Validation Rules

### SpecFile Validation
- Must have at least one `describe` block
- Each `describe` must have at least one `it` block
- `beforeEach`/`afterEach` must be paired with cleanup
- No magic values - use constants or fixtures

### Mock Validation
- Must implement all protocol methods
- Spy properties must be resetable
- Stub properties must have safe defaults

### Fixture Validation
- Must be valid JSON
- Must match expected schema
- File must exist in Tests/Fixtures/

### Network Stub Validation
- Must be removed after test (in afterEach)
- Must not conflict with other stubs
- Timeout stubs must use NSURLErrorTimedOut
