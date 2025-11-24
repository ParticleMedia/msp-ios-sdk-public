import Foundation
import Combine
import MSPiOSCore

class DebugRadioCellViewModel {
    let debugOption: DebugOption
    
    var id: String {
        debugOption.id
    }
    
    var title: String {
        debugOption.displayTitle
    }

    @Published private(set) var isSelected: Bool
    var isSelectedPublisher: AnyPublisher<Bool, Never> {
        $isSelected.eraseToAnyPublisher()
    }
    
    init(
        debugOption: DebugOption,
        isSelected: Bool = false
    ) {
        self.debugOption = debugOption
        self.isSelected = isSelected
    }
    
    func setSelected(_ selected: Bool) {
        isSelected = selected
    }
}
