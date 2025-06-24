import Foundation

class DebugAdLoadSectionViewModel {
    let title: String
    var cellViewModels: [DebugAdLoadCellViewModel]
    var isVisible: Bool
    
    init(title: String, cellViewModels: [DebugAdLoadCellViewModel], isVisible: Bool = true) {
        self.title = title
        self.cellViewModels = cellViewModels
        self.isVisible = isVisible
    }
    
    func selectCell(at index: Int) {
        for (i, cell) in cellViewModels.enumerated() {
            cell.isSelected = (i == index)
        }
    }
    
    func selectedIndex() -> Int? {
        return cellViewModels.firstIndex(where: { $0.isSelected })
    }
    
    func selectedCell() -> DebugAdLoadCellViewModel? {
        return cellViewModels.first(where: { $0.isSelected })
    }
} 