//
//  UnifiedWebViewHost.swift
//  NovaAdapter
//
//  Created by Huanzhi Zhang on 6/19/24.
//

import Foundation
import WebKit

class NovaUnifiedWebViewHost: NSObject {
    private let config: NovaUnifiedWebViewConfig
    private let jsBridgeHandlerMaster: NovaJSBridgeHandlerMaster?
    private var isGoingBackForward = false

    private var wkWebView: WKWebView?
    private weak var navigationDelegate: NovaUnifiedWebViewNavigationDelegate?

    private struct Constants {
        static let jsMessageName = "callNative"
        static let jsBridgeAction = "action"
        static let jsBridgeCallback = "callback"
    }

    private let nativeSchemes: Set<String> = [
        "tel",
        "mailto",
        "sms",
        "newsbreak",
        "com.amazon.mobile.shopping.web",
        "itms-apps",
        "itms-services",
    ]
    private let appStoreHosts: Set<String> = [
        "apps.apple.com",
        "itunes.apple.com",
    ]

    init(
        config: NovaUnifiedWebViewConfig,
        jsBridgeHandlerMaster: NovaJSBridgeHandlerMaster?,
        navigationDelegate: NovaUnifiedWebViewNavigationDelegate?
    ) {
        self.config = config
        self.jsBridgeHandlerMaster = jsBridgeHandlerMaster
        self.navigationDelegate = navigationDelegate

        super.init()

        let userContentController = WKUserContentController()
        userContentController.add(NovaScriptMessageHandlerProxy(handler: self), name: Constants.jsMessageName)
        if let ruleList = NovaContentBlockHelper.contentBlockRuleList(for: config.blockedURLPrefixes) {
            userContentController.add(ruleList)
            //DebugLogging.info(.jsBridge, "webview apply content block rules for url prefixes:\(config.blockedURLPrefixes)")
        }

        let wkWebViewConfiguration = WKWebViewConfiguration()
        wkWebViewConfiguration.userContentController = userContentController
        wkWebViewConfiguration.allowsInlineMediaPlayback = true
        if config.enableNBUserAgent {
            //wkWebViewConfiguration.applicationNameForUserAgent = WKWebView.nb_userAgent
        }

        if config.enableJSBridge {
            let injectedJS = """
                    if (typeof NBJS == "undefined") {
                        var NBJS = {};
                        var callNativeObj = window.webkit.messageHandlers.callNative;
                        NBJS.callNative = callNativeObj.postMessage.bind(callNativeObj);
                    }
                """
            let wkUserScript = WKUserScript(
                source: injectedJS, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            userContentController.addUserScript(wkUserScript)
        }

        self.wkWebView = WKWebView(frame: .zero, configuration: wkWebViewConfiguration)
        if #available(iOS 16.4, *) {
            self.wkWebView?.isInspectable = true
        }
        self.wkWebView?.navigationDelegate = self
        wkWebView?.uiDelegate = self
    }

    //func addJSBridgeHandler(jsBridgeHandlers: [JSBridgeHandling]) {
    //    self.jsBridgeHandlerMaster?.addActionHandlers(jsBridgeHandlers: jsBridgeHandlers)
    //}

    func injectJavaScript(_ js: String, injectionTime: WKUserScriptInjectionTime) {
        let wkUserScript = WKUserScript(source: js, injectionTime: injectionTime, forMainFrameOnly: true)
        self.wkWebView?.configuration.userContentController.addUserScript(wkUserScript)
    }

    func webView() -> WKWebView {
        wkWebView!
    }

    func load(_ url: URL, referer: String? = nil) {
        var request = URLRequest(url: url)
        if let referer = referer {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }
        for (field, value) in config.headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        self.wkWebView?.load(request)
    }

    var scrollDepth: Double? {
        guard let scrollView = wkWebView?.scrollView else {
            return nil
        }

        return Double(scrollView.contentOffset.y) / Double(scrollView.contentSize.height)
    }

    var pageIndex: Int? {
        wkWebView?.backForwardList.backList.count
    }

    // MARK: - Private

    private func canonicalizeAppStoreURL(_ url: URL) -> URL {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let scheme = comps.scheme?.lowercased()
        else { return url }
        // scheme could be `itms-appss`
        if scheme.hasPrefix("itms-apps") { comps.scheme = "itms-apps" }
        if scheme.hasPrefix("itms-services") { comps.scheme = "itms-services" }
        return comps.url ?? url
    }

