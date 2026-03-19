import Nimble
import Quick

@testable import MSPGoogleAdapter
@testable import MSPiOSCore

final class GoogleRewardedAdConfigTests: QuickSpec {
    override class func spec() {
        describe("Google rewarded config") {
            it("builds the expected custom reward string") {
                let reward = Reward(type: "coins", amount: 10)

                expect(GoogleAdapter.customRewardString(for: reward)).to(equal("coins:10"))
            }

            it("omits server side verification options when reward is nil") {
                expect(GoogleAdapter.serverSideVerificationOptions(for: nil)).to(beNil())
            }

            it("creates server side verification options when reward exists") {
                let reward = Reward(type: "lives", amount: 5)

                expect(GoogleAdapter.serverSideVerificationOptions(for: reward)).toNot(beNil())
            }
        }
    }
}
