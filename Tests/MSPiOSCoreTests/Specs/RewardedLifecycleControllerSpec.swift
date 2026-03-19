import Nimble
import Quick
import UIKit

@testable import MSPiOSCore

final class RewardedLifecycleControllerSpec: QuickSpec {
    override class func spec() {
        describe("RewardedLifecycleController") {
            var adListener: MockAdListener!
            var ad: RewardedTestAd!
            var sut: RewardedLifecycleController!

            beforeEach {
                adListener = MockAdListener()
                ad = RewardedTestAd(
                    adNetworkAdapter: RewardedDummyAdNetworkAdapter(),
                    reward: Reward(type: "coins", amount: 10)
                )
                sut = RewardedLifecycleController(adListener: adListener, ad: ad)
            }

            it("fires reward only once") {
                sut.markRewardEarned()
                sut.markRewardEarned()

                expect(adListener.rewardedAds.count).to(equal(1))
            }

            it("does not backfill reward on dismiss") {
                sut.markDismissed()

                expect(adListener.rewardedAds).to(beEmpty())
            }

            it("fires dismiss only once") {
                sut.markDismissed()
                sut.markDismissed()

                expect(adListener.dismissedAds.count).to(equal(1))
            }

            it("preserves reward before dismiss ordering") {
                sut.markRewardEarned()
                sut.markDismissed()

                expect(adListener.callSequence).to(equal(["reward", "dismiss"]))
            }

            it("does not affect an independent controller instance") {
                let otherListener = MockAdListener()
                let otherAd = RewardedTestAd(
                    adNetworkAdapter: RewardedDummyAdNetworkAdapter(),
                    reward: Reward(type: "gems", amount: 5)
                )
                let otherController = RewardedLifecycleController(adListener: otherListener, ad: otherAd)

                sut.markRewardEarned()

                expect(adListener.rewardedAds.count).to(equal(1))
                expect(otherListener.rewardedAds).to(beEmpty())
                _ = otherController  // keep alive
            }
        }
    }
}

private final class MockAdListener: AdListener {
    var rewardedAds: [MSPAd] = []
    var dismissedAds: [MSPAd] = []
    var callSequence: [String] = []

    func onError(msg: String) {
    }

    func onError(msg: String, loadInfo: [String: Any]) {
    }

    func onAdImpression(ad: MSPAd) {
    }

    func onAdClick(ad: MSPAd) {
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
