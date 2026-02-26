// Meszaros Type: Mock (Stub + Spy)
// - Stub: placementsToReturn provides canned responses
// - Spy: fetchCallCount records interactions
@testable import MSPCore

class MockPlacementsRepository: PlacementsRepository {
    var placementsToReturn: [String] = []
    var fetchCallCount = 0

    func fetchPlacementIDs() -> [String] {
        fetchCallCount += 1
        return placementsToReturn
    }
}
