//
//  MobilefuseNativeAd.swift
//  MobilefuseAdapter
//
//  Created by Huanzhi Zhang on 2/5/25.
//

import Foundation
import MSPiOSCore
#if SWIFT_PACKAGE
import MobileFuseSDKWrapper
#else
import MobileFuseSDK
#endif

public class MobilefuseNativeAd: NativeAd {
    public var nativeAdItem: MFNativeAd?
}
