import Foundation
import MSPiOSCore

struct TestParams {
    static let adNetworks = ["msp_fb", "msp_google", "msp_nova", "vungle", "msp_moloco_native"]
    static let creativeTypes = ["video", "image", "playable_video"]
    static let creativeLayouts = ["vertical", "horizontal"]
    // Aligned with Android DemoApp's rewarded / interstitial template groups.
    // video / image: 7 templates; playable_video: 2 templates.
    static let h5TemplateGroupsImageVideo = ["t1", "t1nb", "t1tob", "t1tob-v1", "t2g1", "t2g2", "t2g3"]
    static let h5TemplateGroupsPlayableVideo = ["t1nb", "t3g1"]

    private let testAd: Bool
    private let adNetwork: String?
    private let creativeType: String
    private let creativeLayout: String?
    private let enableH5Format: Bool
    private let h5TemplateGroup: String?
    private let preload: Bool

    init(
        testAd: Bool = false,
        adNetwork: String? = nil,
        creativeType: String = "video",
        creativeLayout: String? = "vertical",
        enableH5Format: Bool = true,
        h5TemplateGroup: String? = "t1tob",
        preload: Bool = true
    ) {
        self.testAd = testAd
        self.adNetwork = adNetwork
        self.creativeType = creativeType
        self.creativeLayout = creativeLayout
        self.enableH5Format = enableH5Format
        self.h5TemplateGroup = h5TemplateGroup
        self.preload = preload
    }

    func toDictionary() -> [String: Any] {
        guard testAd || !(adNetwork?.isEmpty ?? true) else { return [:] }

        var dict: [String: Any] = ["test_ad": testAd]

        guard let adNetwork else { return dict }
        dict["ad_network"] = adNetwork

        guard adNetwork == "msp_nova" else { return dict }

        var expParameter: [String: Any] = [
            "enable_h5_format": String(enableH5Format),
            "preload": String(preload),
        ]
        
        if creativeType == "playable_video" {
            expParameter["enable_h5_for_playable"] = "true"
        }
        
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
