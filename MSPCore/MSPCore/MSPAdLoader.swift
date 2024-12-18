//
//  MSPAdLoader.swift
//  MSPCore
//
//  Created by Huanzhi Zhang on 12/17/24.
//

import Foundation
import MSPiOSCore

public class MSPAdLoader: NSObject, BidListener {
    weak var adListener: AdListener?
    var adRequest: AdRequest?
    
    var bidLoader: BidLoader?
    var adNetworkAdapter: AdNetworkAdapter?

    
    
    public override init() {}
    
    public func loadAd(placementId: String, adListener: AdListener, adRequest: AdRequest) {
        MESMetricReporter.shared.logAdRequest(adRequest: adRequest)
        self.adListener = adListener
        self.adRequest = adRequest
        
        if adRequest.isCacheSupported, let ad = AdCache.shared.peakAd(placementId: placementId) {
            MESMetricReporter.shared.logAdResult(placementId: placementId, ad: ad, fill: true, isFromCache: true)
            adListener.onAdLoaded(placementId: placementId)
            return
        }
        
        self.bidLoader = MSP.shared.bidLoaderProvider.getBidLoader()
        bidLoader?.loadBid(placementId: placementId, adParams: adRequest.customParams, bidListener: self, adRequest: adRequest)
    }
    
    public func onBidResponse(bidResponse: Any, adNetwork: AdNetwork) {
        if let adListener = self.adListener,
           let adRequest = self.adRequest {
            if let adNetworkAdapter = MSP.shared.adNetworkAdapterProvider.getAdNetworkAdapter(adNetwork: adNetwork) {
                self.adNetworkAdapter = adNetworkAdapter
                adNetworkAdapter.setAdMetricReporter(adMetricReporter: AdMetricReporterImp())
                adNetworkAdapter.loadAdCreative(bidResponse: bidResponse, adListener: adListener, context: self, adRequest: adRequest)
            } else {
                adListener.onError(msg: "Ad network is not supported")
            }
        } else {
            adListener?.onError(msg: "Invalid request")
        }
    }
    
    public func onError(msg: String) {
        adListener?.onError(msg: msg)
    }
}
