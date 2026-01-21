# Research: Debug ViewModel Unit Tests

**Feature**: Debug ViewModel Unit Tests
**Date**: 2026-01-21

## Research Summary

All technical questions have been resolved through codebase analysis. No external research required.

---

## Decision 1: Test Framework

**Decision**: Use Quick ~> 7.0 and Nimble ~> 13.0

**Rationale**:
- Mandated by `Sources/constitution.md` Article V.2: "All new unit tests must use the Quick & Nimble framework"
- Already configured in project Podfile
- Existing `PlaceholderSpec.swift` provides pattern to follow

**Alternatives Considered**:
- XCTest: Rejected - Constitution explicitly requires Quick/Nimble for BDD style

---

## Decision 2: Mock Implementation Strategy

**Decision**: Create protocol-conforming mock classes in `Tests/MSPCoreTests/Mocks/Debug/`

**Rationale**:
- All three repositories already have protocol definitions:
  - `DebugSectionsRepository` - `fetchDebugSections(placements:)`
  - `PlacementsRepository` - `fetchPlacementIDs()`
  - `LoadAdRepository` - `loadAd(...)`, `getAd(placementId:)`
- ViewModels accept repositories via initializer injection (dependency injection ready)
- Mocks can be configured with predetermined responses for each test case

**Alternatives Considered**:
- Using real implementations: Rejected - Creates external dependencies, non-deterministic tests
- Subclassing existing services: Rejected - Protocol mocking is cleaner and more explicit

---

## Decision 3: Test File Organization

**Decision**: Create `Tests/MSPCoreTests/Specs/Debug/` directory for test specs

**Rationale**:
- Follows existing convention (`Tests/MSPCoreTests/Specs/`)
- Groups related tests logically
- Separate `Mocks/Debug/` for reusable mock implementations

**Alternatives Considered**:
- Flat structure in Specs/: Rejected - Would clutter existing structure as tests grow
- Mocks inline in test files: Rejected - Reduces reusability

---

## Decision 4: DebugOption Mock Strategy

**Decision**: Create `MockDebugOption` struct implementing `DebugOption` protocol

**Rationale**:
- `DebugOption` is a composition of `DebugDisplayable` and `DebugOptionIdentifiable`
- Required properties: `id: String`, `displayTitle: String`, `isVisible: Bool`
- Simple struct suffices for test data

**Alternatives Considered**:
- Using real AdFormat/AdNetwork: Works for some tests but limits flexibility
- Protocol extension with defaults: Less explicit than dedicated mock

---

## Decision 5: Combine Publisher Testing

**Decision**: Use Nimble's async expectations with `toEventually` matcher

**Rationale**:
- `DebugAdLoadViewModel` uses `@Published` properties and `PassthroughSubject`
- Nimble provides `toEventually` for async assertions
- Can capture published values using Combine sink in test setup

**Alternatives Considered**:
- Manual expectation/fulfillment: More verbose, less readable
- Synchronous testing only: Would miss publisher behavior verification

---

## Decision 6: DebugSection Test Data

**Decision**: Use `DebugSectionData` factory methods to create realistic test data

**Rationale**:
- `DebugSectionData` has factory methods: `adNetworkSection()`, `adFormatSection()`, etc.
- These represent real production configurations including `showCondition` rules
- More reliable than manually constructing test data

**Alternatives Considered**:
- Fully mocked DebugSection: Less realistic, may miss edge cases
- Reading from real service: Creates dependency on `TestDebugSectionsService`

---

## Key Findings from Codebase Analysis

### DebugAdLoadViewModel Dependencies
```swift
init(
    debugSectionsRepository: DebugSectionsRepository = TestDebugSectionsService(),
    placementsRepository: PlacementsRepository = AdConfigPlacementsService(),
    loadAdRepository: LoadAdRepository = TestLoadAdService()
)
```
- All dependencies injectable via initializer
- Default implementations exist but tests should use mocks

### Section Visibility Logic (showCondition)
- `showCondition: Set<String>?` - nil means always visible
- Visibility evaluated via `shouldShowSection(_ section:)`
- Checks if all required IDs in `showCondition` are in current selection
- Example: Creative Type requires `[AdNetwork.nova.rawValue]`
- Example: Layout requires `[AdNetwork.nova.rawValue, AdFormat.interstitial.id]`

### Published Properties to Test
- `@Published sections: [DebugAdLoadSectionViewModel]`
- `toastSignalPublisher: AnyPublisher<ToastSignal, Never>`
- `adPresentationPublisher: AnyPublisher<DebugAdPresentationSignal, Never>`

### AdListener Protocol Methods
- `onError(msg: String)`
- `onAdImpression(ad: MSPAd)`
- `onAdClick(ad: MSPAd)`
- `onAdLoaded(placementId: String)`
- `onAdDismissed(ad: InterstitialAd)`
- `getRootViewController() -> UIViewController?`

---

## No Remaining NEEDS CLARIFICATION Items

All technical decisions resolved through codebase analysis.
