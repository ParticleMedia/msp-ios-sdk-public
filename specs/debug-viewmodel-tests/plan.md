# Implementation Plan: Debug ViewModel Unit Tests

**Branch**: `debug-viewmodel-tests` | **Date**: 2026-01-21 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/debug-viewmodel-tests/spec.md`

## Summary

Add comprehensive unit tests for three Debug ViewModels (`DebugAdLoadViewModel`, `DebugAdLoadSectionViewModel`, `DebugRadioCellViewModel`) using Quick/Nimble BDD framework. Tests will verify business logic including section visibility, selection state management, test parameter generation, and AdListener callback handling through mocked repository dependencies.

## Technical Context

**Language/Version**: Swift 5.0
**Primary Dependencies**: Quick ~> 7.0, Nimble ~> 13.0, Combine
**Storage**: N/A (unit tests only)
**Testing**: Quick & Nimble (BDD style) - mandated by `Sources/constitution.md` Article V.2
**Target Platform**: iOS 15.0+
**Project Type**: Mobile SDK - Tests in `Tests/MSPCoreTests/`
**Performance Goals**: N/A (unit tests)
**Constraints**: Tests must run in isolation without network calls
**Scale/Scope**: 3 ViewModels, ~15-20 test specs

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Article | Requirement | Status | Notes |
|---------|-------------|--------|-------|
| Federal I.2 (Deterministic Builds) | No direct .xcodeproj modification | PASS | Test files added to existing target via XcodeGen glob patterns |
| Federal II.1 (Validation Loop) | Changes must pass automated validation | PASS | Tests themselves are validation |
| Federal III.2 (Protocol-Oriented) | Use protocols for dependencies | PASS | Mock via existing protocols: `LoadAdRepository`, `PlacementsRepository`, `DebugSectionsRepository` |
| Sources IV.3 (Safe Error Handling) | No force unwraps | PASS | Use Nimble matchers for assertions |
| Sources V.1 (TDD Cycle) | Red-Green-Refactor | N/A | Testing existing code, not TDD for new feature |
| Sources V.2 (Quick & Nimble) | Must use Quick & Nimble | PASS | Mandated framework |
| Tests VIII.1 (BDD Style) | describe-context-it structure | PASS | Will follow established pattern |
| Tests VIII.2 (Clear Assertions) | Nimble expressive matchers | PASS | Will use expect/to matchers |
| Tests VIII.3 (No Magic Values) | Named constants for test data | PASS | Will define TestConstants enum |

**Post-Design Re-Check**: All gates PASS. No complexity justification needed.

## Project Structure

### Documentation (this feature)

```text
specs/debug-viewmodel-tests/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Mock structure definitions
├── quickstart.md        # Getting started guide
└── checklists/
    └── requirements.md  # Validation checklist
```

### Source Code (repository root)

```text
Tests/MSPCoreTests/
├── Specs/
│   ├── PlaceholderSpec.swift          # Existing placeholder
│   └── Debug/                         # NEW: Debug ViewModels tests
│       ├── DebugAdLoadViewModelSpec.swift
│       ├── DebugAdLoadSectionViewModelSpec.swift
│       └── DebugRadioCellViewModelSpec.swift
└── Mocks/                             # NEW: Mock implementations
    └── Debug/
        ├── MockDebugSectionsRepository.swift
        ├── MockPlacementsRepository.swift
        ├── MockLoadAdRepository.swift
        └── MockDebugOption.swift
```

**Structure Decision**: Tests placed in `Tests/MSPCoreTests/Specs/Debug/` following existing pattern. Mocks in dedicated `Mocks/Debug/` folder for reusability.

## Complexity Tracking

> No violations requiring justification. Implementation uses existing patterns.

## Test Coverage Matrix

| ViewModel | Test Category | Test Cases |
|-----------|---------------|------------|
| **DebugRadioCellViewModel** | Initialization | id, title from DebugOption |
| | Selection State | setSelected, isSelectedPublisher |
| **DebugAdLoadSectionViewModel** | Initialization | from DebugSection, cellViewModels created |
| | Selection | selectCell, selectedCell, selectedIndex |
| | Visibility | visible getter/setter |
| | Access | cellViewModel(at:), numberOfCells |
| **DebugAdLoadViewModel** | Initialization | sections created, default selections set |
| | Section Visibility | showCondition logic, Nova/Interstitial combos |
| | Selection | selectOption updates visibility |
| | Test Parameters | getTestParameters returns correct JSON |
| | Ad Loading | loadAd with valid/invalid selections |
| | AdListener | onAdLoaded, onError, onAdDismissed signals |
| | Publishers | toastSignalPublisher, adPresentationPublisher |

## Dependencies

### Required Imports in Test Files

```swift
import Quick
import Nimble
import Combine
@testable import MSPCore
@testable import MSPiOSCore  // For AdFormat, AdNetwork, etc.
```

### Mock Dependencies

1. **MockDebugSectionsRepository**: Returns configurable sections
2. **MockPlacementsRepository**: Returns configurable placement IDs
3. **MockLoadAdRepository**: Configurable loadAd behavior, stored ads
4. **MockDebugOption**: Simple struct implementing DebugOption protocol
