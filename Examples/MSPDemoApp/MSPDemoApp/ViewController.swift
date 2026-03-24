import AppTrackingTransparency
import MSPCore
import MSPSnapKit
import MSPiOSCore
import UIKit

class ViewController: UIViewController {
    @IBOutlet var appBannerView: UIView!
    weak var adLoader: MSPAdLoader?
    public var nativeAdView: NativeAdView?
    public var isCtaShown = false

    private let buttonSpacing: CGFloat = 6
    private let horizontalPadding: CGFloat = 24
    private let topPadding: CGFloat = 24
    private let bottomPadding: CGFloat = 24

    private weak var demoScrollView: UIScrollView?
    private var useNovaSandbox = false
    private var enableH5Format = true
    private var h5TemplateGroup: String?
    private var h5TemplateGroupChips: [String: UIButton] = [:]
    private var isCustomParamsExpanded = false
    private weak var customParamsButton: UIButton?
    private weak var customParamsContainer: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.indicatorStyle = .black
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        demoScrollView = scrollView

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = buttonSpacing
        contentStack.alignment = .fill
        contentStack.distribution = .equalSpacing
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        let button1 = makeButton(title: "Prebid Banner View") { [weak self] in
            self?.openDemoAdPage(adType: .prebidBanner)
        }

        let button2 = makeButton(title: "Google Banner View")
        let googleBannerMenuItems = [
            UIAction(title: "s2s", handler: { [weak self] _ in self?.openDemoAdPage(adType: .googleBanner) }),
            UIAction(title: "c2s", handler: { [weak self] _ in self?.openDemoAdPage(adType: .googleBannerC2S) }),
        ]
        button2.menu = UIMenu(title: "Choose an option", children: googleBannerMenuItems)
        button2.showsMenuAsPrimaryAction = true

        let button3 = makeButton(title: "Google Native View")
        let googleNativeMenuItems = [
            UIAction(title: "s2s", handler: { [weak self] _ in self?.openDemoAdPage(adType: .googleNative) }),
            UIAction(title: "c2s", handler: { [weak self] _ in self?.openDemoAdPage(adType: .googleNativeC2S) }),
        ]
        button3.menu = UIMenu(title: "Choose an option", children: googleNativeMenuItems)
        button3.showsMenuAsPrimaryAction = true

        let button4 = makeButton(title: "Nova Native View") { [weak self] in
            self?.openDemoAdPage(adType: .novaNative)
        }

        let button5 = makeButton(title: "Google Interstitial View")
        let googleInterstitialMenuItems = [
            UIAction(title: "s2s", handler: { [weak self] _ in self?.openDemoAdPage(adType: .googleInterstitial) }),
            UIAction(title: "c2s", handler: { [weak self] _ in self?.openDemoAdPage(adType: .googleInterstitialC2S) }),
        ]
        button5.menu = UIMenu(title: "Choose an option", children: googleInterstitialMenuItems)
        button5.showsMenuAsPrimaryAction = true

        let button6 = makeButton(title: "Nova Interstitial View")
        let novaInterstitialMenuItems = [
            UIAction(
                title: "Horizontal Image",
                handler: { [weak self] _ in self?.openDemoAdPage(adType: .novaInterstitialHorizontalImage) }),
            UIAction(
                title: "Vertical Image",
                handler: { [weak self] _ in self?.openDemoAdPage(adType: .novaInterstitialVerticalImage) }),
            UIAction(
                title: "Horizontal Video",
                handler: { [weak self] _ in self?.openDemoAdPage(adType: .novaInterstitialHorizontalVideo) }),
            UIAction(
                title: "Vertical Video",
                handler: { [weak self] _ in self?.openDemoAdPage(adType: .novaInterstitialVerticalVideo) }),
            UIAction(
                title: "High Engagement",
                handler: { [weak self] _ in self?.openDemoAdPage(adType: .novaInterstitialHighEngagement) }),
            UIAction(
                title: "End Card 2 Parts",
                handler: { [weak self] _ in self?.openDemoAdPage(adType: .novaInterstitialEndCard) }),
        ]
        button6.menu = UIMenu(title: "Choose an option", children: novaInterstitialMenuItems)
        button6.showsMenuAsPrimaryAction = true

        let button7 = makeButton(title: "Facebook Native View") { [weak self] in
            self?.openDemoAdPage(adType: .facebookNative)
        }

        let button8 = makeButton(title: "Facebook Interstitial View") { [weak self] in
            self?.openDemoAdPage(adType: .facebookInterstitial)
        }

