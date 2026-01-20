import Foundation
import MSPiOSCore

extension HighEngagementOption: DebugOption {
    var id: String { rawValue }
    
    var displayTitle: String {
        switch self {
        case .yes: return "Yes"
        case .no: return "No"
        }
    }
    
    var isVisible: Bool { true }
    
    var placementIdAttachment: String? { nil }
} 
