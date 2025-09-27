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
        adCtrType: AdCtrType,
        callToAction: String?,
        endCardModel: NovaAdEndCardViewModel?,
        style: NovaAdVideoView.Style
    ) {
        self.videoInfo = videoInfo
        self.adCtrType = adCtrType
        self.callToAction = callToAction
        self.endCardModel = endCardModel
        self.style = style
    }

    // MARK: Internal

    let videoInfo: NovaNativeAdVideoInfo
    let adCtrType: AdCtrType
    let callToAction: String?
    let endCardModel: NovaAdEndCardViewModel?
    let style: NovaAdVideoView.Style
}
