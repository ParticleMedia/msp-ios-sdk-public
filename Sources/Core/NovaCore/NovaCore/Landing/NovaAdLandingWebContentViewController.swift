import Foundation
import SafariServices
import UIKit
import WebKit

class NovaAdLandingWebContentViewController: UIViewController {
    var initialLoadDidRedirectTo: ((WKWebView) -> Void)?
    var didGoBackToInitialLoad: ((WKWebView) -> Void)?
    var webViewDidScroll: ((UIScrollView) -> Void)?
    var webViewDidEndDragging: ((UIScrollView, Bool) -> Void)?
    var webViewDidEndDecelerating: ((UIScrollView) -> Void)?

    private var unifiedWebViewHost: NovaUnifiedWebViewHost!

    private let naviView: NovaWebViewNavigationView = {
        let naviView = NovaWebViewNavigationView()
        naviView.translatesAutoresizingMaskIntoConstraints = false
        return naviView
    }()

    private let progressView: UIProgressView = {
        let view = UIProgressView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.tintColor = UIColor(light: NovaColorPalettes.Blue.tint200, dark: NovaColorPalettes.Blue.tint400)
        return view
    }()

    private let loadingView: ShimmerLoadingView = {
        let view = ShimmerLoadingView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let bottomView: NovaWebViewBottomView = {
        let view = NovaWebViewBottomView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let webContext: NovaAdsLandingWebContext
    private let navigationModel: NovaWebViewNavigationViewModel?

    private var webView: WKWebView!

    private var loadingTimer: Timer?
    private var progressObservation: NSKeyValueObservation?
    private var smoothProgress: SmoothProgress!

    private var titleObservation: NSKeyValueObservation?

    private var backStatusObservation: NSKeyValueObservation?
    private var forwardStatusObservation: NSKeyValueObservation?

    private var status: NovaAdOpenLandingStatus = .inited
    private var playableAdActionHelper: NovaActionHelper<NovaActionState.Init>?

    init(webContext: NovaAdsLandingWebContext, navigationModel: NovaWebViewNavigationViewModel? = nil) {
        self.webContext = webContext
        self.navigationModel = navigationModel
        super.init(nibName: nil, bundle: nil)
        self.unifiedWebViewHost =
            NovaUnifiedWebViewBuilder
            .buildWebViewHost(
                enableNBUserAgent: false,
                enableJSBridge: false,
                navigationDelegate: self
            )
        self.webView = self.unifiedWebViewHost.webView()
        self.webView.scrollView.delegate = self
        self.progressObservation = self.webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, change in
            guard let progress = change.newValue else { return }

            self?.smoothProgress.receiveRealProgress(progress)
        }
        self.smoothProgress = SmoothProgress(delegate: self)
        self.titleObservation = self.webView.observe(\.title, options: [.new]) { [weak self] _, change in
            guard let title = change.newValue else { return }

            self?.naviView.setTitle(title)
        }

        backStatusObservation = webView.observe(\.canGoBack, options: [.new]) { [weak self] _, change in
            guard let canGoBack = change.newValue else { return }

            self?.bottomView.configButton(canGoBack: canGoBack)
        }

        forwardStatusObservation = webView.observe(\.canGoForward, options: [.new]) { [weak self] _, change in
            guard let canGoForward = change.newValue else { return }

            self?.bottomView.configButton(canGoForward: canGoForward)
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification,
            object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.webView.navigationDelegate = nil
        self.webView.stopLoading()
        self.progressObservation?.invalidate()
        self.titleObservation?.invalidate()
        self.backStatusObservation?.invalidate()
        self.forwardStatusObservation?.invalidate()
        self.loadingTimer?.invalidate()
        self.loadingTimer = nil
        self.smoothProgress.stopUpdatingProgress()
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(
            self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let naviViewModel =
            self.navigationModel
            ?? NovaWebViewNavigationViewModel(
                title: webContext.extraInfo.advertiser,
                leftButtonIcon: UIImage.Nova.crossOutline,
                leftButtonTapActionHandler: { [weak self] in
                    self?.navigationViewDidClickBackButton()
                },
                rightButtonIcon: nil,
                rightButtonTapActionHandler: { [weak self] in
                    self?.navigationViewDidClickBackButton()
                }
            )
        naviView.config(viewModel: naviViewModel)

        bottomView.delegate = self

        view.backgroundColor = UIColor(light: NovaColorPalettes.Gray.tint100, dark: NovaColorPalettes.Gray.tint700)

        self.view.addSubviews([naviView, webView, loadingView, progressView, bottomView])

        // Toolbar row + bottom divider in `NovaWebViewNavigationView`.
        let navToolbarHeight: CGFloat = 44 + 1
        NSLayoutConstraint.activate([
            naviView.topAnchor.constraint(equalTo: view.topAnchor),
            naviView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            naviView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        if let fixedBarHeight = navigationModel?.navigationBarHeight {
            naviView.heightAnchor.constraint(equalToConstant: CGFloat(fixedBarHeight)).isActive = true
        } else {
            // Safe area is applied by the system when ready; height = topInset + toolbar (no key-window guesswork).
            naviView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: navToolbarHeight
            ).isActive = true
        }

        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: naviView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: naviView.bottomAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        NSLayoutConstraint.activate([
            loadingView.topAnchor.constraint(equalTo: naviView.bottomAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        NSLayoutConstraint.activate([
            bottomView.topAnchor.constraint(equalTo: webView.bottomAnchor),
            bottomView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomView.heightAnchor.constraint(equalToConstant: 56),
        ])

        unifiedWebViewHost.load(webContext.url, referer: "https://www.newsbreak.com/")
        smoothProgress.startUpdatingProgress()
        NovaAdLandingWebLogHelper.logStart(webContext: webContext)
        status = .started
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        status = .closed
    }

    func changeLeftButtonOnNavigation(isHidden: Bool) {
        naviView.changeLeftButtonVisibility(isHidden: isHidden)
    }

    func changeWebViewTappable(isEnable: Bool) {
        webView.scrollView.isScrollEnabled = isEnable
    }

    func setWebView(offset: CGPoint) {
        webView.scrollView.contentOffset = offset
    }
    
    func logPageClose() {
        NovaAdLandingWebLogHelper.logClose(
            webContext: webContext,
            status: status,
            scrollDepth: unifiedWebViewHost.scrollDepth,
            pageIndex: unifiedWebViewHost.pageIndex
        )
    }
}

private extension NovaAdLandingWebContentViewController {
    func navigationViewDidClickBackButton() {
        logPageClose()
        dismiss(animated: true)
    }

    @objc func appWillResignActive() {
        NovaAdLandingWebLogHelper.logJumpOut(
            webContext: webContext,
            scrollDepth: unifiedWebViewHost.scrollDepth,
            pageIndex: unifiedWebViewHost.pageIndex
        )
    }

    @objc func appWillEnterForeground() {
        NovaAdLandingWebLogHelper.logJumpIn(
            webContext: webContext,
            scrollDepth: unifiedWebViewHost.scrollDepth,
            pageIndex: unifiedWebViewHost.pageIndex
        )
    }
    
    func didFailToLoad(errorMessage: String?) {
        let isForeground = UIApplication.shared.applicationState == .active && self.webView.onTop && self.webView.novaIsPartiallyVisibleOnScreen
        
        NovaAdLandingWebLogHelper.logError(webContext: webContext,
                                           isForeground: isForeground,
                                           errorMessage: errorMessage)
        
    }
    
}

extension NovaAdLandingWebContentViewController: NovaUnifiedWebViewNavigationDelegate {
    func openWebPage(_ url: URL) {
        // If playable ad jump to app store, replace url with fallback url to track conversion
        if case .playable(model: let model) = webContext.extraInfo.adCtrType {
            playableAdActionHelper = NovaActionHelper.build(
                with: .adInView(
                    model: AdActionModel(
                        tracingInfo: webContext.tracingInfo,
                        extraInfo: .init(),
                        ctrType: model.launchAdType
                    )
                )
            )
            .logNovaClickEvent(with: CACurrentMediaTime() - webContext.clickTime, in: .playable)
            .handleAdTap(in: nil)
        } else {
            self.smoothProgress.startUpdatingProgress()
            self.progressView.setProgress(0, animated: false)
            self.progressView.isHidden = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                self.unifiedWebViewHost.load(url)
            }
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {}

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        loadingTimer?.invalidate()
        loadingTimer = Timer.scheduledTimer(
            withTimeInterval: 0.1, repeats: true,
            block: { [weak self] _ in
                guard let self else { return }

                let progress = self.webView.estimatedProgress
                let contentHeight = self.webView.scrollView.contentSize.height
                if progress > 0.88 || contentHeight > self.webView.bounds.height {
                    self.smoothProgress.stopUpdatingProgress()
                    self.loadingTimer?.invalidate()
                    self.loadingTimer = nil
                    self.loadingView.isHidden = true
                    self.progressView.isHidden = true
                }
            })
    }

    func webView(_ webView: WKWebView, policyFor navigationAction: WKNavigationAction) -> WKNavigationActionPolicy? {
        nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NovaAdLandingWebLogHelper.logLoaded(
            webContext: webContext,
            success: true,
            pageIndex: unifiedWebViewHost.pageIndex
        )
        loadingTimer?.invalidate()
        loadingTimer = nil
        smoothProgress.stopUpdatingProgress()
        loadingView.isHidden = true
        progressView.isHidden = true
        status = .allLoaded
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        NovaAdLandingWebLogHelper.logLoaded(
            webContext: webContext,
            success: false,
            error: error,
            pageIndex: unifiedWebViewHost.pageIndex
        )
        loadingTimer?.invalidate()
        loadingTimer = nil
        smoothProgress.stopUpdatingProgress()
        loadingView.isHidden = true
        progressView.isHidden = true
        status = .allLoaded
        
        self.didFailToLoad(errorMessage: error.formattedMessage)
    }

    func webViewInitialLoadDidRedirect(_ webView: WKWebView) {
        self.initialLoadDidRedirectTo?(webView)
    }

    func webViewDidGoBackToInitialLoad(_ webView: WKWebView) {
        self.didGoBackToInitialLoad?(webView)
    }
    
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        self.didFailToLoad(errorMessage: "webview web content process did terminate")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        self.didFailToLoad(errorMessage: error.formattedMessage)
    }
}

// MARK: - SmmothProgressDelegate

extension NovaAdLandingWebContentViewController: SmoothProgressDelegate {
    func didUpdateProgress(_ progress: Double) {
        self.progressView.setProgress(Float(progress), animated: true)
    }
}

// MARK: - WebViewBottomViewDelegate

extension NovaAdLandingWebContentViewController: NovaWebViewBottomViewDelegate {
    func bottomViewDidTapBackButton() {
        guard webView.canGoBack else { return }

        webView.goBack()
    }

    func bottomViewDidTapForwardButton() {
        guard webView.canGoForward else { return }

        webView.goForward()
    }
}

// MARK: - UIScrollViewDelegate

extension NovaAdLandingWebContentViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        webViewDidScroll?(scrollView)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        webViewDidEndDragging?(scrollView, decelerate)
    }
}
