import Foundation
import MSPiOSCore

// Protocol for debug section data
protocol DebugSection {
    var title: String { get }
    var options: [DebugOption] { get }
    /// A set of option IDs that must all be selected for this section to be visible.
    /// If nil, the section is always visible.
    var showCondition: Set<String>? { get }
} 