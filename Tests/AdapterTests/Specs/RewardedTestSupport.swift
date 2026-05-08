import UIKit

@testable import MSPiOSCore

final class MockAdListener: AdListener {
    var onAdRewardReceivedCallCount = 0
    var onAdImpressionCallCount = 0
    var onAdClickCallCount = 0
    var onAdDismissedCallCount = 0
    var onErrorCallCount = 0
    var lastRewardedAd: MSPAd?
    var lastErrorMessage: String?
    var onRewardCallback: (() -> Void)?
    var onDismissCallback: (() -> Void)?

    func onAdRewardReceived(ad: MSPAd) {
        onAdRewardReceivedCallCount += 1
        lastRewardedAd = ad
        onRewardCallback?()
    }

    func onAdImpression(ad: MSPAd) { onAdImpressionCallCount += 1 }
    func onAdClick(ad: MSPAd) { onAdClickCallCount += 1 }

    func onAdDismissed(ad: MSPAd) {
        onAdDismissedCallCount += 1
        onDismissCallback?()
    }

    func onError(msg: String) {
        onErrorCallCount += 1
        lastErrorMessage = msg
    }

    func onError(msg: String, loadInfo: [String: Any]) {
        onErrorCallCount += 1
        lastErrorMessage = msg
    }

    func onAdLoaded(placementId: String) {}
    func onAdLoaded(placementId: String, loadInfo: [String: Any]) {}

    func getRootViewController() -> UIViewController? { UIViewController() }
}

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
        ad: MSPAd, adRequest: AdRequest, bidResponse: Any, reason: String,
        adScreenShot: Data?, fullScreenShot: Data?
    ) {}
    func logAdReport(
        ad: MSPAd, adRequest: AdRequest, bidResponse: Any, reason: String, description: String?,
        adScreenShot: Data?, fullScreenShot: Data?
    ) {}
    func logAdDismiss(ad: MSPAd, adRequest: AdRequest, bidResponse: Any?) {}
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
    var adRequest: AdRequest?
    var adMetricReporter: AdMetricReporter?
    weak var mspAd: MSPAd?
    weak var adListener: AdListener?

    @MainActor
    func loadAdCreative(
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

    func initialize(
        initParams: InitializationParameters,
        adapterInitListener: AdapterInitListener,
        context: Any?
    ) {
    }

    func destroyAd() {
    }

    @MainActor
    func prepareViewForInteraction(nativeAd: NativeAd, nativeAdView: Any) {
    }

    func setAdMetricReporter(adMetricReporter: AdMetricReporter) {
        self.adMetricReporter = adMetricReporter
    }

    func sendHideAdEvent(reason: String, adScreenShot: Data?, fullScreenShot: Data?) {}

    func sendDismissAdEvent() {}

    func sendReportAdEvent(reason: String, description: String?, adScreenShot: Data?, fullScreenShot: Data?) {}

    func getAdNetwork() -> AdNetwork {
        .unknown
    }

    func getSDKVersion() -> String {
        ""
    }
}
