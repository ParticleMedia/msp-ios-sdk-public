import Foundation
import MSPiOSCore

extension RewardTypeOption: DebugOption {
    var id: String { rawValue }

    var displayTitle: String { rawValue.capitalized }

    var isVisible: Bool { true }
}

extension RewardTypeOption: TestParamPresentable {
    var keyValuePairs: [(String, String)] {
        [("reward_type", rawValue)]
    }
}
