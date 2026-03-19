import Foundation
import MSPiOSCore

class AdConfigPlacementsService: PlacementsRepository {
    /// Retrieves placement IDs from AdConfig
    /// - Returns: Array of placement ID strings
    func fetchPlacementIDs() -> [String] {
        let placements = MSPAdConfigManager.shared.adConfig?.placements?.compactMap { $0.placementId } ?? []
        return mergeRewardedDebugPlacements(with: placements)
    }
}
