import Foundation
import MSPiOSCore

class AdConfigPlacementsService: PlacementsRepository {
    /// Retrieves placement IDs from AdConfig
    /// - Returns: Array of placement ID strings
    func fetchPlacementIDs() -> [String] {
        guard let placements = MSPAdConfigManager.shared.adConfig?.placements else {
            return []
        }
        return placements.compactMap { $0.placementId }
    }
}