//
//  NovaNativeAdMedia.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/2/24.
//

import Foundation
import UIKit

public enum NovaNativeAdImageResource {
    case imageURLStr(String)
    case image(UIImage)
}

public struct NovaNativeAdVideoResource {
    let videoInfo: NovaNativeAdVideoInfo
    let adToken: String
    let reporter: IABMetricReporter?
 
    public init(videoInfo: NovaNativeAdVideoInfo, adToken: String, reporter: IABMetricReporter?) {
        self.videoInfo = videoInfo
        self.adToken = adToken
        self.reporter = reporter
    }
}

public enum NovaNativeAdMedia {
    case image(NovaNativeAdImageResource)
    case video(NovaNativeAdVideoResource)
}
