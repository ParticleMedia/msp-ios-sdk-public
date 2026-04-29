enum NovaAdSkipReason: Equatable {
    case timeout
    case error(String?)
    case skipButton
    case backButton
    case auto
    
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
        case .auto:
            return "auto"
        }
    }
    
    var reasonStringValue: String {
        switch self {
        case .timeout:
            return "timeout"
        case .error(let value):
            return "error"
        case .skipButton:
            return "close"
        case .backButton:
            return "back_btn"
        case .auto:
            return "auto"
        }
    }
}

struct NovaAdLoadError: Equatable {
    let isActive: Int // 1: yes, 2: no
    let errorType: String?
    let errorDetail: String?
}

    
