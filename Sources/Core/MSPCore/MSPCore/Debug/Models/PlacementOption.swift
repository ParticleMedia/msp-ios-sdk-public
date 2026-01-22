import Foundation
import MSPiOSCore

struct PlacementOption: DebugOption, DebugOptionIdentifiable, DebugDisplayable {
    let placementId: String

    var id: String {
        placementId
    }

    var title: String {
        placementId
    }

    var placementIdAttachment: String? {
        placementId
    }

    // DebugDisplayable protocol implementation
    var displayText: String {
        placementId
    }

    var displayTitle: String {
        placementId
    }

    var isVisible: Bool {
        true
    }
}
