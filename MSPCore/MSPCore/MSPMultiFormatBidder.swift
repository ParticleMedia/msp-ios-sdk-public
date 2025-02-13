//
//  MSPMultiFormatBidder.swift
//  MSPCore
//
//  Created by Huanzhi Zhang on 12/18/24.
//

import Foundation
import MSPiOSCore
import PrebidMobile

public class MSPMultiFormatBidder: MSPiOSCore.Bidder {
    public weak var auctionBidListener: AuctionBidListener?
    public weak var adListener: AdListener?
    public var adRequest: AdRequest?
    public var adNetworkAdapter: AdNetworkAdapter?
    public var bidLoader: BidLoader?
    
    public override func requestBid(adRequest: AdRequest, bidListener: any AuctionBidListener, adListener: any AdListener) {
        let prebidBidLoader = MSP.shared.bidLoaderProvider.getBidLoader()
        self.auctionBidListener = bidListener
        self.adListener = adListener
        self.adRequest = adRequest
        self.bidLoader = prebidBidLoader
        prebidBidLoader.loadBid(placementId: bidderPlacementId, adParams: adRequest.customParams, bidListener: self, adRequest: adRequest)
    }
}

extension MSPMultiFormatBidder: BidListener {
    public func onBidResponse(bidResponse: Any, adNetwork: MSPiOSCore.AdNetwork) {
        if let adListener = self.adListener,
           let adRequest = self.adRequest,
           let auctionBidListener = auctionBidListener {
            if let adNetworkAdapter = MSP.shared.adNetworkAdapterProvider.getAdNetworkAdapter(adNetwork: adNetwork) {
                self.adNetworkAdapter = adNetworkAdapter
                adNetworkAdapter.setAdMetricReporter(adMetricReporter: AdMetricReporterImp())
                adNetworkAdapter.loadAdCreative(bidResponse: bidResponse, auctionBidListener: auctionBidListener, adListener: adListener, context: self, adRequest: adRequest, bidderPlacementId: bidderPlacementId, bidderFormat: nil, params: self.params)
            } else {
                auctionBidListener.onError(error: "Ad network is not supported")
            }
        } else {
            auctionBidListener?.onError(error: "Invalid request")
        }
    }
    
    public func onError(msg: String) {
        auctionBidListener?.onError(error: "Prebid bid load fail to get a bidResponse")
    }
}
