// Meszaros Type: Fake — value-type with working implementation
@testable import MSPCore

struct FakeDebugSection: DebugSection {
    let id: String
    let title: String
    let options: [DebugOption]
    let showCondition: Set<String>?

    init(
        id: String,
        title: String,
        options: [DebugOption],
        showCondition: Set<String>? = nil
    ) {
        self.id = id
        self.title = title
        self.options = options
        self.showCondition = showCondition
    }
}
