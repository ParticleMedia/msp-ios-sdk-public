import Foundation

public struct NovaUnifiedWebViewConfig {
    public let enableJSBridge: Bool
    public let enableNBUserAgent: Bool
    public let blockedURLPrefixes: [String]
    public let displayNavigationHeader: Bool
    public let navigationTitleText: String?
    public let goBackByUrlAllowed: Bool
    public let headers: [String: String]
    
    public init(enableJSBridge: Bool, enableNBUserAgent: Bool, blockedURLPrefixes: [String], displayNavigationHeader: Bool, navigationTitleText: String?, goBackByUrlAllowed: Bool, headers: [String : String]) {
        self.enableJSBridge = enableJSBridge
        self.enableNBUserAgent = enableNBUserAgent
        self.blockedURLPrefixes = blockedURLPrefixes
        self.displayNavigationHeader = displayNavigationHeader
        self.navigationTitleText = navigationTitleText
        self.goBackByUrlAllowed = goBackByUrlAllowed
        self.headers = headers
    }
}
