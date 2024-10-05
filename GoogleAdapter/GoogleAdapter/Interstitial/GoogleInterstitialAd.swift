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
        if let rootViewController = rootViewController {
            interstitialAdItem?.present(fromRootViewController: rootViewController)
        }
    }
}
