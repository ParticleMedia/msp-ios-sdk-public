//
//  MSPAuctionManager.swift
//  MSPCore
//
//  Created by Huanzhi Zhang on 12/18/24.
//

import Foundation
import MSPiOSCore

public class MSPAuction: Auction {
    
    private let biddingDispatchQueue = DispatchQueue(label: "com.msp.ads.bidding", attributes: .concurrent)
    private var dispatchGroup = DispatchGroup()
    private var auctionBidList: [AuctionBid]?
    
    private var isTimeout = false
    private var remainingTaskCnt = 0
    
    private let taskLock = NSLock()

    
    public override func startAuction(auctionListener: any AuctionListener, adListener: (any AdListener)?) {
        auctionBidList = [AuctionBid]()
        remainingTaskCnt = bidders.count
        for bidder in bidders {
            dispatchGroup.enter()
            fetchBid(bidder: bidder, cacheOnly: cacheOnly, auctionBidListener: self, adListener: adListener)
        }
        
        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            self?.isTimeout = true
            self?.biddingDispatchQueue.async {
                if let winnerBid = self?.getWinnerBid() {
                    auctionListener.onSuccess(winningBid: winnerBid)
                } else {
                    auctionListener.onError(error: "request time out: client auction no winning bid")
                }
            }
        }
        
        // Wait for all responses or timeout
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)
        
        dispatchGroup.notify(queue: biddingDispatchQueue) { [weak self] in
            if let isTimeout = self?.isTimeout,
               isTimeout {
                return
            }
            timeoutWorkItem.cancel()
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
       
        guard let auctionBidList = self.auctionBidList,
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
        self.biddingDispatchQueue.async {
            self.taskLock.lock()
            if self.remainingTaskCnt > 0 {
                self.remainingTaskCnt = self.remainingTaskCnt - 1
                self.auctionBidList?.append(bid)
                self.dispatchGroup.leave()
            }
            self.taskLock.unlock()
        }
    }
    
    public func onError(error: String) {
        self.biddingDispatchQueue.async {
            self.taskLock.lock()
            if self.remainingTaskCnt > 0 {
                self.remainingTaskCnt = self.remainingTaskCnt - 1
                self.dispatchGroup.leave()
            }
            self.taskLock.unlock()
        }
    }
}