        let button9 = makeButton(title: "C2S Bidders Banner View")
        let bannerMenuItems = [
            UIAction(title: "Unity", handler: { [weak self] _ in self?.openDemoAdPage(adType: .unityBanner) }),
            UIAction(title: "Pubmatic", handler: { [weak self] _ in self?.openDemoAdPage(adType: .pubmaticBanner) }),
            UIAction(title: "Inmobi", handler: { [weak self] _ in self?.openDemoAdPage(adType: .inmobiBanner) }),
            UIAction(
                title: "Mobilefuse", handler: { [weak self] _ in self?.openDemoAdPage(adType: .mobilefuseBanner) }),
            UIAction(title: "Mintegral", handler: { [weak self] _ in self?.openDemoAdPage(adType: .mintegralBanner) }),
        ]
        button9.menu = UIMenu(title: "Choose an option", children: bannerMenuItems)
        button9.showsMenuAsPrimaryAction = true

        let button10 = makeButton(title: "C2S Bidders Interstitial View")
        let interstitialMenuItems = [
            UIAction(title: "Unity", handler: { [weak self] _ in self?.openDemoAdPage(adType: .unityInterstitial) }),
            UIAction(
                title: "Pubmatic", handler: { [weak self] _ in self?.openDemoAdPage(adType: .pubmaticInterstitial) }),
            UIAction(title: "Inmobi", handler: { [weak self] _ in self?.openDemoAdPage(adType: .inmobiInterstitial) }),
            UIAction(
                title: "Mobilefuse", handler: { [weak self] _ in self?.openDemoAdPage(adType: .mobilefuseInterstitial) }
            ),
            UIAction(
                title: "Mintegral", handler: { [weak self] _ in self?.openDemoAdPage(adType: .mintegralInterstitial) }),
        ]
        button10.menu = UIMenu(title: "Choose an option", children: interstitialMenuItems)
        button10.showsMenuAsPrimaryAction = true

        let button11 = makeButton(title: "C2S Bidders Native View")
        let nativeMenuItems = [
            UIAction(title: "Unity", handler: { [weak self] _ in self?.openDemoAdPage(adType: .unityNative) }),
            UIAction(title: "Pubmatic", handler: { [weak self] _ in self?.openDemoAdPage(adType: .pubmaticNative) }),
            UIAction(title: "Inmobi", handler: { [weak self] _ in self?.openDemoAdPage(adType: .inmobiNative) }),
            UIAction(
                title: "Mobilefuse", handler: { [weak self] _ in self?.openDemoAdPage(adType: .mobilefuseNative) }),
            UIAction(title: "Mintegral", handler: { [weak self] _ in self?.openDemoAdPage(adType: .mintegralNative) }),
        ]
        button11.menu = UIMenu(title: "Choose an option", children: nativeMenuItems)
        button11.showsMenuAsPrimaryAction = true

        let button12 = makeButton(title: "Client Bidding Banner") { [weak self] in
            self?.openDemoAdPage(adType: .clientBiddingBanner)
        }

        let button13 = makeButton(title: "Prebid Interstitial") { [weak self] in
            self?.openDemoAdPage(adType: .prebidInterstitial)
        }

        let rewardedButton = makeButton(title: "Rewarded Ad")
        let rewardedMenuItems = [
            UIAction(title: "Google", handler: { [weak self] _ in self?.openDemoAdPage(adType: .googleRewarded) }),
            UIAction(title: "Facebook", handler: { [weak self] _ in self?.openDemoAdPage(adType: .facebookRewarded) }),
        ]
        rewardedButton.menu = UIMenu(title: "Choose network", children: rewardedMenuItems)
        rewardedButton.showsMenuAsPrimaryAction = true

        let adListButton = UIButton(type: .system)
        adListButton.setTitle("Ad List (Reuse Test)", for: .normal)
        adListButton.backgroundColor = .systemPurple
        adListButton.setTitleColor(.white, for: .normal)
        adListButton.layer.cornerRadius = 8
        adListButton.addAction(
            UIAction { [weak self] _ in
                let vc = DemoAdListViewController()
                self?.navigationController?.pushViewController(vc, animated: true)
            }, for: .touchUpInside)
        adListButton.snp.makeConstraints { make in make.height.equalTo(50) }

