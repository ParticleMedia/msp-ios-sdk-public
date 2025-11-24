//
//  PubmaticNativeAd.swift
//  PubmaticAdapter
//
//  Created by Huanzhi Zhang on 2/5/25.
//

import Foundation
import MSPiOSCore
#if SWIFT_PACKAGE
import OpenWrapSDKWrapper
#else
import OpenWrapSDK
#endif

public class PubmaticNativeAd: NativeAd {
    public var nativeAdItem: POBNativeAd?
}
