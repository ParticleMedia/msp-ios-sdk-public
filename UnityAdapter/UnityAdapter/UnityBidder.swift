//
//  UnityBidder.swift
//  UnityAdapter
//
//  Created by Huanzhi Zhang on 12/23/24.
//

import Foundation
import MSPiOSCore
import IronSource


public class UnityBidder: MSPiOSCore.Bidder {
    public weak var auctionBidListener: AuctionBidListener?
    public weak var adListener: AdListener?
    public var adRequest: AdRequest?
    public var adNetworkAdapter: AdNetworkAdapter = UnityAdapter()
    
    public var bannerView: LPMBannerAdView?
    
    public override func requestBid(adRequest: AdRequest, bidListener: any AuctionBidListener, adListener: any AdListener) {
        self.auctionBidListener = bidListener
        self.adListener = adListener
        self.adRequest = adRequest
        
        if let auctionBidListener = self.auctionBidListener {
            adNetworkAdapter.loadAdCreative(bidResponse: self, auctionBidListener: auctionBidListener, adListener: adListener, context: self, adRequest: adRequest, bidderPlacementId: bidderPlacementId, bidderFormat: self.bidderFormat)
        }
        
        
    }
    
    public override func setAdMetricReporter(adMetricReporter: AdMetricReporter)  {
        self.adNetworkAdapter.setAdMetricReporter(adMetricReporter: adMetricReporter)
    }
    
    
}
