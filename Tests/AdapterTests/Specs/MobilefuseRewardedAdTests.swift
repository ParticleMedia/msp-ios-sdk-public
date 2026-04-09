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
            var adapter: RewardedAdNetworkAdapterStub!
            var metricReporter: SpyAdMetricReporter!

            beforeEach {
                mockAdListener = MockAdListener()
                testReward = Reward(type: "coins", amount: 10)
                mockMFRewardedAd = MockMFRewardedAd(placementId: "test-placement")
                metricReporter = SpyAdMetricReporter()
                adapter = RewardedAdNetworkAdapterStub()
                adapter.adRequest = AdRequest(
                    customParams: [:], geo: nil, context: nil,
                    adaptiveBannerSize: nil, adSize: nil,
                    placementId: "test", adFormat: .rewarded
                )
                adapter.adMetricReporter = metricReporter
                sut = MobilefuseRewardedAd(
                    adNetworkAdapter: adapter,
                    reward: testReward,
                    mfRewardedAd: mockMFRewardedAd
                )
                sut.adListener = mockAdListener
                adapter.mspAd = sut
                adapter.adListener = mockAdListener
            }

            afterEach {
                sut = nil
                mockAdListener = nil
                mockMFRewardedAd = nil
                testReward = nil
                adapter.mspAd = nil
                adapter = nil
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
                        sut.markRewardEarned()

                        // Assert
                        expect(mockAdListener.onAdRewardReceivedCallCount).to(equal(1))
                        expect(mockAdListener.lastRewardedAd).to(be(sut))
                    }

                    it("should be idempotent - calling twice fires callback once only") {
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
                context("when ad is closed without prior reward") {
                    it("should NOT call onAdRewardReceived") {
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

                it("logs error without calling onError") {
                    // Act
                    sut.handleAdError(reason: "Test error")

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

class MockMFRewardedAd: MFRewardedAd {
    var showCalled = false

    override func show() {
        showCalled = true
    }
}
