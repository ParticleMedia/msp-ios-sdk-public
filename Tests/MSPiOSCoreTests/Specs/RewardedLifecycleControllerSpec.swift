import Nimble
import Quick
import UIKit

@testable import MSPiOSCore

// Note: RewardedLifecycleController methods have dispatchPrecondition(.onQueue(.main)).
// Quick/Nimble `it` closures execute on DispatchQueue.main, so these preconditions pass.
// If test execution ever moves off the main queue, these tests will crash rather than fail.
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

                it("fires impression only once (double-fire regression)") {
                    sut.markDisplayed()
                    sut.markDisplayed()

                    expect(adListener.impressionAds.count).toEventually(equal(1))
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

                it("fires click only once (double-fire regression)") {
                    sut.markClicked()
                    sut.markClicked()

                    expect(adListener.clickedAds.count).toEventually(equal(1))
                    expect(metricReporter.logAdClickCallCount).toEventually(equal(1))
                }

                it("passes click metadata to adMetricReporter") {
                    let metadata = AdClickMetadata(clickAreaName: "cta", clickPosition: 3)

                    sut.markClicked(clickMetadata: metadata)

                    expect(metricReporter.lastClickMetadata?.clickAreaName).toEventually(equal("cta"))
                    expect(metricReporter.lastClickMetadata?.clickPosition).toEventually(equal(3))
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

            it("drops reward callback after dismiss") {
                sut.markDismissed()
                sut.markRewardEarned()

                expect(adListener.rewardedAds).to(beEmpty())
                expect(metricReporter.logAdRewardedCallCount).to(equal(0))
                expect(adListener.callSequence).to(equal(["dismiss"]))
            }

            it("still sends reward MES when listener is nil") {
                sut = RewardedLifecycleController(adListener: nil, ad: ad)

                sut.markRewardEarned()

                expect(metricReporter.logAdRewardedCallCount).to(equal(1))
                expect(adListener.rewardedAds).to(beEmpty())
            }

            it("fires dismiss only once") {
                sut.markDismissed()
                sut.markDismissed()

                expect(adListener.dismissedAds.count).to(equal(1))
            }

            it("calls logAdDismiss on adMetricReporter") {
                sut.markDismissed()

                expect(metricReporter.logAdDismissCallCount).toEventually(equal(1))
            }

            it("does not double-fire ad_dismiss MES when called twice") {
                sut.markDismissed()
                sut.markDismissed()

                expect(metricReporter.logAdDismissCallCount).toEventually(equal(1))
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
        callSequence.append("impression")
    }

    func onAdClick(ad: MSPAd) {
        clickedAds.append(ad)
        callSequence.append("click")
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
    var logAdRewardedCallCount = 0
    var logAdDismissCallCount = 0
    var lastClickMetadata: AdClickMetadata?

    func logAdImpression(ad: MSPAd, adRequest: AdRequest, bidResponse: Any?) {
        logAdImpressionCallCount += 1
    }

    func logAdClick(ad: MSPAd, adRequest: AdRequest, bidResponse: Any?) {
        logAdClickCallCount += 1
    }

    func logAdClick(ad: MSPAd, adRequest: AdRequest, bidResponse: Any?, clickMetadata: AdClickMetadata?) {
        logAdClickCallCount += 1
        lastClickMetadata = clickMetadata
    }

    func logAdRewarded(ad: MSPAd, adRequest: AdRequest, bidResponse: Any?) {
        logAdRewardedCallCount += 1
    }

    func logGetAdFromCache(cacheKey: String, fill: Bool, ad: MSPAd?) {}
    func logAdResult(placementId: String, ad: MSPAd?, fill: Bool, isFromCache: Bool) {}
    func logAdHide(
        ad: MSPAd, adRequest: AdRequest, bidResponse: Any, reason: String,
        adScreenShot: Data?, fullScreenShot: Data?
    ) {}
    func logAdReport(
        ad: MSPAd, adRequest: AdRequest, bidResponse: Any, reason: String, description: String?,
        adScreenShot: Data?, fullScreenShot: Data?
    ) {}
    func logAdDismiss(ad: MSPAd, adRequest: AdRequest, bidResponse: Any?) {
        logAdDismissCallCount += 1
    }
    func logAdResponse(ad: MSPAd?, adRequest: AdRequest, errorCode: MSPErrorCode, errorMessage: String?) {}
}
