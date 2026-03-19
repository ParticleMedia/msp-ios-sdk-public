import Foundation

protocol PlacementsRepository {
    func fetchPlacementIDs() -> [String]
}

extension PlacementsRepository {
    static var rewardedDebugPlacements: [String] {
        [
            "demo-android-rewarded",
            "demo-ios-rewarded",
        ]
    }

    func mergeRewardedDebugPlacements(with placements: [String]) -> [String] {
        var merged = placements
        for placement in Self.rewardedDebugPlacements where !merged.contains(placement) {
            merged.append(placement)
        }
        return merged
    }
}
