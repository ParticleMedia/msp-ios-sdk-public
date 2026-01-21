@testable import MSPCore

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
