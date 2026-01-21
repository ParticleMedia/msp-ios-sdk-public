@testable import MSPCore

enum TestDataFactory {
    static func createSimpleSection(
        id: String,
        title: String,
        optionCount: Int,
        showCondition: Set<String>? = nil
    ) -> MockDebugSection {
        let options = (0..<optionCount).map { index in
            MockDebugOption(
                id: "\(id)_option_\(index)",
                displayTitle: "Option \(index)"
            )
        }
        return MockDebugSection(
            id: id,
            title: title,
            options: options,
            showCondition: showCondition
        )
    }

    static func createProductionLikeSections(placements: [String]) -> [DebugSection] {
        return [
            DebugSectionData.placementSection(placements: placements),
            DebugSectionData.adNetworkSection(),
            DebugSectionData.adFormatSection(),
            DebugSectionData.creativeTypeSection(),
            DebugSectionData.layoutSection(),
            DebugSectionData.highEngagementSection()
        ]
    }

    static func createMinimalSections() -> [MockDebugSection] {
        return [
            createSimpleSection(id: "section1", title: "Section 1", optionCount: 2),
            createSimpleSection(id: "section2", title: "Section 2", optionCount: 3)
        ]
    }
}
