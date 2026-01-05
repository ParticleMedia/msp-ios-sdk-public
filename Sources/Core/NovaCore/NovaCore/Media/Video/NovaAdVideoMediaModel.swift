//
//  NovaAdVideoMediaModel.swift
//  Pods
//
//  Created by Shanyu Li on 2025/8/7.
//

class NovaAdVideoMediaModel {
    // MARK: Lifecycle

    init(
        videoInfo: NovaNativeAdVideoInfo,
        videoLayoutOrientation: NovaNativeMediaLayoutOrientation,
        adCtrType: AdCtrType,
        callToAction: String?,
        endCardModel: NovaAdEndCardViewModel?
    ) {
        self.videoInfo = videoInfo
        self.videoLayoutOrientation = videoLayoutOrientation
        self.adCtrType = adCtrType
        self.callToAction = callToAction
        self.endCardModel = endCardModel
    }

    // MARK: Internal

    let videoInfo: NovaNativeAdVideoInfo
    let videoLayoutOrientation: NovaNativeMediaLayoutOrientation
    let adCtrType: AdCtrType
    let callToAction: String?
    let endCardModel: NovaAdEndCardViewModel?
}
