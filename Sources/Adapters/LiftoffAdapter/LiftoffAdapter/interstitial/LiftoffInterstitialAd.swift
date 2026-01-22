//
//  LiftoffInterstitialAd.swift
//  LiftoffAdapter
//
//  Created by Mingming Luo on 2025/12/9.
//

import Foundation
import MSPiOSCore
import UIKit
import VungleAdsSDK

public class LiftoffInterstitialAd: MSPiOSCore.InterstitialAd {
    public weak var rootViewController: UIViewController?
    public var interstitialAdItem: VungleInterstitial?

    public override func show() {
        if let interstitialAdItem = self.interstitialAdItem,
            let rootViewController = self.rootViewController
        {
            DispatchQueue.main.async {
                interstitialAdItem.present(with: rootViewController)
            }
        }
    }

    public override func show(rootViewController: UIViewController?) {
        if let interstitialAdItem = self.interstitialAdItem,
            let rootViewController = rootViewController
        {
            DispatchQueue.main.async {
                interstitialAdItem.present(with: rootViewController)
            }
        }
    }
}
