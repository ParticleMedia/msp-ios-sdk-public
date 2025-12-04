//
//  MolocoInterstitialAd.swift
//  MolocoAdapter
//
//  Created by Mingming Luo on 2025/11/19.
//

import Foundation
import MSPiOSCore
import MolocoSDK
import UIKit

public class MolocoInterstitialAd: MSPiOSCore.InterstitialAd {
    public weak var rootViewController: UIViewController?
    public var interstitialAdItem: MolocoInterstitial?
    
    public override func show() {
        if let interstitialAdItem = self.interstitialAdItem,
           let rootViewController = self.rootViewController {
            DispatchQueue.main.async {
                interstitialAdItem.show(from: rootViewController)
            }
        }
    }
    
    public override func show(rootViewController: UIViewController?) {
        if let interstitialAdItem = self.interstitialAdItem,
           let rootViewController = rootViewController {
            DispatchQueue.main.async {
                interstitialAdItem.show(from: rootViewController)
            }
        }
    }
}
