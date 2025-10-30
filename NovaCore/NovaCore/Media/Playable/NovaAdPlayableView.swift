//
//  NovaAdPlayableView.swift
//  NBImmersiveAd
//
//  Created by Shanyu Li on 2025/5/13.
//

import Foundation
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
        playableWebView.configuration.userContentController.removeScriptMessageHandler(forName: "mraid")
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
        // Inject minimal MRAID bridge
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "mraid")
        userContentController.addUserScript(WKUserScript(source: mraidShimSource, injectionTime: .atDocumentStart, forMainFrameOnly: true))
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

    private lazy var mraidShimSource: String = // Minimal MRAID 3.0-compatible surface for playable creatives
        """
        (function() {
            if (window.mraid) { return; }
            var listeners = { ready: [], stateChange: [], viewableChange: [] };
            var state = 'loading';
            var placementType = 'inline';
            var viewable = false;
            function fire(event, args) {
                var list = listeners[event];
                for (var i = 0; i < list.length; i++) {
                    try { list[i].apply(null, args || []); } catch (e) {}
                }
            }
            window.mraid = {
                getVersion: function() { return '3.0'; },
                getState: function() { return state; },
                getPlacementType: function() { return placementType; },
                isViewable: function() { return viewable; },
                addEventListener: function(event, listener) {
                    if (!listeners[event]) { return; }
                    var list = listeners[event];
                    if (list.indexOf(listener) === -1) { list.push(listener); }
                },
                removeEventListener: function(event, listener) {
                    if (!listeners[event]) { return; }
                    var list = listeners[event];
                    var idx = list.indexOf(listener);
                    if (idx !== -1) { list.splice(idx, 1); }
                },
                open: function(url) {
                    if (!url) { return; }
                    window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mraid && window.webkit.messageHandlers.mraid.postMessage({ command: 'open', url: String(url) });
                },
                close: function() {
                    window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mraid && window.webkit.messageHandlers.mraid.postMessage({ command: 'close' });
                },
                expand: function() {
                    window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mraid && window.webkit.messageHandlers.mraid.postMessage({ command: 'expand' });
                }
            };
            window.mraidBridge = {
                setState: function(s) { state = s; fire('stateChange', [s]); },
                setViewable: function(v) { var b = (v === true || v === 'true'); if (viewable !== b) { viewable = b; fire('viewableChange', [b]); } },
                fireReady: function() { fire('ready'); }
            };
        })();
        """

    private var isMraidViewable: Bool = false {
        didSet {
            let js = "window.mraidBridge && window.mraidBridge.setViewable(\(isMraidViewable ? "true" : "false"));"
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
}

// MARK: WKUIDelegate

extension NovaAdPlayableView: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
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
        self.actionHelper = self.actionHelper?
            .logNovaClickEvent(with: duration, in: .playable)
            .handleAdTap(in: nil)
        return nil
    }
}

// MARK: WKNavigationDelegate

extension NovaAdPlayableView: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // MRAID ready, default state, set viewable
        let js = "window.mraidBridge && (window.mraidBridge.setState('default'), window.mraidBridge.fireReady());"
        webView.evaluateJavaScript(js, completionHandler: nil)
        updateMraidViewable()
    }
}

// MARK: WKScriptMessageHandler

extension NovaAdPlayableView: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "mraid" else { return }
        guard let body = message.body as? [String: Any], let command = body["command"] as? String else { return }

        switch command {
        case "open":
            let urlString = body["url"] as? String
            handleMraidOpen(urlString: urlString)
        default:
            break
        }
    }
}

// MARK: - MRAID Helpers

private extension NovaAdPlayableView {
    func handleMraidOpen(urlString: String?) {
        let duration: CFTimeInterval? = {
            if let startTime { return CACurrentMediaTime() - startTime } else { return nil }
        }()
        self.actionHelper = self.actionHelper?
            .logNovaClickEvent(with: duration, in: .playable)
            .handleAdTap(in: nil)
    }
}
