import Foundation
import MSPiOSCore

class LoadAdService: LoadAdRepository {
    private var adLoader: MSPAdLoader?
    
    func loadAd(
        placementId: String,
        adFormat: AdFormat,
        testParams: [String: String],
        adListener: AdListener,
        customParams: [String: Any]? = nil
    ) {
        let adLoader = MSPAdLoader()
        self.adLoader = adLoader
        let adRequest = AdRequest(
            customParams: customParams ?? [:],
            geo: nil,
            context: nil,
            adaptiveBannerSize: AdSize(width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: false),
            adSize: AdSize(width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: false),
            placementId: placementId,
            adFormat: adFormat,
            testParams: testParams
        )
        adLoader.loadAd(
            placementId: placementId,
            adListener: adListener,
            adRequest: adRequest
        )
    }
} 