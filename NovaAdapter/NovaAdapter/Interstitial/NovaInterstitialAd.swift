//
//  NovaInterstitialAd.swift
//  NovaAdapter
//
//  Created by Huanzhi Zhang on 10/2/24.
//

import Foundation
import MSPiOSCore
import NovaCore
import UIKit


public class NovaInterstitialAd: MSPiOSCore.InterstitialAd {
    public var rootViewController: UIViewController?
    public var interstitialAdItem: NovaAppOpenAd?
    
    public override func show() {
        if let rootViewController = rootViewController {
            interstitialAdItem?.present(rootViewController: rootViewController)
        }
    }
}
