import Foundation
import MSPiOSCore

// Protocol for debug section data
protocol DebugSection {
    var title: String { get }
    var options: [DebugOptionable] { get }
} 