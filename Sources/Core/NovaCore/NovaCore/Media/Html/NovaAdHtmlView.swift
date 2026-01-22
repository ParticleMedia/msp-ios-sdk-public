//
//  NovaAdHtmlView.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/29/25.
//
import UIKit
import WebKit

class NovaAdHtmlView: WKWebView, WKScriptMessageHandler {
    struct TracingInfo {
        let adUnitId: String
        let encryptedToken: String
    }

    // a view for each html page
    weak var htmlActionDelegate: NovaAdHtmlActionDelegate?
    var tracingInfo: TracingInfo?
    var impressionTimeInMs: Int?

    var useCustomUrl: Bool = false
    var useCustomClose: Bool = false

    public init(supportReportHandling: Bool) {
        let config = WKWebViewConfiguration()
        let userController = WKUserContentController()
        config.userContentController = userController

        let prefs = WKPreferences()
        prefs.javaScriptEnabled = true
        config.preferences = prefs
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.requiresUserActionForMediaPlayback = false
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        super.init(frame: .zero, configuration: config)
        for message in NovaAdHtmlJSMessage.allCases {
            userController.add(self, name: message.rawValue)
        }
        self.navigationDelegate = self
        self.uiDelegate = self
        self.scrollView.isScrollEnabled = false
        self.scrollView.contentInsetAdjustmentBehavior = .never
        self.allowsBackForwardNavigationGestures = true
        self.scrollView.bounces = false
        self.scrollView.contentInsetAdjustmentBehavior = .never
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.showsHorizontalScrollIndicator = false

        injectNovaNativeBridge(enableFeedback: supportReportHandling)
        injectGetAdContextBridge()

        // Inject MRAID hook script (detection only)
        userController.addUserScript(
            WKUserScript(
                source: mraidHookSource,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )

        addSubviews(passThroughView)
        passThroughView.snp.makeConstraints { make in
            make.directionalEdges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func destory() {
        self.clickEventTimerTask?.cancel()
        self.clickEventTimerTask = nil
        for message in NovaAdHtmlJSMessage.allCases {
            configuration.userContentController.removeScriptMessageHandler(forName: message.rawValue)
        }
        configuration.userContentController.removeAllUserScripts()
        self.navigationDelegate = nil
        self.uiDelegate = nil
        self.scrollView.delegate = nil
    }
    deinit {
        DebugLogger.data.debug("htmlview deinit")
        for message in NovaAdHtmlJSMessage.allCases {
            configuration.userContentController.removeScriptMessageHandler(forName: message.rawValue)
        }
    }

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
    private var startTime: CFTimeInterval?
    private var userDidClick: Bool = false
    private var hasRequestedMraidJs: Bool = false
    private var hasInjectedMraidShim: Bool = false

    // Minimal MRAID 3.0-compatible surface for HTML creatives
    private lazy var mraidShimSource: String = loadScript(named: "novaMraid")
    private lazy var mraidHookSource: String = loadScript(named: "novaMraidHook")
    private lazy var mraidInitSource: String = loadScript(named: "novaMraidInit")

    // MARK: - JS injection
    private func injectNovaNativeBridge(enableFeedback: Bool) {
        // Precompute static capability map
        let enableFeedbackString = enableFeedback ? "true" : "false"

        let js = """
            window.novaNativeBridge = {
                supports: function(feature) {
                    switch (feature) {
                        case 'feedback':
                            return \(enableFeedbackString);
                        default:
                            return false;
                    }
                },
                startFeedback: function() {
                    window.webkit.messageHandlers.novaNativeBridge.postMessage({ action: 'startFeedback' });
                },
                
                open: function(payload) {
                    window.webkit.messageHandlers.novaNativeBridge.postMessage({
                        action: 'open',
                        payload: payload || "{}"
                    });
                }
            };
            """

        let script = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        configuration.userContentController.addUserScript(script)
    }

    private func injectGetAdContextBridge() {
        let js = """
            if (!window.__getAdContextBridgeInjected) {
                window.__getAdContextBridgeInjected = true;

                window.novaNativeBridge = window.novaNativeBridge || {};

                // Promise-based call
                window.novaNativeBridge.getAdContext = function() {
                    return new Promise(function(resolve, reject) {
                        try {
                            window.__resolveAdContext = resolve;
                            window.webkit.messageHandlers.getAdContext.postMessage({});
                        } catch(e) { reject(e); }
                    });
                };

                // Swift calls this and JS returns a STRING
                window.onAdContext = function(dataString) {
                    try {
                        // resolve any waiting Promise
                        if (window.__resolveAdContext) {
                            window.__resolveAdContext(dataString);
                            window.__resolveAdContext = null;
                        }
                    } catch(e) { console.error(e); }

                    // MUST return a string because web requested it
                    return dataString;
                };
            }
            """

        let script = WKUserScript(
            source: js,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false)
        configuration.userContentController.addUserScript(script)
    }

    private func attachAdContext() {
        let raw: [String: Any?] = [
            "os": UIDevice.current.systemName,
            "osv": UIDevice.current.systemVersion,
            "bundle": Bundle.main.bundleIdentifier ?? "",
            "cv": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            "ad_unit_id": tracingInfo?.adUnitId,
            "encrypted_ad_token": tracingInfo?.encryptedToken,
            "impression_ts": impressionTimeInMs,
        ]
        let dict: [String: Any] = raw.compactMapValues { $0 }
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: dict)
        } catch {
            DebugLogger.data.error("Failed to serialize ad context: \(String(describing: error), privacy: .public)")
            return
        }
        guard let jsonString = String(data: data, encoding: .utf8) else {
            DebugLogger.data.error("Failed to encode ad context JSON as UTF-8")
            return
        }
        let escaped =
            jsonString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let js = "window.onAdContext(\"\(escaped)\")"
        self.evaluateJavaScript(js, completionHandler: nil)
    }

    public func config(
        with model: NovaAdHtmlPageModel, htmlActionDelegate: NovaAdHtmlActionDelegate?, tracingInfo: TracingInfo
    ) {
        self.htmlActionDelegate = htmlActionDelegate
        self.tracingInfo = tracingInfo
        let resource = model.resource
        self.useCustomUrl = model.useClickUrl
        self.useCustomClose = model.useCustomClose
        resetMraidState()
        switch resource {
        case let .html(html, baseUrl):
            loadHTMLString(html, baseURL: baseUrl)
        case let .url(url):
            load(URLRequest(url: url))
        }
        self.impressionTimeInMs = Int(Date().timeIntervalSince1970 * 1000)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case NovaAdHtmlJSMessage.consoleLog.rawValue:
            print("JS Console: \(String(describing: message.body))")
        case NovaAdHtmlJSMessage.adReport.rawValue:
            htmlActionDelegate?.didTapAdReport()
        case NovaAdHtmlJSMessage.adClose.rawValue:
            if self.useCustomClose {
                htmlActionDelegate?.didTapAdClose()
            }
        case NovaAdHtmlJSMessage.novaNativeBridge.rawValue:
            if let body = message.body as? [String: Any],
                let action = body["action"] as? String
            {
                switch action {
                case "startFeedback":
                    htmlActionDelegate?.didTapAdReport()
                case "open":
                    var customUrl: URL? = nil
                    var clickAreaString: String = ""

                    if let jsonString = body["payload"] as? String,
                        let data = jsonString.data(using: .utf8),
                        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    {
                        // payload is [string : string?] per doc
                        if let urlString = json["url"] as? String,
                            !urlString.isEmpty
                        {
                            customUrl = URL(string: urlString)
                        }

                        clickAreaString = (json["click_area_name"] as? String) ?? ""
                    }

                    htmlActionDelegate?.didTapAdCtr(
                        customUrl: customUrl,
                        clickArea: ClickableAdArea(rawValue: clickAreaString) ?? .html
                    )
                default:
                    DebugLogger.data.debug("Unknown novaNativeBridge action: \(action, privacy: .public)")
                }
            }
        case NovaAdHtmlJSMessage.getAdContext.rawValue:
            self.attachAdContext()
        case NovaAdHtmlJSMessage.mraidBridge.rawValue:
            guard let jsonString = message.body as? String,
                let jsonData = jsonString.data(using: .utf8),
                let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                let action = jsonObject["action"] as? String
            else {
                DebugLogger.data.error("Failed to parse mraidBridge message: \(String(describing: message.body))")
                return
            }

            let params = jsonObject["params"] as? [String: Any] ?? [:]

            // Handle MRAID actions
            handleMraidAction(action: action, params: params)
        default:
            DebugLogger.data.debug("Unknown JS message: \(message.name, privacy: .public)")
        }
    }
}

