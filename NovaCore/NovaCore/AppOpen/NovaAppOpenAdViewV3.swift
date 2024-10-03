//
//  NovaAppOpenAdViewV3.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/2/24.
//

import Foundation
import UIKit

@objc public class NovaAppOpenAdViewV3: UIView {
    // MARK: - Constants
    private enum Constants {
        static let closeButtonSize: Double = 48
    }

    // MARK: - Properties

    private let media: NovaNativeAdMedia
    private let appOpenAd: NovaAppOpenAd
    
    private let actionHandler: ActionHandling

    private let startTime: CFTimeInterval

    private let adLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = UIColor(light: NovaColorPalettes.Black.nb_opacity6(), dark: NovaColorPalettes.White.nb_opacity6())
        label.numberOfLines = 1
        label.text = NSLocalizedString("Advertisement ", comment: "")
        return label
    }()

    private let mediaView: NovaNativeAdMediaViewV2 = {
        let view = NovaNativeAdMediaViewV2()
        view.accessibilityIdentifier = "media"
        return view
    }()

    private let advertiserLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18)
        label.textColor = UIColor(light: NovaColorPalettes.Black.nb_opacity6(), dark: NovaColorPalettes.White.nb_opacity6())
        label.numberOfLines = 1
        label.accessibilityIdentifier = "advertiser"
        return label
    }()
    
    private let feedbackButton: UIButton = {
        let button = UIButton()
        let image = UIImage(
            novasystemName: .ellipsisHorizontalOutline,
            tintColor: UIColor(light: NovaColorPalettes.Gray.tint500, dark: NovaColorPalettes.Gray.tint200))
        button.setImage(image, for: .normal)
        return button
    }()

    private let headlineLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 28, weight: .semibold)
        label.textColor = UIColor(light: NovaColorPalettes.Black.nb_opacity8(), dark: NovaColorPalettes.White.nb_opacity9())
        label.numberOfLines = 4
        label.lineBreakMode = .byWordWrapping
        if #available(iOS 14.0, *) {
            label.lineBreakStrategy = []
        } else {}
        label.accessibilityIdentifier = "headline"
        return label
    }()

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18)
        label.textColor = UIColor(light: NovaColorPalettes.Black.nb_opacity6(), dark: NovaColorPalettes.White.nb_opacity6())
        label.numberOfLines = 4
        label.accessibilityIdentifier = "body"
        return label
    }()

    private let ctaButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = NovaColorPalettes.Blue.tint500
        button.layer.cornerRadius = 8
        button.clipsToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.accessibilityIdentifier = "cta"
        return button
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton()
        button.layer.borderWidth = 1
        button.layer.borderColor = NovaColorPalettes.Gray.tint300.cgColor
        button.layer.cornerRadius = 8
        button.clipsToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.setTitleColor(UIColor(light: NovaColorPalettes.Black.nb_opacity8(), dark: NovaColorPalettes.White.nb_opacity9()), for: .normal)
        return button
    }()

    init(with media: NovaNativeAdMedia, openAd: NovaAppOpenAd, actionHandler: ActionHandling) {
        self.media = media
        self.appOpenAd = openAd
        self.actionHandler = actionHandler
        self.startTime = CACurrentMediaTime()

        super.init(frame: .zero)

        backgroundColor = UIColor(light: NovaColorPalettes.White, dark: NovaColorPalettes.Gray.tint700)
        setupGestures()
        setupSubviews()
        bindAppOpenAd()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func mediaStartShown() {
        mediaView.mediaStartShown()
    }
    
    func mediaEndShown() {
        mediaView.mediaEndShown()
    }
}

// MARK: - Private functions

private extension NovaAppOpenAdViewV3 {
    func bindAppOpenAd() {
        mediaView.config(with: media)
        
        if let advertiser = appOpenAd.advertiser?.trimmingCharacters(in: .whitespacesAndNewlines), !advertiser.isEmpty {
            advertiserLabel.text = advertiser
        }
        if let headline = appOpenAd.headline?.trimmingCharacters(in: .whitespacesAndNewlines), !headline.isEmpty {
            headlineLabel.text = headline
        }
        if let body = appOpenAd.body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
            bodyLabel.text = body
        }
        ctaButton.setTitle(appOpenAd.callToAction, for: .normal)
        closeButton.setTitle(NSLocalizedString("Close", comment: ""), for: .normal)
    }
    
    func setupGestures() {
        closeButton.addTarget(self, action: #selector(didTapCloseButton), for: .touchUpInside)
        feedbackButton.addTarget(self, action: #selector(didTapReportButton), for: .touchUpInside)

        let tappableViews = [mediaView, advertiserLabel, headlineLabel, bodyLabel, ctaButton]
        for view in tappableViews {
            view.isUserInteractionEnabled = true
            view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapAd(sender:))))
        }
    }
    
    func setupSubviews() {
        addSubviews([adLabel, mediaView, advertiserLabel, feedbackButton, headlineLabel, bodyLabel, closeButton, ctaButton])
        adLabel.snp.makeConstraints { make in
            make.top.equalTo(UIApplication.shared.nova_safeAreaInsets.top + 16)
            make.leading.equalTo(16)
        }
        mediaView.snp.makeConstraints { make in
            make.top.equalTo(self.adLabel.snp.bottom).offset(16)
            make.leading.equalTo(16)
            make.trailing.equalTo(-16)
            make.height.equalTo(self.mediaView.snp.width)
                .multipliedBy(Double(1.0 / AdsMediaConstants.defaultAspectRatio))
        }
        advertiserLabel.snp.makeConstraints { make in
            make.top.equalTo(self.mediaView.snp.bottom).offset(24)
            make.leading.equalTo(16)
            make.trailing.lessThanOrEqualTo(feedbackButton.snp.leading).offset(-16)
        }
        feedbackButton.snp.makeConstraints { make in
            make.centerY.equalTo(advertiserLabel)
            make.trailing.equalTo(-16)
            make.width.height.equalTo(24)
        }
        headlineLabel.snp.makeConstraints { make in
            make.top.equalTo(self.advertiserLabel.snp.bottom).offset(20)
            make.leading.equalTo(16)
            make.trailing.equalTo(-16)
        }
        bodyLabel.snp.makeConstraints { make in
            make.top.equalTo(self.headlineLabel.snp.bottom).offset(36)
            make.leading.equalTo(16)
            make.trailing.lessThanOrEqualTo(-16)
        }
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(self.bodyLabel.snp.bottom).offset(72)
            make.height.equalTo(40)
            make.leading.equalTo(16)
            make.trailing.equalTo(self.snp.centerX).offset(-8)
        }
        ctaButton.snp.makeConstraints { make in
            make.top.equalTo(self.closeButton)
            make.leading.equalTo(self.snp.centerX).offset(8)
            make.height.equalTo(40)
            make.trailing.equalTo(-16)
        }
        
        feedbackButton.isHidden = true
    }
    
    @objc func didTapReportButton() {
        //let reportActionModel = ActionModel(
        //    actionKey: NovaAppOpenAdViewActionKey.feedbackReport.rawValue,
        //    actionDataModel: NovaAppOpenAdFeedBackReportActionModel(appOpenAd: appOpenAd)
        //)
        //actionHandler.performAction(actionModel: reportActionModel)
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
            ad: appOpenAd
        )

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
            clickArea: sender.view?.accessibilityIdentifier
        )
    }
}

