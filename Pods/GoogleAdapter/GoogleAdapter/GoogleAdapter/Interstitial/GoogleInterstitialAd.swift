//
//  GoogleInterstitialAd.swift
//  GoogleAdapter
//
//  Created by Huanzhi Zhang on 10/1/24.
//

import Foundation
import GoogleMobileAds
import MSPiOSCore


public class GoogleInterstitialAd: MSPiOSCore.InterstitialAd {
    public var rootViewController: UIViewController?
    public var interstitialAdItem: GADInterstitialAd?
    
    public override func show() {
        interstitialAdItem?.present(fromRootViewController: rootViewController)
    }
    
    public override func show(rootViewController: UIViewController?) {
        interstitialAdItem?.present(fromRootViewController: rootViewController)
    }
}
