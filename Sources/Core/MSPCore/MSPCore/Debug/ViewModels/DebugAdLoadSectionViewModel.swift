import Foundation

class DebugAdLoadSectionViewModel {
    let id: String
    let title: String
    private(set) var cellViewModels: [DebugRadioCellViewModel]
    private var isVisible: Bool
    
    init(id: String, title: String, cellViewModels: [DebugRadioCellViewModel], isVisible: Bool = true) {
        self.id = id
        self.title = title
        self.cellViewModels = cellViewModels
        self.isVisible = isVisible
    }
    
    // Convenience initializer to create from original model data
    convenience init(from sectionData: DebugSection) {
        let cellViewModels = sectionData.options.map { option in
            DebugRadioCellViewModel(debugOption: option)
        }
        self.init(id: sectionData.id, title: sectionData.title, cellViewModels: cellViewModels)
    }
    
    // MARK: - Public Access Methods
    
    var numberOfCells: Int {
        return cellViewModels.count
    }
    
    func cellViewModel(at index: Int) -> DebugRadioCellViewModel? {
        guard index >= 0 && index < cellViewModels.count else { return nil }
        return cellViewModels[index]
    }
    
    var visible: Bool {
        get { return isVisible }
        set { isVisible = newValue }
    }
    
    func selectCell(at index: Int) {
        for (i, cell) in cellViewModels.enumerated() {
            cell.setSelected(i == index)
        }
    }
    
    func selectedIndex() -> Int? {
        return cellViewModels.firstIndex(where: { $0.isSelected })
    }
    
    func selectedCell() -> DebugRadioCellViewModel? {
        return cellViewModels.first(where: { $0.isSelected })
    }
}
