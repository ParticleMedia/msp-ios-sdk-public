//
//  UnityInterstitialAd.swift
//  UnityAdapter
//
//  Created by Huanzhi Zhang on 1/2/25.
//

import Foundation
import MSPiOSCore
import IronSource


public class UnityInterstitialAd: MSPiOSCore.InterstitialAd {
    public weak var rootViewController: UIViewController?
    public var interstitialAdItem: LPMInterstitialAd?
    
    public override func show() {
        if let interstitialAdItem = self.interstitialAdItem,
           let rootViewController = self.rootViewController,
           interstitialAdItem.isAdReady() {
            interstitialAdItem.showAd(viewController: rootViewController, placementName: nil)
        }
    }
    
    public override func show(rootViewController: UIViewController?) {
        if let interstitialAdItem = self.interstitialAdItem,
           let rootViewController = rootViewController,
           interstitialAdItem.isAdReady() {
            interstitialAdItem.showAd(viewController: rootViewController, placementName: nil)
        }
    }
}
