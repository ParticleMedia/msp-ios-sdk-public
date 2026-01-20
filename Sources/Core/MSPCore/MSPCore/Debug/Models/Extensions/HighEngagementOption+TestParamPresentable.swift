import Foundation
import MSPiOSCore

extension HighEngagementOption: TestParamPresentable {
    var keyValuePairs: [(String, String)] {
        switch self {
        case .yes: return [("high_engagement", "true")]
        case .no: return [("high_engagement", "false")]
        }
    }
} 