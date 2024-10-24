//
//  FacebookInterstitialAd.swift
//  FacebookAdapter
//
//  Created by Huanzhi Zhang on 10/23/24.
//

import Foundation
import MSPiOSCore
import FBAudienceNetwork


public class FacebookInterstitialAd: MSPiOSCore.InterstitialAd {
    public var rootViewController: UIViewController?
    public var interstitialAdItem: FBInterstitialAd?
    
    public override func show() {
        interstitialAdItem?.show(fromRootViewController: nil)
    }
    
    public override func show(rootViewController: UIViewController?) {
        interstitialAdItem?.show(fromRootViewController: rootViewController)
    }
}