        let debugButton = UIButton(type: .system)
        debugButton.setTitle("Debug Ad Load", for: .normal)
        debugButton.backgroundColor = .systemOrange
        debugButton.setTitleColor(.white, for: .normal)
        debugButton.layer.cornerRadius = 8
        debugButton.addAction(UIAction { _ in MSP.shared.showMediationDebugger() }, for: .touchUpInside)
        debugButton.snp.makeConstraints { make in make.height.equalTo(50) }

        let standardButtons: [UIButton] = [
            button1, button2, button3, button4, button5, button6, button7, button8,
            button9, button10, button11, button12, button13, rewardedButton,
        ]
        standardButtons.forEach { contentStack.addArrangedSubview($0) }
        contentStack.addArrangedSubview(adListButton)

        setupCustomParamsSection(in: contentStack)

        contentStack.addArrangedSubview(debugButton)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        contentStack.snp.makeConstraints { make in
            make.top.equalTo(scrollView.contentLayoutGuide.snp.top).offset(topPadding)
            make.leading.equalTo(scrollView.contentLayoutGuide.snp.leading).offset(horizontalPadding)
            make.trailing.equalTo(scrollView.contentLayoutGuide.snp.trailing).offset(-horizontalPadding)
            make.bottom.equalTo(scrollView.contentLayoutGuide.snp.bottom).offset(-bottomPadding)
            make.width.equalTo(scrollView.frameLayoutGuide.snp.width).offset(-2 * horizontalPadding)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        demoScrollView?.flashScrollIndicators()
    }

