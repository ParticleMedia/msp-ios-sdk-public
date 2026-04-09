import Nimble
import Quick
import VungleAdsSDK

@testable import MSPLiftoffAdapter
@testable import MSPiOSCore

class LiftoffRewardedAdTests: QuickSpec {
    override class func spec() {
        describe("LiftoffRewardedAd") {
            var sut: LiftoffRewardedAd!
            var mockAdListener: MockAdListener!
            var vungleRewarded: VungleRewarded!
            var testReward: Reward!
            var adapter: RewardedAdNetworkAdapterStub!
            var metricReporter: SpyAdMetricReporter!

            beforeEach {
                mockAdListener = MockAdListener()
                testReward = Reward(type: "coins", amount: 10)
                vungleRewarded = VungleRewarded(placementId: "test-placement")
                adapter = RewardedAdNetworkAdapterStub()
                adapter.adRequest = AdRequest(customParams: [:], geo: nil, context: nil, adaptiveBannerSize: nil, adSize: nil, placementId: "test", adFormat: .rewarded)
                metricReporter = SpyAdMetricReporter()
                adapter.adMetricReporter = metricReporter
                sut = LiftoffRewardedAd(
                    adNetworkAdapter: adapter,
                    reward: testReward,
                    vungleRewarded: vungleRewarded
                )
                sut.adListener = mockAdListener
                adapter.mspAd = sut
                adapter.adListener = mockAdListener
            }

            afterEach {
                sut = nil
                mockAdListener = nil
                vungleRewarded = nil
                testReward = nil
                adapter = nil
                metricReporter = nil
            }

            // MARK: - Initialization
            describe("initialization") {
                it("should be created successfully") {
                    expect(sut).notTo(beNil())
                    expect(sut.reward).to(equal(testReward))
                }
            }

            // MARK: - Show Functionality
            describe("show") {
                context("when called without root view controller") {
                    it("logs the error without calling onError") {
                        sut.show(rootViewController: nil)

                        // show-phase errors are logged only, never forwarded to listener
                        expect(mockAdListener.onErrorCallCount).to(equal(0))
                    }
                }
            }

            // MARK: - Reward Callback
            describe("reward callback") {
                context("when rewardedAdDidRewardUser is called") {
                    it("should fire onAdRewardReceived once") {
                        // Arrange
                        // Act
                        sut.markRewardEarned()

                        // Assert
                        expect(mockAdListener.onAdRewardReceivedCallCount).to(equal(1))
                        expect(mockAdListener.lastRewardedAd).to(be(sut))
                    }

                    it("should be idempotent - calling twice fires callback once only") {
                        // Arrange
                        // Act
                        sut.markRewardEarned()
                        sut.markRewardEarned()

                        // Assert
                        expect(mockAdListener.onAdRewardReceivedCallCount).to(equal(1))
                    }
                }
            }

            // MARK: - Dismiss Callback
            describe("dismiss callback") {
                context("when rewardedAdDidClose is called without prior reward") {
                    it("should NOT call onAdRewardReceived") {
                        // Arrange
                        // Act
                        sut.markDismissed()

                        // Assert
                        expect(mockAdListener.onAdRewardReceivedCallCount).to(equal(0))
                        expect(mockAdListener.onAdDismissedCallCount).to(equal(1))
                    }
                }

                context("when reward fires before dismiss") {
                    it("should fire reward callback before dismiss callback") {
                        // Arrange
                        var callbackOrder: [String] = []
                        mockAdListener.onRewardCallback = { callbackOrder.append("reward") }
                        mockAdListener.onDismissCallback = { callbackOrder.append("dismiss") }

                        // Act
                        sut.markRewardEarned()
                        sut.markDismissed()

                        // Assert
                        expect(callbackOrder).to(equal(["reward", "dismiss"]))
                    }
                }
            }

            // MARK: - Lifecycle Events
            describe("lifecycle events") {
                it("should handle impression tracking") {
                    // Act
                    sut.markDisplayed()

                    // Assert
                    expect(mockAdListener.onAdImpressionCallCount).toEventually(equal(1))
                }

                it("should handle click tracking") {
                    // Act
                    sut.markClicked()

                    // Assert
                    expect(mockAdListener.onAdClickCallCount).toEventually(equal(1))
                }

                it("logs presentation failure without calling onError") {
                    // Arrange
                    let testError = NSError(domain: "VungleTest", code: 123, userInfo: nil)

                    // Act
                    sut.handlePresentFailure(testError)

                    // Assert — show-phase errors are logged only, never forwarded to the listener
                    expect(mockAdListener.onErrorCallCount).to(equal(0))
                }

                it("sends MES impression event on markDisplayed") {
                    // Act
                    sut.markDisplayed()

                    // Assert
                    expect(metricReporter.logAdImpressionCallCount).toEventually(equal(1))
                }

                it("sends MES click event on markClicked") {
                    // Act
                    sut.markClicked()

                    // Assert
                    expect(metricReporter.logAdClickCallCount).toEventually(equal(1))
                }
            }
        }
    }
}

// MARK: - Mock Classes

private final class MockAdListener: AdListener {
    var onAdRewardReceivedCallCount = 0
    var onAdImpressionCallCount = 0
    var onAdClickCallCount = 0
    var onAdDismissedCallCount = 0
    var onErrorCallCount = 0
    var lastRewardedAd: MSPAd?
    var lastErrorMessage: String?
    var onRewardCallback: (() -> Void)?
    var onDismissCallback: (() -> Void)?

    func onAdRewardReceived(ad: MSPAd) {
        onAdRewardReceivedCallCount += 1
        lastRewardedAd = ad
        onRewardCallback?()
    }

    func onAdImpression(ad: MSPAd) {
        onAdImpressionCallCount += 1
    }

    func onAdClick(ad: MSPAd) {
        onAdClickCallCount += 1
    }

    func onAdDismissed(ad: MSPiOSCore.MSPAd) {
        onAdDismissedCallCount += 1
        onDismissCallback?()
    }

    func onError(msg: String, loadInfo: [String: Any]) {
        onErrorCallCount += 1
        lastErrorMessage = msg
    }

    func onAdLoaded(placementId: String, loadInfo: [String: Any]) {}

    func getRootViewController() -> UIViewController? {
        UIViewController()
    }
}
