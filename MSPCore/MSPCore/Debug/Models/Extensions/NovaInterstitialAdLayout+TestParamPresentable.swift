import Foundation
import MSPiOSCore

extension NovaInterstitialAdLayout: TestParamPresentable {
    var keyValuePairs: [(String, String)] {
        switch self {
        case .horizontal: return [("is_vertical", "false")]
        case .vertical: return [("is_vertical", "true")]
        case .endCard: return [("is_vertical", "true"), ("layout", rawValue)]
        case .verticalCancelTopRight: return [("is_vertical", "true"), ("layout", rawValue)]
        case .horizontalCancelTopRight: return [("is_vertical", "false"), ("layout", rawValue)]
        }
    }
} 