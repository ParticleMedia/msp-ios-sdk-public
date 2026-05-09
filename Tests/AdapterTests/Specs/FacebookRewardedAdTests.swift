import FBAudienceNetwork
import Nimble
import Quick
import UIKit

@testable import MSPFacebookAdapter
@testable import MSPiOSCore

final class FacebookRewardedAdTests: QuickSpec {
    override class func spec() {
        describe("FacebookRewardedAd") {
            var sut: FacebookRewardedAd!
            var listener: RewardedAdListenerSpy!
            var adapter: RewardedAdNetworkAdapterStub!
            var metricReporter: SpyAdMetricReporter!
            var presentedViewController: UIViewController?
            var presentCallCount: Int!
            var originalPresenter: ((FBRewardedVideoAd?, UIViewController) -> Void)!

            beforeEach {
                listener = RewardedAdListenerSpy()
                metricReporter = SpyAdMetricReporter()
                adapter = RewardedAdNetworkAdapterStub()
                adapter.adRequest = AdRequest(
                    customParams: [:], geo: nil, context: nil,
                    adaptiveBannerSize: nil, adSize: nil,
                    placementId: "test", adFormat: .rewarded
                )
                adapter.adMetricReporter = metricReporter
                sut = FacebookRewardedAd(
                    adNetworkAdapter: adapter,
                    reward: Reward(type: "coins", amount: 10),
                    rewardedVideoAdItem: nil,
                    rootViewController: UIViewController(),
                    adListener: listener
                )
                adapter.mspAd = sut
                adapter.adListener = listener
                presentedViewController = nil
                presentCallCount = 0
                originalPresenter = FacebookRewardedAd.presenter
                FacebookRewardedAd.presenter = { _, rootViewController in
                    presentCallCount += 1
                    presentedViewController = rootViewController
                }
            }

            afterEach {
                FacebookRewardedAd.presenter = originalPresenter
                adapter.mspAd = nil
            }

            it("calls the rewarded presenter from show") {
                let passedViewController = UIViewController()

                MainActor.assumeIsolated {
                    sut.show(rootViewController: passedViewController)
                }

                expect(presentCallCount).to(equal(1))
                expect(presentedViewController).to(beIdenticalTo(passedViewController))
            }

            it("fires reward when reward is earned") {
                sut.markRewardEarned()

                expect(listener.rewardedAds).to(haveCount(1))
            }

            it("fires dismiss when closed") {
                sut.markDismissed()

                expect(listener.dismissedAds).to(haveCount(1))
            }

            it("does not fire reward on dismiss without reward") {
                sut.markDismissed()

                expect(listener.rewardedAds).to(beEmpty())
            }

            it("fires reward only once when reward is earned twice") {
                sut.markRewardEarned()
                sut.markRewardEarned()

                expect(listener.rewardedAds).to(haveCount(1))
            }

            it("sends MES impression event when markDisplayed is called") {
                sut.markDisplayed()

                expect(metricReporter.logAdImpressionCallCount).toEventually(equal(1))
            }

            it("sends MES click event when markClicked is called") {
                sut.markClicked()

                expect(metricReporter.logAdClickCallCount).toEventually(equal(1))
            }

            // Regression guard: pre-centralization, FacebookAdapter both forwarded the SDK
            // callback into markDisplayed and called logAdImpression directly, double-firing
            // MES. The fix in commit 010388a8 made the controller the single source of truth.
            // Asserting at the adapter layer ensures any future refactor that re-introduces
            // direct MES dispatch will trip this test, not just controller-level tests.
            it("does not double-fire impression when markDisplayed is called twice") {
                sut.markDisplayed()
                sut.markDisplayed()

                expect(metricReporter.logAdImpressionCallCount).toEventually(equal(1))
            }

            it("does not double-fire click when markClicked is called twice") {
                sut.markClicked()
                sut.markClicked()

                expect(metricReporter.logAdClickCallCount).toEventually(equal(1))
            }
        }
    }
}
