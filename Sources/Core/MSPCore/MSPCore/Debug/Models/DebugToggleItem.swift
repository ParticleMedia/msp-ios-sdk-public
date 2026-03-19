import Foundation

/// A model describing a toggle (on/off switch) item within a debug section.
struct DebugToggleItem {
    let id: String
    let title: String
    let defaultIsOn: Bool

    init(id: String, title: String, defaultIsOn: Bool = false) {
        self.id = id
        self.title = title
        self.defaultIsOn = defaultIsOn
    }
}
