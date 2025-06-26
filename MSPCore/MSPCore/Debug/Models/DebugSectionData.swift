import Foundation
import MSPiOSCore

// UIConfig for section titles
private enum SectionTitles {
    static let adNetwork = "Ad Network"
    static let adFormat = "Ad Format"
    static let creativeType = "Creative Type (Nova only)"
    static let layout = "Layout (Nova interstitial only)"
    static let highEngagement = "High Engagement (Nova interstitial only)"
}

// Concrete implementation
struct DebugSectionData: DebugSection {
    let title: String
    let options: [DebugOption]
    let showCondition: Set<String>?
    
    init(title: String, options: [DebugOption], showCondition: Set<String>? = nil) {
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
        return DebugSectionData(title: SectionTitles.adNetwork, options: options)
    }
    
    static func adFormatSection() -> DebugSectionData {
        let options = AdFormat.allCases
            .filter { $0.isVisible }
        return DebugSectionData(title: SectionTitles.adFormat, options: options)
    }
    
    static func creativeTypeSection() -> DebugSectionData {
        let options = NovaCreativeType.allCases
            .filter { $0.isVisible }
        return DebugSectionData(
            title: SectionTitles.creativeType, 
            options: options,
            showCondition: [AdNetwork.nova.rawValue]
        )
    }
    
    static func layoutSection() -> DebugSectionData {
        let options = NovaAppOpenAdLayout.allCases
            .filter { $0.isVisible }
        return DebugSectionData(
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
            title: SectionTitles.highEngagement, 
            options: options,
            showCondition: [AdNetwork.nova.rawValue, AdFormat.interstitial.id]
        )
    }
}
