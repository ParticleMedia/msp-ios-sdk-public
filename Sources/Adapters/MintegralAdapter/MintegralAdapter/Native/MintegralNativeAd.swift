//
//  MintegralNativeAd.swift
//  MintegralAdapter
//
//  Created by Huanzhi Zhang on 2/5/25.
//

import Foundation
import MSPiOSCore
#if SWIFT_PACKAGE
import MTGSDK
#else
import MTGSDK
#endif

public class MintegralNativeAd: NativeAd {
    public var nativeAdItem: MTGCampaign?
}
