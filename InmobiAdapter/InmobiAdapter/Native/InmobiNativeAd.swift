//
//  InmobiNativeAd.swift
//  InmobiAdapter
//
//  Created by Huanzhi Zhang on 2/5/25.
//

import Foundation
import MSPiOSCore
#if SWIFT_PACKAGE
import InMobiSDKWrapper
#else
import InMobiSDK
#endif

public class InmobiNativeAd: NativeAd {
    public var nativeAdItem: IMNative?
    public var priceInDollar: Double?
}
