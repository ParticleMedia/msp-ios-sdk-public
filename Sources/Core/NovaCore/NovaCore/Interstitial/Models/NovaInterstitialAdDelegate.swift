//
//  NovaInterstitialAdDelegate.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/2/24.
//

import Foundation

public protocol NovaInterstitialAdDelegate: AnyObject {
    func interstitialAdDidDisplay(_ interstitialAd: NovaInterstitialAdItem)
    func interstitialAdDidDismiss(_ interstitialAd: NovaInterstitialAdItem)
    func interstitialAdDidLogClick(_ interstitialAd: NovaInterstitialAdItem)
    // Optional
    func interstitialAdDidFailToDisplay(_ interstitialAd: NovaInterstitialAdItem)
}

public extension NovaInterstitialAdDelegate {
    func interstitialAdDidFailToDisplay(_ interstitialAd: NovaInterstitialAdItem) {}
}
