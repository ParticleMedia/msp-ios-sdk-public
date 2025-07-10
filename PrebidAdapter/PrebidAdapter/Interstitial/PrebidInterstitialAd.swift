//
//  PrebidInterstitialAd.swift
//  PrebidAdapter
//
//  Created by Huanzhi Zhang on 7/9/25.
//

import Foundation
import MSPiOSCore
import UIKit
import PrebidMobile


public class PrebidInterstitialAd: MSPiOSCore.InterstitialAd {
    public weak var rootViewController: UIViewController?
    public var interstitialRenderingAdUnit: InterstitialRenderingAdUnit?
    
    public override func show() {
        if let rootViewController = rootViewController {
            interstitialRenderingAdUnit?.show(from: rootViewController)
        }
    }
    
    public override func show(rootViewController: UIViewController?) {
        if let rootViewController = rootViewController {
            interstitialRenderingAdUnit?.show(from: rootViewController)
        }
    }
}
