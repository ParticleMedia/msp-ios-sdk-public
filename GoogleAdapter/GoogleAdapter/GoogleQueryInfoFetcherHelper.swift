//
//  GoogleQueryInfoFetcherHelper.swift
//  GoogleAdapter
//
//  Created by Huanzhi Zhang on 12/21/23.
//

import Foundation
import MSPiOSCore
//import shared
import GoogleMobileAds

public class GoogleQueryInfoFetcherHelper: GoogleQueryInfoFetcher {
    public init() {
        
    }
    
    public func fetch(completeListener: GoogleQueryInfoListener, adRequest: AdRequest) {
        let request = GAMRequest()
        // Specify the "query_info_type" as "requester_type_8" to
        // denote that the usage of QueryInfo is for Ad Manager S2S.
        let extras = getExtras(adRequest: adRequest)
        //extras.additionalParameters = ["query_info_type" : "requester_type_8"]
        request.register(extras)
        let googleAdFormat: GADAdFormat
        switch adRequest.adFormat {
        case .banner:
            googleAdFormat = GADAdFormat.banner
        case .native:
            googleAdFormat = GADAdFormat.native
        case .interstitial:
            googleAdFormat = GADAdFormat.interstitial
        default:
            googleAdFormat = GADAdFormat.native
        }
        //= adRequest.adFormat == .banner ? GADAdFormat.banner : GADAdFormat.native
        GADQueryInfo.createQueryInfo(with: request, adFormat: googleAdFormat) { [weak self] queryInfo, error in
            guard let self = self else {return}
            if let error = error {
                return
            }

            if let queryInfoString = queryInfo?.query {
                completeListener.onComplete(queryInfo: queryInfoString)
            } else {
                completeListener.onComplete(queryInfo: "")
            }
        }
    }
    
    private func getExtras(adRequest: AdRequest) -> GADExtras {
        let extras = GADExtras()
        if let adapterBannerSize = adRequest.adaptiveBannerSize,
           adapterBannerSize.isInlineAdaptiveBanner {
            extras.additionalParameters = ["query_info_type" : "requester_type_8",
                                           "inlined_adaptive_banner_w" : adapterBannerSize.width,
                                           "inlined_adaptive_banner_h" : adapterBannerSize.height]
        } else if let adapterBannerSize = adRequest.adaptiveBannerSize,
                   adapterBannerSize.isAnchorAdaptiveBanner {
            extras.additionalParameters = ["query_info_type" : "requester_type_8",
                                           "adaptive_banner_w" : adapterBannerSize.width,
                                           "adaptive_banner_h" : adapterBannerSize.height]
        } else {
            extras.additionalParameters = ["query_info_type" : "requester_type_8"]
        }
        return extras
    }
}
