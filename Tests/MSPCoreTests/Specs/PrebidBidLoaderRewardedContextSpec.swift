import Nimble
import Quick
import UIKit

@testable import MSPPrebidAdapter
@testable import MSPiOSCore

final class PrebidBidLoaderRewardedContextSpec: QuickSpec {
    override class func spec() {
        describe("PrebidBidLoader rewarded context") {
            it("sets rewarded_video ad_format while preserving publisher placement") {
                let sut = PrebidBidLoader(tokenProviders: BidTokenProviders())
                let adRequest = AdRequest(
                    customParams: [
                        "ad_format": "rewarded",
                        "placement": "caller-override",
                    ],
                    geo: nil,
                    context: nil,
                    adaptiveBannerSize: nil,
                    adSize: nil,
                    placementId: "nova-ios-reward-fullscreen-prod-ob",
                    adFormat: .rewarded
                )

                let config = sut.getAdUnitConfig(
                    configId: "test-config",
                    bidTokens: BidTokens(),
                    requestUUID: adRequest.requestId,
                    prebidBannerAdSize: CGSize(width: 320, height: 50),
                    adRequest: adRequest
                )

                expect(config.contextDataDictionary["ad_format"]).to(equal(["rewarded_video"]))
                expect(config.contextDataDictionary["placement"]).to(equal(["nova-ios-reward-fullscreen-prod-ob"]))
            }
        }
    }
}
