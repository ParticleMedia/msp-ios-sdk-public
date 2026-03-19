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
            button9, button10, button11, button12, button13,
        ]
        standardButtons.forEach { contentStack.addArrangedSubview($0) }
        contentStack.addArrangedSubview(adListButton)

        let customParamsButton = UIButton(type: .system)
        customParamsButton.setTitle("Custom Params  ▶", for: .normal)
        customParamsButton.backgroundColor = .systemTeal
        customParamsButton.setTitleColor(.white, for: .normal)
        customParamsButton.layer.cornerRadius = 8
        customParamsButton.addAction(
            UIAction { [weak self] _ in
                self?.toggleCustomParams()
            }, for: .touchUpInside)
        customParamsButton.snp.makeConstraints { make in make.height.equalTo(50) }
        self.customParamsButton = customParamsButton
        contentStack.addArrangedSubview(customParamsButton)

        let customParamsContainer = UIView()
        customParamsContainer.backgroundColor = .secondarySystemBackground
        customParamsContainer.layer.cornerRadius = 8
        customParamsContainer.isHidden = true

        let sandboxLabel = UILabel()
        sandboxLabel.text = "Nova Sandbox"
        sandboxLabel.translatesAutoresizingMaskIntoConstraints = false
        let sandboxToggle = UISwitch()
        sandboxToggle.isOn = useNovaSandbox
        sandboxToggle.translatesAutoresizingMaskIntoConstraints = false
        sandboxToggle.addTarget(self, action: #selector(novaSandboxToggleChanged(_:)), for: .valueChanged)

        customParamsContainer.addSubview(sandboxLabel)
        customParamsContainer.addSubview(sandboxToggle)
        NSLayoutConstraint.activate([
            customParamsContainer.heightAnchor.constraint(equalToConstant: 50),
            sandboxLabel.leadingAnchor.constraint(equalTo: customParamsContainer.leadingAnchor, constant: 16),
            sandboxLabel.centerYAnchor.constraint(equalTo: customParamsContainer.centerYAnchor),
            sandboxToggle.trailingAnchor.constraint(equalTo: customParamsContainer.trailingAnchor, constant: -16),
            sandboxToggle.centerYAnchor.constraint(equalTo: customParamsContainer.centerYAnchor),
        ])
        self.customParamsContainer = customParamsContainer
        contentStack.addArrangedSubview(customParamsContainer)

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
        let demoAdVC = DemoAdViewController(adType: adType, customParams: buildCustomParams())
        navigationController?.pushViewController(demoAdVC, animated: true)
    }

    private func buildCustomParams() -> [String: Any] {
        [MSPConstants.USE_NOVA_SANDBOX: useNovaSandbox ? "true" : "false"]
    }

    private func toggleCustomParams() {
        isCustomParamsExpanded.toggle()
        customParamsButton?.setTitle(
            "Custom Params  \(isCustomParamsExpanded ? "▼" : "▶")", for: .normal)
        UIView.animate(withDuration: 0.25) {
            self.customParamsContainer?.isHidden = !self.isCustomParamsExpanded
        }
    }

    @objc private func novaSandboxToggleChanged(_ sender: UISwitch) {
        useNovaSandbox = sender.isOn
    }
}
