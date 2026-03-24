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

            beforeEach {
                mockAdListener = MockAdListener()
                testReward = Reward(type: "coins", amount: 10)
                vungleRewarded = VungleRewarded(placementId: "test-placement")
                sut = LiftoffRewardedAd(
                    adNetworkAdapter: RewardedAdNetworkAdapterStub(),
                    reward: testReward,
                    vungleRewarded: vungleRewarded
                )
                sut.adListener = mockAdListener
            }

            afterEach {
                sut = nil
                mockAdListener = nil
                vungleRewarded = nil
                testReward = nil
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
                    it("should report an error") {
                        sut.show(rootViewController: nil)

                        expect(mockAdListener.onErrorCallCount).to(equal(1))
                        expect(mockAdListener.lastErrorMessage).to(contain("Root view controller is required"))
                    }
                }
            }

            // MARK: - Reward Callback
            describe("reward callback") {
                context("when rewardedAdDidRewardUser is called") {
                    it("should fire onAdRewardReceived once") {
                        // Arrange
                        // Act
                        sut.handleReward()

                        // Assert
                        expect(mockAdListener.onAdRewardReceivedCallCount).to(equal(1))
                        expect(mockAdListener.lastRewardedAd).to(be(sut))
                    }

                    it("should be idempotent - calling twice fires callback once only") {
                        // Arrange
                        // Act
                        sut.handleReward()
                        sut.handleReward()

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
                        sut.handleDismiss()

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
                        sut.handleReward()
                        sut.handleDismiss()

                        // Assert
                        expect(callbackOrder).to(equal(["reward", "dismiss"]))
                    }
                }
            }

            // MARK: - Lifecycle Events
            describe("lifecycle events") {
                it("should handle impression tracking") {
                    // Act
                    sut.handleImpression()

                    // Assert
                    expect(mockAdListener.onAdImpressionCallCount).to(equal(1))
                }

                it("should handle click tracking") {
                    // Act
                    sut.handleClick()

                    // Assert
                    expect(mockAdListener.onAdClickCallCount).to(equal(1))
                }

                it("should handle presentation failure") {
                    // Arrange
                    let testError = NSError(domain: "VungleTest", code: 123, userInfo: nil)

                    // Act
                    sut.handlePresentFailure(testError)

                    // Assert
                    expect(mockAdListener.onErrorCallCount).to(equal(1))
                    expect(mockAdListener.lastErrorMessage).to(contain("123"))
                }
            }
        }
    }
}

// MARK: - Mock Classes

class MockAdListener: AdListener {
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
