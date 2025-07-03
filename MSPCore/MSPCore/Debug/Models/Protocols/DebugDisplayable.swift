import Foundation

/// Protocol for types that can be displayed in debug UI
protocol DebugDisplayable {
    var displayTitle: String { get }
    var isVisible: Bool { get }
} 