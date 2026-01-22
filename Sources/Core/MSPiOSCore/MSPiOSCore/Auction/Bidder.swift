//
//  Bidder.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 12/17/24.
//

import Foundation

open class Bidder {
    public var name: String
    public var bidderPlacementId: String
    public var bidderFormat: AdFormat?

    public var params: [String: String]?

    public init(name: String, bidderPlacementId: String, bidderFormat: AdFormat?) {
        self.name = name
        self.bidderPlacementId = bidderPlacementId
        self.bidderFormat = bidderFormat
    }

    open func requestBid(adRequest: AdRequest, bidListener: AuctionBidListener, adListener: AdListener) {
    }

    open func setAdMetricReporter(adMetricReporter: AdMetricReporter) {
    }
}
