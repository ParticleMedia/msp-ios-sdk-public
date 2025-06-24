import Foundation

class DebugAdLoadSectionViewModel {
    let title: String
    var cellViewModels: [DebugRadioCellViewModel]
    var isVisible: Bool
    
    init(title: String, cellViewModels: [DebugRadioCellViewModel], isVisible: Bool = true) {
        self.title = title
        self.cellViewModels = cellViewModels
        self.isVisible = isVisible
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