    private func setupCustomParamsSection(in contentStack: UIStackView) {
        let button = UIButton(type: .system)
        button.setTitle("Custom Params  ▶", for: .normal)
        button.backgroundColor = .systemTeal
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.addAction(UIAction { [weak self] _ in self?.toggleCustomParams() }, for: .touchUpInside)
        button.snp.makeConstraints { make in make.height.equalTo(50) }
        customParamsButton = button
        contentStack.addArrangedSubview(button)

        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 8
        container.isHidden = true

        let sandboxLabel = UILabel()
        sandboxLabel.text = "Nova Sandbox"
        let sandboxToggle = UISwitch()
        sandboxToggle.isOn = useNovaSandbox
        sandboxToggle.addTarget(self, action: #selector(novaSandboxToggleChanged(_:)), for: .valueChanged)
        container.addSubview(sandboxLabel)
        container.addSubview(sandboxToggle)

        let h5Label = UILabel()
        h5Label.text = "Enable H5 Format"
        let h5Toggle = UISwitch()
        h5Toggle.isOn = enableH5Format
        h5Toggle.addTarget(self, action: #selector(enableH5FormatToggleChanged(_:)), for: .valueChanged)
        container.addSubview(h5Label)
        container.addSubview(h5Toggle)

        sandboxLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview()
            make.height.equalTo(50)
        }
        sandboxToggle.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalTo(sandboxLabel)
        }
        h5Label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(50)
            make.height.equalTo(50)
        }
        h5Toggle.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalTo(h5Label)
        }

        let groupLabel = UILabel()
        groupLabel.text = "H5 Template Group"
        let chipStack = UIStackView()
        chipStack.axis = .horizontal
        chipStack.spacing = 8
        chipStack.alignment = .center
        for value in ["t1", "t2g1", "t2g2", "t2g3"] {
            let chip = makeChipButton(title: value, value: value)
            chipStack.addArrangedSubview(chip)
            h5TemplateGroupChips[value] = chip
        }
        container.addSubview(groupLabel)
        container.addSubview(chipStack)

        groupLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(100)
        }
        chipStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalTo(groupLabel.snp.bottom).offset(8)
            make.bottom.equalToSuperview().inset(12)
        }

        customParamsContainer = container
        contentStack.addArrangedSubview(container)
    }

    private func makeButton(title: String, action: (() -> Void)? = nil) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.textAlignment = .center
        if let action = action {
            button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        }
        button.snp.makeConstraints { make in
            make.height.equalTo(50)
        }
        return button
    }

    func openDemoAdPage(adType: AdType) {
        let demoAdVC = DemoAdViewController(
            adType: adType,
            customParams: buildCustomParams(),
            testParams: buildTestParams(for: adType)
        )
        navigationController?.pushViewController(demoAdVC, animated: true)
    }

    private func buildCustomParams() -> [String: Any] {
        [MSPConstants.USE_NOVA_SANDBOX: useNovaSandbox ? "true" : "false"]
    }

    private func buildTestParams(for adType: AdType) -> TestParams {
        TestParams(
            testAd: getTestAd(for: adType),
            adNetwork: getAdNetwork(for: adType),
            creativeType: getCreativeType(for: adType),
            creativeLayout: getCreativeLayout(for: adType),
            enableH5Format: enableH5Format,
            h5TemplateGroup: h5TemplateGroup
        )
    }

    private func getTestAd(for adType: AdType) -> Bool {
        switch adType {
        case .prebidBanner, .prebidInterstitial,
            .googleBanner, .googleNative, .googleInterstitial,
            .facebookNative, .facebookInterstitial,
            .novaNative, .novaInterstitialHorizontalImage, .novaInterstitialVerticalImage,
            .novaInterstitialHorizontalVideo, .novaInterstitialVerticalVideo,
            .novaInterstitialHighEngagement, .novaInterstitialEndCard,
            .googleRewarded, .facebookRewarded:
            return true
        default:
            return false
        }
    }

    private func getAdNetwork(for adType: AdType) -> String? {
        switch adType {
        case .prebidBanner, .prebidInterstitial:
            return "pubmatic"
        case .googleBanner, .googleNative, .googleInterstitial, .googleRewarded:
            return "msp_google"
        case .facebookNative, .facebookInterstitial, .facebookRewarded:
            return "msp_fb"
        case .novaNative, .novaInterstitialHorizontalImage, .novaInterstitialVerticalImage,
            .novaInterstitialHorizontalVideo, .novaInterstitialVerticalVideo,
            .novaInterstitialHighEngagement, .novaInterstitialEndCard:
            return "msp_nova"
        default:
            return nil
        }
    }

    private func getCreativeType(for adType: AdType) -> String {
        switch adType {
        case .novaInterstitialHorizontalImage, .novaInterstitialVerticalImage:
            return "image"
        default:
            return "video"
        }
    }

    private func getCreativeLayout(for adType: AdType) -> String? {
        switch adType {
        case .novaInterstitialHorizontalImage, .novaInterstitialHorizontalVideo, .novaInterstitialHighEngagement:
            return "horizontal"
        case .novaInterstitialVerticalImage, .novaInterstitialVerticalVideo,
            .novaInterstitialEndCard, .novaNative:
            return "vertical"
        default:
            return nil
        }
    }

    private func toggleCustomParams() {
        isCustomParamsExpanded.toggle()
        customParamsButton?.setTitle(
            "Custom Params  \(isCustomParamsExpanded ? "▼" : "▶")", for: .normal)
        if isCustomParamsExpanded {
            customParamsContainer?.alpha = 0
            UIView.animate(withDuration: 0.25) {
                self.customParamsContainer?.isHidden = false
            } completion: { _ in
                UIView.animate(withDuration: 0.2) {
                    self.customParamsContainer?.alpha = 1
                }
            }
        } else {
            UIView.animate(withDuration: 0.2) {
                self.customParamsContainer?.alpha = 0
            } completion: { _ in
                self.customParamsContainer?.isHidden = true
                self.customParamsContainer?.alpha = 1
            }
        }
    }

    @objc private func novaSandboxToggleChanged(_ sender: UISwitch) {
        useNovaSandbox = sender.isOn
    }

    @objc private func enableH5FormatToggleChanged(_ sender: UISwitch) {
        enableH5Format = sender.isOn
    }

    private func makeChipButton(title: String, value: String) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var updated = attrs
            updated.font = .systemFont(ofSize: 13)
            return updated
        }
        let button = UIButton(configuration: config)
        button.layer.cornerRadius = 14
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemTeal.cgColor
        button.accessibilityIdentifier = value
        button.addTarget(self, action: #selector(h5TemplateGroupChipTapped(_:)), for: .touchUpInside)
        updateChipAppearance(button, isSelected: false)
        return button
    }

    private func updateChipAppearance(_ chip: UIButton, isSelected: Bool) {
        var config = chip.configuration
        config?.background.backgroundColor = isSelected ? .systemTeal : .clear
        config?.baseForegroundColor = isSelected ? .white : .systemTeal
        chip.configuration = config
    }

    @objc private func h5TemplateGroupChipTapped(_ sender: UIButton) {
        guard let value = sender.accessibilityIdentifier else { return }
        if h5TemplateGroup == value {
            h5TemplateGroup = nil
            updateChipAppearance(sender, isSelected: false)
        } else {
            if let old = h5TemplateGroup, let oldChip = h5TemplateGroupChips[old] {
                updateChipAppearance(oldChip, isSelected: false)
            }
            h5TemplateGroup = value
            updateChipAppearance(sender, isSelected: true)
        }
    }
}
