//
//  NovaInterstitialAdPageView.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 11/10/25.
//
import UIKit

class NovaInterstitialAdPageView: NovaInterstitialAdNormalView {
    
    weak var pageDelegate: NovaInterstitialMultiPageDelegate?
    
    public init(context: NovaInterstitialAdContext,
                 viewController: UIViewController,
                 reportHandling: (any NovaInterstitialAdReportHandling),
                 pageDelegate: NovaInterstitialMultiPageDelegate?) {
        self.pageDelegate = pageDelegate
        super.init(context: context, viewController: viewController, reportHandling: reportHandling)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didTapSkipButton() {
        pageDelegate?.novaInterstitialDidSkipPage()
    }
    
    override func setupSubviews() {
        // Create subview handler using the creator
        subviewHandler = NovaInterstitialAdSubviewHandlerCreator.create(
            interstitialAd: context.interstitialAd,
            delegate: self,
            viewController: viewController,
            pageIndex: self.context.pageIndex
        )

        // Setup subviews in this view
        subviewHandler
            .setupSubviews(
                in: self,
                showReportButton: reportHandling.novaCanShowReportButton(with: context.interstitialAd.novaAdReportContext)
            )
        if let pageIndex = context.pageIndex {
            subviewHandler.configPage(pageIndex: pageIndex, htmlJSMessageDelegate: self, context: context)
        }

        // Setup tap gesture
        setupTapGesture()
    }

}

extension NovaInterstitialAdPageView: NovaAdHtmlJSMessageDelegate {
    func didTapAdCtr(customUrl: URL?) {
        self.didTapAd(customUrl: customUrl)
    }
    
    func didTapAdReport() {
        self.didTapFeedbackButton()
        print("did tap feedback button")
    }
    
    func didTapAdClose() {
        self.didTapSkipButton()
    }
    
}
