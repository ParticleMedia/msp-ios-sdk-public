//
//  MobilefuseBannerAd.swift
//  MobilefuseAdapter
//
//  Created by Huanzhi Zhang on 2/5/25.
//

import Foundation
import MSPiOSCore
import MobileFuseSDK

public class MobilefuseBannerAd: MSPiOSCore.BannerAd {
    public func show() {
        if let bannerView = self.adView as? MFBannerAd {
            bannerView.show()
        }

    }
}
