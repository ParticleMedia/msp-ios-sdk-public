//
//  NovaAppOpenEndPageAdView.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 6/10/25.
//
import UIKit

@objc public class NovaAppOpenEndPageAdView: UIView {
    
    private let actionHandler: ActionHandling
    public var viewController: UIViewController

    private let nativeAdView: NovaNativeAdView
    private let appOpenAd: NovaAppOpenAd
    
    private let startTime: CFTimeInterval
    
    private enum LayoutMetrics {
        static let avatarSize = 48.0
        static let horizontalMargin = 16.0
        static let progressBarBottomMargin = 22.0 //+ bottomRoundAreaHeight
        static let bottomButtonBottomMargin = 24.0
        static let bottomButtonHeight = 48.0
        static let bottomButtonWidth = 156.0
        static let volumeButtonWidth = 24.0
        static let volumeButtonBottomMargin = 28.0
    }
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
        label.textColor = NovaColorPalettes.Black
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        label.accessibilityIdentifier = "advertiser"
        label.isUserInteractionEnabled = true
        label.textAlignment = .center
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.subtitle1
        label.textColor = NovaColorPalettes.Black
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.accessibilityIdentifier = "body"
        label.isUserInteractionEnabled = true
        label.textAlignment = .center
        return label
    }()
    
    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.body1
        label.textColor = NovaColorPalettes.Gray.tint500
        label.numberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.accessibilityIdentifier = "body"
        label.isUserInteractionEnabled = true
        label.textAlignment = .center
        return label
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
    
    public let topRightCloseButton: UIButton = {
        let button = UIButton()
        //button.setImage(UIImage.Nova.crossCircleLine?.withTintColor(UIColor(light: NovaColorPalettes.Gray.tint600, dark: NovaColorPalettes.Gray.tint200)), for: .normal)
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        button.setImage(UIImage(systemName: "xmark", withConfiguration: config)?.withTintColor(UIColor(light: NovaColorPalettes.White, dark: NovaColorPalettes.Gray.tint200), renderingMode: .alwaysOriginal), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
        button.setTitleColor(UIColor(light: NovaColorPalettes.White, dark: NovaColorPalettes.Gray.tint200), for: .normal)
        button.layer.borderWidth = 1.5
        button.layer.cornerRadius = 12
        button.layer.borderColor = UIColor(light: NovaColorPalettes.White, dark: NovaColorPalettes.Gray.tint200).cgColor
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
    
    public var endCard: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 24
        view.backgroundColor = NovaColorPalettes.White
        view.isUserInteractionEnabled = true
        return view
    }()
    
    private let bottomShadow: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.image = UIImage.Nova.bottomShadow
        return imageView
    }()
    
    init(appOpenAd: NovaAppOpenAd,  actionHandler: ActionHandling, viewController: UIViewController) {
        self.actionHandler = actionHandler
        self.appOpenAd = appOpenAd
        self.viewController = viewController
        
        let adOpenActionHandler = NovaAdOpenActionHandler(viewController: viewController)
        let actionHandlerMaster = ActionHandlerMaster(actionHandlers: [adOpenActionHandler])
        self.startTime = CACurrentMediaTime()
        self.nativeAdView = NovaNativeAdView(actionHandler: actionHandlerMaster)
        
        
        super.init(frame: .zero)

        setupSubviews()
        configAdLabels(for: appOpenAd)
        configAdAvatar(for: appOpenAd)
        configTapGesture(for: appOpenAd)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupSubviews() {
        addSubviews(nativeAdView)

        nativeAdView.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomShadow.translatesAutoresizingMaskIntoConstraints = false
        endCard.translatesAutoresizingMaskIntoConstraints = false
        
        self.backgroundColor = NovaColorPalettes.Gray.tint600

        endCard.addSubviews(advertiserLabel, titleLabel, bodyLabel, ctaButton, advertiserAvatar)
        
        NSLayoutConstraint.activate([
            nativeAdView.topAnchor.constraint(equalTo: self.topAnchor),
            nativeAdView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            nativeAdView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            nativeAdView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            
            advertiserLabel.topAnchor.constraint(equalTo: endCard.topAnchor, constant: 36),
            advertiserLabel.leftAnchor.constraint(equalTo: endCard.leftAnchor, constant: 24),
            advertiserLabel.rightAnchor.constraint(equalTo: endCard.rightAnchor, constant: -24),
            
            titleLabel.topAnchor.constraint(equalTo: advertiserLabel.bottomAnchor, constant: 24),
            titleLabel.leftAnchor.constraint(equalTo: endCard.leftAnchor, constant: 24),
            titleLabel.rightAnchor.constraint(equalTo: endCard.rightAnchor, constant: -24),
            
            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            bodyLabel.leftAnchor.constraint(equalTo: endCard.leftAnchor, constant: 24),
            bodyLabel.rightAnchor.constraint(equalTo: endCard.rightAnchor, constant: -24),
            
            ctaButton.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 24),
            ctaButton.leftAnchor.constraint(equalTo: endCard.leftAnchor, constant: 12),
            ctaButton.rightAnchor.constraint(equalTo: endCard.rightAnchor, constant: -12),
            ctaButton.bottomAnchor.constraint(equalTo: endCard.bottomAnchor, constant: -36),
            
            advertiserAvatar.centerYAnchor.constraint(equalTo: endCard.topAnchor, constant: -6),
            advertiserAvatar.centerXAnchor.constraint(equalTo: endCard.centerXAnchor)
        ])
        
        // Adding subviews
        nativeAdView.addSubviews(bottomShadow, endCard)
        
        NSLayoutConstraint.activate([
            endCard.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            endCard.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            
            // bottomShadow constraints
            bottomShadow.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
            bottomShadow.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
            bottomShadow.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor),
            bottomShadow.topAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
            
            //bottomShadow.heightAnchor.constraint(equalToConstant: UIScreen.main.bounds.width * 280 / 375)
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
        
    }
    
    func configAdLabels(for openAd: NovaAppOpenAd) {
        advertiserLabel.text = openAd.advertiser
        titleLabel.text = openAd.headline
        bodyLabel.text = openAd.body

        //adTagLabel.setTitle(NSLocalizedString("SPONSORED", comment: ""), for: .normal)
        //closeButton.setTitle(NSLocalizedString("Close", comment: ""), for: .normal)
        ctaButton.setTitle(openAd.callToAction, for: .normal)
    }

    func configTapGesture(for openAd: NovaAppOpenAd) {
        //volumeButton.addTarget(self, action: #selector(didTapVolumeButton), for: .touchUpInside)
        //closeButton.addTarget(self, action: #selector(didTapCloseButton), for: .touchUpInside)
        //feedbackButton.addTarget(self, action: #selector(didTapReportButton), for: .touchUpInside)
        nativeAdView.isUserInteractionEnabled = true
        topRightCloseButtonArea.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapCloseButton)))
        
        let tappableViews = getTappableViews()
        for view in tappableViews {
            view.isUserInteractionEnabled = true
            view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapAd(sender:))))
        }
        ctaButton.addTarget(self, action: #selector(didTapAd(sender:)), for: .touchUpInside)
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
    
    private func getTappableViews() -> [UIView] {
        var tappableViews = [UIView]()
        tappableViews = [advertiserAvatar, ctaButton, endCard]
        return tappableViews
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
            if let addStoreId = appOpenAd.appStoreId {
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
}
