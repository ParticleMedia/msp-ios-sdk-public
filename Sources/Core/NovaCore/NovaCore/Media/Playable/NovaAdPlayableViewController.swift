//
//  NovaAdPlayableViewController.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/8/18.
//

import UIKit

// MARK: - NovaAdPlayableViewController

class NovaAdPlayableViewController: UIViewController {
    // MARK: Lifecycle

    init(with config: Config) {
        self.config = config
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Public

    struct Config {
        enum AppInstallBannerDisplayMode {
            case disable
            case bottom
        }

        let playableConfigs: (model: PlayableModel, actionContext: NovaAdMediaActionContext?)
        let advertiser: String?
        let appInstallBannerDisplayMode: AppInstallBannerDisplayMode
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(light: NovaColorPalettes.Gray.tint100, dark: NovaColorPalettes.Gray.tint700)
        view.clipsToBounds = true

        // Do any additional setup after loading the view.
        view.addSubviews(topBar, playableView, bottomBar)

        topBar.snp.makeConstraints { make in
            make.top.directionalHorizontalEdges.equalToSuperview()
            make.height.equalTo(UIApplication.novaSafeAreaInsets.top + 44)
        }
        topBar.addSubviews(closeButton, titleLabel)
        closeButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(6)
            make.bottom.equalToSuperview()
            make.size.equalTo(44)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualToSuperview().offset(56)
            make.trailing.lessThanOrEqualToSuperview().offset(-56)
            make.centerX.equalToSuperview()
            make.centerY.equalTo(closeButton)
        }
        playableView.snp.makeConstraints { make in
            make.directionalHorizontalEdges.equalToSuperview()
            make.top.equalTo(topBar.snp.bottom)
            make.bottom.equalTo(bottomBar.snp.top)
        }
        bottomBar.snp.makeConstraints { make in
            make.bottom.directionalHorizontalEdges.equalToSuperview()
            make.height.equalTo(UIApplication.novaSafeAreaInsets.bottom + 22)
        }

        config(with: config)

        view.layoutIfNeeded()
    }

    // MARK: Private

    private lazy var topBar: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(light: NovaColorPalettes.White, dark: NovaColorPalettes.Gray.tint800)
        return view
    }()

    private lazy var closeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10.0, leading: 10.0, bottom: 10.0, trailing: 10.0)
        configuration.image = .Nova.crossLine?.withRenderingMode(.alwaysTemplate)
        configuration.baseForegroundColor = UIColor(light: NovaColorPalettes.Gray.tint800, dark: NovaColorPalettes.White)
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(didTapCloseButton), for: .touchUpInside)
        return button
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(light: NovaColorPalettes.Gray.tint800, dark: NovaColorPalettes.White)
        label.textAlignment = .center
        label.font = .boldSystemFont(ofSize: 16)
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private lazy var playableView: NovaAdPlayableView = .init()

    private lazy var bottomBar: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(light: NovaColorPalettes.White, dark: NovaColorPalettes.Gray.tint800)
        return view
    }()

    private var appInstallBanner: NovaAdAppInstallBanner?
    private var actionHelper: NovaActionHelper<NovaActionState.Init>?
    private var startTime: CFTimeInterval!

    private let config: Config

    private func config(with config: Config) {
        startTime = CACurrentMediaTime()
        guard let actionContext = config.playableConfigs.actionContext else {
            playableView.config(with: config.playableConfigs.model, actionContext: nil)
            titleLabel.text = config.advertiser
            return
        }

        let sharedActionHelper = NovaActionHelper.build(
            with: .adInViewController(
                model: AdActionModel(
                    tracingInfo: actionContext.adActionTracingInfo,
                    extraInfo: actionContext.adActionExtraInfo,
                    ctrType: config.playableConfigs.model.launchAdType
                ),
                viewController: Weak(self)
            )
        )
        actionHelper = sharedActionHelper

        playableView.config(
            with: config.playableConfigs.model,
            actionContext: actionContext,
            actionHelper: sharedActionHelper
        )
        titleLabel.text = config.advertiser
        setupAppInfoBannerIfNeeded()
    }

    private func setupAppInfoBannerIfNeeded() {
        let playableModel = config.playableConfigs.model
        guard case .appInstall = playableModel.launchAdType,
              config.appInstallBannerDisplayMode == .bottom else {
            return
        }

        guard let actionContext = config.playableConfigs.actionContext,
              let playableConfig = actionContext.adActionExtraInfo.playableConfig,
              let appInfo = playableConfig.appInfo else {
            return
        }

        Task {
            do {
                let appInfo = try await appInfo.value()
                await MainActor.run {
                    let bannerConfig = NovaAdAppInstallBanner.Config(
                        appInfo: appInfo,
                        callToAction: playableConfig.callToAction
                    )
                    self.createAndShowBanner(with: bannerConfig)
                }
            } catch {
                DebugLogger.data.error("Load app info failed: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func createAndShowBanner(with bannerConfig: NovaAdAppInstallBanner.Config) {
        let banner = NovaAdAppInstallBanner(config: bannerConfig)
        banner.delegate = self
        appInstallBanner = banner

        view.insertSubview(banner, aboveSubview: bottomBar)

        banner.snp.makeConstraints { make in
            make.directionalHorizontalEdges.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
        }

        playableView.snp.remakeConstraints { make in
            make.directionalHorizontalEdges.equalToSuperview()
            make.top.equalTo(topBar.snp.bottom)
            make.bottom.equalTo(banner.snp.top)
        }

        banner.showWithAnimation()
    }

    private func handleBannerTap(on view: UIView?) {
        let playableModel = config.playableConfigs.model
        guard case .appInstall = playableModel.launchAdType,
              let actionHelper = actionHelper else {
            return
        }

        self.actionHelper = actionHelper
            .logNovaClickEvent(with: CACurrentMediaTime() - startTime, in: view?.adClickArea)
            .handleAdTap(in: view)
    }
}

// MARK: - NovaAdAppInstallBannerDelegate

extension NovaAdPlayableViewController: NovaAdAppInstallBannerDelegate {
    func appInstallBannerDidTap(_ banner: NovaAdAppInstallBanner, subview: UIView) {
        handleBannerTap(on: subview)
    }
}

private extension NovaAdPlayableViewController {
    @objc func didTapCloseButton() {
        dismiss(animated: true)
    }
}
