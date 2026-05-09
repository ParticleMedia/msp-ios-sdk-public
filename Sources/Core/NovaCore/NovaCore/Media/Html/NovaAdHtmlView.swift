//
//  NovaAdHtmlView.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/29/25.
//
import MSPiOSCore
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
    
    var pageResource: NovaAdHtmlResource?

    private var preloadCompletionHandler: (() -> Void)?
    private var preloadState: PreloadState = .idle

    private enum PreloadState {
        case idle
        case pending
        case finishedWithSuccess
        case finishedWithoutSuccess
    }
    var appStoreId: Int?

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
        let scriptMessageHandlerProxy = NovaScriptMessageHandlerProxy(handler: self)
        self.scriptMessageHandlerProxy = scriptMessageHandlerProxy
        for message in NovaAdHtmlJSMessage.allCases where message != .mraidBridge {
            userController.add(scriptMessageHandlerProxy, name: message.rawValue)
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
        
        self.isOpaque = false

        injectNovaNativeBridge(enableFeedback: supportReportHandling)
        injectGetAdContextBridge()

        mraidController.install(in: userController)

        addSubviews(passThroughView)
        passThroughView.snp.makeConstraints { make in
            make.directionalEdges.equalToSuperview()
        }
        
        if #available(iOS 16.4, *) {
            self.isInspectable = true
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func notifyMraidViewable(_ isViewable: Bool) {
        mraidController.notifyViewable(isViewable)
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

    private var scriptMessageHandlerProxy: NovaScriptMessageHandlerProxy?

    private lazy var mraidController = MraidController(
        webView: self,
        mraidDelegate: self
    )


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
                        case 'skoverlay':
                            return true;
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
                },

                sendNativeAction: function(paramsString) {
                    window.webkit.messageHandlers.novaNativeBridge.postMessage({
                        action: 'sendNativeAction',
                        payload: typeof paramsString === 'string' ? paramsString : JSON.stringify(paramsString || {})
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

    private func handleSendNativeAction(_ paramsString: String?) {
        guard let jsonString = paramsString,
              let data = jsonString.data(using: .utf8),
              let params = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = params["action"] as? String
        else { return }
        switch action {
        case "OPEN_IOS_STORE_OVERLAY":
            htmlActionDelegate?.showSKOverlay(appStoreId: appStoreId)
        default:
            DebugLogger.data.debug("Unknown sendNativeAction: \(action, privacy: .public)")
        }
    }

    public func config(
        with model: NovaAdHtmlPageModel, htmlActionDelegate: NovaAdHtmlActionDelegate?, tracingInfo: TracingInfo
    ) {
        self.htmlActionDelegate = htmlActionDelegate
        self.tracingInfo = tracingInfo
        self.appStoreId = model.appStoreId
        let resource = model.resource
        self.useCustomUrl = model.useClickUrl
        self.useCustomClose = model.useCustomClose
        mraidController.resetState()
        setBackgroundTheme(theme: model.theme)
        if pageResource == nil || pageResource != resource || preloadState != .finishedWithSuccess {
            switch resource {
            case let .html(html, baseUrl):
                loadHTMLString(html, baseURL: baseUrl)
            case let .url(url):
                load(URLRequest(url: url))
            }
            pageResource = resource
        }
        self.impressionTimeInMs = Int(Date().timeIntervalSince1970 * 1000)
    }
    
    public func preload(with model: NovaAdHtmlPageModel, completion: @escaping () -> Void, tracingInfo: TracingInfo) {
        self.tracingInfo = tracingInfo
        preloadCompletionHandler = completion
        preloadState = .pending
        let resource = model.resource
        self.pageResource = resource
        setBackgroundTheme(theme: model.theme)
        switch resource {
        case let .html(html, baseUrl):
            loadHTMLString(html, baseURL: baseUrl)
        case let .url(url):
            load(URLRequest(url: url))
        }
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
                    htmlActionDelegate?.didTapAdCtr(
                        NovaAdClickPayload.openPayload(from: body["payload"])
                    )
                case "sendNativeAction":
                    handleSendNativeAction(body["payload"] as? String)
                default:
                    DebugLogger.data.debug("Unknown novaNativeBridge action: \(action, privacy: .public)")
                }
            }
        case NovaAdHtmlJSMessage.getAdContext.rawValue:
            self.attachAdContext()
        default:
            DebugLogger.data.debug("Unknown JS message: \(message.name, privacy: .public)")
        }
    }
    
    func setBackgroundTheme(theme: String?) {
        guard let theme else {
            return
        }
        switch theme {
        case "LIGHT":
            self.backgroundColor = .white
        case "DARK":
            self.backgroundColor = .black
        default :
            break
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
        
        guard navigationAction.targetFrame == nil else {
            decisionHandler(.allow)
            return
        }

        userDidClick = false

        if url.scheme == "mraid" {
            DebugLogger.ui.info("[Html] mraid:// scheme received — handling via MraidController")
            mraidController.handleMraidSchemeURL(url)
            decisionHandler(.cancel)
            return
        }

        DebugLogger.ui.info("[Html] URL navigation click — opening landing page")
        htmlActionDelegate?.didTapAdCtr(
            NovaAdClickPayload(url: navigationAction.request.url, area: .html)
        )

        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        mraidController.handlePageFinished()
        if preloadState == .pending {
            handlePreloadCompletion(true)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if preloadState == .pending {
            handlePreloadCompletion(false)
        } else {
            htmlActionDelegate?.didFailToLoadPage(errorType: error.errorType, errorDetail: error.errorDetail)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if preloadState == .pending {
            handlePreloadCompletion(false)
        } else {
            htmlActionDelegate?.didFailToLoadPage(errorType: error.errorType, errorDetail: error.errorDetail)
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        if preloadState == .pending {
            handlePreloadCompletion(false)
        } else {
            htmlActionDelegate?.didFailToLoadPage(errorType: "Web Content Process Did Terminate", errorDetail:"")
        }
    }
    
    private func handlePreloadCompletion(_ isSuccess: Bool) {
        guard preloadState == .pending,
              let completionHandler = preloadCompletionHandler else {
            // preload completion should only be handled once for each ad
            return
        }
        if isSuccess {
            preloadState = .finishedWithSuccess
        } else {
            preloadState = .finishedWithoutSuccess
        }
        preloadCompletionHandler = nil
        DispatchQueue.main.async {
            completionHandler()
        }
    }
    
    func getWebErrorMessage(error: Error) -> String? {
        var errorMessage: String?
        if let castedNSError = error as? NSError {
            errorMessage = "\(castedNSError.domain):\(castedNSError.code)"
        } else {
            errorMessage = error.localizedDescription
        }
        return errorMessage
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
            DebugLogger.ui.info("[Html] Blocked window.open() — no preceding user tap")
            return nil
        }
        userDidClick = false
        DebugLogger.ui.info("[Html] window.open() received — opening landing page")
        if useCustomUrl {
            htmlActionDelegate?.didTapAdCtr(
                NovaAdClickPayload(url: navigationAction.request.url, area: .html)
            )
        } else {
            htmlActionDelegate?.didTapAdCtr(NovaAdClickPayload(url: nil, area: .html))
        }
        return nil
    }
}

extension NovaAdHtmlView: MraidBehaviorDelegate {
    func mraidOpen(url: URL?) {
        // Auto-redirect protection is handled entirely in novaMraid.js:
        //   iOS 16+: navigator.userActivation.isActive (~5s window)
        //   iOS 15:  click/touchend event listener (300ms window)
        // No native guard here — see NovaAdPlayableView.mraidOpen for rationale.
        DebugLogger.ui.info("[Html] mraid.open() received — opening landing page")
        htmlActionDelegate?.didTapAdCtr(NovaAdClickPayload(url: url, area: .html))
    }

    func mraidClose() {
        htmlActionDelegate?.didTapAdClose()
    }
}
