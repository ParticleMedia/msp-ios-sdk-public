import Foundation

class DebugChipGroupCellViewModel {
    let id: String
    let title: String
    private(set) var options: [DebugChipGroupItem.ChipOption]
    private(set) var selectedId: String?

    init(item: DebugChipGroupItem) {
        self.id = item.id
        self.title = item.title
        self.options = item.options
        self.selectedId = item.defaultSelectedId
    }

    /// Selects the given chip. If it is already selected, deselects it.
    func selectOption(id: String) {
        selectedId = (selectedId == id) ? nil : id
    }

    /// Replaces the available chip options. Clears the selection if the current
    /// selected ID is no longer present in the new options.
    func replaceOptions(_ newOptions: [DebugChipGroupItem.ChipOption]) {
        options = newOptions
        if let selectedId, !newOptions.contains(where: { $0.id == selectedId }) {
            self.selectedId = nil
        }
    }
}
