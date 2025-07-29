//
//  NovaAppOpenAdEndCardView.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 6/11/25.
//
import UIKit

@objc public class NovaAppOpenAdEndCardView: UIView {
    private let appOpenAd: NovaAppOpenAd
    private let actionHandler: ActionHandling
    private let startTime: CFTimeInterval
    
    private enum LayoutMetrics {
        static let avatarSize = 60.0
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
        imageView.adClickArea = .icon_endcard
        return imageView
    }()

    private let advertiserLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.headline2
        label.textColor = NovaColorPalettes.Black
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adClickArea = .advertiser_endcard
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
        label.adClickArea = .body_endcard
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
        label.adClickArea = .body_endcard
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

        button.adClickArea = .cta_endcard

        return button
    }()
    
    init(appOpenAd: NovaAppOpenAd,  actionHandler: ActionHandling, viewController: UIViewController) {
        
        self.actionHandler = actionHandler
        self.appOpenAd = appOpenAd
        
        let adOpenActionHandler = NovaAdOpenActionHandler(viewController: viewController)
        let actionHandlerMaster = ActionHandlerMaster(actionHandlers: [adOpenActionHandler])
        self.startTime = CACurrentMediaTime()
        
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
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.layer.cornerRadius = 24
        self.backgroundColor = NovaColorPalettes.White
        self.isUserInteractionEnabled = true

        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        advertiserAvatar.translatesAutoresizingMaskIntoConstraints = false

        self.addSubviews(advertiserLabel, titleLabel, bodyLabel, ctaButton, advertiserAvatar)
        
        NSLayoutConstraint.activate([
            
            advertiserLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 36),
            advertiserLabel.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 24),
            advertiserLabel.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -24),
            
            titleLabel.topAnchor.constraint(equalTo: advertiserLabel.bottomAnchor, constant: 24),
            titleLabel.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 24),
            titleLabel.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -24),
            
            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            bodyLabel.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 24),
            bodyLabel.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -24),
            
            ctaButton.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 24),
            ctaButton.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 12),
            ctaButton.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -12),
            ctaButton.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -36),
            
            advertiserAvatar.centerYAnchor.constraint(equalTo: self.topAnchor, constant: -6),
            advertiserAvatar.centerXAnchor.constraint(equalTo: self.centerXAnchor)
        ])
    }
    
    func configAdLabels(for openAd: NovaAppOpenAd) {
        advertiserLabel.text = openAd.advertiser
        titleLabel.text = openAd.headline
        bodyLabel.text = openAd.body

        ctaButton.setTitle(openAd.callToAction, for: .normal)
    }

    func configTapGesture(for openAd: NovaAppOpenAd) {
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
        tappableViews = [advertiserAvatar, ctaButton, self]
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

        NovaAdMetricReporter.logAdClick(
            thirdPartyClickTrackingUrls: appOpenAd.thirdPartyClickTrackingUrls,
            encryptedAdToken: appOpenAd.encryptedAdToken,
            adUnitId: appOpenAd.adUnitId,
            durationInMs: Int((clickTime - startTime) * 1000),
            clickArea: sender.view?.adClickArea)
    }
}
