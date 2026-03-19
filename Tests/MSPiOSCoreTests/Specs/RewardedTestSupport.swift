import UIKit

@testable import MSPiOSCore

final class RewardedDummyAdNetworkAdapter: AdNetworkAdapter {
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

final class RewardedTestAd: RewardedAd {
    override func show(rootViewController: UIViewController?) {
    }
}
