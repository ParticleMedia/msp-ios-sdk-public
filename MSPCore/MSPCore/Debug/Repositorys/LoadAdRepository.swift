import Foundation
import MSPiOSCore

protocol LoadAdRepository {
    func loadAd(
        placementId: String,
        adFormat: AdFormat,
        testParams: [String: String],
        adListener: AdListener,
        customParams: [String: Any]?
    )

    func getAd(placementId: String) -> MSPAd?
} 