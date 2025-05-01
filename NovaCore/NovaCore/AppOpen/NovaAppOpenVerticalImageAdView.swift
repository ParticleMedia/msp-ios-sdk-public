//
//  NovaAppOpenVerticalImageAdView.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 12/5/24.
//

import Foundation
import UIKit

public class NovaAppOpenVerticalImageAdView: UIView {
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
        imageView.image = UIImage.Nova.bottomShadow
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
    
    public let topRightCloseButton: UIButton = {
        let button = UIButton()
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
        button.setTitleColor(UIColor(light: NovaColorPalettes.Gray.tint600, dark: NovaColorPalettes.Gray.tint600), for: .normal)
        button.layer.borderWidth = 0
        button.layer.cornerRadius = 12
        button.backgroundColor = NovaColorPalettes.White
        
        button.widthAnchor.constraint(equalToConstant: 24).isActive = true
        button.heightAnchor.constraint(equalToConstant: 24).isActive = true
        button.isUserInteractionEnabled = false
        return button
    }()
    
    public let topRightCloseButtonArea: UIView = {
        let view = UIView()
        view.widthAnchor.constraint(equalToConstant: 48).isActive = true
        view.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return view
    }()

    private var mediaView: NovaNativeAdMediaViewV2?
    private let media: NovaNativeAdMedia

    private let appOpenAd: NovaAppOpenAd
    private let startTime: CFTimeInterval
    private let viewController: UIViewController
    
    private let novaAppOpenAdLayout: NovaAppOpenAdLayout?

    // MARK: -

