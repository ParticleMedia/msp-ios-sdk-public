import Foundation
import Nimble
import Quick

@testable import MSPiOSCore

final class RewardSpec: QuickSpec {
    override class func spec() {
        describe("Reward") {
            it("stores its initializer values") {
                let reward = Reward(type: "coins", amount: 10)

                expect(reward.type).to(equal("coins"))
                expect(reward.amount).to(equal(10))
            }

            it("supports Equatable") {
                expect(Reward(type: "coins", amount: 10)).to(equal(Reward(type: "coins", amount: 10)))
                expect(Reward(type: "coins", amount: 10)).toNot(equal(Reward(type: "lives", amount: 1)))
            }

            it("round-trips through Codable") {
                let reward = Reward(type: "credits", amount: 5)
                let data = try? JSONEncoder().encode(reward)
                let decoded = try? JSONDecoder().decode(Reward.self, from: data ?? Data())

                expect(decoded).to(equal(reward))
            }
        }
    }
}
