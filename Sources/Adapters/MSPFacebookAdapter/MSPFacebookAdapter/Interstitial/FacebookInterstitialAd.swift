//
//  FacebookInterstitialAd.swift
//  FacebookAdapter
//
//  Created by Huanzhi Zhang on 10/23/24.
//

import FBAudienceNetwork
import Foundation
import MSPiOSCore
import UIKit

public class FacebookInterstitialAd: MSPiOSCore.InterstitialAd {
    public weak var rootViewController: UIViewController?
    public var interstitialAdItem: FBInterstitialAd?

    public override func show() {
        interstitialAdItem?.show(fromRootViewController: nil)
    }

    public override func show(rootViewController: UIViewController?) {
        interstitialAdItem?.show(fromRootViewController: rootViewController)
    }

    public override func isValid() -> Bool {
        interstitialAdItem?.isAdValid ?? false
    }
}
