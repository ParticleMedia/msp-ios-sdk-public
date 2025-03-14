//
//  AuctionBid.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 12/17/24.
//

import Foundation

public class AuctionBid {
    public var bidderName: String
    public var bidderPlacementId: String
    public var ecpm: Double
    
    public init(bidderName: String, bidderPlacementId: String, ecpm: Double) {
        self.bidderName = bidderName
        self.bidderPlacementId = bidderPlacementId
        self.ecpm = ecpm
    }
}
