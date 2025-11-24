//
//  UnityNativeAd.swift
//  UnityAdapter
//
//  Created by Huanzhi Zhang on 1/2/25.
//

import Foundation
import MSPiOSCore
#if SWIFT_PACKAGE
import IronSourceSDKWrapper
#else
import IronSource
#endif

public class UnityNativeAd: NativeAd {
    public var nativeAdItem: LevelPlayNativeAd?
    public var priceInDollar: Double?
}
