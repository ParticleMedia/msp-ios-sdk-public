//
//  File.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 7/9/24.
//

import Foundation

open class AdNetworkManager {
    public init() {}

    open func getAdNetworkAdapter() -> AdNetworkAdapter? {
        nil
    }

    open func getAdBidder(bidderPlacementId: String, bidderFormat: AdFormat?) -> Bidder? {
        nil
    }
}
