// Meszaros Type: Fake — value-type with working implementation
@testable import MSPCore

struct FakeDebugOption: DebugOption {
    let id: String
    let displayTitle: String
    let isVisible: Bool

    init(id: String, displayTitle: String, isVisible: Bool = true) {
        self.id = id
        self.displayTitle = displayTitle
        self.isVisible = isVisible
    }
}
