//
//  GoogleNativeAd.swift
//  GoogleAdapter
//
//  Created by Huanzhi Zhang on 6/13/24.
//

import Foundation
//import shared
import MSPiOSCore
import GoogleMobileAds

public class GoogleNativeAd: MSPiOSCore.NativeAd {
    public var nativeAdItem: GoogleMobileAds.NativeAd?
    public var priceInDollar: Double?
    
    public override func isValid() -> Bool {
        return nativeAdItem != nil
    }
}
