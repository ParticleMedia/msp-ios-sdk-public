import Foundation
import Combine

class DebugRadioCellViewModel {
    let id: String
    let title: String
    
    @Published private(set) var isSelected: Bool
    var isSelectedPublisher: AnyPublisher<Bool, Never> {
        $isSelected.eraseToAnyPublisher()
    }
    
    init(id: String, title: String, isSelected: Bool = false) {
        self.id = id
        self.title = title
        self.isSelected = isSelected
    }
    
    func setSelected(_ selected: Bool) {
        isSelected = selected
    }
}
