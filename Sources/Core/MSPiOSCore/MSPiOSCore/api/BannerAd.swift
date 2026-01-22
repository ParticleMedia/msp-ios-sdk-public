//
//  BannerAd.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 8/29/24.
//

import Foundation
import UIKit

open class BannerAd: MSPAd {
    public var adView: UIView

    public init(adView: UIView, adNetworkAdapter: AdNetworkAdapter) {
        self.adView = adView
        super.init(adNetworkAdapter: adNetworkAdapter)
    }
}
