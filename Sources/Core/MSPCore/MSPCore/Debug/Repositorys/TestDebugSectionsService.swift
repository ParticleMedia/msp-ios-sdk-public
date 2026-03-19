import Foundation
import MSPiOSCore

class TestDebugSectionsService: DebugSectionsRepository {
    func fetchDebugSections(placements: [String]) -> [DebugSection] {
        [
            DebugSectionData.modeSection(),
            DebugSectionData.placementSection(placements: placements),
            DebugSectionData.adNetworkSection(),
            DebugSectionData.adFormatSection(),
            DebugSectionData.rewardTypeSection(),
            DebugSectionData.rewardAmountSection(),
            DebugSectionData.creativeTypeSection(),
            DebugSectionData.layoutSection(),
            DebugSectionData.highEngagementSection(),
            DebugSectionData.customParamsSection(),
        ]
    }
}
