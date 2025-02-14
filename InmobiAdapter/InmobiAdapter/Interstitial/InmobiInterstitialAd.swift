//
//  InmobiInterstitialAd.swift
//  InmobiAdapter
//
//  Created by Huanzhi Zhang on 2/5/25.
//
import Foundation
import MSPiOSCore
import InMobiSDK


public class InmobiInterstitialAd: MSPiOSCore.InterstitialAd {
    public weak var rootViewController: UIViewController?
    public var interstitialAdItem: IMInterstitial?

    public override func show() {
        if let interstitialAdItem = self.interstitialAdItem,
           let rootViewController = self.rootViewController,
           interstitialAdItem.isReady() {
            interstitialAdItem.show(from: rootViewController)
        }
    }

    public override func show(rootViewController: UIViewController?) {
        if let interstitialAdItem = self.interstitialAdItem,
           let rootViewController = rootViewController,
           interstitialAdItem.isReady() {
            interstitialAdItem.show(from: rootViewController)
        }
    }
}
