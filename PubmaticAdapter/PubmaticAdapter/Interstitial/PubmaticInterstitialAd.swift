//
//  PubmaticInterstitialAd.swift
//  PubmaticAdapter
//
//  Created by Huanzhi Zhang on 2/5/25.
//

import Foundation
import MSPiOSCore
import OpenWrapSDK


public class PubmaticInterstitialAd: MSPiOSCore.InterstitialAd {
    public weak var rootViewController: UIViewController?
    public var interstitialAdItem: POBInterstitial?

    public override func show() {
        if let interstitialAdItem = self.interstitialAdItem,
           let rootViewController = self.rootViewController {
            interstitialAdItem.show(from: rootViewController)
        }
    }

    public override func show(rootViewController: UIViewController?) {
        if let interstitialAdItem = self.interstitialAdItem,
           let rootViewController = rootViewController {
            interstitialAdItem.show(from: rootViewController)
        }
    }
}
