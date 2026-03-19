import UIKit

@testable import MSPiOSCore

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
    }

    func getAdNetwork() -> AdNetwork {
        .unknown
    }

    func sendHideAdEvent(reason: String, adScreenShot: Data?, fullScreenShot: Data?) {
    }

    func sendReportAdEvent(reason: String, description: String?, adScreenShot: Data?, fullScreenShot: Data?) {
    }

    func getSDKVersion() -> String {
        ""
    }
}
