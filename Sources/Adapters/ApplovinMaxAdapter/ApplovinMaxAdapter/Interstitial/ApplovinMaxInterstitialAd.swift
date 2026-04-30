//
//  ApplovinMaxInterstitialAd.swift
//  ApplovinMaxAdapter
//

import AppLovinSDK
import Foundation
import MSPiOSCore

public class ApplovinMaxInterstitialAd: MSPiOSCore.InterstitialAd {
    public var maxInterstitialAd: MAInterstitialAd?

    public override func show() {
        if let maxInterstitialAd = self.maxInterstitialAd, maxInterstitialAd.isReady {
            maxInterstitialAd.show()
        }
    }

    public override func show(rootViewController: UIViewController?) {
        show()
    }

    public override func isValid() -> Bool {
        maxInterstitialAd?.isReady ?? false
    }
}
