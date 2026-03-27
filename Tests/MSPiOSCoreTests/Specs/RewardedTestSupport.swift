import UIKit

@testable import MSPiOSCore

final class RewardedDummyAdNetworkAdapter: AdNetworkAdapter {
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

final class RewardedTestAd: RewardedAd {
    override func show(rootViewController: UIViewController?) {
    }
}
