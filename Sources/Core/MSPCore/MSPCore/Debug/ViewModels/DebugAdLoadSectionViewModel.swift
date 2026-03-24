import Foundation

class DebugAdLoadSectionViewModel {
    let id: String
    let title: String
    private(set) var cellViewModels: [DebugRadioCellViewModel]
    private(set) var toggleCellViewModels: [DebugToggleCellViewModel]
    private(set) var chipGroupCellViewModels: [DebugChipGroupCellViewModel]
    private var isVisible: Bool

    init(
        id: String,
        title: String,
        cellViewModels: [DebugRadioCellViewModel],
        toggleCellViewModels: [DebugToggleCellViewModel] = [],
        chipGroupCellViewModels: [DebugChipGroupCellViewModel] = [],
        isVisible: Bool = true
    ) {
        self.id = id
        self.title = title
        self.cellViewModels = cellViewModels
        self.toggleCellViewModels = toggleCellViewModels
        self.chipGroupCellViewModels = chipGroupCellViewModels
        self.isVisible = isVisible
    }

    // Convenience initializer to create from original model data
    convenience init(from sectionData: DebugSection) {
        let cellViewModels = sectionData.options.map { option in
            DebugRadioCellViewModel(debugOption: option)
        }
        let toggleCellViewModels = sectionData.toggleItems.map { item in
            DebugToggleCellViewModel(id: item.id, title: item.title, isOn: item.defaultIsOn)
        }
        let chipGroupCellViewModels = sectionData.chipGroupItems.map { item in
            DebugChipGroupCellViewModel(item: item)
        }
        self.init(
            id: sectionData.id,
            title: sectionData.title,
            cellViewModels: cellViewModels,
            toggleCellViewModels: toggleCellViewModels,
            chipGroupCellViewModels: chipGroupCellViewModels
        )
    }

    // MARK: - Public Access Methods

    var numberOfCells: Int {
        cellViewModels.count + toggleCellViewModels.count + chipGroupCellViewModels.count
    }

    /// Returns true when the row index falls in the toggle cell range.
    func isToggleCell(at index: Int) -> Bool {
        index >= cellViewModels.count && index < cellViewModels.count + toggleCellViewModels.count
    }

    /// Returns true when the row index falls in the chip group cell range.
    func isChipGroupCell(at index: Int) -> Bool {
        index >= cellViewModels.count + toggleCellViewModels.count
    }

    func cellViewModel(at index: Int) -> DebugRadioCellViewModel? {
        guard index >= 0 && index < cellViewModels.count else { return nil }
        return cellViewModels[index]
    }

    func toggleCellViewModel(at index: Int) -> DebugToggleCellViewModel? {
        let toggleIndex = index - cellViewModels.count
        guard toggleIndex >= 0 && toggleIndex < toggleCellViewModels.count else { return nil }
        return toggleCellViewModels[toggleIndex]
    }

    func chipGroupCellViewModel(at index: Int) -> DebugChipGroupCellViewModel? {
        let chipIndex = index - cellViewModels.count - toggleCellViewModels.count
        guard chipIndex >= 0 && chipIndex < chipGroupCellViewModels.count else { return nil }
        return chipGroupCellViewModels[chipIndex]
    }

    var visible: Bool {
        get { isVisible }
        set { isVisible = newValue }
    }

    func selectCell(at index: Int) {
        for (i, cell) in cellViewModels.enumerated() {
            cell.setSelected(i == index)
        }
    }

    func selectedIndex() -> Int? {
        cellViewModels.firstIndex(where: { $0.isSelected })
    }

    func selectedCell() -> DebugRadioCellViewModel? {
        cellViewModels.first(where: { $0.isSelected })
    }

    func replaceOptions(_ options: [DebugOption], preferredSelectedId: String? = nil) {
        let selectedId = preferredSelectedId ?? selectedCell()?.id
        cellViewModels = options.map { option in
            DebugRadioCellViewModel(debugOption: option, isSelected: option.id == selectedId)
        }

        if cellViewModels.isEmpty {
            return
        }

        if cellViewModels.contains(where: { $0.isSelected }) == false {
            cellViewModels[0].setSelected(true)
        }
    }
}
