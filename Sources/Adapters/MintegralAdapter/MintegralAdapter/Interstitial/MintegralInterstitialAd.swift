//
//  MintegralInterstitialAd.swift
//  MintegralAdapter
//
//  Created by Huanzhi Zhang on 2/5/25.
//

import Foundation
import MSPiOSCore
#if SWIFT_PACKAGE
import MTGSDK
#else
import MTGSDK
import MTGSDKNewInterstitial
#endif


public class MintegralInterstitialAd: MSPiOSCore.InterstitialAd {
    public weak var rootViewController: UIViewController?
    public var mintegralInterstitialAdManager: MTGNewInterstitialBidAdManager?

    public override func show() {
        if let mintegralInterstitialAdManager = self.mintegralInterstitialAdManager,
           let rootViewController = self.rootViewController {
            mintegralInterstitialAdManager.show(from: rootViewController)
        }
    }

    public override func show(rootViewController: UIViewController?) {
        if let mintegralInterstitialAdManager = self.mintegralInterstitialAdManager,
           let rootViewController = rootViewController {
            mintegralInterstitialAdManager.show(from: rootViewController)
        }
    }
}
