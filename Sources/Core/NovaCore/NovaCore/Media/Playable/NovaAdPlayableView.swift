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
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        playableWebView.configuration.userContentController.removeScriptMessageHandler(forName: "mraidBridge")
    }

    // MARK: Internal

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateMraidViewable()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        updateMraidViewable()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateMraidViewable()
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
        let userContentController = WKUserContentController()
        userContentController.addUserScript(
            WKUserScript(
                source: mraidShimSource,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
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

    private lazy var mraidShimSource: String = {
        if let script = loadScriptResource(named: "novaMraid") {
            return script
        }
        assertionFailure("Failed to load novaMraid.js from bundle")
        return ""
    }()

    private var isMraidViewable: Bool = false {
        didSet {
            guard oldValue != isMraidViewable else { return }
            let boolString = isMraidViewable ? "true" : "false"
            let js = """
                if (window.mraid && window.mraid._setIsViewable) {
                    window.mraid._setIsViewable(\(boolString));
                }
            """
            playableWebView.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    private var actionHelper: NovaActionHelper<NovaActionState.Init>?
    private var startTime: CFTimeInterval?
    private var userDidClick: Bool = false

    private func updateMraidViewable() {
        let currentlyViewable = window != nil && alpha > 0.01 && !isHidden
        isMraidViewable = currentlyViewable
    }

    private func initializeMraidState(in webView: WKWebView) {
        guard let initScript = loadScriptResource(named: "novaMraidInit") else {
            assertionFailure("Failed to load novaMraidInit.js from bundle")
            return
        }

        webView.evaluateJavaScript(initScript, completionHandler: nil)
    }

    private func handleMraidOpen() {
        let duration: CFTimeInterval? = {
            if let startTime { return CACurrentMediaTime() - startTime } else { return nil }
        }()
        actionHelper = actionHelper?
            .logNovaClickEvent(with: duration, in: .playable)
            .handleAdTap(in: nil)
    }

    private func loadScriptResource(named resourceName: String) -> String? {
        if let scriptURL = NovaResource.getJSScriptResourceURL(resourceName),
           let script = try? String(contentsOf: scriptURL, encoding: .utf8)
        {
            return script
        }

        if let scriptURL = Bundle.main.url(forResource: resourceName, withExtension: "js"),
           let script = try? String(contentsOf: scriptURL, encoding: .utf8)
        {
            return script
        }

        return nil
    }
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

        handleMraidOpen()
        return nil
    }
}

// MARK: WKScriptMessageHandler

extension NovaAdPlayableView: WKScriptMessageHandler {
    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "mraidBridge" else { return }
        guard let jsonString = message.body as? String,
              let jsonData = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let action = jsonObject["action"] as? String
        else {
            return
        }

        switch action {
        case "open":
            handleMraidOpen()
        case "expand", "close", "unload", "resize":
            break
        default:
            break
        }
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
            if command == "open" {
                handleMraidOpen()
            }
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        initializeMraidState(in: webView)
        updateMraidViewable()
    }
}
