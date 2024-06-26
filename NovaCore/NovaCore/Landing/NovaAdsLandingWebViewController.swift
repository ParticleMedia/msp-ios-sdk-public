import SafariServices
import WebKit
import UIKit
import Foundation

@objc public class NovaAdsLandingWebViewController: UIViewController {
    
    public var initialLoadDidRedirectTo: ((WKWebView) -> Void)?
    public var didGoBackToInitialLoad: ((WKWebView) -> Void)?
    public var webViewDidScroll: ((UIScrollView) -> Void)?
    public var webViewDidEndDragging: ((UIScrollView) -> Void)?

    private var unifiedWebViewHost: UnifiedWebViewHost!

    private let naviView: WebViewNavigationView = {
        let naviView = WebViewNavigationView()
        naviView.translatesAutoresizingMaskIntoConstraints = false
        return naviView
    }()

    private let progressView: UIProgressView = {
        let view = UIProgressView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.tintColor = UIColor(light: ColorPalettes.Blue.tint200, dark: ColorPalettes.Blue.tint400)
        return view
    }()

    private let loadingView: ShimmerLoadingView = {
        let view = ShimmerLoadingView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let bottomView: WebViewBottomView = {
        let view = WebViewBottomView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let model: NovaAdOpenActionDataModel
    private let navigationModel: WebViewNavigationViewModel?
    private let navigationHeight: CGFloat?

    private var webView: WKWebView!

    private var loadingTimer: Timer?
    private var progressObservation: NSKeyValueObservation?
    private var smoothProgress: SmoothProgress!

    private var titleObservation: NSKeyValueObservation?

    private var backStatusObservation: NSKeyValueObservation?
    private var forwardStatusObservation: NSKeyValueObservation?

    private var status: NovaAdOpenLandingStatus = .inited
    // NOTE: (shanyu.li) make the loaded logic be the same as safari. Only log with the initial page.
    // because there may be redirect logic, webview.url may not be the same as model.url, so a bool value is used.
    private var didLogFirstPage = false

    public init(
        dataModel: NovaAdOpenActionDataModel,
        navigationModel: WebViewNavigationViewModel? = nil,
        navigationHeight: CGFloat? = nil
    ) {
        self.model = dataModel
        self.navigationModel = navigationModel
        self.navigationHeight = navigationHeight
        super.init(nibName: nil, bundle: nil)
        self.unifiedWebViewHost = UnifiedWebViewBuilder.buildWebViewHost(enableNBUserAgent: false,
                                                                         enableJSBridge: false,
                                                                         navigationDelegate: self)
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
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
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        let naviViewModel = self.navigationModel ?? WebViewNavigationViewModel(
            title: nil,
            leftButtonIcon: .crossOutline,
            leftButtonTapActionHandler: { [weak self] in
                self?.navigationViewDidClickBackButton()
            },
            rightButtonIcon: nil,
            rightButtonTapActionHandler: { [weak self] in
                self?.navigationViewDidClickBackButton()
            })
        naviView.config(viewModel: naviViewModel)

        bottomView.delegate = self

        view.backgroundColor = UIColor(light: ColorPalettes.Gray.tint100, dark: ColorPalettes.Gray.tint700)

        self.view.addSubviews([naviView, webView, loadingView, progressView, bottomView])

        let statusBarHeight = self.navigationHeight ?? (NovaAdsLandingWebViewController.nb_isiPhoneX ? (88 + 1) : (64 + 1))
        NSLayoutConstraint.activate([
            naviView.topAnchor.constraint(equalTo: view.topAnchor),
            naviView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            naviView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            naviView.heightAnchor.constraint(equalToConstant: statusBarHeight)
        ])

        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: naviView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.topAnchor, constant: statusBarHeight),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        NSLayoutConstraint.activate([
            loadingView.topAnchor.constraint(equalTo: view.topAnchor, constant: statusBarHeight),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        NSLayoutConstraint.activate([
            bottomView.topAnchor.constraint(equalTo: webView.bottomAnchor),
            bottomView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomView.heightAnchor.constraint(equalToConstant: 56)
        ])

        unifiedWebViewHost.load(model.url, referer: "https://www.newsbreak.com/")
        smoothProgress.startUpdatingProgress()
        //NovaAdOpenLandingLogger.logStart(adId: model.adId,
        //                                 requestId: model.requestId,
        //                                 adUnitId: model.adUnitId,
        //                                 startTime: model.clickTime,
        //                                 webType: .unified)
        status = .started
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        //NovaAdOpenLandingLogger.logClose(adId: model.adId,
        //                                 requestId: model.requestId,
        //                                 adUnitId: model.adUnitId,
        //                                 startTime: model.clickTime,
        //                                 status: status,
        //                                 webType: .unified)
        status = .closed
    }
    
    public func changeLeftButtonOnNavigation(isHidden: Bool) {
        naviView.changeLeftButtonVisibility(isHidden: isHidden)
    }
    
    public func changeWebViewTappable(isEnable: Bool) {
        webView.scrollView.isScrollEnabled = isEnable
    }
    
    public func setWebView(offset: CGPoint) {
        webView.scrollView.contentOffset = offset
    }
    
    static var nb_isiPhoneX: Bool {
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            return false
        }

        let safeAreaInsets: UIEdgeInsets = UIApplication.shared.windows.first?.safeAreaInsets ?? .zero
        return safeAreaInsets.top > 20
    }
}

private extension NovaAdsLandingWebViewController {
    func navigationViewDidClickBackButton() {
        dismiss(animated: true)
    }
    
    @objc func appWillResignActive() {
        /*
        NovaAdOpenLandingLogger.logJumpOut(
            adId: model.adId,
            requestId: model.requestId,
            adUnitId: model.adUnitId,
            startTime: model.clickTime,
            scrollDepth: unifiedWebViewHost.scrollDepth,
            pageIndex: unifiedWebViewHost.pageIndex, webType: .unified)
         */
    }
    
    @objc func appWillEnterForeground() {
        /*
        NovaAdOpenLandingLogger.logJumpIn(
            adId: model.adId,
            requestId: model.requestId,
            adUnitId: model.adUnitId,
            startTime: model.clickTime,
            scrollDepth: unifiedWebViewHost.scrollDepth,
            pageIndex: unifiedWebViewHost.pageIndex, webType: .unified)
         */
    }
}

extension NovaAdsLandingWebViewController: UnifiedWebViewNavigationDelegate {
    public func openWebPage(_ url: URL) {
        self.smoothProgress.startUpdatingProgress()
        self.progressView.setProgress(0, animated: false)
        self.progressView.isHidden = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            self.unifiedWebViewHost.load(url)
        }
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {}
    
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        loadingTimer?.invalidate()
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { [weak self] _ in
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

    public func webView(_ webView: WKWebView, policyFor navigationAction: WKNavigationAction) -> WKNavigationActionPolicy? {
        return nil
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if !didLogFirstPage {
            /*
            NovaAdOpenLandingLogger.logLoaded(adId: model.adId,
                                              requestId: model.requestId,
                                              adUnitId: model.adUnitId,
                                              startTime: model.clickTime,
                                              success: true,
                                              error: nil,
                                              webType: .unified)
             */
            didLogFirstPage = true
        }
        loadingTimer?.invalidate()
        loadingTimer = nil
        smoothProgress.stopUpdatingProgress()
        loadingView.isHidden = true
        progressView.isHidden = true
        status = .allLoaded
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if !didLogFirstPage {
            /*
            NovaAdOpenLandingLogger.logLoaded(adId: model.adId,
                                              requestId: model.requestId,
                                              adUnitId: model.adUnitId,
                                              startTime: model.clickTime,
                                              success: false,
                                              error: error,
                                              webType: .unified)
             */
            didLogFirstPage = true
        }
        loadingTimer?.invalidate()
        loadingTimer = nil
        smoothProgress.stopUpdatingProgress()
        loadingView.isHidden = true
        progressView.isHidden = true
        status = .allLoaded
    }
    
    public func webViewInitialLoadDidRedirect(_ webView: WKWebView){
        self.initialLoadDidRedirectTo?(webView);
    }
    
    public func webViewDidGoBackToInitialLoad(_ webView: WKWebView) {
        self.didGoBackToInitialLoad?(webView);
    }
}

// MARK: - SmmothProgressDelegate

extension NovaAdsLandingWebViewController: SmoothProgressDelegate {

    func didUpdateProgress(_ progress: Double) {
        self.progressView.setProgress(Float(progress), animated: true)
    }

}

// MARK: - WebViewBottomViewDelegate

extension NovaAdsLandingWebViewController: WebViewBottomViewDelegate {
    public func bottomViewDidTapBackButton() {
        guard webView.canGoBack else { return }

        webView.goBack()
    }

    public func bottomViewDidTapForwardButton() {
        guard webView.canGoForward else { return }

        webView.goForward()
    }
}

// MARK: - UIScrollViewDelegate

extension NovaAdsLandingWebViewController: UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        webViewDidScroll?(scrollView)
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        webViewDidEndDragging?(scrollView)
    }
}
