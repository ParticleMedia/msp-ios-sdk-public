//
//  MobilefuseInterstitialAd.swift
//  MobilefuseAdapter
//
//  Created by Huanzhi Zhang on 2/5/25.
//

import Foundation
import MSPiOSCore
import MobileFuseSDK


public class MobilefuseInterstitialAd: MSPiOSCore.InterstitialAd {
    public weak var rootViewController: UIViewController?
    public var interstitialAdItem: MFInterstitialAd?

    public override func show() {
        if let interstitialAdItem = self.interstitialAdItem,
           let rootViewController = self.rootViewController {
            rootViewController.view.addSubview(interstitialAdItem)
            interstitialAdItem.show()
        }
    }

    public override func show(rootViewController: UIViewController?) {
        if let interstitialAdItem = self.interstitialAdItem,
           let rootViewController = rootViewController {
            rootViewController.view.addSubview(interstitialAdItem)
            interstitialAdItem.show()
        }
    }
}
