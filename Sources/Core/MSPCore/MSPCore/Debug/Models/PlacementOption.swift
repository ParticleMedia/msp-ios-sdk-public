import Foundation
import MSPiOSCore

struct PlacementOption: DebugOption, DebugOptionIdentifiable, DebugDisplayable {
    let placementId: String
    
    var id: String {
        return placementId
    }
    
    var title: String {
        return placementId
    }
    
    var placementIdAttachment: String? {
        return placementId
    }
    
    // DebugDisplayable protocol implementation
    var displayText: String {
        return placementId
    }
    
    var displayTitle: String {
        return placementId
    }
    
    var isVisible: Bool {
        true
    }
}
