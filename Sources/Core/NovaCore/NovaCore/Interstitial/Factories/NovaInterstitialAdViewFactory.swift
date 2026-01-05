//
//  NovaInterstitialAdViewFactory.swift
//  NovaCore
//
//  Created by Patrick on 2025/1/27.
//

import Foundation
import UIKit

// MARK: - NovaInterstitialAdViewFactory

class NovaInterstitialAdViewFactory: NSObject {
    // MARK: Internal

    static func createAdView(
        interstitialAd: NovaInterstitialAdItem,
        viewController: UIViewController,
        reportHandling: any NovaInterstitialAdReportHandling,
        pageIndex: Int? = nil,
        pageDelegate: NovaInterstitialMultiPageDelegate
    ) -> NovaInterstitialAdViewProtocol {
        let context = NovaInterstitialAdContext(
            interstitialAd: interstitialAd,
            layout: interstitialAd.layoutStyle,
            tracingId: nil,
            pageIndex: pageIndex
        )
        if case .html = interstitialAd.creativeType {
            return NovaInterstitialAdPageView(context: context,
                                              viewController: viewController,
                                              reportHandling: reportHandling,
                                              pageDelegate: pageDelegate)
        } else {
            return NovaInterstitialAdNormalView(
                context: context,
                viewController: viewController,
                reportHandling: reportHandling
            )
        }
    }
} 
