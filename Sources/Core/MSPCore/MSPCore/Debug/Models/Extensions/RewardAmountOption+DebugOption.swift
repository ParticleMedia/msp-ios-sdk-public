import Foundation
import MSPiOSCore

extension RewardAmountOption: DebugOption {
    var id: String { rawValue }

    var displayTitle: String { rawValue }

    var isVisible: Bool { true }
}

extension RewardAmountOption: TestParamPresentable {
    var keyValuePairs: [(String, String)] {
        [("reward_amount", rawValue)]
    }
}
