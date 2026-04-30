//
//  ApplovinMaxManager.swift
//  ApplovinMaxAdapter
//

import Foundation
import MSPiOSCore

public class ApplovinMaxManager: AdNetworkManager {
    public override func getAdNetworkAdapter() -> AdNetworkAdapter? {
        ApplovinMaxAdapter()
    }

    public override func getAdBidder(bidderPlacementId: String, bidderFormat: AdFormat?) -> Bidder? {
        ApplovinMaxBidder(name: "applovin", bidderPlacementId: bidderPlacementId, bidderFormat: bidderFormat)
    }
}
