import Foundation

struct NovaUnifiedWebViewConfig {
    let enableJSBridge: Bool
    let enableNBUserAgent: Bool
    let blockedURLPrefixes: [String]
    let displayNavigationHeader: Bool
    let navigationTitleText: String?
    let goBackByUrlAllowed: Bool
    let headers: [String: String]
    
    init(enableJSBridge: Bool, enableNBUserAgent: Bool, blockedURLPrefixes: [String], displayNavigationHeader: Bool, navigationTitleText: String?, goBackByUrlAllowed: Bool, headers: [String : String]) {
        self.enableJSBridge = enableJSBridge
        self.enableNBUserAgent = enableNBUserAgent
        self.blockedURLPrefixes = blockedURLPrefixes
        self.displayNavigationHeader = displayNavigationHeader
        self.navigationTitleText = navigationTitleText
        self.goBackByUrlAllowed = goBackByUrlAllowed
        self.headers = headers
    }
}
