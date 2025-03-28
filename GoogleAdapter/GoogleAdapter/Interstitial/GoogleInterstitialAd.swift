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
    public weak var rootViewController: UIViewController?
    public var interstitialAdItem: GoogleMobileAds.InterstitialAd?
    
    public override func show() {
        interstitialAdItem?.present(from: rootViewController)
    }
    
    public override func show(rootViewController: UIViewController?) {
        interstitialAdItem?.present(from: rootViewController)
    }
}
