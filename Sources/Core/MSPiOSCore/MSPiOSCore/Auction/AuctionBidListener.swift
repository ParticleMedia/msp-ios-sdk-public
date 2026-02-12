//
//  AuctionBidListener.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 12/17/24.
//

import Foundation

public protocol AuctionBidListener: AnyObject {
    func onSuccess(bid: AuctionBid, loadInfo: [String: Any])

    func onError(error: String, loadInfo: [String: Any])
}

public extension AuctionBidListener {
    func onSuccess(bid: AuctionBid) {
        onSuccess(bid: bid, loadInfo: [:])
    }

    func onError(error: String) {
        onError(error: error, loadInfo: [:])
    }
}
