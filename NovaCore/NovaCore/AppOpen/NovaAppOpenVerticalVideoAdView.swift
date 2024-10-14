//
//  NovaAppOpenVerticalVideoAdView.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/2/24.
//

import Foundation
import UIKit

public class NovaAppOpenVerticalVideoAdView: UIView {
    static var nb_isiPhoneX: Bool {
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            return false
        }

        let safeAreaInsets: UIEdgeInsets = UIApplication.shared.windows.first?.safeAreaInsets ?? .zero
        return safeAreaInsets.top > 20
    }
    
    @objc static var bottomRoundAreaHeight: CGFloat {
        return nb_isiPhoneX ? 34.0 : 0.0
    }
    private enum LayoutMetrics {
        static let avatarSize = 24.0
        static let horizontalMargin = 16.0
        static let progressBarBottomMargin = 22.0 + bottomRoundAreaHeight
        static let bottomButtonBottomMargin = 24.0
        static let bottomButtonHeight = 48.0
        static let bottomButtonWidth = 156.0
        static let volumeButtonWidth = 24.0
        static let volumeButtonBottomMargin = 28.0
    }

    private let actionHandler: ActionHandling
    public var viewController: UIViewController

    private let nativeAdView: NovaNativeAdView

    private let volumeButton: UIButton = {
        let button = UIButton()
        button.imageEdgeInsets = UIEdgeInsets(top: 4.0, left: 4.0, bottom: 4.0, right: 4.0)
        return button
    }()

    private let advertiserAvatar: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = LayoutMetrics.avatarSize * 0.5
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = NovaColorPalettes.Gray.tint100.cgColor

        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: LayoutMetrics.avatarSize),
            imageView.heightAnchor.constraint(equalToConstant: LayoutMetrics.avatarSize)
        ])
        imageView.accessibilityIdentifier = "icon"

        return imageView
    }()

    private let advertiserLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.headline2
        label.textColor = NovaColorPalettes.White
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        label.accessibilityIdentifier = "advertiser"
        return label
    }()

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.subtitle1
        label.textColor = NovaColorPalettes.White.nb_opacity9()
        label.numberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.accessibilityIdentifier = "body"
        return label
    }()

    private let adTagLabel: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.font = .systemFont(ofSize: 10, weight: .semibold)
        button.setTitleColor(NovaColorPalettes.White, for: .normal)
        button.setTitle(NSLocalizedString("SPONSORED", comment: ""), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentEdgeInsets = UIEdgeInsets(top: 2.0, left: 6.0, bottom: 2.0, right: 6.0)
        button.backgroundColor = NovaColorPalettes.White.nb_opacity4()
        button.layer.cornerRadius = 2.0
        button.accessibilityIdentifier = "badge"
        return button
    }()

    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = NovaColorPalettes.Gray.tint800.nb_opacity6()
        button.titleLabel?.font = .Nova.body1
        button.setTitleColor(NovaColorPalettes.White.nb_opacity9(), for: .normal)

        button.layer.cornerRadius = 8.0
        button.layer.borderWidth = 1.0
        button.layer.borderColor = NovaColorPalettes.Gray.tint300.cgColor

        button.accessibilityIdentifier = "close"
        return button
    }()

    private let ctaButton: UIButton = {
        let button = UIButton(type: .system)

        button.titleLabel?.font = .Nova.body1
        button.setTitleColor(NovaColorPalettes.White, for: .normal)

        button.layer.backgroundColor = NovaColorPalettes.Blue.tint500.cgColor
        button.layer.borderColor = UIColor(
            light: NovaColorPalettes.Black.nb_opacity6(),
            dark: NovaColorPalettes.Gray.tint200).cgColor
        button.layer.cornerRadius = 8.0

        button.accessibilityIdentifier = "cta"

        return button
    }()

    private let bottomShadow: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.image = AppOpenAdResource.image("bottom_shadow")
        return imageView
    }()

    private lazy var advertiserInfoStackView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [advertiserAvatar, advertiserLabel])
        view.alignment = .center
        view.spacing = 6.0
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var feedbackButton: UIButton = {
        let button = UIButton()
        let image = UIImage(
            novasystemName: .ellipsisHorizontalOutline,
            tintColor: NovaColorPalettes.White)
        button.setImage(image, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var mediaView: NovaNativeAdMediaView?//(UIView & NovaNativeAdImmersiveMediaView)?

    private let appOpenAd: NovaAppOpenAd
    private let appOpenVideoInfo: NovaNativeAdVideoInfo
    private let startTime: CFTimeInterval

    // MARK: -

    init(appOpenAd: NovaAppOpenAd, videoInfo: NovaNativeAdVideoInfo, actionHandler: ActionHandling, viewController: UIViewController) {
        self.actionHandler = actionHandler
        self.appOpenAd = appOpenAd
        self.appOpenVideoInfo = videoInfo
        self.startTime = CACurrentMediaTime()
        self.viewController = viewController
        
        let adOpenActionHandler = NovaAdOpenActionHandler()
        let actionHandlerMaster = ActionHandlerMaster(actionHandlers: [adOpenActionHandler])

        self.nativeAdView = NovaNativeAdView(actionHandler: actionHandlerMaster, rootViewController: viewController)
        
        super.init(frame: .zero)

        setupSubviews()
        configAdLabels(for: appOpenAd)
        configAdAvatar(for: appOpenAd)
        configMediaView(for: appOpenAd)
        configTapGesture(for: appOpenAd)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Public methods

extension NovaAppOpenVerticalVideoAdView {
    func startPlaying() {
        //mediaView?.startPlaying()
    }

    func endPlaying() {
        //mediaView?.endPlaying()
    }
}

// MARK: - Private methods

private extension NovaAppOpenVerticalVideoAdView {
    func setupSubviews() {
        addSubviews(nativeAdView)

        nativeAdView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        nativeAdView.addSubviews(
            bottomShadow,
            closeButton,
            ctaButton,
            adTagLabel,
            advertiserInfoStackView,
            feedbackButton,
            bodyLabel,
            adTagLabel,
            volumeButton)

        bottomShadow.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            let screenWidth = UIScreen.main.bounds.width
            make.height.equalTo(screenWidth * 280 / 375)
        }

        let totalButtonBottomMargin = LayoutMetrics.bottomButtonBottomMargin + LayoutMetrics.progressBarBottomMargin

        closeButton.snp.makeConstraints { make in
            make.leading.equalTo(LayoutMetrics.horizontalMargin)
            make.bottom.equalTo(-totalButtonBottomMargin)
            make.height.equalTo(LayoutMetrics.bottomButtonHeight)
            make.width.equalTo(LayoutMetrics.bottomButtonWidth)
        }

        ctaButton.snp.makeConstraints { make in
            make.trailing.equalTo(-LayoutMetrics.horizontalMargin)
            make.bottom.equalTo(-totalButtonBottomMargin)
            make.height.equalTo(LayoutMetrics.bottomButtonHeight)
            make.width.equalTo(LayoutMetrics.bottomButtonWidth)
        }

        adTagLabel.snp.makeConstraints { make in
            make.leading.equalTo(LayoutMetrics.horizontalMargin)
            make.trailing.lessThanOrEqualTo(-LayoutMetrics.horizontalMargin)
            make.bottom.equalTo(closeButton.snp.top).offset(-16.0)
        }

        bodyLabel.snp.makeConstraints { make in
            make.leading.equalTo(LayoutMetrics.horizontalMargin)
            make.trailing.equalTo(-LayoutMetrics.horizontalMargin)
            make.bottom.equalTo(adTagLabel.snp.top).offset(-8.0)
        }

        advertiserInfoStackView.snp.makeConstraints { make in
            make.leading.equalTo(LayoutMetrics.horizontalMargin)
            make.trailing.lessThanOrEqualTo(feedbackButton.snp.leading).offset(-LayoutMetrics.horizontalMargin)
            make.bottom.equalTo(bodyLabel.snp.top).offset(-8.0)
        }
        
        feedbackButton.snp.makeConstraints { make in
            make.centerY.equalTo(advertiserInfoStackView)
            make.trailing.equalTo(-LayoutMetrics.horizontalMargin)
            make.width.height.equalTo(24)
        }

        volumeButton.snp.makeConstraints { make in
            make.leading.equalTo(LayoutMetrics.horizontalMargin)
            make.height.width.equalTo(LayoutMetrics.volumeButtonWidth)
            make.bottom.equalTo(self.advertiserInfoStackView.snp.top).offset(-LayoutMetrics.volumeButtonBottomMargin)
        }
        
        feedbackButton.isHidden = true
        volumeButton.isHidden = true
    }

    func configAdLabels(for openAd: NovaAppOpenAd) {
        advertiserLabel.text = openAd.advertiser
        bodyLabel.text = openAd.body

        adTagLabel.setTitle(NSLocalizedString("SPONSORED", comment: ""), for: .normal)
        closeButton.setTitle(NSLocalizedString("Close", comment: ""), for: .normal)
        ctaButton.setTitle(openAd.callToAction, for: .normal)
    }

    func configTapGesture(for openAd: NovaAppOpenAd) {
        volumeButton.addTarget(self, action: #selector(didTapVolumeButton), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(didTapCloseButton), for: .touchUpInside)
        feedbackButton.addTarget(self, action: #selector(didTapReportButton), for: .touchUpInside)
        let tappableViews = [bottomShadow,
                             ctaButton,
                             adTagLabel,
                             advertiserInfoStackView,
                             bodyLabel,
                             adTagLabel]
        for view in tappableViews {
            view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapAd(sender:))))
        }
        if openAd.videoInfo?.isVideoClickable ?? false {
            mediaView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapAd(sender:))))
        }
    }

    func configAdAvatar(for openAd: NovaAppOpenAd) {
        guard let iconUrl = openAd.iconUrl else {
            advertiserAvatar.isHidden = true
            return
        }

        advertiserAvatar.sd_setImage(with: URL(string: iconUrl))
    }

    func configMediaView(for openAd: NovaAppOpenAd) {
        if mediaView == nil {
            createMediaView(for: openAd)
        }

        guard let mediaView else { return }
        
        let mediaVM = NovaNativeAdMediaViewModel(encryptedAdToken: openAd.encryptedAdToken,
                                                 imageUrlStr: openAd.imageUrlStr,
                                                 videoInfo: openAd.videoInfo)
        mediaView.config(with: mediaVM, iabReporter: IABMetricReporter()) {
            
        }

        /*
        let mediaViewModel = NovaNativeAdImmersiveMediaViewModel(
            encryptedAdToken: openAd.encryptedAdToken,
            adId: openAd.adId,
            imageUrlStr: openAd.imageUrlStr,
            isImageClickable: false,
            videoInfo: openAd.videoInfo,
            bannerDisplayTime: nil
        )
        mediaView.config(viewModel: mediaViewModel, delegate: nil, iabMetricReporter: nativeAdView.iABMetricReporter)
         */
        setPlayerVolume(muted: openAd.videoInfo?.state?.isMute ?? true)
    }

    func createMediaView(for openAd: NovaAppOpenAd) {
        guard case .nativeVideo = openAd.creativeType else {
            assertionFailure("Unsupported Nova immersive ad creative type = \(String(describing: openAd.creativeType?.rawValue))")
            return
        }

        let mediaView = NovaNativeAdMediaView()
        mediaView.accessibilityIdentifier = "media"
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        
        self.mediaView = mediaView
        //mediaView = NovaNativeAdImmersiveVideoView(progressViewBottomMargin: LayoutMetrics.progressBarBottomMargin)

        mediaView.isUserInteractionEnabled = true
        nativeAdView.insertSubview(mediaView, at: 0)

        mediaView.snp.makeConstraints { make in
            make.edges.equalTo(self.nativeAdView)
        }

        self.mediaView = mediaView
    }

    func setPlayerVolume(muted: Bool) {
        let volumnOnImage = UIImage.Nova.volumeOnLine?.withTintColor(NovaColorPalettes.White)
        let volumnOffImage = UIImage.Nova.volumeOffLine?.withTintColor(NovaColorPalettes.White)
        //mediaView?.setPlayerVolume(muted: muted)
        volumeButton.setImage(muted ? volumnOffImage : volumnOnImage, for: .normal)
    }

    @objc func didTapMediaView() {
        //mediaView?.handleTapGesture()
    }

    @objc func didTapCloseButton() {
        let skipActionModel = ActionModel(
            actionKey: NovaAppOpenAdViewActionKey.manualSkip.rawValue,
            actionDataModel: EmptyActionDataModel())
        actionHandler.performAction(actionModel: skipActionModel)

        let clickTime = CACurrentMediaTime()
        appOpenAd.delegate?.appOpenAdDidDismiss(appOpenAd)
        NovaAdMetricReporter.logAdSkip(
            reason: .skipButton,
            encryptedAdToken: appOpenAd.encryptedAdToken,
            durationInMs: Int((clickTime - startTime) * 1000))
    }
    
    @objc func didTapReportButton() {
        //let reportActionModel = ActionModel(
        //    actionKey: NovaAppOpenAdViewActionKey.feedbackReport.rawValue,
        //    actionDataModel: NovaAppOpenAdFeedBackReportActionModel(appOpenAd: appOpenAd)
        //)
        //actionHandler.performAction(actionModel: reportActionModel)
    }

    @objc func didTapAd(sender: UIGestureRecognizer) {
        guard let ctrUrl = appOpenAd.ctrUrl else {
            assertionFailure("App open ad should have an associated ctr url")
            return
        }

        appOpenAd.delegate?.appOpenAdDidLogClick(appOpenAd)

        let clickTime = CACurrentMediaTime()

        let openActionDataModel = NovaAdOpenActionDataModel(
            url: ctrUrl,
            clickTime: clickTime,
            ad: appOpenAd)

        let launchAction: NovaAdLaunchOption
        if let validLaunchOption = NovaAdLaunchOption(rawValue: appOpenAd.launchOption ?? "") {
            launchAction = validLaunchOption
        } else {
            assertionFailure("Unsupported launch option")
            launchAction = .launchBrowser
        }

        let actionKey: String
        switch launchAction {
        case .launchBrowser:
            actionKey = NovaAdOpenActionKey.launchBrowser.rawValue
        case .launchWebView:
            actionKey = NovaAdOpenActionKey.launchWebView.rawValue
        }

        let tapActionModel = ActionModel(
            actionKey: NovaAppOpenAdViewActionKey.adTapped.rawValue,
            actionDataModel: EmptyActionDataModel())
        actionHandler.performAction(actionModel: tapActionModel)

        let openActionModel = ActionModel(actionKey: actionKey, actionDataModel: openActionDataModel)
        actionHandler.performAction(actionModel: openActionModel)

        NovaAdMetricReporter.logAdClick(
            thirdPartyClickTrackingUrls: appOpenAd.thirdPartyClickTrackingUrls,
            encryptedAdToken: appOpenAd.encryptedAdToken,
            durationInMs: Int((clickTime - startTime) * 1000),
            clickArea: sender.view?.accessibilityIdentifier)
    }

    @objc func didTapVolumeButton() {
        //let muted = mediaView?.getPlayerMutedState() ?? true
        //setPlayerVolume(muted: !muted)
        //NovaAdVideoMetricReporter.logVideoMute(encryptedAdToken: appOpenAd.encryptedAdToken, isMute: !muted)
    }
}
