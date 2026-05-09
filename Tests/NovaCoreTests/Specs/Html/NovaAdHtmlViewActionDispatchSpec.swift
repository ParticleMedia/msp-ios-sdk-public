import Nimble
import Quick
import UIKit
import WebKit

@testable import NovaCore

/// FR-021 contract guard: the SDK MUST NOT relay PRD-listed H5-side events
/// (SKIP / Get Rewards / Close / in-H5 video lifecycle) to native callbacks.
/// The only `novaNativeBridge` action that produces a reward signal is `onAdRewarded`.
///
/// Today the routing rule is enforced by absence — `dispatchNovaNativeBridgeAction`
/// has no case for "skip", "getRewards", "close", "video_*" etc., so they fall through
/// the `default` branch as a debug log. This spec freezes that absence so a future
/// engineer cannot quietly add a `case "skip":` that triggers `didEarnReward` or any
/// other delegate method.
final class NovaAdHtmlViewActionDispatchSpec: QuickSpec {
    override class func spec() {
        describe("NovaAdHtmlView.dispatchNovaNativeBridgeAction") {
            var sut: NovaAdHtmlView!
            var spy: SpyHtmlActionDelegate!

            beforeEach {
                sut = NovaAdHtmlView(supportReportHandling: false)
                spy = SpyHtmlActionDelegate()
                sut.htmlActionDelegate = spy
            }

            // MARK: - Positive: the only action that triggers reward

            it("forwards onAdRewarded to didEarnReward") {
                sut.dispatchNovaNativeBridgeAction("onAdRewarded", body: ["action": "onAdRewarded"])

                expect(spy.didEarnRewardCallCount).to(equal(1))
            }

            // MARK: - FR-021 negative: H5-owned events MUST NOT be relayed

            it("does not relay SKIP button to any delegate method") {
                sut.dispatchNovaNativeBridgeAction("skip", body: ["action": "skip", "skip_type": "after_countdown"])

                expect(spy.didEarnRewardCallCount).to(equal(0))
                expect(spy.didTapAdReportCallCount).to(equal(0))
                expect(spy.didTapAdCloseCallCount).to(equal(0))
                expect(spy.didTapAdCtrCallCount).to(equal(0))
                expect(spy.showSKOverlayCallCount).to(equal(0))
            }

            it("does not relay Get Rewards button to any delegate method") {
                sut.dispatchNovaNativeBridgeAction("getRewards", body: ["action": "getRewards"])

                expect(spy.didEarnRewardCallCount).to(equal(0))
                expect(spy.didTapAdReportCallCount).to(equal(0))
                expect(spy.didTapAdCloseCallCount).to(equal(0))
                expect(spy.didTapAdCtrCallCount).to(equal(0))
            }

            it("does not relay Close button success to any delegate method") {
                // PRD lists "Close button → close ad successfully" as an H5-owned event.
                // SDK has its own close routing via the `adClose` script handler (not
                // novaNativeBridge), so a `close` action posted via novaNativeBridge must
                // not be relayed.
                sut.dispatchNovaNativeBridgeAction("close", body: ["action": "close"])

                expect(spy.didEarnRewardCallCount).to(equal(0))
                expect(spy.didTapAdCloseCallCount).to(equal(0))
            }

            it("does not relay in-H5 video lifecycle events to any delegate method") {
                let videoActions = [
                    "video_start", "video_first_quartile", "video_midpoint",
                    "video_third_quartile", "video_complete",
                ]
                for action in videoActions {
                    sut.dispatchNovaNativeBridgeAction(action, body: ["action": action])
                }

                expect(spy.didEarnRewardCallCount).to(equal(0))
                expect(spy.didTapAdReportCallCount).to(equal(0))
                expect(spy.didTapAdCloseCallCount).to(equal(0))
                expect(spy.didTapAdCtrCallCount).to(equal(0))
            }

            it("does not relay an unknown action to any delegate method") {
                sut.dispatchNovaNativeBridgeAction("totallyMadeUp", body: ["action": "totallyMadeUp"])

                expect(spy.didEarnRewardCallCount).to(equal(0))
                expect(spy.didTapAdReportCallCount).to(equal(0))
                expect(spy.didTapAdCloseCallCount).to(equal(0))
                expect(spy.didTapAdCtrCallCount).to(equal(0))
                expect(spy.showSKOverlayCallCount).to(equal(0))
            }

            // MARK: - Sanity: documented actions other than onAdRewarded still work

            it("forwards startFeedback to didTapAdReport") {
                sut.dispatchNovaNativeBridgeAction("startFeedback", body: ["action": "startFeedback"])

                expect(spy.didTapAdReportCallCount).to(equal(1))
                expect(spy.didEarnRewardCallCount).to(equal(0))
            }

            it("forwards open to didTapAdCtr with parsed payload, without firing reward") {
                let payload = #"{"url":"https://example.com","click_area_name":"cta","click_position":3}"#
                sut.dispatchNovaNativeBridgeAction("open", body: ["action": "open", "payload": payload])

                expect(spy.didTapAdCtrCallCount).to(equal(1))
                expect(spy.lastPayload?.url?.absoluteString).to(equal("https://example.com"))
                expect(spy.lastPayload?.clickPosition).to(equal(3))
                expect(spy.didEarnRewardCallCount).to(equal(0))
            }
        }
    }
}

// MARK: - Test double

private final class SpyHtmlActionDelegate: NovaAdHtmlActionDelegate {
    var didEarnRewardCallCount = 0
    var didTapAdReportCallCount = 0
    var didTapAdCloseCallCount = 0
    var didTapAdCtrCallCount = 0
    var showSKOverlayCallCount = 0
    var didFailToLoadPageCallCount = 0
    var lastPayload: NovaAdClickPayload?

    func didTapAdCtr(_ payload: NovaAdClickPayload) {
        didTapAdCtrCallCount += 1
        lastPayload = payload
    }

    func didTapAdReport() {
        didTapAdReportCallCount += 1
    }

    func didTapAdClose() {
        didTapAdCloseCallCount += 1
    }

    func showSKOverlay(appStoreId: Int?) {
        showSKOverlayCallCount += 1
    }

    func didFailToLoadPage(errorType: String, errorDetail: String) {
        didFailToLoadPageCallCount += 1
    }

    func didEarnReward() {
        didEarnRewardCallCount += 1
    }
}
