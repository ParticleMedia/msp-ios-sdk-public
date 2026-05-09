import Nimble
import Quick
import UIKit

@testable import MSPiOSCore
@testable import MSPNovaAdapter

final class NovaRewardedAdTests: QuickSpec {
    override class func spec() {
        describe("NovaRewardedAd") {
            var sut: NovaRewardedAd!
            var listener: RewardedAdListenerSpy!
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
                sut = NovaRewardedAd(
                    adNetworkAdapter: adapter,
                    reward: Reward(type: "coins", amount: 5),
                    rootViewController: nil,
                    adListener: listener
                )
                adapter.mspAd = sut
                adapter.adListener = listener
            }

            afterEach {
                adapter.mspAd = nil
            }

            // MARK: - Impression

            describe("markDisplayed") {
                it("fires onAdImpression on listener") {
                    sut.markDisplayed()

                    expect(listener.impressedAds).toEventually(haveCount(1))
                }

                it("sends MES impression event") {
                    sut.markDisplayed()

                    expect(metricReporter.logAdImpressionCallCount).toEventually(equal(1))
                }

                it("fires impression only once when called twice") {
                    sut.markDisplayed()
                    sut.markDisplayed()

                    expect(metricReporter.logAdImpressionCallCount).toEventually(equal(1))
                }
            }

            // MARK: - Click

            describe("markClicked") {
                it("fires onAdClick on listener") {
                    sut.markClicked()

                    expect(listener.clickedAds).toEventually(haveCount(1))
                }

                it("sends MES click event") {
                    sut.markClicked()

                    expect(metricReporter.logAdClickCallCount).toEventually(equal(1))
                }

                it("fires click only once when called twice") {
                    sut.markClicked()
                    sut.markClicked()

                    expect(metricReporter.logAdClickCallCount).toEventually(equal(1))
                }

                it("passes click metadata to MES reporter") {
                    let metadata = AdClickMetadata(clickAreaName: "cta", clickPosition: 7)

                    sut.markClicked(clickMetadata: metadata)

                    expect(metricReporter.lastClickMetadata?.clickAreaName).toEventually(equal("cta"))
                    expect(metricReporter.lastClickMetadata?.clickPosition).toEventually(equal(7))
                }
            }

            // MARK: - Reward

            describe("markRewardEarned") {
                it("fires onAdRewardReceived on listener") {
                    sut.markRewardEarned()

                    expect(listener.rewardedAds).to(haveCount(1))
                }

                it("fires reward only once when called twice") {
                    sut.markRewardEarned()
                    sut.markRewardEarned()

                    expect(listener.rewardedAds).to(haveCount(1))
                }
            }

            // MARK: - Dismiss

            describe("markDismissed") {
                it("fires onAdDismissed on listener") {
                    sut.markDismissed()

                    expect(listener.dismissedAds).to(haveCount(1))
                }

                it("does not fire reward on dismiss without prior reward") {
                    sut.markDismissed()

                    expect(listener.rewardedAds).to(beEmpty())
                }

                it("drops reward callback after dismiss") {
                    sut.markDismissed()
                    sut.markRewardEarned()

                    expect(listener.rewardedAds).to(beEmpty())
                    expect(metricReporter.logAdRewardedCallCount).to(equal(0))
                    expect(listener.callSequence).to(equal(["dismiss"]))
                }

                it("keeps reward before dismiss ordering") {
                    sut.markRewardEarned()
                    sut.markDismissed()

                    expect(listener.callSequence).to(equal(["reward", "dismiss"]))
                }
            }

            // MARK: - Show

            describe("show") {
                it("logs error without calling onError when no adItem and no rootViewController") {
                    MainActor.assumeIsolated {
                        sut.show(rootViewController: nil)
                    }

                    expect(listener.errors).to(beEmpty())
                }
            }

            // MARK: - isValid

            describe("isValid") {
                it("returns false when rewardedAdItem is nil") {
                    expect(sut.isValid()).to(beFalse())
                }
            }
        }

        describe("NovaAdapter rewarded load validation") {
            var adapter: NovaAdapter!
            var listener: RewardedAdListenerSpy!
            var auctionListener: NovaRewardedAuctionBidListenerSpy!
            var adRequest: AdRequest!

            beforeEach {
                adapter = NovaAdapter()
                listener = RewardedAdListenerSpy()
                auctionListener = NovaRewardedAuctionBidListenerSpy()
                adapter.auctionBidListener = auctionListener
                adRequest = AdRequest(
                    customParams: [:],
                    geo: nil,
                    context: nil,
                    adaptiveBannerSize: nil,
                    adSize: nil,
                    placementId: "nova-ios-reward-fullscreen-prod-ob",
                    adFormat: .rewarded
                )
            }

            it("fails load when Nova response has no rewarded item") {
                adapter.loadTestAdCreative(
                    adString: #"{"ad":[]}"#,
                    adListener: listener,
                    context: adapter,
                    adRequest: adRequest
                )

                expect(auctionListener.errors).toEventually(equal(["no valid response"]))
            }

            it("fails load when rewarded creative is not HTML") {
                adapter.loadTestAdCreative(
                    adString: Self.novaResponse(creativeType: "IMAGE"),
                    adListener: listener,
                    context: adapter,
                    adRequest: adRequest
                )

                expect(auctionListener.errors).toEventually(
                    equal(["no buildable rewarded ad item from Nova response"])
                )
            }
        }
    }

    private static func novaResponse(creativeType: String) -> String {
        """
        {
          "ad": [
            {
              "creative": {
                "ctrUrl": "https://example.com",
                "creativeType": "\(creativeType)",
                "imageUrl": "https://example.com/image.png"
              },
              "encryptedAdToken": "encrypted-token",
              "adId": "ad-id",
              "adsetId": "ad-set-id",
              "requestId": "request-id",
              "price": 1.23
            }
          ]
        }
        """
    }
}

private final class NovaRewardedAuctionBidListenerSpy: AuctionBidListener {
    var errors: [String] = []
    var successBids: [AuctionBid] = []

    func onSuccess(bid: AuctionBid, loadInfo: [String: Any]) {
        successBids.append(bid)
    }

    func onError(error: String, loadInfo: [String: Any]) {
        errors.append(error)
    }
}
