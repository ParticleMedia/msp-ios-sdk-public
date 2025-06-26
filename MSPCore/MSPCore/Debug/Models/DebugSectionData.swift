import Foundation
import MSPiOSCore

// Concrete implementation
struct DebugSectionData: DebugSection {
    let title: String
    let options: [DebugOptionable]
    
    init(title: String, options: [DebugOptionable]) {
        self.title = title
        self.options = options
    }
}

// Factory methods for creating debug section data
extension DebugSectionData {
    static func adNetworkSection() -> DebugSectionData {
        let options = AdNetwork.allCases
            .filter { $0.isVisible }
        return DebugSectionData(title: "Ad Network", options: options)
    }
    
    static func adFormatSection() -> DebugSectionData {
        let options = AdFormat.allCases
            .filter { $0.isVisible }
        return DebugSectionData(title: "Ad Format", options: options)
    }
    
    static func creativeTypeSection() -> DebugSectionData {
        let options = NovaCreativeType.allCases
            .filter { $0.isVisible }
        return DebugSectionData(title: "Creative Type (Nova only)", options: options)
    }
    
    static func layoutSection() -> DebugSectionData {
        let options = NovaAppOpenAdLayout.allCases
            .filter { $0.isVisible }
        return DebugSectionData(title: "Layout (Nova interstitial only)", options: options)
    }
    
    static func highEngagementSection() -> DebugSectionData {
        let options = [
            HighEngagementOption.yes,
            HighEngagementOption.no
        ]
        return DebugSectionData(title: "High Engagement (Nova interstitial only)", options: options)
    }
}
