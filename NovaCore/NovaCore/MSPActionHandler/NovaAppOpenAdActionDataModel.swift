//
//  NovaAppOpenAdActionDataModel.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 11/13/24.
//

import Foundation


public struct NovaAppOpenAdActionDataModel {
    let url: URL
    let adId: String
    let requestId: String
    let adUnitId: String
    let clickTime: Double
    let videoInfo: NovaNativeAdVideoInfo?
    let encryptedAdToken: String

    public init(url: URL, clickTime: Double, ad: NovaBaseAd) {
        self.url = url
        self.clickTime = clickTime
        self.adId = ad.adId
        self.requestId = ad.requestId
        self.adUnitId = ad.adUnitId
        self.encryptedAdToken = ad.encryptedAdToken
        self.videoInfo = (ad as? NovaNativeAdItem)?.videoInfo
    }
}
