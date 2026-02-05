//
//  MraidCommandHandler.swift
//  NovaCore
//
//  Created by Shanyu Li on 2026/2/2.
//

import Foundation
import MSPiOSCore
import WebKit

final class MraidCommandHandler: NSObject, NovaMraidSupporting {
    weak var mraidDelegate: MraidBehaviorDelegate?
    private unowned let webView: WKWebView
    private let defaultHandler: MraidDefaultHandler

    init(
        webView: WKWebView,
        mraidDelegate: MraidBehaviorDelegate? = nil,
        calendarEventTitle: String = "Event"
    ) {
        self.webView = webView
        self.mraidDelegate = mraidDelegate
        self.mraidCalendarEventDefaultTitle = calendarEventTitle
        self.defaultHandler = MraidDefaultHandler(calendarEventTitle: calendarEventTitle)
        super.init()
    }

    let mraidCalendarEventDefaultTitle: String

    var mraidWebView: WKWebView { webView }

    func handleMraidOpen(params: [String: Any]) {
        let url = mraidUrl(from: params)
        mraidDelegate?.mraidOpen(url: url)
    }

    func handleMraidOpen(url: URL) {
        // Fallback handler for URL scheme (mraid://open?url=...)
        var customUrl: URL? = nil
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems,
            let urlString = queryItems.first(where: { $0.name == "url" })?.value
        {
            customUrl = URL(string: urlString)
        }
        mraidDelegate?.mraidOpen(url: customUrl)
    }

    func handleMraidClose() {
        mraidLogInfo("[MRAID Native] Received close action")
        mraidDelegate?.mraidClose()
        updateMraidState("default")
    }

    func handleMraidPlayVideo(params: [String: Any]) {
        guard let uri = params["uri"] as? String ?? params["url"] as? String,
            let url = URL(string: uri)
        else {
            mraidLogError("[MRAID Native] playVideo invalid or missing uri")
            return
        }
        defaultHandler.playVideo(url: url)
    }

    func handleMraidStorePicture(params: [String: Any]) {
        guard let uri = params["uri"] as? String ?? params["url"] as? String,
            let url = URL(string: uri)
        else {
            mraidLogError("[MRAID Native] storePicture invalid or missing uri")
            return
        }
        defaultHandler.storePicture(url: url)
    }

    func handleMraidCreateCalendarEvent(params: [String: Any]) {
        defaultHandler.createCalendarEvent(params: params)
    }

    func handleMraidMessageBody(_ body: Any) {
        guard let jsonString = body as? String,
            let jsonData = jsonString.data(using: .utf8),
            let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
            let action = jsonObject["action"] as? String
        else {
            mraidLogError("Failed to parse mraidBridge message: \(String(describing: body))")
            return
        }

        let params = jsonObject["params"] as? [String: Any] ?? [:]
        handleMraidAction(action: action, params: params)
    }

    private func mraidUrl(from params: [String: Any]) -> URL? {
        if let urlString = params["url"] as? String, !urlString.isEmpty {
            return URL(string: urlString)
        }
        if let urlString = params["uri"] as? String, !urlString.isEmpty {
            return URL(string: urlString)
        }
        return nil
    }
}
