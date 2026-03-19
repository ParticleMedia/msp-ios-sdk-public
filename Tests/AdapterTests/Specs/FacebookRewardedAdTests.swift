import Nimble
import Quick
import UIKit

import FBAudienceNetwork
@testable import MSPFacebookAdapter
@testable import MSPiOSCore

final class FacebookRewardedAdTests: QuickSpec {
    override class func spec() {
        describe("FacebookRewardedAd") {
            var sut: FacebookRewardedAd!
            var listener: RewardedAdListenerSpy!
            var presentedViewController: UIViewController?
            var presentCallCount: Int!
            var originalPresenter: ((FBRewardedVideoAd?, UIViewController) -> Void)!

            beforeEach {
                listener = RewardedAdListenerSpy()
                sut = FacebookRewardedAd(
                    adNetworkAdapter: RewardedAdNetworkAdapterStub(),
                    reward: Reward(type: "coins", amount: 10),
                    rewardedVideoAdItem: nil,
                    rootViewController: UIViewController(),
                    adListener: listener
                )
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
        }
    }
}
