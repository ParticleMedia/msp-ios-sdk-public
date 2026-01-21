# Quickstart: Debug ViewModel Unit Tests

**Feature**: Debug ViewModel Unit Tests
**Date**: 2026-01-21

## Prerequisites

- Xcode with iOS SDK configured
- CocoaPods installed (`gem install cocoapods`)
- Project in development mode

## Setup

### 1. Ensure Development Mode

```bash
./Scripts/switch-target.sh pods-dev
```

### 2. Install Dependencies

```bash
pod install
```

### 3. Open Workspace

```bash
open MSP.xcworkspace
```

## Running Tests

### From Xcode

1. Select `MSPCoreTests` scheme
2. Press `Cmd + U` to run all tests
3. Or right-click specific test file → "Run Tests"

### From Command Line

```bash
xcodebuild test \
  -workspace MSP.xcworkspace \
  -scheme MSPCoreTests \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

## File Structure

```
Tests/MSPCoreTests/
├── Specs/
│   ├── PlaceholderSpec.swift              # Existing
│   └── Debug/                             # NEW
│       ├── DebugRadioCellViewModelSpec.swift
│       ├── DebugAdLoadSectionViewModelSpec.swift
│       └── DebugAdLoadViewModelSpec.swift
└── Mocks/
    └── Debug/                             # NEW
        ├── MockDebugOption.swift
        ├── MockDebugSection.swift
        ├── MockDebugSectionsRepository.swift
        ├── MockPlacementsRepository.swift
        └── MockLoadAdRepository.swift
```

## Test Pattern

All tests follow Quick/Nimble BDD style per Constitution Article VIII.1:

```swift
import Quick
import Nimble
@testable import MSPCore

class ExampleSpec: QuickSpec {
    override class func spec() {
        describe("ComponentName") {
            var sut: ComponentType!
            var mockDependency: MockDependency!

            beforeEach {
                mockDependency = MockDependency()
                sut = ComponentType(dependency: mockDependency)
            }

            context("when condition") {
                it("should behavior") {
                    expect(sut.property).to(equal(expected))
                }
            }
        }
    }
}
```

## Validation

After implementation, run the round-trip test:

```bash
./Scripts/target-switching/round-trip-test.sh
```

## Quick Reference

| Task | Command |
|------|---------|
| Run all tests | `Cmd + U` in Xcode |
| Run single test | Click diamond next to `it()` |
| View coverage | `Cmd + 9` → Coverage tab |
| Re-run failed | `Ctrl + Option + Cmd + G` |
