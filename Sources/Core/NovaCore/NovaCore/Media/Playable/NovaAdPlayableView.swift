//
//  NovaAdPlayableView.swift
//  NBImmersiveAd
//
//  Created by Shanyu Li on 2025/5/13.
//

import Foundation
import UIKit
import WebKit

// MARK: - NovaAdPlayableView

class NovaAdPlayableView: UIView {
    // MARK: Lifecycle

    init() {
        super.init(frame: .zero)
        addSubviews(playableWebView, passThroughView)
        playableWebView.snp.makeConstraints { make in
            make.directionalEdges.equalToSuperview()
        }
        passThroughView.snp.makeConstraints { make in
            make.directionalEdges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        // Remove message handler to avoid memory leaks
        playableWebView.configuration.userContentController.removeScriptMessageHandler(forName: "mraidBridge")
    }

    func config(with playableModel: PlayableModel, actionContext: NovaAdMediaActionContext?) {
        playableWebView.load(URLRequest(url: playableModel.playableUrl))
        startTime = CACurrentMediaTime()
        guard let actionContext else {
            assertionFailure("Playable ad lack of tracing and action info")
            return
        }

        actionHelper = {
            if let weakVC = actionContext.viewController {
                return NovaActionHelper
                    .build(
                        with:
                        .adInViewController(
                            model: .init(
                                tracingInfo: actionContext.adActionTracingInfo,
                                extraInfo: actionContext.adActionExtraInfo,
                                ctrType: playableModel.launchAdType
                            ),
                            viewController: weakVC
                        )
                    )
            } else {
                return NovaActionHelper
                    .build(
                        with:
                        .adInView(
                            model: .init(
                                tracingInfo: actionContext.adActionTracingInfo,
                                extraInfo: actionContext.adActionExtraInfo,
                                ctrType: playableModel.launchAdType
                            )
                        )
                    )
            }
        }()
    }

    // MARK: Private

    private lazy var passThroughView: NovaAdPassThroughTapView = {
        let passThroughView = NovaAdPassThroughTapView()
        passThroughView.passThroughTapHandler = { [weak self] in
            self?.clickEventTimerTask?.cancel()
            self?.userDidClick = true
            self?.clickEventTimerTask = Task {
                try await Task.sleep(seconds: 0.3)
                self?.userDidClick = false
            }
        }
        return passThroughView
    }()

    private lazy var clickEventTimerTask: Task<Void, Error>? = nil

    private lazy var playableWebView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let userContentController = WKUserContentController()
        userContentController.addUserScript(
            WKUserScript(
                source: mraidHookSource,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        // Register MRAID message handler for iOS bridge
        userContentController.add(self, name: "mraidBridge")
        configuration.userContentController = userContentController
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.backgroundColor = .clear

        webView.uiDelegate = self
        webView.navigationDelegate = self
        return webView
    }()

    private var actionHelper: NovaActionHelper<NovaActionState.Init>?
    private var startTime: CFTimeInterval?
    private var userDidClick: Bool = false
    private var hasRequestedMraidJs: Bool = false
    private var hasInjectedMraidShim: Bool = false

    // Minimal MRAID 3.0-compatible surface for playable creatives
    private lazy var mraidShimSource: String = loadScript(named: "novaMraid")
    private lazy var mraidHookSource: String = loadScript(named: "novaMraidHook")
    private lazy var mraidInitSource: String = loadScript(named: "novaMraidInit")
}

// MARK: WKUIDelegate

extension NovaAdPlayableView: WKUIDelegate {
    func webView(
        _: WKWebView,
        createWebViewWith _: WKWebViewConfiguration,
        for _: WKNavigationAction,
        windowFeatures _: WKWindowFeatures
    ) -> WKWebView? {
        guard userDidClick else {
            return nil
        }

        let duration: CFTimeInterval? = {
            if let startTime {
                return CACurrentMediaTime() - startTime
            } else {
                return nil
            }
        }()
        actionHelper = actionHelper?
            .logNovaClickEvent(with: duration, in: .playable)
            .handleAdTap(in: nil)
        return nil
    }
}

// MARK: WKScriptMessageHandler

extension NovaAdPlayableView: WKScriptMessageHandler {
    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "mraidBridge" else { return }

        // Parse JSON message from JavaScript
        guard let jsonString = message.body as? String,
              let jsonData = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let action = jsonObject["action"] as? String
        else {
            return
        }

        let params = jsonObject["params"] as? [String: Any] ?? [:]

        // Handle MRAID actions
        handleMraidAction(action: action, params: params)
    }
}

// MARK: WKNavigationDelegate

extension NovaAdPlayableView: WKNavigationDelegate {
    func webView(
        _: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        if url.scheme == "mraid" {
            let command = url.host ?? ""
            switch command {
            case "open":
                handleMraidOpen(url: url)
            case "close":
                // Handle close command if needed
                break
            case "expand":
                // Handle expand command if needed
                break
            default:
                break
            }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        // Only initialize MRAID state for creatives that explicitly requested mraid.js
        guard hasRequestedMraidJs else {
            DebugLogger.data.info("Skipping MRAID init: creative did not request mraid.js")
            return
        }

        injectMraidShimIfNeeded()
        initializeMraidState(in: webView)
    }
}

// MARK: - MRAID Helpers

private extension NovaAdPlayableView {
    func injectMraidShimIfNeeded() {
        guard !hasInjectedMraidShim else { return }
        guard !mraidShimSource.isEmpty else { return }

        hasInjectedMraidShim = true
        playableWebView.evaluateJavaScript(mraidShimSource) { _, error in
            if let error {
                DebugLogger.data.error("Failed to inject MRAID shim: \(error)")
            } else {
                DebugLogger.data.info("Injected MRAID shim (novaMraid.js)")
            }
        }
    }

