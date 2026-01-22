import MSPiOSCore

@testable import MSPCore

class MockLoadAdRepository: LoadAdRepository {
    var loadAdCallCount = 0
    var lastLoadedPlacementId: String?
    var lastLoadedAdFormat: AdFormat?
    var lastLoadedTestParams: [String: String]?
    var lastAdListener: AdListener?

    var shouldSucceed = true
    var errorMessage = "Mock error"
    var mockAd: MSPAd?
    var storedAds: [String: MSPAd] = [:]

    func loadAd(
        placementId: String,
        adFormat: AdFormat,
        testParams: [String: String],
        adListener: AdListener,
        customParams: [String: Any]?
    ) {
        loadAdCallCount += 1
        lastLoadedPlacementId = placementId
        lastLoadedAdFormat = adFormat
        lastLoadedTestParams = testParams
        lastAdListener = adListener

        if shouldSucceed {
            if let ad = mockAd {
                storedAds[placementId] = ad
            }
            adListener.onAdLoaded(placementId: placementId)
        } else {
            adListener.onError(msg: errorMessage)
        }
    }

    func getAd(placementId: String) -> MSPAd? {
        storedAds[placementId]
    }
}
