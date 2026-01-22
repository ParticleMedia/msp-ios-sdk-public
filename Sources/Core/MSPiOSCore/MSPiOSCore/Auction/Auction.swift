//
//  Auction.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 12/17/24.
//

import Foundation

open class Auction {
    public var bidders: [Bidder]
    public var adRequest: AdRequest?
    public var cacheOnly: Bool
    public var timeout: TimeInterval

    public init(bidders: [Bidder], adRequest: AdRequest? = nil, cacheOnly: Bool, timeout: TimeInterval) {
        self.bidders = bidders
        self.adRequest = adRequest
        self.cacheOnly = cacheOnly
        self.timeout = timeout
    }

    open func startAuction(auctionListener: AuctionListener, adListener: AdListener?) {
    }

    open func fetchBid(bidder: Bidder, adListener: AdListener?, cacheOnly: Bool) -> AuctionBid? {
        nil
    }
}
