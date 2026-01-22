/// Protocol for types that can be displayed in debug UI
import Foundation

protocol DebugDisplayable {
    var displayTitle: String { get }
    var isVisible: Bool { get }
}
