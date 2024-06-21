@objc public enum NovaAdType: Int {
    case appOpen
    case native
    case banner
    case nativeParallax
}

extension NovaAdType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .appOpen:
            return "app_open"
        case .native, .nativeParallax:
            return "native"
        case .banner:
            return "banner"
        }
    }
}
