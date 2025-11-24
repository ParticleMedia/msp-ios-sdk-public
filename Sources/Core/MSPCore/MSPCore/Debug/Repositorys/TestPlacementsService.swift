import Foundation
import MSPiOSCore

class TestPlacementsService: PlacementsRepository {
    /// Returns a predefined list of hardcoded placement IDs for testing
    /// - Returns: Array of placement ID strings
    func fetchPlacementIDs() -> [String] {
        return ["test-interstitial-1", "test-banner-2", "test-native-3"]
    }
}
