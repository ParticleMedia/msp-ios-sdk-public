//
//  NovaActionHelperModels.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/8/11.
//

// MARK: - AdActionExtraInfo

import Foundation
import UIKit

struct AdActionExtraInfo {
    // MARK: Lifecycle

    init(
        videoMediaModel: NovaAdVideoMediaModel? = nil,
        advertiser: String? = nil,
        playableConfig: PlayableConfig? = nil,
        onAdViewClick: ((UIView?) -> Void)? = nil
    ) {
        self.videoMediaModel = videoMediaModel
        self.advertiser = advertiser
        self.playableConfig = playableConfig
        self.onAdViewClick = onAdViewClick
    }

    // MARK: Internal

    // needed for video ad playing on landing page
    let videoMediaModel: NovaAdVideoMediaModel?
    // needed for some ads missing landing page title
    let advertiser: String?

    let playableConfig: PlayableConfig?

    let onAdViewClick: ((UIView?) -> Void)?

    // Playable ad specific configuration
    struct PlayableConfig {
        let actionBarFormat: NovaAdPlayableInfo.ActionBarFormat?
        let appInfo: AsyncValue<NovaAdAppInfo>?
        let callToAction: String?

        init(
            actionBarFormat: NovaAdPlayableInfo.ActionBarFormat? = nil,
            appInfo: AsyncValue<NovaAdAppInfo>? = nil,
            callToAction: String? = nil,
        ) {
            self.actionBarFormat = actionBarFormat
            self.appInfo = appInfo
            self.callToAction = callToAction
        }
    }
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

        let playableConfig: AdActionExtraInfo.PlayableConfig? = {
            guard let nativeBaseAd = self as? NovaNativeBaseAd else {
                return nil
            }

            switch nativeBaseAd.mediaContent.adMedia {
            case let .imagePlayable(_, playableModel), let .videoPlayable(_, playableModel):
                return AdActionExtraInfo.PlayableConfig(
                    actionBarFormat: playableModel.actionBarFormat,
                    appInfo: playableModel.appInfo,
                    callToAction: nativeBaseAd.callToAction
                )
            default:
                return nil
            }
        }()

        return AdActionExtraInfo(
            videoMediaModel: videoMediaModel, advertiser: advertiser, playableConfig: playableConfig
        ) { adView in
            switch self {
            case let nativeAd as NovaNativeAdItem:
                nativeAd.delegate?
                    .nativeAdDidLogClick(
                        nativeAd,
                        clickAreaName: NovaAdMetricReporter.convertNovaClickAreaNameToMetric(
                            clickArea: adView?.adClickArea?.rawValue) ?? ""
                    )
            case let interstitialAd as NovaInterstitialAdItem:
                interstitialAd.delegate?.interstitialAdDidLogClick(interstitialAd)
            default:
                // TODO: lsy, banner nova ad has no delegate now
                break
            }
        }
    }

    var actionTracingInfo: AdActionTracingInfo {
        AdActionTracingInfo(
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
