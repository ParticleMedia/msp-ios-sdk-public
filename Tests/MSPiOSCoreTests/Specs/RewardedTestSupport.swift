import UIKit

@testable import MSPiOSCore

final class RewardedDummyAdNetworkAdapter: AdNetworkAdapter {
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

    func getAdRequest() -> AdRequest? { adRequest }

    func getAdMetricReporter() -> AdMetricReporter? { adMetricReporter }
}

final class RewardedTestAd: RewardedAd {
    override func show(rootViewController: UIViewController?) {
    }
}
