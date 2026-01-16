//
//  NovaAdVideoMediaModel.swift
//  Pods
//
//  Created by Shanyu Li on 2025/8/7.
//

import Foundation

class NovaAdVideoMediaModel {
    // MARK: Lifecycle

    init(
        videoInfo: NovaNativeAdVideoInfo,
        videoLayoutOrientation: NovaNativeMediaLayoutOrientation,
        adCtrType: AdCtrType,
        callToAction: String?,
        advertiser: String?,
        iconURL: URL?,
        popupCTAStyleVariant: NovaPopupCTAStyleVariant,
        endCardModel: NovaAdEndCardViewModel?
    ) {
        self.videoInfo = videoInfo
        self.videoLayoutOrientation = videoLayoutOrientation
        self.adCtrType = adCtrType
        self.callToAction = callToAction
        self.advertiser = advertiser
        self.iconURL = iconURL
        self.popupCTAStyleVariant = popupCTAStyleVariant
        self.endCardModel = endCardModel
    }

    // MARK: Internal

    let videoInfo: NovaNativeAdVideoInfo
    let videoLayoutOrientation: NovaNativeMediaLayoutOrientation
    let adCtrType: AdCtrType
    let callToAction: String?
    let advertiser: String?
    let iconURL: URL?
    let popupCTAStyleVariant: NovaPopupCTAStyleVariant
    let endCardModel: NovaAdEndCardViewModel?
}
