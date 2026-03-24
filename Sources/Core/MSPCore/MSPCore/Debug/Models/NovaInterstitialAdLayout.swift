// copied from NovaCore
import Foundation

enum NovaInterstitialAdLayout: String, Codable, CaseIterable {
    case horizontal = "horizontal"
    case vertical = "vertical"
    case horizontalCancelTopRight = "horizontal_cancel_top_right"
    case verticalCancelTopRight = "vertical_cancel_top_right"
    case endCard = "end_card_2_part"

    var isVertical: Bool {
        switch self {
        case .vertical, .verticalCancelTopRight, .endCard:
            return true
        case .horizontal, .horizontalCancelTopRight:
            return false
        }
    }

    var testParamsValue: String {
        switch self {
        case .horizontal, .horizontalCancelTopRight:
            return "horizontal"
        case .vertical, .verticalCancelTopRight, .endCard:
            return "vertical"
        }
    }
}
