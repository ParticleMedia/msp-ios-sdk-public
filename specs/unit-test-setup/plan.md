# Implementation Plan: Unit Test Infrastructure Setup

**Branch**: `001-unit-test-setup` | **Date**: 2026-01-20 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-unit-test-setup/spec.md`

## Summary

Setup a comprehensive unit test infrastructure for the MSP iOS SDK using Quick 7.x/Nimble 13.x for BDD-style testing, OHHTTPStubs for network mocking, and protocol-based mocking for internal dependencies. The system will include independent test targets per module (MSPCoreTests, MSPiOSCoreTests, NovaCoreTests, AdapterTests), shared test helpers, JSON fixtures, and GitHub Actions CI integration with 50% coverage enforcement.

## Technical Context

**Language/Version**: Swift 5.0, iOS 15.0+
**Primary Dependencies**: Quick ~> 7.0, Nimble ~> 13.0, OHHTTPStubs/Swift ~> 9.1
**Storage**: N/A (test infrastructure only)
**Testing**: Quick/Nimble (BDD), OHHTTPStubs (network mocking), Protocol-based mocks (internal)
**Target Platform**: iOS 15.0+ (Simulator for testing)
**Project Type**: Mobile SDK with multiple modules
**Performance Goals**: Test suite completes within 5 minutes locally, 30 minutes CI
**Constraints**: Must integrate with existing CocoaPods/XcodeGen workflow, MSPDemoApp as test host
**Scale/Scope**: 4 test targets (MSPCoreTests, MSPiOSCoreTests, NovaCoreTests, AdapterTests), 50% coverage target

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Federal Constitution Compliance

| Article | Requirement | Status | Notes |
|---------|-------------|--------|-------|
| **I.1 (Automation First)** | Manual operations repeated twice must be scripted | ✅ PASS | Test runner script (`run-unit-tests.sh`) automates test execution |
| **I.2 (Deterministic Builds)** | No direct `.xcodeproj` modification; use XcodeGen | ✅ PASS | Test targets defined in `project.yml`, not manual Xcode changes |
| **I.3 (SSOT)** | Root Podfile is authoritative for dependencies | ✅ PASS | Quick/Nimble/OHHTTPStubs versions defined in root Podfile |
| **I.4 (Sanctity of Automation)** | No manual workarounds for build/dependency issues | ✅ PASS | All test setup automated via Podfile and XcodeGen |
| **II.1 (Validation Loop)** | Changes proven by automated validation | ✅ PASS | CI workflow validates all test targets automatically |
| **II.2 (Local Verification)** | Run round-trip-test.sh before commit | ✅ PASS | Tests integrated into existing validation workflow |
| **III.1 (Module Cohesion)** | Core modules cannot import third-party SDK headers | ✅ PASS | Test mocks replace real SDK dependencies |
| **III.2 (Protocol-Oriented Design)** | Adhere to AdNetworkAdapter pattern | ✅ PASS | Mock implementations follow existing protocol patterns |

### Sources Constitution Compliance (Article IV-V)

| Article | Requirement | Status | Notes |
|---------|-------------|--------|-------|
| **IV.3 (Safe Error Handling)** | No force-unwrapping, DocC for public APIs | ✅ PASS | Test helpers use safe optionals |
| **V.1 (TDD Cycle)** | Red-Green-Refactor cycle | ✅ PASS | Quick/Nimble enables TDD workflow |
| **V.2 (Mandatory Testing Framework)** | Must use Quick & Nimble | ✅ PASS | Explicitly required by this feature |

### Tests Constitution Compliance (Article VIII)

| Article | Requirement | Status | Notes |
|---------|-------------|--------|-------|
| **VIII.1 (BDD Style)** | describe-context-it structure | ✅ PASS | Quick provides this structure |
| **VIII.2 (Clear Assertions)** | Use Nimble's expressive matchers | ✅ PASS | Nimble 13.x provides matchers |
| **VIII.3 (No Magic Values)** | Named constants for test values | ✅ PASS | Fixtures and constants used |

### Scripts Constitution Compliance (Article VI)

| Article | Requirement | Status | Notes |
|---------|-------------|--------|-------|
| **VI.1 (Error Handling)** | `set -euo pipefail` in scripts | ✅ PASS | Test runner script follows this |
| **VI.2 (Idempotency)** | Scripts should be idempotent | ✅ PASS | Test script can run multiple times safely |
| **VI.3 (POSIX Compliance)** | Shell scripts POSIX-compliant | ✅ PASS | Script uses POSIX constructs |

**Gate Result**: ✅ ALL GATES PASS - Proceed to Phase 0

## Project Structure

### Documentation (this feature)

```text
specs/001-unit-test-setup/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (N/A for this feature)
├── checklists/
│   └── requirements.md  # Spec validation checklist
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
# Test Infrastructure Structure
Tests/
├── MSPCoreTests/
│   ├── Info.plist
│   ├── Specs/
│   │   └── *.swift              # Quick spec files
│   ├── Mocks/
│   │   └── Mock*.swift          # Protocol-based mocks
│   └── Helpers/
│       └── *.swift              # Module-specific helpers
├── MSPiOSCoreTests/
│   ├── Info.plist
│   ├── Specs/
│   ├── Mocks/
│   └── Helpers/
├── NovaCoreTests/
│   ├── Info.plist
│   ├── Specs/
│   ├── Mocks/
│   └── Helpers/
├── AdapterTests/
│   ├── Info.plist
│   ├── Specs/
│   ├── Mocks/
│   └── Helpers/
├── Shared/
│   ├── TestHelpers.swift        # MSPTestConfiguration, NetworkStub, FixtureLoader
│   ├── NetworkStubs.swift       # OHHTTPStubs wrappers
│   └── AsyncHelpers.swift       # waitUntil extensions
├── Fixtures/
│   ├── bid_response_success.json
│   ├── bid_response_error.json
│   ├── ad_config.json
│   └── *.json                   # Additional fixtures
├── templates/
│   └── unit_test_spec.swift.template  # Existing template
└── constitution.md              # Existing test constitution

