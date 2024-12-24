//
//  MSPAuctionManager.swift
//  MSPCore
//
//  Created by Huanzhi Zhang on 12/18/24.
//

import Foundation
import MSPiOSCore

public class MSPAuction: Auction {
    // To do: add timeout item and add a specific queue for bidding job
    
    private let biddingDispatchQueue = DispatchQueue(label: "com.msp.ads.bidding", attributes: .concurrent)
    private var dispatchGroup = DispatchGroup()
    private var auctionBidList: [AuctionBid]?
    
    public override func startAuction(auctionListener: any AuctionListener, adListener: (any AdListener)?) {
        auctionBidList = [AuctionBid]()
        for bidder in bidders {
            dispatchGroup.enter()
            fetchBid(bidder: bidder, cacheOnly: cacheOnly, auctionBidListener: self, adListener: adListener)
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            if let winnerBid = self?.getWinnerBid() {
                auctionListener.onSuccess(winningBid: winnerBid)
            } else {
                auctionListener.onError(error: "client auction no winning bid")
            }
        }
    }
    
    private func fetchBid(bidder: Bidder, cacheOnly: Bool, auctionBidListener: AuctionBidListener, adListener: AdListener?) {
        if let cachedAd = AdCache.shared.peakAd(placementId: bidder.bidderPlacementId) {
            let auctionBid = AuctionBid(bidderName: bidder.name, bidderPlacementId: bidder.bidderPlacementId, ecpm: cachedAd.adInfo["price"] as? Double ?? 0.0)
            auctionBidListener.onSuccess(bid: auctionBid)
        } else if cacheOnly {
            auctionBidListener.onError(error: "no cached ad in cache")
        } else if let adRequest = self.adRequest,
                  let adListener = adListener {
            bidder.requestBid(adRequest: adRequest, bidListener: self, adListener: adListener)
        } else {
            auctionBidListener.onError(error: "fail to load a bid request")
        }
    }
    
    private func getWinnerBid() -> AuctionBid? {
        guard let auctionBidList = auctionBidList,
              var winnerBid = auctionBidList.first else {return nil}
        for auctionBid in auctionBidList {
            if auctionBid.ecpm > winnerBid.ecpm {
                winnerBid = auctionBid
            }
        }
        return winnerBid
    }
}

extension MSPAuction: AuctionBidListener {
    public func onSuccess(bid: MSPiOSCore.AuctionBid) {
        auctionBidList?.append(bid)
        self.dispatchGroup.leave()
    }
    
    public func onError(error: String) {
        self.dispatchGroup.leave()
    }
}
