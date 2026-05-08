// Meszaros Type: Dummy — satisfies AdNetworkAdapter protocol requirements
// All methods are no-ops; instances are never exercised beyond construction.
import Foundation
import MSPiOSCore

@testable import MSPCore

class DummyAdNetworkAdapter: AdNetworkAdapter {
    func loadAdCreative(
        bidResponse: Any,
        auctionBidListener: AuctionBidListener,
        adListener: AdListener,
        context: Any,
        adRequest: AdRequest,
        bidderPlacementId: String,
        bidderFormat: AdFormat?,
        params: [String: String]?
    ) {}

    func initialize(
        initParams: InitializationParameters,
        adapterInitListener: AdapterInitListener,
        context: Any?
    ) {}

    func destroyAd() {}

    func prepareViewForInteraction(nativeAd: NativeAd, nativeAdView: Any) {}

    func setAdMetricReporter(adMetricReporter: AdMetricReporter) {}

    func getAdNetwork() -> AdNetwork { .unknown }

    func sendHideAdEvent(reason: String, adScreenShot: Data?, fullScreenShot: Data?) {}

    func sendDismissAdEvent() {}

    func sendReportAdEvent(reason: String, description: String?, adScreenShot: Data?, fullScreenShot: Data?) {}

    func getSDKVersion() -> String { "0.0.0" }
}
