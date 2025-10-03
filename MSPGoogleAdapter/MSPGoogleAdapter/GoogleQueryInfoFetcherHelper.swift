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
        let request = AdManagerRequest()
        // Specify the "query_info_type" as "requester_type_8" to
        // denote that the usage of QueryInfo is for Ad Manager S2S.
        let extras = getExtras(adRequest: adRequest)
        if let contentUrls = adRequest.customParams[MSPConstants.GOOGLE_AD_MULTI_CONTENT_URLS] as? [String] {
            request.neighboringContentURLs = contentUrls
        }
        request.register(extras)
        let googleAdFormat: GoogleMobileAds.AdFormat
        switch adRequest.adFormat {
        case .banner:
            googleAdFormat = GoogleMobileAds.AdFormat.banner
        case .native:
            googleAdFormat = GoogleMobileAds.AdFormat.native
        case .interstitial:
            googleAdFormat = GoogleMobileAds.AdFormat.interstitial
        default:
            googleAdFormat = GoogleMobileAds.AdFormat.native
        }
        
        QueryInfo.createQueryInfo(with: request, adFormat: googleAdFormat) { [weak self] queryInfo, error in
            guard let self = self else {
                completeListener.onComplete(queryInfo: "")
                return
            }
            if let error = error {
                completeListener.onComplete(queryInfo: "")
                return
            }

            if let queryInfoString = queryInfo?.query {
                completeListener.onComplete(queryInfo: queryInfoString)
            } else {
                completeListener.onComplete(queryInfo: "")
            }
        }
    }
    
    private func getExtras(adRequest: AdRequest) -> Extras {
        let extras = Extras()
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
