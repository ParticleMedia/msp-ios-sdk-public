//
//  NovaActionHelperModels.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/8/11.
//

import Foundation

// MARK: - AdActionExtraInfo

struct AdActionExtraInfo {
    // MARK: Lifecycle

    init(videoMediaModel: NovaAdVideoMediaModel? = nil, advertiser: String? = nil) {
        self.videoMediaModel = videoMediaModel
        self.advertiser = advertiser
    }

    // MARK: Internal

    // needed for video ad playing on landing page
    let videoMediaModel: NovaAdVideoMediaModel?
    // needed for some ads missing landing page title
    let advertiser: String?
}

// MARK: - AdActionTracingInfo

struct AdActionTracingInfo {
    // using for reporting
    let adId: String
    let adSetId: String
    let requestId: String
    let adUnitId: String
    let thirdPartyClickTrackingUrls: [String]
    let encryptedAdToken: String
    let adOpportunityID: UUID?
}

// MARK: - AdActionModel

struct AdActionModel {
    // MARK: Lifecycle

    init(
        tracingInfo: AdActionTracingInfo,
        extraInfo: AdActionExtraInfo,
        ctrType: AdCtrType
    ) {
        self.tracingInfo = tracingInfo
        self.extraInfo = extraInfo
        self.ctrType = ctrType
    }

    // MARK: Internal

    let tracingInfo: AdActionTracingInfo
    let extraInfo: AdActionExtraInfo
    let ctrType: AdCtrType
}

// MARK: - AdMultipleItemsActionModel

struct AdMultipleItemsActionModel {
    // MARK: Lifecycle

    init(
        tracingInfo: AdActionTracingInfo,
        extraInfo: AdActionExtraInfo,
        outerCtrType: AdCtrType,
        innerCtrType: AdCtrType?
    ) {
        self.tracingInfo = tracingInfo
        self.extraInfo = extraInfo
        self.outerCtrType = outerCtrType
        self.innerCtrType = innerCtrType
    }

    // MARK: Internal

    let tracingInfo: AdActionTracingInfo
    let extraInfo: AdActionExtraInfo
    let outerCtrType: AdCtrType
    let innerCtrType: AdCtrType?
}

extension NovaBaseAd {
    var actionExtraInfo: AdActionExtraInfo {
        let videoMediaModel: NovaAdVideoMediaModel? = {
            guard let nativeBaseAd = self as? NovaNativeBaseAd else {
                return nil
            }
            guard case .video(let model) = nativeBaseAd.mediaContent.adMedia else {
                return nil
            }

            return nativeBaseAd.creativeType == .nativeVideo ? model : nil
        }()

        let advertiser = (self as? NovaNativeBaseAd)?.advertiser

        return AdActionExtraInfo(videoMediaModel: videoMediaModel, advertiser: advertiser)
    }

    var actionTracingInfo: AdActionTracingInfo {
        return AdActionTracingInfo(
            adId: adId,
            adSetId: adSetId,
            requestId: requestId,
            adUnitId: adUnitId,
            thirdPartyClickTrackingUrls: thirdPartyClickTrackingUrls,
            encryptedAdToken: encryptedAdToken,
            adOpportunityID: adOpportunityID
        )
    }
}
