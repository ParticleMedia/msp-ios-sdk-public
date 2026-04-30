// MARK: - AdFormat

import MSPCore
import MSPSnapKit
import MSPiOSCore
import UIKit

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

// MARK: - AdTestViewController

final class AdTestViewController: UIViewController {
    // MARK: - Init

    init(format: AdFormat, placements: [String]? = nil) {
        self.viewModel = AdTestViewModel(format: format, placements: placements ?? [])
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - ViewModel

    private let viewModel: AdTestViewModel

    // MARK: - UI refs

    private weak var placementLabel: UILabel?
    private weak var testParamsCard: TestParamsCardView?
    private weak var statusLabel: UILabel?
    private weak var adContainerView: UIView?
    private weak var bottomBar: AdTestBottomBar?
    private weak var currentNativeAdView: NativeAdView?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.format.rawValue + " Ad"
        view.backgroundColor = .systemGroupedBackground
        setupBottomBar()
        setupScrollContent()
        bindViewModel()
        applyState(viewModel.state)
    }

    // MARK: - Binding

    private func bindViewModel() {
        viewModel.onStateChange = { [weak self] state in
            DispatchQueue.main.async { self?.applyState(state) }
        }
    }

    private func applyState(_ state: AdState) {
        let statusText = state.statusText
        statusLabel?.text = statusText
        statusLabel?.isHidden = statusText.isEmpty

        switch state {
        case .idle, .error:
            bottomBar?.configure(
                loadShowTitle: "Load Ad",
                loadShowEnabled: !viewModel.selectedPlacement.isEmpty,
                destroyEnabled: false
            )
        case .loading:
            bottomBar?.configure(loadShowTitle: "Load Ad", loadShowEnabled: false, destroyEnabled: false)
        case .loaded:
            bottomBar?.configure(loadShowTitle: "Show Ad", loadShowEnabled: true, destroyEnabled: true)
        case .showing:
            bottomBar?.configure(loadShowTitle: "Show Ad", loadShowEnabled: false, destroyEnabled: true)
        }
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

        contentStack.addArrangedSubview(buildPlacementButton())

        let card = TestParamsCardView(format: viewModel.format)
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
        let placement = viewModel.selectedPlacement
        label.text = placement.isEmpty ? "(no placements)" : placement
        label.font = .systemFont(ofSize: 17)
        label.textColor = .label
        label.numberOfLines = 0
        placementLabel = label

        let arrow = UIImageView(
            image: UIImage(
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

        if !viewModel.placements.isEmpty {
            let btn = UIButton(type: .custom)
            btn.addAction(
                UIAction { [weak self] _ in
                    self?.presentPlacementPicker()
                }, for: .touchUpInside)
            container.addSubview(btn)
            btn.snp.makeConstraints { make in make.edges.equalToSuperview() }
        }

        return container
    }

    // MARK: - Ad actions

    private func handleLoadShowTapped() {
        viewModel.state.isLoaded ? showAd() : loadAd()
    }

    private func loadAd() {
        guard let card = testParamsCard else { return }
        let params = TestParams(
            testAd: card.testAd,
            adNetwork: card.adNetwork,
            creativeType: card.creativeType,
            creativeLayout: card.creativeLayout,
            enableH5Format: card.enableH5Format,
            h5TemplateGroup: card.h5TemplateGroup,
            preload: card.preload
        )
        let htmlTestAdString = card.useHtmlTestAdString ? testHtmlAdString : nil
        viewModel.loadAd(
            bannerSize: card.bannerSize,
            novaSandbox: card.novaSandbox,
            params: params,
            htmlTestAdString: htmlTestAdString,
            adListener: self
        )
    }

    private func showAd() {
        guard let ad = viewModel.state.currentAd else { return }
        viewModel.handleAdShowing(ad: ad)

        if let bannerAd = ad as? BannerAd {
            let adView = bannerAd.adView
            adContainerView?.addSubview(adView)
            adView.snp.makeConstraints { make in
                make.top.centerX.equalToSuperview()
                make.width.equalTo(viewModel.loadedBannerSize.width)
                make.height.equalTo(viewModel.loadedBannerSize.height)
                make.bottom.equalToSuperview()
            }
        } else if let nativeAd = ad as? NativeAd {
            let container = DemoNativeAdContainer(frame: CGRect(x: 0, y: 0, width: 300, height: 250))
            let nativeView = NativeAdView(nativeAd: nativeAd, nativeAdContainer: container)
            currentNativeAdView = nativeView
            adContainerView?.addSubview(nativeView)
            nativeView.snp.makeConstraints { make in
                make.top.leading.trailing.bottom.equalToSuperview()
            }
        } else if let interstitialAd = ad as? InterstitialAd {
            interstitialAd.show(rootViewController: self, interstitialAdReportHandling: self)
        } else if let rewardedAd = ad as? RewardedAd {
            rewardedAd.show(rootViewController: self)
        }
    }

    private func destroyAd() {
        adContainerView?.subviews.forEach { $0.removeFromSuperview() }
        currentNativeAdView = nil
        let ad = viewModel.state.currentAd
        if case .loaded = viewModel.state {
            MSP.shared.notifyLoss(winnerBidderName: "dummy winner", winnerPrice: 1.0, ad: ad, requestId: nil)
        }
        viewModel.destroyAd()
    }

    // MARK: - Placement picker

    private func presentPlacementPicker() {
        let picker = PlacementPickerViewController(
            options: viewModel.placements,
            selected: viewModel.selectedPlacement
        ) { [weak self] placement in
            guard let self else { return }
            self.viewModel.selectPlacement(placement)
            self.placementLabel?.text = placement
        }
        present(UINavigationController(rootViewController: picker), animated: true)
    }
}

// MARK: - AdListener

extension AdTestViewController: AdListener {
    func getRootViewController() -> UIViewController? { self }

    func onAdLoaded(placementId: String, loadInfo: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.viewModel.handleAdLoaded(placementId: placementId)
        }
    }

    func onAdLoaded(ad: MSPAd) {
        DispatchQueue.main.async { [weak self] in
            self?.viewModel.handleAdLoaded(ad: ad)
        }
    }

    func onAdDismissed(ad: MSPAd) {
        DispatchQueue.main.async { [weak self] in self?.viewModel.handleAdDismissed() }
    }

    func onAdRewardReceived(ad: MSPAd) { print("[AdTest] Reward received") }
    func onAdClick(ad: MSPAd) { print("[AdTest] Ad clicked") }
    func onAdImpression(ad: MSPAd) { print("[AdTest] Ad impression") }

    func onError(msg: String, loadInfo: [String: Any]) {
        DispatchQueue.main.async { [weak self] in self?.viewModel.handleAdError(msg) }
    }

    func onError(msg: String) {
        DispatchQueue.main.async { [weak self] in self?.viewModel.handleAdError(msg) }
    }
}

extension AdTestViewController: InterstitialAdReportHandling {
    func startReportFlow(
        from presentingVC: UIViewController?,
        for ad: InterstitialAd,
        metadata: [String: Any]?
    ) {
        let presenter = presentingVC ?? self
        AdReportFlow.present(from: presenter) { reason in
            ad.sendReportAdEvent(reason: reason, description: nil)
        }
    }

    func canShowReportButton(for ad: InterstitialAd) -> Bool {
        return true
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
