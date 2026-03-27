import MSPCore
import MSPiOSCore
import MSPSnapKit
import UIKit

// MARK: - AdFormat

enum AdFormat: String {
    case banner = "Banner"
    case native = "Native"
    case interstitial = "Interstitial"
    case rewarded = "Rewarded"

    var mspFormat: MSPiOSCore.AdFormat {
        switch self {
        case .banner: return .banner
        case .native: return .native
        case .interstitial: return .interstitial
        case .rewarded: return .rewarded
        }
    }
}

// MARK: - AdState

private enum AdState {
    case idle
    case loading
    case loaded(MSPAd)
    case showing(MSPAd)
    case error(String)

    var statusText: String {
        switch self {
        case .idle: return ""
        case .loading: return "Loading ad..."
        case .loaded(let ad):
            let network = (ad.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] as? String) ?? "unknown"
            return "Ad loaded: \(network)"
        case .showing(let ad):
            let network = (ad.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] as? String) ?? "unknown"
            return "Ad showing: \(network)"
        case .error(let msg):
            return "Error: \(msg)"
        }
    }

    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }
}

// MARK: - AdTestViewController

class AdTestViewController: UIViewController {

    // MARK: - Init

    init(format: AdFormat, placements: [String]? = nil) {
        self.format = format
        let list = placements ?? []
        self.placements = list
        self.selectedPlacement = list.first ?? ""
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Config

    private let format: AdFormat
    private let placements: [String]

    // MARK: - State

    private var state: AdState = .idle {
        didSet { updateUI() }
    }

    private var selectedPlacement: String
    private var adLoader: MSPAdLoader?
    private weak var currentNativeAdView: NativeAdView?

    // MARK: - UI refs

    private weak var placementLabel: UILabel?
    private weak var testParamsCard: TestParamsCardView?
    private weak var statusLabel: UILabel?
    private weak var adContainerView: UIView?
    private weak var bottomBar: AdTestBottomBar?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = format.rawValue + " Ad"
        view.backgroundColor = .systemGroupedBackground
        setupBottomBar()
        setupScrollContent()
        updateUI()
    }

    // MARK: - Layout

