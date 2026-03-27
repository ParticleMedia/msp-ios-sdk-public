import MSPGoogleAdsTypes
import Nimble
import Quick
import UIKit

@testable import MSPGoogleAdapter
@testable import MSPiOSCore

final class GoogleRewardedAdRewardTests: QuickSpec {
    override class func spec() {
        describe("GoogleRewardedAd reward flow") {
            var sut: GoogleRewardedAd!
            var listener: RewardedAdListenerSpy!
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
                originalPresenter = GoogleRewardedAd.presenter
            }

            afterEach {
                GoogleRewardedAd.presenter = originalPresenter
            }

            it("fires reward when the reward handler runs") {
                GoogleRewardedAd.presenter = { _, _, rewardHandler in
                    rewardHandler()
                }

                let rootVC = UIViewController()
                MainActor.assumeIsolated {
                    sut.show(rootViewController: rootVC)
                }

                expect(listener.rewardedAds).to(haveCount(1))
            }

            it("fires reward only once when the handler runs twice") {
                GoogleRewardedAd.presenter = { _, _, rewardHandler in
                    rewardHandler()
                    rewardHandler()
                }

                let rootVC = UIViewController()
                MainActor.assumeIsolated {
                    sut.show(rootViewController: rootVC)
                }

                expect(listener.rewardedAds).to(haveCount(1))
            }

            it("does not fire reward on dismiss without reward") {
                sut.markDismissed()

                expect(listener.rewardedAds).to(beEmpty())
            }

            it("keeps reward before dismiss ordering") {
                GoogleRewardedAd.presenter = { _, _, rewardHandler in
                    rewardHandler()
                }

                let rootVC = UIViewController()
                MainActor.assumeIsolated {
                    sut.show(rootViewController: rootVC)
                }
                sut.markDismissed()

                expect(listener.callSequence).to(equal(["reward", "dismiss"]))
            }
        }
    }
}
