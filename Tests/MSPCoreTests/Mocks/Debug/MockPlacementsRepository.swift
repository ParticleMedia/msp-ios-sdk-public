@testable import MSPCore

class MockPlacementsRepository: PlacementsRepository {
    var placementsToReturn: [String] = []
    var fetchCallCount = 0

    func fetchPlacementIDs() -> [String] {
        fetchCallCount += 1
        return placementsToReturn
    }
}
