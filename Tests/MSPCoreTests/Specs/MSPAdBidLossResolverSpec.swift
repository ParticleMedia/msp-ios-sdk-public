import Foundation
import Nimble
import Quick

@testable import MSPCore
@testable import MSPiOSCore

final class MSPAdBidLossResolverSpec: QuickSpec {
    override class func spec() {
        describe("MSPAdBidLossResolver") {
            var sut: MSPAdBidLossResolver!

            beforeEach {
                sut = MSPAdBidLossResolver()
            }

            it("does not notify when only c2s bidders have ads") {
                let google = makeCandidate(bidderName: AdNetwork.google.rawValue, price: 1.2)
                let applovin = makeCandidate(bidderName: AdNetwork.applovin.rawValue, price: 1.5)

                let notification = sut.resolveBidLossNotification(
                    candidates: [google, applovin],
                    winner: applovin
                )

                expect(notification).to(beNil())
            }

            it("notifies the highest-priced c2s loss when s2s wins") {
                let msp = makeCandidate(bidderName: MSPBidderName.msp, price: 3.0, requestId: "msp-request")
                let google = makeCandidate(bidderName: AdNetwork.google.rawValue, price: 1.2)
                let applovin = makeCandidate(bidderName: AdNetwork.applovin.rawValue, price: 2.5)

                let notification = sut.resolveBidLossNotification(
                    candidates: [msp, google, applovin],
                    winner: msp
                )

                expect(notification?.winnerBidderName).to(equal(MSPBidderName.msp))
                expect(notification?.winnerPrice).to(equal(3.0))
                expect(notification?.losingAd).to(beIdenticalTo(applovin.ad))
                expect(notification?.requestId).to(beNil())
            }

            it("notifies the s2s loss with request id when c2s wins") {
                let msp = makeCandidate(bidderName: MSPBidderName.msp, price: 1.8, requestId: "s2s-request-id")
                let google = makeCandidate(bidderName: AdNetwork.google.rawValue, price: 2.1)

                let notification = sut.resolveBidLossNotification(
                    candidates: [msp, google],
                    winner: google
                )

                expect(notification?.winnerBidderName).to(equal(AdNetwork.google.rawValue))
                expect(notification?.winnerPrice).to(equal(2.1))
                expect(notification?.losingAd).to(beIdenticalTo(msp.ad))
                expect(notification?.requestId).to(equal("s2s-request-id"))
            }

            it("does not notify s2s loss when request id is missing") {
                let msp = makeCandidate(bidderName: MSPBidderName.msp, price: 1.8)
                let google = makeCandidate(bidderName: AdNetwork.google.rawValue, price: 2.1)

                let notification = sut.resolveBidLossNotification(
                    candidates: [msp, google],
                    winner: google
                )

                expect(notification).to(beNil())
            }

            it("selects the same winner as getAd when prices tie") {
                let first = makeCandidate(bidderName: MSPBidderName.msp, price: 1.0, requestId: "first-request")
                let second = makeCandidate(bidderName: AdNetwork.google.rawValue, price: 1.0)

                let winner = sut.winningCandidate(from: [first, second])

                expect(winner?.bidderName).to(equal(AdNetwork.google.rawValue))
            }
        }
    }

    private static func makeCandidate(
        bidderName: String,
        price: Double,
        requestId: String? = nil
    ) -> MSPAuctionAdCandidate {
        let placementId = "\(bidderName)-\(UUID().uuidString)"
        let ad = makeAd(bidderName: bidderName, price: price, requestId: requestId)
        return MSPAuctionAdCandidate(
            bidderName: bidderName,
            bidderPlacementId: placementId,
            price: price,
            ad: ad
        )
    }

    private static func makeAd(bidderName: String, price: Double, requestId: String?) -> MSPAd {
        let ad = MSPAd(adNetworkAdapter: DummyAdNetworkAdapter())
        ad.adInfo[MSPConstants.AD_INFO_PRICE] = price
        ad.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = bidderName
        ad.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = "\(bidderName)-unit"
        if let requestId = requestId {
            ad.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] = requestId
        }
        return ad
    }
}
