import Foundation

class DebugAdLoadSectionViewModel {
    let id: String
    let title: String
    private(set) var cellViewModels: [DebugRadioCellViewModel]
    private(set) var toggleCellViewModels: [DebugToggleCellViewModel]
    private var isVisible: Bool

    init(
        id: String,
        title: String,
        cellViewModels: [DebugRadioCellViewModel],
        toggleCellViewModels: [DebugToggleCellViewModel] = [],
        isVisible: Bool = true
    ) {
        self.id = id
        self.title = title
        self.cellViewModels = cellViewModels
        self.toggleCellViewModels = toggleCellViewModels
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
        self.init(
            id: sectionData.id,
            title: sectionData.title,
            cellViewModels: cellViewModels,
            toggleCellViewModels: toggleCellViewModels
        )
    }

    // MARK: - Public Access Methods

    var numberOfCells: Int {
        cellViewModels.count + toggleCellViewModels.count
    }

    /// Returns true when the row index falls in the toggle cell range.
    func isToggleCell(at index: Int) -> Bool {
        index >= cellViewModels.count
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
}
