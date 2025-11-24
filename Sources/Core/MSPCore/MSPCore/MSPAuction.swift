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
        MSPLogger.shared.info(message: "[Auction: Load Ad] started")
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
                    MSPLogger.shared.info(message: "[Auction: Load Ad] time out. winner: \(winnerBid.bidderName),\(winnerBid.ecpm),\(winnerBid.bidderPlacementId)")
                    auctionListener.onSuccess(winningBid: winnerBid)
                } else {
                    MSPLogger.shared.info(message: "[Auction: Load Ad] time out. No winning bid")
                    auctionListener.onError(error: "request time out: client auction no winning bid")
                }
            }
        }
        
        // Wait for all responses or timeout
        // timeout is in millisecond
        DispatchQueue.global().asyncAfter(deadline: .now() + (timeout / 1000.0), execute: timeoutWorkItem)
        
        dispatchGroup.notify(queue: biddingDispatchQueue) { [weak self] in
            if let isTimeout = self?.isTimeout,
               isTimeout {
                return
            }
            timeoutWorkItem.cancel()
            if let winnerBid = self?.getWinnerBid() {
                MSPLogger.shared.info(message: "[Auction: Load Ad] completed. winner: \(winnerBid.bidderName),\(winnerBid.ecpm),\(winnerBid.bidderPlacementId)")
                auctionListener.onSuccess(winningBid: winnerBid)
            } else {
                MSPLogger.shared.info(message: "[Auction: Load Ad] completed. No winning bid")
                auctionListener.onError(error: "client auction no winning bid")
            }
            
        }
    }
    
    private func fetchBid(bidder: Bidder, cacheOnly: Bool, auctionBidListener: AuctionBidListener, adListener: AdListener?) {
        MSPLogger.shared.info(message: "[Auction: Load Ad] Fetching bid from bidder: \(bidder.name). bidderPlacementId: \(bidder.bidderPlacementId)")
        if let cachedAd = AdCache.shared.peakAd(placementId: bidder.bidderPlacementId) {
            MSPLogger.shared.info(message: "[Auction: Load Ad] Ad filled from cache: \(bidder.name), price: \(cachedAd.adInfo["price"]), bidderPlacementId:\(bidder.bidderPlacementId)")
            let auctionBid = AuctionBid(bidderName: bidder.name, bidderPlacementId: bidder.bidderPlacementId, ecpm: cachedAd.adInfo["price"] as? Double ?? 0.0, fromCache: true)
            auctionBid.ad = cachedAd
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
        MSPLogger.shared.info(message: "[Auction] Ads filled from bidder: \(bid.bidderName). bidderPlacementId: \(bid.bidderPlacementId)")
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