extension NovaAdHtmlView: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        guard userDidClick else {
            decisionHandler(.allow)
            return
        }

        userDidClick = false

        // Handle mraid:// URL scheme
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

        htmlActionDelegate?.didTapAdCtr(customUrl: navigationAction.request.url, clickArea: .html)

        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        // Only initialize MRAID state for creatives that explicitly requested mraid.js
        guard hasRequestedMraidJs else {
            DebugLogger.data.debug("Skipping MRAID init: creative did not request mraid.js")
            return
        }

        injectMraidShimIfNeeded()
        initializeMraidState(in: webView)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        htmlActionDelegate?.didFailToLoadPage()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        htmlActionDelegate?.didFailToLoadPage()
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        htmlActionDelegate?.didFailToLoadPage()
    }
}

extension NovaAdHtmlView: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard userDidClick else {
            return nil
        }
        userDidClick = false
        if useCustomUrl {
            htmlActionDelegate?.didTapAdCtr(customUrl: navigationAction.request.url, clickArea: .html)
        } else {
            htmlActionDelegate?.didTapAdCtr(customUrl: nil, clickArea: .html)
        }
        return nil
    }
}

// MARK: - MRAID Helpers

private extension NovaAdHtmlView {
    func loadScript(named resourceName: String) -> String {
        guard
            let url = NovaResource.getJSScriptResourceURL(resourceName)
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

    func resetMraidState() {
        hasRequestedMraidJs = false
        hasInjectedMraidShim = false
    }

    func injectMraidShimIfNeeded() {
        guard !hasInjectedMraidShim else { return }
        guard !mraidShimSource.isEmpty else { return }

        hasInjectedMraidShim = true
        self.evaluateJavaScript(mraidShimSource) { _, error in
            if let error {
                DebugLogger.data.error("Failed to inject MRAID shim: \(String(describing: error), privacy: .public)")
            } else {
                DebugLogger.data.debug("Injected MRAID shim (novaMraid.js)")
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
            DebugLogger.data.debug("MRAID requested via script src: \(src, privacy: .public)")
        } else {
            DebugLogger.data.debug("MRAID requested via script src")
        }
    }

    func handleMraidOpen(params: [String: Any]) {
        var customUrl: URL? = nil
        if let urlString = params["url"] as? String {
            customUrl = URL(string: urlString)
        }
        htmlActionDelegate?.didTapAdCtr(customUrl: customUrl, clickArea: .html)
    }

    func handleMraidOpen(url: URL) {
        // Fallback handler for URL scheme (kept for backward compatibility)
        // Parse URL parameters from query string if needed in the future
        // Format: mraid://open?url=encoded_url
        var customUrl: URL? = nil
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems,
            let urlString = queryItems.first(where: { $0.name == "url" })?.value
        {
            customUrl = URL(string: urlString)
        }
        htmlActionDelegate?.didTapAdCtr(customUrl: customUrl, clickArea: .html)
    }

    func initializeMraidState(in webView: WKWebView) {
        guard !mraidInitSource.isEmpty else { return }

        webView.evaluateJavaScript(mraidInitSource) { _, error in
            if let error = error {
                DebugLogger.data.error(
                    "Failed to initialize MRAID state: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
