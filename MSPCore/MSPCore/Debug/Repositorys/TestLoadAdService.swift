import Foundation
import MSPiOSCore

class TestLoadAdService: LoadAdRepository {
    private lazy var adLoader = MSPAdLoader()
    
    func loadAd(
        placementId: String,
        adFormat: AdFormat,
        testParams: [String: String],
        adListener: AdListener,
        customParams: [String: Any]? = nil
    ) {
        var newCustomParams = [String: Any]()
        if let customParams {
            newCustomParams = customParams
        } else {
            newCustomParams[MSPConstants.GOOGLE_AD_MULTI_CONTENT_URLS] = ["https://www.google.com", "https://newsbreak.com"]
        }
        
        var newTestParams = testParams
        newTestParams["mobilefuse"] = "true"
        let adRequest = AdRequest(
            customParams: newCustomParams,
            geo: nil,
            context: nil,
            adaptiveBannerSize: AdSize(width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: false),
            adSize: AdSize(width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: false),
            placementId: placementId,
            adFormat: adFormat,
            testParams: newTestParams
        )
        adLoader.loadAd(
            placementId: placementId,
            adListener: adListener,
            adRequest: adRequest
        )
    }
    
    func getAd(placementId: String) -> MSPAd? {
        return adLoader.getAd(placementId: placementId)
    }
} 
