//
//  GoogleNativeAd.swift
//  GoogleAdapter
//
//  Created by Huanzhi Zhang on 6/13/24.
//

//import shared
import Foundation
import GoogleMobileAds
import MSPGoogleAdsTypes
import MSPiOSCore

public class GoogleNativeAd: MSPiOSCore.NativeAd {
    public var nativeAdItem: MSPGADNativeAd?
    public var priceInDollar: Double?

    public override func isValid() -> Bool {
        nativeAdItem != nil
    }
}
