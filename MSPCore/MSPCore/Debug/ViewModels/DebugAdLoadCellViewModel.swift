import Foundation

class DebugAdLoadCellViewModel {
    let id: String
    let title: String
    var isSelected: Bool
    
    init(id: String, title: String, isSelected: Bool = false) {
        self.id = id
        self.title = title
        self.isSelected = isSelected
    }
} 