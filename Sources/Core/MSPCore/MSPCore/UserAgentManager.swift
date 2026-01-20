//
//  UserAgentManager.swift
//  MSPCore
//
//  Created by Mingming Luo on 2025/10/31.
//

import Foundation
import WebKit
import UIKit

private enum StorageUtils {
    private static let key = "cached_user_agent"

    static func fetchUserAgent() -> String {
        UserDefaults.standard.string(forKey: key) ?? ""
    }

    static func storeUserAgent(_ ua: String) {
        UserDefaults.standard.setValue(ua, forKey: key)
    }
}

final internal class UserAgentManager {

    static let shared = UserAgentManager()

    private init() {}

    private(set) var userAgent: String = ""

    func start() {
        userAgent = StorageUtils.fetchUserAgent()

        if userAgent.isEmpty {
            userAgent = fallbackUserAgent()
        }

        DispatchQueue.main.async { [weak self] in
            self?.updateSystemUserAgent()
        }
    }

    private func fallbackUserAgent() -> String {
        let osVersion = UIDevice.current.systemVersion
        return "Mozilla/5.0 (iPhone; CPU iPhone OS \(osVersion.replacingOccurrences(of: ".", with: "_")) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
    }

    private func updateSystemUserAgent() {
        let webView = WKWebView(frame: .zero)

        var systemUA: String?
        systemUA = webView.value(forKey: "userAgent") as? String

        if systemUA == nil || systemUA!.contains("UNAVAILABLE") {
            webView.evaluateJavaScript("navigator.userAgent") { result, error in
                let uaResult = result as? String
                let trimmedUa = uaResult?.trimmingCharacters(in: .whitespacesAndNewlines)
                let ua = trimmedUa?.isEmpty == false ? result as? String : ""
                systemUA = ua

                self.tryStoreUserAgent(systemUA)
            }
        } else {
            self.tryStoreUserAgent(systemUA)
        }
    }

    private func tryStoreUserAgent(_ userAgent: String?) {
        if let ua = userAgent, !ua.isEmpty, !ua.contains("UNAVAILABLE") {
            self.userAgent = ua
        }
        StorageUtils.storeUserAgent(self.userAgent)
    }
}
