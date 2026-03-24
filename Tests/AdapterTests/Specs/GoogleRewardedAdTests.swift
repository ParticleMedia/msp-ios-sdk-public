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

            beforeEach {
                listener = RewardedAdListenerSpy()
                sut = GoogleRewardedAd(
                    adNetworkAdapter: RewardedAdNetworkAdapterStub(),
                    reward: Reward(type: "coins", amount: 10),
                    rewardedAdItem: nil,
                    rootViewController: UIViewController(),
                    adListener: listener
                )
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

                expect(listener.impressedAds).to(haveCount(1))
            }

            it("records dismissal when marked dismissed") {
                sut.markDismissed()

                expect(listener.dismissedAds).to(haveCount(1))
            }

            it("is valid when it holds a rewarded ad item reference") {
                let fakeItem = unsafeBitCast(NSObject(), to: MSPGADRewardedAd?.self)
                sut.rewardedAdItem = fakeItem

                expect(sut.isValid()).to(beTrue())
            }
        }
    }
}
