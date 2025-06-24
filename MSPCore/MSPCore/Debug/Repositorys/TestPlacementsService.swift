import Foundation

class TestPlacementsService: PlacementsRepository {
    func fetchPlacements() -> [String] {
        return [
            "Home_Feed_Top",
            "Article_Interstitial",
            "Video_Rewarded",
            "Explore_Banner"
        ]
    }
} 