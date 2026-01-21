# Data Model: Debug ViewModel Unit Tests

**Feature**: Debug ViewModel Unit Tests
**Date**: 2026-01-21

## Overview

This document defines the mock implementations and test data structures needed for unit testing the Debug ViewModels. These are **test-only** constructs and do not modify production code.

---

## Mock Implementations

### 1. MockDebugOption

**Purpose**: Simple implementation of `DebugOption` for test data

```swift
struct MockDebugOption: DebugOption {
    let id: String
    let displayTitle: String
    let isVisible: Bool

    init(id: String, displayTitle: String, isVisible: Bool = true) {
        self.id = id
        self.displayTitle = displayTitle
        self.isVisible = isVisible
    }
}
```

**Usage**: Creating test options for sections without depending on real `AdFormat`/`AdNetwork` types.

---

### 2. MockDebugSection

**Purpose**: Simple implementation of `DebugSection` for configurable test sections

```swift
struct MockDebugSection: DebugSection {
    let id: String
    let title: String
    let options: [DebugOption]
    let showCondition: Set<String>?

    init(
        id: String,
        title: String,
        options: [DebugOption],
        showCondition: Set<String>? = nil
    ) {
        self.id = id
        self.title = title
        self.options = options
        self.showCondition = showCondition
    }
}
```

---

### 3. MockDebugSectionsRepository

**Purpose**: Configurable repository that returns predetermined sections

```swift
class MockDebugSectionsRepository: DebugSectionsRepository {
    var sectionsToReturn: [DebugSection] = []
    var fetchCallCount = 0
    var lastFetchedPlacements: [String]?

    func fetchDebugSections(placements: [String]) -> [DebugSection] {
        fetchCallCount += 1
        lastFetchedPlacements = placements
        return sectionsToReturn
    }
}
```

**Configuration Options**:
- `sectionsToReturn`: Set before test to control returned sections
- `fetchCallCount`: Verify repository was called
- `lastFetchedPlacements`: Verify correct placements passed

---

### 4. MockPlacementsRepository

**Purpose**: Returns configurable placement IDs

```swift
class MockPlacementsRepository: PlacementsRepository {
    var placementsToReturn: [String] = []
    var fetchCallCount = 0

    func fetchPlacementIDs() -> [String] {
        fetchCallCount += 1
        return placementsToReturn
    }
}
```

---

### 5. MockLoadAdRepository

**Purpose**: Configurable ad loading behavior for testing callbacks

```swift
class MockLoadAdRepository: LoadAdRepository {
    var loadAdCallCount = 0
    var lastLoadedPlacementId: String?
    var lastLoadedAdFormat: AdFormat?
    var lastLoadedTestParams: [String: String]?
    var lastAdListener: AdListener?

    // Configurable behavior
    var shouldSucceed = true
    var errorMessage = "Mock error"
    var mockAd: MSPAd?
    var storedAds: [String: MSPAd] = [:]

    func loadAd(
        placementId: String,
        adFormat: AdFormat,
        testParams: [String: String],
        adListener: AdListener,
        customParams: [String: Any]?
    ) {
        loadAdCallCount += 1
        lastLoadedPlacementId = placementId
        lastLoadedAdFormat = adFormat
        lastLoadedTestParams = testParams
        lastAdListener = adListener

        // Simulate async callback
        if shouldSucceed {
            if let ad = mockAd {
                storedAds[placementId] = ad
            }
            adListener.onAdLoaded(placementId: placementId)
        } else {
            adListener.onError(msg: errorMessage)
        }
    }

    func getAd(placementId: String) -> MSPAd? {
        return storedAds[placementId]
    }
}
```

---

## Test Constants

**Purpose**: Named constants per Constitution Article VIII.3 (No Magic Values)

```swift
enum TestConstants {
    enum Placements {
        static let placement1 = "test_placement_1"
        static let placement2 = "test_placement_2"
        static let invalidPlacement = "invalid_placement"
    }

    enum SectionIds {
        static let placement = "placement"
        static let adNetwork = "adNetwork"
        static let adFormat = "adFormat"
        static let creativeType = "creativeType"
        static let layout = "layout"
    }

    enum OptionIds {
        static let nova = "nova"
        static let banner = "banner"
        static let interstitial = "interstitial"
        static let native = "native"
    }

    enum Messages {
        static let loadingMessage = "Loading..."
        static let successMessage = "Ad loaded successfully"
        static let errorMessage = "Test error message"
    }
}
```

---

## Test Data Factories

**Purpose**: Create consistent, realistic test data

```swift
enum TestDataFactory {
    /// Creates a basic section with simple options
    static func createSimpleSection(
        id: String,
        title: String,
        optionCount: Int,
        showCondition: Set<String>? = nil
    ) -> MockDebugSection {
        let options = (0..<optionCount).map { index in
            MockDebugOption(
                id: "\(id)_option_\(index)",
                displayTitle: "Option \(index)"
            )
        }
        return MockDebugSection(
            id: id,
            title: title,
            options: options,
            showCondition: showCondition
        )
    }

    /// Creates sections mimicking production structure
    static func createProductionLikeSections(placements: [String]) -> [DebugSection] {
        return [
            DebugSectionData.placementSection(placements: placements),
            DebugSectionData.adNetworkSection(),
            DebugSectionData.adFormatSection(),
            DebugSectionData.creativeTypeSection(),
            DebugSectionData.layoutSection(),
            DebugSectionData.highEngagementSection()
        ]
    }

    /// Creates minimal viable sections for basic tests
    static func createMinimalSections() -> [MockDebugSection] {
        return [
            createSimpleSection(id: "section1", title: "Section 1", optionCount: 2),
            createSimpleSection(id: "section2", title: "Section 2", optionCount: 3)
        ]
    }
}
```

---

## Entity Relationships

```
MockDebugSectionsRepository
    └── returns: [MockDebugSection]
                      └── contains: [MockDebugOption]

MockPlacementsRepository
    └── returns: [String] (placement IDs)

MockLoadAdRepository
    └── stores: [String: MSPAd]
    └── notifies: AdListener (callback)

DebugAdLoadViewModel
    ├── uses: DebugSectionsRepository (mocked)
    ├── uses: PlacementsRepository (mocked)
    ├── uses: LoadAdRepository (mocked)
    └── creates: [DebugAdLoadSectionViewModel]
                      └── creates: [DebugRadioCellViewModel]
```

---

## Validation Rules

| Entity | Rule | Test Verification |
|--------|------|-------------------|
| MockDebugOption | `id` must be non-empty | Enforced by test setup |
| MockDebugSection | `options` can be empty | Test edge case handling |
| MockLoadAdRepository | `storedAds` cleared between tests | `beforeEach` reset |
| MockDebugSectionsRepository | `sectionsToReturn` configured per test | `beforeEach` setup |
