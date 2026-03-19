import Foundation

enum RewardTypeOption: String, CaseIterable {
    case coins
    case lives
    case credits
}

enum RewardAmountOption: String, CaseIterable {
    case one = "1"
    case five = "5"
    case ten = "10"
}
