//
//  NovaInterstitialAdNormalView.swift
//  NovaCore
//
//  Created by Patrick on 2025/1/27.
//

import Foundation
import UIKit
@_implementationOnly import SnapKit

// MARK: - NovaInterstitialAdNormalView

class NovaInterstitialAdNormalView: UIView, NovaInterstitialAdViewProtocol {
    // logging
    private let startTime: CFTimeInterval
    
    // MARK: Lifecycle

    init(
        context: NovaInterstitialAdContext,
        viewController: UIViewController,
        reportHandling: (any NovaInterstitialAdReportHandling)
    ) {
        self.context = context
        self.viewController = viewController
        self.startTime = CACurrentMediaTime()
        self.reportHandling = reportHandling

        // Initialize NovaActionHelper
        self.actionHelper = NovaActionHelper.build(
            with: .adInViewController(
                model: AdActionModel(
                    tracingInfo: context.interstitialAd.actionTracingInfo,
                    extraInfo: context.interstitialAd.actionExtraInfo,
                    ctrType: context.interstitialAd.adCtrType
                ),
                viewController: Weak(viewController)
            )
        )
        
        super.init(frame: .zero)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - NovaInterstitialAdViewProtocol

    func setupSubviews() {
        // Create subview handler using the creator
        subviewHandler = NovaInterstitialAdSubviewHandlerCreator.create(
            interstitialAd: context.interstitialAd,
            delegate: self,
            viewController: viewController
        )

        // Setup subviews in this view
        subviewHandler
            .setupSubviews(
                in: self,
                showReportButton: reportHandling.novaCanShowReportButton(with: context.interstitialAd.novaAdReportContext)
            )
        subviewHandler.config()

        // Setup tap gesture
        setupTapGesture()
    }

    func didAppear() {
        subviewHandler.didAppear()
    }

    func didDisappear() {
        subviewHandler.didDisappear()
    }

    func willAppear() {
        subviewHandler.willAppear()
    }

    func willDisappear() {
        subviewHandler.willDisappear()
    }

    // MARK: Private

    private func setupTapGesture() {
        for clickableView in subviewHandler.clickableViews {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapAd(sender:)))
            clickableView.addGestureRecognizer(tapGesture)
            clickableView.isUserInteractionEnabled = true
        }
    }

    @objc func didTapAd(sender: UITapGestureRecognizer) {
        let clickArea = sender.view?.adClickArea ?? .cta
        let nbClickArea = ClickableAdArea(rawValue: clickArea.rawValue) ?? .cta
        actionHelper = actionHelper
            .logNovaClickEvent(with: CACurrentMediaTime() - startTime, in: nbClickArea)
            .handleAdTap(in: sender.view)
    }

    private let context: NovaInterstitialAdContext
    private var actionHelper: NovaActionHelper<NovaActionState.Init>
    private let reportHandling: any NovaInterstitialAdReportHandling

    private var playableActionHelper: NovaActionHelper<NovaActionState.Init>?
    
    private weak var viewController: UIViewController?
    private var subviewHandler: NovaInterstitialAdSubviewHandler!
}

extension NovaInterstitialAdNormalView: NovaInterstitialAdSubviewBehaviorDelegate {
    // MARK: - NovaInterstitialAdSubviewBehaviorDelegate

    func didTapFeedbackButton() {
        reportHandling
            .novaStartReportFlow(
                from: viewController,
                context: context.interstitialAd.novaAdReportContext
            )
    }

    func didTapCloseButton() {
        actionHelper = actionHelper
            .logNovaSkipEvent(with: .skipButton, duration: CACurrentMediaTime() - CACurrentMediaTime())
            .handleCloseTap()
        context.interstitialAd.delegate?.interstitialAdDidDismiss(context.interstitialAd)
    }
    
    func didTapPlayableAd(with playableModel: PlayableModel) {
        // Create a new action helper for playable ad
        playableActionHelper = NovaActionHelper.build(
            with: .adInViewController(
                model: AdActionModel(
                    tracingInfo: context.interstitialAd.actionTracingInfo,
                    extraInfo: context.interstitialAd.actionExtraInfo,
                    ctrType: playableModel.launchAdType
                ),
                viewController: Weak(viewController)
            )
        )
        
        playableActionHelper = playableActionHelper?
            .logNovaClickEvent(with: CACurrentMediaTime() - CACurrentMediaTime(), in: .playable)
            .handleAdTap(in: nil)
    }
}
