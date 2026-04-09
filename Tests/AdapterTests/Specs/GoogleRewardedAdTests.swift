import MSPGoogleAdsTypes
import Nimble
import Quick
import UIKit

@testable import MSPGoogleAdapter
@testable import MSPiOSCore

final class GoogleRewardedAdTests: QuickSpec {
    override class func spec() {
        describe("GoogleRewardedAd") {
            var sut: GoogleRewardedAd!
            var listener: RewardedAdListenerSpy!
            var presentedViewController: UIViewController?
            var presentCallCount: Int!
            var originalPresenter: ((MSPGADRewardedAd?, UIViewController?, @escaping () -> Void) -> Void)!
            var adapter: RewardedAdNetworkAdapterStub!
            var metricReporter: SpyAdMetricReporter!

            beforeEach {
                listener = RewardedAdListenerSpy()
                adapter = RewardedAdNetworkAdapterStub()
                adapter.adRequest = AdRequest(
                    customParams: [:], geo: nil, context: nil,
                    adaptiveBannerSize: nil, adSize: nil,
                    placementId: "test", adFormat: .rewarded
                )
                metricReporter = SpyAdMetricReporter()
                adapter.adMetricReporter = metricReporter
                sut = GoogleRewardedAd(
                    adNetworkAdapter: adapter,
                    reward: Reward(type: "coins", amount: 10),
                    rewardedAdItem: nil,
                    rootViewController: UIViewController(),
                    adListener: listener
                )
                adapter.mspAd = sut
                adapter.adListener = listener
                presentedViewController = nil
                presentCallCount = 0
                originalPresenter = GoogleRewardedAd.presenter
                GoogleRewardedAd.presenter = { _, rootViewController, _ in
                    presentCallCount += 1
                    presentedViewController = rootViewController
                }
            }

            afterEach {
                GoogleRewardedAd.presenter = originalPresenter
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

            it("records impression when marked displayed") {
                sut.markDisplayed()

                expect(listener.impressedAds).toEventually(haveCount(1))
            }

            it("sends MES impression event when marked displayed") {
                sut.markDisplayed()

                expect(metricReporter.logAdImpressionCallCount).toEventually(equal(1))
            }

            it("sends MES click event when marked clicked") {
                sut.markClicked()

                expect(metricReporter.logAdClickCallCount).toEventually(equal(1))
            }

            it("records dismissal when marked dismissed") {
                sut.markDismissed()

                expect(listener.dismissedAds).to(haveCount(1))
            }

            it("is valid when it holds a rewarded ad item reference") {
                // GADRewardedAd has no public initializer, so unsafeBitCast is the
                // pragmatic way to produce a non-nil value. isValid() only checks != nil,
                // so memory layout doesn't matter here.
                let fakeItem = unsafeBitCast(NSObject(), to: MSPGADRewardedAd?.self)
                sut.rewardedAdItem = fakeItem

                expect(sut.isValid()).to(beTrue())
            }
        }
    }
}
