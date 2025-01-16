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
    
    var winnerBidderPlacementId: String?

    var mspAuction: MSPAuction?
    
    public override init() {}
    
    public func loadAd(placementId: String, adListener: AdListener, adRequest: AdRequest) {
        MESMetricReporter.shared.logAdRequest(adRequest: adRequest)
        self.adListener = adListener
        self.adRequest = adRequest
        
        if let placement = getPlacement(placementId: placementId) {
            let mspAuction = MSPAuction(bidders: getBidders(placement: placement), cacheOnly: false, timeout: Double(placement.auctionTimeout ?? 8))
            self.mspAuction = mspAuction
            mspAuction.adRequest = adRequest
            mspAuction.startAuction(auctionListener: self, adListener: adListener)
        } else {
            adListener.onError(msg: "invalid placement")
        }
    }
    
    public func getPlacement(placementId: String) -> Placement? {
        if let adConfig = MSPAdConfigManager.shared.adConfig,
           let placements = adConfig.placements {
            for placement in placements {
                if placement.placementId == placementId {
                    return placement
                }
            }
        }
        return nil
    }
    
    public func getBidders(placement: Placement) -> [MSPiOSCore.Bidder] {
        var bidders = [MSPiOSCore.Bidder]()
        
        if let bidderInfoList = placement.bidders {
            for bidderInfo in bidderInfoList {
                if let bidder = getBidder(bidderInfo: bidderInfo) {
                    bidders.append(bidder)
                }
            }
        }
        
        return bidders
    }
    
    public func getBidder(bidderInfo: BidderInfo) -> MSPiOSCore.Bidder? {
        var bidderFormat: AdFormat?
        switch bidderInfo.bidderFormat {
        case "banner":
            bidderFormat = .banner
        case "native":
            bidderFormat = .native
        case "interstitial":
            bidderFormat = .interstitial
        case "multi_format":
            bidderFormat = .multi_format
        default:
            bidderFormat = nil
            
        }
        
        switch bidderInfo.name {
        case "msp":
            return MSPMultiFormatBidder(name: "msp", bidderPlacementId: bidderInfo.bidderPlacementId, bidderFormat: bidderFormat)
        case "unity":
            return MSP.shared.adNetworkAdapterProvider.unityManager?.getAdBidder(bidderPlacementId: bidderInfo.bidderPlacementId, bidderFormat: bidderFormat)
        default:
            return nil
        }
    }
    
    public func getAd(placementId: String) -> MSPAd? {
        if let winnerBidderPlacement = self.winnerBidderPlacementId {
            return AdCache.shared.getAd(placementId: winnerBidderPlacement)
        }
        return nil
    }
}



extension MSPAdLoader: AuctionListener {
    public func onSuccess(winningBid: MSPiOSCore.AuctionBid) {
        DispatchQueue.main.async {
            self.winnerBidderPlacementId = winningBid.bidderPlacementId
            if let placementId = self.adRequest?.placementId {
                self.adListener?.onAdLoaded(placementId: placementId)
            }
        }
    }
    
    public func onError(error: String) {
        adListener?.onError(msg: error)
    }
    
    
}

