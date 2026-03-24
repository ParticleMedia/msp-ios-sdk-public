@testable import MSPCore

enum TestDataFactory {
    static func createSimpleSection(
        id: String,
        title: String,
        optionCount: Int,
        showCondition: Set<String>? = nil
    ) -> FakeDebugSection {
        let options = (0..<optionCount).map { index in
            FakeDebugOption(
                id: "\(id)_option_\(index)",
                displayTitle: "Option \(index)"
            )
        }
        return FakeDebugSection(
            id: id,
            title: title,
            options: options,
            showCondition: showCondition
        )
    }

    static func createProductionLikeSections(placements: [String]) -> [DebugSection] {
        [
            DebugSectionData.modeSection(),
            DebugSectionData.placementSection(placements: placements),
            DebugSectionData.adNetworkSection(),
            DebugSectionData.adFormatSection(),
            DebugSectionData.creativeTypeSection(),
            DebugSectionData.layoutSection(),
            DebugSectionData.highEngagementSection(),
        ]
    }

    static func createMinimalSections() -> [FakeDebugSection] {
        [
            createSimpleSection(id: "section1", title: "Section 1", optionCount: 2),
            createSimpleSection(id: "section2", title: "Section 2", optionCount: 3),
        ]
    }
}