    private func isAppStoreWebURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else {
            return false
        }
        return appStoreHosts.contains(host)
    }

    // App Store product pages usually contain `/app/` and a numeric `id`.
    private func isLikelyAppStoreProductPath(_ path: String) -> Bool {
        let lowercasedPath = path.lowercased()
        guard lowercasedPath.contains("/app/") else {
            return false
        }
        return lowercasedPath.range(of: "/id\\d+", options: .regularExpression) != nil
    }

    // Converts App Store web links (http/https) into itms-apps deep links.
    private func itmsAppStoreURL(fromWebURL url: URL) -> URL? {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let scheme = comps.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            isAppStoreWebURL(url),
            isLikelyAppStoreProductPath(comps.path)
        else {
            return nil
        }
        comps.scheme = "itms-apps"
        return comps.url
    }

    @discardableResult
    private func openOutsideIfPossible(_ url: URL) -> Bool {
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return true
        }
        return false
    }

    private func webView(_ webView: WKWebView, policyFor navigationAction: WKNavigationAction)
        -> WKNavigationActionPolicy
    {
        let sourceFrame: WKFrameInfo? = navigationAction.sourceFrame
        let targetFrame: WKFrameInfo? = navigationAction.targetFrame

        guard let originalUrl = navigationAction.request.url else {
            return .allow
        }

        if !webView.canGoBack && navigationAction.navigationType == .linkActivated {
            navigationDelegate?.webViewInitialLoadDidRedirect(webView)
        }
        isGoingBackForward = navigationAction.navigationType == .backForward

        let url = canonicalizeAppStoreURL(originalUrl)
        if let appStoreURL = itmsAppStoreURL(fromWebURL: url),
            openOutsideIfPossible(appStoreURL)
        {
            return .cancel
        }
        if let scheme = url.scheme,
            nativeSchemes.contains(scheme),
            openOutsideIfPossible(url)
        {
            return .cancel
        }

        if !["http", "https"].contains(url.scheme) {
            return .allow
        }

        if config.goBackByUrlAllowed && url.absoluteString.contains("__go_back__") {
            //NBUtil.topViewController()?.navigationController?.popViewController(animated: true)
            return .cancel
        }

        // for google ad in iframe. we should avoid redirect in main frame when click.
        if let source = sourceFrame, !source.isMainFrame, let target = targetFrame, target.isMainFrame {
            if let navigationDelegate = self.navigationDelegate,
                navigationDelegate.webView(self.webView(), canRedirectTo: url)
            {
                navigationDelegate.openWebPage(url)
            }
            return .cancel
        }

        // link open new page
        if navigationAction.navigationType == .linkActivated && targetFrame == nil {
            if let navigationDelegate = self.navigationDelegate,
                navigationDelegate.webView(self.webView(), canRedirectTo: url)
            {
                navigationDelegate.openWebPage(url)
            }
            return .cancel
        }

        // link page in place
        if navigationAction.navigationType == .linkActivated, let target = targetFrame, target.isMainFrame {
            if let navigationDelegate = self.navigationDelegate,
                navigationDelegate.webView(self.webView(), canRedirectTo: url)
            {
                navigationDelegate.openWebPage(url)
            }
            return .cancel
        }

        return .allow
    }

    func SafeAs<T, U>(_ object: T?, _ objectType: U.Type) -> U? {
        if let object = object {
            if let temp = object as? U {
                return temp
            } else {
                //            assertionFailure("cannot cast \(object) to \(objectType)")
                return nil
            }
        } else {
            // It's always OK to cast nil to nil
            return nil
        }
    }
}

extension NovaUnifiedWebViewHost: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {}
}

extension NovaUnifiedWebViewHost: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        self.navigationDelegate?.webView(webView, didCommit: navigation)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.navigationDelegate?.webView(webView, didStartProvisionalNavigation: navigation)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        if let policy = self.navigationDelegate?.webView(webView, policyFor: navigationAction) {
            decisionHandler(policy, preferences)
        } else {
            let actionPolicy = self.webView(webView, policyFor: navigationAction)
            decisionHandler(actionPolicy, preferences)
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        let actionPolicy = self.webView(webView, policyFor: navigationAction)
        decisionHandler(actionPolicy)
    }

    func webView(
        _ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        self.navigationDelegate?.webView(webView, decidePolicyFor: navigationResponse, decisionHandler: decisionHandler)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.navigationDelegate?.webView(webView, didFinish: navigation)
        let currentIsInitialLoad = webView.canGoForward && !webView.canGoBack
        if isGoingBackForward && currentIsInitialLoad {
            navigationDelegate?.webViewDidGoBackToInitialLoad(webView)
            isGoingBackForward = false
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.navigationDelegate?.webView(webView, didFailProvisionalNavigation: navigation, withError: error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        self.navigationDelegate?.webViewWebContentProcessDidTerminate(webView)
    }
}

extension NovaUnifiedWebViewHost: WKUIDelegate {
    func webView(
        _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard let url = navigationAction.request.url else {
            return nil
        }

        let canonicalURL = canonicalizeAppStoreURL(url)

        if let appStoreURL = itmsAppStoreURL(fromWebURL: canonicalURL),
            openOutsideIfPossible(appStoreURL)
        {
            return nil
        }

        if let scheme = canonicalURL.scheme?.lowercased(),
            nativeSchemes.contains(scheme),
            openOutsideIfPossible(canonicalURL)
        {
            return nil
        }

        if ["http", "https"].contains(canonicalURL.scheme?.lowercased() ?? "") {
            if let navigationDelegate = self.navigationDelegate,
                navigationDelegate.webView(self.webView(), canRedirectTo: canonicalURL)
            {
                navigationDelegate.openWebPage(canonicalURL)
            }
        }

        return nil
    }
}

/*
 extension UnifiedWebViewHost: JSBridgeCallbackDelegate {
 func jsCallback(callbackName: String, parameters: [String: Any]) {
 var parameterStr: String = ""
 if let data = try? JSONSerialization.data(withJSONObject: parameters, options: []) {
 parameterStr = String(data: data, encoding: .utf8) ?? ""
 }
 wkWebView?.evaluateJavaScript("\(callbackName)(\(parameterStr));", completionHandler: nil)
 }
 }
 */
