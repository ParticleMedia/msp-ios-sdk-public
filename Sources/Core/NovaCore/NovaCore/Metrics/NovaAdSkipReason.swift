enum NovaAdSkipReason: Equatable {
    case timeout
    case error(String?)
    case skipButton
    case backButton
    
    var stringValue: String {
        switch self {
        case .timeout:
            return "timeout"
        case .error(let value):
            if let errorMessage = value {
                return errorMessage
            }
            return "error"
        case .skipButton:
            return "skip_btn"
        case .backButton:
            return "back_btn"
        }
    }
}