    func handleMraidAction(action: String, params: [String: Any]) {
        switch action {
        case "open":
            handleMraidOpen(params: params)
        case "close":
            // Handle close command if needed
            break
        case "expand":
            // Handle expand command if needed
            break
        case "mraidRequested":
            handleMraidRequested(params: params)
        default:
            break
        }
    }

    func handleMraidRequested(params: [String: Any]) {
        hasRequestedMraidJs = true
        injectMraidShimIfNeeded()
        if let src = params["src"] as? String {
            DebugLogger.data.info("MRAID requested via script src: \(src)")
        } else {
            DebugLogger.data.info("MRAID requested via script src")
        }
    }

    func handleMraidOpen(params _: [String: Any]) {
        // Extract URL from params if needed in the future
        // Currently, we only need to handle the click event, not the target URL

        let duration: CFTimeInterval? = {
            if let startTime { return CACurrentMediaTime() - startTime } else { return nil }
        }()
        actionHelper = actionHelper?
            .logNovaClickEvent(with: duration, in: .playable)
            .handleAdTap(in: nil)
    }

    func handleMraidOpen(url _: URL) {
        // Fallback handler for URL scheme (kept for backward compatibility)
        // Parse URL parameters from query string if needed in the future
        // Format: mraid://open?url=encoded_url
        // Currently, we only need to handle the click event, not the target URL

        let duration: CFTimeInterval? = {
            if let startTime { return CACurrentMediaTime() - startTime } else { return nil }
        }()
        actionHelper = actionHelper?
            .logNovaClickEvent(with: duration, in: .playable)
            .handleAdTap(in: nil)
    }

    func initializeMraidState(in webView: WKWebView) {
        guard !mraidInitSource.isEmpty else { return }
        webView.evaluateJavaScript(mraidInitSource) { _, error in
            if let error = error {
                print("Failed to initialize MRAID state: \(error)")
            }
        }
    }

    func loadScript(named resourceName: String) -> String {
        guard let url = NovaResource.getJSScriptResourceURL(resourceName)
            ?? Bundle.main.url(forResource: resourceName, withExtension: "js")
        else {
            assertionFailure("Failed to find \(resourceName).js in bundle")
            return ""
        }

        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            assertionFailure("Failed to load \(resourceName).js from bundle: \(error)")
            return ""
        }
    }
}
