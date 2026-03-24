import MobileFuseSDK
import Nimble
import Quick

@testable import MSPiOSCore
@testable import MobilefuseAdapter

class MobilefuseRewardedAdTests: QuickSpec {
    override class func spec() {
        describe("MobilefuseRewardedAd") {
            var sut: MobilefuseRewardedAd!
            var mockAdListener: MockAdListener!
            var mockMFRewardedAd: MockMFRewardedAd!
            var testReward: Reward!

            beforeEach {
                mockAdListener = MockAdListener()
                testReward = Reward(type: "coins", amount: 10)
                mockMFRewardedAd = MockMFRewardedAd(placementId: "test-placement")
                sut = MobilefuseRewardedAd(
                    adNetworkAdapter: RewardedAdNetworkAdapterStub(),
                    reward: testReward,
                    mfRewardedAd: mockMFRewardedAd
                )
                sut.adListener = mockAdListener
            }

            afterEach {
                sut = nil
                mockAdListener = nil
                mockMFRewardedAd = nil
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
                context("when called with root view controller") {
                    it("should call MFRewardedAd.show()") {
                        // Arrange
                        let mockViewController = UIViewController()

                        // Act
                        MainActor.assumeIsolated {
                            sut.show(rootViewController: mockViewController)
                        }

                        // Assert
                        expect(mockMFRewardedAd.showCalled).to(beTrue())
                    }
                }
            }

            // MARK: - Reward Callback
            describe("reward callback") {
                context("when reward is earned") {
                    it("should fire onAdRewardReceived once") {
                        // Act
                        sut.handleRewardEarned()

                        // Assert
                        expect(mockAdListener.onAdRewardReceivedCallCount).to(equal(1))
                        expect(mockAdListener.lastRewardedAd).to(be(sut))
                    }

                    it("should be idempotent - calling twice fires callback once only") {
                        // Act
                        sut.handleRewardEarned()
                        sut.handleRewardEarned()

                        // Assert
                        expect(mockAdListener.onAdRewardReceivedCallCount).to(equal(1))
                    }
                }
            }

            // MARK: - Dismiss Callback
            describe("dismiss callback") {
                context("when ad is closed without prior reward") {
                    it("should NOT call onAdRewardReceived") {
                        // Act
                        sut.handleAdClosed()

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
                        sut.handleRewardEarned()
                        sut.handleAdClosed()

                        // Assert
                        expect(callbackOrder).to(equal(["reward", "dismiss"]))
                    }
                }
            }

            // MARK: - Lifecycle Events
            describe("lifecycle events") {
                it("should handle impression tracking") {
                    // Act
                    sut.handleAdRendered()

                    // Assert
                    expect(mockAdListener.onAdImpressionCallCount).to(equal(1))
                }

                it("should handle click tracking") {
                    // Act
                    sut.handleAdClicked()

                    // Assert
                    expect(mockAdListener.onAdClickCallCount).to(equal(1))
                }

                it("should handle error") {
                    // Act
                    sut.handleAdError(reason: "Test error")

                    // Assert
                    expect(mockAdListener.onErrorCallCount).to(equal(1))
                    expect(mockAdListener.lastErrorMessage).to(contain("Test error"))
                }
            }
        }
    }
}

// MARK: - Mock Classes

class MockMFRewardedAd: MFRewardedAd {
    var showCalled = false

    override func show() {
        showCalled = true
    }
}
