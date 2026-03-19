import MolocoSDK
import Nimble
import Quick
import UIKit

@testable import MSPMolocoAdapter
@testable import MSPiOSCore

final class MolocoRewardedAdTests: QuickSpec {
    override class func spec() {
        describe("MolocoRewardedAd") {
            var sut: MolocoRewardedAd!
            var listener: RewardedAdListenerSpy!
            var rewardedItem: MockMolocoRewardedInterstitial!

            beforeEach {
                listener = RewardedAdListenerSpy()
                rewardedItem = MockMolocoRewardedInterstitial()
                sut = MolocoRewardedAd(
                    adNetworkAdapter: RewardedAdNetworkAdapterStub(),
                    reward: Reward(type: "coins", amount: 10),
                    rewardedAdItem: rewardedItem,
                    rootViewController: UIViewController(),
                    adListener: listener
                )
            }

            it("shows via the Moloco rewarded item") {
                let presentingViewController = UIViewController()

                MainActor.assumeIsolated {
                    sut.show(rootViewController: presentingViewController)
                }

                expect(rewardedItem.showCalled).to(beTrue())
                expect(rewardedItem.showViewController).to(beIdenticalTo(presentingViewController))
            }

            it("records impression on didShow") {
                sut.didShow(ad: rewardedItem)

                expect(listener.impressedAds).to(haveCount(1))
            }

            it("records click on didClick") {
                sut.didClick(on: rewardedItem)

                expect(listener.clickedAds).to(haveCount(1))
            }

            it("fires reward once when userRewarded is called twice") {
                sut.userRewarded(ad: rewardedItem)
                sut.userRewarded(ad: rewardedItem)

                expect(listener.rewardedAds).to(haveCount(1))
            }

            it("dismisses without reward when didHide is called first") {
                sut.didHide(ad: rewardedItem)

                expect(listener.rewardedAds).to(beEmpty())
                expect(listener.dismissedAds).to(haveCount(1))
            }

            it("keeps reward before dismiss ordering") {
                sut.userRewarded(ad: rewardedItem)
                sut.didHide(ad: rewardedItem)

                expect(listener.callSequence).to(equal(["reward", "dismiss"]))
            }

            it("forwards present failure to the listener") {
                let error = NSError(domain: "MolocoTest", code: 456, userInfo: nil)

                sut.failToShow(ad: rewardedItem, with: error)

                expect(listener.errors).to(haveCount(1))
                expect(listener.errors.first).to(contain("MolocoTest"))
            }
        }
    }
}

private final class MockMolocoRewardedInterstitial: NSObject, MolocoRewardedInterstitial {
    var rewardedDelegate: (any MolocoRewardedDelegate)?
    var fullscreenViewController: UIViewController?
    var isReady: Bool = true
    var showCalled = false
    weak var showViewController: UIViewController?

    @MainActor
    func load(bidResponse: String) {
    }

    func destroy() {
    }

    @MainActor
    func show(from viewController: UIViewController) {
        showCalled = true
        showViewController = viewController
    }

    @MainActor
    func show(from viewController: UIViewController, muted: Bool) {
        show(from: viewController)
    }
}
