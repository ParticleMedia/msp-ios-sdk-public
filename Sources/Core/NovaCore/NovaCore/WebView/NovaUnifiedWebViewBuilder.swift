//
//  UnifiedWebViewBuilder.swift
//  NovaAdapter
//
//  Created by Huanzhi Zhang on 6/19/24.
//

import Foundation
import UIKit

class NovaUnifiedWebViewBuilder {
    /*
    static func buildWebViewController(urlString: String,
                                              jsBridgeHandlers: [JSBridgeHandling],
                                              headers: [String: String] = [:],
                                              displayNavigationHeader: Bool = true,
                                              navigationTitleText: String? = nil,
                                              topPadding: CGFloat = 0,
                                              bottomPadding: CGFloat = 0,
                                              goBackByUrlAllowed: Bool = false,
                                              addDarkModeParameter: Bool = false,
                                              sendSessionId: Bool = false,
                                              webOpenHandler: ((_ url: URL) -> Bool)? = nil) -> UIViewController {
        var formattedUrlString = urlString
        if addDarkModeParameter && UITraitCollection.current.userInterfaceStyle == .dark {
            var urlComponents = URLComponents(string: urlString)
            var queryItems = urlComponents?.queryItems ?? []
            queryItems.append(contentsOf: [URLQueryItem(name: "dark", value: "true")])
            urlComponents?.queryItems = queryItems
            if let absoluteString = urlComponents?.url?.absoluteString {
                formattedUrlString = absoluteString
            }
        }
        var headers = headers
        if sendSessionId {
            //if let cookie = SafeAs(HpEngine.sharedInstance().prefrence(forKey: kHpUserCookie), [AnyHashable: Any].self),
            //   let token = SafeAs(cookie["Cookie"], String.self) {
            //    headers["Cookie"] = token
            //}
        }
        let config = UnifiedWebViewConfig(enableJSBridge: true,
                                          enableNBUserAgent: true,
                                          blockedURLPrefixes: [],
                                          displayNavigationHeader: displayNavigationHeader,
                                          navigationTitleText: navigationTitleText,
                                          goBackByUrlAllowed: goBackByUrlAllowed,
                                          headers: headers)

        let jsBridgeHandlerMaster = JSBridgeHandlerMaster(jsBridgeHandlers: jsBridgeHandlers)
        return StandardWebViewController(urlString: formattedUrlString,
                                         config: config,
                                         jsBridgeHandlerMaster: jsBridgeHandlerMaster,
                                         topPadding: topPadding,
                                         bottomPadding: bottomPadding,
                                         webOpenHandler: webOpenHandler)
    }
     */

    static func buildWebViewHost(enableNBUserAgent: Bool,
                                        enableJSBridge: Bool = true,
                                        jsBridgeHandlers: [NovaJSBridgeHandling] = [],
                                        blockedURLPrefixes: [String] = [],
                                        navigationDelegate: NovaUnifiedWebViewNavigationDelegate? = nil,
                                        headers: [String: String] = [:]) -> NovaUnifiedWebViewHost {
        let config = NovaUnifiedWebViewConfig(enableJSBridge: enableJSBridge,
                                          enableNBUserAgent: enableNBUserAgent,
                                          blockedURLPrefixes: blockedURLPrefixes,
                                          displayNavigationHeader: true,
                                          navigationTitleText: nil,
                                          goBackByUrlAllowed: false,
                                          headers: headers)
        let jsBridgeHandlerMaster = enableJSBridge ? NovaJSBridgeHandlerMaster(jsBridgeHandlers: jsBridgeHandlers) : nil
        return NovaUnifiedWebViewHost(config: config,
                                  jsBridgeHandlerMaster: jsBridgeHandlerMaster,
                                  navigationDelegate: navigationDelegate)
    }
}
