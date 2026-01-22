//
//  NovaTrackingUrlHelper.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 12/18/25.
//
import Foundation
import WebKit

class NovaTrackingUrlHelper: NSObject {
    static let shared = NovaTrackingUrlHelper()
    private var cachedUserAgent: String?
    private static var referenceWebView: WKWebView?
    private let queue = DispatchQueue(label: "com.nova.tracking", attributes: .concurrent)

    /// The main entry point for your tracking calls
    static func fire(url: URL) {
        shared.getUserAgent { ua in
            var request = URLRequest(url: url)
            request.setValue(ua, forHTTPHeaderField: "User-Agent")

            Task.detached(priority: .userInitiated) {
                do {
                    _ = try await URLSession.shared.data(for: request)
                } catch {
                    print("Tracking error: \(error)")
                }
            }
        }
    }

    private func getUserAgent(completion: @escaping (String?) -> Void) {
        if let cached = cachedUserAgent {
            completion(cached)
            return
        }

        DispatchQueue.main.async { [weak self] in
            let webView = WKWebView(frame: .zero)
            NovaTrackingUrlHelper.referenceWebView = webView
            webView.evaluateJavaScript("navigator.userAgent") { (result, error) in
                let ua = result as? String

                self?.cachedUserAgent = ua
                completion(ua)
            }
        }
    }
}