    private func setupBottomBar() {
        let bar = AdTestBottomBar()
        bar.onLoadShow = { [weak self] in self?.handleLoadShowTapped() }
        bar.onDestroy = { [weak self] in self?.destroyAd() }
        view.addSubview(bar)
        bottomBar = bar

        bar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(72)
        }
    }

    private func setupScrollContent() {
        guard let bottomBar else { return }
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 16
        scrollView.addSubview(contentStack)

        scrollView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
        }
        contentStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-16)
            make.width.equalTo(scrollView).offset(-32)
        }

        let sectionLabel = UILabel()
        sectionLabel.text = "Placement"
        sectionLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        sectionLabel.textColor = .secondaryLabel
        contentStack.addArrangedSubview(sectionLabel)

        let placementBtn = buildPlacementButton()
        contentStack.addArrangedSubview(placementBtn)

        let card = TestParamsCardView(format: format)
        testParamsCard = card
        contentStack.addArrangedSubview(card)

        let status = UILabel()
        status.font = .systemFont(ofSize: 13)
        status.textColor = .secondaryLabel
        status.numberOfLines = 0
        status.isHidden = true
        statusLabel = status
        contentStack.addArrangedSubview(status)

        let adContainer = UIView()
        adContainerView = adContainer
        contentStack.addArrangedSubview(adContainer)
    }

    private func buildPlacementButton() -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemGroupedBackground
        container.layer.cornerRadius = 10

        let label = UILabel()
        label.text = selectedPlacement.isEmpty ? "(no placements)" : selectedPlacement
        label.font = .systemFont(ofSize: 17)
        label.textColor = .label
        label.numberOfLines = 0
        placementLabel = label

        let arrow = UIImageView(image: UIImage(
            systemName: "arrowtriangle.down.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 9)
        ))
        arrow.tintColor = .label
        arrow.setContentHuggingPriority(.required, for: .horizontal)
        arrow.setContentCompressionResistancePriority(.required, for: .horizontal)

        container.addSubview(label)
        container.addSubview(arrow)
        label.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalToSuperview().offset(12)
            make.bottom.equalToSuperview().offset(-12)
            make.trailing.equalTo(arrow.snp.leading).offset(-8)
        }
        arrow.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-12)
        }

        if !placements.isEmpty {
            let btn = UIButton(type: .custom)
            btn.addAction(UIAction { [weak self] _ in
                self?.presentPlacementPicker()
            }, for: .touchUpInside)
            container.addSubview(btn)
            btn.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }

        return container
    }

    private func presentPlacementPicker() {
        let picker = PlacementPickerViewController(
            options: placements,
            selected: selectedPlacement
        ) { [weak self] placement in
            guard let self else { return }
            self.selectedPlacement = placement
            self.placementLabel?.text = placement
            self.updateUI()
        }
        present(UINavigationController(rootViewController: picker), animated: true)
    }

    // MARK: - State updates

    private func updateUI() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let statusText = self.state.statusText
            self.statusLabel?.text = statusText
            self.statusLabel?.isHidden = statusText.isEmpty

            switch self.state {
            case .idle, .error:
                self.bottomBar?.configure(loadShowTitle: "Load Ad", loadShowEnabled: !self.selectedPlacement.isEmpty, destroyEnabled: false)
            case .loading:
                self.bottomBar?.configure(loadShowTitle: "Load Ad", loadShowEnabled: false, destroyEnabled: false)
            case .loaded:
                self.bottomBar?.configure(loadShowTitle: "Show Ad", loadShowEnabled: true, destroyEnabled: true)
            case .showing:
                self.bottomBar?.configure(loadShowTitle: "Show Ad", loadShowEnabled: false, destroyEnabled: true)
            }
        }
    }

    // MARK: - Ad actions

    private func handleLoadShowTapped() {
        state.isLoaded ? showAd() : loadAd()
    }

    private func loadAd() {
        state = .loading
        guard let card = testParamsCard else { return }

        let params = TestParams(
            testAd: card.testAd,
            adNetwork: card.adNetwork,
            creativeType: card.creativeType,
            creativeLayout: card.creativeLayout,
            enableH5Format: card.enableH5Format,
            h5TemplateGroup: card.h5TemplateGroup
        )
        let customParams: [String: Any] = [
            MSPConstants.GOOGLE_AD_MULTI_CONTENT_URLS: ["https://www.google.com", "https://newsbreak.com"],
            MSPConstants.USE_NOVA_SANDBOX: card.novaSandbox ? "true" : "false",
        ]
        let loader = MSPAdLoader()
        adLoader = loader

        let adRequest = AdRequest(
            customParams: customParams,
            geo: nil,
            context: nil,
            adaptiveBannerSize: AdSize(width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: false),
            adSize: AdSize(width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: false),
            placementId: selectedPlacement,
            adFormat: format.mspFormat,
            testParams: params.toDictionary()
        )
        loader.loadAd(placementId: selectedPlacement, adListener: self, adRequest: adRequest)
    }

    private func showAd() {
        guard case .loaded(let ad) = state else { return }
        state = .showing(ad)

        if let bannerAd = ad as? BannerAd {
            let adView = bannerAd.adView
            adContainerView?.addSubview(adView)
            adView.snp.makeConstraints { make in
                make.top.centerX.equalToSuperview()
                make.width.equalTo(320)
                make.height.equalTo(50)
                make.bottom.equalToSuperview()
            }
        } else if let nativeAd = ad as? NativeAd {
            let container = DemoNativeAdContainer(frame: CGRect(x: 0, y: 0, width: 300, height: 250))
            let nativeView = NativeAdView(nativeAd: nativeAd, nativeAdContainer: container)
            currentNativeAdView = nativeView
            adContainerView?.addSubview(nativeView)
            nativeView.snp.makeConstraints { make in
                make.top.leading.trailing.equalToSuperview()
                make.bottom.equalToSuperview()
            }
        } else if let interstitialAd = ad as? InterstitialAd {
            interstitialAd.show()
        } else if let rewardedAd = ad as? RewardedAd {
            rewardedAd.show(rootViewController: self)
        }
    }

    private func destroyAd() {
        adLoader = nil
        adContainerView?.subviews.forEach { $0.removeFromSuperview() }
        currentNativeAdView = nil
        state = .idle
    }
}

// MARK: - AdListener

extension AdTestViewController: AdListener {
    func getRootViewController() -> UIViewController? { self }

    func onAdLoaded(placementId: String, loadInfo: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let ad = self.adLoader?.getAd(placementId: placementId) else {
                self.state = .error("getAd returned nil for \(placementId)")
                return
            }
            self.state = .loaded(ad)
        }
    }

    func onAdLoaded(ad: MSPAd) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if case .loading = self.state { self.state = .loaded(ad) }
        }
    }

    func onAdDismissed(ad: MSPAd) {
        DispatchQueue.main.async { [weak self] in self?.state = .idle }
    }

    func onAdRewardReceived(ad: MSPAd) { print("[AdTest] Reward received") }
    func onAdClick(ad: MSPAd) { print("[AdTest] Ad clicked") }
    func onAdImpression(ad: MSPAd) { print("[AdTest] Ad impression") }
    func onError(msg: String, loadInfo: [String: Any]) {
        DispatchQueue.main.async { [weak self] in self?.state = .error(msg) }
    }
    func onError(msg: String) {
        DispatchQueue.main.async { [weak self] in self?.state = .error(msg) }
    }
}

// MARK: - PlacementPickerViewController

private final class PlacementPickerViewController: UITableViewController {

    private let options: [String]
    private let selected: String
    private let onSelect: (String) -> Void

    init(options: [String], selected: String, onSelect: @escaping (String) -> Void) {
        self.options = options
        self.selected = selected
        self.onSelect = onSelect
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Select Placement"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        options.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let option = options[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = option
        content.textProperties.numberOfLines = 0
        cell.contentConfiguration = content
        cell.accessoryType = option == selected ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelect(options[indexPath.row])
        dismiss(animated: true)
    }
}
