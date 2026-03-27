import UIKit

@testable import MSPiOSCore

final class SpyAdMetricReporter: AdMetricReporter {
    var logAdImpressionCallCount = 0
    var logAdClickCallCount = 0

    func logAdImpression(ad: MSPAd, adRequest: AdRequest, bidResponse: Any?) {
        logAdImpressionCallCount += 1
    }

    func logAdClick(ad: MSPAd, adRequest: AdRequest, bidResponse: Any?) {
        logAdClickCallCount += 1
    }

    func logGetAdFromCache(cacheKey: String, fill: Bool, ad: MSPAd?) {}
    func logAdResult(placementId: String, ad: MSPAd?, fill: Bool, isFromCache: Bool) {}
    func logAdHide(
        ad: MSPAd, adRequest: AdRequest, bidResponse: Any?, reason: String,
        adScreenShot: Data?, fullScreenShot: Data?
    ) {}
    func logAdReport(
        ad: MSPAd, adRequest: AdRequest, bidResponse: Any?, reason: String, description: String?,
        adScreenShot: Data?, fullScreenShot: Data?
    ) {}
    func logAdResponse(ad: MSPAd?, adRequest: AdRequest, errorCode: MSPErrorCode, errorMessage: String?) {}
}

final class RewardedAdListenerSpy: AdListener {
    var impressedAds: [MSPAd] = []
    var clickedAds: [MSPAd] = []
    var rewardedAds: [MSPAd] = []
    var dismissedAds: [MSPAd] = []
    var errors: [String] = []
    var callSequence: [String] = []

    func onError(msg: String) {
        errors.append(msg)
    }

    func onError(msg: String, loadInfo: [String: Any]) {
        errors.append(msg)
    }

    func onAdImpression(ad: MSPAd) {
        impressedAds.append(ad)
        callSequence.append("impression")
    }

    func onAdClick(ad: MSPAd) {
        clickedAds.append(ad)
        callSequence.append("click")
    }

    func onAdLoaded(placementId: String) {
    }

    func onAdLoaded(placementId: String, loadInfo: [String: Any]) {
    }

    func onAdDismissed(ad: MSPAd) {
        dismissedAds.append(ad)
        callSequence.append("dismiss")
    }

    func onAdRewardReceived(ad: MSPAd) {
        rewardedAds.append(ad)
        callSequence.append("reward")
    }

    func getRootViewController() -> UIViewController? {
        nil
    }
}

final class RewardedAdNetworkAdapterStub: AdNetworkAdapter {
    @MainActor
    override func loadAdCreative(
        bidResponse: Any,
        auctionBidListener: AuctionBidListener,
        adListener: AdListener,
        context: Any,
        adRequest: AdRequest,
        bidderPlacementId: String,
        bidderFormat: AdFormat?,
        params: [String: String]?
    ) {
    }

    override func initialize(
        initParams: InitializationParameters,
        adapterInitListener: AdapterInitListener,
        context: Any?
    ) {
    }

    override func destroyAd() {
    }

    @MainActor
    override func prepareViewForInteraction(nativeAd: NativeAd, nativeAdView: Any) {
    }

    override func getAdNetwork() -> AdNetwork {
        .unknown
    }

    override func getSDKVersion() -> String {
        ""
    }
}