# Configuration Files (modifications)
Podfile                          # Add testing_pods function and test targets
Examples/MSPDemoApp/project.yml  # Add test target definitions and AllTests scheme
Configs/xcodegen/
└── test.target_template.yml     # New template for test targets

# CI/CD (new files)
.github/workflows/
└── unit-tests.yml               # New unit test workflow
Scripts/tests/
└── run-unit-tests.sh            # Local test runner script
```

**Structure Decision**: Mobile SDK with test infrastructure. Tests directory at repository root with module-specific subdirectories. Test targets use MSPDemoApp as test host per spec requirements.

## Complexity Tracking

> No constitution violations requiring justification.

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| Separate test targets | 4 targets (MSPCore, MSPiOSCore, NovaCore, Adapters) | Matches module structure, enables parallel CI |
| Shared helpers in Tests/Shared | Single shared location | Avoids duplication, accessible to all targets |
| MSPDemoApp as test host | Required by spec | Provides runtime environment with all dependencies |

---

## Post-Design Constitution Re-Check

*Re-evaluated after Phase 1 design artifacts were generated.*

### Design Artifacts Review

| Artifact | Constitution Compliance | Notes |
|----------|------------------------|-------|
| **research.md** | ✅ PASS | All decisions align with constitution; no violations |
| **data-model.md** | ✅ PASS | Test entities follow protocol-oriented patterns (Art. III.2) |
| **quickstart.md** | ✅ PASS | Documents automated workflows (Art. I.1), uses XcodeGen (Art. I.2) |
| **Project Structure** | ✅ PASS | Uses XcodeGen for test targets (Art. I.2), Podfile SSOT (Art. I.3) |

### Final Gate Status

| Gate | Status | Verification |
|------|--------|--------------|
| No manual .xcodeproj edits | ✅ PASS | All changes via project.yml and Podfile |
| Automation First | ✅ PASS | run-unit-tests.sh, CI workflow defined |
| Protocol-Oriented Mocks | ✅ PASS | Mock pattern follows AdNetworkAdapter |
| BDD Test Structure | ✅ PASS | Quick/Nimble with describe-context-it |
| POSIX Shell Scripts | ✅ PASS | run-unit-tests.sh uses set -euo pipefail |

**Final Result**: ✅ ALL POST-DESIGN GATES PASS - Ready for `/speckit.tasks`

---

## Generated Artifacts

| File | Description | Status |
|------|-------------|--------|
| `spec.md` | Feature specification | ✅ Complete |
| `plan.md` | This implementation plan | ✅ Complete |
| `research.md` | Technical research findings | ✅ Complete |
| `data-model.md` | Test entity definitions | ✅ Complete |
| `quickstart.md` | Developer quickstart guide | ✅ Complete |
| `checklists/requirements.md` | Spec validation checklist | ✅ Complete |

## Next Steps

Run `/speckit.tasks` to generate the implementation task list based on this plan.
