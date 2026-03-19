import Foundation

class DebugToggleCellViewModel {
    let id: String
    let title: String
    private(set) var isOn: Bool

    init(id: String, title: String, isOn: Bool = false) {
        self.id = id
        self.title = title
        self.isOn = isOn
    }

    func setOn(_ on: Bool) {
        isOn = on
    }
}
