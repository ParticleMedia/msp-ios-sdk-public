import Foundation
import MSPiOSCore

class TestParams {
    private let testAd: Bool
    private let adNetwork: String?
    private let creativeType: String
    private let creativeLayout: String?
    private let enableH5Format: Bool
    private let h5TemplateGroup: String?

    init(
        testAd: Bool = false,
        adNetwork: String? = nil,
        creativeType: String = "video",
        creativeLayout: String? = "vertical",
        enableH5Format: Bool = true,
        h5TemplateGroup: String? = "h5g3"
    ) {
        self.testAd = testAd
        self.adNetwork = adNetwork
        self.creativeType = creativeType
        self.creativeLayout = creativeLayout
        self.enableH5Format = enableH5Format
        self.h5TemplateGroup = h5TemplateGroup
    }

    func toDictionary() -> [String: Any] {
        guard testAd || !(adNetwork?.isEmpty ?? true) else { return [:] }

        var dict: [String: Any] = ["test_ad": testAd]

        guard let adNetwork else { return dict }
        dict["ad_network"] = adNetwork

        guard adNetwork == "msp_nova" else { return dict }

        var expParameter: [String: Any] = ["enable_h5_format": String(enableH5Format)]
        if let h5TemplateGroup {
            expParameter["h5_template_group"] = h5TemplateGroup
        }

        dict[MSPConstants.TEST_PARAM_KEY_DEBUG_ITEM] =
            [
                "debug": true,
                "creative_type": creativeType.uppercased(),
                "layout": creativeLayout ?? "",
                "exp_parameter": expParameter,
            ] as [String: Any]

        return dict
    }
}
