//
//  NovaInterstitialAdH5SubviewHandler.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/29/25.
//
import Foundation
import UIKit
import WebKit
@_implementationOnly import SnapKit

class NovaInterstitialAdHtmlSubviewHandler: NovaInterstitialAdSubviewHandler, NovaTopRightClosable {
    var darkColor: UIColor { NovaColorPalettes.Gray.tint200 }
    
    enum LayoutMetrics {
        static let avatarSize = 24.0
        static let horizontalMargin = 16.0
        static let bottomButtonBottomMargin = 24.0
        static let bottomButtonHeight = 48.0
        static let bottomButtonWidth = 156.0
        static let volumeButtonWidth = 32.0
        static let volumeButtonBottomMargin = 28.0
    }
    
    private let interstitialAd: NovaInterstitialAdItem
    private weak var delegate: NovaInterstitialAdSubviewBehaviorDelegate?
    private weak var viewController: UIViewController?
    private weak var parentView: UIView?
    var countdownTimer: Timer?
    let countdownSecondRemaining: Int
    var delayTimer: Timer?
    var delaySecondRemaining: Int?
    var pageIndex: Int?
    
    private let showTopRightCloseButton: Bool
    
    var clickableViews = [UIView]()
    
    private(set) lazy var topRightCloseButton: UIButton = {
        let button = UIButton()
        button.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapCloseButton)))
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .regular)
        button.setTitleColor(UIColor.white, for: .normal)
        button.layer.cornerRadius = 8
        button.backgroundColor = NovaColorPalettes.Gray.tint600.withAlphaComponent(0.5)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.isUserInteractionEnabled = false
        return button
    }()
    
    private(set) lazy var topRightCloseButtonArea: UIView = {
        let view = UIView()
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapCloseButton)))
        return view
    }()
    
    private lazy var mediaView: NovaAdMediaView = {
        let view = NovaAdMediaView()
        view.adClickArea = .media
        return view
    }()
    
    private var htmlView: NovaAdHtmlView?
    
    init(
       interstitialAd: NovaInterstitialAdItem,
       showTopRightCloseButton: Bool,
       delegate: NovaInterstitialAdSubviewBehaviorDelegate,
       viewController: UIViewController?,
       pageIndex: Int?
    ) {
        self.interstitialAd = interstitialAd
        self.delegate = delegate
        self.viewController = viewController
        self.showTopRightCloseButton = showTopRightCloseButton
        self.pageIndex = pageIndex
        if case .html = interstitialAd.creativeType,
           let model = interstitialAd.htmlModel,
           let pageIndex = pageIndex,
           pageIndex >= 0 && pageIndex < model.pages.count {
            self.countdownSecondRemaining = model.pages[pageIndex].closeCountDownSeconds ?? 0
            self.delaySecondRemaining = model.pages[pageIndex].closeDelaySeconds ?? 0
        } else {
            self.countdownSecondRemaining = interstitialAd.closeCountDownTimeSeconds ?? 0
            self.delaySecondRemaining = 0
        }
    }
    
    func setupSubviews(in containerView: UIView, showReportButton: Bool) {
        self.parentView = containerView
        let htmlView = NovaAdHtmlView()
        self.htmlView = htmlView
        containerView.addSubview(htmlView)

        htmlView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        if showTopRightCloseButton {
            containerView.addSubview(topRightCloseButton)
            topRightCloseButton.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(64)
                make.trailing.equalToSuperview().offset(-16)
                make.height.equalTo(32)
                make.width.greaterThanOrEqualTo(32)
            }
        }
        print("set up delay timer")
        setupDelayTimerIfNeeded()
    }
    
    func config() {
        
    }
    
    func configPage(pageIndex: Int, htmlJSMessageDelegate: NovaAdHtmlJSMessageDelegate?, context: NovaInterstitialAdContext?) {
        if let htmlModel = interstitialAd.htmlModel,
           pageIndex >= 0 && pageIndex < htmlModel.pages.count {
            htmlView?.config(with: htmlModel.pages[pageIndex], htmlJSMessageDelegate: htmlJSMessageDelegate, context: context)
        }
    }
    
    @objc private func didTapCloseButton() {
        htmlView?.removeFromSuperview()
        htmlView?.pauseAllMediaPlayback()
        htmlView = nil
        delegate?.didTapSkipButton()
    }
    
    func didAppear() {
        htmlView?.setAllMediaPlaybackSuspended(false, completionHandler: nil)
    }
    
    func willDisappear() {
        htmlView?.setAllMediaPlaybackSuspended(true, completionHandler: nil)
    }
    
    func enableTopRightCloseButton(button: UIButton, clickableArea: UIView) {
        topRightCloseButton.isUserInteractionEnabled = true
        if case .html = self.interstitialAd.creativeType,
           let model = self.interstitialAd.htmlModel,
           let pageIndex = pageIndex,
           pageIndex >= 0 && pageIndex < model.pages.count - 1 {
            // not the last page
            configTopRightButtonForSkip()
        } else {
            configTopRightButtonForClose()
        }
    }
    
    func configTopRightButtonForSkip() {
        topRightCloseButton.setTitle(nil, for: .normal)

        topRightCloseButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .white       // text + chevron should be white since bg is translucent
        config.attributedTitle = AttributedString("SKIP")
        let font = UIFont.systemFont(ofSize: 14, weight: .medium)
        config.image = UIImage(systemName: "chevron.right")
        config.imagePlacement = .trailing
        config.imagePadding = 4

        config.contentInsets = NSDirectionalEdgeInsets(
            top: 8,
            leading: 12,
            bottom: 8,
            trailing: 10
        )
        topRightCloseButton.configuration = config
        topRightCloseButton.translatesAutoresizingMaskIntoConstraints = false
    }
    
    func configTopRightButtonForClose() {
        topRightCloseButton.setTitle(nil, for: .normal)

        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "xmark")
        config.baseForegroundColor = .white

        config.preferredSymbolConfigurationForImage =
            UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)

        config.contentInsets = NSDirectionalEdgeInsets(
            top: 6, leading: 6, bottom: 6, trailing: 6
        )

        topRightCloseButton.configuration = config

    }
}
