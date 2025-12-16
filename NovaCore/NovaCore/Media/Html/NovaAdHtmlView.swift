//
//  NovaAdHtmlView.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/29/25.
//
import WebKit
import UIKit

class NovaAdHtmlView: WKWebView, WKScriptMessageHandler {
    
    // a view for each html page
    weak var htmlJSMessageDelegate: NovaAdHtmlJSMessageDelegate?
    var novaInterstitialAdContext: NovaInterstitialAdContext?
    var impressionTimeInMs: Int?
    
    var useCustomUrl: Bool = false
    var useCustomClose: Bool = false
    
    public init() {
        
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
        userController.add(self, name: "consoleLog")
        self.navigationDelegate = self
        self.uiDelegate = self
        self.scrollView.isScrollEnabled = false
        self.scrollView.contentInsetAdjustmentBehavior = .never
        self.allowsBackForwardNavigationGestures = true
        self.scrollView.bounces = false
        self.scrollView.contentInsetAdjustmentBehavior = .never
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.showsHorizontalScrollIndicator = false

        injectNovaNativeBridge(enableFeedback: false)
        injectGetAdContextBridge()
        
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
        print("htmlview deinit")
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

        let script = WKUserScript(source: js,
                                  injectionTime: .atDocumentStart,
                                  forMainFrameOnly: false)
        configuration.userContentController.addUserScript(script)
    }
    
    private func attachAdContext() {
        
        let dict: [String: Any] = [
            "os": UIDevice.current.systemName,
            "osv": UIDevice.current.systemVersion,
            "bundle": Bundle.main.bundleIdentifier ?? "",
            "cv": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            "ad_unit_id": self.novaInterstitialAdContext?.interstitialAd.adUnitId,
            "encrypted_ad_token": self.novaInterstitialAdContext?.interstitialAd.encryptedAdToken,
            "impression_ts": impressionTimeInMs
        ]
        let data = try! JSONSerialization.data(withJSONObject: dict)
        let jsonString = String(data: data, encoding: .utf8)!
        let escaped = jsonString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let js = "window.onAdContext(\"\(escaped)\")"
        self.evaluateJavaScript(js, completionHandler: nil)
    }
    
    public func config(with model: NovaAdHtmlPageModel, htmlJSMessageDelegate: NovaAdHtmlJSMessageDelegate?, context: NovaInterstitialAdContext?) {
        self.htmlJSMessageDelegate = htmlJSMessageDelegate
        self.novaInterstitialAdContext = context
        let resource = model.resource
        self.useCustomUrl = model.useClickUrl
        self.useCustomClose = model.useCustomClose
        if let htmlString = resource.htmlString, !htmlString.isEmpty {
            if let urlString = resource.url, let baseURL = URL(string: urlString) {
                self.loadHTMLString(htmlString, baseURL: baseURL)
            } else {
                self.loadHTMLString(htmlString, baseURL: nil)
            }
        } else if let urlString = resource.url, let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            self.load(request)
        }
        self.impressionTimeInMs = Int(Date().timeIntervalSince1970 * 1000)
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "consoleLog" {
            print("JS Console:", message.body)
        }
        switch message.name {
        case NovaAdHtmlJSMessage.adClick.rawValue:
            var customUrl: URL? = nil
            if self.useCustomUrl,
               let body = message.body as? [String: Any],
               let urlString = body["customUrl"] as? String {
                customUrl = URL(string: urlString)
            }
            htmlJSMessageDelegate?.didTapAdCtr(customUrl: customUrl)
        case NovaAdHtmlJSMessage.adReport.rawValue:
            htmlJSMessageDelegate?.didTapAdReport()
        case NovaAdHtmlJSMessage.adClose.rawValue:
            if self.useCustomClose {
                htmlJSMessageDelegate?.didTapAdClose()
            }
        case NovaAdHtmlJSMessage.novaNativeBridge.rawValue:
            if let body = message.body as? [String: Any],
               let action = body["action"] as? String {
                switch action {
                case "startFeedback":
                    htmlJSMessageDelegate?.didTapAdReport()
                default:
                    print("⚠️ Unknown novaNativeBridge action:", action)
                }
            }
        case NovaAdHtmlJSMessage.getAdContext.rawValue:
            self.attachAdContext()
        default: print("⚠️ Unknown JS message:", message.name)
        }
    }
}

extension NovaAdHtmlView: WKNavigationDelegate {
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        guard userDidClick else {
            decisionHandler(.allow)
            return
        }
        userDidClick = false
        htmlJSMessageDelegate?.didTapAdCtr(customUrl: navigationAction.request.url)
        decisionHandler(.cancel)
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
            htmlJSMessageDelegate?.didTapAdCtr(customUrl: navigationAction.request.url)
        } else {
            htmlJSMessageDelegate?.didTapAdCtr(customUrl: nil)
        }
        return nil
    }
}

