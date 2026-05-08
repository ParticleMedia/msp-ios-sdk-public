import Nimble
import Quick

@testable import MSPCore
@testable import MSPiOSCore

final class MSPAdLoaderRewardedRolloutSpec: QuickSpec {
    override class func spec() {
        describe("MSPAdLoader rewarded rollout") {
            var sut: MSPAdLoader!
            var originalManagers: [AdNetwork: AdNetworkManager]!

            beforeEach {
                sut = MSPAdLoader()
                originalManagers = MSP.shared.adNetworkAdapterProvider.adNetworkManagerDict
                MSP.shared.adNetworkAdapterProvider.adNetworkManagerDict = [
                    .google: FakeAdNetworkManager(network: .google),
                    .facebook: FakeAdNetworkManager(network: .facebook),
                    .moloco: FakeAdNetworkManager(network: .moloco),
                ]
            }

            afterEach {
                MSP.shared.adNetworkAdapterProvider.adNetworkManagerDict = originalManagers
            }

            it("filters rewarded bidders to the rollout allowlist") {
                let placement = Placement(
                    placementId: "rewarded-placement",
                    auctionTimeout: 8000,
                    bidders: [
                        BidderInfo(
                            name: AdNetwork.google.rawValue, bidderPlacementId: "google-placement",
                            bidderFormat: "rewarded", params: nil),
                        BidderInfo(
                            name: MSPBidderName.msp, bidderPlacementId: "msp-placement", bidderFormat: "rewarded",
                            params: nil),
                        BidderInfo(
                            name: AdNetwork.facebook.rawValue, bidderPlacementId: "facebook-placement",
                            bidderFormat: "rewarded", params: nil),
                        BidderInfo(
                            name: AdNetwork.moloco.rawValue, bidderPlacementId: "moloco-placement",
                            bidderFormat: "rewarded", params: nil),
                    ]
                )
                let adRequest = makeAdRequest(format: .rewarded)

                let bidders = sut.getBidders(placement: placement, adRequest: adRequest)

                // Facebook passes the rollout allowlist but has no direct-adapter getBidder
                // implementation, so only google produces a non-nil Bidder.
                expect(bidders.map(\.name)).to(equal([AdNetwork.google.rawValue]))
            }

            it("does not filter non-rewarded requests") {
                let placement = Placement(
                    placementId: "interstitial-placement",
                    auctionTimeout: 8000,
                    bidders: [
                        BidderInfo(
                            name: AdNetwork.google.rawValue, bidderPlacementId: "google-placement",
                            bidderFormat: "interstitial", params: nil),
                        BidderInfo(
                            name: MSPBidderName.msp, bidderPlacementId: "msp-placement", bidderFormat: "interstitial",
                            params: nil),
                        BidderInfo(
                            name: AdNetwork.moloco.rawValue, bidderPlacementId: "moloco-placement",
                            bidderFormat: "interstitial", params: nil),
                    ]
                )
                let adRequest = makeAdRequest(format: .interstitial)

                let bidders = sut.getBidders(placement: placement, adRequest: adRequest)

                expect(bidders.map(\.name)).to(
                    equal([
                        AdNetwork.google.rawValue,
                        MSPBidderName.msp,
                        AdNetwork.moloco.rawValue,
                    ]))
            }

            it("supports replacing the rollout policy") {
                sut.rewardedAdapterRolloutPolicy = StubRewardedAdapterRolloutPolicy(
                    enabledNetworkNames: [AdNetwork.moloco.rawValue]
                )
                let placement = Placement(
                    placementId: "custom-rollout-placement",
                    auctionTimeout: 8000,
                    bidders: [
                        BidderInfo(
                            name: AdNetwork.facebook.rawValue, bidderPlacementId: "facebook-placement",
                            bidderFormat: "rewarded", params: nil),
                        BidderInfo(
                            name: AdNetwork.moloco.rawValue, bidderPlacementId: "moloco-placement",
                            bidderFormat: "rewarded", params: nil),
                    ]
                )
                let adRequest = makeAdRequest(format: .rewarded)

                let bidders = sut.getBidders(placement: placement, adRequest: adRequest)

                expect(bidders.map(\.name)).to(equal([AdNetwork.moloco.rawValue]))
            }
        }
    }

    private static func makeAdRequest(format: AdFormat) -> AdRequest {
        AdRequest(
            customParams: [:],
            geo: nil,
            context: nil,
            adaptiveBannerSize: nil,
            adSize: nil,
            placementId: "test-placement",
            adFormat: format
        )
    }
}

private final class FakeAdNetworkManager: AdNetworkManager {
    private let network: AdNetwork

    init(network: AdNetwork) {
        self.network = network
        super.init()
    }

    override func getAdBidder(bidderPlacementId: String, bidderFormat: AdFormat?) -> Bidder? {
        Bidder(name: network.rawValue, bidderPlacementId: bidderPlacementId, bidderFormat: bidderFormat)
    }
}

private struct StubRewardedAdapterRolloutPolicy: RewardedAdapterRolloutPolicy {
    let enabledNetworkNames: Set<String>

    init(enabledNetworkNames: [String]) {
        self.enabledNetworkNames = Set(enabledNetworkNames)
    }

    func isEnabled(networkName: String, placementId: String) -> Bool {
        enabledNetworkNames.contains(networkName)
    }
}
