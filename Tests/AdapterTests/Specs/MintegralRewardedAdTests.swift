import MTGSDK
import MTGSDKReward
import Nimble
import Quick

@testable import MSPiOSCore
@testable import MintegralAdapter

class MintegralRewardedAdTests: QuickSpec {
    override class func spec() {
        describe("MintegralRewardedAd") {
            var sut: MintegralRewardedAd!
            var mockAdListener: MockAdListener!
            var mockMTGRewardAdManager: MockMTGRewardAdManager!
            var testReward: Reward!

            beforeEach {
                mockAdListener = MockAdListener()
                testReward = Reward(type: "coins", amount: 10)
                mockMTGRewardAdManager = MockMTGRewardAdManager()
                sut = MintegralRewardedAd(
                    adNetworkAdapter: RewardedAdNetworkAdapterStub(),
                    reward: testReward,
                    placementId: "test-placement",
                    unitId: "test-unit",
                    mtgRewardAdManager: mockMTGRewardAdManager
                )
                sut.adListener = mockAdListener
            }

            afterEach {
                sut = nil
                mockAdListener = nil
                mockMTGRewardAdManager = nil
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
                    it("should call MTGRewardAdManager showVideo API") {
                        // Arrange
                        let mockViewController = UIViewController()

                        // Act
                        MainActor.assumeIsolated {
                            sut.show(rootViewController: mockViewController)
                        }

                        // Assert
                        expect(mockMTGRewardAdManager.showCalled).to(beTrue())
                        expect(mockMTGRewardAdManager.showViewController).to(be(mockViewController))
                    }
                }
            }

            // MARK: - Reward Callback
            describe("reward callback") {
                context("when onVideoAdDismissed is called with converted=true") {
                    it("should fire onAdRewardReceived once then dismiss") {
                        // Arrange
                        var callbackOrder: [String] = []
                        mockAdListener.onRewardCallback = { callbackOrder.append("reward") }
                        mockAdListener.onDismissCallback = { callbackOrder.append("dismiss") }

                        // Act
                        sut.handleDismiss(converted: true)

                        // Assert
                        expect(mockAdListener.onAdRewardReceivedCallCount).to(equal(1))
                        expect(mockAdListener.onAdDismissedCallCount).to(equal(1))
                        expect(callbackOrder).to(equal(["reward", "dismiss"]))
                    }

                    it("should be idempotent - calling twice fires callbacks once only") {
                        // Arrange
                        // Act
                        sut.handleDismiss(converted: true)
                        sut.handleDismiss(converted: true)

                        // Assert
                        expect(mockAdListener.onAdRewardReceivedCallCount).to(equal(1))
                        expect(mockAdListener.onAdDismissedCallCount).to(equal(1))
                    }
                }

                context("when onVideoAdDismissed is called with converted=false") {
                    it("should NOT call onAdRewardReceived") {
                        // Arrange
                        // Act
                        sut.handleDismiss(converted: false)

                        // Assert
                        expect(mockAdListener.onAdRewardReceivedCallCount).to(equal(0))
                        expect(mockAdListener.onAdDismissedCallCount).to(equal(1))
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
                    let testError = NSError(domain: "MintegralTest", code: 789, userInfo: nil)

                    // Act
                    sut.handleShowFailure(testError)

                    // Assert
                    expect(mockAdListener.onErrorCallCount).to(equal(1))
                    expect(mockAdListener.lastErrorMessage).to(contain("789"))
                }
            }
        }
    }
}

// MARK: - Mock Classes

class MockMTGRewardAdManager: MTGBidRewardAdManager {
    var showCalled = false
    var showViewController: UIViewController?

    override func showVideo(
        withPlacementId placementId: String?,
        unitId: String,
        userId: String?,
        delegate: (any MTGRewardAdShowDelegate)?,
        viewController: UIViewController
    ) {
        showCalled = true
        showViewController = viewController
    }
}
