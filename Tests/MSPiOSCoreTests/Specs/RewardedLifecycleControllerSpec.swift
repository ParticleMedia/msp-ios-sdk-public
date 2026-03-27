import Nimble
import Quick
import UIKit

@testable import MSPiOSCore

final class RewardedLifecycleControllerSpec: QuickSpec {
    override class func spec() {
        describe("RewardedLifecycleController") {
            var adListener: MockAdListener!
            var adapter: RewardedDummyAdNetworkAdapter!
            var metricReporter: SpyAdMetricReporter!
            var ad: RewardedTestAd!
            var sut: RewardedLifecycleController!

            beforeEach {
                adListener = MockAdListener()
                metricReporter = SpyAdMetricReporter()
                adapter = RewardedDummyAdNetworkAdapter()
                adapter.adMetricReporter = metricReporter
                adapter.adRequest = AdRequest(
                    customParams: [:], geo: nil, context: nil,
                    adaptiveBannerSize: nil, adSize: nil,
                    placementId: "test", adFormat: .rewarded
                )
                ad = RewardedTestAd(adNetworkAdapter: adapter, reward: Reward(type: "coins", amount: 10))
                adapter.mspAd = ad
                adapter.adListener = adListener
                sut = RewardedLifecycleController(adListener: adListener, ad: ad)
            }

            // MARK: - markDisplayed

            describe("markDisplayed") {
                it("calls onAdImpression on adListener") {
                    sut.markDisplayed()

                    expect(adListener.impressionAds.count).toEventually(equal(1))
                }

                it("calls logAdImpression on adMetricReporter") {
                    sut.markDisplayed()

                    expect(metricReporter.logAdImpressionCallCount).toEventually(equal(1))
                }
            }

            // MARK: - markClicked

            describe("markClicked") {
                it("calls onAdClick on adListener") {
                    sut.markClicked()

                    expect(adListener.clickedAds.count).toEventually(equal(1))
                }

                it("calls logAdClick on adMetricReporter") {
                    sut.markClicked()

                    expect(metricReporter.logAdClickCallCount).toEventually(equal(1))
                }
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
    var impressionAds: [MSPAd] = []
    var clickedAds: [MSPAd] = []
    var callSequence: [String] = []

    func onError(msg: String) {
    }

    func onError(msg: String, loadInfo: [String: Any]) {
    }

    func onAdImpression(ad: MSPAd) {
        impressionAds.append(ad)
    }

    func onAdClick(ad: MSPAd) {
        clickedAds.append(ad)
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

private final class SpyAdMetricReporter: AdMetricReporter {
    var logAdImpressionCallCount = 0
    var logAdClickCallCount = 0

    func logAdImpression(ad: MSPAd, adRequest: AdRequest, bidResponse: Any?) {
        logAdImpressionCallCount += 1
    }

    func logAdClick(ad: MSPAd, adRequest: AdRequest, bidResponse: Any?) {
        logAdClickCallCount += 1
    }

    func logGetAdFromCache(cacheKey: String, fill: Bool, ad: MSPAd?) {}
    func logAdResult(placementId: String, ad: MSPAd?, fill: Bool, isFromCache: Bool) {}
    func logAdHide(
        ad: MSPAd, adRequest: AdRequest, bidResponse: Any?, reason: String,
        adScreenShot: Data?, fullScreenShot: Data?
    ) {}
    func logAdReport(
        ad: MSPAd, adRequest: AdRequest, bidResponse: Any?, reason: String, description: String?,
        adScreenShot: Data?, fullScreenShot: Data?
    ) {}
    func logAdResponse(ad: MSPAd?, adRequest: AdRequest, errorCode: MSPErrorCode, errorMessage: String?) {}
}
