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
        viewController: UIViewController
    ) -> NovaInterstitialAdViewProtocol {
        let context = NovaInterstitialAdContext(
            interstitialAd: interstitialAd,
            layout: interstitialAd.layoutStyle,
            tracingId: nil
        )
        
        return NovaInterstitialAdNormalView(
            context: context,
            viewController: viewController
        )
    }
} 
