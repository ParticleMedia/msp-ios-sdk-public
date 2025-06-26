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
            
            // Set initial visibility based on showCondition
            sectionViewModel.visible = shouldShowSection(data)
            
            return sectionViewModel
        }
    }
    
    private func shouldShowSection(_ section: DebugSection) -> Bool {
        guard let showCondition = section.showCondition else {
            // If showCondition is nil, section is always visible
            return true
        }
        
        // Check if all required option IDs are in the current selection
        let selectedOptionIds = getSelectedOptionIds()
        return showCondition.isSubset(of: selectedOptionIds)
    }
    
    private func getSelectedOptionIds() -> Set<String> {
        var selectedIds: Set<String> = []
        
        for section in sections {
            if let selectedCell = section.selectedCell() {
                selectedIds.insert(selectedCell.id)
            }
        }
        
        return selectedIds
    }
    
    private func setDefaultSelections() {
        // Set default selections based on showCondition requirements
        for (index, section) in sections.enumerated() {
            if index < originalSectionData.count {
                let sectionData = originalSectionData[index]
                
                // If this section has a showCondition, set the first available option as default
                if let showCondition = sectionData.showCondition {
                    for requiredId in showCondition {
                        for i in 0..<section.numberOfCells {
                            if let cell = section.cellViewModel(at: i), cell.id == requiredId {
                                section.selectCell(at: i)
                                break
                            }
                        }
                    }
                } else {
                    // For sections without showCondition, set the first option as default
                    if section.numberOfCells > 0 {
                        section.selectCell(at: 0)
                    }
                }
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
        // Update visibility for all sections based on their showCondition
        for (index, section) in sections.enumerated() {
            if index < originalSectionData.count {
                let shouldShow = shouldShowSection(originalSectionData[index])
                section.visible = shouldShow
            }
        }
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
