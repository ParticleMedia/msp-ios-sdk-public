//
//  MraidController.swift
//  NovaCore
//
//  Created by Shanyu Li on 2026/2/2.
//

import Foundation
import MSPiOSCore
import WebKit

final class MraidController: NSObject {
    static let scriptMessageName = "mraidBridge"

    private let commandHandler: MraidCommandHandler
    private let jsBridge: MraidJsToNativeBridge
    weak var mraidDelegate: MraidBehaviorDelegate? {
        didSet {
            commandHandler.mraidDelegate = mraidDelegate
        }
    }

    func install(in userContentController: WKUserContentController) {
        let shimScript = WKUserScript(
            source: commandHandler.mraidShimSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(shimScript)
        userContentController.add(jsBridge, name: Self.scriptMessageName)
    }

    func resetState() {
        commandHandler.resetMraidState()
    }

    private var isViewable: Bool = false

    func notifyViewable(_ isViewable: Bool) {
        self.isViewable = isViewable
        commandHandler.notifyViewable(isViewable)
    }

    func handlePageFinished() {
        commandHandler.hasFinishedLoad = true
        commandHandler.initializeMraidState(in: commandHandler.mraidWebView)
        // Re-apply current viewable state after init. WKWebView serializes evaluateJavaScript
        // calls in order, so this runs after novaMraidInit.js has finished.
        commandHandler.notifyViewable(isViewable)
    }

    func handleMraidSchemeURL(_ url: URL) {
        let command = url.host ?? ""
        switch command {
        case "open":
            commandHandler.handleMraidOpen(url: url)
        case "close":
            commandHandler.handleMraidClose()
        case "expand":
            commandHandler.handleMraidExpand(params: [:])
        case "resize":
            commandHandler.handleMraidResize(params: [:])
        default:
            commandHandler.mraidLogInfo("[MRAID Native] Unknown mraid command: \(command)")
        }
    }

    init(
        webView: WKWebView,
        mraidDelegate: MraidBehaviorDelegate? = nil
    ) {
        let handler = MraidCommandHandler(
            webView: webView,
            mraidDelegate: mraidDelegate
        )
        self.commandHandler = handler
        self.jsBridge = MraidJsToNativeBridge(commandHandler: handler)
        super.init()
    }
}
