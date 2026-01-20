//
//  AuctionBidListener.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 12/17/24.
//

import Foundation

public protocol AuctionBidListener: AnyObject {
    
    func onSuccess(bid: AuctionBid)
    
    func onError(error: String)
}
