import Foundation
import Combine

class DebugAdLoadViewModel {
    enum SectionType: Int, CaseIterable {
        case adNetwork, adFormat, creativeType, layout, highEngagement, placements
    }
    
    @Published private(set) var sections: [DebugAdLoadSectionViewModel] = []
    let placements: [String]
    var visibleSectionsPublisher: AnyPublisher<[DebugAdLoadSectionViewModel], Never> {
        $sections.map { $0.filter { $0.isVisible } }.eraseToAnyPublisher()
    }
    
    init(placementsRepository: PlacementsRepository = TestPlacementsService()) {
        self.placements = placementsRepository.fetchPlacements()
        setupSections()
    }
    
    private func setupSections() {
        // Ad Network
        let adNetworkOptions = [
            DebugRadioCellViewModel(id: "msp_fb", title: "msp_fb", isSelected: true),
            DebugRadioCellViewModel(id: "msp_google", title: "msp_google"),
            DebugRadioCellViewModel(id: "msp_nova", title: "msp_nova"),
            DebugRadioCellViewModel(id: "moloco", title: "moloco")
        ]
        let adNetworkSection = DebugAdLoadSectionViewModel(title: "Ad Network", cellViewModels: adNetworkOptions)
        // Ad Format
        let adFormatOptions = [
            DebugRadioCellViewModel(id: "native", title: "native", isSelected: true),
            DebugRadioCellViewModel(id: "interstitial", title: "interstitial")
        ]
        let adFormatSection = DebugAdLoadSectionViewModel(title: "Ad Format", cellViewModels: adFormatOptions)
        // Creative Type (Nova only)
        let creativeTypeOptions = [
            DebugRadioCellViewModel(id: "video", title: "video", isSelected: true),
            DebugRadioCellViewModel(id: "image", title: "image")
        ]
        let creativeTypeSection = DebugAdLoadSectionViewModel(title: "Creative Type (Nova only)", cellViewModels: creativeTypeOptions, isVisible: false)
        // Layout (Nova interstitial only)
        let layoutOptions = [
            DebugRadioCellViewModel(id: "vertical", title: "vertical", isSelected: true),
            DebugRadioCellViewModel(id: "horizontal", title: "horizontal")
        ]
        let layoutSection = DebugAdLoadSectionViewModel(title: "Layout (Nova interstitial only)", cellViewModels: layoutOptions, isVisible: false)
        // High Engagement (Nova interstitial only)
        let highEngagementOptions = [
            DebugRadioCellViewModel(id: "yes", title: "yes"),
            DebugRadioCellViewModel(id: "no", title: "no", isSelected: true)
        ]
        let highEngagementSection = DebugAdLoadSectionViewModel(title: "High Engagement (Nova interstitial only)", cellViewModels: highEngagementOptions, isVisible: false)
        // Placements
        let placementOptions = placements.map { DebugRadioCellViewModel(id: $0, title: $0) }
        if let first = placementOptions.first { first.setSelected(true) }
        let placementsSection = DebugAdLoadSectionViewModel(title: "Placements", cellViewModels: placementOptions)
        
        sections = [adNetworkSection, adFormatSection, creativeTypeSection, layoutSection, highEngagementSection, placementsSection]
        updateSectionVisibility()
    }
    
    func selectOption(section: Int, row: Int) {
        let sectionVM = sections[section]
        sectionVM.selectCell(at: row)
        updateSectionVisibility()
        // Trigger Combine update
        sections = sections
    }
    
    func updateSectionVisibility() {
        let adNetwork = sections[0].selectedCell()?.id
        let adFormat = sections[1].selectedCell()?.id
        // Creative Type only for msp_nova
        sections[2].isVisible = (adNetwork == "msp_nova")
        // Layout and High Engagement only for msp_nova + interstitial
        let showLayout = (adNetwork == "msp_nova" && adFormat == "interstitial")
        sections[3].isVisible = showLayout
        sections[4].isVisible = showLayout
    }
} 
