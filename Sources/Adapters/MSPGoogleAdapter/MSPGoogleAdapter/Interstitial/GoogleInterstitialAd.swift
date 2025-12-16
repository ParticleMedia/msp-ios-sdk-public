//
//  GoogleInterstitialAd.swift
//  GoogleAdapter
//
//  Created by Huanzhi Zhang on 10/1/24.
//

import Foundation
import UIKit
import GoogleMobileAds
import MSPiOSCore


public class GoogleInterstitialAd: MSPiOSCore.InterstitialAd {
    public weak var rootViewController: UIViewController?
    public var interstitialAdItem: MSPGADInterstitialAd?
    
    public override func show() {
        // Use unified wrapper function to avoid "Ambiguous use of 'present(from:)'" errors
        // between CocoaPods and SPM versions of GoogleMobileAds
        MSPGADInterstitialAdPresent(interstitialAdItem, from: rootViewController)
    }
    
    public override func show(rootViewController: UIViewController?) {
        // Use unified wrapper function to avoid "Ambiguous use of 'present(from:)'" errors
        // between CocoaPods and SPM versions of GoogleMobileAds
        MSPGADInterstitialAdPresent(interstitialAdItem, from: rootViewController)
    }
    
    public override func isValid() -> Bool {
        return interstitialAdItem != nil
    }
}
