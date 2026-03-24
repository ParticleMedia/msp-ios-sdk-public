import Foundation

/// A model describing a single-select chip group within a debug section.
struct DebugChipGroupItem {
    struct ChipOption {
        let id: String
        let title: String
    }

    let id: String
    let title: String
    let options: [ChipOption]
    let defaultSelectedId: String?

    init(id: String, title: String, options: [ChipOption], defaultSelectedId: String? = nil) {
        self.id = id
        self.title = title
        self.options = options
        self.defaultSelectedId = defaultSelectedId
    }
}
