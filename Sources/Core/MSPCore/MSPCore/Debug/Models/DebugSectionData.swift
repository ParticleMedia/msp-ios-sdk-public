// Concrete implementation
import Foundation
import MSPiOSCore

struct DebugSectionData: DebugSection {
    // UIConfig for section titles and IDs
    enum SectionTitles {
        static let mode = "Load Mode"
        static let placement = "Placement"
        static let adNetwork = "Ad Network"
        static let adFormat = "Ad Format"
        static let rewardType = "Reward Type"
        static let rewardAmount = "Reward Amount"
        static let creativeType = "Creative Type (Nova only)"
        static let layout = "Layout (Nova interstitial only)"
        static let highEngagement = "High Engagement (Nova interstitial only)"
        static let customParams = "Custom Params (Nova only)"
    }

    enum SectionIds {
        static let mode = "mode"
        static let placement = "placement"
        static let adNetwork = "adNetwork"
        static let adFormat = "adFormat"
        static let rewardType = "rewardType"
        static let rewardAmount = "rewardAmount"
        static let creativeType = "creativeType"
        static let layout = "layout"
        static let highEngagement = "highEngagement"
        static let customParams = "customParams"
    }

    let id: String
    let title: String
    let options: [DebugOption]
    let showCondition: Set<String>?
    let toggleItems: [DebugToggleItem]
    let chipGroupItems: [DebugChipGroupItem]

    init(
        id: String,
        title: String,
        options: [DebugOption],
        showCondition: Set<String>? = nil,
        toggleItems: [DebugToggleItem] = [],
        chipGroupItems: [DebugChipGroupItem] = []
    ) {
        self.id = id
        self.title = title
        self.options = options
        self.showCondition = showCondition
        self.toggleItems = toggleItems
        self.chipGroupItems = chipGroupItems
    }
}

enum DebugLoadMode: CaseIterable, DebugOption {
    case mspAuction
    case scopedNetwork

    var id: String {
        switch self {
        case .mspAuction:
            return "mspAuction"
        case .scopedNetwork:
            return "scopedNetwork"
        }
    }

    var displayTitle: String {
        switch self {
        case .mspAuction:
            return "MSP Auction"
        case .scopedNetwork:
            return "Direct Network (C2S)"
        }
    }

    var isVisible: Bool { true }
}

// Factory methods for creating debug section data
extension DebugSectionData {
    static func modeSection() -> DebugSectionData {
        DebugSectionData(id: SectionIds.mode, title: SectionTitles.mode, options: DebugLoadMode.allCases)
    }

    static func adNetworkSection() -> DebugSectionData {
        var options: [DebugOption] = [DebugAllNetworksOption()]
        options.append(contentsOf: AdNetwork.allCases.filter { $0.isVisible })
        return DebugSectionData(id: SectionIds.adNetwork, title: SectionTitles.adNetwork, options: options)
    }

    static func adFormatSection() -> DebugSectionData {
        let options = AdFormat.allCases
            .filter { $0.isVisible }
        return DebugSectionData(id: SectionIds.adFormat, title: SectionTitles.adFormat, options: options)
    }

    static func creativeTypeSection() -> DebugSectionData {
        let options = NovaCreativeType.allCases
            .filter { $0.isVisible }
        return DebugSectionData(
            id: SectionIds.creativeType,
            title: SectionTitles.creativeType,
            options: options,
            showCondition: [AdNetwork.nova.rawValue, DebugLoadMode.mspAuction.id]
        )
    }

    static func rewardTypeSection() -> DebugSectionData {
        let options = RewardTypeOption.allCases.filter { $0.isVisible }
        return DebugSectionData(
            id: SectionIds.rewardType,
            title: SectionTitles.rewardType,
            options: options,
            showCondition: [AdFormat.rewarded.id]
        )
    }

    static func rewardAmountSection() -> DebugSectionData {
        let options = RewardAmountOption.allCases.filter { $0.isVisible }
        return DebugSectionData(
            id: SectionIds.rewardAmount,
            title: SectionTitles.rewardAmount,
            options: options,
            showCondition: [AdFormat.rewarded.id]
        )
    }

    static func layoutSection() -> DebugSectionData {
        let options = NovaInterstitialAdLayout.allCases
            .filter { $0.isVisible }
        return DebugSectionData(
            id: SectionIds.layout,
            title: SectionTitles.layout,
            options: options,
            showCondition: [AdNetwork.nova.rawValue, AdFormat.interstitial.id, DebugLoadMode.mspAuction.id]
        )
    }

    static func highEngagementSection() -> DebugSectionData {
        let options = [
            HighEngagementOption.yes,
            HighEngagementOption.no,
        ]
        return DebugSectionData(
            id: SectionIds.highEngagement,
            title: SectionTitles.highEngagement,
            options: options,
            showCondition: [AdNetwork.nova.rawValue, AdFormat.interstitial.id, DebugLoadMode.mspAuction.id]
        )
    }

    enum H5TemplateGroupOptions {
        static let imageVideo: [DebugChipGroupItem.ChipOption] = [
            .init(id: "t1", title: "t1"),
            .init(id: "t2g1", title: "t2g1"),
            .init(id: "t2g2", title: "t2g2"),
            .init(id: "t2g3", title: "t2g3"),
            .init(id: "t1nb", title: "t1nb"),
            .init(id: "t1nb-v1", title: "t1nb-v1"),
        ]
        static let playableVideo: [DebugChipGroupItem.ChipOption] = [
            .init(id: "t3g1", title: "t3g1"),
            .init(id: "t1nb", title: "t1nb"),
            .init(id: "t1nb-v1", title: "t1nb-v1"),
        ]
    }

    static func customParamsSection() -> DebugSectionData {
        DebugSectionData(
            id: SectionIds.customParams,
            title: SectionTitles.customParams,
            options: [],
            showCondition: [AdNetwork.nova.rawValue],
            toggleItems: [
                DebugToggleItem(id: MSPConstants.USE_NOVA_SANDBOX, title: "Nova Sandbox"),
                DebugToggleItem(id: "enable_h5_format", title: "Enable H5 Format"),
            ],
            chipGroupItems: [
                DebugChipGroupItem(
                    id: "h5_template_group",
                    title: "H5 Template Group",
                    options: H5TemplateGroupOptions.imageVideo
                )
            ]
        )
    }

    static func placementSection(placements: [String]) -> DebugSectionData {
        let options = placements.map { placement in
            PlacementOption(placementId: placement)
        }
        return DebugSectionData(
            id: SectionIds.placement,
            title: SectionTitles.placement,
            options: options,
            showCondition: [DebugLoadMode.mspAuction.id]
        )
    }
}
