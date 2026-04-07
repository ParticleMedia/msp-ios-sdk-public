import Nimble
import Quick
@testable import NovaCore

final class NovaTwoPartPlayableLayoutMetricsSpec: QuickSpec {
    override class func spec() {
        describe("NovaTwoPartPlayableLayoutMetrics") {
            describe("bottomBannerInset") {
                it("[TPB001] uses safe area when the device has a home indicator") {
                    expect(NovaTwoPartPlayableLayoutMetrics.bottomBannerInset(for: 34)).to(equal(34))
                }

                it("[TPB002] preserves a minimum bottom inset when safe area is zero") {
                    expect(NovaTwoPartPlayableLayoutMetrics.bottomBannerInset(for: 0)).to(equal(12))
                }

                it("[TPB003] floors small safe areas to the minimum inset") {
                    expect(NovaTwoPartPlayableLayoutMetrics.bottomBannerInset(for: 8)).to(equal(12))
                }
            }
        }
    }
}
