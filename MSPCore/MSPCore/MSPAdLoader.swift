//
//  MSPAdLoader.swift
//  MSPCore
//
//  Created by Huanzhi Zhang on 12/17/24.
//

import Foundation
import MSPiOSCore

public class MSPAdLoader: NSObject {
    
    weak var adListener: AdListener?
    var adRequest: AdRequest?
    
    var bidLoader: BidLoader?
    var adNetworkAdapter: AdNetworkAdapter?

    var mspAuction: MSPAuction?
    
    public override init() {}
    
    public func loadAd(placementId: String, adListener: AdListener, adRequest: AdRequest) {
        MESMetricReporter.shared.logAdRequest(adRequest: adRequest)
        self.adListener = adListener
        self.adRequest = adRequest
        /*
        if let ad = AdCache.shared.peakAd(placementId: placementId) {
            MESMetricReporter.shared.logAdResult(placementId: placementId, ad: ad, fill: true, isFromCache: true)
            adListener.onAdLoaded(placementId: placementId)
            return
        }
        
        self.bidLoader = MSP.shared.bidLoaderProvider.getBidLoader()
        bidLoader?.loadBid(placementId: placementId, adParams: adRequest.customParams, bidListener: self, adRequest: adRequest)
         */
        let mspAuction = MSPAuction(bidders: getBidders(placementId: placementId), cacheOnly: false, timeout: 5000)
        self.mspAuction = mspAuction
        mspAuction.adRequest = adRequest
        mspAuction.startAuction(auctionListener: self, adListener: adListener)
    }
    
    public func getBidders(placementId: String) -> [MSPiOSCore.Bidder] {
        var bidders = [MSPiOSCore.Bidder]()
        
        if let adConfig = MSPAdConfigManager.shared.adConfig,
           let placements = adConfig.placements {
            for placement in placements {
                if placement.placementId == placementId,
                   let bidderInfoList = placement.bidders {
                    for bidderInfo in bidderInfoList {
                        if let bidder = getBidder(bidderInfo: bidderInfo) {
                            bidders.append(bidder)
                        }
                    }
                }
            }
        }
        
        return bidders
    }
    
    public func getBidder(bidderInfo: BidderInfo) -> MSPiOSCore.Bidder? {
        switch bidderInfo.name {
        case "msp":
            return MSPMultiFormatBidder(name: "msp", bidderPlacementId: bidderInfo.bidderPlacementId)
        case "unity":
            return MSP.shared.adNetworkAdapterProvider.unityManager?.getAdBidder(bidderPlacementId: bidderInfo.bidderPlacementId)
        default:
            return nil
        }
    }
    /*
    public func onBidResponse(bidResponse: Any, adNetwork: AdNetwork) {
        if let adListener = self.adListener,
           let adRequest = self.adRequest {
            if let adNetworkAdapter = MSP.shared.adNetworkAdapterProvider.getAdNetworkAdapter(adNetwork: adNetwork) {
                self.adNetworkAdapter = adNetworkAdapter
                adNetworkAdapter.setAdMetricReporter(adMetricReporter: AdMetricReporterImp())
                adNetworkAdapter.loadAdCreative(bidResponse: bidResponse, auctionBidListener: self, adListener: adListener, context: self, adRequest: adRequest)
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
     */
}



extension MSPAdLoader: AuctionListener {
    public func onSuccess(winningBid: MSPiOSCore.AuctionBid) {
        DispatchQueue.main.async {
            self.adListener?.onAdLoaded(placementId: winningBid.bidderPlacementId)
        }
    }
    
    public func onError(error: String) {
        adListener?.onError(msg: error)
    }
    
    
}

