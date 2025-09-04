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

    // MARK: Internal

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
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.backgroundColor = .clear

        webView.uiDelegate = self
        return webView
    }()

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
