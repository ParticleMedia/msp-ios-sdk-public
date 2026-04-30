import MSPSnapKit
import UIKit
import WebKit

final class WebBrowserViewController: UIViewController {

    // MARK: - Properties

    private let initialURL: URL
    private var progressObservation: NSKeyValueObservation?
    private var webView: WKWebView!
    private var scriptMessageHandlerProxy: WeakScriptMessageHandler?

    // MARK: - UI

    private let progressBar: UIProgressView = {
        let bar = UIProgressView(progressViewStyle: .bar)
        bar.trackTintColor = .clear
        bar.progressTintColor = .systemBlue
        return bar
    }()

    private lazy var closeButton: UIButton = makeOverlayButton(systemName: "xmark", action: #selector(closeTapped))
    private lazy var reloadButton: UIButton = makeOverlayButton(systemName: "arrow.clockwise", action: #selector(reload))

    // MARK: - Init

    init(url: URL) {
        self.initialURL = url
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupWebView()
        setupProgressBar()
        webView.load(URLRequest(url: initialURL))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    deinit {
        progressObservation?.invalidate()
        for name in JSMessage.allCases {
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: name.rawValue)
        }
    }

    // MARK: - Setup

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.requiresUserActionForMediaPlayback = false

        let userController = WKUserContentController()
        config.userContentController = userController
        userController.addUserScript(novaNativeBridgeScript())

        let proxy = WeakScriptMessageHandler(handler: self)
        scriptMessageHandlerProxy = proxy
        for name in JSMessage.allCases {
            userController.add(proxy, name: name.rawValue)
        }

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(webView)
        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupProgressBar() {
        view.addSubview(progressBar)
        progressBar.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(2)
        }
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            guard let self else { return }
            let progress = Float(webView.estimatedProgress)
            self.progressBar.setProgress(progress, animated: true)
            self.progressBar.isHidden = progress >= 1.0
        }
    }

    private func setupOverlayButtons() {
        view.addSubview(closeButton)
        view.addSubview(reloadButton)
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            make.leading.equalToSuperview().offset(16)
            make.size.equalTo(32)
        }
        reloadButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            make.trailing.equalToSuperview().offset(-16)
            make.size.equalTo(32)
        }
    }

    // MARK: - Helpers

    private func makeOverlayButton(systemName: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: systemName)
        config.baseForegroundColor = .white
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        button.configuration = config
        button.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        button.layer.cornerRadius = 16
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func novaNativeBridgeScript() -> WKUserScript {
        let js = """
            window.novaNativeBridge = {
                supports: function(feature) {
                    switch (feature) {
                        case 'feedback': return true;
                        default: return false;
                    }
                },
                startFeedback: function() {
                    window.webkit.messageHandlers.novaNativeBridge.postMessage({ action: 'startFeedback' });
                },
                open: function(payload) {
                    window.webkit.messageHandlers.novaNativeBridge.postMessage({
                        action: 'open',
                        payload: payload || '{}'
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
        return WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func reload() {
        webView.reload()
    }
}

// MARK: - WKScriptMessageHandler

extension WebBrowserViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch JSMessage(rawValue: message.name) {
        case .adClose:
            navigationController?.popViewController(animated: true)
        case .adReport:
            showReportFlow()
        case .novaNativeBridge:
            handleNativeBridge(message.body)
        case .none:
            break
        }
    }

    private func handleNativeBridge(_ body: Any) {
        guard let dict = body as? [String: Any], let action = dict["action"] as? String else { return }
        switch action {
        case "startFeedback":
            showReportFlow()
        case "open":
            handleOpen(payload: dict["payload"] as? String)
        default:
            break
        }
    }

    private func handleOpen(payload: String?) {
        guard let payload,
              let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let urlString = json["url"] as? String,
              let url = URL(string: urlString)
        else { return }
        UIApplication.shared.open(url)
    }

    private func showReportFlow() {
        AdReportFlow.present(from: self) { reason in
            print("[WebDebugger] Report submitted: \(reason)")
        }
    }
}

// MARK: - WKNavigationDelegate

extension WebBrowserViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        progressBar.isHidden = false
        progressBar.setProgress(0.05, animated: false)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressBar.isHidden = true
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        progressBar.isHidden = true
    }
}

// MARK: - JS Message Names

private enum JSMessage: String, CaseIterable {
    case novaNativeBridge
    case adClose
    case adReport
}

// MARK: - WeakScriptMessageHandler (retain-cycle guard)

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var handler: WKScriptMessageHandler?

    init(handler: WKScriptMessageHandler) {
        self.handler = handler
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        handler?.userContentController(userContentController, didReceive: message)
    }
}
