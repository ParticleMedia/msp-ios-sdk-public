import Foundation
import Nimble
import Quick

@testable import MSPCore
@testable import MSPiOSCore

final class MSPAdLoaderBidLossNotificationSpec: QuickSpec {
    override class func spec() {
        describe("MSPAdLoader bid loss notifications") {
            var sut: MSPAdLoader!
            var originalExternalPlacements: [String: Placement]!
            var cachedPlacementIds: [String]!
            var notifications: [MSPBidLossNotification]!

            beforeEach {
                sut = MSPAdLoader()
                originalExternalPlacements = MSPAdConfigManager.shared.externalAdConfigPlacements
                cachedPlacementIds = []
                notifications = []
                sut.bidLossNotifier = { notifications.append($0) }
            }

            afterEach {
                for placementId in cachedPlacementIds {
                    _ = AdCache.shared.getAd(placementId: placementId)
                }
                MSPAdConfigManager.shared.externalAdConfigPlacements = originalExternalPlacements
            }

            it("notifies the highest-priced c2s loss when s2s wins getAd") {
                let placementId = uniquePlacementId("s2s-wins")
                let mspPlacementId = uniquePlacementId("msp")
                let googlePlacementId = uniquePlacementId("google")
                let applovinPlacementId = uniquePlacementId("applovin")
                cachedPlacementIds = [mspPlacementId, googlePlacementId, applovinPlacementId]
                registerPlacement(
                    placementId: placementId,
                    bidders: [
                        makeBidderInfo(name: MSPBidderName.msp, placementId: mspPlacementId),
                        makeBidderInfo(name: AdNetwork.google.rawValue, placementId: googlePlacementId),
                        makeBidderInfo(name: AdNetwork.applovin.rawValue, placementId: applovinPlacementId),
                    ]
                )
                let mspAd = cacheAd(placementId: mspPlacementId, bidderName: MSPBidderName.msp, price: 3.0)
                _ = cacheAd(placementId: googlePlacementId, bidderName: AdNetwork.google.rawValue, price: 1.2)
                let applovinAd = cacheAd(
                    placementId: applovinPlacementId, bidderName: AdNetwork.applovin.rawValue, price: 2.5)

                let returnedAd = sut.getAd(placementId: placementId)

                expect(returnedAd).to(beIdenticalTo(mspAd))
                expect(notifications).to(haveCount(1))
                expect(notifications.first?.winnerBidderName).to(equal(MSPBidderName.msp))
                expect(notifications.first?.winnerPrice).to(equal(3.0))
                expect(notifications.first?.losingAd).to(beIdenticalTo(applovinAd))
                expect(notifications.first?.requestId).to(beNil())
            }

            it("notifies the s2s loss with request id when c2s wins getAd") {
                let placementId = uniquePlacementId("c2s-wins")
                let mspPlacementId = uniquePlacementId("msp")
                let googlePlacementId = uniquePlacementId("google")
                cachedPlacementIds = [mspPlacementId, googlePlacementId]
                registerPlacement(
                    placementId: placementId,
                    bidders: [
                        makeBidderInfo(name: MSPBidderName.msp, placementId: mspPlacementId),
                        makeBidderInfo(name: AdNetwork.google.rawValue, placementId: googlePlacementId),
                    ]
                )
                let mspAd = cacheAd(
                    placementId: mspPlacementId, bidderName: MSPBidderName.msp, price: 1.8, requestId: "s2s-request-id")
                let googleAd = cacheAd(
                    placementId: googlePlacementId, bidderName: AdNetwork.google.rawValue, price: 2.1)

                let returnedAd = sut.getAd(placementId: placementId)

                expect(returnedAd).to(beIdenticalTo(googleAd))
                expect(notifications).to(haveCount(1))
                expect(notifications.first?.winnerBidderName).to(equal(AdNetwork.google.rawValue))
                expect(notifications.first?.winnerPrice).to(equal(2.1))
                expect(notifications.first?.losingAd).to(beIdenticalTo(mspAd))
                expect(notifications.first?.requestId).to(equal("s2s-request-id"))
            }

            it("does not notify when c2s wins getAd and the s2s request id is missing") {
                let placementId = uniquePlacementId("missing-request-id")
                let mspPlacementId = uniquePlacementId("msp")
                let googlePlacementId = uniquePlacementId("google")
                cachedPlacementIds = [mspPlacementId, googlePlacementId]
                registerPlacement(
                    placementId: placementId,
                    bidders: [
                        makeBidderInfo(name: MSPBidderName.msp, placementId: mspPlacementId),
                        makeBidderInfo(name: AdNetwork.google.rawValue, placementId: googlePlacementId),
                    ]
                )
                _ = cacheAd(placementId: mspPlacementId, bidderName: MSPBidderName.msp, price: 1.8)
                let googleAd = cacheAd(
                    placementId: googlePlacementId, bidderName: AdNetwork.google.rawValue, price: 2.1)

                let returnedAd = sut.getAd(placementId: placementId)

                expect(returnedAd).to(beIdenticalTo(googleAd))
                expect(notifications).to(beEmpty())
            }
        }
    }

    private static func registerPlacement(placementId: String, bidders: [BidderInfo]) {
        MSPAdConfigManager.shared.externalAdConfigPlacements[placementId] = Placement(
            placementId: placementId,
            auctionTimeout: 8000,
            bidders: bidders
        )
    }

    private static func makeBidderInfo(name: String, placementId: String) -> BidderInfo {
        BidderInfo(name: name, bidderPlacementId: placementId, bidderFormat: "interstitial", params: nil)
    }

    private static func cacheAd(
        placementId: String,
        bidderName: String,
        price: Double,
        requestId: String? = nil
    ) -> MSPAd {
        let ad = MSPAd(adNetworkAdapter: DummyAdNetworkAdapter())
        ad.adInfo[MSPConstants.AD_INFO_PRICE] = price
        ad.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = bidderName
        ad.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = "\(bidderName)-unit"
        if let requestId = requestId {
            ad.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] = requestId
        }
        AdCache.shared.saveAd(placementId: placementId, ad: ad)
        return ad
    }

    private static func uniquePlacementId(_ prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString)"
    }
}
