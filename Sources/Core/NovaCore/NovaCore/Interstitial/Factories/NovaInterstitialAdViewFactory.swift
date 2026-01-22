//
//  NovaInterstitialAdViewFactory.swift
//  NovaCore
//
//  Created by Patrick on 2025/1/27.
//

// MARK: - NovaInterstitialAdViewFactory

import Foundation
import UIKit

class NovaInterstitialAdViewFactory: NSObject {
    // MARK: Internal

    static func createAdView(
        interstitialAd: NovaInterstitialAdItem,
        viewController: UIViewController,
        reportHandling: any NovaInterstitialAdReportHandling
    ) -> NovaInterstitialAdViewProtocol {
        let context = NovaInterstitialAdContext(
            interstitialAd: interstitialAd,
            layout: interstitialAd.layoutStyle,
            tracingId: nil
        )
        return NovaInterstitialAdNormalView(
            context: context,
            viewController: viewController,
            reportHandling: reportHandling
        )
    }
}
