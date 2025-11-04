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
        (function () {
            if (window.mraid) return;
        
            var listeners = {};
        
            window.mraid = {
                getState: function () {
                    return 'default';
                },
                getVersion: function () {
                    return '2.0';
                },
                isViewable: function () {
                    return true;
                },
        
                addEventListener: function (event, listener) {
                    if (!listeners[event]) listeners[event] = [];
                    listeners[event].push(listener);
                },
                removeEventListener: function (event, listener) {
                    if (!listeners[event]) return;
                    var idx = listeners[event].indexOf(listener);
                    if (idx !== -1) listeners[event].splice(idx, 1);
                },
        
                open: function (url) {
                    window.location = 'mraid://open?url=' + encodeURIComponent(url);
                },
                close: function () {
                    window.location = 'mraid://close';
                },
                expand: function (url) {
                    window.location =
                        'mraid://expand' + (url ? ('?url=' + encodeURIComponent(url)) : '');
                },
                useCustomClose: function (use) {
                    window.location = 'mraid://useCustomClose?value=' + (use ? 'true' : 'false');
                },
        
                fireEvent: function (event, args) {
                    if (!listeners[event]) return;
                    listeners[event].forEach(function (fn) {
                        try {
                            fn(args);
                        } catch (e) { }
                    });
                }
            };
        })();
        """

    private var actionHelper: NovaActionHelper<NovaActionState.Init>?
    private var startTime: CFTimeInterval?
    private var userDidClick: Bool = false
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
    public func webView(
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
                handleMraidOpen()
            default:
                break
            }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}

// MARK: - MRAID Helpers

private extension NovaAdPlayableView {
    func handleMraidOpen() {
        let duration: CFTimeInterval? = {
            if let startTime { return CACurrentMediaTime() - startTime } else { return nil }
        }()
        actionHelper = actionHelper?
            .logNovaClickEvent(with: duration, in: .playable)
            .handleAdTap(in: nil)
    }
}
