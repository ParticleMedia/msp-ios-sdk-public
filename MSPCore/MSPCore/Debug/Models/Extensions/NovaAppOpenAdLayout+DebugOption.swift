import Foundation
import MSPiOSCore

extension NovaAppOpenAdLayout: DebugOption {
    var id: String { rawValue }
    
    var displayTitle: String {
        switch self {
        case .horizontal: return "Horizontal"
        case .vertical: return "Vertical"
        case .horizontalCancelTopRight: return "Horizontal Cancel TopRight"
        case .verticalCancelTopRight: return "Vertical Cancel TopRight"
        case .endCard: return "End Card"
        }
    }
    
    var isVisible: Bool { true }
    
    var placementIdAttachment: String? { nil }
} 
