// Protocol for debug section data
import Foundation
import MSPiOSCore

protocol DebugSection {
    var id: String { get }
    var title: String { get }
    var options: [DebugOption] { get }
    /// A set of option IDs that must all be selected for this section to be visible.
    /// If nil, the section is always visible.
    var showCondition: Set<String>? { get }
    /// Toggle (on/off switch) items within this section. Defaults to empty.
    var toggleItems: [DebugToggleItem] { get }
    /// Single-select chip group items within this section. Defaults to empty.
    var chipGroupItems: [DebugChipGroupItem] { get }
}

extension DebugSection {
    var toggleItems: [DebugToggleItem] { [] }
    var chipGroupItems: [DebugChipGroupItem] { [] }
}
