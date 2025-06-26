import Foundation
import Combine
import MSPiOSCore

class DebugAdLoadViewModel {
    @Published private(set) var sections: [DebugAdLoadSectionViewModel] = []
    private let originalSectionData: [DebugSection]
    let placements: [String]
    var visibleSectionsPublisher: AnyPublisher<[DebugAdLoadSectionViewModel], Never> {
        $sections.map { $0.filter { $0.visible } }.eraseToAnyPublisher()
    }
    
    private let repository: DebugSectionsRepository
    
    init(
        repository: DebugSectionsRepository,
        placementsRepository: PlacementsRepository = TestPlacementsService()
    ) {
        self.repository = repository
        self.placements = placementsRepository.fetchPlacements()
        // Store original model data
        self.originalSectionData = repository.fetchDebugSections(placements: self.placements)
        // Assemble SectionViewModel from original model data and set initial visibility
        self.sections = createSectionViewModels()
        // Set default selections
        setDefaultSelections()
        updateSectionVisibility()
    }
    
    private func createSectionViewModels() -> [DebugAdLoadSectionViewModel] {
        return originalSectionData.enumerated().map { index, data in
            let sectionViewModel = DebugAdLoadSectionViewModel(from: data)
            
            // Set initial visibility based on section type and business rules
            switch index {
            case 0, 1: // Ad Network and Ad Format sections
                sectionViewModel.visible = true
            case 2, 3, 4: // Creative Type, Layout, and High Engagement sections
                sectionViewModel.visible = false
            default:
                sectionViewModel.visible = true
            }
            
            return sectionViewModel
        }
    }
    
    private func setDefaultSelections() {
        // Set Facebook as default for Ad Network
        for i in 0..<sections[0].numberOfCells {
            if let cell = sections[0].cellViewModel(at: i), cell.id == "facebook" {
                sections[0].selectCell(at: i)
                break
            }
        }
        
        // Set Native as default for Ad Format
        for i in 0..<sections[1].numberOfCells {
            if let cell = sections[1].cellViewModel(at: i), cell.id == "native" {
                sections[1].selectCell(at: i)
                break
            }
        }
        
        // Set Native Video as default for Creative Type
        for i in 0..<sections[2].numberOfCells {
            if let cell = sections[2].cellViewModel(at: i), cell.id == "nativeVideo" {
                sections[2].selectCell(at: i)
                break
            }
        }
        
        // Set Vertical as default for Layout
        for i in 0..<sections[3].numberOfCells {
            if let cell = sections[3].cellViewModel(at: i), cell.id == "vertical" {
                sections[3].selectCell(at: i)
                break
            }
        }
        
        // Set No as default for High Engagement
        for i in 0..<sections[4].numberOfCells {
            if let cell = sections[4].cellViewModel(at: i), cell.id == "no" {
                sections[4].selectCell(at: i)
                break
            }
        }
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
        // Creative Type only for nova
        sections[2].visible = (adNetwork == "nova")
        // Layout and High Engagement only for nova + interstitial
        let showLayout = (adNetwork == "nova" && adFormat == "interstitial")
        sections[3].visible = showLayout
        sections[4].visible = showLayout
    }
    
    // Get test parameters from selected options
    func getTestParameters() -> [String: String] {
        var params: [String: String] = [:]
        
        // Add parameters from each selected option
        for (index, section) in sections.enumerated() {
            if let selectedCell = section.selectedCell(),
               index < originalSectionData.count {
                let originalOptions = originalSectionData[index].options
                if let selectedOption = originalOptions.first(where: { $0.id == selectedCell.id }) {
                    // Check if the option conforms to TestParamPresentable
                    if let testParamOption = selectedOption as? TestParamPresentable {
                        for (key, value) in testParamOption.keyValuePairs {
                            params[key] = value
                        }
                    }
                }
            }
        }
        
        return params
    }
    
    func getSelectedOptions() -> [String: DebugOptionable] {
        var selectedOptions: [String: DebugOptionable] = [:]
        
        for section in sections {
            if let selectedCell = section.selectedCell() {
                selectedOptions[section.title] = selectedCell.debugOption
            }
        }
        
        return selectedOptions
    }
} 
