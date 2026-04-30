import Foundation
import MSPiOSCore

extension AdNetwork: TestParamAssembler {
    func assembleTestParams(
        baseParams: [String: Any],
        toggleValues: [String: Bool],
        chipValues: [String: String?]
    ) -> [String: Any] {
        var dict = baseParams

        switch self {
        case .nova:
            let creativeType = (dict.removeValue(forKey: "creative_type") as? String ?? "video").uppercased()
            let isVertical = dict.removeValue(forKey: "is_vertical") as? String
            let layoutDirection = isVertical == "false" ? "horizontal" : "vertical"
            // Remove Nova-only flat keys that are folded into debug_item
            dict.removeValue(forKey: "layout")
            dict.removeValue(forKey: "high_engagement")

            let enableH5 = toggleValues["enable_h5_format"] ?? true
            var expParameter: [String: Any] = ["enable_h5_format": String(enableH5)]
            if let h5Group = chipValues["h5_template_group"] ?? nil {
                expParameter["h5_template_group"] = h5Group
            }

            dict[MSPConstants.TEST_PARAM_KEY_DEBUG_ITEM] =
                [
                    "debug": true,
                    "creative_type": creativeType,
                    "layout": layoutDirection,
                    "exp_parameter": expParameter,
                ] as [String: Any]

        case .google, .facebook, .prebid, .unity, .pubmatic,
            .mintegral, .mobilefuse, .inmobi, .amazon, .moloco, .liftoff, .applovin:
            // Flat params passed through as-is
            break

        case .unknown:
            break
        }

        return dict
    }
}
