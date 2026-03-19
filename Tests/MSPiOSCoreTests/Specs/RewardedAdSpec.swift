import Nimble
import Quick
import UIKit

@testable import MSPiOSCore

final class RewardedAdSpec: QuickSpec {
    override class func spec() {
        describe("RewardedAd") {
            it("exposes the configured reward") {
                let reward = Reward(type: "coins", amount: 10)
                let sut = RewardedTestAd(adNetworkAdapter: RewardedDummyAdNetworkAdapter(), reward: reward)

                expect(sut.reward).to(equal(reward))
            }

            it("is an MSPAd but not an InterstitialAd") {
                let sut = RewardedTestAd(
                    adNetworkAdapter: RewardedDummyAdNetworkAdapter(),
                    reward: Reward(type: "coins", amount: 1)
                )

                expect(sut).to(beAKindOf(MSPAd.self))
                expect(sut as? InterstitialAd).to(beNil())
            }
        }
    }
}