    init(with media: NovaNativeAdMedia, appOpenAd: NovaAppOpenAd, actionHandler: ActionHandling, viewController: UIViewController, novaAppOpenAdLayout: NovaAppOpenAdLayout?) {
        self.actionHandler = actionHandler
        self.appOpenAd = appOpenAd
        self.startTime = CACurrentMediaTime()
        self.media = media
        self.viewController = viewController
        self.novaAppOpenAdLayout = novaAppOpenAdLayout
        
        let adOpenActionHandler = NovaAdOpenActionHandler(viewController: viewController)
        let actionHandlerMaster = ActionHandlerMaster(actionHandlers: [adOpenActionHandler])

        self.nativeAdView = NovaNativeAdView(actionHandler: actionHandlerMaster)
        
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

// MARK: - Private methods

private extension NovaAppOpenVerticalImageAdView {
    func setupSubviews() {
        addSubviews(nativeAdView)

        nativeAdView.translatesAutoresizingMaskIntoConstraints = false
        bottomShadow.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        adTagLabel.translatesAutoresizingMaskIntoConstraints = false
        advertiserInfoStackView.translatesAutoresizingMaskIntoConstraints = false
        feedbackButton.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        volumeButton.translatesAutoresizingMaskIntoConstraints = false

        // Adding subviews
        nativeAdView.addSubviews(
            bottomShadow,
            closeButton,
            ctaButton,
            adTagLabel,
            advertiserInfoStackView,
            feedbackButton,
            bodyLabel,
            adTagLabel,
            volumeButton
        )
        let totalButtonBottomMargin = LayoutMetrics.bottomButtonBottomMargin + LayoutMetrics.progressBarBottomMargin
        if UIDevice.current.userInterfaceIdiom == .pad {
            NSLayoutConstraint.activate([
                // ctaButton constraints
                ctaButton.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -LayoutMetrics.horizontalMargin),
                ctaButton.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor, constant: -totalButtonBottomMargin),
                ctaButton.heightAnchor.constraint(equalToConstant: LayoutMetrics.bottomButtonHeight),
                
                // closeButton constraints
                closeButton.leadingAnchor.constraint(equalTo: nativeAdView.centerXAnchor, constant: LayoutMetrics.horizontalMargin),
                closeButton.trailingAnchor.constraint(equalTo: ctaButton.leadingAnchor, constant: -LayoutMetrics.horizontalMargin),
                closeButton.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor, constant: -totalButtonBottomMargin),
                closeButton.heightAnchor.constraint(equalToConstant: LayoutMetrics.bottomButtonHeight),
                closeButton.widthAnchor.constraint(equalTo: ctaButton.widthAnchor),
                
                // nativeAdView constraints
                nativeAdView.topAnchor.constraint(equalTo: self.topAnchor),
                nativeAdView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                nativeAdView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                nativeAdView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
                
                // bottomShadow constraints
                bottomShadow.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
                bottomShadow.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
                bottomShadow.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor),
                bottomShadow.heightAnchor.constraint(equalToConstant: UIScreen.main.bounds.width * 280 / 375),
                
                // adTagLabel constraints
                adTagLabel.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: LayoutMetrics.horizontalMargin),
                adTagLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -LayoutMetrics.horizontalMargin),
                adTagLabel.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor, constant: -totalButtonBottomMargin),
                
                // bodyLabel constraints
                bodyLabel.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: LayoutMetrics.horizontalMargin),
                bodyLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -LayoutMetrics.horizontalMargin),
                bodyLabel.bottomAnchor.constraint(equalTo: adTagLabel.topAnchor, constant: -8.0),
                
                // advertiserInfoStackView constraints
                advertiserInfoStackView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: LayoutMetrics.horizontalMargin),
                advertiserInfoStackView.trailingAnchor.constraint(lessThanOrEqualTo: feedbackButton.leadingAnchor, constant: -LayoutMetrics.horizontalMargin),
                advertiserInfoStackView.bottomAnchor.constraint(equalTo: bodyLabel.topAnchor, constant: -8.0),
                
                // feedbackButton constraints
                feedbackButton.centerYAnchor.constraint(equalTo: advertiserInfoStackView.centerYAnchor),
                feedbackButton.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -LayoutMetrics.horizontalMargin),
                feedbackButton.widthAnchor.constraint(equalToConstant: 24),
                feedbackButton.heightAnchor.constraint(equalToConstant: 24),
                
                // volumeButton constraints
                volumeButton.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: LayoutMetrics.horizontalMargin),
                volumeButton.heightAnchor.constraint(equalToConstant: LayoutMetrics.volumeButtonWidth),
                volumeButton.widthAnchor.constraint(equalToConstant: LayoutMetrics.volumeButtonWidth),
                volumeButton.bottomAnchor.constraint(equalTo: advertiserInfoStackView.topAnchor, constant: -LayoutMetrics.volumeButtonBottomMargin)
                
            ])
        } else {
            if let novaAppOpenAdLayout = self.novaAppOpenAdLayout,
               novaAppOpenAdLayout == .verticalCancelTopRight {
                closeButton.isHidden = true
                NSLayoutConstraint.activate([
                    // ctaButton constraints
                    ctaButton.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: LayoutMetrics.horizontalMargin),
                    ctaButton.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -LayoutMetrics.horizontalMargin),
                    ctaButton.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor, constant: -totalButtonBottomMargin),
                    ctaButton.heightAnchor.constraint(equalToConstant: LayoutMetrics.bottomButtonHeight),
                    ctaButton.widthAnchor.constraint(equalToConstant: LayoutMetrics.bottomButtonWidth)
                ])
                addSubview(topRightCloseButtonArea)
                topRightCloseButtonArea.translatesAutoresizingMaskIntoConstraints = false
                topRightCloseButton.translatesAutoresizingMaskIntoConstraints = false
                topRightCloseButtonArea.addSubview(topRightCloseButton)
                NSLayoutConstraint.activate([
                    topRightCloseButtonArea.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor, constant: self.safeAreaInsets.top + 4),
                    topRightCloseButtonArea.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -4),
                    topRightCloseButton.centerXAnchor.constraint(equalTo: topRightCloseButtonArea.centerXAnchor),
                    topRightCloseButton.centerYAnchor.constraint(equalTo: topRightCloseButtonArea.centerYAnchor)
                ])
                
            } else {
                NSLayoutConstraint.activate([
                    // closeButton constraints
                    closeButton.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: LayoutMetrics.horizontalMargin),
                    closeButton.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor, constant: -totalButtonBottomMargin),
                    closeButton.heightAnchor.constraint(equalToConstant: LayoutMetrics.bottomButtonHeight),
                    closeButton.trailingAnchor.constraint(equalTo: self.centerXAnchor, constant: -8),
                    
                    // ctaButton constraints
                    ctaButton.leadingAnchor.constraint(equalTo: self.centerXAnchor, constant: 8),
                    ctaButton.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -LayoutMetrics.horizontalMargin),
                    ctaButton.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor, constant: -totalButtonBottomMargin),
                    ctaButton.heightAnchor.constraint(equalToConstant: LayoutMetrics.bottomButtonHeight)
                ])
            }
            // Activate native constraints
            NSLayoutConstraint.activate([
                // nativeAdView constraints
                nativeAdView.topAnchor.constraint(equalTo: self.topAnchor),
                nativeAdView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                nativeAdView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                nativeAdView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
                
                // bottomShadow constraints
                bottomShadow.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
                bottomShadow.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
                bottomShadow.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor),
                bottomShadow.heightAnchor.constraint(equalToConstant: UIScreen.main.bounds.width * 280 / 375),
                
                // adTagLabel constraints
                adTagLabel.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: LayoutMetrics.horizontalMargin),
                adTagLabel.trailingAnchor.constraint(lessThanOrEqualTo: nativeAdView.trailingAnchor, constant: -LayoutMetrics.horizontalMargin),
                adTagLabel.bottomAnchor.constraint(equalTo: ctaButton.topAnchor, constant: -16.0),
                
                // bodyLabel constraints
                bodyLabel.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: LayoutMetrics.horizontalMargin),
                bodyLabel.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -LayoutMetrics.horizontalMargin),
                bodyLabel.bottomAnchor.constraint(equalTo: adTagLabel.topAnchor, constant: -8.0),
                
                // advertiserInfoStackView constraints
                advertiserInfoStackView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: LayoutMetrics.horizontalMargin),
                advertiserInfoStackView.trailingAnchor.constraint(lessThanOrEqualTo: feedbackButton.leadingAnchor, constant: -LayoutMetrics.horizontalMargin),
                advertiserInfoStackView.bottomAnchor.constraint(equalTo: bodyLabel.topAnchor, constant: -8.0),
                
                // feedbackButton constraints
                feedbackButton.centerYAnchor.constraint(equalTo: advertiserInfoStackView.centerYAnchor),
                feedbackButton.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -LayoutMetrics.horizontalMargin),
                feedbackButton.widthAnchor.constraint(equalToConstant: 24),
                feedbackButton.heightAnchor.constraint(equalToConstant: 24),
                
                // volumeButton constraints
                volumeButton.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: LayoutMetrics.horizontalMargin),
                volumeButton.heightAnchor.constraint(equalToConstant: LayoutMetrics.volumeButtonWidth),
                volumeButton.widthAnchor.constraint(equalToConstant: LayoutMetrics.volumeButtonWidth),
                volumeButton.bottomAnchor.constraint(equalTo: advertiserInfoStackView.topAnchor, constant: -LayoutMetrics.volumeButtonBottomMargin)
            ])
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
        closeButton.addTarget(self, action: #selector(didTapCloseButton), for: .touchUpInside)
        feedbackButton.addTarget(self, action: #selector(didTapReportButton), for: .touchUpInside)
        topRightCloseButtonArea.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapCloseButton)))
        let tappableViews = [bottomShadow,
                             ctaButton,
                             adTagLabel,
                             advertiserInfoStackView,
                             bodyLabel,
                             adTagLabel]
        for view in tappableViews {
            view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapAd(sender:))))
        }
        if openAd.isImageClickable ?? true {
            mediaView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapAd(sender:))))
        }
    }

    func configAdAvatar(for openAd: NovaAppOpenAd) {
        guard let iconUrl = openAd.iconUrl else {
            advertiserAvatar.isHidden = true
            return
        }
        if let url = URL(string: iconUrl) {
            NovaUIUtils.setImage(from: url, to: advertiserAvatar) {
                
            }
        }
    }

    func configMediaView(for openAd: NovaAppOpenAd) {
        if mediaView == nil {
            createMediaView(for: openAd)
        }

        guard let mediaView else { return }
        if UIDevice.current.userInterfaceIdiom == .pad {
            mediaView.imageView.contentMode = .scaleAspectFit
        }
        mediaView.config(with: media)
    }

    func createMediaView(for openAd: NovaAppOpenAd) {

        let mediaView = NovaNativeAdMediaViewV2()
        mediaView.accessibilityIdentifier = "media"
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        
        self.mediaView = mediaView
        //mediaView = NovaNativeAdImmersiveVideoView(progressViewBottomMargin: LayoutMetrics.progressBarBottomMargin)

        mediaView.isUserInteractionEnabled = true
        nativeAdView.insertSubview(mediaView, at: 0)

        NSLayoutConstraint.activate([
            mediaView.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
            mediaView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
            mediaView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
            mediaView.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor)
        ])

        self.mediaView = mediaView
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
            if let appStoreId = appOpenAd.appStoreId {
                actionKey = NovaAdOpenActionKey.launchStore.rawValue
            } else {
                actionKey = NovaAdOpenActionKey.launchWebView.rawValue
            }
        }

        let tapActionModel = ActionModel(
            actionKey: actionKey,
            actionDataModel: openActionDataModel)
        actionHandler.performAction(actionModel: tapActionModel)

        //let openActionModel = ActionModel(actionKey: actionKey, actionDataModel: openActionDataModel)
        //actionHandler.performAction(actionModel: openActionModel)

        NovaAdMetricReporter.logAdClick(
            thirdPartyClickTrackingUrls: appOpenAd.thirdPartyClickTrackingUrls,
            encryptedAdToken: appOpenAd.encryptedAdToken,
            durationInMs: Int((clickTime - startTime) * 1000),
            clickArea: sender.view?.accessibilityIdentifier)
    }

   
}
