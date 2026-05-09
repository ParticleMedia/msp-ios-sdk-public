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
            var adapter: RewardedAdNetworkAdapterStub!
            var metricReporter: SpyAdMetricReporter!

            beforeEach {
                listener = RewardedAdListenerSpy()
                rewardedItem = MockMolocoRewardedInterstitial()
                adapter = RewardedAdNetworkAdapterStub()
                adapter.adRequest = AdRequest(
                    customParams: [:], geo: nil, context: nil,
                    adaptiveBannerSize: nil, adSize: nil,
                    placementId: "test", adFormat: .rewarded
                )
                metricReporter = SpyAdMetricReporter()
                adapter.adMetricReporter = metricReporter
                sut = MolocoRewardedAd(
                    adNetworkAdapter: adapter,
                    reward: Reward(type: "coins", amount: 10),
                    rewardedAdItem: rewardedItem,
                    rootViewController: UIViewController(),
                    adListener: listener
                )
                adapter.mspAd = sut
                adapter.adListener = listener
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

                expect(listener.impressedAds).toEventually(haveCount(1))
            }

            it("records click on didClick") {
                sut.didClick(on: rewardedItem)

                expect(listener.clickedAds).toEventually(haveCount(1))
            }

            it("sends MES impression event on didShow") {
                sut.didShow(ad: rewardedItem)

                expect(metricReporter.logAdImpressionCallCount).toEventually(equal(1))
            }

            it("sends MES click event on didClick") {
                sut.didClick(on: rewardedItem)

                expect(metricReporter.logAdClickCallCount).toEventually(equal(1))
            }

            it("fires reward once when userRewarded is called twice") {
                sut.userRewarded(ad: rewardedItem)
                sut.userRewarded(ad: rewardedItem)

                expect(listener.rewardedAds).toEventually(haveCount(1))
            }

            it("dismisses without reward when didHide is called first") {
                sut.didHide(ad: rewardedItem)

                expect(listener.dismissedAds).toEventually(haveCount(1))
                expect(listener.rewardedAds).to(beEmpty())
            }

            it("keeps reward before dismiss ordering") {
                sut.userRewarded(ad: rewardedItem)
                sut.didHide(ad: rewardedItem)

                expect(listener.callSequence).toEventually(equal(["reward", "dismiss"]))
            }

            it("logs present failure without calling onError") {
                let error = NSError(domain: "MolocoTest", code: 456, userInfo: nil)

                sut.failToShow(ad: rewardedItem, with: error)

                expect(listener.errors).to(beEmpty())
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
