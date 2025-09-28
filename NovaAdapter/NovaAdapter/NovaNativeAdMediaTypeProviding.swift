//
//  NovaNativeAdMediaTypeProviding.swift
//  Pods
//
//  Created by Shanyu Li on 2025/9/28.
//

import NovaCore
import MSPiOSCore

public protocol NovaNativeAdMediaTypeProviding {
    var mediaType: NovaAdMediaType? { get }
}

extension MSPiOSCore.NativeAd: NovaNativeAdMediaTypeProviding {
    public var mediaType: NovaAdMediaType? {
        if let novaAd = self as? NovaNativeAd {
            return novaAd.nativeAdItem?.mediaContent.mediaType
        }
        return nil
    }
}
