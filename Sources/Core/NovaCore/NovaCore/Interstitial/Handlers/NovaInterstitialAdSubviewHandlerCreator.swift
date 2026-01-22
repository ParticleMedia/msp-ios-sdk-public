//
//  NovaInterstitialAdSubviewHandlerCreator.swift
//  NovaCore
//
//  Created by Patrick on 2025/1/27.
//

// MARK: - NovaInterstitialAdSubviewHandlerCreator

import Foundation
import UIKit

class NovaInterstitialAdSubviewHandlerCreator {
    // MARK: Internal

    static func create(
        interstitialAd: NovaInterstitialAdItem,
        delegate: NovaInterstitialAdSubviewBehaviorDelegate,
        viewController: UIViewController?
    ) -> NovaInterstitialAdSubviewHandler {
        // Prefer playable variants when creativeType indicates playable
        switch interstitialAd.layoutTypeInInterstitial {
        case .horizontal(let showTopRightCloseButton):
            return NovaInterstitialAdHorizontalSubviewHandler(
                interstitialAd: interstitialAd,
                showTopRightCloseButton: showTopRightCloseButton,
                delegate: delegate,
                viewController: viewController
            )
        case .vertical(let showTopRightCloseButton):
            return NovaInterstitialAdVerticalSubviewHandler(
                interstitialAd: interstitialAd,
                showTopRightCloseButton: showTopRightCloseButton,
                delegate: delegate,
                viewController: viewController
            )
        case .playable:
            return NovaInterstitialAdPlayableSubviewHandler(interstitialAd: interstitialAd, delegate: delegate)
        case .twoPartPlayable:
            return NovaInterstitialAdTwoPartPlayableSubviewHandler(
                interstitialAd: interstitialAd,
                delegate: delegate,
                viewController: viewController
            )
        case .skOverlay(let appStoreId, let thirdPartyTrackingURL):
            return NovaInterstitialAdSKOverlaySubviewHandler(
                interstitialAd: interstitialAd,
                delegate: delegate,
                viewController: viewController,
                appStoreId: appStoreId,
                thirdPartyTrackingURL: thirdPartyTrackingURL
            )

        case let .html(model):
            return NovaInterstitialAdPageSubviewHandler(
                interstitialAd: interstitialAd,
                delegate: delegate,
                viewController: viewController,
                htmlMediaModel: model
            )
        }
    }
}
