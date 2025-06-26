import Foundation
import MSPiOSCore

class TestDebugSectionsService: DebugSectionsRepository {
    func fetchDebugSections(placements: [String]) -> [DebugSection] {
        return [
            DebugSectionData.adNetworkSection(),
            DebugSectionData.adFormatSection(),
            DebugSectionData.creativeTypeSection(),
            DebugSectionData.layoutSection(),
            DebugSectionData.highEngagementSection()
        ]
    }
} 