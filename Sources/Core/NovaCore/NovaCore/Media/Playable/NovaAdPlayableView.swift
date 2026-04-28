//
//  NovaAdPlayableView.swift
//  NBImmersiveAd
//
//  Created by Shanyu Li on 2025/5/13.
//

// MARK: - NovaAdPlayableView

import Foundation
import MSPiOSCore
import UIKit
import WebKit

public protocol NovaAdPlayableViewDelegate: AnyObject {
    func playableViewDidRequestClose()
}

public extension NovaAdPlayableViewDelegate {
    func playableViewDidRequestClose() {}
}

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
        mraidController.install(in: playableWebView.configuration.userContentController)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        // Remove message handlers to avoid memory leaks
        #if DEBUG
            playableWebView.configuration.userContentController.removeScriptMessageHandler(forName: "consoleLog")
        #endif
        playableWebView.configuration.userContentController.removeScriptMessageHandler(
            forName: MraidController.scriptMessageName
        )
    }

    func config(
        with playableModel: PlayableModel,
        actionContext: NovaAdMediaActionContext?,
        actionHelper: NovaActionHelper<NovaActionState.Init>? = nil
    ) {
        playableWebView.load(URLRequest(url: playableModel.playableUrl))
        startTime = CACurrentMediaTime()

        if let actionHelper = actionHelper {
            self.actionHelper = actionHelper
        } else {
            guard let actionContext else {
                assertionFailure("Playable ad lack of tracing and action info")
                return
            }

            self.actionHelper = {
                if let weakVC = actionContext.viewController {
                    return
                        NovaActionHelper
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
                    return
                        NovaActionHelper
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

        #if DEBUG
            userContentController.addUserScript(
                WKUserScript(
                    source: consoleLoggerSource,
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: true
                )
            )
        #endif

        #if DEBUG
            userContentController.add(self, name: "consoleLog")
        #endif
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
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        return webView
    }()

    private var actionHelper: NovaActionHelper<NovaActionState.Init>?
    private var startTime: CFTimeInterval?
    private var userDidClick: Bool = false
    weak var delegate: NovaAdPlayableViewDelegate?


    // Minimal MRAID 3.0-compatible surface for playable creatives
    private lazy var consoleLoggerSource: String = NovaJavaScriptResourceLoader.loadScript(named: "consoleLogger")
    private lazy var mraidController = MraidController(
        webView: playableWebView,
        mraidDelegate: self
    )
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
            DebugLogger.ui.info("[Playable] Blocked window.open() — no preceding user tap")
            return nil
        }

        DebugLogger.ui.info("[Playable] window.open() received — opening landing page")
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
        #if DEBUG
            if message.name == "consoleLog" {
                handleConsoleLog(message: message)
                return
            }
        #endif
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
            // mraid:// scheme bypasses the JS-layer userActivation check in
            // novaMraid.js, so we guard with native userDidClick here.
            if userDidClick {
                DebugLogger.ui.info("[Playable] mraid:// scheme received — handling via MraidController")
                mraidController.handleMraidSchemeURL(url)
            } else {
                DebugLogger.ui.warning("[Playable] Blocked mraid:// scheme — no preceding user tap")
            }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        mraidController.handlePageFinished()
    }
}

extension NovaAdPlayableView: MraidBehaviorDelegate {
    func mraidOpen(url: URL?) {
        // Auto-redirect protection is handled entirely in novaMraid.js:
        //   iOS 16+: navigator.userActivation.isActive (~5s window)
        //   iOS 15:  click/touchend event listener (300ms window)
        // No native guard here — mraid.open() is a pure JS API so the JS
        // layer always executes first. A native userDidClick guard would
        // conflict because its 0.3s timer is shorter than userActivation's
        // ~5s window, causing legitimate clicks to be dropped when the
        // creative has animation between tap and mraid.open().
        DebugLogger.ui.info("[Playable] mraid.open() received — opening landing page")
        let duration: CFTimeInterval? = {
            if let startTime { return CACurrentMediaTime() - startTime } else { return nil }
        }()
        actionHelper = actionHelper?
            .logNovaClickEvent(with: duration, in: .playable)
            .handleAdTap(in: nil)
    }

    func mraidClose() {
        delegate?.playableViewDidRequestClose()
    }
}

#if DEBUG
    private extension NovaAdPlayableView {
        func handleConsoleLog(message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                let level = body["level"] as? String,
                let logMessage = body["message"] as? String
            else {
                return
            }

            let prefix: String
            switch level {
            case "error":
                prefix = "[JS Error]"
            case "warn":
                prefix = "[JS Warn]"
            case "info":
                prefix = "[JS Info]"
            case "debug":
                prefix = "[JS Debug]"
            default:
                prefix = "[JS Log]"
            }

            DebugLogger.data.info("\(prefix) \(logMessage)")
        }
    }
#endif

extension NovaAdPlayableView {
    var mraidWebView: WKWebView { playableWebView }
    var mraidCalendarEventDefaultTitle: String { "Playable Event" }
}
