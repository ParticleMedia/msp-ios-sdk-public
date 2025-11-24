import Foundation
import MSPiOSCore

// Concrete implementation
struct DebugSectionData: DebugSection {
    // UIConfig for section titles and IDs
    enum SectionTitles {
        static let placement = "Placement"
        static let adNetwork = "Ad Network"
        static let adFormat = "Ad Format"
        static let creativeType = "Creative Type (Nova only)"
        static let layout = "Layout (Nova interstitial only)"
        static let highEngagement = "High Engagement (Nova interstitial only)"
    }
    
    enum SectionIds {
        static let placement = "placement"
        static let adNetwork = "adNetwork"
        static let adFormat = "adFormat"
        static let creativeType = "creativeType"
        static let layout = "layout"
        static let highEngagement = "highEngagement"
    }

    let id: String
    let title: String
    let options: [DebugOption]
    let showCondition: Set<String>?
    
    init(id: String, title: String, options: [DebugOption], showCondition: Set<String>? = nil) {
        self.id = id
        self.title = title
        self.options = options
        self.showCondition = showCondition
    }
}

// Factory methods for creating debug section data
extension DebugSectionData {
    static func adNetworkSection() -> DebugSectionData {
        let options = AdNetwork.allCases
            .filter { $0.isVisible }
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
            showCondition: [AdNetwork.nova.rawValue]
        )
    }
    
    static func layoutSection() -> DebugSectionData {
        let options = NovaInterstitialAdLayout.allCases
            .filter { $0.isVisible }
        return DebugSectionData(
            id: SectionIds.layout,
            title: SectionTitles.layout, 
            options: options,
            showCondition: [AdNetwork.nova.rawValue, AdFormat.interstitial.id]
        )
    }
    
    static func highEngagementSection() -> DebugSectionData {
        let options = [
            HighEngagementOption.yes,
            HighEngagementOption.no
        ]
        return DebugSectionData(
            id: SectionIds.highEngagement,
            title: SectionTitles.highEngagement, 
            options: options,
            showCondition: [AdNetwork.nova.rawValue, AdFormat.interstitial.id]
        )
    }
    
    static func placementSection(placements: [String]) -> DebugSectionData {
        let options = placements.map { placement in
            return PlacementOption(placementId: placement)
        }
        return DebugSectionData(
            id: SectionIds.placement,
            title: SectionTitles.placement, 
            options: options
        )
    }
}
