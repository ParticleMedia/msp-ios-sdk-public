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
        // Start with debug defaults; caller-supplied params take precedence.
        var newCustomParams: [String: Any] = [
            MSPConstants.GOOGLE_AD_MULTI_CONTENT_URLS: [
                "https://www.google.com", "https://newsbreak.com",
            ]
        ]
        if let customParams {
            for (key, value) in customParams {
                newCustomParams[key] = value
            }
        }

        var newTestParams = testParams
        newTestParams["mobilefuse"] = "true"
        let adRequest = AdRequest(
            customParams: newCustomParams,
            geo: nil,
            context: nil,
            adaptiveBannerSize: AdSize(
                width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: false),
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
        adLoader.getAd(placementId: placementId)
    }
}
