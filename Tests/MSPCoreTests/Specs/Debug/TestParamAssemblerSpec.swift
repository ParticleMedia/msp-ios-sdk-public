import Nimble
import Quick

@testable import MSPCore
@testable import MSPiOSCore

class TestParamAssemblerSpec: QuickSpec {
    override class func spec() {
        describe("AdNetwork+TestParamAssembler") {

            // MARK: - Non-Nova networks

            context("when network is Google") {
                it("should pass through flat params unchanged") {
                    let baseParams: [String: Any] = [
                        "test_ad": true,
                        "ad_network": "msp_google",
                    ]

                    let result = AdNetwork.google.assembleTestParams(
                        baseParams: baseParams, toggleValues: [:], chipValues: [:])

                    expect(result["test_ad"] as? Bool).to(beTrue())
                    expect(result["ad_network"] as? String).to(equal("msp_google"))
                    expect(result[MSPConstants.TEST_PARAM_KEY_DEBUG_ITEM]).to(beNil())
                }
            }

            context("when network is Facebook") {
                it("should pass through flat params unchanged") {
                    let baseParams: [String: Any] = [
                        "test_ad": true,
                        "ad_network": "msp_fb",
                    ]

                    let result = AdNetwork.facebook.assembleTestParams(
                        baseParams: baseParams, toggleValues: [:], chipValues: [:])

                    expect(result["ad_network"] as? String).to(equal("msp_fb"))
                    expect(result[MSPConstants.TEST_PARAM_KEY_DEBUG_ITEM]).to(beNil())
                }
            }

            context("when flat params include reward fields") {
                it("should preserve reward_type and reward_amount for non-Nova") {
                    let baseParams: [String: Any] = [
                        "test_ad": true,
                        "ad_network": "msp_google",
                        "reward_type": "coin",
                        "reward_amount": "10",
                    ]

                    let result = AdNetwork.google.assembleTestParams(
                        baseParams: baseParams, toggleValues: [:], chipValues: [:])

                    expect(result["reward_type"] as? String).to(equal("coin"))
                    expect(result["reward_amount"] as? String).to(equal("10"))
                }
            }

            // MARK: - Nova network

            context("when network is Nova") {
                it("should produce debug_item with uppercased creative_type") {
                    let baseParams: [String: Any] = [
                        "test_ad": true,
                        "ad_network": "msp_nova",
                        "creative_type": "image",
                    ]

                    let result = AdNetwork.nova.assembleTestParams(
                        baseParams: baseParams, toggleValues: [:], chipValues: [:])

                    let debugItem = result[MSPConstants.TEST_PARAM_KEY_DEBUG_ITEM] as? [String: Any]
                    expect(debugItem).toNot(beNil())
                    expect(debugItem?["debug"] as? Bool).to(beTrue())
                    expect(debugItem?["creative_type"] as? String).to(equal("IMAGE"))
                }

                it("should default creative_type to VIDEO when not provided") {
                    let baseParams: [String: Any] = [
                        "test_ad": true,
                        "ad_network": "msp_nova",
                    ]

                    let result = AdNetwork.nova.assembleTestParams(
                        baseParams: baseParams, toggleValues: [:], chipValues: [:])

                    let debugItem = result[MSPConstants.TEST_PARAM_KEY_DEBUG_ITEM] as? [String: Any]
                    expect(debugItem?["creative_type"] as? String).to(equal("VIDEO"))
                }

                it("should derive layout direction from is_vertical") {
                    let verticalParams: [String: Any] = [
                        "test_ad": true,
                        "ad_network": "msp_nova",
                        "is_vertical": "true",
                    ]

                    let verticalResult = AdNetwork.nova.assembleTestParams(
                        baseParams: verticalParams, toggleValues: [:], chipValues: [:])
                    let verticalItem = verticalResult[MSPConstants.TEST_PARAM_KEY_DEBUG_ITEM] as? [String: Any]
                    expect(verticalItem?["layout"] as? String).to(equal("vertical"))

                    let horizontalParams: [String: Any] = [
                        "test_ad": true,
                        "ad_network": "msp_nova",
                        "is_vertical": "false",
                    ]

                    let horizontalResult = AdNetwork.nova.assembleTestParams(
                        baseParams: horizontalParams, toggleValues: [:], chipValues: [:])
                    let horizontalItem = horizontalResult[MSPConstants.TEST_PARAM_KEY_DEBUG_ITEM] as? [String: Any]
                    expect(horizontalItem?["layout"] as? String).to(equal("horizontal"))
                }

                it("should include enable_h5_format from toggle values") {
                    let baseParams: [String: Any] = [
                        "test_ad": true,
                        "ad_network": "msp_nova",
                    ]
                    let toggleValues = ["enable_h5_format": false]

                    let result = AdNetwork.nova.assembleTestParams(
                        baseParams: baseParams, toggleValues: toggleValues, chipValues: [:])

                    let debugItem = result[MSPConstants.TEST_PARAM_KEY_DEBUG_ITEM] as? [String: Any]
                    let expParam = debugItem?["exp_parameter"] as? [String: Any]
                    expect(expParam?["enable_h5_format"] as? String).to(equal("false"))
                }

                it("should default enable_h5_format to true when toggle not present") {
                    let baseParams: [String: Any] = [
                        "test_ad": true,
                        "ad_network": "msp_nova",
                    ]

                    let result = AdNetwork.nova.assembleTestParams(
                        baseParams: baseParams, toggleValues: [:], chipValues: [:])

                    let debugItem = result[MSPConstants.TEST_PARAM_KEY_DEBUG_ITEM] as? [String: Any]
                    let expParam = debugItem?["exp_parameter"] as? [String: Any]
                    expect(expParam?["enable_h5_format"] as? String).to(equal("true"))
                }

                it("should include h5_template_group from chip values") {
                    let baseParams: [String: Any] = [
                        "test_ad": true,
                        "ad_network": "msp_nova",
                    ]
                    let chipValues: [String: String?] = ["h5_template_group": "t2g3"]

                    let result = AdNetwork.nova.assembleTestParams(
                        baseParams: baseParams, toggleValues: [:], chipValues: chipValues)

                    let debugItem = result[MSPConstants.TEST_PARAM_KEY_DEBUG_ITEM] as? [String: Any]
                    let expParam = debugItem?["exp_parameter"] as? [String: Any]
                    expect(expParam?["h5_template_group"] as? String).to(equal("t2g3"))
                }

                it("should omit h5_template_group when chip is nil") {
                    let baseParams: [String: Any] = [
                        "test_ad": true,
                        "ad_network": "msp_nova",
                    ]
                    let chipValues: [String: String?] = ["h5_template_group": nil]

                    let result = AdNetwork.nova.assembleTestParams(
                        baseParams: baseParams, toggleValues: [:], chipValues: chipValues)

                    let debugItem = result[MSPConstants.TEST_PARAM_KEY_DEBUG_ITEM] as? [String: Any]
                    let expParam = debugItem?["exp_parameter"] as? [String: Any]
                    expect(expParam?["h5_template_group"]).to(beNil())
                }

                it("should remove Nova-only flat keys from top-level dict") {
                    let baseParams: [String: Any] = [
                        "test_ad": true,
                        "ad_network": "msp_nova",
                        "creative_type": "video",
                        "is_vertical": "true",
                        "layout": "end_card_2_part",
                        "high_engagement": "true",
                    ]

                    let result = AdNetwork.nova.assembleTestParams(
                        baseParams: baseParams, toggleValues: [:], chipValues: [:])

                    expect(result["creative_type"]).to(beNil())
                    expect(result["is_vertical"]).to(beNil())
                    expect(result["layout"]).to(beNil())
                    expect(result["high_engagement"]).to(beNil())
                    expect(result[MSPConstants.TEST_PARAM_KEY_DEBUG_ITEM]).toNot(beNil())
                }

                it("should preserve reward fields alongside debug_item for Nova rewarded") {
                    let baseParams: [String: Any] = [
                        "test_ad": true,
                        "ad_network": "msp_nova",
                        "reward_type": "coin",
                        "reward_amount": "10",
                    ]

                    let result = AdNetwork.nova.assembleTestParams(
                        baseParams: baseParams, toggleValues: [:], chipValues: [:])

                    expect(result["reward_type"] as? String).to(equal("coin"))
                    expect(result["reward_amount"] as? String).to(equal("10"))
                    expect(result[MSPConstants.TEST_PARAM_KEY_DEBUG_ITEM]).toNot(beNil())
                }
            }
        }
    }
}
